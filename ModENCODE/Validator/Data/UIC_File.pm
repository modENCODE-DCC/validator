package ModENCODE::Validator::Data::UIC_File;

use strict;
my $root_dir;
BEGIN {
  $root_dir = $0;
  $root_dir =~ s/[^\/]*$//;
  $root_dir = "./" unless $root_dir =~ /\//;
  push @INC, $root_dir;
}
use Class::Std;
use Carp qw(croak carp);
use base qw(ModENCODE::Validator::Data::Data);
use ModENCODE::ErrorHandler qw(log_error);
use LWP::UserAgent;
use File::Basename qw(basename);
use IPC::Open3 qw(open3);
use IO::Select;

my %cached_fastq_files  :ATTR( :default<{}> );
my %seen_data           :ATTR( :default<{}> );
my %transfer_host       :ATTR( :name<transfer_host>,     :default<"74.114.99.77"> );
my %remote_url_prefix   :ATTR( :name<remote_url_prefix>, :default<"rsync://uberkeley\@74.114.99.63::berkeley/pipeline/"> );
my %local_web_prefix    :ATTR( :name<local_web_prefix>,  :default<"http://submit.modencode.org/submit/public/get_file/"> );
my %transfer_cmd        :ATTR( :name<transfer_cmd>,      :default<"devel/fetcher.pl"> );
my %remote_user         :ATTR( :name<remote_user>,       :default<"uberkeley"> );
my %identity_file       :ATTR( :name<identity_file>,     :default<"id_rsa.uic"> );
my %seen_url_filenames  :ATTR( :default<{}> );

sub START {
  my ($self, $ident, $args) = @_;
  if ($identity_file{$ident} !~ /^\//) {
    # Relative to root_dir
    $identity_file{$ident} = $root_dir . "/" . $identity_file{$ident};
  }
}

sub validate {
  my ($self) = @_;
  my $success = 1;

  log_error "Transferring large files to " . $self->get_transfer_host . ".", "notice", ">";
  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    next if $seen_data{$datum->get_id}++; # Don't re-update the same datum
    my $datum_obj = $datum->get_object;

    if (!length($datum_obj->get_value())) {
      log_error "No file for " . $datum_obj->get_heading(), ", though one was expected.", 'warning';
      next;
    } elsif (-r $datum_obj->get_value()) {
      log_error "Found local file " . $datum_obj->get_value() . " for column " . $datum_obj->get_heading() . " [" . $datum_obj->get_name . "]; skipping transfer to " . $self->get_transfer_host . ".", "notice";
      next;
    } elsif ($cached_fastq_files{ident $self}->{$datum_obj->get_value()}++) {
      log_error "Referring to the same " . $datum_obj->get_type(1)->get_name . " file (" . $datum_obj->get_value . ") in two different data columns!", "error";
      $success = 0;
      next;
    }

    my ($this_success, $done, $failed, $destination, $destination_size, $log);
    if ($datum_obj->get_value() =~ m|://|) {
      ($this_success, $success, $done, $failed, $destination, $destination_size, $log) = $self->transfer_file($datum_obj);
      last unless $success; # Some serious failure means we should stop processing
      if (!$this_success) {
        # Local fetch
        my $url = $datum_obj->get_value();
        $destination = File::Basename::basename($url);
        my $uniqid = ($seen_url_filenames{ident $self}->{$destination} ||= 0);
        if ($uniqid) { $destination = $uniqid . "_" . $destination; }
        log_error "Fetching remote file from $url to $destination...", "notice", ">";
        if (-r $destination) {
          log_error "$destination found locally...overwriting...", "notice";
        }
        my $ua = LWP::UserAgent->new();
        my $res = $ua->mirror($url, $destination);
        if ($res->is_success) {
          log_error "Done.", "notice", "<";
        } elsif ($res->is_error) {
          my $error_msg = $res->status_line;
          log_error ("Error retrieving Result File [" . $datum_obj->get_name() . "] from " . $datum_obj->get_value(), "error");
          log_error ("HTTP Response for $destination was:  " . $error_msg , "error", "<");
          $success = 0;
          last;
        }
        # Now pass it along to the transfer host from here...
        my $local_url = $self->get_local_url($destination);
        my @attributes = $datum_obj->get_attributes;
        push @attributes, new ModENCODE::Chado::DatumAttribute({
            'value' => $url,
            'type' => new ModENCODE::Chado::CVTerm({'name' => 'anyURI', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
            'name' => 'URL',
            'heading' => 'File Download URL',
            'datum' => $datum,
          });
        my $new_datum = new ModENCODE::Chado::Data({
            'heading' => $datum_obj->get_heading,
            'name' => $datum_obj->get_name,
            'value' => $local_url,
            'termsource' => $datum_obj->get_termsource,
            'type' => $datum_obj->get_type,
            'attributes' => \@attributes,
            'features' => $datum_obj->get_features || undef,
            'wiggle_datas' => $datum_obj->get_wiggle_datas || undef,
            'organisms' => $datum_obj->get_organisms || undef,
          });
        ModENCODE::Cache::update_datum($datum->get_object, $new_datum->get_object);
        $datum_obj = $new_datum->get_object;

        log_error "Transferring file from local machine ($local_url) to transfer host.", "notice", ">";
        ($this_success, $success, $done, $failed, $destination, $destination_size, $log) = $self->transfer_file($datum_obj);
        last unless $success;
        if (!$this_success) {
          log_error "Couldn't transfer from local copy to transfer host: $failed.", "error", "<";
          $success = 0;
          last;
        }
        log_error "Done.", "notice", "<";
      }
    } else {
      # It's already a local file
      if (!-r $datum_obj->get_value) {
        log_error "Couldn't find file " . $datum_obj->get_value . "!", "error", "<";
        $success = 0;
        last;
      }
      next;
    }
    $seen_url_filenames{ident $self}->{$destination}++;

    # Update datum to include a pointer to the remote URL
    my $current_time = time();
    my $current_date = Date::Format::time2str("%Y-%m-%d", $current_time, 'GMT');
    $datum_obj->add_attribute(new ModENCODE::Chado::DatumAttribute({
          'value' => $destination,
          'type' => new ModENCODE::Chado::CVTerm({'name' => 'anyURI', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
          'name' => 'Remote URL',
          'heading' => 'Remote File Location',
          'datum' => $datum,
        }));
    $datum_obj->add_attribute(new ModENCODE::Chado::DatumAttribute({
          'value' => $current_date,
          'type' => new ModENCODE::Chado::CVTerm({'name' => 'date', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
          'name' => 'Date',
          'heading' => 'File Transfer Date',
          'datum' => $datum,
        }));

  }

  log_error "Done.", "notice", "<";
  return $success;
}

sub parse_response {
  my $text = shift;

  my ($done) = ($text =~ /^done\t(.*)$/m);
  if (!defined($done)) { $done = -1; chomp $text; log_error "Couldn't parse $text.", "error"; }
  my ($failed) = ($text =~ /^failed\t(.*)$/m);
  my ($destination) = ($text =~ /^destination\t(.*)$/m);
  my ($destination_size) = ($text =~ /^destination_size\t(.*)$/m);
  my $log = "";
  if ($text =~ /^log$/m) {
    my @text = split(/\n/, $text);
    my $after_log = 0;
    foreach my $line (@text) {
      if ($after_log) {
        last if ($line !~ /^  /);
        $log .= $line . "\n";
      }
      if ($line =~ /^log$/) { $after_log = 1; }
    }
  }
  return ($done, $failed, $destination, $destination_size, $log);
}

sub transfer_file {
  my ($self, $datum_obj)  = @_;
  my $success = 1;
  my $this_success = 1;
  my $ssh = `which ssh` || '/usr/bin/ssh';
  chomp($ssh);
  # SSH to the transfer machine and try to grab the file
  my $cmd = $self->get_transfer_cmd . " upload";
  my $url = $datum_obj->get_value();
  my $command_id = `hostname`;
  chomp($command_id);
  $command_id .= "_" . $$;
  my $failed;
  my $response = "";
  {
    my @args =("-o", "User=" . $remote_user{ident $self}, "-o", "PasswordAuthentication=no", "-o", "IdentityFile=" . $identity_file{ident $self});
    my $pid = open3(my $sin, my $sout, my $serr, $ssh, @args, $self->get_transfer_host, $cmd);
    print $sin $url . "\n";
    print $sin $command_id . "\n";
    print $sin $self->get_project_id() . "\n";
    my $s = new IO::Select($sout); #, $serr);
    while (scalar($s->handles()) > 0) {
      my @ready = $s->can_read(1);
      foreach my $h (@ready) {
        my $buf = <$h>;
        if (!$buf) {
          $s->remove($h);
        } else {
          if (my ($destination) = ($buf =~ /started\t(.*)/)) {
            my $remote_destination = $self->canonpath($self->get_remote_url_prefix . "/" . $destination);
            log_error "Started transferring " . $datum_obj->get_value() . " to $remote_destination.", "notice", ">";
            $s->remove($sout);
          }
          if (($failed) = ($buf =~ /failed\t(.*)/)) {
            log_error "Failed to transfer " . $datum_obj->get_value() . " to " . $self->get_transfer_host . ": " . $failed . ". Fetching locally.", "warning";
            $s->remove($sout);
            $this_success = 0;
          }
        }
      }
    }
  }

  my ($done, $destination, $destination_size, $log);
  if ($this_success) {

    # Wait for transfer to complete
    $cmd = $self->get_transfer_cmd . " check";
    while (1) {
      my @args =("-o", "User=" . $remote_user{ident $self}, "-o", "PasswordAuthentication=no", "-o", "IdentityFile=" . $identity_file{ident $self});
      open3(my $sin, my $sout, my $serr, $ssh, @args, $self->get_transfer_host, $cmd);
      print $sin $url . "\n";
      print $sin $command_id . "\n";
      print $sin $self->get_project_id() . "\n";
      my $s = new IO::Select($sout);
      my $response = "";
      while (scalar($s->handles()) > 0) {
        my @ready = $s->can_read(1);
        foreach my $h (@ready) {
          my $buf = <$h>;
          if (!$buf) {
            $s->remove($h);
          } else {
            $response .= $buf;
          }
        }
      }
      ($done, $failed, $destination, $destination_size, $log) = parse_response($response);
      if ($done) {
        # Either success or failure
        last;
      } else {
        # Anything interesting here?
        log_error "Fetched $destination_size bytes.", "notice";
      }
      sleep 5;
    }

    if ($done == 1) {
      if (!$failed) {
        $destination = $self->canonpath($self->get_remote_url_prefix . "/" . $destination);
        log_error "Successfully transferred $destination_size bytes from " . $datum_obj->get_value() . " to $destination.", "notice", "<";
      } else {
        log_error "Failed to transfer file: $failed.", "warning", "<";
        log_error "Log:", "warning", ">";
        for my $line (split(/\n/, $log)) {
          log_error $line, "warning";
        }
        log_error "Will try to fetch locally.", "warning", "<";
        $this_success = 0;
      }
    } elsif ($done == -1) {
      log_error "Lost connection to " . $self->get_transfer_host . ". Please try your validation again or contact help\@modencode.org.", "error";
      $success = 0;
      last;
    }
  }
  return ($this_success, $success, $done, $failed, $destination, $destination_size, $log);
}

sub get_local_url {
  my ($self, $destination) = @_;
  $destination = $self->canonpath($self->get_project_id() . "/extracted/" . $destination);

  my $project_id = $self->get_project_id();
  # Tricky workaround to get the actual project path & number
  $destination =~ s/^.*\/($project_id\/extracted\/.*)/\1/;
  if (scalar(split(/\//, $destination)) > 3) {
    # Not running against a real path; shall we fake it?
    log_error "Detected validator not running in a directory like ###/extracted/; can't transfer to " . $self->get_transfer_host . " from here.", "warning";
  }
  $destination = $self->canonpath($self->get_local_web_prefix() . "/" . $destination);
  return $destination;
}

sub get_project_id {
  my ($self) = @_;
  my ($project_id) = ($ARGV[0] =~ m/^.*\/(\d+)\/extracted\/.*/);
  return $project_id;
}

sub canonpath {
  my ($self, $path) = @_;
  # Remove any double slashes that don't follow a colon
  $path =~ s/(?<!:)\/\/+/\//g;
  return $path;
}

1;


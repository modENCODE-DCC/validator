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
require Date::Format;

my %cached_fastq_files  :ATTR( :default<{}> );
my %seen_data           :ATTR( :default<{}> );
my %transfer_host       :ATTR( :name<transfer_host>,     :default<"74.114.99.142"> );
my %remote_url_prefix   :ATTR( :name<remote_url_prefix>, :default<"http://submit.modencode.org/submit/public/get_file/"> );
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

  log_error "Transferring large files to local drive.", "notice", ">"; 
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
    my $destination ;
    if ($datum_obj->get_value() =~ m|://|) {
      # Local fetch by default
      my $url = $datum_obj->get_value();
      $destination = File::Basename::basename($url);
      my $uniqid = ($seen_url_filenames{ident $self}->{$destination} ||= 0);
      if ($uniqid) { $destination = $uniqid . "_" . $destination; }
      # Download it to the correct path
      my $destination_dir = $self->get_local_fastq_path() ; 
      # Make the dir if it doesn't exist
      unless (-d $destination_dir){
        mkdir $destination_dir ;
      }
      my $destination_path = $destination_dir . $destination ;
      if (-r $destination_path) {
        log_error "$destination_path found locally...overwriting...", "notice";
      }
      my $ua = LWP::UserAgent->new();
      my $res = $ua->mirror($url, $destination_path);
      if ($res->is_success) {
        log_error "Done.", "notice", "<";
      } elsif ($res->is_error) {
        my $error_msg = $res->status_line;
        log_error ("Error retrieving Result File [" . $datum_obj->get_name() . "] from " . $datum_obj->get_value(), "error");
        log_error ("HTTP Response for $destination_path was:  " . $error_msg , "error", "<");
        $success = 0;
        last;
      }
            log_error "Done.", "notice", "<";
    } else {
      # It's already a local file
      if ($datum_obj->get_value =~ /TMPID/) {
        log_error "Creating temporary object identifier " . $datum_obj->get_value, "notice";
      } elsif (!-r $datum_obj->get_value) {
        log_error "Couldn't find file " . $datum_obj->get_value . "!", "error", "<";
        $success = 0;
        last;
      }
      next;
    }
    $seen_url_filenames{ident $self}->{$destination}++;

    my $local_url = $self->get_local_url($destination) ; 
    
    # Update datum to include a pointer to the remote URL
    my $current_time = time();
    my $current_date = Date::Format::time2str("%Y-%m-%d", $current_time, 'GMT');
    $datum_obj->add_attribute(new ModENCODE::Chado::DatumAttribute({
          'value' => $local_url,
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

# Returns path to the folder that you should put documents in.
# If there is at least one /extracted/ in the path, it is a "fastq" folder
# at the same level as the highest extracted ; otherwise it is a "fastq"
# folder inside the lowest folder.
# DOES NOT APPEND DESTINATION ON
sub get_local_fastq_path {
  # $ARGV[0] is expected to be the path to the IDF.
  my ($self) = @_;
  my $idf_path = $ARGV[0] ;
  my $fastq_path ;
  if ($idf_path =~ m/extracted\//){
    ($fastq_path = $idf_path) =~ s/extracted\/.*//;
    $fastq_path .= "fastq/" ;
  } else {
    ($fastq_path) = ($idf_path =~ m/^(.*\/)/ );
    $fastq_path .= "fastq/" ;
  }
  my $result =$self->canonpath( $fastq_path);
  return $result ;
}

# Returns path to where thing can be downloaded from submit site.
# complains if idf doesn't contain a project id / extracted to
# figure it out from.
sub get_local_url {
  my ($self, $destination) = @_;
  $destination = $self->canonpath($self->get_project_id() . "/fastq/" . $destination);

  my $project_id = $self->get_project_id();
  # Tricky workaround to get the actual project path & number
  $destination =~ s/^.*\/($project_id\/fastq\/.*)/\1/;
  if (scalar(split(/\//, $destination)) > 3) {
    # Not running against a real path; shall we fake it?
    log_error "Detected validator not running in a directory like ###/extracted/; can't transfer to " . $self->get_transfer_host . " from here.", "warning";
  }
  $destination = $self->canonpath($self->get_local_web_prefix() . "/" . $destination);
  #log_error "TODO remove: returning local url>$destination<" ;
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


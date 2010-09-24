package ModENCODE::Validator::Data::Result_File;
=pod

=head1 NAME

ModENCODE::Validator::Data::Result_File - Class for verifying the existence of
result files referenced in  BIR-TAB data column objects.

=head1 SYNOPSIS

This class is meant to be used to verify the existence of the files referenced
(by path) when given L<ModENCODE::Chado::Data> objects with values that are
paths to result files. 

=head1 USAGE

A BIR-TAB data column should be run through this validator if it contains the
path to a result file. This is implemented in practice by a special case in
L<ModENCODE::Validator::Data> that checks any data column with a heading of
"Result File"  using this validtor.

If the given path is a http/ftp URL, then the file is fetched from the 
remote site into the local directory.  If an error occurs during data transfer,
then the error is reported to the user and the file check will not pass.
The datum object is modified so that the "name" of the file, which previously
was the URL, is now replaced with the local filename (simply the filename 
given at the end of the URL).

Once downloaded, or with files that were not specified with a url, there is
a basic check to see if the file specified exists at the indicated relative
path.  

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'relative/path/to/file'
  });
  my $applied_protocol = new ModENCODE::Chado::AppliedProtocol({
    'input_data' => [ $datum ],
  });
  my $validator = new ModENCODE::Validator::Data::Result_File();
  $validator->add_datum($datum, $applied_protocol);
  if ($validator->validate()) {
    my $new_datum = $validator->merge($datum); # Actually does nothing for now
    print $new_datum->get_value() . " is an existing file.\n";
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Data>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> have values that point to existing files.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>,
returns that same datum with no changes. This should eventually do something;
see L</TODO>.

=back

=head1 TODO

This class should eventually do something to ensure that the uploaded file is
either pushed into the L<Experiment|ModENCODE::Chado::Experiment> object or
saved somewhere outside of the submission path.

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<ModENCODE::Chado::CVTerm>,
L<ModENCODE::Validator::Data::GFF3>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::CEL>,
L<ModENCODE::Validator::Data::SO_transcript>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::dbEST_acc>,
L<ModENCODE::Validator::Data::dbEST_acc_list>,

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use HTTP::Request::Common 'GET';
use LWP::UserAgent;
use ModENCODE::ErrorHandler qw(log_error);

my %seen_filenames      :ATTR( :default<{}> );
my %seen_url_filenames  :ATTR( :default<{}> );
my %seen_data           :ATTR( :default<{}> );       

sub validate {
  my ($self) = @_;
  my $success = 1;
  my $path = "";

  log_error ("Validating existence of Result File(s)", "notice", ">");
  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;

    my $filename = $datum->get_object->get_value;
    if (!length($filename)) {
      log_error "No entry for " . $datum->get_object->get_heading . " [" . $datum->get_object->get_name . "].", 'warning';
      next;
    }

    next if $seen_data{$datum->get_id}++; # Don't re-update the same datum
    if ($seen_filenames{ident $self}->{$filename}) {
      # A different datum, but the same filename (different column)
      log_error "Referring to the same file in two different data columns! (Duplicating data...)", "warning";
      #$success = 0;
      next;
    }

    my $datum_obj = $datum->get_object;

    if ($datum_obj->get_value() =~ m'(http|ftp|rsync)s?://') {
      # If this datum's value is a URL, pull it down and replace the current
      # datum with a pointer to the local file
      my $ua = LWP::UserAgent->new();

      my $url = $datum_obj->get_value();
      # For FASTQ, just check if it exists, but don't fetch
      # Happily enough, LWP::UserAgent supports faking a HEAD request for FTP URLs.
      if (
        $datum_obj->get_type(1)->get_name() eq "FASTQ"
        || $datum_obj->get_type(1)->get_name() eq "SFF"
      ) {
        my $req = HTTP::Request->new('HEAD', $url);
        my $res = $ua->request($req);
        log_error("Checking to see if " . $datum_obj->get_type(1)->get_name() . " file at $url exists.", "notice", ">");
        if ($res->is_success) {
          log_error("Yes, delaying fetch.", "notice");
        } else {
          log_error("No, can't find file at URL $url using HTTP HEAD request!", "error");
          $success = 0;
        }
        log_error("Done.", "notice", "<");
        next;
      }

      my @filename = split(/\//, $url);
      my $f_length = @filename;
      $filename = @filename[$f_length-1];
      # Watch out for different URLs with the same filename component
      my $unique_filename = $filename;
      my $uniqid = 1;
      while ($seen_url_filenames{ident $self}->{$unique_filename}) {
        $unique_filename = $uniqid . "_" . $filename;
        $uniqid++;
      }
      $filename = $unique_filename;
      $seen_url_filenames{ident $self}->{$filename} = 1;

      log_error ("URL ($url) found for Result File [" . $datum_obj->get_name() . "]; saving as " . $filename . ".", "notice", ">");

      # Tag the datum with the date of download
      my @attributes = $datum_obj->get_attributes;
      my $current_time = time();
      my $current_date = Date::Format::time2str("%Y-%m-%d", $current_time, 'GMT');
      push @attributes, new ModENCODE::Chado::DatumAttribute({
          'value' => $url,
          'type' => new ModENCODE::Chado::CVTerm({'name' => 'anyURI', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
          'name' => 'URL',
          'heading' => 'File Download URL',
          'datum' => $datum,
        });
      push @attributes, new ModENCODE::Chado::DatumAttribute({
          'value' => $current_date,
          'type' => new ModENCODE::Chado::CVTerm({'name' => 'date', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
          'name' => 'Date',
          'heading' => 'File Download Date',
          'datum' => $datum,
        });
      my $new_datum = new ModENCODE::Chado::Data({
          'heading' => $datum_obj->get_heading,
          'name' => $datum_obj->get_name,
          'value' => $filename,
          'termsource' => $datum_obj->get_termsource,
          'type' => $datum_obj->get_type,
          'attributes' => \@attributes,
          'features' => $datum_obj->get_features || undef,
          'wiggle_datas' => $datum_obj->get_wiggle_datas || undef,
          'organisms' => $datum_obj->get_organisms || undef,
        });

      # Need to replace a datum everywhere it occurs. The easiest way to do this is by 
      # replacing it in the CachedObject we got it from.
      ModENCODE::Cache::update_datum($datum->get_object, $new_datum->get_object);

      #open a connection, grab the file, and stick it in a local file.  we are already in the local directory,
      #so it should put it in the right place.      
      my $fetch_success = 0;
      my $error_msg = "Stick in the GET reply here.";

      log_error ("Fetching remote file from $url...", "notice");

      if (-r $filename) {
        log_error("$filename found locally...overwriting...", "notice");
      }

      my $res = $ua->mirror($url, $filename);
      if ($res->is_success) {
        my $filesize = -s $filename;
        #set the datum to have the local filename
        log_error ("Retrieved " . $filesize . " bytes from remote site.","notice");
      } elsif ($res->is_error) {
        #not okay.  report the error
        $error_msg = $res->status_line;
        log_error ("Error retrieving Result File [" . $datum_obj->get_name() . "] from " . $datum_obj->get_value(), "error");
        log_error ("HTTP Response for $filename was:  " . $error_msg , "error", "<");
        $success = 0;
        next;
      }

      $seen_filenames{ident $self}->{$url} = $filename;
      log_error "Done.", "notice", "<";
    } else {
      # Already a local file, just make sure it exists
      $seen_filenames{ident $self}->{$filename} = $filename;
    }

    if (!-r $filename) {
      log_error "Can't find Result File [" . $datum_obj->get_name() . "]=" . $filename . ".", "error";
      $success = 0;
    } else {
      log_error "Found Result File: " . $filename , "notice";
    }
  }
  log_error ("Done.","notice","<");
  return $success;
}

1;

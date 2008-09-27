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
#use ModENCODE::Chado::Attribute;
#use ModENCODE::Chado::Data;
use ModENCODE::ErrorHandler qw(log_error);

my %cached_files            :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  my $success = 1;
  my $path = "";
  log_error ("Validating specified file(s) existence", "notice", ">");
  foreach my $datum_hash (@{$self->get_data()}) {
      my $datum_success = 1;
      my $datum = $datum_hash->{'datum'}->clone();
      if (length($datum->get_value())) {
	  my $filename = $datum->get_value();
	  if (!($cached_files{ident $self}->{$filename})) {
	      if ($datum->get_value() =~ m'(http|ftp)s?://') {
		  #if there's a URL specified, try to fetch it.
		  my $url = $datum->get_value();
		  my @filename = split(/\//, $url);
		  my $f_length = @filename;
		  $filename = @filename[$f_length-1];
		  
		  log_error ("URL found for Result File [" . $datum->get_name() . "] = " . $filename , "notice", ">");
		  
		  #open a connection, grab the file, and stick it in a local file.  we are already in the local directory,
		  #so it should put it in the right place.      
		  my $fetch_success = 0;
		  my $error_msg = "Stick in the GET reply here.";
		  my $req = HTTP::Request->new('GET', $datum->get_value());
		  my $ua = LWP::UserAgent->new();
		  log_error ("Fetching remote file from $url...", "notice");
		  if (-r $filename) {
		      log_error("$filename found locally...overwriting...", "notice");
		  }
		  my $res = $ua->request($req,$filename);
		  if ($res->is_success) {
		      my $filesize = -s $filename;
		      #set the datum to have the local filename
		      $datum->set_value($filename);
		      log_error ("Retrieved " . $filesize . " bytes from remote site.","notice");
		  } elsif ($res->is_error) {	
		      #not okay.  report the error
		      $error_msg = $res->status_line;
		      log_error ("Error retrieving Result File [" . $datum->get_name() . "] from " . $datum->get_value(), "error");
		      log_error ("HTTP Response for $filename was:  " . $error_msg , "error");
		      $datum_success = 0;
		      $success = 0;
		  }
		  $cached_files{ident $self}->{$url} = $filename;
		  log_error ("","notice","<");
	      } else {
		  $cached_files{ident $self}->{$filename} = $filename;
	      }
	      if (!-r $filename) {
		  log_error "Can't find Result File [" . $datum->get_name() . "]=" . $datum->get_value() . ".", "error";
		  $datum_success = 0;
		  $success = 0;
	      } else {
		  log_error "File found: " . $filename , "notice";
	      }
	  } else { #its cached
	      if ($filename =~ m'(http|ftp)s?://') {
		  #if we're here, there's a URL specified, and the file should have already been processed.
		  #we want to replace the url with the local filename.
		  my $url = $datum->get_value();
		  my @filename = split(/\//, $url);
		  my $f_length = @filename;
		  $filename = @filename[$f_length-1];
		  if (-r $filename) {
		      $datum->set_value($filename);
		  } else {
		  log_error "Can't find Result File [" . $datum->get_name() . "]=" . $datum->get_value() . ".", "error";
		  $datum_success = 0;
		  $success = 0;
		  }
	      }
	      #log_error ("Already come across this file. Will only process $filename once.", "notice");
	  }   
      } else {
	  log_error "No File for " . $datum->get_heading(), 'warning';
	  $datum_success = 1;
	  next;
      }
      
      $datum_hash->{'is_valid'} = $datum_success;
      $datum_hash->{'merged_datum'} = $datum;
  }
  log_error ("Done.","notice","<");
  return $success;
}

sub merge {
    my ($self, $datum, $applied_protocol) = @_;
    return $datum;
}

1;

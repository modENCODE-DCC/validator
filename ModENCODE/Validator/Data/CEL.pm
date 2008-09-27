package ModENCODE::Validator::Data::CEL;
=pod

=head1 NAME

ModENCODE::Validator::Data::CEL - NEARLY THERE - Class for doing some
basic checks for existence of CEL files referenced in  BIR-TAB data 
column objects.

=head1 SYNOPSIS

This class is meant to be used to verify if specified CEL files are included
at the specified path.  This differs from the L<ModENCODE::Validator::Data::Result_File>
validator in that if a URL is specified, then it expects the files to be
already downloaded to the local directory.  If a URL was specified, then 
some additional attributes will be added to the data object using 
L<ModENCODE::Chado::Data::add_attribute>; specifically
the URL that the data file was retrieved from will be specified, as well as the 
current date in YYYY-MM-DD format specified as the Download data.  
Because the contents of the CEL files are not added to the chado database, the
file is not parsed or verified in any other way.  Only the filename is needed
for later retrieval or linkage.

=head1 TODO

The contents of this class should actually be for a more generic "raw array" CV type, for 
which CEL, pair, and others, would default to.

=head 1 SEE ALSO
L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::Data::Attribute>

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use base qw(ModENCODE::Validator::Data::Data);
use ModENCODE::Chado::Wiggle_Data;
use ModENCODE::ErrorHandler qw(log_error);

my %cached_cel_files            :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  log_error "Validating attached CEL file(s).", "notice", ">";
  my $success = 1;
  my $last_file = "";
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum_success = 1;
    my $wig_type = "none";
    my $datum = $datum_hash->{'datum'}->clone();
    my $filename = $datum->get_value();
    my $url = '';
    if (length($filename)) {
	if ($filename =~ m'(http|ftp)s?://') {
	    #if its a URL, then it should have been downloaded locally
	    #using the Result_File validator
	    #use the local filename.
	    $url = $filename;
	    my @filename = split(/\//, $url);
	    my $f_length = @filename;
	    $filename = @filename[$f_length-1];
	    my $url_attr = new ModENCODE::Chado::Attribute({
		'value' => $url,
		'type' => new ModENCODE::Chado::CVTerm({'name' => 'anyURI', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
		'name' => 'URL',
		'heading' => 'File Download URL'});
	    my $current_time = time();
	    my $current_date = Date::Format::time2str("%Y-%m-%d", $current_time, 'GMT');
	    my $download_date_attr = new ModENCODE::Chado::Attribute({
		'value' => $current_date,
		'type' => new ModENCODE::Chado::CVTerm({'name' => 'date', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
		'name' => 'Date',
		'heading' => 'File Download Date'});
	    $datum->add_attribute($url_attr);
	    $datum->add_attribute($download_date_attr);
	}
	if ($cached_cel_files{ident $self}->{$datum->get_value()}) {
#	    log_error ("Already come across this file. Will only process once.", "notice");
	} else {
	    if (!-r $filename) {
		log_error "Cannot find CEL file " . $datum->get_value() . " for column " . $datum->get_heading();
		$datum_success = 0;
		$success = 0;
	    } else {
		$datum->set_value($filename);
		log_error ("Your specified file " . $datum->get_value() . " exists, but we won't check it.", "notice");
		$cached_cel_files{ident $self}->{$datum->get_value()} = $datum->get_value();
	    }
	}
    } else {
      log_error "No CEL file for " . $datum->get_heading(), 'warning';
      $datum_success = 1;
      next;
    }
    $datum_hash->{'is_valid'} = $datum_success;
    $datum_hash->{'merged_datum'} = $datum;
  }
  log_error "Done.", "notice", "<";
  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;

  return $self->get_datum($datum, $applied_protocol)->{'merged_datum'};
}

1;

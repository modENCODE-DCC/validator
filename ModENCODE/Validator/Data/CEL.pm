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
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Validator::Data::Result_File;

sub validate {
  my ($self) = @_;
  log_error "Validating attached CEL file(s).", "notice", ">";
  # Re-use the Result File validator to make sure these exist as files
  # even if they were mistakenly(?) put in a Result Value column instead of 
  # a Result File one

  my $file_validator = new ModENCODE::Validator::Data::Result_File({ 'experiment' => $self->get_experiment });
  while (my $ap_datum = $self->next_datum) {
    $file_validator->add_datum_pair($ap_datum);
  }
  return $file_validator->validate();
}

1;

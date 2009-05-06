package ModENCODE::Validator::Attributes;
=pod

=head1 NAME

ModENCODE::Validator::Attributes - Delegator used to apply validators to BIR-TAB
attribute columns.

=head1 SYNOPSIS

This class is designed to be run on an
L<Experiment|ModENCODE::Chado::Experiment> object. It will then call any of the
validators defined in the L<Class::Std> L<BUILD|/new(\%args)> method on the appropriate
attribute columns. To add new third-party attribute validators, you should
extend this class and just overried the C<BUILD> method to attach the
additional attribute validators.

=head1 USAGE

=head2 Extending for Other Modules

The L<constructor|/new(\%args)> sets the contents of the C<%validators{ident $self}>
hash. The keys of the hash are I<either> the BIR-TAB Term Source type (e.g.
C<URL_mediawiki>) or the L<CVTerm|ModENCODE::Chado::CVTerm> type of the
attribute column (e.g.  C<SO:transcript>). The value of the hash is the
validator that should be run on any columns with that Term Source or type. For
instance:

  $validators{$ident}->{'URL_mediawiki_expansion'} = new ModENCODE::Validator::Attributes::URL_mediawiki_expansion();

The above line specifies that the
L<ModENCODE::Validator::Attributes::URL_mediawiki_expansion> validator should be
used on any attribute column that is followed by a C<Term Source REF> column
containing a reference to a term source of type C<URL_mediawiki_expansion>. Each
value in the attribute column will be added to the validator using its
L<add_attribute|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
method. The syntax for validating based on the attribute type is very similar,
just replace the Term Source name (C<URL_mediawiki_expansion>) with a
colon-delimited controlled vocabulary and term, like so:

  $validators{$ident}->{'SO:transcript'} = new ModENCODE::Validator::Attributes::Transcript();

=head2 Running

  my $attribute_validator = new ModENCODE::Validator::Attributes();
  my $success = $attribute_validator->validate($experiment);
  if ($success) {
    $experiment = $attribute_validator->merge($experiment);
  }

Once a ModENCODE::Validator::Attributes object (or extending subclass) has been
created, you can validate the attribute columns associated with all L<applied
protocols|ModENCODE::Chado::AppliedProtocol> in an
L<Experiment|ModENCODE::Chado::Experiment> object by using the
</validate($experiment)> method and then merge in any changes made by the
validators using L</merge($experiment)>.

=head1 FUNCTIONS

=over

=item new(\%args)

Constructor called on any objects created by L<Class::Std> defined in the
C<BUILD> method. See the documentation for L<Class::Std/BUILD()> for more
information on when this method is called. In this class, it is used to define
which attribute validators should be used for which columns. (See L<Extending
for Other Modules|/Extending for Other Modules>.) Note that every C<BUILD>
method in the class hierarchy will be called, so if you don't want to use the
default validators in a subclass, you'll want to clean out the
C<%validators{ident $self}> hash.

=item validate($experiment)

Collects all of the attribute columns associated with any L<applied
protocols|ModENCODE::Chado::AppliedProtocol> or L<data|ModENCODE::Chado::Data>
in the L<Experiment|ModENCODE::Chado::Experiment> object in C<$experiment>. For
each L<ModENCODE::Chado::Attribute> found, it calls the
L<add_attribute|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
method of any validator defined in the C<%validators{ident $self}> hash for the
attribute's type or Term Source type. Once all attributes have been apportioned
to their appropriate validator(s), the
L<validate()|ModENCODE::Validator::Attributes::Attributes/validate()>
method of each validator is called. If all of the C<validate> calls return true,
then this C<validate($experiment)> call returns 1, otherwise it returns 0.

For any attribute with no validator associated for either the term source type
or attribute type, a warning is printed and the attribute is left untouched,
assumed to be a free text field.

=item merge($experiment)

Collects all of the attribute columns associated with any L<applied
protocols|ModENCODE::Chado::AppliedProtocol> or L<data|ModENCODE::Chado::Data>
in the L<Experiment|ModENCODE::Chado::Experiment> object in C<$experiment>. For
each L<ModENCODE::Chado::Attribute> found, it calls the
L<add_attribute|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
method of any validator defined in the C<%validators{ident $self}> hash for the
attribute's type or Term Source type. Once all attributes have been apportioned
to their appropriate mergers(s), the
L<merge()|ModENCODE::Validator::Attributes::Attributes/merge()> method of each
validator is called. The C<merge> method of each validator should return an
arrayref of L<attributes|ModENCODE::Chado::Attribute> containing the
C<$attribute>, with any changes made, plus any new attributes that are being
added. The attribute object in the C<$experiment> is then replaced with with
updated attributes.

For any attribute with no validator associated for either the term source type
or attribute type, a warning is printed and the attribute is left untouched,
assumed to be a free text field.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Validator::Attributes::Attributes>,
L<ModENCODE::Validator::Attributes::Organism>,
L<ModENCODE::Validator::Attributes::URL_mediawiki_expansion>,
L<ModENCODE::Chado::Attribute>, L<ModENCODE::Chado::DBXref>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Experiment>,
L<ModENCODE::Chado::AppliedProtocol>, L<ModENCODE::Validator::Data>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use ModENCODE::Validator::Attributes::URL_mediawiki_expansion;
use ModENCODE::Validator::Attributes::Organism;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

use constant DEBUG => 1;

my %termsource_validators       :ATTR( :default<{}> );
my %type_validators             :ATTR( :default<{}> );
my %experiment                  :ATTR( :name<experiment> );

sub START {
  my ($self, $ident, $args) = @_;
  $termsource_validators{$ident}->{'URL_mediawiki_expansion'} = new ModENCODE::Validator::Attributes::URL_mediawiki_expansion();
  $type_validators{$ident}->{'organism'} = new ModENCODE::Validator::Attributes::Organism();
}

sub validate {
  my $self = shift;
  my $success = 1;
  my $experiment = $self->get_experiment;

  my @all_attributes = (
    (map { $_->get_object->get_attributes } ModENCODE::Cache::get_all_objects('protocol')),
    (map { $_->get_object->get_attributes } ModENCODE::Cache::get_all_objects('data')),
  );


  foreach my $attribute_cacheobj (@all_attributes) {

    my $attribute = $attribute_cacheobj->get_object;
    # For any attribute with a termsource for which there exists a validator module
    my $attribute_termsource_type;
    if ($attribute->get_termsource() && $attribute->get_termsource(1)->get_db()) {
      $attribute_termsource_type = $attribute->get_termsource(1)->get_db(1)->get_description();
      my $validator = $termsource_validators{ident $self}->{$attribute_termsource_type};
      if (!$validator) {
        log_error "No validator for attribute " . $attribute->get_heading() . " [" . $attribute->get_name() . "] with term source type $attribute_termsource_type.", "warning";
        next;
      }
      log_error "Adding attribute " . $attribute->get_heading . " [" . $attribute->get_name . "] to validator " . ref($validator) . " because of term source.", "debug";
      $validator->add_attribute($attribute_cacheobj);
    }

    # Throw a warning if a field looks like a wiki URL but doesn't have an appropriate termsource
    if ($attribute->get_value =~ /oldid=/ && $attribute_termsource_type ne 'URL_mediawiki_expansion') {
      log_error "It looks like you meant to provide a reference to a wiki URL " . $attribute->get_value . " in the " . 
      $attribute->get_heading . " [" . $attribute->get_name . "] field in the SDRF, but it doesn't have a Term Source REF " .
      "of type URL_mediawiki_expansion!", "warning";
    }

    # For any attribute with a type for which there exists a validator module
    if ($attribute->get_type() && $attribute->get_type(1)->get_cv()) {
      my $attribute_type_source = $attribute->get_type(1)->get_cv(1)->get_name();
      my $validator = $type_validators{ident $self}->{$attribute_type_source};
      if (!$validator) {
        log_error "No validator for attribute of type $attribute_type_source.", "warning";
        next;
      }
      log_error "Adding attribute " . $attribute->get_heading . " [" . $attribute->get_name . "] to validator " . ref($validator) . " because of type.", "debug";
      $validator->add_attribute($attribute_cacheobj);
    }
  }

  # For any attribute with a type where there exists a validator module
  foreach my $validator (values(%{$termsource_validators{ident $self}}), values(%{$type_validators{ident $self}})) {
    if (!$validator->validate()) {
      return 0;
    }
  }
  return 1;
}

1;


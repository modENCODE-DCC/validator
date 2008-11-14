package ModENCODE::Validator::Attributes::Organism;
=pod

=head1 NAME

ModENCODE::Validator::Attributes::Organism - Class for converting BIR-TAB
attribute columns containing organism names into L<ModENCODE::Chado::Organism>
objects. This class is a subclass of the abstract
L<ModENCODE::Validator::Attributes::Attributes>.

=head1 SYNOPSIS

This class actually does very little in the way of validation - its purpose is
simple to convert strings ("Drosophila melanogaster") into
L<ModENCODE::Chado::Organism> objects by splitting on whitespace. Given an
L<Attribute|ModENCODE::Chado::Attribute> with a
L<value|ModENCODE::Chado::Attribute/get_value() | set_value($value)> containing
an organism, it will create a "merged" attribute with a type of
"CARO:multi-cellular organism" and an associated Chado
L<Organism|ModENCODE::Chado::Organism>.

  my $attribute = new ModENCODE::Chado::Attribute({
    'value' => 'Drosophila melanogaster'
  });
  my $validator = ModENCODE::Validator::Attributes::Organism();
  $validator->add_attribute($attribute);
  if ($validator->validate()) {
    my ($attribute) = @{$validator->merge($attribute)};
    print $attribute->get_organisms()->[0]->get_genus() . "\n";
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Attributes>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the attributes added using
L<add_attribute($attribute)|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
have values that match the regular expression C</\S+\s+\S+/> so that they can be
split into a putative genus and species.

=item merge($attribute)

Given an original L<attribute|ModENCODE::Chado::Attribute> C<$attribute>,
returns an arrayref containing a copy of that attribute with an
L<Organism|ModENCODE::Chado::Organism> object added and the type of the
attribute changed to a L<CVTerm|ModENCODE::Chado::CVTerm> for
"CARO:multi-cellular organism".

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Attribute>,
L<ModENCODE::Validator::Attributes>,
L<ModENCODE::Validator::Attributes::Attributes>, L<ModENCODE::Chado::CVTerm>,
L<ModENCODE::Chado::Organism>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Attributes::Attributes );
use Class::Std;
use Carp qw(croak carp);

use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::DB;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Organism;
use ModENCODE::ErrorHandler qw(log_error);
use Data::Dumper;

sub validate {
  my ($self) = @_;
  my $success = 1;

  log_error "Validating attributes of type organism.", "notice", ">";
  my %organisms;
  foreach my $attribute_hash (@{$self->get_attributes()}) {
    my $attribute = $attribute_hash->{'attribute'}->clone();

    if (!$organisms{$attribute->get_value()}) {
      my ($genus, $species) = ($attribute->get_value() =~ m/^(\S+)\s+(.+)$/);
      if (length($genus) && length($species)) {
        my $organism = new ModENCODE::Chado::Organism({
            'genus' => $genus,
            'species' => $species,
          });
        $attribute->add_organism($organism);
        $organisms{$attribute->get_value()} = [ $attribute ];
        $attribute->set_type(new ModENCODE::Chado::CVTerm({
              'name' => 'multi-cellular organism',
              'cv' => new ModENCODE::Chado::CV({ 'name' => 'CARO' }),
              'dbxref' => new ModENCODE::Chado::DBXref({
                  'db' => new ModENCODE::Chado::DB({'name' => 'CARO'}),
                  'accession' => 'multi-cellular organism',
                }),
            }));
      } elsif (length($attribute->get_value())) {
        log_error "Couldn't parse organism genus and species out of " . $attribute->get_heading . " [" . $attribute->get_name() . "]=" . $attribute->get_value() . ".";
        $success = 0;
      }
    }
    if ($organisms{$attribute->get_value()}) {
      $attribute_hash->{'merged_attributes'} = $organisms{$attribute->get_value()};
    }
  }
  log_error "Done.", "notice", "<";
  return $success;
}

sub merge {
  my ($self, $datum) = @_;

  my ($validated_entry) = grep { $_->{'attribute'}->equals($datum); } @{$self->get_attributes()};

  return $validated_entry->{'merged_attributes'};
}

1;

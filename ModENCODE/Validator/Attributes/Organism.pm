package ModENCODE::Validator::Attributes::Organism;
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

sub validate {
  my ($self) = @_;
  my $success = 1;

  log_error "Validating attributes of type organism.", "notice", ">";
  my %organisms;
  foreach my $attribute_hash (@{$self->get_attributes()}) {
    my $attribute = $attribute_hash->{'attribute'}->clone();
    if (!$organisms{$attribute->get_value()}) {
      my ($genus, $species) = ($attribute->get_value() =~ m/^(\S+)\s*(.*)$/);
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
}

sub merge {
  my ($self, $datum) = @_;

  my ($validated_entry) = grep { $_->{'attribute'}->equals($datum); } @{$self->get_attributes()};

  return $validated_entry->{'merged_attributes'};
}

1;

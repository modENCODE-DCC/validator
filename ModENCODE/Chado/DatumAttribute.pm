package ModENCODE::Chado::DatumAttribute;

use base ModENCODE::Chado::Attribute;
use Class::Std;

my %datum         :ATTR( :set<datum>,            :init_arg<datum> );

sub new {
  my $temp = Class::Std::new(@_);
  my $cached_attribute = ModENCODE::Cache::get_cached_datum_attribute($temp);

  if ($cached_attribute) {
    # Update any cached attribute
    my $need_save = 0;
    if ($temp->get_value() && !($cached_attribute->get_object->get_value())) {
      $cached_attribute->get_object->set_value($temp->get_value);
      $need_save = 1;
    }
    if ($temp->get_termsource() && !($cached_attribute->get_object->get_termsource())) {
      $cached_attribute->get_object->set_termsource($temp->get_termsource);
      $need_save = 1;
    }
    if ($temp->get_type() && !($cached_attribute->get_object->get_type())) {
      $cached_attribute->get_object->set_type($temp->get_type);
      $need_save = 1;
    }
    if (@{$temp->get_organisms()} && !(@{$cached_attribute->get_object->get_organisms()})) {
      $cached_attribute->get_object->set_organisms($temp->get_organisms);
      $need_save = 1;
    }
    ModENCODE::Cache::save_attribute($cached_attribute->get_object) if $need_save;
    return $cached_attribute;
  }
  # This is a new attribute
  my $self = $temp;
  return ModENCODE::Cache::add_datum_attribute_to_cache($self);
}

sub get_datum_id {
  my $self = shift;
  return $datum{ident $self} ? $datum{ident $self}->get_id : undef;
}

sub get_datum {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $datum = $datum{ident $self};
  return undef unless defined $datum;
  return $get_cached_object ? $datum{ident $self}->get_object : $datum{ident $self};
}

sub save {
  ModENCODE::Cache::save_datum_attribute(shift);
}

1;


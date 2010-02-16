package ModENCODE::Chado::ProtocolAttribute;

use base ModENCODE::Chado::Attribute;
use Class::Std;

my %protocol         :ATTR( :set<protocol>,            :init_arg<protocol> );

sub new {
  my $temp = Class::Std::new(@_);
  return new ModENCODE::Cache::ProtocolAttribute({'content' => $temp }) if ModENCODE::Cache::get_paused();
  my $cached_attribute = ModENCODE::Cache::get_cached_protocol_attribute($temp);

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
  return ModENCODE::Cache::add_protocol_attribute_to_cache($self);
}

sub get_protocol_id {
  my $self = shift;
  return $protocol{ident $self} ? $protocol{ident $self}->get_id : undef;
}

sub get_protocol {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $protocol = $protocol{ident $self};
  return undef unless defined $protocol;
  return $get_cached_object ? $protocol{ident $self}->get_object : $protocol{ident $self};
}

sub save {
  ModENCODE::Cache::save_protocol_attribute(shift);
}

1;

package ModENCODE::Validator::Attributes;
use strict;
use ModENCODE::Validator::Attributes::URL_mediawiki_expansion;
use ModENCODE::Validator::Attributes::Organism;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %validators                  :ATTR( :default<{}> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  $validators{$ident}->{'URL_mediawiki_expansion'} = new ModENCODE::Validator::Attributes::URL_mediawiki_expansion();
  $validators{$ident}->{'organism'} = new ModENCODE::Validator::Attributes::Organism();
}

sub merge {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  
  # Get attributes for data only; don't expand protocol attributes
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my @protocol_attributes = @{$applied_protocol->get_protocol()->get_attributes()};
      my @new_attributes;
      foreach my $attribute (@{$applied_protocol->get_protocol()->get_attributes()}) {
        if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
          my $attribute_termsource_type = $attribute->get_termsource()->get_db()->get_description();
          my $validator = $validators{ident $self}->{$attribute_termsource_type};
          if ($validator) {
            my $merged_attributes = $validator->merge($attribute);
            croak "Cannot merge attributes columns if they do not validate" unless $merged_attributes;
            push @new_attributes, @$merged_attributes;
          } else {
            # Just keep the original attribute
            push @new_attributes, $attribute;
          }
        } elsif ($attribute->get_type() && $attribute->get_type()->get_cv()) {
          my $attribute_type_source = $attribute->get_type->get_cv()->get_name();
          my $validator = $validators{ident $self}->{$attribute_type_source};
          if ($validator) {
            my $merged_attributes = $validator->merge($attribute);
            croak "Cannot merge attributes columns if they do not validate" unless $merged_attributes;
            push @new_attributes, @$merged_attributes;
          } else {
            # Just keep the original attribute
            push @new_attributes, $attribute;
          }
        }
      }
      $applied_protocol->get_protocol()->set_attributes(\@new_attributes);
      foreach my $datum (@{$applied_protocol->get_output_data()}, @{$applied_protocol->get_input_data()}) {
        # Get a copy of the array of attributes (so we can swap them out)
        my @datum_attributes = @{$datum->get_attributes()};
        my @new_attributes;
        foreach my $attribute (@datum_attributes) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            my $attribute_termsource_type = $attribute->get_termsource()->get_db()->get_description();
            my $validator = $validators{ident $self}->{$attribute_termsource_type};
            if ($validator) {
              my $merged_attributes = $validator->merge($attribute);
              croak "Cannot merge attributes columns if they do not validate" unless $merged_attributes;
              push @new_attributes, @$merged_attributes;
            } else {
              # Just keep the original attribute
              push @new_attributes, $attribute;
            }
          } elsif ($attribute->get_type() && $attribute->get_type()->get_cv()) {
            my $attribute_type_source = $attribute->get_type->get_cv()->get_name();
            my $validator = $validators{ident $self}->{$attribute_type_source};
            if ($validator) {
              my $merged_attributes = $validator->merge($attribute);
              croak "Cannot merge attributes columns if they do not validate" unless $merged_attributes;
              push @new_attributes, @$merged_attributes;
            } else {
              # Just keep the original attribute
              push @new_attributes, $attribute;
            }
          }
        }
        $datum->set_attributes(\@new_attributes);
      }
    }
  }
  return $experiment;
}

sub validate {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  my $success = 1;

  my @unique_attributes;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      foreach my $attribute (@{$applied_protocol->get_protocol()->get_attributes()}) {
        if (!scalar(grep { $attribute == $_ } @unique_attributes)) {
          push @unique_attributes, $attribute;
        }
      }
      foreach my $datum (@{$applied_protocol->get_output_data()}, @{$applied_protocol->get_input_data()}) {
        foreach my $attribute (@{$datum->get_attributes()}) {
          # Actual equality, not ->equals, since we want to validate the attributes
          if (!scalar(grep { $attribute == $_ } @unique_attributes)) {
            push @unique_attributes, $attribute;
          }
        }
      }
    }
  }

  # For any attribute with a termsource of type where there exists a validator module
  foreach my $attribute (@unique_attributes) {
    if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
      my $attribute_termsource_type = $attribute->get_termsource()->get_db()->get_description();
      my $validator = $validators{ident $self}->{$attribute_termsource_type};
      if (!$validator) {
        log_error "No validator for attribute " . $attribute->get_heading() . " [" . $attribute->get_name() . "] with term source type $attribute_termsource_type.", "warning";
        next;
      }
      $validator->add_attribute($attribute);
    }
  }
  # For any attribute with a type where there exists a validator module
  foreach my $attribute (@unique_attributes) {
    if ($attribute->get_type() && $attribute->get_type()->get_cv()) {
      my $attribute_type_source = $attribute->get_type->get_cv()->get_name();
      my $validator = $validators{ident $self}->{$attribute_type_source};
      if (!$validator) {
        log_error "No validator for attribute of type $attribute_type_source.", "warning";
        next;
      }
      $validator->add_attribute($attribute);
    }
  }
  foreach my $validator (values(%{$validators{ident $self}})) {
    if (!$validator->validate()) {
      return 0;
    }
  }
  return 1;
}

1;

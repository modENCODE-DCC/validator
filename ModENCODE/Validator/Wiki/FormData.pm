package ModENCODE::Validator::Wiki::FormData;
use Class::Std;
use Carp qw(croak);
use ModENCODE::Validator::Wiki::FormValues;
use strict;

# Attributes
my %version          :ATTR( :name<version>, :default<0> );
my %name             :ATTR( :name<name>, :default<undef> );

# Relationships
my %values           :ATTR( :get<values>, :default<[]> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $init_values = $args->{'values'};
  $values{ident $self} = [];
  if (defined($init_values)) {
    if (ref($init_values) eq 'ARRAY' || ref($init_values) eq 'ArrayOfFormValues') {
      foreach my $value (@$init_values) {
        if (ref($value) eq 'ModENCODE::Validator::Wiki::FormValues') {
          foreach my $val (@{$value->get_values()}) {
            $self->add_value($value->get_name(), $val);
          }
        } elsif (ref($value) eq 'FormValues') {
          bless($value, 'HASH');
          $value = new ModENCODE::Validator::Wiki::FormValues($value);
          foreach my $val (@{$value->get_values()}) {
            $self->add_value($value->get_name(), $value->get_types(), $val);
          }
        } else {
          croak "Can't add a " . ref($value) . " as a FormValues object";
        }
      }
    } elsif (ref($init_values) eq 'ModENCODE::Validator::Wiki::FormValues') {
      push @{$values{$ident}}, $init_values;
    } elsif (ref($init_values) eq 'HASH') {
      foreach my $valuekey (keys(%$init_values)) {
        foreach my $value (@{$init_values->{$valuekey}}) {
          $self->addValue($valuekey, $value);
        }
      }
    } else {
      croak "Can't figure out how to parse a " . ref($init_values) . " into FormValues object(s)"
    }
  }
}

sub add_value {
  my ($self, $valuekey, $types, $value) = @_;
  my $found = 0;
  foreach my $formvalues (@{$self->get_values()}) {
    if ($formvalues->get_name eq $valuekey) {
      $formvalues->add_value($value);
      foreach my $type (@$types) {
        $formvalues->add_type($type);
      }
      $found = 1;
      last;
    }
  }
  if (!$found) {
    my $newFormValues = new ModENCODE::Validator::Wiki::FormValues({
        'name' => $valuekey,
        'values' => [ $value ],
      });
    foreach my $type (@$types) {
      $newFormValues->add_type($type);
    }
    push @{$values{ident $self}}, $newFormValues;
  }
}

sub to_string {
  my ($self) = @_;
  my $string = "Form: " . $self->get_name() . "." . $self->get_version();
  $string .= "\n  " . join("\n  ", map { $_->to_string() } @{$self->get_values()}) . "\n";
  return $string;
}

1;

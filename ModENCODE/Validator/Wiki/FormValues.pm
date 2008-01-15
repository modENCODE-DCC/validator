package ModENCODE::Validator::Wiki::FormValues;
use Class::Std;
use Carp qw(croak);
use strict;

# Attributes
my %name             :ATTR( :name<name> );
my %type             :ATTR( :name<type>, :default<undef> );
my %values           :ATTR( :get<values>, :default<[]> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $values = $args->{'values'};
  $type{$ident} = $args->{'type'};
  if (defined($values)) {
    if (ref($values) ne 'ARRAY' && ref($values) ne 'ArrayOfStrings') {
      $values = [ $values ];
    }
    foreach my $value (@$values) {
      $self->add_value($value);
    }
  }
}

sub add_value {
  my ($self, $value) = @_;
  push @{$values{ident $self}}, $value;
}

sub to_string {
  my ($self) = @_;
  my $string = $self->get_name();
  $string .= "<" . $self->get_type() . ">";
  $string .= "(" . join(", ", @{$self->get_values()}) . ")";
  return $string;
}

1;

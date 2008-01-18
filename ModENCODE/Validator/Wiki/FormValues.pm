package ModENCODE::Validator::Wiki::FormValues;
use Class::Std;
use Carp qw(croak);
use strict;

# Attributes
my %name             :ATTR( :name<name> );
my %types            :ATTR( :name<types>, :default<[]> );
my %values           :ATTR( :get<values>, :default<[]> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $values = $args->{'values'};
  $types{$ident} = $args->{'types'} if ref($args->{'types'} eq "ARRAY");
  if (defined($values)) {
    if (ref($values) ne 'ARRAY' && ref($values) ne 'ArrayOfStrings') {
      $values = [ $values ];
    }
    foreach my $value (@$values) {
      $self->add_value($value);
    }
  }
}

sub add_type {
  my ($self, $type) = @_;
  if (!scalar(grep { $_ eq $type } @{$types{ident $self}})) {
    push @{$types{ident $self}}, $type;
  }

}
sub add_value {
  my ($self, $value, $type) = @_;
  push @{$values{ident $self}}, $value;
}

sub to_string {
  my ($self) = @_;
  my $string = $self->get_name();
  $string .= "<" . join(", ", @{$self->get_types()}) . ">";
  $string .= "(" . join(", ", @{$self->get_values()}) . ")";
  return $string;
}

1;

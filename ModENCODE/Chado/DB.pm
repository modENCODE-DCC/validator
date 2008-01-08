package ModENCODE::Chado::DB;

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %url              :ATTR( :name<url>,                 :default<undef> );
my %description      :ATTR( :name<description>,         :default<undef> );

sub to_string {
  my ($self) = @_;
  my $string = $self->get_name();
  $string .= "(" if (defined($self->get_url()) || defined($self->get_description()));
  $string .= $self->get_description() . ":" if defined($self->get_description());
  $string .= $self->get_url() if defined($self->get_url());
  $string .= ")" if (defined($self->get_url()) || defined($self->get_description()));
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name());

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::DB({
      'name' => $self->get_name(),
      'url' => $self->get_url(),
      'description' => $self->get_description(),
    });
  return $clone;
}

1;

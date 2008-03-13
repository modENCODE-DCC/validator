package ModENCODE::Chado::FeatureLoc;

use strict;
use Class::Std;
use Carp qw(carp croak);

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %fmin             :ATTR( :name<fmin>,                :default<undef> );
my %fmax             :ATTR( :name<fmax>,                :default<undef> );
my %rank             :ATTR( :name<rank>,                :default<undef> );
my %strand           :ATTR( :name<strand>,              :default<undef> );

# Relationships
my %srcfeature       :ATTR( :get<srcfeature>,           :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $srcfeature = $args->{'srcfeature'};
  if (defined($srcfeature)) {
    $self->set_srcfeature($srcfeature);
  }
}

sub set_srcfeature {
  my ($self, $srcfeature) = @_;
  ($srcfeature->isa('ModENCODE::Chado::Feature')) or Carp::confess("Can't add a " . ref($srcfeature) . " as a srcfeature.");
  $srcfeature{ident $self} = $srcfeature;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_fmin() eq $other->get_fmin() && $self->get_fmax() eq $other->get_fmax() && $self->get_rank() eq $other->get_rank() && $self->get_strand() eq $other->get_strand());
  if ($self->get_srcfeature()) {
    return 0 unless $other->get_srcfeature();
    return 0 unless $self->get_srcfeature()->equals($other->get_srcfeature());
  } else {
    return 0 if $other->get_srcfeature();
  }

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::FeatureLoc({
      'fmin' => $self->get_fmin(),
      'fmax' => $self->get_fmax(),
      'rank' => $self->get_rank(),
      'strand' => $self->get_strand(),
    });
  $clone->set_srcfeature($self->get_srcfeature()->clone()) if $self->get_srcfeature();
  return $clone;
}

sub to_string {
  my ($self) = @_;
  my $string = "featureloc(" . $self->get_fmin() . ", " . $self->get_fmax() . ")";
  return $string;
}

1;

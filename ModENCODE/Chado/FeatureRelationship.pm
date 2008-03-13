package ModENCODE::Chado::FeatureRelationship;

use strict;
use Class::Std;
use Carp qw(carp croak);

# Attributes
my %rank             :ATTR( :name<rank> );

# Relationships
my %object           :ATTR( :get<object>,               :default<undef> ); # Child
my %subject          :ATTR( :get<subject>,              :default<undef> ); # Parent
my %type             :ATTR( :get<type>,                 :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $object = $args->{'object'};
  if (defined($object)) {
    $self->set_object($object);
  }
  my $subject = $args->{'subject'};
  if (defined($subject)) {
    $self->set_subject($subject);
  }
  my $type = $args->{'type'};
  if (defined($type)) {
    $self->set_type($type);
  }
}

sub set_object {
  my ($self, $object) = @_;
  ($object->isa('ModENCODE::Chado::Feature')) or Carp::confess("Can't add a " . ref($object) . " as a object.");
  $object{ident $self} = $object;
}

sub set_subject {
  my ($self, $subject) = @_;
  ($subject->isa('ModENCODE::Chado::Feature')) or Carp::confess("Can't add a " . ref($subject) . " as a subject.");
  $subject{ident $self} = $subject;
}

sub set_type {
  my ($self, $type) = @_;
  ($type->isa('ModENCODE::Chado::CVTerm')) or croak("Can't add a " . ref($type) . " as a type.");
  $type{ident $self} = $type;
}

sub equals {
  my ($self, $other, $feature_parent) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_rank() eq $other->get_rank());
  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  } else {
    return 0 if $other->get_type();
  }


  if ($self->get_object()) {
    return 0 unless $other->get_object();
    return 0 unless $self->get_object() == ($other->get_object());
  } else {
    return 0 if $other->get_object();
  }
  if ($self->get_subject()) {
    return 0 unless $other->get_subject();
    return 0 unless $self->get_subject() == ($other->get_subject());
  } else {
    return 0 if $other->get_subject();
  }

  return 1;
}

sub clone_for {
  my ($self, $uncloned_parent, $cloned_parent) = @_;
  my $clone = new ModENCODE::Chado::FeatureRelationship({
      'rank' => $self->get_rank(),
    });
  $clone->set_type($self->get_type()->clone()) if $self->get_type();

  if ($self->get_object()) {
    if ($uncloned_parent == $self->get_object()) {
      $clone->set_object($cloned_parent);
    } else {
      $clone->set_object($self->get_object()->clone()) if $self->get_object();
    }
  }
  if ($self->get_subject()) {
    if ($uncloned_parent == $self->get_subject()) {
      $clone->set_subject($cloned_parent);
    } else {
      $clone->set_subject($self->get_subject()->clone()) if $self->get_subject();
    }
  }
  return $clone;
}

sub to_string {
  my ($self) = @_;
  my $string = $self->get_object()->to_string() . " " . $self->get_type()->get_name() . " the parent";
  return $string;
}

1;

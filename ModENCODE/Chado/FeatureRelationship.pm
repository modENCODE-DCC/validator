package ModENCODE::Chado::FeatureRelationship;
=pod

=head1 NAME

ModENCODE::Chado::FeatureRelationship - A class representing a simplified Chado
I<feature_relationship> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<feature_relationship> table. It provides accessors for the various attributes
of a feature relationship that are stored in the feature_relationship table
itself, plus accessors for relationships to certain other Chado tables (i.e.
B<feature> and B<cvterm>).

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_rank()|/get_rank() |
set_rank($rank)> or $obj->L<set_rank()|/get_rank() |
set_rank($rank)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::FeatureRelationship({ 'rank' =E<gt> 0, 'type' =E<gt> new
L<ModENCODE::Chado::CVTerm()|ModENCODE::Chado::CVTerm> });> will create a new
FeatureRelationship object with a rank of 0 and a type set to the empty CVTerm
type object.  For complex types (other Chado objects), the default
L<Class::Std> setters and initializers have been replaced with subroutines that
make sure the type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::FeatureRelationship

=over

  my $feature_relationship = new ModENCODE::Chado::FeatureRelationship
    # Simple attributes
    'rank'              => 0,

    # Object relationships
    'subject'           => new ModENCODE::Chado::Feature(),
    'object'            => new ModENCODE::Chado::Feature(),
    'type'              => new ModENCODE::Chado::CVTerm()
  });

  $feature_relationship->set_rank(1);
  my $rank = $feature_relationship->get_rank();
  print $feature_relationship->to_string();

=back

=head1 ACCESSORS

=over

=item get_rank() | set_rank($rank)

The rank of this Chado feature relationship; it corresponds to the
feature_relationship.rank field in a Chado database.

=item get_subject() | set_subject($feature) 

The subject feature of this Chado feature relationship. The form of a
relationship is I<subject> I<type> I<object>. (For instance 'transcript' is
'part_of' a 'gene'.) This subject must be a L<ModENCODE::Chado::Feature> or
conforming subclass (via C<isa>). The subject feature object corresponds to a
feature in the Chado feature table, and the feature_relationship.subject_id
field is used to track the relationship.

=item get_object() | set_object($feature) 

The object feature of this Chado feature relationship. The form of a
relationship is I<object> I<type> I<object>. (For instance 'transcript' is
'part_of' a 'gene'.) This object must be a L<ModENCODE::Chado::Feature> or
conforming obclass (via C<isa>). The object feature object corresponds to a
feature in the Chado feature table, and the feature_relationship.object_id field
is used to track the relationship.

=item get_type() | set_type($type)

The type of this Chado feature relationship. The form of a relationship is
I<object> I<type> I<object>. (For instance 'transcript' is 'part_of' a 'gene'.)
This must be a L<ModENCODE::Chado::CVTerm> or conforming subclass (via C<isa>).
The type object corresponds to a cvterm in the Chado cvterm table, and the
feature_relationship.type_id field is used to track the relationship.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this feature relationship and $obj are equal. Checks all simple
and complex attributes. Also requires that this object and $obj are of the exact
same type. (A parent class != a subclass, even if all attributes are the same.)

=item clone_for($uncloned_parent, $cloned_parent)

Returns a deep copy of this object, recursing to clone all complex type
attributes. Since this is generally called by
L<ModENCODE::Chado::Feature:clone()|ModENCODE::Chado::Feature/clone()>, it needs
to be able to avoid re-cloning the parent feature. Thus, it takes in the parent
feature and the clone of the parent feature being created and uses the
C<$cloned_parent> instead of creating a new clone of C<$uncloned_parent>.

=item to_string()

Return a string representation of this feature relationship.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Feature>, L<ModENCODE::Chado::CVTerm>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(carp croak);

# Attributes
my %rank             :ATTR( :name<rank> );

# Relationships
my %subject          :ATTR( :get<subject>,              :default<undef> ); # Subject does type to
my %object           :ATTR( :get<object>,               :default<undef> ); # Object (e.g. transcript part_of gene)
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

package ModENCODE::Chado::CV;
=pod

=head1 NAME

ModENCODE::Chado::CV - A class representing a simplified Chado I<cv> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<cv> table. It provides accessors for the various attributes of
a Chado cv object that are stored in the cv table itself.

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. For this class,
all of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_name()|/get_name() | set_name($name)> or
$obj->L<set_name()|/get_name() | set_name($name)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new ModENCODE::Chado::CV({
'name' =E<gt> 'SO', 'definition' =E<gt> 'Sequence Ontology' });> will create a
new CV object with a name of 'SO' and a definition of 'Sequence Ontology'.

=back

=head2 Using ModENCODE::Chado::CV

=over

  my $cv = new ModENCODE::Chado::CV({
    # Simple attributes
    'name'              => 'SO',
    'definition'        => 'Sequence Ontology'
  });

  $cv->set_definition('New Definition');
  my $definition = $cv->get_definition();
  print $cv->to_string();

=back

=head1 ACCESSORS

=over

=item get_name() | set_name($name)

The name of this Chado controlled vocabulary; it corresponds to the cv.name
field in a Chado database.

=item get_definition() | set_definition($definition)

The definition of this Chado controlled vocabulary; it corresponds to the
cv.definition field in a Chado database.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this feature and $obj are equal. Checks all attributes. Also
requires that this object and $obj are of the exact same type.  (A parent class
!= a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object. There are no complex objects that this
object can reference, so this just creates a copy of the existing attributes.

=item to_string()

Return a string representation of this controlled vocabulary.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::CVTerm>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(croak);

my %all_cvs;

# Attributes
my %name             :ATTR( :name<name> );
my %definition       :ATTR( :name<definition>,          :default<''> );

sub new {
  my $self = Class::Std::new(@_);
  # Caching CVs
  my $cached_cv = $all_cvs{$self->get_name()};
  if ($cached_cv) {
    $cached_cv->set_definition($self->get_definition()) if ($self->get_definition() && !($cached_cv->get_definition));
    return $cached_cv;
  }
  $all_cvs{$self->get_name()} = $self;
  return $self;
}


sub to_string {
  my ($self) = @_;
  return $self->get_name();
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_definition() eq $other->get_definition());

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::CV({
      'name' => $self->get_name(),
      'definition' => $self->get_definition(),
    });
  return $clone;
}

1;

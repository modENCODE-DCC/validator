package ModENCODE::Chado::Organism;
=pod

=head1 NAME

ModENCODE::Chado::Organism - A class representing a simplified Chado
I<organism> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<organism> table. It provides accessors for the various attributes of an
organism that are stored in the organism table itself.

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_genus()|/get_genus() |
set_genus($genus)> or $obj->L<set_genus()|/get_genus() | set_genus($genus)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::Organism({ 'genus' =E<gt> 'Drosophila', 'species' =E<gt>
'melanogaster' });> will create a new Organism object with a genus of
'Drosophila' and a species of 'melanogaster'.

=back

=head2 Using ModENCODE::Chado::Organism

=over

  my $organism = new ModENCODE::Chado::Organism({
    # Simple attributes
    'chadoxml_id'       => 'Organism_111',
    'genus'             => 'Drosophila',
    'species'           => 'melanogaster'
  });

  $organism->set_genus('New Genus');
  my $genus = $organism->get_genus();
  print $organism->to_string();

=back

=head1 ACCESSORS

=over

=item get_chadoxml_id() | set_chadoxml_id($chadoxml_id)

The I<chadoxml_id> is used by L<ModENCODE::Chado::XMLWriter> to keep track of
the ChadoXML Macro ID (used to refer to the same feature in XML multiple times).
It is also populated when using L<ModENCODE::Parser::Chado> to pull data out of
a Chado database. (Note that the XMLWriter will generate new I<chadoxml_id>s in
this case; it does so whenever the I<chadoxml_id> is purely numeric.

=item get_genus() | set_genus($genus)

The genus of this Chado organism; it corresponds to the organism.genus field in
a Chado database.

=item get_species() | set_species($species)

The species of this Chado organism; it corresponds to the organism.species field
in a Chado database.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this organism and $obj are equal. Checks all attributes. Also
requires that this object and $obj are of the exact same type.  (A parent class
!= a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object. There are no complex objects that this
object can reference, so this just creates a copy of the existing attributes.

=item to_string()

Return a string representation of this organism.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::Attribute>,
L<ModENCODE::Chado::Feature>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;

# Attributes
my %organism_id      :ATTR( :name<id>,                  :default<undef> );
my %genus            :ATTR( :get<genus>,                :init_arg<genus> );
my %species          :ATTR( :get<species> ,             :init_arg<species> );

sub new_no_cache {
  return Class::Std::new(@_);
}

sub new {
  my $temp = Class::Std::new(@_);
  my $cached_organism = ModENCODE::Cache::get_cached_organism($temp);

  if ($cached_organism) {
    # Nothing to update
    return $cached_organism;
  }
  # This is a new organism
  my $self = $temp;
  return ModENCODE::Cache::add_organism_to_cache($self);
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_genus() eq $other->get_genus() && $self->get_species() eq $other->get_species());

  return 1;
}

sub equals {
  my ($self, $other) = @_;

  return 0 unless ($self->get_genus() eq $other->get_genus() && $self->get_species() eq $other->get_species());

  return 1;
}

sub to_string {
  my ($self) = @_;
  return $self->get_genus() . " " . $self->get_species();
}

sub save {
  ModENCODE::Cache::save_organism(shift);
}


1;


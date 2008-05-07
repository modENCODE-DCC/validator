package ModENCODE::Chado::FeatureLoc;
=pod

=head1 NAME

ModENCODE::Chado::FeatureLoc - A class representing a simplified Chado
I<featureloc> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<featureloc> table. It provides accessors for the various attributes of a
feature location that are stored in the featureloc table itself, plus accessors
for relationships to certain other Chado tables (i.e. B<feature>).

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_fmin()|/get_fmin() |
set_fmin($fmin)> or $obj->L<set_fmin()|/get_fmin() |
set_fmin($fmin)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::FeatureLoc({ 'fmin' =E<gt> 300105, 'fmax' =E<gt> 300505 });>
will create a new FeatureLoc object with a start (fmin) of 300105 and an end
(fmax) of 300505. For complex types (other Chado objects), the default
L<Class::Std> setters and initializers have been replaced with subroutines that
make sure the type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::FeatureLoc

=over

  my $featureloc = new ModENCODE::Chado::FeatureLoc({
    # Simple attributes
    'chadoxml_id'       => 'FeatureLoc_111',
    'fmin'              => 300105,
    'fmax'              => 300505,
    'rank'              => 0,
    'strand'            => -1,

    # Object relationships
    'srcfeature'        => new ModENCODE::Chado::Feature()
  });

  $featureloc->set_name('New Name);
  my $fmin = $featureloc->get_fmin();
  print $featureloc->to_string();

=back

=head1 ACCESSORS

=over

=item get_chadoxml_id() | set_chadoxml_id($chadoxml_id)

The I<chadoxml_id> is used by L<ModENCODE::Chado::XMLWriter> to keep track of
the ChadoXML Macro ID (used to refer to the same feature in XML multiple times).
It is also populated when using L<ModENCODE::Parser::Chado> to pull data out of
a Chado database. (Note that the XMLWriter will generate new I<chadoxml_id>s in
this case; it does so whenever the I<chadoxml_id> is purely numeric.

=item get_fmin() | set_fmin($fmin)

The start (fmin) of this Chado feature location; it corresponds to the
featureloc.fmin field in a Chado database.

=item get_fmax() | set_fmax($fmax)

The end (fmax) of this Chado feature location; it corresponds to the
featureloc.fmax field in a Chado database.

=item get_rank() | set_rank($rank)

The rank of this Chado feature location; it corresponds to the featureloc.rank
field in a Chado database.

=item get_strand() | set_strand($strand)

The strand of this Chado feature location; it corresponds to the
featureloc.strand field in a Chado database. This should be either 0, +1, or
-1.  (Numeric values, not "+" or "-".)

=item get_srcfeature() | set_srcfeature($srcfeature) 

The source feature of this Chado feature location. This must be a
L<ModENCODE::Chado::Feature> or conforming subclass (via C<isa>). The source
feature object corresponds to a feature in the Chado feature table, and the
featureloc.srcfeature_id field is used to track the relationship.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this feature location and $obj are equal. Checks all simple and
complex attributes. Also requires that this object and $obj are of the exact
same type. (A parent class != a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes.

=item to_string()

Return a string representation of this feature location.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Feature>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

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
  my $string = "featureloc";
  $string .= " " . $self->get_srcfeature()->get_name() if $self->get_srcfeature();
  $string .= "(" . $self->get_fmin() . ", " . $self->get_fmax() . ")";
  return $string;
}

1;

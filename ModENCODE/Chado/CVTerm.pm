package ModENCODE::Chado::CVTerm;
=pod

=head1 NAME

ModENCODE::Chado::CVTerm - A class representing a simplified Chado
I<cvterm> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado B<cvterm>
table. It provides accessors for the various attributes of a controlled
vocbulary term that are stored in the cvterm table itself, plus accessors for
relationships to certain other Chado tables (i.e. B<cv> and B<dbxref>).

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_name()|/get_name() | set_name($name)> or
$obj->L<set_name()|/get_name() | set_name($name)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::CVTerm({ 'name' =E<gt> 'gene', 'definition' =E<gt> 'A gene is
a gene' });> will create a new CVTerm object with a name of 'gene' and 'A gene
is a gene' as the definition. For complex types (other Chado objects), the
default L<Class::Std> setters and initializers have been replaced with
subroutines that make sure the type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::CVTerm

=over

  my $cvterm = new ModENCODE::Chado::CVTerm({
    # Simple attributes
    'name'              => 'gene',
    'definition'        => 'A gene is a gene',
    'is_obsolete'       => 0,

    # Object relationships
    'cv'                => new ModENCODE::Chado::CV(),
    'dbxref'            => new ModENCODE::Chado::DBXref()
  });

  $cvterm->set_name('New Name);
  my $cvterm_name = $cvterm->get_name();
  print $cvterm->to_string();

=back

=head1 ACCESSORS

=over

=item get_name() | set_name($name)

The name of this Chado controlled vocabulary term; it corresponds to the
cvterm.name field in a Chado database.

=item get_definition() | set_definition($definition)

The definition of this Chado controlled vocabulary term; it corresponds to the
cvterm.definition field in a Chado database.

=item get_is_obsolete() | set_is_obsolete($is_obsolete)

Whether or not this Chado controlled vocabulary term is obsolete; it corresponds
to the cvterm.is_obsolete field in a Chado database and is treated as a boolean
value by Perl L<DBI>. B<0> is false, most other values (including B<1>) are
true.

=item get_dbxref() | set_dbxref($dbxref) 

The dbxref of this Chado controlled vocabulary term. This must be a
L<ModENCODE::Chado::DBXref> or conforming subclass (via C<isa>). The dbxref
object corresponds to a dbxref in the Chado dbxref table, and the
cvterm.dbxref_id field is used to track the relationship.

=item get_cv() | set_cv($cv) 

The controlled vocabulary containing this Chado controlled vocabulary term. This
must be a L<ModENCODE::Chado::CV> or conforming subclass (via C<isa>). The
controlled vocabulary object corresponds to a controlled vocabulary in the Chado
cv table, and the cvterm.cv_id field is used to track the relationship.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this controlled vocabulary term and $obj are equal. Checks all
simple and complex attributes. Also requires that this object and $obj are of
the exact same type. (A parent class != a subclass, even if all attributes are
the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes.

=item to_string()

Return a string representation of this controlled vocabulary term.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::CV>, L<ModENCODE::Chado::DBXref>,
L<ModENCODE::Chado::Feature>, L<ModENCODE::Chado::Attribute>,
L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::ExperimentProp>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(croak);

use ModENCODE::Chado::DB;
use ModENCODE::Chado::DBXref;

my %all_cvterms;

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %name             :ATTR( :name<name> );
my %definition       :ATTR( :name<definition>,          :default<''> );
my %is_obsolete      :ATTR( :name<is_obsolete>,         :default<0> );

# Relationships
my %cv               :ATTR( :get<cv>, :init_arg<cv> );
my %dbxref           :ATTR( :get<dbxref>,               :default<undef> );


sub new {
  my $self = Class::Std::new(@_);
  # Caching CVTerms
  $all_cvterms{$self->get_cv()->get_name()} = {} if (!defined($all_cvterms{$self->get_cv()->get_name()}));
  $all_cvterms{$self->get_cv()->get_name()}->{$self->get_name()} = {} if (!defined($all_cvterms{$self->get_cv()->get_name()}->{$self->get_name()}));
  $all_cvterms{$self->get_cv()->get_name()}->{$self->get_name()} = {} if (!defined($all_cvterms{$self->get_cv()->get_name()}->{$self->get_name()}));

  my $cached_cvterm = $all_cvterms{$self->get_cv()->get_name()}->{$self->get_name()}->{$self->get_is_obsolete()};

  if ($cached_cvterm) {
    # Add any additional info
    $cached_cvterm->set_definition($self->get_definition()) if ($self->get_definition() && !($cached_cvterm->get_definition()));
    $cached_cvterm->set_dbxref($self->get_dbxref()) if ($self->get_dbxref() && !($cached_cvterm->get_dbxref()));
    return $cached_cvterm;
  } else {
    $all_cvterms{$self->get_cv()->get_name()}->{$self->get_name()}->{$self->get_is_obsolete()} = $self;
  }
  return $self;
}

sub get_all_cvterms {
  return \%all_cvterms;
}

sub START {
  my ($self, $ident, $args) = @_;
  my $cv = $args->{'cv'};
  if (defined($cv)) {
    # Redo using the setter to make sure it's a valid CV
    $self->set_cv($cv);
  }
  my $dbxref = $args->{'dbxref'};
  if (defined($dbxref)) {
    $self->set_dbxref($dbxref);
  }
}

sub set_cv {
  my ($self, $cv) = @_;
  ($cv->isa('ModENCODE::Chado::CV')) or croak("Can't add a " . ref($cv) . " as a CV.");
  $cv{ident $self} = $cv;
}

sub set_dbxref {
  my ($self, $dbxref) = @_;
  ($dbxref->isa('ModENCODE::Chado::DBXref')) or croak("Can't add a " . ref($dbxref) . " as a DBXref.");
  $dbxref{ident $self} = $dbxref;
}

sub to_string {
  my ($self) = @_;
  my $string = "{";
  $string .= $self->get_cv()->to_string() . ":" if $self->get_cv();
  $string .= $self->get_name();
  $string .= "}";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless $self == $other;
  return 1;

#  return 0 unless ref($self) eq ref($other);
#
#  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_definition() eq $other->get_definition() && $self->get_is_obsolete() eq $other->get_is_obsolete());
#
#  if ($self->get_cv()) {
#    return 0 unless $other->get_cv();
#    return 0 unless $self->get_cv()->equals($other->get_cv());
#  } else {
#    return 0 if $other->get_cv();
#  }
#
#  if ($self->get_dbxref()) {
#    return 0 unless $other->get_dbxref();
#    return 0 unless $self->get_dbxref()->equals($other->get_dbxref());
#  } else {
#    return 0 if $other->get_dbxref();
#  }
#
#
#  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::CVTerm({
      'name' => $self->get_name(),
      'cv' => $self->get_cv(),
      'definition' => $self->get_definition(),
      'is_obsolete' => $self->get_is_obsolete(),
    });
  $clone->set_dbxref($self->get_dbxref()->clone()) if $self->get_dbxref();
  return $clone;
}
1;

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
use ModENCODE::Cache;
use Carp qw(croak);

# Attributes
my %cv_id            :ATTR( :name<id>,                  :default<undef> );
my %name             :ATTR( :get<name>,                 :init_arg<name> );
my %definition       :ATTR( :name<definition>,          :default<''> );

sub new_no_cache {
  return Class::Std::new(@_);
}

sub new {
  my $temp = Class::Std::new(@_);
  return new ModENCODE::Cache::CV({'content' => $temp }) if ModENCODE::Cache::get_paused();
  my $cached_cv = ModENCODE::Cache::get_cached_cv($temp);
  if ($cached_cv) {
    # Update any cached CV
    my $need_save = 0;
    if ($temp->get_definition && !($cached_cv->get_definition)) {
      $cached_cv->set_definition($temp->get_definition);
      $need_save = 1;
    }
    ModENCODE::Cache::save_cv($cached_cv) if $need_save; # For update
    return $cached_cv;
  }

  # This is a new CV
  my $self = $temp;
  return ModENCODE::Cache::add_cv_to_cache($self);
}


sub to_string {
  my ($self) = @_;
  return $self->get_name();
}

sub save {
  ModENCODE::Cache::save_cv(shift);
}



1;

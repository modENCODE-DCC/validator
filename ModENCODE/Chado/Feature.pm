package ModENCODE::Chado::Feature;
=pod

=head1 NAME

ModENCODE::Chado::Feature - A class representing a simplified Chado I<feature>
object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<feature> table. It provides accessors for the various attributes of a feature
that are stored in the feature table itself, plus accessors for relationships to
certain other Chado tables (such as B<organism>, B<feature_relationship>, etc.)

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_name()|/get_name() | set_name($name)> or
$obj->L<set_name()|/get_name() | set_name($name)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, 
C<my $obj = new ModENCODE::Chado::Feature({ 'name' =E<gt> 'myfeature', 'residues' =E<gt> 'GATTACA' });>
will create a new Feature object with a name of 'myfeature' and 'GATTACA' as the
residues. For complex types (other Chado objects), the default L<Class::Std>
setters and initializers have been replaced with subroutines that make sure
the type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::Feature

=over

  my $feature = new ModENCODE::Chado::Feature({
    # Simple attributes
    'chadoxml_id'       => 'Feature_111',
    'name'              => 'AT19612.5prime',
    'uniquename'        => 'BF485572',
    'residues'          => 'GATTACA',
    'seqlen'            => 7,
    'timeaccessioned'   => '2008-01-24',
    'timelastmodified'  => '2008-01-26',
    'is_analysis'       => 0,

    # Object relationships
    'organism'          => new ModENCODE::Chado::Organism(),
    'type'              => new ModENCODE::Chado::CVTerm(),
    'analysisfeatures'  => [ new ModENCODE::Chado::AnalysisFeature(), ... ],
    'locations'         => [ new ModENCODE::Chado::Location(), ... ],
    'relationships'     => [ new ModENCODE::Chado::Relationship(), ... ],
    'dbxrefs'           => [ new ModENCODE::Chado::DBXref(), ... ],
    'primary_dbxref'    => new ModENCODE::Chado::DBXref(),
  });

  $feature->set_name('New Name);
  my $feature_name = $feature->get_name();
  print $feature->to_string();

=back

=head1 ACCESSORS

=over

=item get_chadoxml_id() | set_chadoxml_id($chadoxml_id)

The I<chadoxml_id> is used by L<ModENCODE::Chado::XMLWriter> to keep track of
the ChadoXML Macro ID (used to refer to the same feature in XML multiple times).
It is also populated when using L<ModENCODE::Parser::Chado> to pull data out of
a Chado database. (Note that the XMLWriter will generate new I<chadoxml_id>s in
this case; it does so whenever the I<chadoxml_id> is purely numeric.

=item get_name() | set_name($name)

The name of this Chado feature; it corresponds to the feature.name field in a
Chado database.

=item get_uniquename() | set_uniquename($uniquename)

The uniquename of this Chado feature; it corresponds to the feature.uniquename
field in a Chado database.

=item get_residues() | set_residues($residues)

The residues of this Chado feature; it corresponds to the feature.residues field
in a Chado database.

=item get_seqlen() | set_seqlen($seqlen)

The seqlen of this Chado feature; it corresponds to the feature.seqlen field in
a Chado database.

=item get_timeaccessioned() | set_timeaccessioned($timeaccessioned)

The timeaccessioned of this Chado feature; it corresponds to the
feature.timeaccessioned field in a Chado database. Should be in a format that
Perl L<DBI> can understand as a timestamp, for instance C<2008-02-21 14:45:01>.

=item get_timelastmodified() | set_timelastmodified($timelastmodified)

The timelastmodified of this Chado feature; it corresponds to the
feature.timelastmodified field in a Chado database. Should be in a format that
Perl L<DBI> can understand as a timestamp, for instance C<2008-02-21 14:45:01>.

=item get_is_analysis() | set_is_analysis($is_analysis)

Whether or not this Chado feature is an analysis feature. It corresponds to the
feature.is_analysis field in a Chado database and is treated as a boolean value
by Perl L<DBI>. B<0> is false, most other values (including B<1>) are true.

=item get_organism() | set_organism($organism)

The organism of this Chado feature. This must be a L<ModENCODE::Chado::Organism>
or conforming subclass (via C<isa>). The organism object corresponds to the
organism in the Chado organism table, and the feature.organism_id field is used
to track the relationship.

=item get_type() | set_type($type)

The type of this Chado feature. This must be a L<ModENCODE::Chado::CVTerm> or
conforming subclass (via C<isa>). The type object corresponds to a cvterm in the
Chado cvterm table, and the feature.type_id field is used to track the
relationship.

=item get_analysisfeatures() | add_analysisfeature($analysisfeature)

A list of all the analysisfeatures associated with this Chado feature. The
getter returns an arrayref of L<ModENCODE::Chado::AnalysisFeature> objects, and
the adder adds another analysisfeature to the list. The analysisfeature objects
must be a L<ModENCODE::Chado::AnalysisFeature> or conforming subclass (via
C<isa>).  The analysisfeature objects corresponds to the analysisfeatures in the
Chado analysisfeature table, and the analysisfeature.feature_id field is used to
track the relationship.

=item get_locations() | add_location($location)

A list of all the locations associated with this Chado feature. The getter
returns an arrayref of L<ModENCODE::Chado::FeatureLoc> objects, and the adder
adds another location to the list. The location objects must be a
L<ModENCODE::Chado::FeatureLoc> or conforming subclass (via C<isa>).  The
location objects corresponds to the locations in the Chado featureloc table, and
the featureloc.feature_id field is used to track the relationship.

=item get_relationships() | add_relationship($relationship)

A list of all the relationships associated with this Chado feature. The getter
returns an arrayref of L<ModENCODE::Chado::FeatureRelationship> objects, and the
adder adds another relationship to the list. The relationship objects must be a
L<ModENCODE::Chado::FeatureRelationship> or conforming subclass (via C<isa>).
The relationship objects corresponds to the relationships in the Chado
feature_relationship table. This feature object can be either the object or
subject of the relationship, which means it will be tracked either in
feature_relationship.object_id or feature_relationship.subject_id.

=item get_dbxrefs() | add_dbxref($dbxref)

A list of all the dbxrefs associated with this Chado feature. The getter returns
an arrayref of L<ModENCODE::Chado::DBXref> objects, and the adder adds another
dbxref to the list. The dbxref objects must be a L<ModENCODE::Chado::DBXref> or
conforming subclass (via C<isa>).  The dbxref objects corresponds to the dbxrefs
in the Chado feature_dbxref table, and the feature_dbxref.feature_id and
feature_dbxref.dbxref_id fields are used to track the relationship.

B<NOTE:> If a dbxref is set using L<set_primary_dbxref|/get_primary_dbxref() |
set_primary_dbxref($dbxref)>, and does not already exist in the list of dbxrefs,
it will be added. Likewise, if no primary dbxref is yet set and one it added to
the list of dbxrefs, it will be set as the primary dbxref.

=item get_primary_dbxref() | set_primary_dbxref($primary_dbxref)

The primary dbxref of this Chado feature. This must be a
L<ModENCODE::Chado::DBXref> or conforming subclass (via C<isa>). The dbxref
object corresponds to a dbxref in the Chado dbxref table, and the
feature.dbxref_id field is used to track the relationship.

B<NOTE:> If a primary_dbxref is set using this function, and does not yet exist
in the list of all dbxrefs returned by L<get_dbxrefs()|/get_dbxrefs() |
add_dbxref($dbxref)>, then it will be added to that list. Likewise, if no
primary dbxref is yet set and one it added to the list of dbxrefs, it will be
set as the primary dbxref.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this feature and $obj are equal. Checks all simple and complex
attributes I<except for the relationships attribute> (to avoid deep graph
traversal). Also requires that this object and $obj are of the exact same type.
(A parent class != a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes. Uses the special utility function
L<ModENCODE::Chado::FeatureRelationship::clone_for($self, $clone)|ModENCODE::Chado::FeatureRelationship/clone_for($uncloned_parent,
$cloned_parent)> to allow deep cloning of relationships.

=item mimic($feature)

Given a ModENCODE::Chado::Feature, sets all of the attributes of this feature to
be the same as $feature, I<except for the relationship attribute> (to avoid deep
graph traversal).

=item to_string()

Return a string representation of this feature. Attempts to follow relationships
and print all related features. (May be very slow; mostly useful for debugging.)

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Organism>, L<ModENCODE::Chado::CVTerm>,
L<ModENCODE::Chado::AnalysisFeature>, L<ModENCODE::Chado::FeatureLoc>,
L<ModENCODE::Chado::FeatureRelationship>, L<ModENCODE::Chado::DBXref>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(carp croak confess);
use ModENCODE::ErrorHandler qw(log_error);

# Attributes
my %feature_id       :ATTR( :name<id>,                                                  :default<undef> );
my %dirty            :ATTR( :default<1> );
my %name             :ATTR( :get<name>,                 :init_arg<name>,                :default<undef> );
my %uniquename       :ATTR( :get<uniquename>,           :init_arg<uniquename> );
my %residues         :ATTR( :get<residues>,             :init_arg<residues>,            :default<undef> );
my %seqlen           :ATTR( :get<seqlen>,               :init_arg<seqlen>,              :default<undef> );
my %timeaccessioned  :ATTR( :get<timeaccessioned>,      :init_arg<timeaccessioned>,     :default<undef> );
my %timelastmodified :ATTR( :get<timelastmodified>,     :init_arg<timelastmodified>,    :default<undef> );
my %is_analysis      :ATTR( :get<is_analysis>,          :init_arg<is_analysis>,         :default<0> );

# Relationships
my %organism         :ATTR(                             :init_arg<organism>,            :default<undef> );
my %type             :ATTR(                             :init_arg<type>,                :default<undef> );
my %analysisfeatures :ATTR( :get<analysisfeatures>,     :init_arg<analysisfeatures>,    :default<[]> );
my %locations        :ATTR( :get<locations>,            :init_arg<locations>,           :default<[]> );
my %properties       :ATTR( :get<properties>,           :init_arg<properties>,          :default<[]> );
my %relationships    :ATTR( :set<relationships>,        :init_arg<relationships>,       :default<[]> );
my %dbxrefs          :ATTR(                             :init_arg<dbxrefs>,             :default<[]> );
my %primary_dbxref   :ATTR(                             :init_arg<primary_dbxref>,      :default<undef> );

sub set_name { my ($self, $name) = @_; $self->dirty(); $name{ident $self} = $name; }
sub set_residues { my ($self, $residues) = @_; $self->dirty(); $residues{ident $self} = $residues; }
sub set_seqlen { my ($self, $seqlen) = @_; $self->dirty(); $seqlen{ident $self} = $seqlen; }
sub set_timeaccessioned { my ($self, $timeaccessioned) = @_; $self->dirty(); $timeaccessioned{ident $self} = $timeaccessioned; }
sub set_timelastmodified { my ($self, $timelastmodified) = @_; $self->dirty(); $timelastmodified{ident $self} = $timelastmodified; }
sub set_is_analysis { my ($self, $is_analysis) = @_; $self->dirty(); $is_analysis{ident $self} = $is_analysis; }
sub set_analysisfeatures { my ($self, $analysisfeatures) = @_; $self->dirty(); $analysisfeatures{ident $self} = $analysisfeatures; }
sub set_locations { my ($self, $locations) = @_; $self->dirty(); $locations{ident $self} = $locations; }
sub set_properties { my ($self, $properties) = @_; $self->dirty(); $properties{ident $self} = $properties; }

sub dirty {
  my $self = shift;
  $dirty{$self} = 1;
}

sub clean {
  $dirty{ident shift} = 0;
}

sub is_dirty {
  return $dirty{ident shift};
}

sub new_no_cache {
  return Class::Std::new(@_);
}

sub new {
  my $temp = Class::Std::new(@_);
  my $cached_feature = ModENCODE::Cache::get_cached_feature($temp);

  if ($cached_feature) {
    # Update any cached feature
    my $need_save = 0;

    if ($temp->get_name && !($cached_feature->get_object->get_name)) {
      $cached_feature->get_object->set_name($temp->get_name);
      $need_save = 1;
    }
    if ($temp->get_residues && !($cached_feature->get_object->get_residues)) {
      $cached_feature->get_object->set_residues($temp->get_residues);
      $need_save = 1;
    }
    if ($temp->get_seqlen && !($cached_feature->get_object->get_seqlen)) {
      $cached_feature->get_object->set_seqlen($temp->get_seqlen);
      $need_save = 1;
    }
    if ($temp->get_timeaccessioned && !($cached_feature->get_object->get_timeaccessioned)) {
      $cached_feature->get_object->set_timeaccessioned($temp->get_timeaccessioned);
      $need_save = 1;
    }
    if ($temp->get_timelastmodified && !($cached_feature->get_object->get_timelastmodified)) {
      $cached_feature->get_object->set_timelastmodified($temp->get_timelastmodified);
      $need_save = 1;
    }
    if ($temp->get_is_analysis && !($cached_feature->get_object->get_is_analysis)) {
      $cached_feature->get_object->set_is_analysis($temp->get_is_analysis);
      $need_save = 1;
    }

    if ($temp->get_organism && !($cached_feature->get_object->get_organism)) {
      $cached_feature->get_object->set_organism($temp->get_organism);
      $need_save = 1;
    }
    if ($temp->get_type && !($cached_feature->get_object->get_type)) {
      $cached_feature->get_object->set_type($temp->get_type);
      $need_save = 1;
    }

    if (scalar($temp->get_analysisfeatures) && !scalar($cached_feature->get_object->get_analysisfeatures)) {
      $cached_feature->get_object->set_analysisfeatures($temp->get_analysisfeatures);
      $need_save = 1;
    }
    if (scalar($temp->get_locations) && !scalar($cached_feature->get_object->get_locations)) {
      $cached_feature->get_object->set_locations($temp->get_locations);
      $need_save = 1;
    }
    if (scalar($temp->get_properties) && !scalar($cached_feature->get_object->get_properties)) {
      $cached_feature->get_object->set_properties($temp->get_properties);
      $need_save = 1;
    }
    if (scalar($temp->get_relationships) && !scalar($cached_feature->get_object->get_relationships)) {
      $cached_feature->get_object->set_relationships($temp->get_relationships);
      $need_save = 1;
    }
    if ($temp->get_primary_dbxref && !($cached_feature->get_object->get_primary_dbxref)) {
      $cached_feature->get_object->set_primary_dbxref($temp->get_primary_dbxref);
      $need_save = 1;
    }
    if (scalar($temp->get_dbxrefs) && !scalar($cached_feature->get_object->get_dbxrefs)) {
      $cached_feature->get_object->set_dbxrefs($temp->get_dbxrefs);
      $need_save = 1;
    }

    ModENCODE::Cache::save_feature($cached_feature->get_object) if $need_save;
    return $cached_feature;
  }

  # This is a new feature
  my $self = $temp;
  return ModENCODE::Cache::add_feature_to_cache($self);
}

sub START {
  my ($self, $ident, $args) = @_;

  # Make sure the primary DBXref is in the list of DBXrefs
  my $dbxref = $self->get_primary_dbxref;
  if ($dbxref) {
    my ($matching_dbxref) = grep { $dbxref->get_id == $_->get_id } $self->get_dbxrefs;
    if (!$matching_dbxref) {
      $self->add_dbxref($dbxref);
      $matching_dbxref = $dbxref;
      $self->dirty();
    }
  }

  # Set the primary_dbxref if one hasn't yet been
  if (!$self->get_primary_dbxref && scalar($self->get_dbxrefs)) {
    my ($first_dbxref) = $self->get_dbxrefs;
    $self->set_primary_dbxref($first_dbxref);
  }

}

sub get_organism_id {
  my $self = shift;
  return $organism{ident $self} ? $organism{ident $self}->get_id : undef;
}

sub get_organism {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $organism = $organism{ident $self};
  return undef unless defined $organism;
  return $get_cached_object ? $organism{ident $self}->get_object : $organism{ident $self};
}

sub get_type_id {
  my $self = shift;
  return $type{ident $self} ? $type{ident $self}->get_id : undef;
}

sub get_type {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $type = $type{ident $self};
  return undef unless defined $type;
  return $get_cached_object ? $type{ident $self}->get_object : $type{ident $self};
}

sub get_primary_dbxref_id {
  my $self = shift;
  return $primary_dbxref{ident $self} ? $primary_dbxref{ident $self}->get_id : undef;
}

sub get_primary_dbxref {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $primary_dbxref = $primary_dbxref{ident $self};
  return $get_cached_object ? $primary_dbxref->get_object : $primary_dbxref;
}

sub get_dbxref_ids {
  my $self = shift;
  return map { $_->get_id } @{$dbxrefs{ident $self}}
}

sub get_dbxrefs {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $dbxrefs = $dbxrefs{ident $self};
  return $get_cached_object ? map { $_->get_object } @$dbxrefs : @$dbxrefs;
}

sub add_dbxref {
  my ($self, $dbxref) = @_;
  ($dbxref->get_object->isa('ModENCODE::Chado::DBXref')) or Carp::confess("Can't add a " . ref($dbxref) . " as a dbxref.");
  return if grep { $_->get_id == $dbxref->get_id } @{$dbxrefs{ident $self}};
  push @{$dbxrefs{ident $self}}, $dbxref;
  if (!$self->get_primary_dbxref()) {
    $self->set_primary_dbxref($dbxref);
  }
}

sub set_dbxrefs {
  my ($self, $dbxrefs) = @_;
  $dbxrefs{ident $self} = [];
  $self->dirty();
  if (!scalar(@$dbxrefs)) {
    delete $primary_dbxref{ident $self};
    return;
  }

  my $found_primary = 0;
  foreach my $dbxref (@$dbxrefs) {
    $found_primary = 1 if ($primary_dbxref{ident $self}->get_id == $dbxref->get_id);
    push @{$dbxrefs{ident $self}}, $dbxref;
  }
  $self->set_primary_dbxref($dbxrefs->[0]) unless $found_primary;
}

sub set_primary_dbxref {
  my ($self, $dbxref) = @_;
  $self->dirty();
  ($dbxref->get_object->isa('ModENCODE::Chado::DBXref')) or croak("Can't add a " . ref($dbxref) . " as a primary_dbxref.");
  my ($matching_dbxref) = grep { $dbxref->get_id == $_->get_id } $self->get_dbxrefs;
  if (!$matching_dbxref) {
    $self->add_dbxref($dbxref);
    $matching_dbxref = $dbxref;
  }
  $primary_dbxref{ident $self} = $matching_dbxref;
}

sub set_type {
  my ($self, $type) = @_;
  $self->dirty();
  ($type->get_object->isa('ModENCODE::Chado::CVTerm')) or croak("Can't add a " . ref($type) . " as a type.");
  $type{ident $self} = $type;
}

sub set_organism {
  my ($self, $organism) = @_;
  $self->dirty();
  ($organism->get_object->isa('ModENCODE::Chado::Organism')) or Carp::confess("Can't add a " . ref($organism) . " as an organism.");
  $organism{ident $self} = $organism;
}

sub add_location {
  my ($self, $location) = @_;
  ($location->isa('ModENCODE::Chado::FeatureLoc')) or Carp::confess("Can't add a " . ref($location) . " as a location.");
  return if grep { 
    (
      (
        $_->get_srcfeature && $location->get_srcfeature &&
        $_->get_srcfeature->get_id == $location->get_srcfeature->get_id
      ) || (
        !$_->get_srcfeature && !$location->get_srcfeature
      )
    ) && 
    $_->get_fmin == $location->get_fmin &&
    $_->get_fmax == $location->get_fmax &&
    $_->get_rank == $location->get_rank &&
    $_->get_strand == $location->get_strand &&
    $_->get_residue_info eq $location->get_residue_info
  } @{$locations{ident $self}};
  push @{$locations{ident $self}}, $location;
}

sub add_property {
  my ($self, $property) = @_;
  ($property->isa('ModENCODE::Chado::FeatureProp')) or Carp::confess("Can't add a " . ref($property) . " as a property.");
  return if grep { 
    $_->get_type->get_id == $property->get_type->get_id &&
    $_->get_value == $property->get_value &&
    $_->get_rank == $property->get_rank
  } @{$properties{ident $self}};
  push @{$properties{ident $self}}, $property;
}

sub add_analysisfeature {
  my ($self, $analysisfeature) = @_;
  ($analysisfeature->isa('ModENCODE::Chado::AnalysisFeature')) or Carp::confess("Can't add a " . ref($analysisfeature) . " as an analysisfeature.");
  my ($existing_af) = grep { $_->get_analysis_id == $analysisfeature->get_analysis_id } @{$self->get_analysisfeatures()};
  if ($existing_af) {
    log_error "Updating existing analysisfeature", "debug";
    # Duplicate, so update the existing one if necessary
    if ($analysisfeature->get_rawscore() && !$existing_af->get_rawscore()) {
      $existing_af->set_rawscore($analysisfeature->get_rawscore);
    }
    if ($analysisfeature->get_normscore() && !$existing_af->get_normscore()) {
      $existing_af->set_normscore($analysisfeature->get_normscore);
    }
    if ($analysisfeature->get_significance() && !$existing_af->get_significance()) {
      $existing_af->set_significance($analysisfeature->get_significance);
    }
    if ($analysisfeature->get_identity() && !$existing_af->get_identity()) {
      $existing_af->set_identity($analysisfeature->get_identity);
    }
  } else {
    push @{$analysisfeatures{ident $self}}, $analysisfeature;
  }
}

sub get_relationship_ids {
  my $self = shift;
  return map { $_->get_id } @{$relationships{ident $self}}
}

sub get_relationships {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $relationships = $relationships{ident $self};
  return $get_cached_object ? map { $_->get_object } @$relationships : @$relationships;
}

sub add_relationship {
  my ($self, $relationship) = @_;
  ($relationship->get_object->isa('ModENCODE::Chado::FeatureRelationship')) or Carp::confess("Can't add a " . ref($relationship) . " as a feature relationship.");
  return if grep { $_->get_id == $relationship->get_id } @{$relationships{ident $self}};
  push @{$relationships{ident $self}}, $relationship;
}

sub to_string {
  my ($self) = @_;
  $::SEEN_FEATURES = [] if $::DEPTH == 0;
  $::SEEN_RELATIONSHIPS = [] if $::DEPTH == 0;
  $::DEPTH++;
  my $string = "feature(" . $self->get_uniquename() . "/" . $self->get_name() . ")";
  $string .= " of type " . $self->get_type(1)->get_name if $self->get_type();
  $string .= " of organism " . $self->get_organism(1)->to_string() if $self->get_organism();
  $string .= " with " . scalar(@{$self->get_analysisfeatures()}) . " analysisfeatures";
  $string .= " with " . scalar($self->get_dbxrefs) . " DBXrefs";
  $string .= " with primary DBXref: " . $self->get_primary_dbxref(1)->to_string if $self->get_primary_dbxref;
  $string .= " with " . scalar(@{$self->get_locations()}) . " locations";
  $string .= " with " . scalar(@{$self->get_properties()}) . " properties";
  $string .= "\n";
  foreach my $analysisfeature (@{$self->get_analysisfeatures}) {
    $string .= "  " . $analysisfeature->to_string . "\n";
  }
  foreach my $dbxref ($self->get_dbxrefs(1)) {
    $string .= "  " . $dbxref->to_string . "\n";
  }
  my @okay_obj_relationships_to_follow;
  my @okay_subj_relationships_to_follow;
  my @not_okay_obj_relationships_to_follow;
  my @not_okay_subj_relationships_to_follow;
  push @$::SEEN_FEATURES, $self;
  foreach my $rel ($self->get_relationships(1)) {
    next if (scalar(grep { $rel == $_ } @$::SEEN_RELATIONSHIPS));
    push @$::SEEN_RELATIONSHIPS, $rel;

    if (!scalar(grep { $rel->get_object() == $_ } @$::SEEN_FEATURES)) {
      push @okay_obj_relationships_to_follow, $rel;
    } else {
      push @not_okay_obj_relationships_to_follow, $rel unless ($rel->get_object() == $self);
    }

    if (!scalar(grep { $rel->get_subject() == $_ } @$::SEEN_FEATURES)) {
      push @okay_subj_relationships_to_follow, $rel;
    } else {
      push @not_okay_subj_relationships_to_follow, $rel unless ($rel->get_subject() == $self);
    }
  }
  my @okay_srcfeatures;
  my @not_okay_srcfeatures;
  foreach my $loc (@{$self->get_locations()}) {
    if (!scalar(grep { $loc->get_srcfeature() == $_ } @$::SEEN_FEATURES)) {
      push @okay_srcfeatures, $loc;
    } else {
      push @not_okay_srcfeatures, $loc unless ($loc->get_srcfeature() == $self);
    }
  }
  $string .= "(\n" if (scalar(@okay_subj_relationships_to_follow) || scalar(@okay_obj_relationships_to_follow) || scalar(@not_okay_subj_relationships_to_follow) || scalar(@not_okay_obj_relationships_to_follow) || scalar(@okay_srcfeatures) || scalar(@not_okay_srcfeatures));
  my $spaces;
  for (my $i = 0; $i < $::DEPTH-1; $i++) {
    $spaces .= "  ";
  }
  foreach my $relationship (@okay_obj_relationships_to_follow) {
    $string .= "${spaces}  OBJ: this feature " . $relationship->get_type(1)->get_name() . " the above feature; " . $relationship->get_object(1)->to_string() . "\n";
  }
  foreach my $relationship (@okay_subj_relationships_to_follow) {
    $string .= "${spaces}  SUBJ: the above feature " . $relationship->get_type(1)->get_name() . " " . $relationship->get_subject(1)->to_string() . "\n";
  }
  foreach my $relationship (@not_okay_obj_relationships_to_follow) {
    $string .= "${spaces}  SEEN OBJ: this feature " . $relationship->get_type(1)->get_name() . " the above feature; " . $relationship->get_object(1)->get_uniquename() . "\n";
  }
  foreach my $relationship (@not_okay_subj_relationships_to_follow) {
    $string .= "${spaces}  SEEN SUBJ: the above feature " . $relationship->get_type(1)->get_name() . " " . $relationship->get_subject(1)->get_uniquename() . "\n";
  }
  foreach my $srcfeature (@okay_srcfeatures) {
    $string .= "${spaces}  SRCFEATURE: " . $srcfeature->to_string() . "\n";
  }
  foreach my $srcfeature (@not_okay_srcfeatures) {
    $string .= "${spaces}  SEEN SRCFEATURE: " . $srcfeature->to_string() . "\n";
  }
  $string .= "${spaces})" if (scalar(@okay_subj_relationships_to_follow) || scalar(@okay_obj_relationships_to_follow) || scalar(@not_okay_subj_relationships_to_follow) || scalar(@not_okay_obj_relationships_to_follow) || scalar(@okay_srcfeatures) || scalar(@not_okay_srcfeatures));
  $::DEPTH--;
  return $string;
}

sub save {
  my $self = shift;
  if ($dirty{ident $self}) {
    $dirty{ident $self} = 0;
    ModENCODE::Cache::save_feature($self);
  }
}

1;

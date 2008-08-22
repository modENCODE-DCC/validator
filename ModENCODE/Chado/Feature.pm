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
use Carp qw(carp croak);
use ModENCODE::ErrorHandler qw(log_error);

my @all_features;

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %name             :ATTR( :name<name>,                :default<undef> );
my %uniquename       :ATTR( :name<uniquename>,          :default<undef> );
my %residues         :ATTR( :name<residues>,            :default<undef> );
my %seqlen           :ATTR( :name<seqlen>,              :default<undef> );
my %timeaccessioned  :ATTR( :name<timeaccessioned>,     :default<undef> );
my %timelastmodified :ATTR( :name<timelastmodified>,    :default<undef> );
my %is_analysis      :ATTR( :name<is_analysis>,         :default<0> );

# Relationships
my %organism         :ATTR( :get<organism>,             :default<undef> );
my %type             :ATTR( :get<type>,                 :default<undef> );
my %analysisfeatures :ATTR( :get<analysisfeatures>,     :default<[]> );
my %locations        :ATTR( :get<locations>,            :default<[]> );
my %relationships    :ATTR( :get<relationships>,        :default<[]> );
my %dbxrefs          :ATTR( :get<dbxrefs>,              :default<[]> );
my %primary_dbxref   :ATTR( :get<primary_dbxref>,       :default<undef> );

sub new {
  my $self = Class::Std::new(@_);
  # Cache features
  push @all_features, $self;
  return $self;
}

sub get_all_features {
  return \@all_features;
}

sub START {
  my ($self, $ident, $args) = @_;
  my $organism = $args->{'organism'};
  if (defined($organism)) {
    $self->set_organism($organism);
  }
  my $type = $args->{'type'};
  if (defined($type)) {
    $self->set_type($type);
  }
  my $locations = $args->{'locations'};
  if (defined($locations)) {
    (ref($locations) eq "ARRAY") or croak("Can't set locations from a " . ref($locations) . ". Expected an ARRAY");
    foreach my $location (@$locations) {
      $self->add_location($location);
    }
  }
  my $analysisfeatures = $args->{'analysisfeatures'};
  if (defined($analysisfeatures)) {
    (ref($analysisfeatures) eq "ARRAY") or croak("Can't set analysisfeatures from a " . ref($analysisfeatures) . ". Expected an ARRAY");
    foreach my $analysisfeature (@$analysisfeatures) {
      $self->add_analysisfeature($analysisfeature);
    }
  }
  my $relationships = $args->{'relationships'};
  if (defined($relationships)) {
    (ref($relationships) eq "ARRAY") or croak("Can't set relationships from a " . ref($relationships) . ". Expected an ARRAY");
    foreach my $relationship (@$relationships) {
      $self->add_relationship($relationship);
    }
  }
  my $dbxrefs = $args->{'dbxrefs'};
  if (defined($dbxrefs)) {
    (ref($dbxrefs) eq "ARRAY") or croak("Can't set dbxrefs from a " . ref($dbxrefs) . ". Expected an ARRAY");
    foreach my $dbxref (@$dbxrefs) {
      $self->add_dbxref($dbxref);
    }
  }
  my $primary_dbxref = $args->{'primary_dbxref'};
  if (defined($primary_dbxref)) {
    $self->set_primary_dbxref($primary_dbxref);
  }
}

sub add_dbxref {
  my ($self, $dbxref) = @_;
  ($dbxref->isa('ModENCODE::Chado::DBXref')) or Carp::confess("Can't add a " . ref($dbxref) . " as a dbxref.");
  return if scalar(grep { $dbxref->equals($_) } @{$self->get_dbxrefs()}); # No duplicates
  push @{$dbxrefs{ident $self}}, $dbxref;
  if (!$self->get_primary_dbxref()) {
    $self->set_primary_dbxref($dbxref);
  }
}

sub set_primary_dbxref {
  my ($self, $dbxref) = @_;
  ($dbxref->isa('ModENCODE::Chado::DBXref')) or croak("Can't add a " . ref($dbxref) . " as a primary_dbxref.");
  my ($matching_dbxref) = grep { $dbxref->equals($_) } @{$self->get_dbxrefs()};
  my $matching_dbxref;
  if (!$matching_dbxref) {
    $self->add_dbxref($dbxref);
    $matching_dbxref = $dbxref;
  }
  $primary_dbxref{ident $self} = $matching_dbxref;
}

sub set_type {
  my ($self, $type) = @_;
  ($type->isa('ModENCODE::Chado::CVTerm')) or croak("Can't add a " . ref($type) . " as a type.");
  $type{ident $self} = $type;
}

sub set_organism {
  my ($self, $organism) = @_;
  ($organism->isa('ModENCODE::Chado::Organism')) or Carp::confess("Can't add a " . ref($organism) . " as an organism.");
  $organism{ident $self} = $organism;
}

sub add_location {
  my ($self, $location) = @_;
  ($location->isa('ModENCODE::Chado::FeatureLoc')) or Carp::confess("Can't add a " . ref($location) . " as a location.");
  push @{$locations{ident $self}}, $location;
}

sub add_analysisfeature {
  my ($self, $analysisfeature) = @_;
  ($analysisfeature->isa('ModENCODE::Chado::AnalysisFeature')) or Carp::confess("Can't add a " . ref($analysisfeature) . " as an analysisfeature.");
  push @{$analysisfeatures{ident $self}}, $analysisfeature;
}

sub add_relationship {
  my ($self, $relationship) = @_;
  ($relationship->isa('ModENCODE::Chado::FeatureRelationship')) or Carp::confess("Can't add a " . ref($relationship) . " as an relationship.");
#  if (!scalar(grep { $_->equals($relationship) } @{$self->get_relationships()})) {
    push @{$relationships{ident $self}}, $relationship;
#  }
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_uniquename() eq $other->get_uniquename() && $self->get_residues() eq $other->get_residues() && $self->get_seqlen() eq $other->get_seqlen() && $self->get_timeaccessioned() eq $other->get_timeaccessioned() && $self->get_timelastmodified() eq $other->get_timelastmodified());
  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  } else {
    return 0 if $other->get_type();
  }

  if ($self->get_organism()) {
    return 0 unless $other->get_organism();
    return 0 unless $self->get_organism()->equals($other->get_organism());
  } else {
    return 0 if $other->get_organism();
  }

  my @locations = @{$self->get_locations()};
  return 0 unless scalar(@locations) == scalar(@{$other->get_locations()});
  foreach my $location (@locations) {
    return 0 unless scalar(grep { $_->equals($location) } @{$other->get_locations()});
  }

  my @analysisfeatures = @{$self->get_analysisfeatures()};
  return 0 unless scalar(@analysisfeatures) == scalar(@{$other->get_analysisfeatures()});
  foreach my $analysisfeature (@analysisfeatures) {
    return 0 unless scalar(grep { $_->equals($analysisfeature) } @{$other->get_analysisfeatures()});
  }

  my @dbxrefs = @{$self->get_dbxrefs()};
  return 0 unless scalar(@dbxrefs) == scalar(@{$other->get_dbxrefs()});
  foreach my $dbxref (@dbxrefs) {
    return 0 unless scalar(grep { $_->equals($dbxref) } @{$other->get_dbxrefs()});
  }

  if ($self->get_primary_dbxref()) {
    return 0 unless $other->get_primary_dbxref();
    return 0 unless $self->get_primary_dbxref()->equals($other->get_primary_dbxref());
  } else {
    return 0 if $other->get_primary_dbxref();
  }

#  my @relationships = @{$self->get_relationships()};
#  return 0 unless scalar(@relationships) == scalar(@{$other->get_relationships()});
#  foreach my $relationship (@relationships) {
#    return 0 unless scalar(grep { $_->equals($relationship, $self) } @{$other->get_relationships()});
#  }

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Feature({
      'chadoxml_id' => $self->get_chadoxml_id(),
      'name' => $self->get_name(),
      'uniquename' => $self->get_uniquename(),
      'residues' => $self->get_residues(),
      'seqlen' => $self->get_seqlen(),
      'timeaccessioned' => $self->get_timeaccessioned(),
      'timelastmodified' => $self->get_timelastmodified(),
    });
  $clone->set_type($self->get_type()->clone()) if $self->get_type();
  $clone->set_organism($self->get_organism()->clone()) if $self->get_organism();
  foreach my $location (@{$self->get_locations()}) {
    $clone->add_location($location->clone());
  }
  foreach my $analysisfeature (@{$self->get_analysisfeatures()}) {
    $clone->add_analysisfeature($analysisfeature->clone());
  }
  foreach my $relationship (@{$self->get_relationships()}) {
    $clone->add_relationship($relationship->clone_for($self, $clone));
  }
  foreach my $dbxref (@{$self->get_dbxrefs()}) {
    $clone->add_dbxref($dbxref->clone($self));
  }
  $clone->set_primary_dbxref($self->get_primary_dbxref()->clone()) if $self->get_primary_dbxref();
  return $clone;
}

sub mimic {
  my ($self, $other) = @_;
  if (ref($self) ne ref($other)) {
    log_error "A " . ref($self) . " cannot mimic a " . ref($other);
    return;
  }
  $chadoxml_id{ident $self} = $other->get_chadoxml_id();
  $name{ident $self} = $other->get_name();
  $uniquename{ident $self} = $other->get_uniquename();
  $residues{ident $self} = $other->get_residues();
  $seqlen{ident $self} = $other->get_seqlen();
  $timeaccessioned{ident $self} = $other->get_timeaccessioned();
  $timelastmodified{ident $self} = $other->get_timelastmodified();
  $is_analysis{ident $self} = $other->get_is_analysis();
  $organism{ident $self} = $other->get_organism();
  $type{ident $self} = $other->get_type();
  $analysisfeatures{ident $self} = $other->get_analysisfeatures();
  $locations{ident $self} = $other->get_locations();
  $dbxrefs{ident $self} = $other->get_dbxrefs();
  $primary_dbxref{ident $self} = $other->get_primary_dbxref();
#  $relationships{ident $self} = $other->get_relationships();
}

sub to_string {
  my ($self) = @_;
  $::SEEN_FEATURES = [] if $::DEPTH == 0;
  $::SEEN_RELATIONSHIPS = [] if $::DEPTH == 0;
  $::DEPTH++;
  my $string = "feature(" . $self->get_uniquename() . ")";
#  my $string = "feature('" . $self->get_name() . "'/" . $self->get_uniquename() . "')";
#  $string .= " of organism " . $self->get_organism()->to_string() if $self->get_organism();
#  $string .= " with " . scalar(@{$self->get_analysisfeatures()}) . " analysisfeatures";
  $string .= " with " . scalar(@{$self->get_locations()}) . " locations";
  my @okay_obj_relationships_to_follow;
  my @okay_subj_relationships_to_follow;
  my @not_okay_obj_relationships_to_follow;
  my @not_okay_subj_relationships_to_follow;
  push @$::SEEN_FEATURES, $self;
  foreach my $rel (@{$self->get_relationships()}) {
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
    $string .= "${spaces}  OBJ: this feature " . $relationship->get_type()->get_name() . " the above feature; " . $relationship->get_object()->to_string() . "\n";
  }
  foreach my $relationship (@okay_subj_relationships_to_follow) {
    $string .= "${spaces}  SUBJ: the above feature " . $relationship->get_type()->get_name() . " " . $relationship->get_subject()->to_string() . "\n";
  }
  foreach my $relationship (@not_okay_obj_relationships_to_follow) {
    $string .= "${spaces}  SEEN OBJ: this feature " . $relationship->get_type()->get_name() . " the above feature; " . $relationship->get_object()->get_uniquename() . "\n";
  }
  foreach my $relationship (@not_okay_subj_relationships_to_follow) {
    $string .= "${spaces}  SEEN SUBJ: the above feature " . $relationship->get_type()->get_name() . " " . $relationship->get_subject()->get_uniquename() . "\n";
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

1;

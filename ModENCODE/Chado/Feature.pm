package ModENCODE::Chado::Feature;

use strict;
use Class::Std;
use Carp qw(carp croak);
use ModENCODE::ErrorHandler qw(log_error);

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

sub BUILD {
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

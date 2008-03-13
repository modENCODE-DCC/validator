package ModENCODE::Chado::AnalysisFeature;

use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Chado::Analysis;
use ModENCODE::Chado::Feature;

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %rawscore         :ATTR( :name<rawscore>,            :default<undef> );
my %normscore        :ATTR( :name<normscore>,           :default<undef> );
my %significance     :ATTR( :name<significance>,        :default<undef> );
my %identity         :ATTR( :name<identity>,            :default<undef> );

# Relationships
my %feature          :ATTR( :get<feature>,              :default<undef> );
my %analysis         :ATTR( :get<analysis>,             :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $feature = $args->{'feature'};
  if (defined($feature)) {
    $self->set_feature($feature);
  }
  my $analysis = $args->{'analysis'};
  if (defined($analysis)) {
    $self->set_analysis($analysis);
  }
}

sub set_feature {
  my ($self, $feature) = @_;
  ($feature->isa('ModENCODE::Chado::Feature')) or Carp::confess("Can't add a " . ref($feature) . " as an feature.");
  $feature{ident $self} = $feature;
}

sub set_analysis {
  my ($self, $analysis) = @_;
  ($analysis->isa('ModENCODE::Chado::Analysis')) or Carp::confess("Can't add a " . ref($analysis) . " as an analysis.");
  $analysis{ident $self} = $analysis;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_rawscore() eq $other->get_rawscore() && $self->get_normscore() eq $other->get_normscore() && $self->get_significance() eq $other->get_significance() && $self->get_identity() eq $other->get_identity());

  if ($self->get_feature()) {
    return 0 unless $other->get_feature();
    return 0 unless $self->get_feature()->equals($other->get_feature());
  } else {
    return 0 if $other->get_feature();
  }

  if ($self->get_analysis()) {
    return 0 unless $other->get_analysis();
    return 0 unless $self->get_analysis()->equals($other->get_analysis());
  } else {
    return 0 if $other->get_analysis();
  }


  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Feature({
      'chadoxml_id' => $self->get_chadoxml_id(),
      'rawscore' => $self->get_rawscore(),
      'normscore' => $self->get_normscore(),
      'significance' => $self->get_significance(),
      'identity' => $self->get_identity(),
    });
  $clone->set_feature($self->get_feature()->clone()) if $self->get_feature();
  $clone->set_analysis($self->get_analysis()->clone()) if $self->get_analysis();
  return $clone;
}

sub to_string {
  my ($self) = @_;
  my $string = "analysisfeature(" . $self->get_rawscore() . ", " . $self->get_identity() . ")";
  $string .= " of feature " . $self->get_feature()->to_string() if $self->get_feature();
  $string .= " for " . $self->get_analysis()->to_string() if $self->get_analysis();
  return $string;
}

1;

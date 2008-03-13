package ModENCODE::Chado::Analysis;

use strict;
use Class::Std;
use Carp qw(croak carp);

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %name             :ATTR( :name<name>,                :default<undef> );
my %description      :ATTR( :name<description>,         :default<undef> );
my %program          :ATTR( :name<program>,             :default<undef> );
my %programversion   :ATTR( :name<programversion>,      :default<undef> );
my %algorithm        :ATTR( :name<algorithm>,           :default<undef> );
my %sourcename       :ATTR( :name<sourcename>,          :default<undef> );
my %sourceversion    :ATTR( :name<sourceversion>,       :default<undef> );
my %sourceuri        :ATTR( :name<sourceuri>,           :default<undef> );
my %timeexecuted     :ATTR( :name<timeexecuted>,        :default<undef> );

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless (
    $self->get_name() eq $other->get_name() && 
    $self->get_description() eq $other->get_description() &&
    $self->get_program() eq $other->get_program() &&
    $self->get_programversion() eq $other->get_programversion() &&
    $self->get_algorithm() eq $other->get_algorithm() &&
    $self->get_sourcename() eq $other->get_sourcename() &&
    $self->get_sourceversion() eq $other->get_sourceversion() &&
    $self->get_sourceuri() eq $other->get_sourceuri() &&
    $self->get_timeexecuted() eq $other->get_timeexecuted()
  );

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Feature({
      'chadoxml_id' => $self->get_chadoxml_id(),
      'name' => $self->get_name(), 
      'description' => $self->get_description(),
      'program' => $self->get_program(),
      'programversion' => $self->get_programversion(),
      'algorithm' => $self->get_algorithm(),
      'sourcename' => $self->get_sourcename(),
      'sourceversion' => $self->get_sourceversion(),
      'sourceuri' => $self->get_sourceuri(),
      'timeexecuted' => $self->get_timeexecuted(),
    });
  return $clone;
}

sub to_string {
  my ($self) = @_;
  my $string = "analysis '" . $self->get_name() . ": " . $self->get_description() . "'";
  return $string;
}

1;

package ModENCODE::Chado::Wiggle_Data;

use strict;
use Class::Std;
use Carp qw(croak carp);

# Attributes
my %chadoxml_id       :ATTR( :name<chadoxml_id>,         :default<undef> );
my %type              :ATTR( :name<type>,                :default<'wiggle_0'> );
my %name              :ATTR( :name<name>,                :default<'User Track'> );
my %visibility        :ATTR( :name<visibility>,          :default<'hide'> );
my %color             :ATTR( :name<color>,               :default<[255, 255, 255]> );
my %altColor          :ATTR( :name<altColor>,            :default<[128, 128, 128]> );
my %priority          :ATTR( :name<priority>,            :default<100> );
my %autoscale         :ATTR( :name<autoscale>,           :default<0> );
my %gridDefault       :ATTR( :name<gridDefault>,         :default<0> );
my %maxHeightPixels   :ATTR( :name<maxHeightPixels>,     :default<[128, 128, 11]> );
my %graphType         :ATTR( :name<graphType>,           :default<'bar'> );
my %viewLimits        :ATTR( :name<viewLimits>,          :default<[0, 0]> );
my %yLineMark         :ATTR( :name<yLineMark>,           :default<0.0> );
my %yLineOnOff        :ATTR( :name<yLineOnOff>,          :default<0> );
my %windowingFunction :ATTR( :name<windowingFunction>,   :default<'maximum'> );
my %smoothingWindow   :ATTR( :name<smoothingWindow>,     :default<1> );
my %data              :ATTR( :name<data>,                :default<''> );

sub to_string {
  my ($self) = @_;
  my $string = "<~wiggle~";
  $string .= " name=\"" . $self->get_name() . "\"" if $self->get_name();
  $string .= ">";
  my ($firstline) = ($self->get_data() =~ m/(.*)/);
  $string .= "$firstline";
  $string .= "</~wiggle~>";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_chadoxml_id() eq $other->get_chadoxml_id());
  return 0 unless ($self->get_type() eq $other->get_type());
  return 0 unless ($self->get_name() eq $other->get_name());
  return 0 unless ($self->get_visibility() eq $other->get_visibility());
  return 0 unless ($self->arrays_equal($self->get_color(), $other->get_color()));
  return 0 unless ($self->arrays_equal($self->get_altColor(), $other->get_altColor()));
  return 0 unless ($self->get_priority() eq $other->get_priority());
  return 0 unless ($self->get_autoscale() eq $other->get_autoscale());
  return 0 unless ($self->get_gridDefault() eq $other->get_gridDefault());
  return 0 unless ($self->arrays_equal($self->get_maxHeightPixels(), $other->get_maxHeightPixels()));
  return 0 unless ($self->get_graphType() eq $other->get_graphType());
  return 0 unless ($self->arrays_equal($self->get_viewLimits(), $other->get_viewLimits()));
  return 0 unless ($self->get_yLineMark() eq $other->get_yLineMark());
  return 0 unless ($self->get_yLineOnOff() eq $other->get_yLineOnOff());
  return 0 unless ($self->get_windowingFunction() eq $other->get_windowingFunction());
  return 0 unless ($self->get_smoothingWindow() eq $other->get_smoothingWindow());
  return 0 unless ($self->get_data() eq $other->get_data());

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Wiggle_Data({
      'chadoxml_id' => $self->get_chadoxml_id(),
      'type' => $self->get_type(),
      'name' => $self->get_name(),
      'visibility' => $self->get_visibility(),
      'color' => \@{$self->get_color()},
      'altColor' => \@{$self->get_altColor()},
      'priority' => $self->get_priority(),
      'autoscale' => $self->get_autoscale(),
      'gridDefault' => $self->get_gridDefault(),
      'maxHeightPixels' => \@{$self->get_maxHeightPixels()},
      'graphType' => $self->get_graphType(),
      'viewLimits' => \@{$self->get_viewLimits()},
      'yLineMark' => $self->get_yLineMark(),
      'yLineOnOff' => $self->get_yLineOnOff(),
      'windowingFunction' => $self->get_windowingFunction(),
      'smoothingWindow' => $self->get_smoothingWindow(),
      'data' => $self->get_data(),
    });
  return $clone;
}

sub arrays_equal : PRIVATE {
  my ($self, $a, $b) = @_;
  if (ref($a) != "ARRAY" || ref($b) != "ARRAY") {
    carp "Trying to use Wiggle_Data::arrays_equal() on non-arrays";
    return 0;
  }
  if (scalar(@$a) != scalar(@$b)) {
    return 0;
  }
  $b = \@{$b}; # Make a copy
  for (my $i = 0; $i < scalar(@$a); $i++) {
    my $elem = $a->[$i];
    for (my $j = 0; $j < scalar(@$b); $j++) {
      if ($elem eq $b->[$j]) {
        splice(@$b, $i, 1);
        last;
      }
    }
  }
  if (scalar(@$b) > 0) {
    return 0;
  }
  return 1;
}

1;

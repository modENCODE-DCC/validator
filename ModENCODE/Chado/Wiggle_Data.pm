package ModENCODE::Chado::Wiggle_Data;

use strict;
use Class::Std;
use Carp qw(croak);

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
my %data              :ATTR( :name<data> );

sub to_string {
  my ($self) = @_;
  my $string = $self->get_name();
  $string .= "(" if (defined($self->get_url()) || defined($self->get_description()));
  $string .= $self->get_description() . ":" if defined($self->get_description());
  $string .= $self->get_url() if defined($self->get_url());
  $string .= ")" if (defined($self->get_url()) || defined($self->get_description()));
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name());

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Wiggle_Data({
      'name' => $self->get_name(),
      'url' => $self->get_url(),
      'description' => $self->get_description(),
    });
  return $clone;
}

1;

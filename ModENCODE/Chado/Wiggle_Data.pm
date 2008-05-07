package ModENCODE::Chado::Wiggle_Data;
=pod

=head1 NAME

ModENCODE::Chado::Wiggle_Data - A class representing a simplified Chado
I<wiggle_data> object. B<NOTE:> The wiggle_data table only exists in
Chado instances with the BIR-TAB extension installed.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<wiggle_data> table. It provides accessors for the various attributes of a
Wiggle-format file that are stored in the wiggle_data table itself.

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
ModENCODE::Chado::Wiggle_Data({ 'name' =E<gt> 'Continuous Data', 'data' =E<gt>
"chrX 1001 1002 101.1\nchrX 1003 1004 19.5" });> will create a new Wiggle_Data
object with a name of 'Continuous Data' and a two data points as per the
wiggle format: L<http://genome.ucsc.edu/goldenPath/help/wiggle.html>.

=back

=head2 Using ModENCODE::Chado::Wiggle_Data

=over

  my $wiggle_data = new ModENCODE::Chado::Wiggle_Data({
    # Simple attributes
    'chadoxml_id'       => 'Wiggle_Data_111',
    'type'              => 'wiggle_0',
    'name'              => 'User Track',
    'visibility'        => 'hide',
    'color'             => [255, 255, 255],
    'altColor'          => [128, 128, 128],
    'priority'          => 100,
    'autoscale'         => 0,
    'gridDefault'       => 0,
    'maxHeightPixels'   => [128, 128, 11],
    'graphType'         => 'bar',
    'viewLimits'        => [0, 0],
    'yLineMark'         => 0.0,
    'yLineOnOff'        => 0,
    'windowingFunction' => 'maximum',
    'smoothingWindow'   => 1,
    'data'              => "chrX 1001 1002 101.1\nchrX 1003 1004 19.5"
  });

  $wiggle_data->set_name('a name');
  my $name = $wiggle_data->get_name();
  print $wiggle_data->to_string();

=back

=head1 ACCESSORS

=over

=item get_chadoxml_id() | set_chadoxml_id($chadoxml_id)

The I<chadoxml_id> is used by L<ModENCODE::Chado::XMLWriter> to keep track of
the ChadoXML Macro ID (used to refer to the same feature in XML multiple times).
It is also populated when using L<ModENCODE::Parser::Chado> to pull data out of
a Chado database. (Note that the XMLWriter will generate new I<chadoxml_id>s in
this case; it does so whenever the I<chadoxml_id> is purely numeric.

=item get_type() | set_type($type)

The type of this Chado wiggle data file; it corresponds to the wiggle_data.type
field in a Chado database.

=item get_name() | set_name($name)

The name of this Chado wiggle data file; it corresponds to the wiggle_data.name
field in a Chado database.

=item get_visibility() | set_visibility($visibility)

The visibility of this Chado wiggle data file; it corresponds to the
wiggle_data.visibility field in a Chado database.

=item get_color() | set_color($color)

The color of this Chado wiggle data file; it corresponds to the
wiggle_data.color field in a Chado database.

=item get_altColor() | set_altColor($altColor)

The altColor of this Chado wiggle data file; it corresponds to the
wiggle_data.altColor field in a Chado database.

=item get_priority() | set_priority($priority)

The priority of this Chado wiggle data file; it corresponds to the
wiggle_data.priority field in a Chado database.

=item get_autoscale() | set_autoscale($autoscale)

The autoscale of this Chado wiggle data file; it corresponds to the
wiggle_data.autoscale field in a Chado database.

=item get_gridDefault() | set_gridDefault($gridDefault)

The gridDefault of this Chado wiggle data file; it corresponds to the
wiggle_data.gridDefault field in a Chado database.

=item get_maxHeightPixels() | set_maxHeightPixels($maxHeightPixels)

The maxHeightPixels of this Chado wiggle data file; it corresponds to the
wiggle_data.maxHeightPixels field in a Chado database.

=item get_graphType() | set_graphType($graphType)

The graphType of this Chado wiggle data file; it corresponds to the
wiggle_data.graphType field in a Chado database.

=item get_viewLimits() | set_viewLimits($viewLimits)

The viewLimits of this Chado wiggle data file; it corresponds to the
wiggle_data.viewLimits field in a Chado database.

=item get_yLineMark() | set_yLineMark($yLineMark)

The yLineMark of this Chado wiggle data file; it corresponds to the
wiggle_data.yLineMark field in a Chado database.

=item get_yLineOnOff() | set_yLineOnOff($yLineOnOff)

The yLineOnOff of this Chado wiggle data file; it corresponds to the
wiggle_data.yLineOnOff field in a Chado database.

=item get_windowingFunction() | set_windowingFunction($windowingFunction)

The windowingFunction of this Chado wiggle data file; it corresponds to the
wiggle_data.windowingFunction field in a Chado database.

=item get_smoothingWindow() | set_smoothingWindow($smoothingWindow)

The smoothingWindow of this Chado wiggle data file; it corresponds to the
wiggle_data.smoothingWindow field in a Chado database.

=item get_data() | set_data($data)

The data of this Chado wiggle data file; it corresponds to the wiggle_data.data
field in a Chado database.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this organism and $obj are equal. Checks all attributes. Also
requires that this object and $obj are of the exact same type.  (A parent class
!= a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object. There are no complex objects that this
object can reference, so this just creates a copy of the existing attributes.

=item to_string()

Return a string representation of this wiggle data file.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Data>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

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

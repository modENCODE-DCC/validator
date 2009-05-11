package ModENCODE::Chado::Analysis;
=pod

=head1 NAME

ModENCODE::Chado::Analysis - A class representing a simplified Chado
I<analysis> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<analysis> table. It provides accessors for the various attributes of
an analysis that are stored in the analysis table itself.

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_program()|/get_program() |
set_program($program)> or $obj->L<set_program()|/get_program() |
set_program($program)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, 
C<my $obj = new ModENCODE::Chado::Analysis({ 'program' =E<gt> 'RACE', 'programversion' =E<gt> 1 });>
will create a new Analysis object with a program of 'RACE' and a programversion
of 19.

=back

=head2 Using ModENCODE::Chado::Analysis

=over

  my $analysis = new ModENCODE::Chado::Analysis({
    # Simple attributes
    'chadoxml_id'       => 'Analysis_111',
    'name'              => 'BLAST v. 1-FASTA foo.fa-NR',
    'description'       => 'BLAST version 1 used on FASTA foo.fa vs. NR database',
    'program'           => 'BLAST',
    'programversion'    => 1,
    'algorithm'         => 'blast',
    'sourcename'        => 'NR',
    'sourceversion'     => 1,
    'sourceuri'         => 'http://ncbi.nlm.nih.gov',
    'timeexecuted'      => '2008-01-24 14:22:01'
  });

  $analysisfeature->set_program('New Program');
  my $program = $analysisfeature->get_program();
  print $analysis->to_string();


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

The name of this Chado analysis; it corresponds to the analysis.name
field in a Chado database.

=item get_description() | set_description($description)

The description of this Chado analysis; it corresponds to the
analysis.description field in a Chado database.

=item get_program() | set_program($program)

The program of this Chado analysis; it corresponds to the analysis.program
field in a Chado database.

=item get_programversion() | set_programversion($programversion)

The programversion of this Chado analysis; it corresponds to the
analysis.programversion field in a Chado database.

=item get_algorithm() | set_algorithm($algorithm)

The algorithm of this Chado analysis; it corresponds to the analysis.algorithm
field in a Chado database.

=item get_sourcename() | set_sourcename($sourcename)

The sourcename of this Chado analysis; it corresponds to the analysis.sourcename
field in a Chado database.

=item get_sourceversion() | set_sourceversion($sourceversion)

The sourceversion of this Chado analysis; it corresponds to the
analysis.sourceversion field in a Chado database.

=item get_sourceuri() | set_sourceuri($sourceuri)

The sourceuri of this Chado analysis; it corresponds to the analysis.sourceuri
field in a Chado database.

=item get_timeexecuted() | set_timeexecuted($timeexecuted)

The timeexecuted of this Chado analysis; it corresponds to the
analysis.timeexecuted field in a Chado database. Should be in a format that Perl
L<DBI> can understand as a timestamp, for instance C<2008-02-21 14:45:01>.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this analysis and $obj are equal. Checks all attributes. Also
requires that this object and $obj are of the exact same type.  (A parent class
!= a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object. There are no complex objects that this
object can reference, so this just creates a copy of the existing attributes.

=item to_string()

Return a string representation of this analysis.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::AnalysisFeature>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.


=cut

use strict;
use Class::Std;
use Carp qw(croak carp);

# Attributes
my %analysis_id      :ATTR( :name<id>,                  :default<undef> );
my %program          :ATTR( :get<program>,              :init_arg<program> );
my %programversion   :ATTR( :get<programversion>,       :init_arg<programversion> );
my %sourcename       :ATTR( :get<sourcename>,           :init_arg<sourcename>, :default<''> );

my %name             :ATTR( :name<name>,                :default<undef> );
my %description      :ATTR( :name<description>,         :default<undef> );
my %algorithm        :ATTR( :name<algorithm>,           :default<undef> );
my %sourceversion    :ATTR( :name<sourceversion>,       :default<undef> );
my %sourceuri        :ATTR( :name<sourceuri>,           :default<undef> );
my %timeexecuted     :ATTR( :name<timeexecuted>,        :default<undef> );

sub new_no_cache {
  return Class::Std::new(@_);
}

sub new {
  my $temp = Class::Std::new(@_);
  return new ModENCODE::Cache::Analysis({'content' => $temp }) if ModENCODE::Cache::get_paused();
  my $cached_analysis = ModENCODE::Cache::get_cached_analysis($temp);

  if ($cached_analysis) {
    # Update any cached analysis
    my $need_save = 0;

    if ($temp->get_name && !($cached_analysis->get_object->get_name)) {
      $cached_analysis->get_object->set_name($temp->get_name);
      $need_save = 1;
    }
    if ($temp->get_description && !($cached_analysis->get_object->get_description)) {
      $cached_analysis->get_object->set_description($temp->get_description);
      $need_save = 1;
    }
    if ($temp->get_algorithm && !($cached_analysis->get_object->get_algorithm)) {
      $cached_analysis->get_object->set_algorithm($temp->get_algorithm);
      $need_save = 1;
    }
    if ($temp->get_sourceversion && !($cached_analysis->get_object->get_sourceversion)) {
      $cached_analysis->get_object->set_sourceversion($temp->get_sourceversion);
      $need_save = 1;
    }
    if ($temp->get_sourceuri && !($cached_analysis->get_object->get_sourceuri)) {
      $cached_analysis->get_object->set_sourceuri($temp->get_sourceuri);
      $need_save = 1;
    }
    if ($temp->get_timeexecuted && !($cached_analysis->get_object->get_timeexecuted)) {
      $cached_analysis->get_object->set_timeexecuted($temp->get_timeexecuted);
      $need_save = 1;

    }
    ModENCODE::Cache::save_analysis($cached_analysis->get_object) if $need_save;
    return $cached_analysis;
  }

  # This is a new analysis
  my $self = $temp;
  return ModENCODE::Cache::add_analysis_to_cache($self);
}


sub to_string {
  my ($self) = @_;
  my $string = "analysis '" . $self->get_name() . ": " . $self->get_sourcename() . "'";
  $string .= " (" . $self->get_program() . "." . $self->get_programversion() . ")";
  return $string;
}

sub save {
  ModENCODE::Cache::save_analysis(shift);
}

1;

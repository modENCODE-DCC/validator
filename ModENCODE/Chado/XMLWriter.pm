package ModENCODE::Chado::XMLWriter;
=pod

=head1 NAME

ModENCODE::Chado::XMLWriter - Class for writing L<stag-storenode.pl>-compatible
ChadoXML for loading an L<ModENCODE::Chado::Experiment> object into a Chado
database with the BIR-TAB extension installed.

=head1 SYNOPSIS

This class is used to write ChadoXML compatible with a Chado database with the
BIR-TAB extension installed. It is known to work with the L<stag-storenode.pl>
utility distributed with L<DBIx::DBStag>, and may be compatible with
L<XML::Xort>. It can be used to write either an entire
L<Experiment|ModENCODE::Chado::Experiment> object, or single features at a time
(see L</PREWRITTEN FEATURES>).

=head1 USAGE

The usual use of C<XMLWriter> is to write an entire
L<ModENCODE::Chado::Experiment> object out to ChadoXML in preparation for
loading it. This is done with the L</write_chadoxml($experiment)> method. By
default, the XML will be written to C<STDOUT>, but you can set the L<output
handle|/get_output_handle() | set_output_handle($file_handle)> if you want to
output to a file.

  open FH, "+>output.xml";
  my $xmlwriter = new ModENCODE::Chado::XMLWriter({
    'output_handle' => \*FH
  });
  $xmlwriter->write_chadoxml($experiment)

The ChadoXML generated utilizes the "macro" syntax of ChadoXML; most elements
(in particular, features) are only printed in full once, and thereafter referred
to by their I<id>s. For instance:

  <feature id="Feature_1">
    <name>Some feature</name>
    ...
  </feature>
  <feature_relationship>
    <object_id>Feature_1</object_id>
    <subject_id>
      <feature>
        <name>Another feature</name>
        ...
      </feature>
    </subject_id>
  </feature_relationship>

You can also use an C<XMLWriter> to write out single features and their attached
data (which may include related features) using
L</write_standalone_feature($feature)>. Note that unlike
L</write_chadoxml($experiment)>, this will not writer the C<E<lt>chadoxmlE<gt>>
start and end tags.

=head2 Macro IDs

As part of generating "macro" syntax, an C<XMLWriter> will alter many of the
L<ModENCODE::Chado|index> objects being written by setting the C<chadoxml_id>
field to track the macro I<id>. The features you pass in will therefore not be
identical after writing them; they will have newly set C<chadoxml_id>s unless
they were set beforehand. Any C<chadoxml_id>s created by this parser will be of
the form C<FeatureType_123>.

L<ModENCODE::Parser::Chado> also sets C<chadoxml_id>s to the internal database
IDs, which are purely numberic. Since this would otherwise cause the XMLWriter
to never write out the full versions of those features, purely numeric
C<chadoxml_id>s are treated the same as blank ones, and replaced with
C<FeatureType_123> style IDs.

=head1 PREWRITTEN FEATURES

In order to cut down on memory usage, some modules (such as
L<ModENCODE::Validator::Data::dbEST_acc>) use C<XMLWriter> to write out features
to temporary files as they are validated. Each module will use its own
C<XMLWriter>, with its own L<file handle|/get_output_handle() |
set_output_handle($file_handle)>. In order to merge all these files together,
the calling module should call the static method
L</add_additional_xml_writer($writer)>, like so:

  my $pre_feature = new ModENCODE::Chado::Feature(\%attribs);
  my $pre_writer = new ModENCODE::Chado::XMLWriter();
  $pre_writer->set_output_handle($tmp_file);

  # Can use both static or instance version of method:
  $pre_writer->add_additional_xml_writer($pre_writer);
  # OR
  ModENCODE::Chado::XMLWriter::add_additional_xml_writer($pre_writer);

  # Write the feature to the temporary file
  $pre_writer->write_standalone_feature($pre_feature);

Whenever any C<XMLWriter>'s L</write_chadoxml($experiment)> method is called, it
will first iterate through the "additional" C<XMLWriter>s and copy the contents
of their output files into the beginning of the ChadoXML being written.

  $main_writer->write_chadoxml($experiment);

The resulting ChadoXML will look like:

  <chadoxml>
    <!-- begin imported section -->
    <feature id="Feature_1">
      <name>Prewritten feature</name>
      ...
    </feature>
    <!-- end imported section -->
    <experiment>
      ...
      <feature id="Feature_2">
        <name>Feature from experiment object</name>
        ...
        <feature_relationship>
          <feature_id>Feature_1</feature>
          ...
        </feature_relationship>
      </feature>
    </experiment>
  </chadoxml>

Note that any L<Features|ModENCODE::Chado::Feature> in the main
L<Experiment|ModENCODE::Chado::Experiment> object will have been replaced with
placeholder features with only the
L<chadoxml_id|ModENCODE::Chado::Feature/get_chadoxml_id() |
set_chadoxml_id($chadoxml_id)> set. Thus, when the main C<XMLWriter> attempts to
print the feature, it will just print the ChadoXML Macro ID as it will with any
other features that have been previously printed.

=head1 FUNCTIONS

=over

=item get_indent_width() | set_indent_width($width)

Get or set the number of spaces to indent each level of the XML. Default is two
(2) spaces. Note that spaces don't really matter to XML parsers, so changing
this is purely for readability (or possibly overzealous storage-optimization).

=item get_output_handle() | set_output_handle($file_handle)

Get a reference to the filehandle that any XML output will be written to. For
XMLWriters where you will use L</write_standalone_feature($feature)>, this should
probably be a temporary file generated with L<File::Temp>. It should I<not> be
C<STDERR> or C<STDOUT> or another write-only handle. For
L</write_chadoxml($experiment)>, this can be any file that can be written to
(including C<STDERR> and C<STDOUT>).

=item add_additional_xml_writer($writer)

Static method that adds the C<XMLWriter> passed in as C<$writer> to a private
static array of C<XMLWriter>s. The L</write_chadoxml($experiment)> method then
gets the file handles associated with those C<XMLWriter>s (using
L<get_output_handle()|/get_output_handle() | set_output_handle($file_handle)>,
pulls the content from them, and writes it to the current C<XMLWriters> output
handle.

=item write_chadoxml($experiment)

Writes out the L<ModENCODE::Chado::Experiment> object in C<$experiment> as
ChadoXML. Additionally, if there are any C<XMLWriter>s that were passed to the static
method L</add_additional_xml_writer($writer)>, then the XML content they have
written is inserted immediately after the opening C<E<lt>chadoxmlE<gt>>.

=item write_standalone_feature($feature)

Writes out a L<ModENCODE::Chado::Feature> and any associated objects (which may
include other features, relationships, etc.) as ChadoXML, and adds
C<chadoxml_id>s to the features created that can be used later as ChadoXML
"macro" IDs. (See L</Macro IDs>.) Note that any XML fragments written with this
function is not wrapped inside a C<E<lt>chadoxmlE<gt>> block and is thus not a
valid XML document.

=back

=SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Experiment>, L<ModENCODE::Chado::Feature>,
L<File::Temp>, L<XML::Xort>, L<stag-storenode.pl>

=AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use HTML::Entities ();
use ModENCODE::ErrorHandler qw(log_error);

my %indent              :ATTR(                             :default<0> );
my %indent_width        :ATTR( :name<indent_width>,        :default<2> );
my %data_this_proto     :ATTR(                             :default<{ 'input' => [], 'output' => []> });
my %seen_relationships  :ATTR(                             :default<{}> );
my %all_relationships   :ATTR(                             :default<[]> );
my %delayed_writes      :ATTR(                             :default<[]> );
my %output_handle       :ATTR( :name<output_handle>,       :default<\*STDOUT> );
my $current_uniqid = 0;
my $additional_xml_writers = [];

# Semi-macro-ified version (protocols are macro-d, data isn't)
sub add_additional_xml_writer {
  my $xml_writer = shift;
  $xml_writer = shift if length(@_); # Allow use as either static or object method
  push @$additional_xml_writers, $xml_writer;
}

sub write_chadoxml {
  my ($self, $experiment) = @_;
  $self->set_indent(0);
  $self->clear_seen_data();
  $self->println("<chadoxml>");
  $delayed_writes{ident $self} = [];

  # Append things from additional element files (already-written features)
  foreach my $xml_writer (@$additional_xml_writers) {
    $self->println("<!-- begin imported section -->");
    my $fh = $xml_writer->get_output_handle();
    seek($fh, 0, 0);
    while (my $line = <$fh>) {
      $line =~ s/^\s*|\s*[\n\r]*$//g;
      $self->println($line);
    }
    $self->println("<!-- end imported section -->");
  }

  # Write all of the dbxrefs
  log_error "Writing dbxrefs.", "notice", ">";
  my $all_dbxrefs = ModENCODE::Chado::DBXref::get_all_dbxrefs();
  foreach my $db (keys(%$all_dbxrefs)) {
    foreach my $accession (keys(%{$all_dbxrefs->{$db}})) {
      foreach my $version (keys(%{$all_dbxrefs->{$db}->{$accession}})) {
        my $dbxref = $all_dbxrefs->{$db}->{$accession}->{$version};
        $dbxref->set_chadoxml_id($self->generate_uniqid("DBXref"));
        $self->write_dbxref($dbxref);
      }
    }
  }
  log_error "Done.", "notice", "<";

  log_error "Writing controlled vocabulary terms.", "notice", ">";
  # Write all of the cvterms
  my $all_cvterms = ModENCODE::Chado::CVTerm::get_all_cvterms();
  foreach my $cv (keys(%$all_cvterms)) {
    foreach my $term (keys(%{$all_cvterms->{$cv}})) {
      foreach my $is_obsolete (keys(%{$all_cvterms->{$cv}->{$term}})) {
        my $cvterm = $all_cvterms->{$cv}->{$term}->{$is_obsolete};
        $cvterm->set_chadoxml_id($self->generate_uniqid("CVTerm"));
        $self->write_cvterm($cvterm);
      }
    }
  }
  log_error "Done.", "notice", "<";

  log_error "Writing Chado features.", "notice", ">";
  # Write all of the features
  $all_relationships{ident $self} = [];
  my $all_features = ModENCODE::Chado::Feature::get_all_features();
  foreach my $feature (@$all_features) {
    $feature->set_chadoxml_id($self->generate_uniqid("Feature"));
    $self->write_feature($feature);
  }
  log_error "Done.", "notice", "<";

  log_error "Writing feature relationships.", "notice", ">";
  # Write all of the feature relationships
  foreach my $relationship (@{$all_relationships{ident $self}}) {
    $self->write_feature_relationship($relationship);
  }
  undef @{$all_relationships{ident $self}};
  log_error "Done.", "notice", "<";

  log_error "Writing protocol definitions.", "notice", ">";
  # Write all of the protocols
  my @seen_protocols;
  for (my $i = 0; $i < $experiment->get_num_applied_protocol_slots(); $i++) {
    my $applied_protocols = $experiment->get_applied_protocols_at_slot($i);
    foreach my $applied_protocol (@$applied_protocols) {
      my $protocol = $applied_protocol->get_protocol();
      my $seen_protocol;
      if (!scalar(($seen_protocol) = grep { $_->equals($protocol) } @seen_protocols)) {
        $protocol->set_chadoxml_id($self->generate_uniqid("Protocol"));
        $self->write_protocol($protocol);
        push @seen_protocols, $protocol;
      } else {
        $protocol->set_chadoxml_id($seen_protocol->get_chadoxml_id());
      }
    }
  }
  log_error "Done.", "notice", "<";

  log_error "Writing applied protocols.", "notice", ">";
  # Write all of the applied protocols
  for (my $i = 0; $i < $experiment->get_num_applied_protocol_slots(); $i++) {
    my $applied_protocols = $experiment->get_applied_protocols_at_slot($i);
    foreach my $applied_protocol (@$applied_protocols) {
      $applied_protocol->set_chadoxml_id($self->generate_uniqid("AppliedProtocol"));
      $self->write_applied_protocol($applied_protocol);
    }
    $self->shift_seen_data()
  }
  log_error "Done.", "notice", "<";

  # Write the experiment
  log_error "Writing experiment definition.", "notice", ">";
  $experiment->set_chadoxml_id($self->generate_uniqid("Experiment"));
  $self->println("<experiment id=\"" . $experiment->get_chadoxml_id() . "\">");
  $self->println("<description>" . xml_escape($experiment->get_description()) . "</description>");
  $self->println("<uniquename>" . xml_escape($experiment->get_uniquename()) . "</uniquename>");
  foreach my $applied_protocol (@{$experiment->get_applied_protocols_at_slot(0)}) {
    $self->println("<experiment_applied_protocol>");
    $self->println("<first_applied_protocol_id>" . $applied_protocol->get_chadoxml_id() . "</first_applied_protocol_id>");
    $self->println("</experiment_applied_protocol>");
  }
  log_error "Done.", "notice", "<";
  
  $self->println("</experiment>");
  # Write the experiment properties
  foreach my $experiment_property (@{$experiment->get_properties()}) {
    $self->write_experiment_prop($experiment_property, $experiment);
  }
  # Do delayed writes
  $self->write_delayed_writes();



  $self->println("</chadoxml>");
}

sub write_delayed_writes : PRIVATE {
  my ($self) = @_;
  foreach my $delayed_write (@{$delayed_writes{ident $self}}) {
    &$delayed_write();
  }
}

sub write_applied_protocol : PRIVATE {
  my ($self, $applied_protocol) = @_;
  
  $self->println("<applied_protocol id=\"" . $applied_protocol->get_chadoxml_id() . "\">");
  $self->println("<protocol_id>" . $applied_protocol->get_protocol()->get_chadoxml_id() . "</protocol_id>");
  for (my $i = 0; $i < scalar(@{$applied_protocol->get_input_data()}); $i++) {
    my $datum = $applied_protocol->get_input_data()->[$i];
    my $seen_datum = $self->seen_datum($datum, 'input');
    $self->println("<applied_protocol_data>");
    $self->println("<direction>input</direction>");
    if ($seen_datum) {
      # Replace existing data with this one that is equal
      $applied_protocol->get_input_data()->[$i] = $seen_datum;
      $self->println("<data_id>" . $seen_datum->get_chadoxml_id() . "</data_id>");
    } else {
      $datum->set_chadoxml_id($self->generate_uniqid("Datum"));
      $self->add_seen_datum($datum, 'input');
      $self->println("<data_id>");
      $self->write_datum($datum);
      $self->println("</data_id>");
    }
    $self->println("</applied_protocol_data>");
  }
  for (my $i = 0; $i < scalar(@{$applied_protocol->get_output_data()}); $i++) {
    my $datum = $applied_protocol->get_output_data()->[$i];
    my $seen_datum = $self->seen_datum($datum, 'output');
    $self->println("<applied_protocol_data>");
    $self->println("<direction>output</direction>");
    if ($seen_datum) {
      # Replace existing data with this one that is equal
      $applied_protocol->get_output_data()->[$i] = $seen_datum;
      $self->println("<data_id>" . $seen_datum->get_chadoxml_id() . "</data_id>");
    } else {
      $datum->set_chadoxml_id($self->generate_uniqid("Datum"));
      $self->add_seen_datum($datum, 'output');
      $self->println("<data_id>");
      $self->write_datum($datum);
      $self->println("</data_id>");
    }
    $self->println("</applied_protocol_data>");
  }
  $self->println("</applied_protocol>");

}

sub write_protocol : PRIVATE {
  my ($self, $protocol) = @_;
  $self->println("<protocol id=\"" . $protocol->get_chadoxml_id() . "\">");
  $self->println("<name>" . xml_escape($protocol->get_name()) . "</name>");
  $self->println("<version>" . xml_escape($protocol->get_version()) . "</version>");
  $self->println("<description>" . xml_escape($protocol->get_description()) . "</description>");

  foreach my $attribute (@{$protocol->get_attributes()}) {
    $self->println("<protocol_attribute>");
    $self->println("<attribute_id>");
    $self->write_attribute($attribute);
    $self->println("</attribute_id>");
    $self->println("</protocol_attribute>");
  }

  if ($protocol->get_termsource()) {
    $self->println("<dbxref_id>" . $protocol->get_termsource()->get_chadoxml_id() . "</dbxref_id>");
  }

  $self->println("</protocol>");
}

sub write_experiment_prop : PRIVATE {
  my ($self, $experiment_prop, $experiment) = @_;
  $self->println("<experiment_prop>");
  $self->println("<experiment_id>" . $experiment->get_chadoxml_id() . "</experiment_id>");
  $self->println("<name>" . xml_escape($experiment_prop->get_name()) . "</name>");
  $self->println("<value>" . xml_escape($experiment_prop->get_value()) . "</value>");
  $self->println("<rank>" . xml_escape($experiment_prop->get_rank()) . "</rank>");
  if ($experiment_prop->get_termsource()) {
    $self->println("<dbxref_id>" . $experiment_prop->get_termsource()->get_chadoxml_id() . "</dbxref_id>");
  }

  if ($experiment_prop->get_type()) {
    $self->println("<type_id>" . $experiment_prop->get_type()->get_chadoxml_id() . "</type_id>");
  }
  $self->println("</experiment_prop>");
}

sub write_datum : PRIVATE {
  my ($self, $datum) = @_;
  $self->println("<data id=\"" . $datum->get_chadoxml_id() . "\">");
  $self->println("<name>" . xml_escape($datum->get_name()) . "</name>");
  $self->println("<heading>" . xml_escape($datum->get_heading()) . "</heading>");
  $self->println("<value>" . xml_escape($datum->get_value()) . "</value>");

  if ($datum->get_termsource()) {
    $self->println("<dbxref_id>" . $datum->get_termsource()->get_chadoxml_id() . "</dbxref_id>");
  }

  if ($datum->get_type()) {
    $self->println("<type_id>" . $datum->get_type()->get_chadoxml_id() . "</type_id>");
  }

  foreach my $feature (@{$datum->get_features()}) {
    $self->println("<data_feature>");
      $self->println("<feature_id>" . $feature->get_chadoxml_id() . "</feature_id>");
    $self->println("</data_feature>");
  }

  foreach my $wiggle_data (@{$datum->get_wiggle_datas()}) {
    $self->println("<data_wiggle_data>");
    if ($wiggle_data->get_chadoxml_id() && $wiggle_data->get_chadoxml_id() !~ /^\d+$/) {
      $self->println("<wiggle_data_id>" . $wiggle_data->get_chadoxml_id() . "</wiggle_data_id>");
    } else {
      $wiggle_data->set_chadoxml_id($self->generate_uniqid("Wiggle_Data"));
      $self->println("<wiggle_data_id>");
      $self->write_wiggle_data($wiggle_data);
      $self->println("</wiggle_data_id>");
    }
    $self->println("</data_wiggle_data>");
  }

  foreach my $organism (@{$datum->get_organisms()}) {
    $self->println("<data_organism>");
    $self->println("<organism_id>");
    $self->write_organism($organism);
    $self->println("</organism_id>");
    $self->println("</data_organism>");
  }

  foreach my $attribute (@{$datum->get_attributes()}) {
    $self->println("<data_attribute>");
    $self->println("<attribute_id>");
    $self->write_attribute($attribute);
    $self->println("</attribute_id>");
    $self->println("</data_attribute>");
  }

  $self->println("</data>");
}

sub write_standalone_feature {
  my ($self, $feature) = @_;
  unless ($feature->get_chadoxml_id() && $feature->get_chadoxml_id() !~ /^\d+$/) {
    $feature->set_chadoxml_id($self->generate_uniqid("Feature"));
    $self->write_feature($feature);
  }
  return $feature->get_chadoxml_id();
}

sub write_feature : PRIVATE {
  my ($self, $feature) = @_;
  $self->println("<feature id=\"" . $feature->get_chadoxml_id() . "\">");
  $self->println("<name>" . xml_escape($feature->get_name()) . "</name>");
  $self->println("<uniquename>" . xml_escape($feature->get_uniquename()) . "</uniquename>");
  $self->println("<residues>" . xml_escape($feature->get_residues()) . "</residues>");
  $self->println("<seqlen>" . xml_escape($feature->get_seqlen()) . "</seqlen>") if length($feature->get_seqlen());
  $self->println("<timeaccessioned>" . xml_escape($feature->get_timeaccessioned()) . "</timeaccessioned>") if length($feature->get_timeaccessioned());
  $self->println("<timelastmodified>" . xml_escape($feature->get_timelastmodified()) . "</timelastmodified>") if length($feature->get_timelastmodified());
  $self->println("<is_analysis>" . xml_escape($feature->get_is_analysis()) . "</is_analysis>") if length(xml_escape($feature->get_is_analysis()));

  if ($feature->get_type()) {
    $self->println("<type_id>" . $feature->get_type()->get_chadoxml_id() . "</type_id>");
  }
  if ($feature->get_organism()) {
    $self->println("<organism_id>");
    $self->write_organism($feature->get_organism());
    $self->println("</organism_id>");
  }
  if ($feature->get_primary_dbxref()) {
    $self->println("<dbxref_id>" . $feature->get_primary_dbxref()->get_chadoxml_id() . "</dbxref_id>");
  }
  foreach my $feature_dbxref (@{$feature->get_dbxrefs()}) {
    $self->println("<feature_dbxref>");
    $self->println("<dbxref_id>" . $feature_dbxref->get_chadoxml_id() . "</dbxref_id>");
    $self->println("</feature_dbxref>");
  }
  foreach my $feature_location (@{$feature->get_locations()}) {
    $self->write_featureloc_later_for_feature($feature_location, $feature);
  }
  foreach my $analysisfeature (@{$feature->get_analysisfeatures()}) {
    $self->write_analysisfeature_later_for_feature($analysisfeature, $feature);
  }
  if ($feature->get_relationships()) {
    foreach my $feature_relationship (@{$feature->get_relationships()}) {
      # Save this feature relationship to write later
      push @{$all_relationships{ident $self}}, $feature_relationship;
    }
  }
  $self->println("</feature>");
}

sub write_feature_relationship : PRIVATE {
  my ($self, $feature_relationship, $feature_parent) = @_;
  
  my $subject = $feature_relationship->get_subject();
  my $object = $feature_relationship->get_object();

  if ($subject xor $object) {
    log_error "Attempting to write a feature_relationship with a subject but no object or vice versa.", "error";
    exit;
  }

  my $seen_subject = 1;
  my $seen_object = 1;
  if (!$subject->get_chadoxml_id() || $subject->get_chadoxml_id() =~ /^\d+$/) {
    $seen_subject = 0;
    $subject->set_chadoxml_id($self->generate_uniqid("Feature"));
  }
  if (!$object->get_chadoxml_id() || $object->get_chadoxml_id() =~ /^\d+$/) {
    $seen_object = 0;
    $object->set_chadoxml_id($self->generate_uniqid("Feature"));
  }

  if (!$self->seen_relationship($subject, $object, $feature_relationship->get_type())) {
    $self->add_seen_relationship($subject, $object, $feature_relationship->get_type());

    $self->println("<feature_relationship>");
    $self->println("<rank>" . xml_escape($feature_relationship->get_rank()) . "</rank>") if length($feature_relationship->get_rank());
    if ($feature_relationship->get_type()) {
      $self->println("<type_id>" . $feature_relationship->get_type()->get_chadoxml_id() . "</type_id>");
    }
        $self->println("<subject_id>" . $subject->get_chadoxml_id() . "</subject_id>");
        $self->println("<object_id>" . $object->get_chadoxml_id() . "</object_id>");

    $self->println("</feature_relationship>");

  }
}

sub write_analysisfeature : PRIVATE {
  my ($self, $analysisfeature) = @_;
  $self->println("<analysisfeature>");
  $self->println("<rawscore>" . xml_escape($analysisfeature->get_rawscore()) . "</rawscore>") if length($analysisfeature->get_rawscore());
  $self->println("<normscore>" . xml_escape($analysisfeature->get_normscore()) . "</normscore>") if length($analysisfeature->get_normscore());
  $self->println("<significance>" . xml_escape($analysisfeature->get_significance()) . "</significance>") if length($analysisfeature->get_significance());
  $self->println("<identity>" . xml_escape($analysisfeature->get_identity()) . "</identity>") if length($analysisfeature->get_identity());
  if ($analysisfeature->get_feature()) {
      $self->println("<feature_id>" . $analysisfeature->get_feature()->get_chadoxml_id() . "</feature_id>");
  }
  if ($analysisfeature->get_analysis()) {
    if ($analysisfeature->get_analysis()->get_chadoxml_id() && $analysisfeature->get_analysis()->get_chadoxml_id() !~ /^\d+$/) {
      $self->println("<analysis_id>" . $analysisfeature->get_analysis()->get_chadoxml_id() . "</analysis_id>");
    } else {
      $analysisfeature->get_analysis()->set_chadoxml_id($self->generate_uniqid("Analysis"));
      $self->println("<analysis_id>");
      $self->write_analysis($analysisfeature->get_analysis());
      $self->println("</analysis_id>");
    }
  }
  $self->println("</analysisfeature>");
}

sub write_analysisfeature_later_for_feature : PRIVATE {
  my ($self, $analysisfeature, $feature) = @_;
  push @{$delayed_writes{ident $self}}, sub { 
    if (!$analysisfeature->get_chadoxml_id() || $analysisfeature->get_chadoxml_id() =~ /^\d+$/) {
      $analysisfeature->set_chadoxml_id($self->generate_uniqid("AnalysisFeature"));
      $self->write_analysisfeature($analysisfeature, $feature); 
    }
  };
}

sub write_featureloc_later_for_feature : PRIVATE {
  my ($self, $featureloc, $feature) = @_;
  push @{$delayed_writes{ident $self}}, sub { 
    if (!$featureloc->get_chadoxml_id() || $featureloc->get_chadoxml_id() =~ /^\d+$/) {
      $featureloc->set_chadoxml_id($self->generate_uniqid("FeatureLoc"));
      $self->write_featureloc($featureloc, $feature); 
    }
  };
}

sub write_featureloc : PRIVATE {
  my ($self, $featureloc, $feature) = @_;
  $self->println("<featureloc>");
  if ($feature) {
    croak "Cannot write featureloc feature with no chadoxml_id with feature " . $feature->_DUMP() unless $feature->get_chadoxml_id();
    $self->println("<feature_id>" . $feature->get_chadoxml_id() . "</feature_id>");
  }
  $self->println("<fmin>" . xml_escape($featureloc->get_fmin()) . "</fmin>") if length($featureloc->get_fmin());
  $self->println("<fmax>" . xml_escape($featureloc->get_fmax()) . "</fmax>") if length($featureloc->get_fmax());
  $self->println("<rank>" . xml_escape($featureloc->get_rank()) . "</rank>") if length($featureloc->get_rank());
  $self->println("<strand>" . xml_escape($featureloc->get_strand()) . "</strand>") if length($featureloc->get_strand());
  if ($featureloc->get_srcfeature()) {
      $self->println("<srcfeature_id>" . $featureloc->get_srcfeature()->get_chadoxml_id() . "</srcfeature_id>");
  }
  $self->println("</featureloc>");
}

sub write_analysis : PRIVATE {
  my ($self, $analysis) = @_;
  $self->println("<analysis id=\"" . $analysis->get_chadoxml_id() . "\">");
  $self->println("<name>" . xml_escape($analysis->get_name()) . "</name>");
  $self->println("<description>" . xml_escape($analysis->get_description()) . "</description>");
  $self->println("<program>" . xml_escape($analysis->get_program()) . "</program>");
  $self->println("<programversion>" . xml_escape($analysis->get_programversion()) . "</programversion>");
  $self->println("<algorithm>" . xml_escape($analysis->get_algorithm()) . "</algorithm>");
  $self->println("<sourcename>" . xml_escape($analysis->get_sourcename()) . "</sourcename>");
  $self->println("<sourceversion>" . xml_escape($analysis->get_sourceversion()) . "</sourceversion>");
  $self->println("<sourceuri>" . xml_escape($analysis->get_sourceuri()) . "</sourceuri>");
  $self->println("<timeexecuted>" . xml_escape($analysis->get_timeexecuted()) . "</timeexecuted>") if length($analysis->get_timeexecuted());
  $self->println("</analysis>");
}


sub write_organism : PRIVATE {
  my ($self, $organism) = @_;
  $self->println("<organism>");
  $self->println("<genus>" . xml_escape($organism->get_genus()) . "</genus>");
  $self->println("<species>" . xml_escape($organism->get_species()) . "</species>");
  $self->println("</organism>");
}

sub write_wiggle_data : PRIVATE {
  my ($self, $wiggle_data) = @_;
  $self->println("<wiggle_data id=\"" . $wiggle_data->get_chadoxml_id() . "\">");
  $self->println("<type>" . $wiggle_data->get_type() . "</type>");
  $self->println("<name>" . $wiggle_data->get_name() . "</name>");
  $self->println("<visibility>" . $wiggle_data->get_visibility() . "</visibility>");
  $self->println("<color>(" . join(", ", @{$wiggle_data->get_color()}) . ")</color>");
  $self->println("<altColor>(" . join(", ", @{$wiggle_data->get_altColor()}) . ")</altColor>");
  $self->println("<priority>" . $wiggle_data->get_priority() . "</priority>");
  $self->println("<autoscale>" . $wiggle_data->get_autoscale() . "</autoscale>");
  $self->println("<gridDefault>" . $wiggle_data->get_gridDefault() . "</gridDefault>");
  $self->println("<maxHeightPixels>(" . join(", ", @{$wiggle_data->get_maxHeightPixels()}) . ")</maxHeightPixels>");
  $self->println("<graphType>" . $wiggle_data->get_graphType() . "</graphType>");
  $self->println("<viewLimits>(" . join(", ", @{$wiggle_data->get_viewLimits()}) . ")</viewLimits>");
  $self->println("<yLineMark>" . $wiggle_data->get_yLineMark() . "</yLineMark>");
  $self->println("<yLineOnOff>" . $wiggle_data->get_yLineOnOff() . "</yLineOnOff>");
  $self->println("<windowingFunction>" . $wiggle_data->get_windowingFunction() . "</windowingFunction>");
  $self->println("<smoothingWindow>" . $wiggle_data->get_smoothingWindow() . "</smoothingWindow>");
  $self->println("<data>" . $wiggle_data->get_data() . "</data>");
  $self->println("</wiggle_data>");
}

sub write_attribute : PRIVATE {
  my ($self, $attribute) = @_;
  $self->println("<attribute>");
  $self->println("<name>" . xml_escape($attribute->get_name()) . "</name>");
  $self->println("<heading>" . xml_escape($attribute->get_heading()) . "</heading>");
  $self->println("<value>" . xml_escape($attribute->get_value()) . "</value>");
  $self->println("<rank>" . xml_escape($attribute->get_rank()) . "</rank>");

  if ($attribute->get_termsource()) {
    $self->println("<dbxref_id>" . $attribute->get_termsource()->get_chadoxml_id() . "</dbxref_id>");
  }

  if ($attribute->get_type()) {
    $self->println("<type_id>" . $attribute->get_type()->get_chadoxml_id() . "</type_id>");
  }

  foreach my $organism (@{$attribute->get_organisms()}) {
    $self->println("<attribute_organism>");
    $self->println("<organism_id>");
    $self->write_organism($organism);
    $self->println("</organism_id>");
    $self->println("</attribute_organism>");
  }

  $self->println("</attribute>");
}

sub write_cvterm : PRIVATE {
  my ($self, $cvterm) = @_;
  $self->println("<cvterm id=\"" . $cvterm->get_chadoxml_id() . "\">");
  $self->println("<name>" . xml_escape($cvterm->get_name()) . "</name>");
  $self->println("<definition>" . xml_escape($cvterm->get_definition()) . "</definition>");
  $self->println("<is_obsolete>" . xml_escape($cvterm->get_is_obsolete()) . "</is_obsolete>");
  
  if ($cvterm->get_cv()) {
    $self->println("<cv_id>");
    $self->write_cv($cvterm->get_cv());
    $self->println("</cv_id>");
  }

  if ($cvterm->get_dbxref()) {
    $self->println("<dbxref_id>" . $cvterm->get_dbxref()->get_chadoxml_id() . "</dbxref_id>");
  }

  $self->println("</cvterm>");
}

sub write_cv : PRIVATE {
  my ($self, $cv) = @_;
  $self->println("<cv>");
  $self->println("<name>" . xml_escape($cv->get_name()) . "</name>");
  $self->println("<definition>" . xml_escape($cv->get_definition()) . "</definition>");
  $self->println("</cv>");
}

sub write_dbxref : PRIVATE {
  my ($self, $dbxref) = @_;
  $self->println("<dbxref id=\"" . $dbxref->get_chadoxml_id() . "\">");
  $self->println("<accession>" . xml_escape($dbxref->get_accession()) . "</accession>");
  $self->println("<version>" . xml_escape($dbxref->get_version()) . "</version>");
  $self->println("<db_id>");
  $self->write_db($dbxref->get_db());
  $self->println("</db_id>");
  $self->println("</dbxref>");
}

sub write_db : PRIVATE {
  my ($self, $db) = @_;
  $self->println("<db>");
  $self->println("<name>" . xml_escape($db->get_name()) . "</name>");
  $self->println("<url>" . xml_escape($db->get_url()) . "</url>");
  $self->println("<description>" . xml_escape($db->get_description()) . "</description>");
  $self->println("</db>");
}

sub println {
  my ($self, $text) = @_;
  print {$output_handle{ident $self}} $text . "\n";
}

sub println_2 {
  my ($self, $text) = @_;
  my @numincs = ($text =~ m/(<[a-zA-Z])/g);
  my @numdecs = ($text =~ m/(<\/)/g);
  my $diffincs = scalar(@numincs) - scalar(@numdecs);
  for (my $i = 0; $i > $diffincs; $i--) {
    $self->dec_indent();
  }
  print {$output_handle{ident $self}} $self->indent_txt() . $text . "\n";
  for (my $i = 0; $i < $diffincs; $i++) {
    $self->inc_indent();
  }
}

sub indent_txt : PRIVATE {
  my ($self) = @_;
  my $string = "";
  for (my $i = 0; $i < $self->get_indent() * $self->get_indent_width(); $i++) {
    $string .= " ";
  }
  return $string;
}

sub set_indent : PRIVATE {
  my ($self, $new_level) = @_;
  $indent{ident $self} = $new_level;
}

sub dec_indent : PRIVATE {
  my ($self) = @_;
  carp "Decrementing indent below 0" if ($indent{ident $self} <= 0);
  $indent{ident $self} -= $self->get_indent_width();
  return $indent{ident $self};
}

sub inc_indent : PRIVATE {
  my ($self) = @_;
  $indent{ident $self} += $self->get_indent_width();
  return $indent{ident $self};
}

sub get_indent : PRIVATE {
  my ($self) = @_;
  return $indent{ident $self};
}

sub generate_uniqid : PRIVATE {
  my ($self, $prefix) = @_;
  $current_uniqid++;
  return $prefix . "_" . $current_uniqid;
}

sub clear_seen_data : PRIVATE {
  my ($self) = @_;
  $data_this_proto{ident $self} = { 'input' => [], 'output' => [] };
}

sub shift_seen_data : PRIVATE {
  my ($self) = @_;
  $data_this_proto{ident $self}->{'input'} = $data_this_proto{ident $self}->{'output'};
  $data_this_proto{ident $self}->{'output'} = [];
}

sub seen_datum : PRIVATE {
  my ($self, $datum, $direction) = @_;
  my ($seen_datum) = grep { $_->equals($datum) } @{$data_this_proto{ident $self}->{$direction}};
  return $seen_datum;
}

sub add_seen_datum : PRIVATE {
  my ($self, $datum, $direction) = @_;
  push @{$data_this_proto{ident $self}->{$direction}}, $datum;
}

sub add_seen_relationship : PRIVATE {
  my ($self, $subject, $object, $reltype) = @_;

  $seen_relationships{ident $self}->{$subject->get_chadoxml_id()} = {} unless defined($seen_relationships{ident $self}->{$subject->get_chadoxml_id()});
  $seen_relationships{ident $self}->{$subject->get_chadoxml_id()}->{$reltype->get_chadoxml_id()} = {} unless defined($seen_relationships{ident $self}->{$subject->get_chadoxml_id()}->{$reltype->get_chadoxml_id()});
  $seen_relationships{ident $self}->{$subject->get_chadoxml_id()}->{$reltype->get_chadoxml_id()}->{$object->get_chadoxml_id()} = 1;
  #push @{$seen_relationships{ident $self}}, [ $subject->get_chadoxml_id(), $object->get_chadoxml_id() ];
}

sub seen_relationship : PRIVATE {
  my ($self, $subject, $object, $reltype) = @_;
  return defined(
    $seen_relationships{ident $self}->
      {$subject->get_chadoxml_id()}->
        {$reltype->get_chadoxml_id()}->
          {$object->get_chadoxml_id()}
  );
}

sub xml_escape {
  my ($value) = @_;
  $value =~ s/>/&gt;/g;
  $value =~ s/</&lt;/g;
  $value =~ s/&/&amp;/g;
  return $value;
}

1;

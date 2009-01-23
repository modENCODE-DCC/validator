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
use File::Temp;

my %indent              :ATTR(                          :default<0> );
my %indent_width        :ATTR( :name<indent_width>,     :default<2> );
my %output_handle       :ATTR( :name<output_handle>,    :default<\*STDOUT> );
my %seen_ids            :ATTR( :name<seen_ids>,         :default<{}> );
my %tempfiles           :ATTR( :name<tempfiles>,        :default<{}> );

sub set_output_file {
  my ($self, $filename) = @_;
  log_error "(Writing submission to file $filename.)", "notice";
  return open($output_handle{ident $self}, "+>", $filename);
}

sub write_chadoxml {
  my ($self, $experiment) = @_;
  $self->set_indent(0);
  $seen_ids{ident $self} = {};
  my @tempfile_names = ('dbxrefs', 'cvterms', 'organisms', 'features', 'featurelocs', 'featureprops', 'feature_relationships', 'analyses', 'analysisfeatures', 'attributes', 'protocols', 'wiggle_data', 'data', 'default');
  foreach my $tempfile (@tempfile_names) {
    $self->get_tempfiles()->{$tempfile} = File::Temp::tempfile( DIR => ModENCODE::Config::get_cfg()->val('cache', 'tmpdir'), SUFFIX => ".chadoxml" );
  }

  # Assign IDs to and write the applied protocols
  log_error "Writing protocols and data.", "notice", ">";
  my $ap_id = 0;
  for (my $i = 0; $i < $experiment->get_num_applied_protocol_slots(); $i++) {
    my $applied_protocols = $experiment->get_applied_protocols_at_slot($i);
    foreach my $applied_protocol (@$applied_protocols) {
      $applied_protocol->set_id($ap_id++);
      $self->write_applied_protocol($applied_protocol);
    }
  }
  log_error "Done.", "notice", "<";


  # Write the experiment
  log_error "Writing experiment data.", "notice", ">";
  my $id = "experiment_" . $experiment->get_id();
  $self->println("<experiment id=\"$id\">");
  $self->println("<description>" . xml_escape($experiment->get_description()) . "</description>");
  $self->println("<uniquename>" . xml_escape($experiment->get_uniquename()) . "</uniquename>");
  foreach my $applied_protocol (@{$experiment->get_applied_protocols_at_slot(0)}) {
    $self->println("<experiment_applied_protocol>");
    $self->println("<first_applied_protocol_id>" . $self->write_applied_protocol($applied_protocol) . "</first_applied_protocol_id>");
    $self->println("</experiment_applied_protocol>");
  }
  log_error "Done.", "notice", "<";
  
  $self->println("</experiment>");

  log_error "Writing experiment properties", "notice", ">";
  # Write the experiment properties
  foreach my $experiment_property ($experiment->get_properties(1)) {
    $self->write_experiment_prop($experiment_property, $id);
  }
  log_error "Done.", "notice", "<";

  log_error "Combining temporary output files.", "notice", ">";
  # Combine temporary files into actual output
  print {$output_handle{ident $self}} "<chadoxml>\n";
  foreach my $tempfile (@tempfile_names) {
    my $tmpfh = $self->get_tempfiles()->{$tempfile};
    seek($tmpfh, 0, 0);
    while (<$tmpfh>) {
      print {$output_handle{ident $self}} $_;
    }
    close $tmpfh;
  }
  print {$output_handle{ident $self}} "</chadoxml>\n";
  log_error "Done.", "notice", "<";

}

sub write_applied_protocol : PRIVATE {
  my ($self, $applied_protocol) = @_;
  
  my $id = "applied_protocol_" . $applied_protocol->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println("<applied_protocol id=\"$id\">");
    $self->println("<protocol_id>" . $self->write_protocol($applied_protocol->get_protocol(1)) . "</protocol_id>");
    foreach my $input_datum_cache ($applied_protocol->get_input_data()) {
      my $input_datum = $input_datum_cache->get_object; # Do this here so we only load each datum as we need it
      $self->println("<applied_protocol_data>");
      $self->println("<direction>input</direction>");
      $self->println("<data_id>" . $self->write_datum($input_datum) .  "</data_id>");
      $self->println("</applied_protocol_data>");
      $input_datum_cache->set_content($input_datum_cache->get_id);
    }
    foreach my $output_datum_cache ($applied_protocol->get_output_data()) {
      my $output_datum = $output_datum_cache->get_object; # Do this here so we only load each datum as we need it
      $self->println("<applied_protocol_data>");
      $self->println("<direction>output</direction>");
      $self->println("<data_id>" . $self->write_datum($output_datum) .  "</data_id>");
      $self->println("</applied_protocol_data>");
      $output_datum_cache->set_content($output_datum_cache->get_id);
    }
    $self->println("</applied_protocol>");
  }
  return $id;

}

sub write_protocol : PRIVATE {
  my ($self, $protocol) = @_;
  my $id = "protocol_" . $protocol->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('protocols', "<protocol id=\"$id\">");
    $self->println_to('protocols', "<name>" . xml_escape($protocol->get_name()) . "</name>");
    $self->println_to('protocols', "<version>" . xml_escape($protocol->get_version()) . "</version>");
    $self->println_to('protocols', "<description>" . xml_escape($protocol->get_description()) . "</description>");

    foreach my $attribute ($protocol->get_attributes(1)) {
      $self->println_to('protocols', "<protocol_attribute>");
      $self->println_to('protocols', "<attribute_id>" . $self->write_attribute($attribute) . "</attribute_id>");
      $self->println_to('protocols', "</protocol_attribute>");
    }

    if ($protocol->get_termsource()) {
      $self->println_to('protocols', "<dbxref_id>" . $self->write_dbxref($protocol->get_termsource(1)) .  "</dbxref_id>");
    }

    $self->println_to('protocols', "</protocol>");
  }
  return $id;
}

sub write_experiment_prop : PRIVATE {
  my ($self, $experiment_prop, $experiment_id) = @_;
  my $id = "experiment_prop_" . $experiment_prop->get_id();
  if ($seen_ids{ident $self}->{$id}++) {
    $self->println("$id");
  } else {
    $self->println("<experiment_prop id=\"$id\">");
    $self->println("<experiment_id>$experiment_id</experiment_id>");
    $self->println("<name>" . xml_escape($experiment_prop->get_name()) . "</name>");
    $self->println("<value>" . xml_escape($experiment_prop->get_value()) . "</value>");
    $self->println("<rank>" . xml_escape($experiment_prop->get_rank()) . "</rank>");
    if ($experiment_prop->get_termsource()) {
      $self->println("<dbxref_id>" . $self->write_dbxref($experiment_prop->get_termsource(1)) .  "</dbxref_id>");
    }
    if ($experiment_prop->get_type()) {
      $self->println("<type_id>" . $self->write_cvterm($experiment_prop->get_type(1)) . "</type_id>");
    }
    $self->println("</experiment_prop>");
  }
  return $id;
}

sub write_datum : PRIVATE {
  my ($self, $datum) = @_;
  my $id = "datum_" . $datum->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('data', "<data id=\"$id\">");
    $self->println_to('data', "<name>" . xml_escape($datum->get_name()) . "</name>");
    $self->println_to('data', "<heading>" . xml_escape($datum->get_heading()) . "</heading>");
    $self->println_to('data', "<value>" . xml_escape($datum->get_value()) . "</value>");

    if ($datum->get_termsource()) {
      $self->println_to('data', "<dbxref_id>" . $self->write_dbxref($datum->get_termsource(1)) .  "</dbxref_id>");
    }
    if ($datum->get_type()) {
      $self->println_to('data', "<type_id>" . $self->write_cvterm($datum->get_type(1)) . "</type_id>");
    }

    foreach my $feature_cache ($datum->get_features()) {
      my $feature = $feature_cache->get_object; # Do this here so we only load each feature as we need it
      $self->println_to('data', "<data_feature>");
      $self->println_to('data', "<feature_id>" . $self->write_feature($feature) . "</feature_id>");
      $self->println_to('data', "</data_feature>");
      $feature_cache->shrink();
      $feature_cache->set_content($feature_cache->get_id);
    }

    foreach my $wiggle_data ($datum->get_wiggle_datas(1)) {
      $self->println_to('data', "<data_wiggle_data>");
      $self->println_to('data', "<wiggle_data_id>" . $self->write_wiggle_data($wiggle_data) . "</wiggle_data_id>");
      $self->println_to('data', "</data_wiggle_data>");
    }

    foreach my $organism ($datum->get_organisms(1)) {
      $self->println_to('data', "<data_organism>");
      $self->println_to('data', "<organism_id>" . $self->write_organism($organism) . "</organism_id>");
      $self->println_to('data', "</data_organism>");
    }

    foreach my $attribute ($datum->get_attributes(1)) {
      $self->println_to('data', "<data_attribute>");
      $self->println_to('data', "<attribute_id>" . $self->write_attribute($attribute) . "</attribute_id>");
      $self->println_to('data', "</data_attribute>");
    }

    $self->println_to('data', "</data>");
  }
  return $id;
}

sub write_feature : PRIVATE {
  my ($self, $feature) = @_;
  my $id = "feature_" . $feature->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('features', "<feature id=\"$id\">");
    $self->println_to('features', "<name>" . xml_escape($feature->get_name()) . "</name>");
    $self->println_to('features', "<uniquename>" . xml_escape($feature->get_uniquename()) . "</uniquename>");
    $self->println_to('features', "<residues>" . xml_escape($feature->get_residues()) . "</residues>");
    $self->println_to('features', "<seqlen>" . xml_escape($feature->get_seqlen()) . "</seqlen>") if length($feature->get_seqlen());
    $self->println_to('features', "<timeaccessioned>" . xml_escape($feature->get_timeaccessioned()) . "</timeaccessioned>") if length($feature->get_timeaccessioned());
    $self->println_to('features', "<timelastmodified>" . xml_escape($feature->get_timelastmodified()) . "</timelastmodified>") if length($feature->get_timelastmodified());
    $self->println_to('features', "<is_analysis>" . xml_escape($feature->get_is_analysis()) . "</is_analysis>") if length(xml_escape($feature->get_is_analysis()));

    if ($feature->get_type()) {
      $self->println_to('features', "<type_id>" . $self->write_cvterm($feature->get_type(1)) . "</type_id>");
    }
    if ($feature->get_organism()) {
      $self->println_to('features', "<organism_id>" . $self->write_organism($feature->get_organism(1)) . "</organism_id>");
    }
    if ($feature->get_primary_dbxref()) {
      $self->println_to('features', "<dbxref_id>" . $self->write_dbxref($feature->get_primary_dbxref(1)) . "</dbxref_id>");
    }
    foreach my $feature_dbxref ($feature->get_dbxrefs(1)) {
      $self->println_to('features', "<feature_dbxref>");
      $self->println_to('features', "<dbxref_id>" . $self->write_dbxref($feature_dbxref) . "</dbxref_id>");
      $self->println_to('features', "</feature_dbxref>");
    }
    foreach my $analysisfeature (@{$feature->get_analysisfeatures()}) {
      $self->write_analysisfeature($analysisfeature, $id);
    }
    $self->println_to('features', "</feature>");

    # Don't put these inside the feature object; rather, write later
    # That way any additional <feature> objects that need to be written 
    # won't end up inside the above feature tag.
    foreach my $feature_relationship ($feature->get_relationships(1)) {
      $self->write_feature_relationship($feature_relationship);
    }
    foreach my $feature_location (@{$feature->get_locations()}) {
      $self->write_featureloc($feature_location, $id);
    }
    foreach my $feature_property (@{$feature->get_properties()}) {
      $self->write_featureprop($feature_property, $id);
    }
  }
  return $id;
}

sub write_feature_relationship : PRIVATE {
  my ($self, $feature_relationship) = @_;

  # Make sure the features are written before we start recursing feature_relationship->object->feature_relationship
  $self->write_feature($feature_relationship->get_subject(1));
  $self->write_feature($feature_relationship->get_object(1));

  my $id = "feature_relationship_" . $feature_relationship->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('feature_relationships', "<feature_relationship>");
    $self->println_to('feature_relationships', "<rank>" . xml_escape($feature_relationship->get_rank()) . "</rank>") if length($feature_relationship->get_rank());
    $self->println_to('feature_relationships', "<subject_id>" . $self->write_feature($feature_relationship->get_subject(1)) . "</subject_id>");
    $self->println_to('feature_relationships', "<object_id>" . $self->write_feature($feature_relationship->get_object(1)) . "</object_id>");
    if ($feature_relationship->get_type()) {
      $self->println_to('feature_relationships', "<type_id>" . $self->write_cvterm($feature_relationship->get_type(1)) . "</type_id>");
    }
    $self->println_to('feature_relationships', "</feature_relationship>");
  }
}

sub write_analysisfeature : PRIVATE {
  my ($self, $analysisfeature, $feature_id) = @_;
  $self->println_to('analysisfeatures', "<analysisfeature>");
  $self->println_to('analysisfeatures', "<feature_id>$feature_id</feature_id>");
  $self->println_to('analysisfeatures', "<rawscore>" . xml_escape($analysisfeature->get_rawscore()) . "</rawscore>") if length($analysisfeature->get_rawscore());
  $self->println_to('analysisfeatures', "<normscore>" . xml_escape($analysisfeature->get_normscore()) . "</normscore>") if length($analysisfeature->get_normscore());
  $self->println_to('analysisfeatures', "<significance>" . xml_escape($analysisfeature->get_significance()) . "</significance>") if length($analysisfeature->get_significance());
  $self->println_to('analysisfeatures', "<identity>" . xml_escape($analysisfeature->get_identity()) . "</identity>") if length($analysisfeature->get_identity());
  $self->println_to('analysisfeatures', "<analysis_id>" . $self->write_analysis($analysisfeature->get_analysis(1)) . "</analysis_id>");
  $self->println_to('analysisfeatures', "</analysisfeature>");
}

sub write_featureloc : PRIVATE {
  my ($self, $featureloc, $feature_id) = @_;
  if ($featureloc->get_srcfeature()) {
    # Make sure this feature is written before we start recursing featureloc->srcfeature->featureloc
    $self->write_feature($featureloc->get_srcfeature(1));
  }

  $self->println_to('featurelocs', "<featureloc>");
  $self->println_to('featurelocs', "<feature_id>$feature_id</feature_id>");
  $self->println_to('featurelocs', "<fmin>" . xml_escape($featureloc->get_fmin()) . "</fmin>") if length($featureloc->get_fmin());
  $self->println_to('featurelocs', "<fmax>" . xml_escape($featureloc->get_fmax()) . "</fmax>") if length($featureloc->get_fmax());
  $self->println_to('featurelocs', "<rank>" . xml_escape($featureloc->get_rank()) . "</rank>") if length($featureloc->get_rank());
  $self->println_to('featurelocs', "<strand>" . xml_escape($featureloc->get_strand()) . "</strand>") if length($featureloc->get_strand());
  if ($featureloc->get_srcfeature()) {
    $self->println_to('featurelocs', "<srcfeature_id>" . $self->write_feature($featureloc->get_srcfeature(1)) . "</srcfeature_id>");
  }
  $self->println_to('featurelocs', "</featureloc>");
}

sub write_featureprop : PRIVATE {
  my ($self, $featureprop, $feature_id) = @_;

  $self->println_to('featureprops', "<featureprop>");
  $self->println_to('featureprops', "<feature_id>$feature_id</feature_id>");
  $self->println_to('featureprops', "<value>" . xml_escape($featureprop->get_value()) . "</value>") if length($featureprop->get_value());
  $self->println_to('featureprops', "<rank>" . xml_escape($featureprop->get_rank()) . "</rank>") if length($featureprop->get_rank());
  $self->println_to('featureprops', "<type_id>" . $self->write_cvterm($featureprop->get_type(1)) .  "</type_id>");
  $self->println_to('featureprops', "</featureprop>");
}

sub write_analysis : PRIVATE {
  my ($self, $analysis) = @_;
  my $id = "analysis_" . $analysis->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('analyses', "<analysis id=\"$id\">");
    $self->println_to('analyses', "<name>" . xml_escape($analysis->get_name()) . "</name>");
    $self->println_to('analyses', "<description>" . xml_escape($analysis->get_description()) . "</description>");
    $self->println_to('analyses', "<program>" . xml_escape($analysis->get_program()) . "</program>");
    $self->println_to('analyses', "<programversion>" . xml_escape($analysis->get_programversion()) . "</programversion>");
    $self->println_to('analyses', "<algorithm>" . xml_escape($analysis->get_algorithm()) . "</algorithm>");
    $self->println_to('analyses', "<sourcename>" . xml_escape($analysis->get_sourcename()) . "</sourcename>");
    $self->println_to('analyses', "<sourceversion>" . xml_escape($analysis->get_sourceversion()) . "</sourceversion>");
    $self->println_to('analyses', "<sourceuri>" . xml_escape($analysis->get_sourceuri()) . "</sourceuri>");
    $self->println_to('analyses', "<timeexecuted>" . xml_escape($analysis->get_timeexecuted()) . "</timeexecuted>") if length($analysis->get_timeexecuted());
    $self->println_to('analyses', "</analysis>");
  }
  return $id;
}


sub write_organism : PRIVATE {
  my ($self, $organism) = @_;
  my $id = "organism_" . $organism->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('organisms', "<organism id=\"$id\">");
    $self->println_to('organisms', "<genus>" . xml_escape($organism->get_genus()) . "</genus>");
    $self->println_to('organisms', "<species>" . xml_escape($organism->get_species()) . "</species>");
    $self->println_to('organisms', "</organism>");
  }
  return $id;
}

sub write_wiggle_data : PRIVATE {
  my ($self, $wiggle_data) = @_;
  my $id = "wiggle_data_" . $wiggle_data->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('wiggle_data', "<wiggle_data id=\"$id\">");
    $self->println_to('wiggle_data', "<type>" . $wiggle_data->get_type() . "</type>");
    $self->println_to('wiggle_data', "<name>" . $wiggle_data->get_name() . "</name>");
    $self->println_to('wiggle_data', "<visibility>" . $wiggle_data->get_visibility() . "</visibility>");
    $self->println_to('wiggle_data', "<color>(" . join(", ", @{$wiggle_data->get_color()}) . ")</color>");
    $self->println_to('wiggle_data', "<altColor>(" . join(", ", @{$wiggle_data->get_altColor()}) . ")</altColor>");
    $self->println_to('wiggle_data', "<priority>" . $wiggle_data->get_priority() . "</priority>");
    $self->println_to('wiggle_data', "<autoscale>" . $wiggle_data->get_autoscale() . "</autoscale>");
    $self->println_to('wiggle_data', "<gridDefault>" . $wiggle_data->get_gridDefault() . "</gridDefault>");
    $self->println_to('wiggle_data', "<maxHeightPixels>(" . join(", ", @{$wiggle_data->get_maxHeightPixels()}) . ")</maxHeightPixels>");
    $self->println_to('wiggle_data', "<graphType>" . $wiggle_data->get_graphType() . "</graphType>");
    $self->println_to('wiggle_data', "<viewLimits>(" . join(", ", @{$wiggle_data->get_viewLimits()}) . ")</viewLimits>");
    $self->println_to('wiggle_data', "<yLineMark>" . $wiggle_data->get_yLineMark() . "</yLineMark>");
    $self->println_to('wiggle_data', "<yLineOnOff>" . $wiggle_data->get_yLineOnOff() . "</yLineOnOff>");
    $self->println_to('wiggle_data', "<windowingFunction>" . $wiggle_data->get_windowingFunction() . "</windowingFunction>");
    $self->println_to('wiggle_data', "<smoothingWindow>" . $wiggle_data->get_smoothingWindow() . "</smoothingWindow>");
    $self->println_to('wiggle_data', "<data>" . $wiggle_data->get_data() . "</data>");
    $self->println_to('wiggle_data', "</wiggle_data>");
  }
  return $id;
}

sub write_attribute : PRIVATE {
  my ($self, $attribute) = @_;
  my $id = "attribute_" . $attribute->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('attributes', "<attribute id=\"$id\">");
    $self->println_to('attributes', "<name>" . xml_escape($attribute->get_name()) . "</name>");
    $self->println_to('attributes', "<heading>" . xml_escape($attribute->get_heading()) . "</heading>");
    $self->println_to('attributes', "<value>" . xml_escape($attribute->get_value()) . "</value>");
    $self->println_to('attributes', "<rank>" . xml_escape($attribute->get_rank()) . "</rank>");

    if ($attribute->get_termsource()) {
      $self->println_to('attributes', "<dbxref_id>" . $self->write_dbxref($attribute->get_termsource(1)) .  "</dbxref_id>");
    }
    if ($attribute->get_type()) {
      $self->println_to('attributes', "<type_id>" . $self->write_cvterm($attribute->get_type(1)) .  "</type_id>");
    }

    foreach my $organism ($attribute->get_organisms(1)) {
      $self->println_to('attributes', "<attribute_organism>");
      $self->println_to('attributes', "<organism_id>" . $self->write_organism($organism) . "</organism_id>");
      $self->println_to('attributes', "</attribute_organism>");
    }

    $self->println_to('attributes', "</attribute>");
  }
  return $id;
}

sub write_cvterm : PRIVATE {
  my ($self, $cvterm) = @_;
  my $id = "cvterm_" . $cvterm->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('cvterms', "<cvterm id=\"$id\">");
    $self->println_to('cvterms', "<name>" . xml_escape($cvterm->get_name()) . "</name>");
    $self->println_to('cvterms', "<definition>" . xml_escape($cvterm->get_definition()) . "</definition>");
    $self->println_to('cvterms', "<is_obsolete>" . xml_escape($cvterm->get_is_obsolete()) . "</is_obsolete>");
  
    if ($cvterm->get_cv()) {
      $self->write_cv($cvterm->get_cv(1));
    }

    if ($cvterm->get_dbxref()) {
      $self->println_to('cvterms', "<dbxref_id>" . $self->write_dbxref($cvterm->get_dbxref(1)) . "</dbxref_id>");
    }

    $self->println_to('cvterms', "</cvterm>");
  }
  return $id;
}

sub write_cv : PRIVATE {
  my ($self, $cv) = @_;
  my $id = "cv_" . $cv->get_id();
  if ($seen_ids{ident $self}->{$id}++) {
    $self->println_to('cvterms', "<cv_id>$id</cv_id>");
  } else {
    $self->println_to('cvterms', "<cv_id>");
    $self->println_to('cvterms', "<cv id=\"$id\">");
    $self->println_to('cvterms', "<name>" . xml_escape($cv->get_name()) . "</name>");
    $self->println_to('cvterms', "<definition>" . xml_escape($cv->get_definition()) . "</definition>");
    $self->println_to('cvterms', "</cv>");
    $self->println_to('cvterms', "</cv_id>");
  }
}

sub write_dbxref : PRIVATE {
  my ($self, $dbxref) = @_;
  my $id = "dbxref_" . $dbxref->get_id();
  if (!$seen_ids{ident $self}->{$id}++) {
    $self->println_to('dbxrefs', "<dbxref id=\"$id\">");
    $self->println_to('dbxrefs', "<accession>" . xml_escape($dbxref->get_accession()) . "</accession>");
    $self->println_to('dbxrefs', "<version>" . xml_escape($dbxref->get_version()) . "</version>");
    $self->write_db($dbxref->get_db(1));
    $self->println_to('dbxrefs', "</dbxref>");
  }
  return $id;
}

sub write_db : PRIVATE {
  my ($self, $db) = @_;
  my $id = "db_" . $db->get_id();
  if ($seen_ids{ident $self}->{$id}++) {
    $self->println_to('dbxrefs', "<db_id>$id</db_id>");
  } else {
    $self->println_to('dbxrefs', "<db_id>");
    $self->println_to('dbxrefs', "<db id=\"$id\">");
    $self->println_to('dbxrefs', "<name>" . xml_escape($db->get_name()) . "</name>");
    $self->println_to('dbxrefs', "<url>" . xml_escape($db->get_url()) . "</url>");
    $self->println_to('dbxrefs', "<description>" . xml_escape($db->get_description()) . "</description>");
    $self->println_to('dbxrefs', "</db>");
    $self->println_to('dbxrefs', "</db_id>");
  }
}

sub println {
  my ($self, $text) = @_;
  $self->println_to('default', $text);
}

sub println_to {
  my ($self, $tempfile, $text) = @_;
  my @numincs = ($text =~ m/(<[a-zA-Z])/g);
  my @numdecs = ($text =~ m/(<\/)/g);
  my $diffincs = scalar(@numincs) - scalar(@numdecs);
  for (my $i = 0; $i > $diffincs; $i--) {
    $self->dec_indent();
  }
  my $tmpfh = $self->get_tempfiles()->{$tempfile};
  print $tmpfh $self->indent_txt() . $text . "\n";
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

sub xml_escape {
  my ($value) = @_;
  $value =~ s/>/&gt;/g;
  $value =~ s/</&lt;/g;
  $value =~ s/&/&amp;/g;
  return $value;
}

1;

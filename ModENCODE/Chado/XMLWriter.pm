package ModENCODE::Chado::XMLWriter;

use strict;
use Class::Std;
use Carp qw(croak carp);
use HTML::Entities ();
use ModENCODE::ErrorHandler qw(log_error);

my %indent              :ATTR(                             :default<0> );
my %indent_width        :ATTR( :name<indent_width>,        :default<2> );
my %current_uniqid      :ATTR(                             :default<0> );
my %data_this_proto     :ATTR(                             :default<{ 'input' => [], 'output' => []> });
my %seen_relationships  :ATTR(                             :default<[]> );
my %delayed_writes      :ATTR(                             :default<[]> );

# Semi-macro-ified version (protocols are macro-d, data isn't)
sub write_chadoxml {
  my ($self, $experiment) = @_;
  $self->set_indent(0);
  $self->reset_uniqid();
  $self->clear_seen_data();
  $self->println("<chadoxml>");
  $delayed_writes{ident $self} = [];

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

  # Write all of the applied protocols
  for (my $i = 0; $i < $experiment->get_num_applied_protocol_slots(); $i++) {
    my $applied_protocols = $experiment->get_applied_protocols_at_slot($i);
    foreach my $applied_protocol (@$applied_protocols) {
      $applied_protocol->set_chadoxml_id($self->generate_uniqid("AppliedProtocol"));
      $self->write_applied_protocol($applied_protocol);
    }
    $self->shift_seen_data()
  }

  # Write the experiment
  $experiment->set_chadoxml_id($self->generate_uniqid("Experiment"));
  $self->println("<experiment id=\"" . $experiment->get_chadoxml_id() . "\">");
  $self->println("<description>" . xml_escape($experiment->get_description()) . "</description>");
  $self->println("<uniquename>" . xml_escape($experiment->get_uniquename()) . "</uniquename>");
  foreach my $applied_protocol (@{$experiment->get_applied_protocols_at_slot(0)}) {
    $self->println("<experiment_applied_protocol>");
    $self->println("<first_applied_protocol_id>" . $applied_protocol->get_chadoxml_id() . "</first_applied_protocol_id>");
    $self->println("</experiment_applied_protocol>");
  }
  
  $self->println("</experiment>");
  # Write the experiment properties
  foreach my $experiment_property (@{$experiment->get_properties()}) {
    $self->write_experiment_prop($experiment_property, $experiment);
  }
  # Do delayed writes
  $self->write_delayed_writes();



  $self->println("</chadoxml>");
}

sub write_delayed_writes {
  my ($self) = @_;
  foreach my $delayed_write (@{$delayed_writes{ident $self}}) {
    &$delayed_write();
  }
}

sub write_applied_protocol : PRIVATE {
  my ($self, $applied_protocol) = @_;
  
  $self->println("<applied_protocol id=\"" . $applied_protocol->get_chadoxml_id() . "\">");
  $self->println("<protocol_id>" . $applied_protocol->get_protocol()->get_chadoxml_id() . "</protocol_id>");
  foreach my $datum (@{$applied_protocol->get_input_data()}) {
    my $seen_datum = $self->seen_datum($datum, 'input');
    $self->println("<applied_protocol_data>");
    $self->println("<direction>input</direction>");
    if ($seen_datum) {
      $datum->set_chadoxml_id($seen_datum->get_chadoxml_id);
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
  foreach my $datum (@{$applied_protocol->get_output_data()}) {
    my $seen_datum = $self->seen_datum($datum, 'output');
    $self->println("<applied_protocol_data>");
    $self->println("<direction>output</direction>");
    if ($seen_datum) {
      $datum->set_chadoxml_id($seen_datum->get_chadoxml_id);
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
    $self->println("<dbxref_id>");
    $self->write_dbxref($protocol->get_termsource());
    $self->println("</dbxref_id>");
  }

  $self->println("</protocol>");
}

sub write_experiment_prop {
  my ($self, $experiment_prop, $experiment) = @_;
  $self->println("<experiment_prop>");
  $self->println("<experiment_id>" . $experiment->get_chadoxml_id() . "</experiment_id>");
  $self->println("<name>" . xml_escape($experiment_prop->get_name()) . "</name>");
  $self->println("<value>" . xml_escape($experiment_prop->get_value()) . "</value>");
  $self->println("<rank>" . xml_escape($experiment_prop->get_rank()) . "</rank>");
  if ($experiment_prop->get_termsource()) {
    $self->println("<dbxref_id>");
    $self->write_dbxref($experiment_prop->get_termsource());
    $self->println("</dbxref_id>");
  }

  if ($experiment_prop->get_type()) {
    $self->println("<type_id>");
    $self->write_cvterm($experiment_prop->get_type());
    $self->println("</type_id>");
  }
  $self->println("</experiment_prop>");
}

sub write_datum {
  my ($self, $datum) = @_;
  $self->println("<data id=\"" . $datum->get_chadoxml_id() . "\">");
  $self->println("<name>" . xml_escape($datum->get_name()) . "</name>");
  $self->println("<heading>" . xml_escape($datum->get_heading()) . "</heading>");
  $self->println("<value>" . xml_escape($datum->get_value()) . "</value>");

  if ($datum->get_termsource()) {
    $self->println("<dbxref_id>");
    $self->write_dbxref($datum->get_termsource());
    $self->println("</dbxref_id>");
  }

  if ($datum->get_type()) {
    $self->println("<type_id>");
    $self->write_cvterm($datum->get_type());
    $self->println("</type_id>");
  }

  foreach my $feature (@{$datum->get_features()}) {
    $self->println("<data_feature>");
    if ($feature->get_chadoxml_id()) {
      $self->println("<feature_id>" . $feature->get_chadoxml_id() . "</feature_id>");
    } else {
      $feature->set_chadoxml_id($self->generate_uniqid("Wiggle_Data"));
      $self->println("<feature_id>");
      $self->write_feature($feature);
      $self->println("</feature_id>");
    }
    $self->println("</data_feature>");
  }

  foreach my $wiggle_data (@{$datum->get_wiggle_datas()}) {
    $self->println("<data_wiggle_data>");
    if ($wiggle_data->get_chadoxml_id()) {
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

sub write_feature {
  my ($self, $feature) = @_;
  $self->println("<feature id=\"" . $feature->get_chadoxml_id() . "\">");
  $self->println("<name>" . xml_escape($feature->get_name()) . "</name>");
  $self->println("<uniquename>" . xml_escape($feature->get_uniquename()) . "</uniquename>");
  $self->println("<residues>" . xml_escape($feature->get_residues()) . "</residues>");
  $self->println("<seqlen>" . xml_escape($feature->get_seqlen()) . "</seqlen>") if length($feature->get_seqlen());
  $self->println("<timeaccessioned>" . xml_escape($feature->get_timeaccessioned()) . "</timeaccessioned>") if length($feature->get_timeaccessioned());
  $self->println("<timelastmodified>" . xml_escape($feature->get_timelastmodified()) . "</timelastmodified>") if length($feature->get_timelastmodified());
  $self->println("<is_analysis>" . xml_escape($feature->get_is_analysis()) . "</is_analysis>");

  if ($feature->get_type()) {
    $self->println("<type_id>");
    $self->write_cvterm($feature->get_type());
    $self->println("</type_id>");
  }
  if ($feature->get_organism()) {
    $self->println("<organism_id>");
    $self->write_organism($feature->get_organism());
    $self->println("</organism_id>");
  }
  foreach my $feature_location (@{$feature->get_locations()}) {
    $self->write_featureloc_later_for_feature($feature_location, $feature);
  }
  foreach my $analysisfeature (@{$feature->get_analysisfeatures()}) {
    $self->write_analysisfeature_later_for_feature($analysisfeature, $feature);
  }
  if ($feature->get_relationships()) {
    foreach my $feature_relationship (@{$feature->get_relationships()}) {
      $self->write_feature_relationship($feature_relationship, $feature);
    }
  }
  $self->println("</feature>");
}

sub write_feature_relationship {
  my ($self, $feature_relationship, $feature_parent) = @_;
  
  my $subject = $feature_relationship->get_subject();
  my $object = $feature_relationship->get_object();

  if ($subject xor $object) {
    log_error "Attempting to write a feature_relationship with a subject but no object or vice versa.", "error";
    exit;
  }

  my $seen_subject = 1;
  my $seen_object = 1;
  if (!$subject->get_chadoxml_id()) {
    $seen_subject = 0;
    $subject->set_chadoxml_id($self->generate_uniqid("Feature"));
  }
  if (!$object->get_chadoxml_id()) {
    $seen_object = 0;
    $object->set_chadoxml_id($self->generate_uniqid("Feature"));
  }

  if (!$self->seen_relationship($subject, $object)) {
    $self->add_seen_relationship($subject, $object);

    $self->println("<feature_relationship>");
    $self->println("<rank>" . xml_escape($feature_relationship->get_rank()) . "</rank>") if length($feature_relationship->get_rank());
    if ($feature_relationship->get_type()) {
      $self->println("<type_id>");
      $self->write_cvterm($feature_relationship->get_type());
      $self->println("</type_id>");
    }
    if ($seen_subject) {
      if ($subject != $feature_parent) {
        $self->println("<subject_id>" . $subject->get_chadoxml_id() . "</subject_id>");
      }
    } else {
      $self->println("<subject_id>");
      $self->write_feature($subject);
      $self->println("</subject_id>");
    }
    if ($seen_object) {
      if ($object != $feature_parent) {
        $self->println("<object_id>" . $object->get_chadoxml_id() . "</object_id>");
      }
    } else {
      $self->println("<object_id>");
      $self->write_feature($object);
      $self->println("</object_id>");
    }

    $self->println("</feature_relationship>");


#    push @{$delayed_writes{ident $self}}, sub {
#      $self->println("<feature_relationship>");
#      $self->println("<rank>" . xml_escape($feature_relationship->get_rank()) . "</rank>") if length($feature_relationship->get_rank());
#      if ($feature_relationship->get_type()) {
#        $self->println("<type_id>");
#        $self->write_cvterm($feature_relationship->get_type());
#        $self->println("</type_id>");
#      }
#      $self->println("<subject_id>" . $subject->get_chadoxml_id() . "</subject_id>");
#      $self->println("<object_id>" . $object->get_chadoxml_id() . "</object_id>");
#      $self->println("</feature_relationship>");
#    };
#    if (!$subject->get_chadoxml_id()) {
#      $subject->set_chadoxml_id($self->generate_uniqid("Feature"));
#      $self->println("<feature_id>");
#      $self->write_feature($subject);
#      $self->println("</feature_id>");
#    }
#    if (!$object->get_chadoxml_id()) {
#      $object->set_chadoxml_id($self->generate_uniqid("Feature"));
#      $self->println("<feature_id>");
#      $self->write_feature($object);
#      $self->println("</feature_id>");
#    }
  }
}

sub write_analysisfeature {
  my ($self, $analysisfeature) = @_;
  $self->println("<analysisfeature>");
  $self->println("<rawscore>" . xml_escape($analysisfeature->get_rawscore()) . "</rawscore>") if length($analysisfeature->get_rawscore());
  $self->println("<normscore>" . xml_escape($analysisfeature->get_normscore()) . "</normscore>") if length($analysisfeature->get_normscore());
  $self->println("<significance>" . xml_escape($analysisfeature->get_significance()) . "</significance>") if length($analysisfeature->get_significance());
  $self->println("<identity>" . xml_escape($analysisfeature->get_identity()) . "</identity>") if length($analysisfeature->get_identity());
  if ($analysisfeature->get_feature()) {
    if ($analysisfeature->get_feature()->get_chadoxml_id()) {
      $self->println("<feature_id>" . $analysisfeature->get_feature()->get_chadoxml_id() . "</feature_id>");
    } else {
      $analysisfeature->get_feature()->set_chadoxml_id($self->generate_uniqid("Feature"));
      $self->println("<feature_id>");
      $self->write_feature($analysisfeature->get_feature());
      $self->println("</feature_id>");
    }
  }
  if ($analysisfeature->get_analysis()) {
    if ($analysisfeature->get_analysis()->get_chadoxml_id()) {
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

sub write_analysisfeature_later_for_feature {
  my ($self, $analysisfeature, $feature) = @_;
  push @{$delayed_writes{ident $self}}, sub { 
    if (!$analysisfeature->get_chadoxml_id()) {
      $analysisfeature->set_chadoxml_id($self->generate_uniqid("AnalysisFeature"));
      $self->write_analysisfeature($analysisfeature, $feature); 
    }
  };
}

sub write_featureloc_later_for_feature {
  my ($self, $featureloc, $feature) = @_;
  push @{$delayed_writes{ident $self}}, sub { 
    if (!$featureloc->get_chadoxml_id()) {
      $featureloc->set_chadoxml_id($self->generate_uniqid("FeatureLoc"));
      $self->write_featureloc($featureloc, $feature); 
    }
  };
}

sub write_featureloc {
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
    if ($featureloc->get_srcfeature()->get_chadoxml_id()) {
      $self->println("<srcfeature_id>" . $featureloc->get_srcfeature()->get_chadoxml_id() . "</srcfeature_id>");
    } else {
      $featureloc->get_srcfeature()->set_chadoxml_id($self->generate_uniqid("Feature"));
      $self->println("<srcfeature_id>");
      $self->write_feature($featureloc->get_srcfeature());
      $self->println("</srcfeature_id>");
    }
  }
  $self->println("</featureloc>");
}

sub write_analysis {
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


sub write_organism {
  my ($self, $organism) = @_;
  $self->println("<organism>");
  $self->println("<genus>" . xml_escape($organism->get_genus()) . "</genus>");
  $self->println("<species>" . xml_escape($organism->get_species()) . "</species>");
  $self->println("</organism>");
}

sub write_wiggle_data {
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

sub write_attribute {
  my ($self, $attribute) = @_;
  $self->println("<attribute>");
  $self->println("<name>" . xml_escape($attribute->get_name()) . "</name>");
  $self->println("<heading>" . xml_escape($attribute->get_heading()) . "</heading>");
  $self->println("<value>" . xml_escape($attribute->get_value()) . "</value>");
  $self->println("<rank>" . xml_escape($attribute->get_rank()) . "</rank>");

  if ($attribute->get_termsource()) {
    $self->println("<dbxref_id>");
    $self->write_dbxref($attribute->get_termsource());
    $self->println("</dbxref_id>");
  }

  if ($attribute->get_type()) {
    $self->println("<type_id>");
    $self->write_cvterm($attribute->get_type());
    $self->println("</type_id>");
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

sub write_cvterm {
  my ($self, $cvterm) = @_;
  $self->println("<cvterm>");
  $self->println("<name>" . xml_escape($cvterm->get_name()) . "</name>");
  $self->println("<definition>" . xml_escape($cvterm->get_definition()) . "</definition>");
  $self->println("<is_obsolete>" . xml_escape($cvterm->get_is_obsolete()) . "</is_obsolete>");
  
  if ($cvterm->get_cv()) {
    $self->println("<cv_id>");
    $self->write_cv($cvterm->get_cv());
    $self->println("</cv_id>");
  }

  if ($cvterm->get_dbxref()) {
    $self->println("<dbxref_id>");
    $self->write_dbxref($cvterm->get_dbxref());
    $self->println("</dbxref_id>");
  }

  $self->println("</cvterm>");
}

sub write_cv {
  my ($self, $cv) = @_;
  $self->println("<cv>");
  $self->println("<name>" . xml_escape($cv->get_name()) . "</name>");
  $self->println("<definition>" . xml_escape($cv->get_definition()) . "</definition>");
  $self->println("</cv>");
}

sub write_dbxref : PRIVATE {
  my ($self, $dbxref) = @_;
  $self->println("<dbxref>");
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
  my @numincs = ($text =~ m/(<[a-zA-Z])/g);
  my @numdecs = ($text =~ m/(<\/)/g);
  my $diffincs = scalar(@numincs) - scalar(@numdecs);
  for (my $i = 0; $i > $diffincs; $i--) {
    $self->dec_indent();
  }
  print $self->indent_txt() . $text . "\n";
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

sub reset_uniqid : PRIVATE {
  my ($self) = @_;
  $current_uniqid{ident $self} = 0;
}

sub generate_uniqid : PRIVATE {
  my ($self, $prefix) = @_;
  $current_uniqid{ident $self}++;
  return $prefix . "_" . $current_uniqid{ident $self};
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
  my ($self, $subject, $object) = @_;
  push @{$seen_relationships{ident $self}}, [ $subject->get_chadoxml_id(), $object->get_chadoxml_id() ];
}

sub seen_relationship : PRIVATE {
  my ($self, $subject, $object) = @_;
  foreach my $seen_rel (@{$seen_relationships{ident $self}}) {
    if (
      $seen_rel->[0] eq $subject->get_chadoxml_id() &&
      $seen_rel->[1] eq $object->get_chadoxml_id()
    ) { 
      return 1;
    }
  }
  return 0;
}

sub xml_escape {
  my ($value) = @_;
  $value =~ s/>/&gt;/g;
  $value =~ s/</&lt;/g;
  $value =~ s/"/&quot;/g;
  $value =~ s/'/&#39;/g;
  $value =~ s/&/&amp;/g;
  return $value;
}

1;

package ModENCODE::Chado::XMLWriter;

use strict;
use Class::Std;
use Carp qw(croak carp);
use HTML::Entities ();

my %indent          :ATTR(                             :default<0> );
my %indent_width    :ATTR( :name<indent_width>,        :default<2> );
my %current_uniqid  :ATTR(                             :default<0> );
my %data_this_proto :ATTR(                             :default<{ 'input' => [], 'output' => []> });

# Semi-macro-ified version (protocols are macro-d, data isn't)
sub write_chadoxml {
  my ($self, $experiment) = @_;
  $self->set_indent(0);
  $self->reset_uniqid();
  $self->clear_seen_data();
  $self->println("<chadoxml>");

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
  $self->println("<experiment>");
  $self->println("<description>" . HTML::Entities::encode_numeric($experiment->get_description()) . "</description>");
  foreach my $experiment_property (@{$experiment->get_properties()}) {
    $self->println("<experiment_prop_id>");
    $self->write_experiment_prop($experiment_property);
    $self->println("</experiment_prop_id>");
  }
  foreach my $applied_protocol (@{$experiment->get_applied_protocols_at_slot(0)}) {
    $self->println("<experiment_applied_protocol>");
    $self->println("<first_applied_protocol_id>" . $applied_protocol->get_chadoxml_id() . "</first_applied_protocol_id>");
    $self->println("</experiment_applied_protocol>");
  }
  
  $self->println("</experiment>");
  $self->println("</chadoxml>");
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
  $self->println("<name>" . HTML::Entities::encode_numeric($protocol->get_name()) . "</name>");
  $self->println("<description>" . HTML::Entities::encode_numeric($protocol->get_description()) . "</description>");

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
  my ($self, $experiment_prop) = @_;
  $self->println("<experiment_prop>");
  $self->println("<name>" . HTML::Entities::encode_numeric($experiment_prop->get_name()) . "</name>");
  $self->println("<value>" . HTML::Entities::encode_numeric($experiment_prop->get_value()) . "</value>");
  $self->println("<rank>" . HTML::Entities::encode_numeric($experiment_prop->get_rank()) . "</rank>");
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
  $self->println("<name>" . HTML::Entities::encode_numeric($datum->get_name()) . "</name>");
  $self->println("<heading>" . HTML::Entities::encode_numeric($datum->get_heading()) . "</heading>");
  $self->println("<value>" . HTML::Entities::encode_numeric($datum->get_value()) . "</value>");

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

  foreach my $attribute (@{$datum->get_attributes()}) {
    $self->println("<data_attribute>");
    $self->println("<attribute_id>");
    $self->write_attribute($attribute);
    $self->println("</attribute_id>");
    $self->println("</data_attribute>");
  }

  $self->println("</data>");
}

sub write_attribute {
  my ($self, $attribute) = @_;
  $self->println("<attribute>");
  $self->println("<name>" . HTML::Entities::encode_numeric($attribute->get_name()) . "</name>");
  $self->println("<heading>" . HTML::Entities::encode_numeric($attribute->get_heading()) . "</heading>");
  $self->println("<value>" . HTML::Entities::encode_numeric($attribute->get_value()) . "</value>");
  $self->println("<rank>" . HTML::Entities::encode_numeric($attribute->get_rank()) . "</rank>");

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

  $self->println("</attribute>");
}

sub write_cvterm {
  my ($self, $cvterm) = @_;
  $self->println("<cvterm>");
  $self->println("<name>" . HTML::Entities::encode_numeric($cvterm->get_name()) . "</name>");
  $self->println("<definition>" . HTML::Entities::encode_numeric($cvterm->get_definition()) . "</definition>");
  
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
  $self->println("<name>" . HTML::Entities::encode_numeric($cv->get_name()) . "</name>");
  $self->println("<definition>" . HTML::Entities::encode_numeric($cv->get_definition()) . "</definition>");
  $self->println("</cv>");
}

sub write_dbxref : PRIVATE {
  my ($self, $dbxref) = @_;
  $self->println("<dbxref>");
  $self->println("<accession>" . HTML::Entities::encode_numeric($dbxref->get_accession()) . "</accession>");
  $self->println("<version>" . HTML::Entities::encode_numeric($dbxref->get_version()) . "</version>");
  $self->println("<db_id>");
  $self->write_db($dbxref->get_db());
  $self->println("</db_id>");
  $self->println("</dbxref>");
}

sub write_db : PRIVATE {
  my ($self, $db) = @_;
  $self->println("<db>");
  $self->println("<name>" . HTML::Entities::encode_numeric($db->get_name()) . "</name>");
  $self->println("<url>" . HTML::Entities::encode_numeric($db->get_url()) . "</url>");
  $self->println("<description>" . HTML::Entities::encode_numeric($db->get_description()) . "</description>");
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

1;

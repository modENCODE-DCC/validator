package ModENCODE::Parser::SDRF;

use strict;

use Class::Std;
use Parse::RecDescent;
use Carp qw(croak carp);
use Data::Dumper;

use ModENCODE::Chado::AppliedProtocol;
use ModENCODE::Chado::Protocol;
use ModENCODE::Chado::Data;
use ModENCODE::Chado::DB;
use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::Attribute;
use ModENCODE::Chado::Experiment;

my %grammar     :ATTR;

sub BUILD {
  my ($self, $ident, $args) = @_;

  $grammar{$ident} = <<'  GRAMMAR';
    SDRF_header:                        input_or_output(s?) protocol(s) end_of_line
                                        { 
                                          $return = [ 
                                            sub {
                                              my ($self, $line) = @_;

                                              # Get inputs that come before the first protocol. This 
                                              # is mainly for biomaterials
                                              my @extra_inputs;
                                              foreach my $sub (@{$item[1]}) {
                                                if (ref $sub eq 'CODE') {
                                                  push @extra_inputs, &$sub($self, $line);
                                                } else {
                                                  print "Not a sub: $sub\n";
                                                }
                                              }

                                              # Parse everything else (the protocols)
                                              my @protocols;
                                              foreach my $sub (@{$item[2]}) {
                                                if (ref $sub eq 'CODE') {
                                                  push @protocols, &$sub($self, $line);
                                                } else {
                                                  print "Not a sub: $sub\n";
                                                }
                                              }
                                              if (scalar(@$line)) {
                                                carp("Didn't process input line fully: " . join("\t", @$line));
                                              }

                                              # Add the initial inputs to the first protocol.
                                              foreach my $input (@extra_inputs) {
                                                # Totally ignoring direction here because initial data can be
                                                # "outputs" from an invisible-to-us prior process
                                                $protocols[0]->add_input_datum($input->{'datum'});
                                              }

                                              # Return the protocols
                                              return \@protocols;
                                            },
                                            scalar(@{$item[2]})
                                          ];
                                        }
                                        | <error>

    end_of_line:                        <skip:'[" \t\n\r]*'> /\Z/

    ## # # # # # # # # # # # # ##
    # PROTOCOL                  #
    ## # # # # # # # # # # # # ##
    protocol_ref:                       /Protocol *REF/i

    protocol:                           protocol_ref term_source(?) attribute(s?) input_or_output(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            return $self->create_protocol($value, $item[2], $item[3], $item[4], $values);
                                          };
                                        }

    ## # # # # # # # # # # # # ##
    # INPUT/OUTPUT GENERIC      #
    ## # # # # # # # # # # # # ##
    input_or_output:                    input | output

    input:                              parameter
                                          { $return = sub { return { 'direction' => 'input', 'datum' => &{$item[1]}(@_) } } }
                                        | parameter_file
                                          { $return = sub { return { 'direction' => 'input', 'datum' => &{$item[1]}(@_) } } }
                                        | array_design_ref
                                          { $return = sub { return { 'direction' => 'input', 'datum' => &{$item[1]}(@_) } } }
                                        | hybridization_name
                                          { $return = sub { return { 'direction' => 'input', 'datum' => &{$item[1]}(@_) } } }

    output:                             result 
                                          { $return = sub { return { 'direction' => 'output', 'datum' => &{$item[1]}(@_) } } }
                                        | biomaterial
                                          { $return = sub { return { 'direction' => 'output', 'datum' => &{$item[1]}(@_) } } }
                                        | data_file 
                                          { $return = sub { return { 'direction' => 'output', 'datum' => &{$item[1]}(@_) } } }
                                        | array_data_file 
                                          { $return = sub { return { 'direction' => 'output', 'datum' => &{$item[1]}(@_) } } }
                                        | array_matrix_data_file
                                          { $return = sub { return { 'direction' => 'output', 'datum' => &{$item[1]}(@_) } } }

    ## # # # # # # # # # # # # ##
    # INPUT TYPES               #
    ## # # # # # # # # # # # # ##
    parameter_heading:                  /Parameter *Values?/i
    parameter:                          parameter_heading <skip:' *'> bracket_term <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = undef;
                                            return $self->create_input($item[1], $value, $item[3], $type, $item[5], $item[6], $values);
                                          };
                                        }

    parameter_file_header:              /Parameter *Files?/i
    parameter_file:                     parameter_file_header <skip:' *'> bracket_term <skip:'[ "]*\t[ "]*'> attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'modtab:file';
                                            return $self->create_input($item[1], $value, $item[3], $type, undef, $item[5], $values);
                                          };
                                        }

    array_design_ref_heading:           /Array *Design *REF/i
    array_design_ref:                   array_design_ref_heading <skip:' *'> bracket_term <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = undef;
                                            return $self->create_input($item[1], $value, $item[3], $type, $item[5], $item[6], $values);
                                          };
                                        }

    hybridization_name_heading:         /Hybridization *Names?/i
    hybridization_name:                 hybridization_name_heading <skip:' *'> bracket_term <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = undef;
                                            return $self->create_input($item[1], $value, $item[3], $type, $item[5], $item[6], $values);
                                          };
                                        }



    ## # # # # # # # # # # # # ##
    # OUTPUT TYPES              #
    ## # # # # # # # # # # # # ##
    result_header:                      /Result *Values?/i
    result:                             result_header <skip:' *'> bracket_term <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = undef;
                                            return $self->create_output($item[1], $value, $item[3], $type, $item[5], $item[6], $values);
                                          };
                                        }

    biomaterial:                        source_name | sample_name | extract_name | labeled_extract_name

    source_name_heading:                /Source *Names?/i 
    source_name:                        source_name_heading <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'mage:biosource';
                                            return $self->create_input($item[1], $value, undef, $type, $item[3], $item[4], $values);
                                          };
                                        }

    sample_name_heading:                /Sample *Names?/i
    sample_name:                        sample_name_heading <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'mage:biosample';
                                            return $self->create_input($item[1], $value, undef, $type, $item[3], $item[4], $values);
                                          };
                                        }

    extract_name_heading:               /Extract *Names?/i
    extract_name:                       extract_name_heading <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'mage:biosample';
                                            return $self->create_input($item[1], $value, undef, $type, $item[3], $item[4], $values);
                                          };
                                        }

    labeled_extract_name_heading:       /Labell?ed *Extract *Names?/i
    labeled_extract_name:               labeled_extract_name_heading <skip:'[ "]*\t[ "]*'> term_source(?) attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'mage:labeledextract';
                                            return $self->create_input($item[1], $value, undef, $type, $item[3], $item[4], $values);
                                          };
                                        }


    data_file_header:                   /Result *Files?/i
    data_file:                          data_file_header <skip:' *'> bracket_term <skip:'[ "]*\t[ "]*'> attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'modtab:generic_file';
                                            return $self->create_input($item[1], $value, $item[3], $type, undef, $item[5], $values);
                                          };
                                        }

    array_data_file_header:             /(Derived)? *Array *Data *Files?/i
    array_data_file:                    array_data_file_header <skip:'[ "]*\t[ "]*'> attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'mage:datafile';
                                            return $self->create_input($item[1], $value, undef, $type, undef, $item[3], $values);
                                          };
                                        }

    array_matrix_data_file_header:      /Array *Matrix *Data *Files?/i
    array_matrix_data_file:             array_matrix_data_file_header <skip:'[ "]*\t[ "]*'> attribute(s?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            my $type = 'mage:datafile';
                                            return $self->create_input($item[1], $value, undef, $type, undef, $item[3], $values);
                                          };
                                        }


    ## # # # # # # # # # # # # ##
    # OTHER METADATA            #
    ## # # # # # # # # # # # # ##
    attribute:                          attribute_text <skip:' *'> bracket_term(?) <skip:' *'> paren_term(?) <skip:'[ "]*\t[ "]*'> term_source(?)
                                        { 
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            return $self->create_attribute($value, $item[1], $item[3][0], $item[5][0], $item[7], $values);
                                          };
                                        }

    attribute_text:                     ...!input ...!output ...!protocol 
                                        ...!term_accession_number ...!term_source 
                                        ...!parameter_file_header ...!data_file_header
                                        /([^\t"\[\(]+)[ "]*/
                                        { 
                                          $return = $1;
                                          $return =~ s/^\s*|\s*[\r\n]+//g;
                                        }

    term_source_header:                 /Term *Source *REF/i
                                        {
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            return $value;
                                          };
                                        }
    term_accession_number:              /Term *Accession *(?:Numbers?)?/i
                                        {
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            my $value = shift(@$values);
                                            return $value;
                                          };
                                        }
    term_source:                        term_source_header term_accession_number(?)
                                        {
                                          $return = sub {
                                            my ($self, $values) = @_;
                                            return $self->create_termsource($item[1], $item[2], $values);
                                          };
                                        }

    bracket_term:                       /\A \[ [ ]* ([^\]]+?) [ ]* \]/xms
                                        { $return = $1 }
    paren_term:                         /\A \( [ ]* ([^\)]+?) [ ]* \)/xms
                                        { $return = $1 }


  GRAMMAR

}
sub parse {
  my ($self, $document) = @_;
  if ( -r $document ) {
    local $/;
    open FH, "<$document" or croak "Couldn't read file $document";
    $document = <FH>;
    close FH;
  } else {
    croak "Can't find file '$document'";
  }
  $document =~ s/\A [" ]*/\t/gxms;
  $document =~ s/\015[^\012]/\n/g; # Replace old-style Mac CR endings with LFs like a regular OS
  my $parser = $self->_get_parser();
  open DOC, '<', \$document;

  # Parse header line
  my $header = <DOC>;
  my $parse_results = $parser->SDRF_header($header) or croak "Couldn't parse header line";
  my ($row_parser, $num_applied_protocols) = @$parse_results;

  my @applied_protocol_slots;
  for (my $i = 0; $i < $num_applied_protocols; $i++) {
    $applied_protocol_slots[$i] = [];
  }

  # Parse the rest of the file
  while (my $line = <DOC>) {
    $line =~ s/[\r\n]*$//g;
    next if $line =~ m/^\s*#/; # Skip comments
    next if $line =~ m/^\s*$/; # Skip blank lines

    # Parse and build objects for this row
    my @vals = split /\t/, $line;
    @vals = map { s/^"|"$//g; $_; } @vals;
    my $applied_protocols = &{$row_parser}($self, \@vals);

    # Sanity check
    if (scalar(@$applied_protocols) != $num_applied_protocols) {
      croak "Got back " . scalar(@$applied_protocols) . " applied_protocols when $num_applied_protocols applied_protocols were expected";
    }

    my $applied_protocol_slot = 0;
    for (my $applied_protocol_slot = 0; $applied_protocol_slot < $num_applied_protocols; $applied_protocol_slot++) {
      push(@{$applied_protocol_slots[$applied_protocol_slot]}, $applied_protocols->[$applied_protocol_slot]);
    }
  }

  # Okay, we've got a bunch of rows of data.

  # Need a little post-processing: make outputs of previous applied_protocols be 
  # inputs to following applied_protocols.
  my $anonymous_data_num = 0;
  for (my $i = 0; $i < $num_applied_protocols-1; $i++) {
    for (my $j = 0; $j < scalar(@{$applied_protocol_slots[$i]}); $j++) {
      my $previous_applied_protocol = $applied_protocol_slots[$i][$j];
      my $next_applied_protocol = $applied_protocol_slots[$i+1][$j];
      my $data = $previous_applied_protocol->get_output_data();
      if (scalar(@$data)) {
        foreach my $datum (@$data) {
          $next_applied_protocol->add_input_datum($datum);
        }
      } else {
        # No outputs, so we need to create an anonymous link
        my $type = new ModENCODE::Chado::CVTerm({
            'name' => 'anonymous_datum',
            'cv' => new ModENCODE::Chado::CV({
                'name' => 'modencode'
              }),
          });
        my $anonymous_datum = new ModENCODE::Chado::Data({
            'heading' => "Anonymous Datum #" . $anonymous_data_num++,
            'type' => $type,
            'anonymous' => 1,
          });
        $previous_applied_protocol->add_output_datum($anonymous_datum);
        $next_applied_protocol->add_input_datum($anonymous_datum);
      }
    }
  }

  for (my $i = 0; $i < $num_applied_protocols; $i++) {
    $applied_protocol_slots[$i] = $self->_reduce_applied_protocols($applied_protocol_slots[$i]);
  }

  my $experiment = new ModENCODE::Chado::Experiment({
      'applied_protocol_slots' => \@applied_protocol_slots,
    });

  return $experiment;
}

sub _reduce_applied_protocols : PRIVATE {
  my ($self, $applied_protocols) = @_;
  my @merged_applied_protocols;
  foreach my $applied_protocol (@$applied_protocols) {
    if (!scalar(grep { $_->equals($applied_protocol) } @merged_applied_protocols)) {
      push @merged_applied_protocols, $applied_protocol;
    }
  }
  return \@merged_applied_protocols;
}

sub _get_parser : RESTRICTED {
  my ($self) = @_;
  $::RD_ERRORS++;
  $::RD_WARN++;
  $::RD_HINT++;
  $Parse::RecDescent::skip = '[ "]*\t[ "]*';
  my $parser = new Parse::RecDescent($grammar{ident $self});
}

sub create_input {
  my ($self, $heading, $value, $name, $type, $termsource, $attributes, $values) = @_;

  my $input = new ModENCODE::Chado::Data({
      'name' => $name,
      'heading' => $heading,
      'value' => $value,
    });

  # Map functions to values; order matters (should match inputs)
  my ($termsource) = map { &$_($self, $values) } @$termsource;
  my @attributes = map { &$_($self, $values) } @$attributes;

  # Term source
  if ($termsource) {
    $input->set_termsource($termsource);
  }

  # Attributes
  foreach my $attribute (@attributes) {
    $input->add_attribute($attribute);
  }

  # Type
  if ($type) {
    my ($cv, $cvterm) = split(/:/, $type, 2);
    $type = new ModENCODE::Chado::CVTerm({
        'name' => $cvterm,
        'cv' => new ModENCODE::Chado::CV({
            'name' => $cv,
          }),
      });
    $input->set_type($type);
  }

  return $input;
}

sub create_output {
  my ($self, $heading, $value, $name, $type, $termsource, $attributes, $values) = @_;

  # Map functions to values; order matters (should match inputs)
  my ($termsource) = map { &$_($self, $values) } @$termsource;
  my @attributes = map { &$_($self, $values) } @$attributes;

  my $output = new ModENCODE::Chado::Data({
      'name' => $name,
      'heading' => $heading,
      'value' => $value,
    });

  # Term source
  if ($termsource) {
    $output->set_termsource($termsource);
  }
  
  # Attributes
  foreach my $attribute (@attributes) {
    $output->add_attribute($attribute);
  }

  # Type
  if ($type) {
    my ($cv, $cvterm) = split(/:/, $type, 2);
    $type = new ModENCODE::Chado::CVTerm({
        'name' => $cvterm,
        'cv' => new ModENCODE::Chado::CV({
            'name' => $cv,
          }),
      });
    $output->set_type($type);
  }

  return $output;
}

sub create_protocol {
  my ($self, $name, $termsource, $attributes, $data, $values) = @_;
  my $protocol = new ModENCODE::Chado::Protocol({
      'name'       => $name,
    });

  # Map functions to values; order matters (should match inputs)
  my ($termsource) = map { &$_($self, $values) } @$termsource;
  my @attributes = map { &$_($self, $values) } @$attributes;
  my @data = map { &$_($self, $values) } @$data;

  # Term source
  if ($termsource) {
    $protocol->set_termsource($termsource);
  }

  # Attributes
  foreach my $attribute (@attributes) {
    $protocol->add_attribute($attribute);
  }

  my $applied_protocol = new ModENCODE::Chado::AppliedProtocol({
      'protocol'       => $protocol,
    });

  # Input/Output data
  foreach my $datum (@data) {
    if ($datum->{'direction'} eq 'input') {
      $applied_protocol->add_input_datum($datum->{'datum'});
    }
  }
  foreach my $datum (@data) {
    if ($datum->{'direction'} eq 'output') {
      $applied_protocol->add_output_datum($datum->{'datum'});
    }
  }
  return $applied_protocol;
}

sub create_termsource {
  my ($self, $termsource_ref, $accession, $values) = @_;
  $termsource_ref = &$termsource_ref($self, $values);
  ($accession) = map { &$_($self, $values) } @$accession;
  my $db = new ModENCODE::Chado::DB({
      'name' => $termsource_ref,
    });
  my $dbxref = new ModENCODE::Chado::DBXref({
      'db' => $db,
    });
  if (length($accession)) {
    $dbxref->set_accession($accession);
  }
  return $dbxref;
}

sub create_attribute {
  my ($self, $value, $heading, $name, $type, $termsource, $values) = @_;
  my $attribute = new ModENCODE::Chado::Attribute({
      'heading' => $heading,
      'name' => $name,
      'value' => $value,
    });

  # Map functions to values; order matters (should match inputs)
  my ($termsource) = map { &$_($self, $values) } @$termsource;

  # Type
  if ($type) {
    my ($cv, $cvterm) = split(/:/, $type, 2);
    $type = new ModENCODE::Chado::CVTerm({
        'name' => $cvterm,
        'cv' => new ModENCODE::Chado::CV({
            'name' => $cv,
          }),
      });
    $attribute->set_type($type);
  }

  # Term source
  if ($termsource) {
    $attribute->set_termsource($termsource);
  }

  return $attribute;
}

1;

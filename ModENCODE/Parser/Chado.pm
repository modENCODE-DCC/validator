package ModENCODE::Parser::Chado;

use strict;
use Class::Std;
use Carp qw(croak carp);
use Data::Dumper;

use DBI;
use ModENCODE::Chado::Experiment;
use ModENCODE::Chado::AppliedProtocol;
use ModENCODE::Chado::Protocol;
use ModENCODE::Chado::Data;
use ModENCODE::Chado::DB;
use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::Attribute;

my %dbh             :ATTR(                          :default<undef> );
my %host            :ATTR( :name<host>,             :default<undef> );
my %port            :ATTR( :name<port>,             :default<undef> );
my %db              :ATTR( :name<db>,               :default<undef> );
my %username        :ATTR( :name<username>,         :default<''> );
my %password        :ATTR( :name<password>,         :default<''> );
my %protocol_slots  :ATTR(                          :default<[]> );
my %experiment      :ATTR(                          :default<undef> );

sub START {
  my ($self, $ident, $args) = @_;
  if (defined($self->get_db())) {
    $self->get_dbh(1); # Try to pre-connect to the database; suppress warnings
  }
}

sub DEMOLISH {
  my ($self) = @_;
  if ($dbh{ident $self}) {
    $dbh{ident $self}->disconnect();
  }
}

sub get_available_experiments {
  my ($self) = @_;
  my $sth = $self->get_dbh()->prepare("SELECT experiment_id, description FROM experiment");
  $sth->execute();
  my @experiments;
  while (my $row = $sth->fetchrow_hashref()) {
    push @experiments, $row;
  }
  return \@experiments;
}

sub get_experiment {
  my ($self) = @_;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    print STDERR "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?\n";
  }
  if (!defined($experiment{ident $self})) {
    print STDERR "Experiment is empty; perhaps you need to call load_experiment(\$experiment_id) first?\n";
  }
  return $experiment{ident $self};
}


sub get_normalized_protocol_slots {
  my ($self) = @_;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    print STDERR "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?\n";
  }
  my @return_protocol_slots;
  for (my $i = 0; $i < scalar(@{$protocol_slots{ident $self}}); $i++) {
    my $protocol_slot = $protocol_slots{ident $self}->[$i];
    for (my $j = 0; $j < scalar(@$protocol_slot); $j++) {
      $return_protocol_slots[$i] = [] if (!defined($return_protocol_slots[$i]));
      $return_protocol_slots[$i]->[$j] = $protocol_slot->[$j]->{'applied_protocol'};
    }
  }
  return \@return_protocol_slots;
}

sub get_denormalized_protocol_slots {
  my ($self) = @_;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    print STDERR "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?\n";
  }
  my @new_protocol_slots = ($protocol_slots{ident $self}->[0]);
  foreach my $first_applied_protocol (@{$protocol_slots{ident $self}->[0]}) {
    denormalize_applied_protocol($first_applied_protocol, $protocol_slots{ident $self}, \@new_protocol_slots);
  }
  my @return_protocol_slots;
  for (my $i = 0; $i < scalar(@new_protocol_slots); $i++) {
    my $protocol_slot = $new_protocol_slots[$i];
    for (my $j = 0; $j < scalar(@$protocol_slot); $j++) {
      $return_protocol_slots[$i] = [] if (!defined($return_protocol_slots[$i]));
      $return_protocol_slots[$i]->[$j] = $protocol_slot->[$j]->{'applied_protocol'};
    }
  }
  return \@return_protocol_slots;
}

sub get_tsv {
  my ($self, $columns) = @_;
  if (ref($columns) ne 'ARRAY') {
    $columns = $self->get_tsv_columns();
  } else {
    # This requires that the @$columns array is rectangular; i.e. all columns 
    # are the same length (like breakout before you start playing, not after).
    if (ref($columns->[0]) ne "ARRAY") {
      carp "Cannot print_tsv a \@columns array that is not an array of arrays";
      return;
    }
    my $expected_length = scalar(@{$columns->[0]});
    foreach my $column (@$columns) {
      if (scalar(@$column) ne $expected_length) {
        carp "Cannot print_tsv a \@columns array that is not an array of arrays";
        return;
      }
    }
  }
  my $column_length = scalar(@{$columns->[0]});
  my $return_string = "";
  for (my $i = 0; $i < $column_length; $i++) {
    $return_string .= join("\t", map { $_->[$i] } @$columns) . "\n";
  }
  return $return_string;
}

sub get_tsv_columns {
  my ($self) = @_;
  my @protocol_slots;
  if (!scalar(@{$protocol_slots{ident $self}})) {
    print STDERR "Protocol slots are empty; perhaps you need to call load_experiment(\$experiment_id) first?\n";
    return [];
  }
  my @protocol_slots = ($protocol_slots{ident $self}->[0]);
  foreach my $first_applied_protocol (@{$protocol_slots{ident $self}->[0]}) {
    denormalize_applied_protocol($first_applied_protocol, $protocol_slots{ident $self}, \@protocol_slots);
  }
  my @columns;

  # Use seen_data to keep from re-printing out as inputs of the next
  # protocol (which is the way they're stored in Chado, but not the 
  # way they should be printed for MAGE-TAB
  my @seen_data;

  # Build the columns protocol by protocol:
  for (my $i = 0; $i < scalar(@protocol_slots); $i++) {
    my $applied_protocols = $protocol_slots[$i];
    # If this is one of the leftmost (first) protocols, put the inputs 
    # before the protocol name (as with Source Name). This means the 
    # final output will look like:
    # [ Data ] Protocol [ Data Protocol ]* Data
    if ($i == 0) {
      # Collect the inputs into @input_columns, which is an array of arrays
      # (one array for each input + attributes)
      my @input_columns;
      foreach my $applied_protocol (@$applied_protocols) {
        # Inputs go after the protocol if it's not the first protocol
        my @input_data = @{$applied_protocol->{'applied_protocol'}->get_input_data()};
        for (my $i = 0; $i < scalar(@input_data); $i++) {
          my $input = $input_data[$i];
          $input_columns[$i] = [] if (ref($input_columns[$i]) ne "ARRAY");
          $self->flatten_data(@input_columns[$i], $input);
        } 
      }
      # Append all of the arrays in input_columns to the final 
      # @columns array so we end up with:
      # Input [ Attr ]* Input [ Attr ]*
      for (my $i = 0; $i < scalar(@input_columns); $i++) {
        push @columns, @{$input_columns[$i]};
      }
    }

    # Now get the protocol name and attributes (the core of the protocol)
    # and collect the columns into protocol_columns
    my @protocol_columns;
    foreach my $applied_protocol (@$applied_protocols) {
      my $protocol = $applied_protocol->{'applied_protocol'}->get_protocol();
      if (!scalar(@protocol_columns)) {
        # Core protocol name
        push @protocol_columns, [ "Protocol REF" ];
        # Protocol termsource
        if ($protocol->get_termsource() && $protocol->get_termsource->get_db()) {
          push @columns, [ "Term Source REF" ];
          if (length($protocol->get_termsource()->get_accession())) {
            push @columns, [ "Term Accession Number" ];
          }
        }
        # Protocol attributes
        foreach my $attribute (@{$protocol->get_attributes()}) {
          push @columns, $self->flatten_attribute($attribute);
        }
      }
      my $cur_column = 0;
      push @{$protocol_columns[$cur_column++]}, $protocol->get_name();
      push @{$protocol_columns[$cur_column++]}, $protocol->get_termsource()->get_db()->get_name() if $protocol->get_termsource() && $protocol->get_termsource()->get_db();
      push @{$protocol_columns[$cur_column++]}, $protocol->get_termsource()->get_accession() if $protocol->get_termsource() && $protocol->get_termsource()->get_accession();
      foreach my $attribute (@{$protocol->get_attributes()}) {
        push @{$protocol_columns[$cur_column++]}, $attribute->get_value();
        push @{$protocol_columns[$cur_column++]}, $attribute->get_termsource()->get_db()->get_name() if $attribute->get_termsource() && $attribute->get_termsource()->get_db();
        push @{$protocol_columns[$cur_column++]}, $attribute->get_termsource()->get_accession() if $attribute->get_termsource() && $attribute->get_termsource()->get_accession();
      }
    }
    # Push the protocol's columns onto the final @columns array
    push @columns, @protocol_columns;

    # If this is NOT one of the leftmost (first) protocols, put the inputs 
    # after the protocol name.
    if ($i > 0) {
      my @input_columns;
      foreach my $applied_protocol (@$applied_protocols) {
        # Inputs go after the protocol if it's not the first protocol
        my @input_data = @{$applied_protocol->{'applied_protocol'}->get_input_data()};
        for (my $i = 0; $i < scalar(@input_data); $i++) {
          my $input = $input_data[$i];
          $input_columns[$i] = [] if (ref($input_columns[$i]) ne "ARRAY");
          my @is_seen = grep { $_ == $input->get_chadoxml_id} @seen_data;
          # If this datum has already been used as an output from the previous
          # set of protocols, then it shouldn't be reprinted as an input here
          if (!scalar(@is_seen)) {
            $self->flatten_data(@input_columns[$i], $input);
          }
        } 
      }
      for (my $i = 0; $i < scalar(@input_columns); $i++) {
        push @columns, @{$input_columns[$i]};
      }
    }

    # Now get the outputs, which go after the inputs after the protocol.
    # Make sure to track what outputs are used in @seen_data so we don't 
    # reprint them as inputs in the next set of protocols
    @seen_data = ();
    my @output_columns;
    foreach my $applied_protocol (@$applied_protocols) {
      my @output_data = @{$applied_protocol->{'applied_protocol'}->get_output_data()};
      for (my $i = 0; $i < scalar(@output_data); $i++) {
        my $output = $output_data[$i];
        $output_columns[$i] = [] if (ref($output_columns[$i]) ne "ARRAY");
        $self->flatten_data(@output_columns[$i], $output);
        push @seen_data, $output->get_chadoxml_id();
      } 
    }
    for (my $i = 0; $i < scalar(@output_columns); $i++) {
      push @columns, @{$output_columns[$i]};
    }
  }

  return \@columns;
}

sub flatten_data : PRIVATE {
  my ($self, $data_columns, $datum) = @_;
  if (
    $datum->get_type() && $datum->get_type()->get_name() eq "anonymous_datum" &&
    $datum->get_type()->get_cv() && $datum->get_type()->get_cv()->get_name eq "modencode"
  ) { 
    # Skip "anonymous" data
    return; 
  }
  if (!scalar(@$data_columns)) {
    push @$data_columns, $self->get_data_column_headings($datum);
  }
  my $cur_column = 0;
  push @{$data_columns->[$cur_column++]}, $datum->get_value();
  push @{$data_columns->[$cur_column++]}, $datum->get_termsource()->get_db()->get_name() if $datum->get_termsource() && $datum->get_termsource()->get_db();
  push @{$data_columns->[$cur_column++]}, $datum->get_termsource()->get_accession() if $datum->get_termsource() && $datum->get_termsource()->get_accession();
  foreach my $attribute (@{$datum->get_attributes()}) {
    push @{$data_columns->[$cur_column++]}, $attribute->get_value();
    push @{$data_columns->[$cur_column++]}, $attribute->get_termsource()->get_db()->get_name() if $attribute->get_termsource() && $attribute->get_termsource()->get_db();
    push @{$data_columns->[$cur_column++]}, $attribute->get_termsource()->get_accession() if $attribute->get_termsource() && $attribute->get_termsource()->get_accession();
  }
}

sub get_data_column_headings : PRIVATE {
  my ($self, $datum) = @_;
  my @columns;
  if (
    $datum->get_type() && $datum->get_type()->get_name() eq "anonymous_datum" &&
    $datum->get_type()->get_cv() && $datum->get_type()->get_cv()->get_name eq "modencode"
  ) { 
    # Skip "anonymous" data
    return; 
  }
  # Datum heading and name
  my $datum_heading = $datum->get_heading();
  if (length($datum->get_name())) {
    $datum_heading .= "[" . $datum->get_name() . "]" if (length($datum->get_name()));
  }
  # Datum type
  if ($datum->get_type() && length($datum->get_type()->get_name()) && !($datum->get_type()->get_cv() && $datum->get_type()->get_cv()->get_name eq "mage")) {
    $datum_heading .= "(";
    $datum_heading .= $datum->get_type()->get_cv()->get_name() . ":" if ($datum->get_type()->get_cv() && length($datum->get_type()->get_cv()->get_name()));
    $datum_heading .= $datum->get_type()->get_name() . ")";
  }
  push @columns, [ $datum_heading ];

  # Datum termsource
  if ($datum->get_termsource() && $datum->get_termsource->get_db()) {
    push @columns, [ "Term Source REF" ];
    if (length($datum->get_termsource()->get_accession())) {
      push @columns, [ "Term Accession Number" ];
    }
  }

  # Datum attributes
  foreach my $attribute (@{$datum->get_attributes()}) {
    push @columns, $self->flatten_attribute($attribute);
  }

  return @columns;
}

sub flatten_attribute : PRIVATE {
  my ($self, $attribute) = @_;
  my @columns;
  # Attribute heading and name
  my $attribute_heading = $attribute->get_heading();
  if (length($attribute->get_name())) {
    $attribute_heading .= "[" . $attribute->get_name() . "]" if (length($attribute->get_name()));
  }
  # Attribute type
  if ($attribute->get_type() && length($attribute->get_type()->get_name()) && !($attribute->get_type()->get_cv() && $attribute->get_type()->get_cv()->get_name eq "mage")) {
    $attribute_heading .= "(";
    $attribute_heading .= $attribute->get_type()->get_cv()->get_name() . ":" if ($attribute->get_type()->get_cv() && length($attribute->get_type()->get_cv()->get_name()));
    $attribute_heading .= $attribute->get_type()->get_name() . ")";
  }
  push @columns, [ $attribute_heading ];
  # Attribute termsource
  if ($attribute->get_termsource() && $attribute->get_termsource->get_db()) {
    push @columns, [ "Term Source REF" ];
    if (length($attribute->get_termsource()->get_accession())) {
      push @columns, [ "Term Accession Number" ];
    }
  }

  return @columns;
}


sub load_experiment {
  my ($self, $experiment_id) = @_;

  my @protocol_slots;
  # Get the first (leftmost) set of applied protocols used in this experiment
  my $first_proto_sth = $self->get_dbh()->prepare("SELECT first_applied_protocol_id FROM experiment_applied_protocol WHERE experiment_id = ?");
  $first_proto_sth->execute($experiment_id);
  my @applied_protocols;
  while (my ($app_proto_id) = $first_proto_sth->fetchrow_array()) {
    my $app_proto = $self->get_applied_protocol($app_proto_id);
    push @applied_protocols, $app_proto;
  }
  @applied_protocols = map { { 'applied_protocol' => $_, 'previous_applied_protocol_id' => [] } } @applied_protocols;
  $protocol_slots[0] = \@applied_protocols;

  # Follow the linked list of applied_protocol->data->applied_protocol and
  # fill in the rest of the protocol slots
  my $get_next_applied_protocols_sth = $self->get_dbh()->prepare("SELECT apd.applied_protocol_id FROM applied_protocol_data apd WHERE apd.data_id = ? AND apd.direction = 'input'");
  my %next_applied_protocols;
  do { # while (scalar(values(%next_applied_protocols)))
    my @applied_protocol_data;
    # For each applied_protocol in the current column, get the output data
    foreach my $applied_protocol (@{$protocol_slots[scalar(@protocol_slots)-1]}) {
      foreach my $datum (@{$applied_protocol->{'applied_protocol'}->get_output_data()}) {
        push @applied_protocol_data, { 
          'from_applied_protocol' => $applied_protocol->{'applied_protocol'}->get_chadoxml_id, 
          'datum' => $datum
        };
      }
    }
    # For each piece of output data collected, fetch the applied protocols
    # that use it as input data
    my @next_applied_protocol_ids;
    undef(%next_applied_protocols);
    foreach my $datum (@applied_protocol_data) {
      $get_next_applied_protocols_sth->execute($datum->{'datum'}->get_chadoxml_id());
      while (my ($applied_protocol_id) = $get_next_applied_protocols_sth->fetchrow_array()) {
        if (!scalar(grep { $_ == $applied_protocol_id } @next_applied_protocol_ids)) {
          push @next_applied_protocol_ids, $applied_protocol_id;
          $next_applied_protocols{$applied_protocol_id} = {
            'applied_protocol' => $self->get_applied_protocol($applied_protocol_id),
            'previous_applied_protocol_id' => [ $datum->{'from_applied_protocol'} ],
          };
        } else {
          push @{$next_applied_protocols{$applied_protocol_id}->{'previous_applied_protocol_id'}}, $datum->{'from_applied_protocol'};
        }
      }
    }
    # If there were any applied_protocols collected, then push them into the
    # protocol slots
    if (scalar(values(%next_applied_protocols))) {
      my @copy_of_next_applied_protocols = values(%next_applied_protocols);
      push @protocol_slots, \@copy_of_next_applied_protocols;
    }
  } while (scalar(values(%next_applied_protocols)));
  $protocol_slots{ident $self} = \@protocol_slots;

  my $experiment_sth = $self->get_dbh()->prepare("SELECT experiment_id, description FROM experiment WHERE experiment_id = ?");
  $experiment_sth->execute($experiment_id);
  my $row = $experiment_sth->fetchrow_hashref();
  $experiment{ident $self} = new ModENCODE::Chado::Experiment({
      'description' => $row->{'description'},
      'applied_protocol_slots' => $self->get_normalized_protocol_slots(),
    });
  my $experiment_prop_sth = $self->get_dbh()->prepare("SELECT name, type_id, dbxref_id, value, rank FROM experiment_prop WHERE experiment_id = ?");
  $experient_prop_sth->execute($experiment_id);
  while (my $row = $experiment_prop_sth->fetchrow_hashref()) {
    my $property = new ModENCODE::Chado::ExperimentProp({
        'name' => $row->{'name'},
        'value' => $row->{'value'},
        'rank' => $row->{'rank'},
      });
    my $termsource = $self->get_termsource($row->{'dbxref_id'};
    $property->set_termsource($termsource) if $termsource;
    my $type = $self->get_type($row->{'type_id'};
    $property->set_type($type) if $type;
    $experiment{ident $self}->add_property($property);
  }
}

sub get_applied_protocol {
  my ($self, $applied_protocol_id) = @_;
  my $applied_protocol = new ModENCODE::Chado::AppliedProtocol({ 'chadoxml_id' => $applied_protocol_id });
  my $sth = $self->get_dbh()->prepare("SELECT protocol_id FROM applied_protocol WHERE applied_protocol_id = ?");
  $sth->execute($applied_protocol_id);
  my ($protocol_id) = $sth->fetchrow_array();
  my $protocol = $self->get_protocol($protocol_id);
  $applied_protocol->set_protocol($protocol);
  $sth = $self->get_dbh()->prepare("SELECT data_id, direction FROM applied_protocol_data WHERE applied_protocol_id = ?");
  $sth->execute($applied_protocol_id);
  while (my $row = $sth->fetchrow_hashref()) {
    if ($row->{'direction'} =~ 'input') {
      $applied_protocol->add_input_datum($self->get_datum($row->{'data_id'}));
    } else {
      $applied_protocol->add_output_datum($self->get_datum($row->{'data_id'}));
    }
  }
  return $applied_protocol;
}

sub get_protocol {
  my ($self, $protocol_id) = @_;
  my $protocol = new ModENCODE::Chado::Protocol({ 'chadoxml_id' => $protocol_id });
  my $sth = $self->get_dbh()->prepare("SELECT name, description, dbxref_id FROM protocol WHERE protocol_id = ?");
  $sth->execute($protocol_id);
  my $row = $sth->fetchrow_hashref();
  $protocol->set_name($row->{'name'});
  $protocol->set_description($row->{'description'});
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  $protocol->set_termsource($termsource) if $termsource;
  $sth = $self->get_dbh()->prepare("SELECT attribute_id FROM protocol_attribute WHERE protocol_id = ?");
  $sth->execute($protocol_id);
  while (my ($attr_id) = $sth->fetchrow_array()) {
    $protocol->add_attribute($self->get_attribute($attr_id));
  }
  return $protocol;
}

sub get_datum {
  my ($self, $datum_id) = @_;
  my $datum = new ModENCODE::Chado::Data({ 'chadoxml_id' => $datum_id });
  my $sth = $self->get_dbh()->prepare("SELECT name, heading, value, dbxref_id, type_id FROM data WHERE data_id = ?");
  $sth->execute($datum_id);
  my $row = $sth->fetchrow_hashref();
  $datum->set_name($row->{'name'});
  $datum->set_heading($row->{'heading'});
  $datum->set_value($row->{'value'});
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  $datum->set_termsource($termsource) if $termsource;
  my $type = $self->get_type($row->{'type_id'});
  $datum->set_type($type) if $type;
  $sth = $self->get_dbh()->prepare("SELECT attribute_id FROM data_attribute WHERE data_id = ?");
  $sth->execute($datum_id);
  while (my ($attr_id) = $sth->fetchrow_array()) {
    $datum->add_attribute($self->get_attribute($attr_id));
  }
  return $datum;
}

sub get_termsource {
  my ($self, $dbxref_id) = @_;
  return 0 unless($dbxref_id);
  my $sth = $self->get_dbh()->prepare("SELECT dbx.accession, dbx.version, db.name FROM dbxref dbx INNER JOIN db ON dbx.db_id = db.db_id WHERE dbxref_id = ?");
  $sth->execute($dbxref_id);
  my $row = $sth->fetchrow_hashref();
  my $dbxref = new ModENCODE::Chado::DBXref({
      'accession' => $row->{'accession'},
      'version' => $row->{'version'},
      'db' => new ModENCODE::Chado::DB({ 'name' => $row->{'name'} }),
    });
  return $dbxref;
}

sub get_type {
  my ($self, $cvterm_id) = @_;
  return 0 unless($cvterm_id);
  my $sth = $self->get_dbh()->prepare("SELECT cvt.name, cvt.definition, cvt.dbxref_id, cv.name as cvname, cv.definition as cvdefinition FROM cvterm cvt INNER JOIN cv ON cvt.cv_id = cv.cv_id WHERE cvterm_id = ?");
  $sth->execute($cvterm_id);
  my $row = $sth->fetchrow_hashref();
  my $cvterm = new ModENCODE::Chado::CVTerm({
      'name' => $row->{'name'},
      'definition' => $row->{'definition'},
      'cv' => new ModENCODE::Chado::CV({ 'name' => $row->{'cvname'}, 'definition' => $row->{'definition'} }),
    });
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  $cvterm->set_dbxref($termsource) if $termsource;
  return $cvterm;
}

sub get_attribute {
  my ($self, $attribute_id) = @_;
  my $attribute = new ModENCODE::Chado::Attribute({ 'chadoxml_id' => $attribute_id });
  my $sth = $self->get_dbh()->prepare("SELECT name, heading, value, dbxref_id, type_id FROM attribute WHERE attribute_id = ?");
  $sth->execute($attribute_id);
  my $row = $sth->fetchrow_hashref();
  $attribute->set_name($row->{'name'});
  $attribute->set_heading($row->{'heading'});
  $attribute->set_value($row->{'value'});
  my $termsource = $self->get_termsource($row->{'dbxref_id'});
  $attribute->set_termsource($termsource) if $termsource;
  my $type = $self->get_type($row->{'type_id'});
  $attribute->set_type($type) if $type;
  return $attribute;
}

sub denormalize_applied_protocol {
  my ($applied_protocol, $protocol_slots, $new_protocol_slots, $slotnum) = @_;
  $slotnum ||= 1;
  if (!defined($protocol_slots->[$slotnum])) {
    return (1);
  }
  my $next_applied_protocols = $protocol_slots->[$slotnum];
  my $previous_applied_protocol_id = $applied_protocol->{'applied_protocol'}->get_chadoxml_id();
  my @these_protocols;

  foreach my $next_applied_protocol (@$next_applied_protocols) {
    foreach my $next_prev_applied_protocol_id (@{$next_applied_protocol->{'previous_applied_protocol_id'}}) {
      if ( $next_prev_applied_protocol_id == $previous_applied_protocol_id) {
        my @next_rows = denormalize_applied_protocol($next_applied_protocol, $protocol_slots, $new_protocol_slots, $slotnum+1);
        for (my $i = 0; $i < scalar(@next_rows); $i++) {
          push @these_protocols, $next_applied_protocol;
        }
      }
    }
  }

  push @{$new_protocol_slots->[$slotnum]}, @these_protocols;
  return @these_protocols;
}

sub get_dbh : PRIVATE {
  my ($self, $suppress_warnings) = @_;
  
  if (!defined($dbh{ident $self}) || !$dbh{ident $self} || ($dbh{ident $self} && !($dbh{ident $self}->{Active}))) {
    return undef unless defined($self->get_db());
    my $dsn = "dbi:Pg:dbname=" . $self->get_db();
    $dsn .= ";host=" . $self->get_host() if defined($self->get_host());
    $dsn .= ";port=" . $self->get_port() if defined($self->get_port());
    eval {
      $dbh{ident $self} = DBI->connect($dsn, $self->get_username(), $self->get_password(), { RaiseError => 1, AutoCommit => 0 });
    };

    if (!$suppress_warnings && (!defined($dbh{ident $self}) || !$dbh{ident $self})) {
      croak "Couldn't connect to data source \"$dsn\", using username \"" . $self->get_username() . "\" and password \"" . $self->get_password() . "\"\n  " . $DBI::errstr;
    }
  }

  return $dbh{ident $self};
}

1;

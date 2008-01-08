package ModENCODE::Chado::AppliedProtocol;

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );

# Relationships
my %input_data       :ATTR( :get<input_data>,           :default<[]> );
my %output_data      :ATTR( :get<output_data>,          :default<[]> );
my %protocol         :ATTR( :get<protocol>,             :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $input_data = $args->{'input_data'};
  if (defined($input_data)) {
    if (ref($input_data) ne 'ARRAY') {
      $input_data = [ $input_data ];
    }
    foreach my $input_datum (@$input_data) {
      $self->add_input_datum($input_datum);
    }
  }
  my $output_data = $args->{'output_data'};
  if (defined($output_data)) {
    if (ref($output_data) ne 'ARRAY') {
      $output_data = [ $output_data ];
    }
    foreach my $output_datum (@$output_data) {
      $self->add_output_datum($output_datum);
    }
  }
  my $protocol = $args->{'protocol'};
  if (defined($protocol)) {
    $self->set_protocol($protocol);
  }
}

sub add_input_datum {
  my ($self, $input_datum) = @_;
  ($input_datum->isa('ModENCODE::Chado::Data')) or croak("Can't add a " . ref($input_datum) . " as a input_datum.");
  push @{$input_data{ident $self}}, $input_datum;
}

sub add_output_datum {
  my ($self, $output_datum) = @_;
  ($output_datum->isa('ModENCODE::Chado::Data')) or croak("Can't add a " . ref($output_datum) . " as a output_datum.");
  push @{$output_data{ident $self}}, $output_datum;
}

sub set_protocol {
  my ($self, $protocol) = @_;
  ($protocol->isa('ModENCODE::Chado::Protocol')) or croak("Can't add a " . ref($protocol) . " as a protocol.");
  $protocol{ident $self} = $protocol;
}

sub to_string {
  my ($self) = @_;
  my $string = "Applied Protocol \"" . $self->get_protocol()->to_string() . "\"->";
  $string .= "(" . join(", ", map { $_->to_string() } @{$self->get_input_data()}) . ")";
  $string .= " = (" . join(", ", map { $_->to_string() } @{$self->get_output_data()}) . ")";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  my @input_data = @{$self->get_input_data()};
  return 0 unless scalar(@input_data) == scalar(@{$other->get_input_data()});
  foreach my $datum (@input_data) {
    return 0 unless scalar(grep { $_->equals($datum) } @{$other->get_input_data()});
  }

  my @output_data = @{$self->get_output_data()};
  return 0 unless scalar(@output_data) == scalar(@{$other->get_output_data()});
  foreach my $datum (@output_data) {
    return 0 unless scalar(grep { $_->equals($datum) } @{$other->get_output_data()});
  }

  if ($self->get_protocol()) {
    return 0 unless $other->get_protocol();
    return 0 unless $self->get_protocol()->equals($other->get_protocol());
  }

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::AppliedProtocol({
      'chadoxml_id' => $self->get_chadoxml_id(),
    });
  foreach my $input_datum (@{$self->get_input_data()}) {
    $clone->add_input_datum($input_datum->clone());
  }
  foreach my $output_datum (@{$self->get_output_data()}) {
    $clone->add_output_datum($output_datum->clone());
  }
  $clone->set_protocol($self->get_protocol()->clone());
  return $clone;
}

1;

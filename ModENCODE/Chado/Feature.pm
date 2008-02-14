package ModENCODE::Chado::Feature;

use strict;
use Class::Std;
use Carp qw(carp croak);

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %name             :ATTR( :name<name>,                :default<undef> );
my %uniquename       :ATTR( :name<uniquename>,          :default<undef> );
my %residues         :ATTR( :name<residues>,            :default<undef> );
my %seqlen           :ATTR( :name<seqlen>,              :default<undef> );
my %timeaccessioned  :ATTR( :name<timeaccessioned>,     :default<undef> );
my %timelastmodified :ATTR( :name<timelastmodified>,    :default<undef> );

# Relationships
my %organism         :ATTR( :get<organism>,             :default<undef> );
my %type             :ATTR( :get<type>,                 :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $organism = $args->{'organism'};
  if (defined($organism)) {
    $self->set_organism($organism);
  }
  my $type = $args->{'type'};
  if (defined($type)) {
    $self->set_type($type);
  }
}

sub set_type {
  my ($self, $type) = @_;
  ($type->isa('ModENCODE::Chado::CVTerm')) or croak("Can't add a " . ref($type) . " as a type.");
  $type{ident $self} = $type;
}

sub set_organism {
  my ($self, $organism) = @_;
  ($organism->isa('ModENCODE::Chado::Organism')) or Carp::confess("Can't add a " . ref($organism) . " as an organism.");
  $organism{ident $self} = $organism;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_uniquename() eq $other->get_uniquename() && $self->get_residues() eq $other->get_residues() && $self->get_seqlen() eq $other->get_seqlen() && $self->get_timeaccessioned() eq $other->get_timeaccessioned() && $self->get_timelastmodified() eq $other->get_timelastmodified());
  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  }

  if ($self->get_organism()) {
    return 0 unless $other->get_organism();
    return 0 unless $self->get_organism()->equals($other->get_organism());
  }

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Feature({
      'chadoxml_id' => $self->get_chadoxml_id(),
      'name' => $self->get_name(),
      'uniquename' => $self->get_uniquename(),
      'residues' => $self->get_residues(),
      'seqlen' => $self->get_seqlen(),
      'timeaccessioned' => $self->get_timeaccessioned(),
      'timelastmodified' => $self->get_timelastmodified(),
    });
  $clone->set_type($self->get_type()->clone()) if $self->get_type();
  $clone->set_organism($self->get_organism()->clone()) if $self->get_organism();
  return $clone;
}

sub to_string {
  my ($self) = @_;
  my $string = "feature('" . $self->get_name() . "'/" . $self->get_uniquename() . "')";
  $string .= " of organism " . $self->get_organism()->to_string() if $self->get_organism();
  return $string;
}

1;

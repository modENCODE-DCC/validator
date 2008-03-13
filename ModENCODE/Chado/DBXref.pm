package ModENCODE::Chado::DBXref;

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %accession        :ATTR( :name<accession>,           :default<''> );
my %version          :ATTR( :name<version>,             :default<undef> );

# Relationships
my %db               :ATTR( :get<db>,                   :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $db = $args->{'db'};
  if (defined($db)) {
    $self->set_db($db);
  }
}

sub set_db {
  my ($self, $db) = @_;
  ($db->isa('ModENCODE::Chado::DB')) or croak("Can't add a " . ref($db) . " as a DB.");
  $db{ident $self} = $db;
}

sub to_string {
  my ($self) = @_;
  my $string = "[REF:" . $self->get_db()->to_string() . ".";
  $string .= ($self->get_accession() || "xxx");
  $string .= "(" . $self->get_version() . ")" if defined($self->get_version());
  $string .= "]";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_accession() eq $other->get_accession() && $self->get_version() eq $other->get_version());

  if ($self->get_db()) {
    return 0 unless $other->get_db();
    return 0 unless $self->get_db()->equals($other->get_db());
  } else {
    return 0 if $other->get_db();
  }


  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::DBXref({
      'accession' => $self->get_accession(),
      'version' => $self->get_version(),
    });
  $clone->set_db($self->get_db()->clone());
  return $clone;
}

1;

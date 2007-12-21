package ModENCODE::Chado::DBXref;

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %accession        :ATTR( :name<accession>,           :default<''> );
my %version          :ATTR( :name<version>,             :default<''> );

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
  $string .= ($self->get_accession() || "xxx") . "]";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_accession() eq $other->get_accession() && $self->get_version() eq $other->get_version());

  if ($self->get_db()) {
    return 0 unless $other->get_db();
    return 0 unless $self->get_db()->equals($other->get_db());
  }

  return 1;
}

1;

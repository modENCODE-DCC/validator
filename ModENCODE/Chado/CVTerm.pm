package ModENCODE::Chado::CVTerm;

use strict;
use Class::Std;
use Carp qw(croak);

use ModENCODE::Chado::DB;
use ModENCODE::Chado::DBXref;

# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %definition       :ATTR( :name<definition>,          :default<''> );
my %is_obsolete      :ATTR( :name<is_obsolete>,         :default<0> );

# Relationships
my %cv               :ATTR( :get<cv>,                   :default<undef> );
my %dbxref           :ATTR( :get<dbxref>,               :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cv = $args->{'cv'};
  if (defined($cv)) {
    $self->set_cv($cv);
  }
  my $dbxref = $args->{'dbxref'};
  if (defined($dbxref)) {
    $self->set_dbxref($dbxref);
  }
}

sub set_cv {
  my ($self, $cv) = @_;
  ($cv->isa('ModENCODE::Chado::CV')) or croak("Can't add a " . ref($cv) . " as a CV.");
  $cv{ident $self} = $cv;
}

sub set_dbxref {
  my ($self, $dbxref) = @_;
  ($dbxref->isa('ModENCODE::Chado::DBXref')) or croak("Can't add a " . ref($dbxref) . " as a DBXref.");
  $dbxref{ident $self} = $dbxref;
}

sub to_string {
  my ($self) = @_;
  my $string = "{";
  $string .= $self->get_cv()->to_string() . ":" if $self->get_cv();
  $string .= $self->get_name();
  $string .= "}";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_definition() eq $other->get_definition() && $self->get_is_obsolete() eq $other->get_is_obsolete());

  if ($self->get_cv()) {
    return 0 unless $other->get_cv();
    return 0 unless $self->get_cv()->equals($other->get_cv());
  } else {
    return 0 if $other->get_cv();
  }

  if ($self->get_dbxref()) {
    return 0 unless $other->get_dbxref();
    return 0 unless $self->get_dbxref()->equals($other->get_dbxref());
  } else {
    return 0 if $other->get_dbxref();
  }


  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::CVTerm({
      'name' => $self->get_name(),
      'definition' => $self->get_definition(),
      'is_obsolete' => $self->get_is_obsolete(),
    });
  $clone->set_cv($self->get_cv()->clone()) if $self->get_cv();
  $clone->set_dbxref($self->get_dbxref()->clone()) if $self->get_dbxref();
  return $clone;
}
1;

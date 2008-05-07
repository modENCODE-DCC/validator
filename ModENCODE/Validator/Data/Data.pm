package ModENCODE::Validator::Data::Data;
=pod

=head1 NAME

ModENCODE::Validator::Data::Data - Abstract class for creating validators for
BIR-TAB data columns. Validators referenced in L<ModENCODE::Validator::Data>
should at the very least conform to the interface described by this class.

=head1 SYNOPSIS

This class provides a set of both abstract and implemented methods that are
called by the L<merge|ModENCODE::Validator::Data/merge($experiment)> and
L<validate|ModENCODE::Validator::Data/validate($experiment)> methods of
L<ModENCODE::Validator::Data>. Any classes that will be used to validate BIR-TAB
data columns should extend this class. (They are not I<required> to extend this
class, however, as long as they implement the same methods.).

=head1 USAGE

What follows is a sample implementation of a subclass of
C<ModENCODE::Validator::Data::Data> that can be used as a template for creating
new data validators.

  use base qw( ModENCODE::Validator::Data::Data )
  sub validate {
    my ($self) = @_;
    my $success = 1;
    foreach my $datum_hash (@{$self->get_data()}) {
      my $datum = $datum_hash->{'datum'}->clone();
      if ($datum # IS VALID) {
        $datum_hash->{'is_valid'} = 1;
        $datum->CHANGE_SOMETHING;
        $datum_hash->{'merged_datum'} = $datum;
      } else {
        $datum_hash->{'is_valid'} = 0;
        $success = 0;
      }
    }
    return $success;
  }
  sub merge {
    my ($self, $datum, $applied_protocol) = @_;
    if ($self->is_valid($datum, $applied_protocol)) {
      my $validated_datum_hash = $self->get_datum($datum, $applied_protocol);
      return $validated_datum->{'merged_datum'};
    } else {
      die "Error: datum invalid, can't continue merging.";
    }
  }

=head1 FUNCTIONS

=over

=item add_datum($datum, $applied_protocol)

Add a new L<ModENCODE::Chado::Data> to this data validator that will be
validated when L</validate()> is called. 

=item get_data()

Returns an arrayref of hashes containing all of the data added to this validator
so far. The hashes are of the form:

  { 'datum' => $datum, 'applied_protocol' => $applied_protocol, 'is_valid' => $is_valid }

The C<$applied_protocol> is tracked in addition to the datum because a datum
that is valid for one protocol may not be valid for another, so it is important
to know which which protocol is using the C<$datum>.

If you are using the default L</is_valid($datum, $applied_protocol)>
implementation, then the C<$is_valid> variable should be -1 before validation
has been done, and 0 (for invalid) or 1 (for valid) thereafter.

It is also acceptable to add other entries to the hash by pulling out a
datum hashref using L</get_data()> and then adding additional terms to
it.

=item get_datum($datum, $applied_protocol)

Convenience method for pulling out a datum hash from L</get_data()> with a
matching datum and applied protocol. Returns the hash entry, just like
C<grep>ing it from L</get_data()>.

=item validate()

I<Abstract method> - Should validate all data stored in the list of data hashes
returned by L</get_data()>. Return 1 if all tested data are valid, 0 otherwise.

=item merge($datum, $applied_protocol)

I<Abstract method> - Should return a L<attribute|ModENCODE::Chado::Data> that
contains an updated datum for the original C<$datum> attached to
C<$applied_protocol> or the original datum (or a copy) if no changes were made.
The returned datum will be passed to the original datum's
L<mimic|ModENCODE::Chado::Data/mimic($datum)> method.

=item is_valid($datum, $applied_protocol)

Default implementation to check if an datum that has been checked for validity
is, in fact, valid. Returns of the value of the C<'is_valid'> entry in the hash
for the C<$datum> and C<$applied_protocol> returned by L</get_data()>. If
C<'is_valid'> is -1, then C<croak>s because the attribute has not yet been
validated.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Validator::Attributes::Attributes>,
L<ModENCODE::Validator::Attribute>, L<ModENCODE::Chado::Data>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Experiment>,
L<ModENCODE::Chado::AppliedProtocol>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::GFF3>, L<ModENCODE::Validator::Data::Result_File>,
L<ModENCODE::Validator::Data::SO_transcript>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::dbEST_acc>,
L<ModENCODE::Validator::Data::dbEST_acc_list>,

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %data                        :ATTR( :get<data>,                      :default<[]> );
my %data_validator              :ATTR( :init_arg<data_validator> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  if (ref($self) eq "ModENCODE::Validator::Data::Data") {
    croak "ModENCODE::Validator::Data::Data is an abstract class; you cannot create an instance of it.";
  }
}

sub get_data_validator : RESTRICTED {
  my ($self) = @_;
  return $data_validator{ident $self};
}

sub is_valid {
  my ($self, $datum, $applied_protocol) = @_;
  my $validated_entry = grep { $_->{'datum'}->equals($datum) && $_->{'applied_protocol'}->equals($applied_protocol) } @{$self->get_data()};

  if ($validated_entry->{'is_valid'} == -1) {
    croak "The datum " . $datum->to_string() . " hasn't been validated yet";
  } else {
    return $validated_entry->{'is_valid'};
  }
}
sub add_datum {
  my ($self, $datum, $applied_protocol, $quick_check_equals)  = @_;
#  $quick_check_equals ||= 0;
  $datum->isa('ModENCODE::Chado::Data') or Carp::confess "Can't add a " .  ref($datum) . " to a data validator as a datum.";
  $applied_protocol->isa('ModENCODE::Chado::AppliedProtocol') or Carp::confess "Can't add a " .  ref($applied_protocol) . " to a data validator as an applied_protocol.";
#  if ($quick_check_equals) {
#    my $datum_exists = scalar(grep { $_->{'datum'} == $datum } @{$self->get_data()});
#    if (!$datum_exists) {

      push @{$data{ident $self}}, { 'datum' => $datum, 'applied_protocol' => $applied_protocol, 'is_valid' => -1 };
#    }
#  } else {
#    my $datum_exists = scalar(
#      grep { $_->{'datum'}->equals($datum) && $_->{'applied_protocol'}->equals($applied_protocol) } @{$self->get_data()}
#    );
#    my $datum_exists = scalar(grep { $_->{'datum'} == $datum } @{$self->get_data()});
#    if (!$datum_exists) {
#      push @{$self->get_data()}, { 'datum' => $datum->clone(), 'applied_protocol' => $applied_protocol, 'is_valid' => -1 };
#    }
#  }
}

sub get_datum {
  my ($self, $datum, $applied_protocol) = @_;
  my ($entry) = grep { $_->{'datum'}->equals($datum) && $_->{'applied_protocol'}->equals($applied_protocol) } @{$self->get_data()};
  return $entry;
}
sub validate {
  my ($self) = @_;
  croak "You must implement the 'validate' method in " . ref($self) . " before you use it as a data validator.";
}
sub merge {
  my ($self) = @_;
  croak "You must implement the 'merge' method in " . ref($self) . " before you use it as a data validator.";
}

1;

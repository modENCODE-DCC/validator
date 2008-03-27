package ModENCODE::Validator::Data::Data;

use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %data                        :ATTR( :get<data>,                      :default<[]> );
my %data_validator              :ATTR( :init_arg<data_validator> );

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
  croak "Can't add a " . ref($datum) . " as a ModENCODE::Chado::Data" unless ref($datum) eq "ModENCODE::Chado::Data";
  croak "Can't add a " . ref($applied_protocol) . " as a ModENCODE::Chado::AppliedProtocol" unless ref($applied_protocol) eq "ModENCODE::Chado::AppliedProtocol";
#  if ($quick_check_equals) {
#    my $datum_exists = scalar(grep { $_->{'datum'} == $datum } @{$self->get_data()});
#    if (!$datum_exists) {
      push @{$self->get_data()}, { 'datum' => $datum, 'applied_protocol' => $applied_protocol, 'is_valid' => -1 };
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

1;

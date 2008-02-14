package ModENCODE::Validator::Data::Data;

use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %data                        :ATTR( :get<data>, :default<[]> );

sub is_valid {
  my ($self, $datum) = @_;
  my $validated_entry = grep { $_->{'datum'}->equals($datum); } @{$self->get_data()};

  if ($validated_entry->{'is_valid'} == -1) {
    croak "The datum " . $datum->to_string() . " hasn't been validated yet";
  } else {
    return $validated_entry->{'is_valid'};
  }
}
sub add_datum {
  my ($self, $datum)  = @_;
  croak "Can't add a " . ref($datum) . " as a ModENCODE::Chado::Data" unless ref($datum) eq "ModENCODE::Chado::Data";
  my $datum_exists = scalar(
    grep { $_->{'datum'}->equals($datum); } @{$self->get_data()}
  );
  if (!$datum_exists) {
    push @{$self->get_data()}, { 'datum' => $datum->clone(), 'is_valid' => -1 };
  }
}

1;

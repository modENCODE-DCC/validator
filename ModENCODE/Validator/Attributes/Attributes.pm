package ModENCODE::Validator::Attributes::Attributes;

use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %attributes                        :ATTR( :get<attributes>, :default<[]> );

sub is_valid {
  my ($self, $attribute) = @_;
  my $validated_entry = grep { $_->{'attribute'}->equals($attribute); } @{$self->get_attributes()};

  if ($validated_entry->{'is_valid'} == -1) {
    croak "The attribute " . $attribute->to_string() . " hasn't been validated yet";
  } else {
    return $validated_entry->{'is_valid'};
  }
}
sub add_attribute {
  my ($self, $attribute)  = @_;
  croak "Can't add a " . ref($attribute) . " as a ModENCODE::Chado::Attribute" unless ref($attribute) eq "ModENCODE::Chado::Attribute";
  my $attribute_exists = scalar(
    grep { $_->{'attribute'}->equals($attribute); } @{$self->get_attributes()}
  );
  if (!$attribute_exists) {
    push @{$self->get_attributes()}, { 'attribute' => $attribute->clone(), 'is_valid' => -1 };
  }
}

1;

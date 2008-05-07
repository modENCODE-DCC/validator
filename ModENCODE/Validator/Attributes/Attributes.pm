package ModENCODE::Validator::Attributes::Attributes;
=pod

=head1 NAME

ModENCODE::Validator::Attributes::Attributes - Abstract class for creating
validators for BIR-TAB attribute columns. Validators referenced in
L<ModENCODE::Validator::Attributes> should at the very least conform to the
interface described by this class.

=head1 SYNOPSIS

This class provides a set of both abstract and implemented methods that are
called by the L<merge|ModENCODE::Validator::Attributes/merge($experiment)> and
L<validate|ModENCODE::Validator::Attributes/validate($experiment)> methods of
L<ModENCODE::Validator::Attributes>. Any classes that will be used to validate
BIR-TAB attribute columns should extend this class. (They are not I<required> to
extend this class, however, as long as they implement the same methods.)

=head1 USAGE

What follows is a sample implementation of a subclass of
C<ModENCODE::Validator::Attributes::Attributes> that can be used as a template
for creating new attribute validators.

  use base qw( ModENCODE::Validator::Attributes::Attributes );
  sub validate {
    my ($self) = @_;
    my $success = 1;
    foreach my $attribute_hash (@{$self->get_attributes()}) {
      my $attribute = $attribute_hash->{'attribute'}->clone();
      if ($attribute # IS VALID) {
        $attribute_hash->{'is_valid'} = 1;
        $attribute->CHANGE_SOMETHING;
        $attribute_hash->{'merged_attributes'} = [ $new_attribute ];
      } else {
        $attribute_hash->{'is_valid'} = 0;
        $success = 0;
      }
    }
    return $success;
  }
  sub merge {
    my ($self, $attribute) = @_;
    if ($self->is_valid($attribute)) {
      my ($validated_entry) = grep { $_->{'attribute'}->equals($attribute); } @{$self->get_attributes()};
      return $validated_entry->{'merged_attributes'};
    } else {
      die "Error: attribute invalid, can't continue merging.";
    }
  }

=head1 FUNCTIONS

=over

=item add_attribute($attribute) 

Add a new L<ModENCODE::Chado::Attribute> to this attribute validator that will
be validated when L</validate()> is called.

=item get_attributes()

Returns an arrayref of hashes containing all of the attributes added to this
validator so far. The hashes are of the form:

  { 'attribute' => $attribute, 'is_valid' => $is_valid }

If you are using the default L</is_valid($attribute)> implementation, then the
C<$is_valid> variable should be -1 before validation has been done, and 0 (for
invalid) or 1 (for valid) thereafter.

It is also acceptable to add other entries to the hash by pulling out an
attribute hashref using L</get_attributes()> and then adding additional terms to
it.

  my $attr_hash = $validator->get_attributes()->[0];
  $attr_hash->{'new_key'} = $additional_stuff;

This technique is commonly used by subclasses to attach additional data during
the validation step that will then be used during the merging step.

=item validate()

I<Abstract method> - Should validate all attributes stored in the list of attribute
hashes returned by L</get_attributes()>. Return 1 if all tested attributes are
valid, 0 otherwise.

=item merge($attribute)

I<Abstract method> - Should return an arrayref of
L<attribute|ModENCODE::Chado::Attribute>(s) that contains an updated attribute
and any additional attributes generated for the original C<$attribute> or an
arrayref containing the original attribute (or a copy) if no changes were made.
The returned attributes will replace the one passed in.

=item is_valid($attribute)

Default implementation to check if an attribute that has been checked for
validity is, in fact, valid. Returns of the value of the C<'is_valid'> entry in
the hash for the C<$attribute> returned by L</get_attributes()>. If
C<'is_valid'> is -1, then C<croak>s because the attribute has not yet been
validated.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Validator::Attributes>,
L<ModENCODE::Validator::Attributes::Organism>,
L<ModENCODE::Validator::Attributes::URL_mediawiki_expansion>,
L<ModENCODE::Chado::Attribute>, L<ModENCODE::Validator::Data::Data>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %attributes                        :ATTR( :get<attributes>, :default<[]> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  if (ref($self) eq "ModENCODE::Validator::Attributes::Attributes") {
    croak "ModENCODE::Validator::Attributes::Attributes is an abstract class; you cannot create an instance of it.";
  }
}

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
  $attribute->isa('ModENCODE::Chado::Attribute') or Carp::confess "Can't add a " . ref($attribute) . " to an attribute validator as an attribute.";
  my $attribute_exists = scalar(
    grep { $_->{'attribute'}->equals($attribute); } @{$self->get_attributes()}
  );
  if (!$attribute_exists) {
    push @{$self->get_attributes()}, { 'attribute' => $attribute->clone(), 'is_valid' => -1 };
  }
}
sub validate {
  my ($self) = @_;
  croak "You must implement the 'validate' method in " . ref($self) . " before you use it as an attribute validator.";
}
sub merge {
  my ($self) = @_;
  croak "You must implement the 'merge' method in " . ref($self) . " before you use it as an attribute validator.";
}

1;

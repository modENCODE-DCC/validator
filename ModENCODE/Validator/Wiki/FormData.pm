package ModENCODE::Validator::Wiki::FormData;
=pod

=head1 NAME

ModENCODE::Validator::Wiki::FormData - Helper class for SOAP transactions
between the MediaWiki DBFields extension and L<ModENCODE::Validator::Wiki>.

=head1 SYNOPSIS

This class presents a L<Class::Std> interface for dealing with L<SOAP::Lite>
SOAP responses from the MediaWiki DBFields extension. A DBFields form result
(from the I<getFormData> SOAP service) can be converted into a C<FormData>
object by simply L<constructing|/new(\%args)> a C<FormData> object from the SOAP result.

=head1 USAGE

To generate a C<FormData> object from a SOAP response, bless the response object
as a HASH and then pass it to the C<FormData> L<constructor|/new(\%args)>:

  my $soap_client = SOAP::Lite->service(ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'));
  my $soap_result = $soap_client->getFormData($soap_query);
  bless($soap_result, 'HASH');

  my $formdata = new ModENCODE::Validator::Wiki::FormData($soap_result);
  print $formdata->get_name() . ": " . $formdata->get_version();

=head1 FUNCTIONS

=over

=item get_version() | set_version($version)

Return or set the revision number of the DBFields form that is being fetched.
This number indicates the number of changes that have been made to the DBFields
form.

=item get_name() | set_name($name)

Return or set the name of the DBFields form that is being fetched.

=item get_values() | set_values($values)

Return an array of L<ModENCODE::Validator::Wiki::FormValues> objects for the
DBFields form that is being fetched. Note that the name C<FormValues> is a
little misleading; a single L<FormValues|ModENCODE::Validator::Wiki::FormValues>
object is equivalent to just a single hash key and an array of values like C<{
$key =E<gt> \@values }>

When setting values, C<$values> can be either an arrayref, I<OR> an
C<ArrayOfFormValues> (the SOAP type returned by DBFields, which can be treated as an
arrayref), I<OR> a single L<FormValues|ModENCODE::Validator::Wiki::FormValues>
object, I<OR> a hashref.

If C<$values> is an arrayref or an C<ArrayOfFormValues>, then each entry must
either be a L<FormValues|ModENCODE::Validator::Wiki::FormValues> object, in
which case it is added to this object's list of form values, or it can be the
SOAP type C<FormValues>, in which case it is passed to the
L<constructor|ModENCODE::Validator::Wiki::FormValues/new(\%args)> for a
L<FormValues|ModENCODE::Validator::Wiki::FormValues> object and the resulting
object is added to the list of form values.

If C<$values> is a single L<FormValues|ModENCODE::Validator::Wiki::FormValues>
object, then it is set as the sole entry in this object's list of form values.

If C<$values> is a hashref, then each each unique key/value pair is added to
this object's list of form values using L</add_value($key, $types, $value)>.

=item add_value($key, $types, $value)

If this object's list of form values does not contain a L<form
value|ModENCODE::Validator::Wiki::FormValues> with a name of C<$key>, then a new
L<FormValues|ModENCODE::Validator::Wiki::FormValues> object is created and added
to this object's list of form values with a name of C<$key>, types of C<$types>,
and a value of C<$value>.

If this object's list of form values does contain a L<form
value|ModENCODE::Validator::Wiki::FormValues> with a name of C<$key>, then
C<$value> is added to that form value's list of values, and any types in
C<$types> are added to that form value's list of types.

=item get_string_values() | set_string_values($values)

Return an array of L<ModENCODE::Validator::Wiki::FormValues> objects for the
DBFields form that is being fetched. Note that the name C<FormValues> is a
little misleading; a single L<FormValues|ModENCODE::Validator::Wiki::FormValues>
object is equivalent to just a single hash key and an array of values like C<{
$key =E<gt> \@values }>

The string values, unlike the regular values, should only contain a single
key/value pair, with the full contents of all the values in their original,
unsplit form. Furthermore, form value types are ignored (and stripped in most
cases). When setting values, C<$values> should be either an arrayref,
I<OR> an C<ArrayOfFormValues> (the SOAP type returned by DBFields, which can be
treated as an arrayref), I<OR> a single
L<FormValues|ModENCODE::Validator::Wiki::FormValues> object, I<OR> a hashref.

If C<$values> is an arrayref or an C<ArrayOfFormValues>, then each entry must
either be a L<FormValues|ModENCODE::Validator::Wiki::FormValues> object, in
which case it is added to this object's list of form values, or it can be the
SOAP type C<FormValues>, in which case it is passed to the
L<constructor|ModENCODE::Validator::Wiki::FormValues/new(\%args)> for a
L<FormValues|ModENCODE::Validator::Wiki::FormValues> object and the resulting
object is added to the list of form values.

If C<$values> is a single L<FormValues|ModENCODE::Validator::Wiki::FormValues>
object, then it is set as the sole entry in this object's list of form values.

If C<$values> is a hashref, then each each unique key/value pair is added to
this object's list of form values using L</add_value($key, $types, $value)>.

=item add_string_value($key, $value)

If this object's list of form values does not contain a L<form
value|ModENCODE::Validator::Wiki::FormValues> with a name of C<$key>, then a new
L<FormValues|ModENCODE::Validator::Wiki::FormValues> object is created and added
to this object's list of form values with a name of C<$key>, types of C<$types>,
and a value of C<$value>.

If this object's list of string form values does contain a L<form
value|ModENCODE::Validator::Wiki::FormValues> with a name of C<$key>, then
C<$value> is added to that form value's list of values, and any types in
C<$types> are added to that form value's list of types.

=item new(\%args)

Construct a new C<FormData> object for the arguments in C<%args>. The default
L<Class::Std> setters are used for the L<version|/get_version() |
set_version($version)> and L<name|/get_name() | set_name($name)>. For the
values, L<set_values|/get_values() | set_values($values)> is used.

=item to_string()

Returns a string representation of this object, useful for debugging.

=back

=head1 SEE ALSO

L<Class::Std>, L<SOAP::Lite>, L<ModENCODE::Validator::Wiki>,
L<ModENCODE::Validator::Wiki::FormValues>,
L<ModENCODE::Validator::Wiki::LoginResult>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use Class::Std;
use Carp qw(croak);
use ModENCODE::Validator::Wiki::FormValues;
use strict;

# Attributes
my %version          :ATTR( :name<version>, :default<0> );
my %name             :ATTR( :name<name>, :default<undef> );
my %is_complete      :ATTR( :name<is_complete>, :default<undef> );

# Relationships
my %values           :ATTR( :get<values>, :default<[]> );
my %string_values    :ATTR( :get<string_values>, :default<[]> );

sub START {
  my ($self, $ident, $args) = @_;
  if ($args->{'values'}) {
    $self->set_values($args->{'values'});
  }
  if ($args->{'string_values'}) {
    $self->set_string_values($args->{'string_values'});
  }
}

sub set_values {
  my ($self, $set_values) = @_;
  $values{ident $self} = [];
  if (defined($set_values)) {
    if (ref($set_values) eq 'ARRAY' || ref($set_values) eq 'ArrayOfFormValues') {
      foreach my $value (@$set_values) {
        if (ref($value) eq 'ModENCODE::Validator::Wiki::FormValues') {
          foreach my $val (@{$value->get_values()}) {
            $self->add_value($value->get_name(), [], $val);
          }
        } elsif (ref($value) eq 'FormValues') {
          bless($value, 'HASH');
          $value = new ModENCODE::Validator::Wiki::FormValues($value);
          foreach my $val (@{$value->get_values()}) {
            $self->add_value($value->get_name(), $value->get_types(), $val);
          }
        } else {
          croak "Can't add a " . ref($value) . " as a FormValues object";
        }
      }
    } elsif (ref($set_values) eq 'ModENCODE::Validator::Wiki::FormValues') {
      push @{$values{ident $self}}, $set_values;
    } elsif (ref($set_values) eq 'HASH') {
      foreach my $valuekey (keys(%$set_values)) {
        foreach my $value (@{$set_values->{$valuekey}}) {
          $self->add_value($valuekey, [], $value);
        }
      }
    } else {
      croak "Can't figure out how to parse a " . ref($set_values) . " into FormValues object(s)"
    }
  }
}

sub add_value {
  my ($self, $valuekey, $types, $value) = @_;
  my $found = 0;
  foreach my $formvalues (@{$self->get_values()}) {
    if ($formvalues->get_name eq $valuekey) {
      $formvalues->add_value($value);
      foreach my $type (@$types) {
        $formvalues->add_type($type);
      }
      $found = 1;
      last;
    }
  }
  if (!$found) {
    my $newFormValues = new ModENCODE::Validator::Wiki::FormValues({
        'name' => $valuekey,
        'values' => [ $value ],
      });
    foreach my $type (@$types) {
      $newFormValues->add_type($type);
    }
    push @{$values{ident $self}}, $newFormValues;
  }
}

sub set_string_values {
  my ($self, $set_values) = @_;
  $string_values{ident $self} = [];
  if (defined($set_values)) {
    if (ref($set_values) eq 'ARRAY' || ref($set_values) eq 'ArrayOfFormValues') {
      foreach my $value (@$set_values) {
        if (ref($value) eq 'ModENCODE::Validator::Wiki::FormValues') {
          foreach my $val (@{$value->get_string_values()}) {
            $self->add_string_value($value->get_name(), $val);
          }
        } elsif (ref($value) eq 'FormValues') {
          bless($value, 'HASH');
          $value = new ModENCODE::Validator::Wiki::FormValues($value);
          foreach my $val (@{$value->get_values()}) {
            $self->add_string_value($value->get_name(), $val);
          }
        } else {
          croak "Can't add a " . ref($value) . " as a FormValues object";
        }
      }
    } elsif (ref($set_values) eq 'ModENCODE::Validator::Wiki::FormValues') {
      push @{$string_values{ident $self}}, $set_values;
    } elsif (ref($set_values) eq 'HASH') {
      foreach my $valuekey (keys(%$set_values)) {
        foreach my $value (@{$set_values->{$valuekey}}) {
          $self->add_string_value($valuekey, $value);
        }
      }
    } else {
      croak "Can't figure out how to parse a " . ref($set_values) . " into FormValues object(s)"
    }
  }
}

sub add_string_value {
  my ($self, $valuekey, $value) = @_;
  my $found = 0;
  foreach my $formvalues (@{$self->get_string_values()}) {
    if ($formvalues->get_name eq $valuekey) {
      $formvalues->add_value($value);
      $found = 1;
      last;
    }
  }
  if (!$found) {
    my $newFormValues = new ModENCODE::Validator::Wiki::FormValues({
        'name' => $valuekey,
        'values' => [ $value ],
      });
    push @{$string_values{ident $self}}, $newFormValues;
  }
}

sub to_string {
  my ($self) = @_;
  my $string = "Form: " . $self->get_name() . "." . $self->get_version();
  $string .= "\n  " . join("\n  ", map { $_->to_string() } @{$self->get_values()}) . "\n";
  $string .= "Complete? " . $self->get_is_complete();
  return $string;
}

1;

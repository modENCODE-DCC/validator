package ModENCODE::Validator::Wiki::FormValues;
=pod

=head1 NAME

ModENCODE::Validator::Wiki::FormValues - Helper class for SOAP transactions
between the MediaWiki DBFields extension and L<ModENCODE::Validator::Wiki>, used
by L<ModENCODE::Validator::Wiki::FormValues>.

=head1 SYNOPSIS

This class presents a L<Class::Std> interface for dealing with portions of the
L<SOAP::Lite> SOAP responses from the MediaWiki DBFields extension. A DBFields
form result (from the I<getFormData> SOAP service) can be converted into a
C<FormData> object by simply
L<constructing|ModENCODE::Validator::Wiki::FormData/new(\%args)> a
L<ModENCODE::Validator::Wiki::FormData> object from the SOAP result; the
L<values|ModENCODE::Validator::Wiki::FormData/get_values() |
set_values($values)> of that object will be a list of C<FormValues> objects.

=head1 USAGE

To get a list C<FormValues> object from a SOAP response, bless the response object
as a HASH and then pass it to the
L<FormData|ModENCODE::Validator::Wiki::FormData>
L<constructor|ModENCODE::Validator::Wiki::FormData/new(\%args)>, then pull out
the values:

  my $soap_client = SOAP::Lite->service(ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'));
  my $soap_result = $soap_client->getFormData($soap_query);
  bless($soap_result, 'HASH');

  my $formdata = new ModENCODE::Validator::Wiki::FormData($soap_result);
  my $list_of_form_values = $formdata->get_values();
  foreach my $form_value (@$list_of_form_values) {
    print $form_value->get_name();
  }

=head1 FUNCTIONS

=over

=item get_name() | set_name($name)

Return or set the name of the DBFields form field that this object represents.

=item get_types() | set_types($types) | add_type($type)

Return or set or add new types of the form field that this object represents.
Note that these are controlled vocabulary names, not actual
L<ModENCODE::Chado::CV> objects.

=item get_values() | set_values($values) | add_value($value)

Return or set or add new values for the form field that this object represents.
When setting, C<$values> can be either an arrayref or a C<ArrayOfStrings> which
is a SOAP type that can be treated as an arrayref. It can also be a string, in
which case it is set as the sole value of this object.


=item new(\%args)

Create a new C<FormValues> object with the given arguments. The default
L<Class::Std> setters are used for the L<name|/get_name() | set_name($name)> and
L<types|/get_types() | set_types($types) | add_type($type)>, while the custom
L<set_values($values)|/get_values() | set_values($values) | add_value($value)> is
used for the values.

=item to_string()

Returns a string representation of this object, useful for debugging.

=back

=head1 SEE ALSO

L<Class::Std>, L<SOAP::Lite>, L<ModENCODE::Validator::Wiki>,
L<ModENCODE::Validator::Wiki::FormData>,
L<ModENCODE::Validator::Wiki::LoginResult>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use Class::Std;
use Carp qw(croak);
use strict;

# Attributes
my %name             :ATTR( :name<name> );
my %types            :ATTR( :name<types>, :default<[]> );
my %values           :ATTR( :get<values>, :init_arg<values>, :default<[]> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_values($args->{'values'}) if ($args->{'values'});
  $types{$ident} = $args->{'types'} if ref($args->{'types'} eq "ARRAY");
}

sub set_values {
  my ($self, $values) = @_;
  if (defined($values)) {
    if (ref($values) ne 'ARRAY' && ref($values) ne 'ArrayOfStrings') {
      $values = [ $values ];
    }
    foreach my $value (@$values) {
      $self->add_value($value);
    }
  }
}

sub add_type {
  my ($self, $type) = @_;
  if (!scalar(grep { $_ eq $type } @{$types{ident $self}})) {
    push @{$types{ident $self}}, $type;
  }

}
sub add_value {
  my ($self, $value, $type) = @_;
  push @{$values{ident $self}}, $value;
}

sub to_string {
  my ($self) = @_;
  my $string = $self->get_name();
  $string .= "<" . join(", ", @{$self->get_types()}) . ">";
  $string .= "(" . join(", ", @{$self->get_values()}) . ")";
  return $string;
}

1;

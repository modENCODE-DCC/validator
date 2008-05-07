package ModENCODE::Validator::Wiki::LoginResult;
=pod

=head1 NAME

ModENCODE::Validator::Wiki::LoginResult - Helper class for SOAP transactions
between the MediaWiki DBFields extension and L<ModENCODE::Validator::Wiki>, used
specifically for authenticating to the DBFields SOAP service.

=head1 SYNOPSIS

This class presents a L<Class::Std> interface for dealing with L<SOAP::Lite>
SOAP responses from the MediaWiki DBFields extension. A DBFields authentication
response result (from the I<getLoginCookie> SOAP service) can be converted into
a C<LoginResult> object by simply constructing a C<LoginResult>
object from the SOAP result.

=head1 USAGE

To get a C<LoginResult> object from a SOAP response, bless the response object
as a HASH and then pass it to the L<constrcutor|/new(\%args)>:

  my $soap_client = SOAP::Lite->service(ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'));
  my $login_result = $soap_client->getLoginCookie($username, $password, $domain);
  bless($login_result, 'HASH');

  $login_result = new ModENCODE::Validator::Wiki::LoginResult($login);
  print $login_result->get_lgtoken();

For more information about the fields returned, see the MediaWiki documentation
at L<http://www.mediawiki.org/wiki/API:Login>.

=head1 FUNCTIONS

=over

=item get_result() | set_result($result)

Get or set the MediaWiki login result string.

=item is_logged_in()

Returns 1 if the L<result|/get_result() | set_result($result)> equals
C<"Success">, 0 otherwise.

=item get_username() | get_lgusername() | set_username($username)

Get or set the MediaWiki login username string. C<get_username()> is just a
synonym for C<get_lgusername()>.

=item get_userid() | get_lguserid() | set_userid($userid)

Get or set the MediaWiki login userid string. C<get_userid()> is just a
synonym for C<get_lguserid()>.

=item get_token() | get_lgtoken() | set_token($token)

Get or set the MediaWiki login token string. C<get_token()> is just a
synonym for C<get_lgtoken()>.

=item get_wait() | set_wait($wait)

Get or set the number of seconds to wait until you can retry the login.

=item get_cookieprefix() | set_cookieprefix($cookieprefix)

Get or set the MediaWiki login cookieprefix string.

=item get_details() | set_details($details)

Get or set the MediaWiki login result details string.

=item get_sessionid() | set_sessionid($sessionid)

Get or set the MediaWiki login result session id string.

=item to_string()

Returns a string representation of this object, useful for debugging.

=item get_soap_obj()

Returns a L<SOAP::Data> object representing this object that can be used to pull
out the various fields as L<SOAP::Data> objects that can be passed back into
other SOAP calls, for example:

  my $soap_client = SOAP::Lite->service(ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'));
  my $login_result = $soap_client->getLoginCookie($username, $password, $domain);
  bless($login_result, 'HASH');
  $login_result = new ModENCODE::Validator::Wiki::LoginResult($login);

  my $data = $soap_client->getFormData('query' => \SOAP::Data->value(
    SOAP::Data->name('name' => HTML::Entities::encode($protocol_name))->type('xsd:string'),
    SOAP::Data->name('version' => undef)->type('xsd:int'),
    SOAP::Data->name('auth' => 
    #########################################
      \$login_result->get_soap_obj())->type('LoginResult')
    #########################################
  ))->type('FormDataQuery');

=back

=head1 SEE ALSO

L<Class::Std>, L<SOAP::Lite>, L<SOAP::Data>, L<ModENCODE::Validator::Wiki>,
L<ModENCODE::Validator::Wiki::FormValues>,
L<ModENCODE::Validator::Wiki::FormData>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use Class::Std;
use Carp qw(croak);
use SOAP::Lite;
use strict;

# Attributes
my %result           :ATTR( :name<result> );
my %lgusername       :ATTR( :name<lgusername>,  :default<undef> );
my %lguserid         :ATTR( :name<lguserid>,    :default<undef> );
my %lgtoken          :ATTR( :name<lgtoken>,     :default<undef> );
my %wait             :ATTR( :name<wait>,        :default<undef> );
my %cookieprefix     :ATTR( :name<cookieprefix>,:default<undef> );
my %details          :ATTR( :name<details>,     :default<undef> );
my %sessionid        :ATTR( :name<sessionid>,   :default<undef> );

sub get_username {
  my ($self) = @_;
  return $self->get_lgusername();
}

sub get_userid {
  my ($self) = @_;
  return $self->get_lguserid();
}

sub get_token {
  my ($self) = @_;
  return $self->get_lgtoken();
}

sub is_logged_in {
  my ($self) = @_;
  return ($self->get_result() eq "Success");
}

sub to_string {
  my ($self) = @_;
  my $string = "'" . $self->get_lgusername() . "' is ";
  $string .= $self->is_logged_in() ? "logged in" : "not logged in";
  $string .= " with token '" . $self->get_lgtoken() . "'.";
  return $string;
}

sub get_soap_obj {
  my ($self) = @_;
  my $data = SOAP::Data->name('auth' =>
    SOAP::Data->value(
      SOAP::Data->name('result' => $self->get_result())->type('xsd:string'),
      SOAP::Data->name('lgusername' => $self->get_lgusername())->type('xsd:string'),
      SOAP::Data->name('lguserid' => $self->get_lguserid())->type('xsd:string'),
      SOAP::Data->name('lgtoken' => $self->get_lgtoken())->type('xsd:string'),
      SOAP::Data->name('wait' => $self->get_wait())->type('xsd:string'),
      SOAP::Data->name('cookieprefix' => $self->get_cookieprefix())->type('xsd:string'),
      SOAP::Data->name('details' => $self->get_details())->type('xsd:string'),
      SOAP::Data->name('sessionid' => $self->get_sessionid())->type('xsd:string')
    )->type('LoginResult')->uri('http://wiki.modencode.org/project/extensions/DBFields/namespaces/dbfields'));
  return $data;
}

1;

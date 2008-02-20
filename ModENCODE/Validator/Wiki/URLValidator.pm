package ModENCODE::Validator::Wiki::URLValidator;


use SOAP::Lite;# +trace => qw(debug);
use ModENCODE::Validator::Wiki::LoginResult;
use HTTP::Cookies;
use Class::Std;
use Carp qw(croak carp);
use LWP::UserAgent;
use URI::Escape ();
use strict;

my %username                    :ATTR( :name<username>, :default<''> );
my %password                    :ATTR( :name<password>, :default<''> );
my %domain                      :ATTR( :name<domain>,   :default<''> );
my %soap_client                 :ATTR;
my %soap_wsdl                   :ATTR( :name<wsdl>,     :default<'http://wiki.modencode.org/project/extensions/DBFields/DBFieldsService.wsdl'> );
my %useragent                   :ATTR;

sub START {
  my ($self, $ident, $args) = @_;
  $soap_client{$ident} = SOAP::Lite->service($self->get_wsdl());
  $soap_client{$ident}->serializer->envprefix('SOAP-ENV');
  $soap_client{$ident}->serializer->encprefix('SOAP-ENC');
  $soap_client{$ident}->serializer->soapversion('1.1');

  my $login = $soap_client{ident $self}->getLoginCookie($self->get_username(), $self->get_password(), $self->get_domain());
  bless $login, 'HASH';
  $login = new ModENCODE::Validator::Wiki::LoginResult($login);

  my ($wiki_domain) = ($self->get_wsdl() =~ m/:\/\/([^:\/]+)/);

  my $cookie_jar = new HTTP::Cookies();
  $cookie_jar->set_cookie(undef, $login->get_cookieprefix() . "UserID", $login->get_lguserid(), '/', $wiki_domain);
  $cookie_jar->set_cookie(undef, $login->get_cookieprefix() . "UserName", $login->get_lgusername(), '/', $wiki_domain);
  $cookie_jar->set_cookie(undef, $login->get_cookieprefix() . "Token", $login->get_lgtoken(), '/', $wiki_domain);

  $useragent{$ident} = new LWP::UserAgent();
  $useragent{$ident}->cookie_jar($cookie_jar);
}

sub get_url {
  my ($self, $url) = @_;
  return $useragent{ident $self}->request(new HTTP::Request('GET' => $url));
}

1;

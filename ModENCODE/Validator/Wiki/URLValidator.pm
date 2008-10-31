package ModENCODE::Validator::Wiki::URLValidator;
=pod

=head1 NAME

ModENCODE::Validator::Wiki::URLValidator - Helper class for validating the
presence of MediaWiki pages through interactions with the DBFields
extension (used primarily by L<ModENCODE::Validator::CVHandler>).

=head1 SYNOPSIS

This class uses the SOAP web services provided by the MediaWiki DBFields
extension to authenticate with a MediaWiki wiki and attempt to fetch a wiki
page. Verifying whether or not the page is populated with data is up to the
invoking method (one trick is to check the result returned by L</get_url($url)>
to see if it contains C<'div class="noarticletext"'>).

=head1 USAGE

This class should be constructed with a username, password, wiki domain, and
WSDL URL which will attempt to fetch a MediaWiki login cookie and initialize an
L<LWP::UserAgent> object with that cookie for future requests.

  my $url_validator = new ModENCODE::Validator::Wiki::URLValidator({
    'username' => 'User',
    'password' => 'somepass',
    'domain'   => 'wiki.com',
    'wsdl'     => 'http://wiki.com/dbfields_soap.wsdl'
  });

  my $res = $url_validator->get_url('http://wiki.com/Page');
  if ($res->is_success()) {
    if (
      $res->content() !~ m/div class="noarticletext"/ && 
      $res->content() !~ m/<title>Error<\/title>/
    ) {
      print "Page exists!";
    } else {
      print "Page not populated or other error.";
    }
  } else {
    print "404 or other HTTP error.";
  }

=head1 FUNCTIONS

=over

=item get_username()

Get the username being used to authenticate to the wiki.

=item get_password()

Get the password being used to authenticate to the wiki.

=item get_domain()

Get the domain being used to authenticate to the wiki.

=item get_wsdl() | set_wsdl($wsdl)

Get the WSDL URL being used to authenticate to the wiki.

=item get_url($url)

Attempt to fetch the URL in C<$url> using L<LWP::UserAgent> and return the
L<HTTP::Response> object. Include in the request the login cookie fetched during
initialization (if any).

=back

=head1 SEE ALSO

L<ModENCODE::Validator::CVHandler>, L<ModENCODE::Validator::Wiki>,
L<SOAP::Lite>, L<LWP::UserAgent>, L<HTTP::Response>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use SOAP::Lite;# +trace => qw(debug);
use ModENCODE::Validator::Wiki::LoginResult;
use HTTP::Cookies;
use Class::Std;
use Carp qw(croak carp);
use LWP::UserAgent;
use URI::Escape ();
use strict;

my %username                    :ATTR( :get<username>, :init_arg<username>, :default<''> );
my %password                    :ATTR( :get<password>, :init_arg<password>, :default<''> );
my %domain                      :ATTR( :get<domain>,   :init_arg<domain>,   :default<''> );
my %soap_client                 :ATTR;
my %soap_wsdl                   :ATTR( :get<wsdl>,     :init_arg<wsdl>,     :default<'http://wiki.modencode.org/project/extensions/DBFields/DBFieldsService.wsdl'> );
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
  my $escaped_url = $url;
  $escaped_url =~ s/ /_/g;
  return $useragent{ident $self}->request(new HTTP::Request('GET' => $escaped_url));
}

1;

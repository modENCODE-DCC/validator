package ModENCODE::Validator::Wiki;

use strict;
use Class::Std;
use Carp qw(croak carp);
use SOAP::Lite; #+trace => qw(debug);
use ModENCODE::Validator::Wiki::FormData;
use ModENCODE::Validator::Wiki::FormValues;
use ModENCODE::Validator::Wiki::LoginResult;

sub validate {
  my ($self, $experiment) = @_;
  my $success = 1;

  use Data::Dumper;

  my $old_generate_stub = *SOAP::Schema::generate_stub;
  my $new_generate_stub = sub {
    my $stubtxt = $old_generate_stub->(@_);
    my $testexists = '# HACKY FIX TO MISSING "can(\'as_$typename\')"
      if (!($self->serializer->can($method))) {
        push @parameters, $param;
        next;
      }
    ';
    $stubtxt =~ s/# TODO - if can\('as_'.\$typename\) {\.\.\.}/$testexists/;
    return $stubtxt;
  };

  undef *SOAP::Schema::generate_stub;
  *SOAP::Schema::generate_stub = $new_generate_stub;

  # Get soap client
  my $soap_client = SOAP::Lite->service('http://wiki.modencode.org/project/extensions/DBFields/DBFieldsService.wsdl');
  $soap_client->serializer->envprefix('SOAP-ENV');
  $soap_client->serializer->encprefix('SOAP-ENC');
  $soap_client->serializer->soapversion('1.1');




  # Attempt to login using wiki credentials
  my $username = "Yostinso";
  my $password = "Hella99";
  my $domain = 'modencode_wiki';
  
  my $login = $soap_client->getLoginCookie($username, $password, $domain);
  bless $login, 'HASH';
  $login = new ModENCODE::Validator::Wiki::LoginResult($login);

  # Get wiki protocol data
  my %protocols;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      if (!defined($protocols{$protocol->get_name()})) {
        $protocols{$protocol->get_name()} = [];
      }
      push @{$protocols{$protocol->get_name()}}, $applied_protocol->get_protocol();
    }
  }
  my @unique_protocol_names = (); foreach my $name (keys(%protocols)) { if (!scalar(grep { $_ eq $name } @unique_protocol_names)) { push @unique_protocol_names, $name; } };

  foreach my $protocol_name (@unique_protocol_names) {
    my $data = SOAP::Data->name('query' => \SOAP::Data->value(
        SOAP::Data->name('name' => $protocol_name)->type('xsd:string'),
        SOAP::Data->name('version' => undef)->type('xsd:int'),
        SOAP::Data->name('auth' => \$login->get_soap_obj())->type('LoginResult'),
    ))
    ->type('FormDataQuery');
    my $res = $soap_client->getFormData($data);

    if (!$res) {
      carp "No form data for protocol '$protocol_name'";
      next;
    }
    bless($res, 'HASH');
    my $formdata = new ModENCODE::Validator::Wiki::FormData($res);
    print "Got protocol data: " . $formdata->to_string() . "\n";
  }

  return $success;
}

1;

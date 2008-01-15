package ModENCODE::Validator::Wiki::LoginResult;
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

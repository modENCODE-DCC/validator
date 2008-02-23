package ModENCODE::Validator::Attributes::URL_mediawiki_expansion;
use strict;
use base qw( ModENCODE::Validator::Attributes::Attributes );
use Class::Std;
use Carp qw(croak carp);
use SOAP::Lite;
use ModENCODE::Validator::Wiki::FormData;
use ModENCODE::Validator::Wiki::FormValues;
use ModENCODE::Validator::Wiki::LoginResult;
use ModENCODE::Validator::CVHandler;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use HTML::Entities ();
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;

sub BUILD {
  # HACKY FIX TO MISSING "can('as_$typename')"
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
}

sub validate {
  my ($self) = @_;
  my $success = 1;

  # Get soap client
  my $soap_client = SOAP::Lite->service('http://wiki.modencode.org/project/extensions/DBFields/DBFieldsService.wsdl');
  $soap_client->serializer->envprefix('SOAP-ENV');
  $soap_client->serializer->encprefix('SOAP-ENC');
  $soap_client->serializer->soapversion('1.1');

  # Attempt to login using wiki credentials
  my $login = $soap_client->getLoginCookie(
    ModENCODE::Config::get_cfg()->val('wiki', 'username'),
    ModENCODE::Config::get_cfg()->val('wiki', 'password'),
    ModENCODE::Config::get_cfg()->val('wiki', 'domain'),
  );
  bless $login, 'HASH';
  $login = new ModENCODE::Validator::Wiki::LoginResult($login);
  
  log_error "Fetching expanded attributes from the wiki...", "notice", ">";
  my %pages;
  foreach my $attribute_hash (@{$self->get_attributes()}) {
    my $attribute = $attribute_hash->{'attribute'}->clone();
    if (!defined($pages{$attribute->get_value()})) {
      my $soap_data = SOAP::Data->name('query' => \SOAP::Data->value(
          SOAP::Data->name('name' => HTML::Entities::encode($attribute->get_value()))->type('xsd:string'),
          SOAP::Data->name('version' => undef)->type('xsd:int'),
          SOAP::Data->name('auth' => \$login->get_soap_obj())->type('LoginResult'),
        ))
      ->type('FormDataQuery');
      my $res = $soap_client->getFormData($soap_data);

      if (!$res) {
        $pages{$attribute->get_value()} = 0;
      } else {
        bless($res, 'HASH');
        my $result_data = new ModENCODE::Validator::Wiki::FormData($res);
        if ($result_data) {
          my @new_attributes = ( $attribute );
          foreach my $formvalues (@{$result_data->get_values()}) {
            my $rank = 0;
            foreach my $formvalue (@{$formvalues->get_values()}) {
              my ($cv, $term, $name) = ModENCODE::Validator::CVHandler::parse_term($formvalue);
              if (!length($term) && length($cv)) {
                $term = $cv;
                $cv = $result_data->get_types()->[0];
              } elsif (!length($term)) {
                $term = $formvalue;
              }
              my $new_attribute = new ModENCODE::Chado::Attribute({
                  'heading' => $formvalues->get_name(),
                  'value' => $term,
                  'rank' => $rank,
                  'type' => new ModENCODE::Chado::CVTerm({
                      'name' => 'string',
                      'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }),
                    }),
                });
              $rank++;
              push @new_attributes, $new_attribute;
            }
          }
          $pages{$attribute->get_value()} = \@new_attributes; # Array of merged 
        }
      }
    }

    if (!($pages{$attribute->get_value()})) {
      # If %pages is false for this attribute, couldn't find the expansion page; nothing to expand
    } else {
      $attribute_hash->{'merged_attributes'} = $pages{$attribute->get_value()};
    }
  }
  log_error "Done.", "notice", "<";

  return $success;
}

sub merge {
  my ($self, $datum) = @_;

  my ($validated_entry) = grep { $_->{'attribute'}->equals($datum); } @{$self->get_attributes()};

  return $validated_entry->{'merged_attributes'};
}

1;

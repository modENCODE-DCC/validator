package ModENCODE::Validator::Data::URL_mediawiki_expansion;
=pod

=head1 NAME

ModENCODE::Validator::Data::URL_mediawiki_expansion - Class for validating
and converting BIR-TAB data columns containing MediaWiki URLs pointing to
pages containing a DBFields form into additional attribute columns based on the
form. This class is a subclass of the abstract
L<ModENCODE::Validator::Data::Data>.

=head1 SYNOPSIS

This class is meant to be used to pull additional attribute columns into a
BIR-TAB experiment from a MediaWiki wiki running the DBFields extension. The
value of any datum passed in using
L<add_datum($datum)|ModENCODE::Validator::Data::Data/add_datum($datum)>
will be passed to the getFormData service of DBFields web service defined by the
WSDL configured in the [wiki]/soap_wsdl_url option in the ini-file loaded by
L<ModENCODE::Config>.

=head1 USAGE

If there is a DBFields form on that page named by the datum value, then the
DBFields service will return the field names and values. Each field is then
turned into a new L<attribute|ModENCODE::Chado::Attribute> with the value equal
to the value of the field and the name equal to the name of the field. The
original data column kept intact and the attribute columns generated are added
to it. The field can also be typed if it is a controlled-vocabulary field (as
described by the DBFields syntax).

The resulting datum with added attributes is returned as an arrayref when
L</merge($datum)> is called, and the returned datum is used in
L<ModENCODE::Validator::Data> to replace the datum passed in.

If there is not a DBFields form on the page named by the datum value, then
validation fails (L</validate()> returns 0).

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'MyMediaWikiPage?oldid=128'
  });
  my $validator = new ModENCODE::Validator::Data::URL_mediawiki_expansion();
  $validator->add_datum($datum);
  if ($validator->validate()) {
    my $new_datum = @{$validator->merge($datum)};
    foreach (@{$new_datum->get_attributes}) {
      print $_->get_name() . " = " . $_->get_value() . "\n";
    }
  }

Note that this class is not meant to be used directly, rather it is meant to be
used within L<ModENCODE::Validator::Data>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using
L<add_datum($datum)|ModENCODE::Validator::Data::Data/add_datum($datum)>
have values that exist as MediaWiki wiki pages with DBFields forms that can be
accessed using the getFormData service of the DBFields extension. If such a page
doesn't exist, then it returns 0, otherwise returns 1.

=item merge($datum)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>, returns an updated
copy of that datum with references to any new attributes corresponding the
DBFields form on the page referenced in the original datum's value.

=back

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<SOAP::Lite>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Data::Data );
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
  my $self = shift;
  my $success = 1;

  # Get soap client
  my $soap_client = SOAP::Lite->service(ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'));
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
  
  log_error "Fetching expanded attributes for data from the wiki...", "notice", ">";
  my %pages;
  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    my ($name, $version) = ($datum->get_object->get_value() =~ /^(.*?)(?:&oldid=(\d*))?$/);
    $name =~ s/_/ /g;
    if (!defined($pages{$datum->get_object->get_value()})) {
      my $soap_data = SOAP::Data->name('query' => \SOAP::Data->value(
          SOAP::Data->name('name' => HTML::Entities::encode($name))->type('xsd:string'),
          SOAP::Data->name('revision' => $version)->type('xsd:int'),
          SOAP::Data->name('auth' => \$login->get_soap_obj())->type('LoginResult'),
        ))
      ->type('FormDataQuery');
      my $res = $soap_client->getFormData($soap_data);

      if (!$res) {
        $pages{$datum->get_object->get_value()} = 0;
      } else {
        bless($res, 'HASH');
        my $result_data = new ModENCODE::Validator::Wiki::FormData($res);
        if ($result_data) {
          my @new_attributes;
          foreach my $formvalues (@{$result_data->get_values()}) {
            my $rank = 0;
            foreach my $formvalue (@{$formvalues->get_values()}) {
              next unless scalar(@{$formvalues->get_types()});
              my ($cv, $term, $name) = ModENCODE::Config::get_cvhandler()->parse_term($formvalue);
              my $type = new ModENCODE::Chado::CVTerm({
                  'name' => 'string',
                  'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }),
                });
              if (length($term) && length($cv)) {
                if (ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)) {
                  my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
                  $type = new ModENCODE::Chado::CVTerm({
                      'name' => $term,
                      'cv' => new ModENCODE::Chado::CV({ 'name' => $canonical_cvname }),
                    });
                } else {
                  my $canonical_cv = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv);
                  if (!$canonical_cv) {
                    ModENCODE::Config::get_cvhandler()->add_cv($cv, undef, "database");
                  } else {
                    $cv = $canonical_cv->{'names'}->[0]
                  }
                  $type = new ModENCODE::Chado::CVTerm({
                      'name' => $term,
                      'cv' => new ModENCODE::Chado::CV({ 'name' => $cv }),
                    });
                }
              } elsif (!length($term) && length($cv)) {
                $term = $cv;
                $cv = $formvalues->get_types()->[0];
                if (ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)) {
                  my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
                  $type = new ModENCODE::Chado::CVTerm({
                      'name' => $term,
                      'cv' => new ModENCODE::Chado::CV({ 'name' => $canonical_cvname }),
                    });
                }
              } elsif (!length($term)) {
                $term = $formvalue;
              }
              my $new_attribute = new ModENCODE::Chado::DatumAttribute({
                  'heading' => $formvalues->get_name(),
                  'value' => $term,
                  'rank' => $rank,
                  'type' => $type,
                  'datum' => $datum,
                });
              $datum->get_object->add_attribute($new_attribute);
              $rank++;
              push @new_attributes, $new_attribute;
            }
          }
          $pages{$datum->get_object->get_value()} = \@new_attributes; # Array of merged 
        }
      }
    }

    if (!($pages{$datum->get_object->get_value()})) {
      if ($datum->get_object->get_value()) {
        $success = 0;
        log_error "Couldn't expand " . $datum->get_object->get_value() . " in the " . $datum->get_object->get_heading() . " [" . $datum->get_object->get_name() . "] field with any attribute columns in the " . ref($self) . " validator.", "error";
      } else {
        log_error "Couldn't expand the empty value in the " . $datum->get_object->get_heading() . " [" . $datum->get_object->get_name() . "] field with any attribute columns in the " . ref($self) . " validator.", "warning";
      }
    }
  }
  log_error "Done.", "notice", "<";

  return $success;
}

1;

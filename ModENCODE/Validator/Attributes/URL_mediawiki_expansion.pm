package ModENCODE::Validator::Attributes::URL_mediawiki_expansion;
=pod

=head1 NAME

ModENCODE::Validator::Attributes::URL_mediawiki_expansion - Class for validating
and converting BIR-TAB attribute columns containing MediaWiki URLs pointing to
pages containing a DBFields form into additional attribute columns based on the
form. This class is a subclass of the abstract
L<ModENCODE::Validator::Attributes::Attributes>.

=head1 SYNOPSIS

This class is meant to be used to pull additional attribute columns into a
BIR-TAB experiment from a MediaWiki wiki running the DBFields extension. The
value of any attribute passed in using
L<add_attribute($attribute)|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
will be passed to the getFormData service of DBFields web service defined by the
WSDL configured in the [wiki]/soap_wsdl_url option in the ini-file loaded by
L<ModENCODE::Config>.

=head1 USAGE

If there is a DBFields form on that page named by the attribute value, then the
DBFields service will return the field names and values. Each field is then
turned into a new L<attribute|ModENCODE::Chado::Attribute> with the value equal
to the value of the field and the name equal to the name of the field. The
original attribute is also kept intact. The field can also be typed if it is a
controlled-vocabulary field (as described by the DBFields syntax).

The resulting set of attributes is returned as an arrayref when
L</merge($attribute)> is called, and the whole set is used in
L<ModENCODE::Validator::Attributes> to replace the attribute passed in.

If there is not a DBFields form on the page named by the attribute value, then
validation fails (L</validate()> returns 0).

  my $attribute = new ModENCODE::Chado::Attribute({
    'value' => 'MyMediaWikiPage?oldid=128'
  });
  my $validator = new ModENCODE::Validator::Attributes::URL_mediawiki_expansion();
  $validator->add_attribute($attribute);
  if ($validator->validate()) {
    my @new_attributes = @{$validator->merge($attribute)};
    foreach (@new_attributes) {
      print $_->get_name() . " = " . $_->get_value() . "\n";
    }
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Attributes>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the attributes added using
L<add_attribute($attribute)|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
have values that exist as MediaWiki wiki pages with DBFields forms that can be
accessed using the getFormData service of the DBFields extension. If such a page
doesn't exist, then it returns 0, otherwise returns 1.

=item merge($attribute)

Given an original L<attribute|ModENCODE::Chado::Attribute> C<$attribute>,
returns an arrayref containing a copy of that attribute plus any new attributes
corresponding the DBFields form on the page referenced in the original
attribute's value.

=back

=head1 SEE ALSO

L<ModENCODE::Chado::Attribute>, L<ModENCODE::Validator::Attributes>,
L<ModENCODE::Validator::Attributes::Attributes>, L<SOAP::Lite>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
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
  
  log_error "Fetching expanded attributes from the wiki...", "notice", ">";
  my %pages;
  foreach my $attribute_hash (@{$self->get_attributes()}) {
    my $attribute = $attribute_hash->{'attribute'}->clone();
    my ($name, $version) = ($attribute->get_value() =~ /^(.*?)(?:&oldid=(\d*))?$/);
    $name =~ s/_/ /g;
    if (!defined($pages{$attribute->get_value()})) {
      my $soap_data = SOAP::Data->name('query' => \SOAP::Data->value(
          SOAP::Data->name('name' => HTML::Entities::encode($name))->type('xsd:string'),
          SOAP::Data->name('revision' => $version)->type('xsd:int'),
          SOAP::Data->name('auth' => \$login->get_soap_obj())->type('LoginResult'),
        ))
      ->type('FormDataQuery');
      my $res = $soap_client->getFormData($soap_data);
      #print STDERR "form_data: " . Dumper($res);
      if (!$res) {
        $pages{$attribute->get_value()} = 0;
      } else {
        bless($res, 'HASH');
        my $result_data = new ModENCODE::Validator::Wiki::FormData($res);
        if ($result_data) {
          if ($result_data->get_is_complete()) {
	    my @new_attributes = ( $attribute );
	  
	    #if ($result_data->get_is_required()) {
	    #  print STDERR $result_data->get_name() . " is required"; }
	    #else {
	    #  print STDERR $result_data->get_name() . " is not required"; }
	    foreach my $formvalues (@{$result_data->get_values()}) {
	      my $rank = 0;
	      foreach my $formvalue (@{$formvalues->get_values()}) {
                my ($cv, $term, $name) = ModENCODE::Validator::CVHandler::parse_term($formvalue);
		my $type = new ModENCODE::Chado::CVTerm({
                  'name' => 'string',
                  'cv' => new ModENCODE::Chado::CV({ 'name' => 'xsd' }),
                  });
		if (!length($term) && length($cv)) {
		  $term = $cv;
		  $cv = $result_data->get_types()->[0];
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
		my $new_attribute = new ModENCODE::Chado::Attribute({
                    'heading' => $formvalues->get_name(),
                    'value' => $term,
		    'rank' => $rank,
		    'type' => $type,
		    });
		$rank++;
		push @new_attributes, $new_attribute;
	      }
	    }
	    $pages{$attribute->get_value()} = \@new_attributes; # Array of merged 
	    log_error "Expanded wiki page " . $attribute->get_value(), "notice";
	  } else {
	      log_error "Required fields defined in wiki page " . 
		  $attribute->get_value() . " in " . $attribute->get_heading() . 
		  " [" . $attribute->get_name() . "] are missing.", "error";
	      $success = 0;
	  }
        }
      }
    }

    if (!($pages{$attribute->get_value()})) {
      # If %pages is false for this attribute, couldn't find the expansion page; nothing to expand
      if ($attribute->get_value()) {
        $success = 0;
        log_error "Couldn't expand " . $attribute->get_value() . " in the " . $attribute->get_heading() . " [" . $attribute->get_name() . "] field into a new set of attribute columns in the " . ref($self) . " validator.  This is either because the URL is incorrect or the wiki page is incomplete", "error";
      } else {
        log_error "Couldn't expand the empty value in the " . $attribute->get_heading() . " [" . $attribute->get_name() . "] field into a new set of attribute columns in the " . ref($self) . " validator.", "warning";
        $attribute_hash->{'merged_attributes'} = $attribute;
      }
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

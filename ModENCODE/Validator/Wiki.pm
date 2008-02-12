package ModENCODE::Validator::Wiki;

use strict;
use Class::Std;
use Carp qw(croak carp);
use SOAP::Lite;# +trace => qw(debug);
use ModENCODE::Validator::Wiki::FormData;
use ModENCODE::Validator::Wiki::FormValues;
use ModENCODE::Validator::Wiki::LoginResult;
use ModENCODE::Validator::CVHandler;
use HTML::Entities ();
use ModENCODE::ErrorHandler qw(log_error);

my %protocol_defs_by_name       :ATTR( :default<undef> );
my %protocol_defs_by_url        :ATTR( :default<undef> );
my %termsources                 :ATTR( :name<termsources> );
my %cvhandler                   :ATTR;

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cvhandler = $args->{'cvhandler'};
  if (ref($cvhandler) ne 'ModENCODE::Validator::CVHandler') {
    croak "Cannot create a ModENCODE::Validator::Wiki without a cvhandler of type ModENCODE::Validator::CVHandler";
  }
  $cvhandler{ident $self} = $cvhandler;

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

sub merge {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  log_error "(Re)validating experiment vs. wiki:", "notice", ">";
  $self->validate($experiment) or croak "Can't merge wiki data if it doesn't validate!"; # Cache all the protocol definitions and stuff if they aren't already
  log_error "Done.", "notice", "<";

  log_error "Adding types from the wiki to input and output parameters.", "notice", ">";
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      my $wiki_protocol_def = $protocol_defs_by_url{ident $self}->{$protocol->get_description()};
      $wiki_protocol_def = $protocol_defs_by_name{ident $self}->{$protocol->get_name()} unless $wiki_protocol_def;
      my ($input_type_defs) = grep { $_->get_name() =~ /^\s*input *types?\s*$/i } @{$wiki_protocol_def->get_values()};
      my ($output_type_defs) = grep { $_->get_name() =~ /^\s*output *types?\s*$/i } @{$wiki_protocol_def->get_values()};

      # INPUTS
      my $input_type_defs_terms = [];
      foreach my $value (@{$input_type_defs->get_values()}) {
        my ($name, $cv, $term) = (undef, split(/:/, $value));
        if (!defined($term)) {
          $term = $cv;
          $cv = $input_type_defs->get_types()->[0];
        }
        ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
        $term =~ s/^\s*|\s*$//g;
        push(@$input_type_defs_terms, { 'term' => $term, 'cv' => $cv, 'name' => $name });
      }
      # Since we've validated, there can be at most one anonymous datum
      foreach my $input_datum (@{$applied_protocol->get_input_data()}) {
        my ($wiki_input_def) = grep { $_->{'name'} eq $input_datum->get_name() } @$input_type_defs_terms;
        if (!$wiki_input_def) { 
          ($wiki_input_def) = grep { $_->{'name'} =~ /^\s*$/ || !defined($_->{'name'}) } @$input_type_defs_terms;
          if (!$wiki_input_def && $input_datum->is_anonymous()) {
            # An automatically added anonymous datum w/ no type; leave it alone since
            # it will be used to tie together applied protocols
            next;
          } else {
            log_error "input term '" . $input_datum->get_name() . "' is named in the IDF/SDRF, but not in the wiki.", "warning" if ($input_datum->get_name());
          }
        }
        if (!$wiki_input_def) {
          croak "Couldn't find the wiki definition for input '" . $input_datum->get_name() . "' in protocol " . $protocol->get_name() . " even though everything validated";
        }
        my $cv = $wiki_input_def->{'cv'};
        my $term = $wiki_input_def->{'term'};
        my $canonical_cvname = $cvhandler{ident $self}->get_cv_by_name($cv)->{'names'}->[0];
        $input_datum->set_type(new ModENCODE::Chado::CVTerm({
              'name' => $term,
              'cv' => new ModENCODE::Chado::CV({
                  'name' => $canonical_cvname,
                }),
            })
        );
      }

      # OUTPUTS
      my $output_type_defs_terms = [];
      foreach my $value (@{$output_type_defs->get_values()}) {
        my ($name, $cv, $term) = (undef, split(/:/, $value));
        if (!defined($term)) {
          $term = $cv;
          $cv = $output_type_defs->get_types()->[0];
        }
        ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
        $term =~ s/^\s*|\s*$//g;
        push(@$output_type_defs_terms, { 'term' => $term, 'cv' => $cv, 'name' => $name });
      }
      # Since we've validated, there can be at most one anonymous datum
      foreach my $output_datum (@{$applied_protocol->get_output_data()}) {
        my ($wiki_output_def) = grep { $_->{'name'} eq $output_datum->get_name() } @$output_type_defs_terms;
        if (!$wiki_output_def) { 
          ($wiki_output_def) = grep { $_->{'name'} =~ /^\s*$/ || !defined($_->{'name'}) } @$output_type_defs_terms;
          if (!$wiki_output_def && $output_datum->is_anonymous()) {
            # An automatically added anonymous datum w/ no type; leave it alone since
            # it will be used to tie together applied protocols
            next;
          } else {
            log_error "output term '" . $output_datum->get_name() . "' is named in the IDF/SDRF, but not in the wiki.", "warning" if ($output_datum->get_name());
          }
        }
        if (!$wiki_output_def) {
          croak "Couldn't find the wiki definition for output '" . $output_datum->get_name() . "' in protocol " . $protocol->get_name() . " even though everything validated";
        }
        my $cv = $wiki_output_def->{'cv'};
        my $term = $wiki_output_def->{'term'};
        my $canonical_cvname = $cvhandler{ident $self}->get_cv_by_name($cv)->{'names'}->[0];
        $output_datum->set_type(new ModENCODE::Chado::CVTerm({
              'name' => $term,
              'cv' => new ModENCODE::Chado::CV({
                  'name' => $canonical_cvname,
                }),
            })
        );
      }
    }
  }
  log_error "Done.", "notice", "<";
  log_error "Adding wiki protocol metadata to the protocol objects.", "notice", ">";
  # Add protocol attributes based on wiki forms
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      my $protocol_name = $protocol->get_name();
      my $protocol_url = $protocol->get_description();
      my $protocol_def = (defined($protocol_defs_by_url{ident $self}->{$protocol_url}) ? $protocol_defs_by_url{ident $self}->{$protocol_url} : $protocol_defs_by_name{ident $self}->{$protocol_name});
      croak "How did this experiment manage to validate with a wiki-less protocol?!" unless $protocol_def;
      # Protocol description
      my ($protocol_description) = grep { $_->get_name() =~ /^\s*short *descriptions?$/i } @{$protocol_def->get_values()};
      if ($protocol_description) {
        $protocol_description = $protocol_description->get_values()->[0];
        $protocol->set_description($protocol_description);
      } else {
        log_error "No description for protocol $protocol_name found at $protocol_url. Using URL as description.", "warning";
        $protocol->set_description("Please see: " . $protocol_url);
      }
      # Protocol type
      # TODO: Map the CV to a Chado CV if possible
      my ($protocol_type) = grep { $_->get_name() =~ /^\s*protocol *types?$/i } @{$protocol_def->get_values()};
      # Other protocol attributes
      foreach my $wiki_protocol_attr (@{$protocol_def->get_values()}) {
        # Skip special fields (description and I/O parameters)
        next if $wiki_protocol_attr->get_name() =~ /^\s*short *descriptions?$/i;
        next if $wiki_protocol_attr->get_name() =~ /^\s*input *types?$/i;
        next if $wiki_protocol_attr->get_name() =~ /^\s*output *types?$/i;
        next if $wiki_protocol_attr->get_name() =~ /^\s*protocol *types?$/i;

        my $rank = 0;
        foreach my $value (@{$wiki_protocol_attr->get_values()}) {
          my $protocol_attr = new ModENCODE::Chado::Attribute({
              'heading' => $wiki_protocol_attr->get_name(),
              'value' => $value,
              'rank' => $rank,
            });
          # If this field has controlled vocab(s), create a CVTerm for each value
          if (scalar(@{$wiki_protocol_attr->get_types()})) {
            my ($name, $cv, $term) = (undef, split(/:/, $value));
            if (!defined($term)) {
              $term = $cv;
              $cv = $wiki_protocol_attr->get_types()->[0];
            }
            # TODO: Map the CV to a Chado CV if possible
            # Set the type_id of the attribute to this term
            my $canonical_cvname = $cvhandler{ident $self}->get_cv_by_name($cv)->{'names'}->[0];
            $protocol_attr->set_type(new ModENCODE::Chado::CVTerm({
                  'name' => $term,
                  'cv' => new ModENCODE::Chado::CV({
                      'name' => $canonical_cvname,
                    }),
                })
            );
          } else {
            # Set the type_id of the attribute to "string"
            $protocol_attr->set_type(new ModENCODE::Chado::CVTerm({
                  'name' => 'string',
                  'cv' => new ModENCODE::Chado::CV({
                      'name' => 'xsd' 
                    }),
                })
            );
          }
          $protocol->add_attribute($protocol_attr);
          $rank++;
        }
      }
    }
  }

  log_error "Done.", "notice", "<";
  return $experiment;
}

sub validate {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone(); # Don't do anything to change the experiment passed in
  my $success = 1;

  # Get soap client
  my $soap_client = SOAP::Lite->service('http://wiki.modencode.org/project/extensions/DBFields/DBFieldsService.wsdl');
  $soap_client->serializer->envprefix('SOAP-ENV');
  $soap_client->serializer->encprefix('SOAP-ENC');
  $soap_client->serializer->soapversion('1.1');

  # Attempt to login using wiki credentials
  my $username = "Validator_Robot";
  my $password = "vdate_358";
  my $domain = 'modencode_wiki';
  
  my %protocols;
  # Get wiki protocol data names and/or URLs
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      if (!defined($protocols{$protocol->get_name()})) {
        $protocols{$protocol->get_name()} = [];
        $protocols{$protocol->get_name()} = [];
      }
      push @{$protocols{$protocol->get_name()}}, $applied_protocol->get_protocol();
    }
  }
  # Get unique protocol names and descriptions
  my @unique_protocol_names = (); foreach my $name (keys(%protocols)) { if (!scalar(grep { $_ eq $name } @unique_protocol_names)) { push @unique_protocol_names, $name; } };
  my @unique_protocol_descriptions = (); foreach my $protocols (values(%protocols)) { foreach my $protocol (@$protocols) { if (!scalar(grep { $_ eq $protocol->get_description() } @unique_protocol_descriptions) && ($protocol->get_description() !~ m/^\s*$/)) { push @unique_protocol_descriptions, $protocol->get_description(); } } };

  my $login = $soap_client->getLoginCookie($username, $password, $domain);
  bless $login, 'HASH';
  $login = new ModENCODE::Validator::Wiki::LoginResult($login);

  # Fetch protocol descriptions from wiki based on protocol name
  log_error "Fetching protocol definitions from the wiki...", "notice", ">";
  if (defined($protocol_defs_by_url{ident $self}) && defined($protocol_defs_by_name{ident $self})) {
    log_error "Using cached.", "notice";
  } else {
    $protocol_defs_by_url{ident $self} = {};
    $protocol_defs_by_name{ident $self} = {};
    foreach my $protocol_name (@unique_protocol_names) {
      my $data = SOAP::Data->name('query' => \SOAP::Data->value(
          SOAP::Data->name('name' => HTML::Entities::encode($protocol_name))->type('xsd:string'),
          SOAP::Data->name('version' => undef)->type('xsd:int'),
          SOAP::Data->name('auth' => \$login->get_soap_obj())->type('LoginResult'),
      ))
      ->type('FormDataQuery');
      my $res = $soap_client->getFormData($data);

      if (!$res) { next; }
      bless($res, 'HASH');
      my $formdata = new ModENCODE::Validator::Wiki::FormData($res);
      $protocol_defs_by_name{ident $self}->{$protocol_name} = $formdata;
    }
    # Fetch protocol descriptions from wiki based on wiki link in the Protocol Description field
    log_error " ", "notice", "=";
    foreach my $protocol_description (@unique_protocol_descriptions) {
      log_error ".", "notice", ".";
      next unless $protocol_description =~ m/^\s*https?:\/\/wiki.modencode.org\/project/;
      my $data = SOAP::Data->name('query' => \SOAP::Data->value(
          SOAP::Data->name('url' => HTML::Entities::encode($protocol_description))->type('xsd:string'),
          SOAP::Data->name('auth' => \$login->get_soap_obj())->type('LoginResult'),
      ))
      ->type('FormDataQuery');
      my $res = $soap_client->getFormData($data);
      if (!$res) { next; }
      bless($res, 'HASH');
      my $formdata = new ModENCODE::Validator::Wiki::FormData($res);
      $protocol_defs_by_url{ident $self}->{$protocol_description} = $formdata;
    }
    log_error "\n", "notice", ".";
  }
  log_error "Done.", "notice", "<";

  # Validate wiki data vs. experiment data passed in
  log_error "Verifying IDF protocols against wiki...", "notice", ">";
  log_error "Validating wiki CV terms...", "notice", ">";
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      my $wiki_protocol_def = $protocol_defs_by_url{ident $self}->{$protocol->get_description()};
      $wiki_protocol_def = $protocol_defs_by_name{ident $self}->{$protocol->get_name()} unless $wiki_protocol_def;
      if (!$wiki_protocol_def) {
        croak "Couldn't find definition for protocol '" . $protocol->get_name() . "' with wiki-link '" . $protocol->get_description() . "'";
      }
      # First, any wiki field with a CV needs to be validated
      foreach my $wiki_protocol_attr (@{$wiki_protocol_def->get_values()}) {
        if (scalar(@{$wiki_protocol_attr->get_types()}) && scalar(@{$wiki_protocol_attr->get_values()})) {
          foreach my $value (@{$wiki_protocol_attr->get_values()}) {
            my ($cv, $term, $name) = $cvhandler{ident $self}->parse_term($value);
            if (!defined($cv)) { $cv = $wiki_protocol_attr->get_types()->[0]; }
            if (!$cvhandler{ident $self}->is_valid_term($cv, $term)) {
              log_error "Couldn't find cvterm '$cv.$term'.";
              $success = 0;
            }
          }
        }
      }
    }
  }
  # Second, special fields need to be dealt with:
  # * "input type" and "output type" are parameter definitions, and need to be validated against the IDF
  # definitions of the same and against the actual uses of them in the SDRF
  log_error "Done.", "notice", "<";
  log_error "Verifying that IDF controlled vocabulary match SDRF controlled vocabulary.", "notice", ">";
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      my $wiki_protocol_def = $protocol_defs_by_url{ident $self}->{$protocol->get_description()};
      $wiki_protocol_def = $protocol_defs_by_name{ident $self}->{$protocol->get_name()} unless $wiki_protocol_def;
      my ($input_type_defs) = grep { $_->get_name() =~ /^\s*input *types?\s*$/i } @{$wiki_protocol_def->get_values()};
      my ($output_type_defs) = grep { $_->get_name() =~ /^\s*output *types?\s*$/i } @{$wiki_protocol_def->get_values()};

      # PROTOCOL TYPE
      my ($wiki_protocol_type_def) = grep { $_->get_name() =~ /^\s*protocol *types?$/i } @{$wiki_protocol_def->get_values()};
      my @wiki_protocol_types = @{$wiki_protocol_type_def->get_values()};
      for (my $i = 0; $i < scalar(@wiki_protocol_types); $i++) { $wiki_protocol_types[$i] =~ s/^\s*|\s*$//; }
      my @idf_protocol_types = grep { $_->get_heading() =~ /^\s*Protocol *Types?$/i } @{$protocol->get_attributes()};
      if (!scalar(@idf_protocol_types)) {
        log_error "Protocol '" . $protocol->get_name() . "' has no protocol type definition in the IDF.", "warning";
      } 
      if (scalar(@wiki_protocol_types) != scalar(@idf_protocol_types)) {
        log_error "The protocol '" . $protocol->get_name() . "' has " . scalar(@wiki_protocol_types) . " Protocol Types in the wiki, and " . scalar(@idf_protocol_types) . " in the IDF.";
        $success = 0;
        next;
      }

      foreach my $idf_protocol_type (@idf_protocol_types) {
        my ($idf_type_cv, $idf_type_term, undef) = $cvhandler{ident $self}->parse_term($idf_protocol_type->get_value());
        if (!$idf_type_cv) { $idf_type_cv = $idf_protocol_type->get_termsource()->get_db()->get_name(); }
        if (!$cvhandler{ident $self}->get_cv_by_name($idf_type_cv)) {
          my $idf_type_url = $idf_protocol_type->get_termsource()->get_db()->get_url();
          my $idf_type_url_type = $idf_protocol_type->get_termsource()->get_db()->get_description();
          $cvhandler{ident $self}->add_cv($idf_type_cv, $idf_type_url, $idf_type_url_type);
        }
        if (!$cvhandler{ident $self}->get_cv_by_name($idf_type_cv)) {
          log_error "Could not find a canonical URL for the controlled vocabulary $idf_type_cv when validating term " . $idf_protocol_type->get_value() . ".";
          $success = 0;
          next;
        }
        my $idf_type_cv = $cvhandler{ident $self}->get_cv_by_name($idf_type_cv)->{'names'}->[0];
        my $valid = 0;
        for (my $i = 0; $i < @wiki_protocol_types; $i++) {
          my $wiki_protocol_type = $wiki_protocol_types[$i];
          my ($cv, $term, $name) = $cvhandler{ident $self}->parse_term($wiki_protocol_type);
          if (!defined($cv)) { $cv = $wiki_protocol_type_def->get_types()->[0]; }
          my $cv = $cvhandler{ident $self}->get_cv_by_name($cv)->{'names'}->[0];
          if ($cv eq $idf_type_cv && $term eq $idf_type_term) {
            $valid = 1;
            last;
          }
        }
        if (!$valid) {
          log_error "Could not find the protocol type $idf_type_cv:$idf_type_term defined in the wiki for '" . $protocol->get_name() . "'.";
          $success = 0;
        }
      }
      # INPUTS
      my $input_type_defs_terms = [];
      foreach my $value (@{$input_type_defs->get_values()}) {
        my ($name, $cv, $term) = (undef, split(/:/, $value));
        if (!defined($term)) {
          $term = $cv;
          $cv = $input_type_defs->get_types()->[0];
        }
        ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
        $term =~ s/^\s*|\s*$//g;
        push(@$input_type_defs_terms, { 'term' => $term, 'cv' => $cv, 'name' => $name });
      }

      # Fail if there's more than one unnamed input in the SDRF
      my @anonymous_data = grep { $_->is_anonymous() } @{$applied_protocol->get_input_data()};
      if (scalar(grep { !defined($_->get_name()) || length($_->get_name()) <= 0 } @{$applied_protocol->get_input_data()}) - scalar(@anonymous_data) > 1) {
        log_error "Cannot have more than one un-named input parameter (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_input_data()}) . ") for protocol " . $protocol->get_name() . " in the SDRF.";
        $success = 0;
        next;
      }
      # Fail if there's more than one unnamed input in the wiki
      if (scalar(grep { !defined($_->{'name'}) || length($_->{'name'}) <= 0 } @$input_type_defs_terms) > 1) {
        log_error "Cannot have more than one un-named input parameter (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$input_type_defs_terms) . ") for protocol " . $protocol->get_name() . " in the wiki.";
        $success = 0;
        next;
      }
      # Fail if the number of inputs in the SDRF is not equal to the number in the wiki
      if (
        scalar(@$input_type_defs_terms) != scalar(@{$applied_protocol->get_input_data()}) - scalar(@anonymous_data) # Everything but an un-needed anonymous one
        &&
        scalar(@$input_type_defs_terms) != scalar(@{$applied_protocol->get_input_data()}) # Everything accounted for
      ) {
        log_error("There are " . scalar(@$input_type_defs_terms) . " input parameters according to the wiki" .
        " (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$input_type_defs_terms) . ")" .
        ", and " . scalar(@{$applied_protocol->get_input_data()}) . " input parameters in the SDRF" .
        " (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_input_data()}) . ")" .
        " for protocol " . $protocol->get_name() . ".\n" .
        "Please correct one or the other.");
        $success = 0;
        next;
      }
      # Verify that any named inputs are also named in the $experiment
      # If there's only one unnamed one in the set, see if there's an unnamed type in the wiki for it?
      foreach my $wiki_term (@$input_type_defs_terms) {
        next unless (defined($wiki_term->{'name'}) && length($wiki_term->{'name'})); # Allowed to have one unnamed one
        if (!scalar(grep { $_->get_name() eq $wiki_term->{'name'} } @{$applied_protocol->get_input_data()})) {
          log_error "Can't find the input [" . $wiki_term->{'name'} . "] in the SDRF for protocol '" . $protocol->get_name() . "'.";
          $success = 0;
          next;
        }
      }

      # OUTPUTS
      my $output_type_defs_terms = [];
      foreach my $value (@{$output_type_defs->get_values()}) {
        my ($name, $cv, $term) = (undef, split(/:/, $value));
        if (!defined($term)) {
          $term = $cv;
          $cv = $output_type_defs->get_types()->[0];
        }
        ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
        $term =~ s/^\s*|\s*$//g;
        push(@$output_type_defs_terms, { 'term' => $term, 'cv' => $cv, 'name' => $name });
      }

      # Fail if there's more than one unnamed output in the SDRF
      my @anonymous_data = grep { $_->is_anonymous() } @{$applied_protocol->get_output_data()};
      if (scalar(grep { !defined($_->get_name()) || length($_->get_name()) <= 0 } @{$applied_protocol->get_output_data()}) - scalar(@anonymous_data) > 1) {
        log_error "Cannot have more than one un-named output parameter (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_output_data()}) . ") for protocol " . $protocol->get_name() . " in the SDRF.";
        $success = 0;
        next;
      }
      # Fail if there's more than one unnamed output in the wiki
      if (scalar(grep { !defined($_->{'name'}) || length($_->{'name'}) <= 0 } @$output_type_defs_terms) > 1) {
        log_error "Cannot have more than one un-named output parameter (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$output_type_defs_terms) . ") for protocol '" . $protocol->get_name() . "' in the wiki.";
        $success = 0;
        next;
      }
      # Fail if the number of outputs in the SDRF is not equal to the number in the wiki
      if (
        scalar(@$output_type_defs_terms) != scalar(@{$applied_protocol->get_output_data()}) - scalar(@anonymous_data) # Everything but an un-needed anonymous one
        &&
        scalar(@$output_type_defs_terms) != scalar(@{$applied_protocol->get_output_data()}) # Everything accounted for
      ) {
        log_error("There are " . scalar(@$output_type_defs_terms) . " output parameters according to the wiki" .
        " (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$output_type_defs_terms) . ")" .
        ", and " . scalar(@{$applied_protocol->get_output_data()}) . " output parameters in the SDRF" .
        " (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_output_data()}) . ")" .
        " for protocol '" . $protocol->get_name() . "'.\n" .
        "Please correct one or the other.");
        $success = 0;
        next;
      }
      # Verify that any named outputs are also named in the $experiment
      # If there's only one unnamed one in the set, see if there's an unnamed type in the wiki for it?
      foreach my $wiki_term (@$output_type_defs_terms) {
        next unless (defined($wiki_term->{'name'}) && length($wiki_term->{'name'})); # Allowed to have one unnamed one
        if (!scalar(grep { $_->get_name() eq $wiki_term->{'name'} } @{$applied_protocol->get_output_data()})) {
          log_error "Can't find the output [" . $wiki_term->{'name'} . "] in the SDRF for protocol '" . $protocol->get_name() . "'.";
          $success = 0;
          next;
        }
      }
    }
  }
  log_error "Done.", "notice", "<";
  log_error "Done.", "notice", "<";

  return $success;
}

1;

package ModENCODE::Validator::Wiki;
=pod

=head1 NAME

ModENCODE::Validator::Wiki - Validator that will validate a BIR-TAB
L<ModENCODE::Chado::Experiment> object by verifying it against a MediaWiki
installation running the DBFields extensions with appropriate templates for
protocols installed.

=head1 SYNOPSIS

This class uses the SOAP web services provided by the MediaWiki DBFields
extension to ensure that protocols described in a BIR-TAB SDRF/IDF match
protocol definitions on the wiki. It will also pull additional fields out of the
DBFields forms and attach them to the L<ModENCODE::Chado::Protocol> objects in
the L<Experiment|ModENCODE::Chado::Experiment> object being validated.

There are four special field names that should exist in the DBFields form for
any protocol being validated: C<input types>, C<output types>, C<protocol
types>, and C<short description> (these fields are case insensitive). The first
three of these should ideally be linked to a controlled vocabulary as part of
the DBFields form; this controlled vocabulary will allow the terms pulled in to
be converted to L<CVTerms|ModENCODE::Chado::CVTerm>.

=head1 USAGE

=head2 Inputs/Outputs

The C<input types> and C<output types> fields should contain semicolon-separated
entries in the form:

  CV:cvterm [field name]

Where C<CV> is a L<CV|ModENCODE::Chado::CV>, C<cvterm> is a
L<CVTerm|ModENCODE::Chado::CVTerm>, and field name is a string matching up to
the L<name|ModENCODE::Chado::Data/get_name() | set_name($name)> field of a
L<Data|ModENCODE::Chado::Data> object. For each
L<ModENCODE::Chado::AppliedProtocol> in the
L<Experiment|ModENCODE::Chado::Experiment> being validated, the DBFields form
(kept in the protocol's
L<description|ModENCODE::Chado::Protocol/get_description() |
set_description($description)>) is fetched and used to ensure that there is an
input to the L<AppliedProtocol|ModENCODE::Chado::AppliedProtocol> for each field
in C<input types> and an output for each field in C<output types>. In each case,
a I<single> field may optionally have no name (e.g. C<CV:cvterm> without
C<[field name>). If there is a (single) field from the
L<SDRF|ModENCODE::Parser::SDRF>/L<AppliedProtocol|ModENCODE::Chado::AppliedProtocol> that has not yet been
matched to a type, the unnamed one will be used. If there is more than one such
unnamed field, or if there are any fields that cannot be matched between the
L<AppliedProtocol|ModENCODE::Chado::AppliedProtocol> and DBFields information,
then validation fails. This means that validation will always fail if there are
a different number of inputs or outputs in the
L<AppliedProtocol|ModENCODE::Chado::AppliedProtocol> as compared to the
DBFields data. (Validation also fails if there is no DBFields entry at all for a
protocol.)

Furthermore, if the C<input types> or C<output types> field in the DBFields form
has an associated controlled vocabulary, then all of the generated
L<CVTerms|ModENCODE::Chado::CVTerm> are checked against the controlled
vocabulary using
L<ModENCODE::Validator::CVHandler/is_valid_term($cvname, $term)>.

=head2 Protocol Type(s)

The C<protocol types> field contains semicolon-separated types for the protocol;
these must match the C<Protocol Type> field from the IDF, which are stored as
protocol attributes. This field is most useful when there is a controlled
vocabulary associated with the DBFields form field. When this is the case, not
only must the terms be consistent, but they must exist in the controlled
vocabulary; this is checked using the
L<ModENCODE::Validator::CVHandler/is_valid_term($cvname, $term)>
method.

=head2 Short Description

The contents of this field are used to replace the
L<Protocol's|ModENCODE::Chado::Protocol>
L<description|ModENCODE::Chado::Protocol/get_description() |
set_description($description)> during the merging process. If there is no short
description, then the protocol's description is set to the URL of the wiki page
containing the DBFields form being used and a warning message is printed.

=head2 Configuration

The validation requires valid credentials to login to the MediaWiki instance, as
well as the SOAP service definition URL (WSDL). These can be configured in the
C<[wiki]> section of the ini-file loaded by L<ModENCODE::Config>. (For more
information on configuring, see the L<[wiki] section|ModENCODE::Config/[wiki]> in
L<ModENCODE::Config>.

=head2 Running the Validator

To run the validator:

  my $wiki_validator = new ModENCODE::Validator::Wiki();
  if ($wiki_validator->validate($experiment)) {
    $experiment = $wiki_validator->merge($experiment);
    my $applied_protocl = $experiment->get_applied_protocols_at_slot(0)->[0];
    print $applied_protocol->get_input_data()->[0]->get_type()->to_string();
  }

=head1 FUNCTIONS

=over

=item validate($experiment)

Ensures that the L<Experiment|ModENCODE::Chado::Experiment> specified in
C<$experiment> contains only
L<AppliedProtocols|ModENCODE::Chado::AppliedProtocol> with
L<Protocols|ModENCODE::Chado::Protocol> that match the protocols defined using
the DBFields extension for MediaWiki. Returns 0 if the protocols do not match
the templates, or 1 if they do.

=item merge($experiment)

Updates any L<Protocols|ModENCODE::Chado::Protocol> to include L<controlled
vocabulary terms|ModENCODE::Chado::CVTerm> for any
L<Data|ModENCODE::Chado::Data> associated with those terms by types defined in
the C<input types> and C<output types> fields from a DBFields form. Also updates
the L<description|ModENCODE::Chado::Protocol/get_description() |
set_description($description)> for any L<Protocols|ModENCODE::Chado::Protocol>
based on the C<short description> field in the DBFields form. Returns the
updated L<ModENCODE::Chado::Experiment> object.

=back

=head1 SEE ALSO

L<Class::Std>, L<SOAP::Lite>, L<SOAP::Data>,
L<ModENCODE::Validator::Wiki::FormData>,
L<ModENCODE::Validator::Wiki::FormValues>,
L<ModENCODE::Validator::Wiki::LoginResult>, L<ModENCODE::Validator::CVHandler>,
L<ModENCODE::Validator::Attributes>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::IDF_SDRF>, L<ModENCODE::Validator::CVHandler>,
L<ModENCODE::Validator::TermSources>, L<ModENCODE::Chado::Experiment>,
L<ModENCODE::Chado::ExperimentProp>, L<ModENCODE::Chado::Protocol>,
L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::Attribute>,
L<ModENCODE::Chado::Feature>, L<ModENCODE::Chado::CVTerm>,
L<ModENCODE::Chado::DBXref>, L<ModENCODE::Chado::DB>, L<ModENCODE::Chado::CV>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use SOAP::Lite;# +trace => qw(debug);
use ModENCODE::Validator::Wiki::FormData;
use ModENCODE::Validator::Wiki::FormValues;
use ModENCODE::Validator::Wiki::LoginResult;
#use ModENCODE::Validator::CVHandler;
use HTML::Entities ();
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;

my %experiment                  :ATTR( :name<experiment> );

sub BUILD {
  my ($self, $ident, $args) = @_;

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
  my $experiment = $self->get_experiment();
  my $success = 1;
  my $anonymous_data_num = 0;
  my %seen;

  # Get soap client
  my $soap_client = SOAP::Lite->service(ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'));
  $soap_client->serializer->envprefix('SOAP-ENV');
  $soap_client->serializer->encprefix('SOAP-ENC');
  $soap_client->serializer->soapversion('1.1');

  my @protocols = grep { !$seen{$_->get_id}++ } map { $_->get_protocol() } map { @$_ } @{$experiment->get_applied_protocol_slots()};
  my ($experiment_description) = grep { $_->get_object->get_name() eq "Experiment Description" } $experiment->get_properties;

  # Attempt to login using wiki credentials
  my $login = $soap_client->getLoginCookie(
    ModENCODE::Config::get_cfg()->val('wiki', 'username'),
    ModENCODE::Config::get_cfg()->val('wiki', 'password'),
    ModENCODE::Config::get_cfg()->val('wiki', 'domain'),
  );
  bless $login, 'HASH';
  $login = new ModENCODE::Validator::Wiki::LoginResult($login);

  # Fetch protocol descriptions from wiki based on protocol name
  log_error "Fetching protocol definitions from the wiki...", "notice", ">";

  # Get the protocol definitions by the URL in the protocol descriptions
  # (and tack on the experiment description)
  log_error " ", "notice", "=";
  my %protocol_defs_by_url;
  foreach my $protocol_description ($experiment_description->get_object->get_value, map { $_->get_object->get_description } @protocols) {
    log_error ".", "notice", ".";
    next unless $protocol_description =~ m/^\s*http:\/\//;
    my $data = SOAP::Data->name('query' => \SOAP::Data->value(
        SOAP::Data->name('url' => HTML::Entities::encode($protocol_description))->type('xsd:string'),
        SOAP::Data->name('auth' => \$login->get_soap_obj())->type('LoginResult'),
      ))
    ->type('FormDataQuery');
    my $res = $soap_client->getFormData($data);
    if (!$res) { next; }
    bless($res, 'HASH');
    my ($oldid) = ($protocol_description =~ /oldid=(\d+)/);
    if ($res->{'requested_name'} && ($res->{'requested_name'} ne $res->{'name'})) {
      log_error "\n", "notice", ".";
      log_error "Tried to get " . $res->{'requested_name'} . ":$oldid, but got back " . $res->{'name'} . ":" . $res->{'revision'} . " instead.", "error";
      $success = 0;
    }
    my $formdata = new ModENCODE::Validator::Wiki::FormData($res);
    $protocol_defs_by_url{$protocol_description} = $formdata;
  }
  log_error "\n", "notice", ".";

  log_error "Done.", "notice", "<";

  log_error "Verifying IDF protocols against wiki...", "notice", ">";

  # Validate wiki data vs. experiment data passed in
  foreach my $protocol (@protocols) {
    my $wiki_protocol_def = $protocol_defs_by_url{$protocol->get_object->get_description()};
    if (!$wiki_protocol_def) {
      log_error "Couldn't find definition for protocol '" . $protocol->get_object->get_name() . "' with wiki-link '" . $protocol->get_object->get_description() . "'";
      $success = 0;
      next;
    } else {
      my ($protocol_description) = grep { $_->get_name() =~ /^\s*short *descriptions?$/i } @{$wiki_protocol_def->get_string_values()};
      $protocol_description = $protocol_description->get_values->[0] if $protocol_description;
      if (!$protocol_description) {
        log_error "Couldn't find a short description on the wiki for the " . $protocol->get_object->get_name . " protocol.", "error";
        $success = 0;
        next;
      }
      my $dbxref = new ModENCODE::Chado::DBXref({
          'db' => new ModENCODE::Chado::DB({
              'name' => 'ModencodeWiki'
            }),
          'accession' => $protocol->get_object->get_description,
        });
      $protocol->get_object->set_termsource($dbxref) unless $protocol->get_object->get_termsource;
      my $protocol_version = $wiki_protocol_def->get_version;
      $protocol->get_object->set_version($protocol_version);
      $protocol->get_object->set_description($protocol_description);
    }

    log_error "Validating wiki CV terms for protocol " . $protocol->get_object->get_name . "...", "notice", ">";
    # First, any wiki field with a CV needs to be validated
    foreach my $wiki_protocol_attr (@{$wiki_protocol_def->get_values()}) {
      if (scalar(@{$wiki_protocol_attr->get_types()}) && scalar(@{$wiki_protocol_attr->get_values()})) {
        foreach my $value (@{$wiki_protocol_attr->get_values()}) {
          my ($cv, $term, $name) = ModENCODE::Config::get_cvhandler()->parse_term($value);
          if (!defined($cv)) { $cv = $wiki_protocol_attr->get_types()->[0]; }
          if (!ModENCODE::Config::get_cvhandler()->is_valid_term($cv, $term)) {
            log_error "Couldn't find cvterm '$cv:$term'.";
            $success = 0;
          }
        }
      }
      # Add any attributes that aren't a special field
      next if $wiki_protocol_attr->get_name() =~ /^\s*short *descriptions?$/i;
      next if $wiki_protocol_attr->get_name() =~ /^\s*input *types?$/i;
      next if $wiki_protocol_attr->get_name() =~ /^\s*output *types?$/i;
      next if $wiki_protocol_attr->get_name() =~ /^\s*protocol *types?$/i;

      my $rank = 0;
      foreach my $value (@{$wiki_protocol_attr->get_values}) {
        my $protocol_attr = new ModENCODE::Chado::ProtocolAttribute({
            'heading' => $wiki_protocol_attr->get_name(),
            'value' => $value,
            'rank' => $rank,
            'type' => new ModENCODE::Chado::CVTerm({
                'name' => 'string',
                'cv' => new ModENCODE::Chado::CV({
                    'name' => 'xsd',
                  }),
              }),
            'protocol' => $protocol,
          });
        if (scalar(@{$wiki_protocol_attr->get_types()})) {
          my ($name, $cv, $term) = (undef, split(/:/, $value));
          if (!defined($term)) {
            $term = $cv;
            $cv = $wiki_protocol_attr->get_types()->[0];
          }
          # Set the type_id of the attribute to this term
          my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
          $protocol_attr->get_object->set_type(new ModENCODE::Chado::CVTerm({
                'name' => $term,
                'cv' => new ModENCODE::Chado::CV({
                    'name' => $canonical_cvname,
                  }),
              })
          );
        } else {
          # Set the type_id of the attribute to "string"
          $protocol_attr->get_object->set_type(new ModENCODE::Chado::CVTerm({
                'name' => 'string',
                'cv' => new ModENCODE::Chado::CV({
                    'name' => 'xsd' 
                  }),
              })
          );
          # Set the value to the whole string_value (can't split on commas if there's no types)
          my ($str_value) = grep { $_->get_name() eq $wiki_protocol_attr->get_name() } @{$wiki_protocol_def->get_string_values()};
          $value = $str_value->get_values()->[0];
          $protocol_attr->get_object->set_value($value);
        }
        log_error "Adding attribute " . $protocol_attr->get_object->get_heading . "=" . $protocol_attr->get_object->get_value . " from wiki to protocol " . $protocol->get_object->get_name . ".", "debug";
        $protocol->get_object->add_attribute($protocol_attr);
        $rank++;
      }
    }
    log_error "Done.", "notice", "<";

    # Second, special fields need to be dealt with:
    # * "input type" and "output type" are parameter definitions, and need to be validated against the IDF
    # definitions of the same and against the actual uses of them in the SDRF
    log_error "Verifying that IDF controlled vocabulary match SDRF controlled vocabulary for protocol " . $protocol->get_object->get_name . ".", "notice", ">";
    my ($wiki_protocol_type_def) = grep { $_->get_name() =~ /^\s*protocol *types?$/i } @{$wiki_protocol_def->get_values()};
    # PROTOCOL TYPE
    if (!$wiki_protocol_type_def) {
      log_error "No protocol type(s) defined in the wiki for '" . $protocol->get_object->get_name() . "'", "error";
      $success = 0;
      next;
    }
    my @wiki_protocol_types = @{$wiki_protocol_type_def->get_values()};
    @wiki_protocol_types = map { $_ =~ s/^\s*|\s*$//; $_ } @wiki_protocol_types;

    my @idf_protocol_types = grep { $_->get_object->get_heading() =~ /^\s*Protocol *Types?$/i } $protocol->get_object->get_attributes;
    if (!scalar(@idf_protocol_types)) {
      log_error "Protocol '" . $protocol->get_object->get_name() . "' has no protocol type definition in the IDF.", "warning";
    } 
    if (scalar(@wiki_protocol_types) != scalar(@idf_protocol_types)) {
      log_error "Protocol '" . $protocol->get_object->get_name() . "' has a different number of types in the wiki (" .
      scalar(@wiki_protocol_types) . ") and the IDF (" . scalar(@idf_protocol_types) . "), please fix this.", "error";
      $success = 0;
      next;
    }

    # Make sure each CV and term defined in the IDF exist, and get the canonical CV name(s)
    @idf_protocol_types = sort { $a->[0] . ":" . $a->[1] cmp $b->[0] . ":" . $b->[1] } map {
      my ($cv, $term, undef) = ModENCODE::Config::get_cvhandler->parse_term($_->get_object->get_value);
      $cv = $_->get_object->get_termsource(1)->get_db(1)->get_name unless $cv;
      if (!ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)) {
        # If the CV isn't loaded or available, load it
        my $cv_url = $_->get_object->get_termsource(1)->get_db(1)->get_url();
        my $cv_url_type = $_->get_object->get_termsource(1)->get_db(1)->get_description(); # OBO, etc.
        ModENCODE::Config::get_cvhandler()->add_cv($cv, $cv_url, $cv_url_type);
      }
      if (!ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)) {
        log_error "Could not find a canonical URL for the controlled vocabulary $cv when validating term " . $_->get_value() . ".";
        $success = 0;
        next;
      }

      # The CV is now a real CV, so get back the canonical name for it
      # Case doesn't matter, so lowercase it
      $cv = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
      [ $cv, $term ]
    } @idf_protocol_types;

    @wiki_protocol_types = sort { $a->[0] . ":" . $a->[1] cmp $b->[0] . ":" . $b->[1] } map {
      my ($cv, $term, $name) = ModENCODE::Config::get_cvhandler()->parse_term($_);
      $_->get_types()->[0] unless $cv;
      $cv = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
      [$cv, $term]
    } @wiki_protocol_types;

    # Make sure @idf_protocol_types and @wiki_protocol_types are the same
    if (scalar(@wiki_protocol_types) != scalar(@idf_protocol_types)) {
      log_error "The protocol '" . $protocol->get_object->get_name() . "' has " . scalar(@wiki_protocol_types) . " Protocol Types in the wiki, and " . scalar(@idf_protocol_types) . " in the IDF.";
      $success = 0;
      next;
    }
    for (my $i = 0; $i < scalar(@wiki_protocol_types); $i++) {
      if (
        $idf_protocol_types[$i]->[0] ne $wiki_protocol_types[$i]->[0] || 
        $idf_protocol_types[$i]->[1] ne $wiki_protocol_types[$i]->[1]) {
        log_error "The protocol type " . $idf_protocol_types[$i]->[0] . ":" . $idf_protocol_types[$i]->[1] . " defined in the IDF does not match the protocol type (" . $wiki_protocol_types[$i]->[0] . ":" . $wiki_protocol_types[$i]->[1] . ") defined in the wiki for '" . $protocol->get_object->get_name() . "'.";
        $success = 0;
      }
    }
    log_error "Done.", "notice", "<";

    # Validate and merge inputs and outputs, merge protocol type

    # Collect all of the inputs from the wiki
    my ($input_type_defs) = grep { $_->get_name() =~ /^\s*input *types?\s*$/i } @{$wiki_protocol_def->get_values()};
    my @wiki_input_definitions = sort { $a->{'cv'} . ":" . $a->{'term'} . ":" . $a->{'value'} cmp $b->{'cv'} . ":" . $b->{'term'} . ":" . $b->{'value'} } 
    map {
      my ($name, $cv, $term) = (undef, split(/:/, $_));
      if (!defined($term)) {
        $term = $cv;
        $cv = $input_type_defs->get_types->[0];
      }
      ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
      $term =~ s/^\s*|\s*$//g;
      { 'term' => $term, 'cv' => $cv, 'name' => $name }
    } @{$input_type_defs->get_values};
    # Fail if there's more than one unnamed input in the wiki
    if (scalar(grep { !defined($_->{'name'}) || length($_->{'name'}) <= 0 } @wiki_input_definitions) > 1) {
      log_error "Cannot have more than one un-named input parameter (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @wiki_input_definitions) . ") for protocol " . $protocol->get_object->get_name() . " in the wiki.";
      $success = 0;
      next;
    }

    # Collect all of the outputs from the wiki
    my ($output_type_defs) = grep { $_->get_name() =~ /^\s*output *types?\s*$/i } @{$wiki_protocol_def->get_values()};
    if (!$output_type_defs) {
      log_error "No outputs for protocol " . $protocol->get_object->get_name() . "! Please check your protocol definition on the wiki.", "error";
      $success = 0;
      next;
    }
    my @wiki_output_definitions = sort { $a->{'cv'} . ":" . $a->{'term'} . ":" . $a->{'value'} cmp $b->{'cv'} . ":" . $b->{'term'} . ":" . $b->{'value'} } 
    map {
      my ($name, $cv, $term) = (undef, split(/:/, $_));
      if (!defined($term)) {
        $term = $cv;
        $cv = $output_type_defs->get_types->[0];
      }
      ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
      $term =~ s/^\s*|\s*$//g;
      { 'term' => $term, 'cv' => $cv, 'name' => $name }
    } @{$output_type_defs->get_values};
    # Fail if there's more than one unnamed output in the wiki
    if (scalar(grep { !defined($_->{'name'}) || length($_->{'name'}) <= 0 } @wiki_output_definitions) > 1) {
      log_error "Cannot have more than one un-named output parameter (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @wiki_output_definitions) . ") for protocol " . $protocol->get_object->get_name() . " in the wiki.";
      $success = 0;
      next;
    }

    ############################
    # Allow multiple protocols in a single column by checking to make sure inputs and outputs are identical
    ############################
    my @applied_protocols_for_this_protocol;
    my $applied_protocol_slot_for_this_protocol;
    for (my $i = 0; $i < scalar(@{$experiment->get_applied_protocol_slots}); $i++) {
      push @applied_protocols_for_this_protocol, grep { $_->get_protocol_id == $protocol->get_id } @{$experiment->get_applied_protocol_slots->[$i]};
      if (scalar(@applied_protocols_for_this_protocol)) {
        $applied_protocol_slot_for_this_protocol = $i;
        last;
      }
    }
    if (scalar(@applied_protocols_for_this_protocol) != scalar(@{$experiment->get_applied_protocol_slots->[$applied_protocol_slot_for_this_protocol]})) {
      log_error "You are using multiple protocols in a single column (column " . ($applied_protocol_slot_for_this_protocol+1) . "); this is supported only if the inputs and outputs are described identically in the wiki!", "warning";
      my %seen;
      # Compare wiki definitions to verify that they're the same
      my @descriptions = grep { !$seen{$_}++ } map { 
        $_->get_protocol(1)->get_termsource() ? $_->get_protocol(1)->get_termsource(1)->get_accession : $_->get_protocol(1)->get_description() 
      } @{$experiment->get_applied_protocol_slots->[$applied_protocol_slot_for_this_protocol]};

      my @definitions = map { 
        my $url = $_;
        if (!$protocol_defs_by_url{$url}) {
          log_error "Couldn't find protocol/experiment definition on wiki at URL $url", "error";
          $success = 0;
          last;
        }
        my ($input_type_defs) = grep { $_->get_name() =~ /^\s*input *types?\s*$/i } @{$protocol_defs_by_url{$url}->get_values()};
        my ($output_type_defs) = grep { $_->get_name() =~ /^\s*output *types?\s*$/i } @{$protocol_defs_by_url{$url}->get_values()};

        my @input_defs = map {
          my ($name, $cv, $term) = (undef, split(/:/, $_));
          if (!defined($term)) {
            $term = $cv;
            $cv = $input_type_defs->get_types->[0];
          }
          ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
          $term =~ s/^\s*|\s*$//g;
          { 'term' => $term, 'cv' => $cv, 'name' => $name }
        } @{$input_type_defs->get_values};

        my @output_defs = map {
          my ($name, $cv, $term) = (undef, split(/:/, $_));
          if (!defined($term)) {
            $term = $cv;
            $cv = $output_type_defs->get_types->[0];
          }
          ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
          $term =~ s/^\s*|\s*$//g;
          { 'term' => $term, 'cv' => $cv, 'name' => $name }
        } @{$output_type_defs->get_values};

        [ \@input_defs, \@output_defs, $url ];

      } @descriptions;
      foreach my $definition (@definitions) {
        my @inputs = @{$definition->[0]};
        my @outputs = @{$definition->[1]};
        my $url = $definition->[3];
        foreach my $other_definition (@definitions) {
          my @other_inputs = @{$other_definition->[0]};
          my @other_outputs = @{$other_definition->[1]};
          my $other_url = $other_definition->[3];
          if (scalar(@other_inputs) != scalar(@inputs)) {
            log_error "Protocol at $url has " . scalar(@inputs) . " inputs, while protocol at $other_url has " . scalar(@other_inputs) . " inputs. These cannot differ for alternative treatments!", "error";
            $success = 0;
          } elsif (scalar(@other_outputs) != scalar(@outputs)) {
            log_error "Protocol at $url has " . scalar(@outputs) . " outputs, while protocol at $other_url has " . scalar(@other_outputs) . " outputs. These cannot differ for alternative treatments!", "error";
            $success = 0;
          }

          for (my $i = 0; $i < scalar(@inputs); $i++) {
            if (
              $inputs[$i]->{'cv'} ne $other_inputs[$i]->{'cv'} ||
              $inputs[$i]->{'name'} ne $other_inputs[$i]->{'name'} ||
              $inputs[$i]->{'term'} ne $other_inputs[$i]->{'term'}
            ) {
              log_error "Input $i for the protocol at $url is not the same as input $i for the protocol at $other_url:", "error";
              log_error "  " . $inputs[$i]->{'cv'} . ":" . $inputs[$i]->{'term'} . " [" . $inputs[$i]->{'name'} . "] != " . 
                        $other_inputs[$i]->{'cv'} . ":" . $other_inputs[$i]->{'term'} . " [" . $other_inputs[$i]->{'name'} . "]", "error";
              $success = 0;
            }
          }
          for (my $i = 0; $i < scalar(@outputs); $i++) {
            if (
              $outputs[$i]->{'cv'} ne $other_outputs[$i]->{'cv'} ||
              $outputs[$i]->{'name'} ne $other_outputs[$i]->{'name'} ||
              $outputs[$i]->{'term'} ne $other_outputs[$i]->{'term'}
            ) {
              log_error "Input $i for the protocol at $url is not the same as output $i for the protocol at $other_url:", "error";
              log_error "  " . $outputs[$i]->{'cv'} . ":" . $outputs[$i]->{'term'} . " [" . $outputs[$i]->{'name'} . "] != " . 
                        $other_outputs[$i]->{'cv'} . ":" . $other_outputs[$i]->{'term'} . " [" . $other_outputs[$i]->{'name'} . "]", "error";
              $success = 0;
            }
          }
          return $success unless $success;
        }
      }
    }
    ############################
    # End block to verify that protocols in a single column have the same inputs/outputs
    ############################

    # Validate the inputs and outputs from the SDRF against the wiki for each applied protocol
    foreach my $applied_protocol (@applied_protocols_for_this_protocol) {
      # INPUTS
      # Fail if there's more than one unnamed input in the SDRF
      my @anonymous_data = grep { $_->is_anonymous() } $applied_protocol->get_input_data(1);
      if (scalar(grep { !defined($_->get_name()) || length($_->get_name()) <= 0 } $applied_protocol->get_input_data(1)) - scalar(@anonymous_data) > 1) {
        log_error "Cannot have more than one un-named input parameter (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } $applied_protocol->get_input_data(1)) . ") for protocol " . $protocol->get_object->get_name() . " in the SDRF.";
        $success = 0;
        next;
      }

      # Really special case where there's a single _extra_ anonymous datum implied by the wiki (type but no name)
      # AND no unnamed (anonymous_data) column in the SDRF AND named columns in the SDRF so an anonymous datum
      # was not automatically created
      if (
        # No unnamed columns in SDRF
        scalar(@anonymous_data) == 0
        && 
        # Only one extra type in wiki
        (scalar(@wiki_input_definitions)-1) == scalar($applied_protocol->get_input_data)
        &&
        # Only one unnamed type in wiki
        scalar(grep { $_->{'name'} eq '' } @wiki_input_definitions) == 1
      ) {
        my ($missing_type) = grep { $_->{'name'} eq '' } @wiki_input_definitions;
        if ($applied_protocol_slot_for_this_protocol == 0) {
          log_error "You can't have an anonymous implied input to the first protocol with no column for it in the SDRF; check the wiki for inputs of type " . $missing_type->{'cv'} . ":" . $missing_type->{'term'} . ".", "error";
          $success = 0;
          next;
        } else {
          log_error "Assuming that " . $missing_type->{'cv'} . ":" . $missing_type->{'term'} . " applies to an implied extra input column that is not shown in the SDRF.", "warning";
          next;
        }
      }

      # Fail if the number of inputs in the SDRF is not equal to the number in the wiki
      if (
        scalar(@wiki_input_definitions) != scalar($applied_protocol->get_input_data) - scalar(@anonymous_data) # Everything but an un-needed anonymous one
        &&
        scalar(@wiki_input_definitions) != scalar($applied_protocol->get_input_data) # Everything accounted for
      ) {
        log_error("There are " . scalar(@wiki_input_definitions) . " input parameters according to the wiki" .
        " (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @wiki_input_definitions) . ")" .
        ", and " . scalar($applied_protocol->get_input_data) . " input parameters in the SDRF" .
        " (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } $applied_protocol->get_input_data(1)) . ")" .
        " for protocol " . $protocol->get_object->get_name() . ".\n" .
        "Please correct one or the other.");
        $success = 0;
        next;
      }
      # Verify that any named inputs are also named in the $experiment
      # If there's only one unnamed one in the set, see if there's an unnamed type in the wiki for it?
      foreach my $wiki_term (@wiki_input_definitions) {
        next unless (defined($wiki_term->{'name'}) && length($wiki_term->{'name'})); # Allowed to have one unnamed one
        if (!scalar(grep { $_->get_name() eq $wiki_term->{'name'} } $applied_protocol->get_input_data(1))) {
          log_error "Can't find the input [" . $wiki_term->{'name'} . "] in the SDRF for protocol '" . $protocol->get_object->get_name() . "'.";
          $success = 0;
          next;
        }
      }

      # Update the input's type to match the type defined on the wiki
      foreach my $input ($applied_protocol->get_input_data) {
        my ($wiki_term) = grep { $_->{'name'} eq $input->get_object->get_name } @wiki_input_definitions;
        if (!$wiki_term) {
          # Try to find an anonymous term
          ($wiki_term) = grep { $_->{'name'} =~ /^\s*$/ || !defined($_->{'name'}) } @wiki_input_definitions;
          if (!$wiki_term && $input->get_object->is_anonymous) {
            # An automatically added anonymous datum w/ no type; leave it alone since
            # it will be used to tie together applied protocols
            next;
          } else {
            log_error "Input term of " . $applied_protocol->get_protocol(1)->get_name() . ": " . $input->get_object->get_heading . " [" . $input->get_object->get_name . "] is named in the IDF/SDRF, but not in the wiki.", "warning" if ($input->get_object->get_name());
          }
        }
        if (!$wiki_term) {
          # No anonymous type found on the wiki
          $success = 0;
          log_error "Couldn't find the wiki definition for input '" . $input->get_object->get_name() . "' in protocol " . $protocol->get_object->get_name() . " even though everything validated", "error";
          next;
        }
        my $cv = $wiki_term->{'cv'};
        my $term = $wiki_term->{'term'};
        $cv = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
        log_error "Updating type of input " . $input->get_object->get_heading . " [" . $input->get_object->get_name . "] to $cv:$term.", "debug";
        $input->get_object->set_type(new ModENCODE::Chado::CVTerm({
              'name' => $term,
              'cv' => new ModENCODE::Chado::CV({
                  'name' => $cv,
                }),
            })
        );
      }

      # OUTPUTS
      # Fail if there's more than one unnamed output in the SDRF
      @anonymous_data = grep { $_->is_anonymous() } $applied_protocol->get_output_data(1);
      if (scalar(grep { !defined($_->get_name()) || length($_->get_name()) <= 0 } $applied_protocol->get_output_data(1)) - scalar(@anonymous_data) > 1) {
        log_error "Cannot have more than one un-named output parameter (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } $applied_protocol->get_output_data(1)) . ") for protocol " . $protocol->get_object->get_name() . " in the SDRF.";
        $success = 0;
        next;
      }

      my @anonymous_implied_by_wiki = me_array_subtract(
        [grep { $_ } map { $_->get_name() } $applied_protocol->get_output_data(1)],
        [grep { $_ } map { $_->{'name'} } @wiki_output_definitions]
      );

      # Really special case where there's a single _extra_ anonymous datum implied by the wiki (type but no name)
      # AND no unnamed (anonymous_data) column in the SDRF AND named columns in the SDRF so an anonymous datum
      # was not automatically created
      if (
        # No unnamed columns in SDRF
        scalar(@anonymous_data) == 0
        && 
        # Only one extra type in wiki
        (scalar(@wiki_output_definitions)-1) == scalar($applied_protocol->get_output_data)
        &&
        # Only one unnamed type in wiki
        scalar(grep { $_->{'name'} eq '' } @wiki_output_definitions) == 1
        &&
        # One remaining named type in the SDRF
        scalar(@anonymous_implied_by_wiki) == 1
      ) {
        my ($missing_type) = grep { $_->{'name'} eq '' } @wiki_output_definitions;
        log_error "Assuming that " . $missing_type->{'cv'} . ":" . $missing_type->{'term'} . " applies to an implied extra output column that is shown named in the SDRF.", "warning";
        use Data::Dumper; print Dumper(map { $_->_DUMP(); } $applied_protocol->get_output_data(1)); exit;
        next;
      }
      # Update the output's type to match the type defined on the wiki
      if (scalar($applied_protocol->get_output_data) == (scalar(@wiki_output_definitions)-1)) {
        # Really special case where there's a single _extra_ anonymous datum implied by the wiki (type but no name)
        # AND no unnamed (anonymous_data) column in the SDRF AND named columns in the SDRF so an anonymous datum
        # was not automatically created
        my $type = new ModENCODE::Chado::CVTerm({
            'name' => 'anonymous_datum',
            'cv' => new ModENCODE::Chado::CV({
                'name' => 'modencode'
              }),
          });
        my $anonymous_datum = new ModENCODE::Chado::Data({
            'heading' => "Anonymous Extra Datum #" . $anonymous_data_num++,
            'type' => $type,
            'value' => '',
            'anonymous' => 1,
          });
        $applied_protocol->add_output_datum($anonymous_datum);
        log_error "Creating extra anonymous datum " . $anonymous_datum->get_object->get_heading() . " as output for " . $applied_protocol->get_protocol(1)->get_name . ".", "warning";

        # If we added an anonymous output because there were none, then add it as an 
        # input to the next protocol to the right (in SDRF)
        my @potential_next_applied_protocol_slots = @{$experiment->get_applied_protocol_slots->[$applied_protocol_slot_for_this_protocol+1]} if ($applied_protocol_slot_for_this_protocol+1 < scalar(@{$experiment->get_applied_protocol_slots}));
        foreach my $potential_next_applied_protocol (@potential_next_applied_protocol_slots) {
          foreach my $current_output ($applied_protocol->get_output_data) {
            if (
              !scalar($potential_next_applied_protocol->get_input_data) ||
              scalar(grep { $_ == $current_output } $potential_next_applied_protocol->get_input_data)
            ) {
              $potential_next_applied_protocol->add_input_datum($anonymous_datum);
              log_error "Creating extra anonymous datum " . $anonymous_datum->get_object->get_heading() . " as input for " . $potential_next_applied_protocol->get_protocol(1)->get_name . ".", "warning";
              last;
            }
          }
        }
        push @anonymous_data, $anonymous_datum;
      }
      # Fail if the number of outputs in the SDRF is not equal to the number in the wiki
      if (
        scalar(@wiki_output_definitions) != scalar($applied_protocol->get_output_data) - scalar(@anonymous_data) # Everything but an un-needed anonymous one
        &&
        scalar(@wiki_output_definitions) != scalar($applied_protocol->get_output_data) # Everything accounted for
      ) {
        log_error("There are " . (scalar(@wiki_output_definitions) - scalar(@anonymous_implied_by_wiki)) . " output parameters according to the wiki" .
        " (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @wiki_output_definitions) . ")" .
        ", and " . scalar($applied_protocol->get_output_data) . " output parameters in the SDRF" .
        " (" . join(", ", map { $_->get_object->get_heading() . "[" . $_->get_object->get_name() . "]" } $applied_protocol->get_output_data) . ")" .
        " for protocol " . $protocol->get_object->get_name() . ".\n" .
        "Please correct one or the other.");
        $success = 0;
        next;
      }
      # Verify that any named outputs are also named in the $experiment
      # If there's only one unnamed one in the set, see if there's an unnamed type in the wiki for it?
      foreach my $wiki_term (@wiki_output_definitions) {
        next unless (defined($wiki_term->{'name'}) && length($wiki_term->{'name'})); # Allowed to have one unnamed one
        if (!scalar(grep { $_->get_name() eq $wiki_term->{'name'} } $applied_protocol->get_output_data(1))) {
          log_error "Can't find the output [" . $wiki_term->{'name'} . "] in the SDRF for protocol '" . $protocol->get_object->get_name() . "'.";
          $success = 0;
          next;
        }
      }

      foreach my $output ($applied_protocol->get_output_data) {
        my ($wiki_term) = grep { $_->{'name'} eq $output->get_object->get_name } @wiki_output_definitions;
        if (!$wiki_term) {
          # Try to find an anonymous term
          ($wiki_term) = grep { $_->{'name'} =~ /^\s*$/ || !defined($_->{'name'}) } @wiki_output_definitions;
          if (!$wiki_term && $output->get_object->is_anonymous) {
            # An automatically added anonymous datum w/ no type; leave it alone since
            # it will be used to tie together applied protocols
            next;
          } else {
            log_error "Input term of " . $applied_protocol->get_protocol(1)->get_name() . ": " . $output->get_object->get_heading . " [" . $output->get_object->get_name . "] is named in the IDF/SDRF, but not in the wiki.", "warning" if ($output->get_object->get_name());
          }
        }
        if (!$wiki_term) {
          # No anonymous type found on the wiki
          $success = 0;
          log_error "Couldn't find the wiki definition for output '" . $output->get_object->get_name() . "' in protocol " . $protocol->get_object->get_name() . " even though everything validated", "error";
          next;
        }
        my $cv = $wiki_term->{'cv'};
        my $term = $wiki_term->{'term'};
        $cv = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
        log_error "Updating type of output " . $output->get_object->get_heading . " [" . $output->get_object->get_name . "] to $cv:$term.", "debug";
        $output->get_object->set_type(new ModENCODE::Chado::CVTerm({
              'name' => $term,
              'cv' => new ModENCODE::Chado::CV({
                  'name' => $cv,
                }),
            })
        );
      }

    }
  }
  log_error "Done.", "notice", "<";

  if ($protocol_defs_by_url{$experiment_description->get_object->get_value}) {
    my $wiki_experiment_description_def = $protocol_defs_by_url{$experiment_description->get_object->get_value};
    my ($description) = grep { $_->get_name() eq "short description" } @{$wiki_experiment_description_def->get_string_values()};
    $description = $description->get_values()->[0];
    if (!$description) {
      $success = 0;
      log_error "No experiment description found on wiki page at URL " . $experiment_description->get_object->get_value . ".", "error";
    } else {
      my $dbxref = new ModENCODE::Chado::DBXref({
          'db' => new ModENCODE::Chado::DB({
              'name' => 'ModencodeWiki'
            }),
          'accession' => $experiment_description->get_object->get_value,
        });
      $experiment_description->get_object->set_termsource($dbxref);
      $experiment_description->get_object->set_value($description);
      log_error "Setting experiment description from wiki.", "notice";

      my %extra_experiment_attrs = ("assay" => "Assay Type", "data_type" => "Data Type");
      foreach my $attr_name (keys(%extra_experiment_attrs)) {
        my $attr_title = $extra_experiment_attrs{$attr_name};
        my ($attr_value) = grep { $_->get_name() eq $attr_name } @{$wiki_experiment_description_def->get_string_values()};
        $attr_value = $attr_value->get_values()->[0];
        if (!$attr_value) {
          $success = 0;
          log_error "No $attr_title specified on experiment description page at URL " . $experiment_description->get_object->get_value . ".", "error";
        } else {
          my $attr_prop = new ModENCODE::Chado::ExperimentProp({
              'experiment' => $experiment,
              'value' => $attr_value,
              'name' => $attr_title,
              'type' => new ModENCODE::Chado::CVTerm({'name' => 'string', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
              'dbxref' => $dbxref,
            });
          $experiment->add_property($attr_prop);
        }
      }
    }
  } else {
    log_error "No experiment description page found on wiki at URL " . $experiment_description->get_object->get_value . ".", "error";
    $success = 0;
  }

  return $success;
}

sub me_array_subtract {
  # minuend - subtrahend = difference
  my ($minuend_array, $subtrahend_array) = @_;
  my @difference = ();
  foreach my $minuend (@$minuend_array) {
    push(@difference, $minuend) unless scalar(grep { $minuend eq $_ } @$subtrahend_array);
  }
  return @difference;
}


1;


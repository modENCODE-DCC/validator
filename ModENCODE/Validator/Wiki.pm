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
use ModENCODE::Validator::CVHandler;
use HTML::Entities ();
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;

my %protocol_defs_by_name       :ATTR( :default<undef> );
my %protocol_defs_by_url        :ATTR( :default<undef> );
my %termsources                 :ATTR( :name<termsources> );

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

sub merge {
  my ($self, $experiment) = @_;
  #$experiment = $experiment->clone();
  my $anonymous_data_num = 0;
  log_error "(Re)validating experiment vs. wiki:", "notice", ">";
  $self->validate($experiment) or croak "Can't merge wiki data if it doesn't validate!"; # Cache all the protocol definitions and stuff if they aren't already
  log_error "Done.", "notice", "<";

  log_error "Adding types from the wiki to input and output parameters.", "notice", ">";
  #foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
  my $all_applied_protocol_slots = $experiment->get_applied_protocol_slots();
  for (my $i = 0; $i < scalar(@$all_applied_protocol_slots); $i++) {
    my $applied_protocol_slots = $all_applied_protocol_slots->[$i];
    my $potential_next_applied_protocol_slots = $all_applied_protocol_slots->[$i+1] if ($i+1 < scalar(@$all_applied_protocol_slots));
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
            log_error "input term of " . $applied_protocol->get_protocol()->get_name() . "'" . $input_datum->get_name() . "' is named in the IDF/SDRF, but not in the wiki.", "warning" if ($input_datum->get_name());
          }
        }
        if (!$wiki_input_def) {
          croak "Couldn't find the wiki definition for input '" . $input_datum->get_name() . "' in protocol " . $protocol->get_name() . " even though everything validated";
        }
        my $cv = $wiki_input_def->{'cv'};
        my $term = $wiki_input_def->{'term'};
        my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
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
      if (scalar(@{$applied_protocol->get_output_data()}) == (scalar(@$output_type_defs_terms)-1)) {
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
            'anonymous' => 1,
          });
        $applied_protocol->add_output_datum($anonymous_datum);
        log_error "Creating extra anonymous datum " . $anonymous_datum->get_heading() . " as output for " . $applied_protocol->get_protocol()->get_name() . ".", "warning";
        my @next_applied_protocols;
        if ($potential_next_applied_protocol_slots) {
          foreach my $potential_next_applied_protocol (@$potential_next_applied_protocol_slots) {
            foreach my $current_output_datum (@{$applied_protocol->get_output_data()}) {
              # TODO: Make data be the same in-memory REF here so we don't have to check the contents of the datums
              if (
                !scalar(@{$potential_next_applied_protocol->get_input_data()}) ||
                scalar(grep { 
                  $_->get_name() eq $current_output_datum->get_name() &&
                  $_->get_heading() eq $current_output_datum->get_heading() &&
                  $_->get_value() eq $current_output_datum->get_value()
                  } @{$potential_next_applied_protocol->get_input_data()})
              ) {
                $potential_next_applied_protocol->add_input_datum($anonymous_datum);
                log_error "Creating extra anonymous datum " . $anonymous_datum->get_heading() . " as input for " . $potential_next_applied_protocol->get_protocol()->get_name() . ".", "warning";
                last;
              }
            }
          }
        }
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
            log_error "output term " . $applied_protocol->get_protocol()->get_name() . "'" . $output_datum->get_name() . "' is named in the IDF/SDRF, but not in the wiki.", "warning" if ($output_datum->get_name());
          }
        }
        if (!$wiki_output_def) {
          croak "Couldn't find the wiki definition for output '" . $output_datum->get_name() . "' in protocol " . $protocol->get_name() . " even though everything validated";
        }
        my $cv = $wiki_output_def->{'cv'};
        my $term = $wiki_output_def->{'term'};
        my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
        log_error "Setting type of anonymous datum " . $output_datum->get_heading() . " to $canonical_cvname:$term", "notice" if ($output_datum->is_anonymous());
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
  my @unique_protocols;
  my $col = 0;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      unless (grep { $_ == $protocol } @unique_protocols) {
        push @unique_protocols, $protocol
      }
    }
  }

  foreach my $protocol (@unique_protocols) {
    my $protocol_name = $protocol->get_name();
    my $protocol_url = $protocol->get_description();
    my $protocol_def = (defined($protocol_defs_by_url{ident $self}->{$protocol_url}) ? $protocol_defs_by_url{ident $self}->{$protocol_url} : $protocol_defs_by_name{ident $self}->{$protocol_name});
    my $protocol_version = $protocol_def->get_version();

    next unless $protocol_url =~ m/^\s*http:\/\//;

    $protocol->set_version($protocol_version) if length($protocol_version);
    croak "How did this experiment manage to validate with a wiki-less protocol?!" unless $protocol_def;
    # Protocol description
    my $protocol_url_attr = new ModENCODE::Chado::Attribute({
        'heading' => 'Protocol URL',
        'value' => $protocol_url,
        'type' => new ModENCODE::Chado::CVTerm({
            'name' => 'anyURI',
            'cv' => new ModENCODE::Chado::CV({
                'name' => 'xsd',
              }),
          }),
      });
    $protocol->add_attribute($protocol_url_attr);
    my ($protocol_description) = grep { $_->get_name() =~ /^\s*short *descriptions?$/i } @{$protocol_def->get_string_values()};
    if ($protocol_description) {
      $protocol_description = $protocol_description->get_values()->[0];
      if ($protocol_description =~ /^\s*$/) {
	  log_error "Short Description is empty for protocol '$protocol_name' found at $protocol_url", "error"; 
      } else {
	  $protocol->set_description($protocol_description);
      }
    } else {
      log_error "No description for protocol $protocol_name found at $protocol_url. You must have a description for each protocol.", "error";
      $protocol->set_description("Please see: " . $protocol_url);
    }
    # Protocol type
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
            'type' => new ModENCODE::Chado::CVTerm({
                'name' => 'string',
                'cv' => new ModENCODE::Chado::CV({
                    'name' => 'xsd',
                  }),
              }),
          });
        # If this field has controlled vocab(s), create a CVTerm for each value
        if (scalar(@{$wiki_protocol_attr->get_types()})) {
          my ($name, $cv, $term) = (undef, split(/:/, $value));
          if (!defined($term)) {
            $term = $cv;
            $cv = $wiki_protocol_attr->get_types()->[0];
          }
          # Set the type_id of the attribute to this term
          my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
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
          # Set the value to the whole string_value (can't split on commas if there's no types)
          my ($str_value) = grep { $_->get_name() eq $wiki_protocol_attr->get_name() } @{$protocol_def->get_string_values()};
          $value = $str_value->get_values()->[0];
          $protocol_attr->set_value($value);
        }
        $protocol->add_attribute($protocol_attr);
        $rank++;
      }
    }
  }


  my ($experiment_description) = grep { $_->get_name() eq "Experiment Description" } @{$experiment->get_properties()};
  if ($protocol_defs_by_url{ident $self}->{$experiment_description->get_value()}) {
    my $wiki_experiment_description_def = $protocol_defs_by_url{ident $self}->{$experiment_description->get_value()};
    my ($description) = grep { $_->get_name() eq "short description" } @{$wiki_experiment_description_def->get_string_values()};
    $description = $description->get_values()->[0];
    $experiment_description->set_value($description);
    log_error "Setting experiment description from wiki.", "notice";
  }

  log_error "Done.", "notice", "<";
  return $experiment;
}

sub validate {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone(); # Don't do anything to change the experiment passed in
  my $success = 1;

  # Get soap client
  my $soap_client = SOAP::Lite->service(ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'));
  $soap_client->serializer->envprefix('SOAP-ENV');
  $soap_client->serializer->encprefix('SOAP-ENC');
  $soap_client->serializer->soapversion('1.1');

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

  # Tack on the experiment description
  my ($experiment_description) = grep { $_->get_name() eq "Experiment Description" } @{$experiment->get_properties()};
  push @unique_protocol_descriptions, $experiment_description->get_value();

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
      next unless $protocol_description =~ m/^\s*http:\/\//;
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
      if (!$formdata->get_is_complete()) {
	  log_error "\n", "notice", ".";
	  log_error "Required fields are missing from the protocol wiki page at $protocol_description"; 
	  $success = 0;
      }
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
            my ($cv, $term, $name) = ModENCODE::Config::get_cvhandler()->parse_term($value);
            if (!defined($cv)) { $cv = $wiki_protocol_attr->get_types()->[0]; }
            if (!ModENCODE::Config::get_cvhandler()->is_valid_term($cv, $term)) {
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
      if (!$wiki_protocol_type_def) {
	  log_error "No protocol type defined in the wiki for '" . $protocol->get_name() . "'", "error";
	  $success = 0;
	  next;
      }
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
        my ($idf_type_cv, $idf_type_term, undef) = ModENCODE::Config::get_cvhandler()->parse_term($idf_protocol_type->get_value());
        if (!$idf_type_cv) { $idf_type_cv = $idf_protocol_type->get_termsource()->get_db()->get_name(); }
        if (!ModENCODE::Config::get_cvhandler()->get_cv_by_name($idf_type_cv)) {
          my $idf_type_url = $idf_protocol_type->get_termsource()->get_db()->get_url();
          my $idf_type_url_type = $idf_protocol_type->get_termsource()->get_db()->get_description();
          ModENCODE::Config::get_cvhandler()->add_cv($idf_type_cv, $idf_type_url, $idf_type_url_type);
        }
        if (!ModENCODE::Config::get_cvhandler()->get_cv_by_name($idf_type_cv)) {
          log_error "Could not find a canonical URL for the controlled vocabulary $idf_type_cv when validating term " . $idf_protocol_type->get_value() . ".";
          $success = 0;
          next;
        }
        my $idf_type_cv = ModENCODE::Config::get_cvhandler()->get_cv_by_name($idf_type_cv)->{'names'}->[0];
        my $valid = 0;
        for (my $i = 0; $i < @wiki_protocol_types; $i++) {
          my $wiki_protocol_type = $wiki_protocol_types[$i];
          my ($cv, $term, $name) = ModENCODE::Config::get_cvhandler()->parse_term($wiki_protocol_type);
          if (!defined($cv)) { $cv = $wiki_protocol_type_def->get_types()->[0]; }
          my $cv = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv)->{'names'}->[0];
#          if ($cv eq $idf_type_cv && $term eq $idf_type_term) {
          if (lc($cv) eq lc($idf_type_cv) && $term eq $idf_type_term) {
            $valid = 1;
            last;
          }
        }
        if (!$valid) {
          log_error "The protocol type $idf_type_cv:$idf_type_term defined in the IDF does not match the protocol type defined in the wiki for '" . $protocol->get_name() . "'.";
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
      # Really special case where there's a single _extra_ anonymous datum implied by the wiki (type but no name)
      # AND no unnamed (anonymous_data) column in the SDRF AND named columns in the SDRF so an anonymous datum
      # was not automatically created
      if (
        # No unnamed columns in SDRF
        scalar(@anonymous_data) == 0
        && 
        # Only one extra type in wiki
        (scalar(@$input_type_defs_terms)-1) == scalar(@{$applied_protocol->get_input_data()})
        &&
        # Only one unnamed type in wiki
        scalar(grep { $_->{'name'} eq '' } @$input_type_defs_terms) == 1
      ) {
        my ($missing_type) = grep { $_->{'name'} eq '' } @$input_type_defs_terms;
        log_error "Assuming that " . $missing_type->{'cv'} . ":" . $missing_type->{'term'} . " applies to an implied extra input column that is not shown in the SDRF.", "warning";
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
      # Really special case where there's a single _extra_ anonymous datum implied by the wiki (type but no name)
      # AND no unnamed (anonymous_data) column in the SDRF AND named columns in the SDRF so an anonymous datum
      # was not automatically created
      if (
        # No unnamed columns in SDRF
        scalar(@anonymous_data) == 0
        && 
        # Only one extra type in wiki
        (scalar(@$output_type_defs_terms)-1) == scalar(@{$applied_protocol->get_output_data()})
        &&
        # Only one unnamed type in wiki
        scalar(grep { $_->{'name'} eq '' } @$output_type_defs_terms) == 1
      ) {
        my ($missing_type) = grep { $_->{'name'} eq '' } @$output_type_defs_terms;
        log_error "Assuming that " . $missing_type->{'cv'} . ":" . $missing_type->{'term'} . " applies to an implied extra output column that is not shown in the SDRF.", "warning";
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

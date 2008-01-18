package ModENCODE::Validator::Wiki;

use strict;
use Class::Std;
use Carp qw(croak carp);
use SOAP::Lite;# +trace => qw(debug);
use LWP::UserAgent;
use ModENCODE::Validator::Wiki::FormData;
use ModENCODE::Validator::Wiki::FormValues;
use ModENCODE::Validator::Wiki::LoginResult;
use HTML::Entities ();
use URI::Escape ();
use GO::Parser;

my %protocol_defs_by_name       :ATTR( :default<{}> );
my %protocol_defs_by_url        :ATTR( :default<{}> );

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

  # Get wiki protocol data names and/or URLs
  my %protocols;
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

  # Fetch protocol descriptions from wiki based on protocol name
  print STDERR "  Fetching protocol definitions from the wiki...\n";
  my %protocol_defs_by_name;
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
  my %protocol_defs_by_url;
  foreach my $protocol_description (@unique_protocol_descriptions) {
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
    #print "Got protocol data: " . $formdata->to_string() . "\n";
  }
  print STDERR "    Done.\n";


  my %cv_name_mappings; # = { $wiki_cv => { 'idf_cv' => $idf_cv, 'url' => $url.obo, 'urltype' => $OWLorOBOorURL }
  my %validated_cvterms; # = { 'cv' => 'term' => 1/0 }
  # Validate wiki data vs. experiment data passed in
  print STDERR "  Verifying IDF protocols against wiki...\n";
  print STDERR "    Validating wiki CV terms...\n";
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      my $wiki_protocol_def = $protocol_defs_by_url{ident $self}->{$protocol->get_description()};
      $wiki_protocol_def = $protocol_defs_by_name{ident $self}->{$protocol->get_name()} unless $wiki_protocol_def;
      if (!$wiki_protocol_def) {
        croak "Couldn't find definition for protocol '" . $protocol->get_name() . "' with wiki-link '" . $protocol->get_description() . "'";
      }
      # First, any wiki field with a CV needs to be validated
      my $ua = new LWP::UserAgent();
      foreach my $wiki_protocol_attr (@{$wiki_protocol_def->get_values()}) {
        if (scalar(@{$wiki_protocol_attr->get_types()}) && scalar(@{$wiki_protocol_attr->get_values()})) {
          foreach my $value (@{$wiki_protocol_attr->get_values()}) {
            my ($name, $cv, $term) = (undef, split(/:/, $value));
            if (!defined($term)) {
              $term = $cv;
              $cv = $wiki_protocol_attr->get_types()->[0];
            }
            ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
            $term =~ s/^\s*|\s*$//g;
            if (defined($validated_cvterms{$cv}->{$term})) {
              next; # Already validated (or not, as the case may be)
            } else {
              if (!$cv_name_mappings{$cv}->{'url'}) {
                # Fetch the canonical URL from the wiki service
                my $res = $ua->request(new HTTP::Request('GET' => 'http://wiki.modencode.org/project/extensions/DBFields/DBFieldsCVTerm.php?get_canonical_url=' . URI::Escape::uri_escape($cv)));
                croak "Couldn't connect to canonical URL source: " . $res->status_line unless $res->is_success;
                ($cv_name_mappings{$cv}->{'url'}) = ($res->content =~ m/<canonical_url>\s*(.*)\s*<\/canonical_url>/);
                ($cv_name_mappings{$cv}->{'urltype'}) = ($res->content =~ m/<canonical_url_type>\s*(.*)\s*<\/canonical_url_type>/);
                croak "Didn't get canonical URL info for $cv" unless length($cv_name_mappings{$cv}->{'url'}) && length($cv_name_mappings{$cv}->{'urltype'});
              }
              my $filename = $cv_name_mappings{$cv}->{'url'} . "." . $cv_name_mappings{$cv}->{'urltype'};
              $filename =~ s/\//!/g;
              $filename = "ontology_cache/$filename";
              if (!(-r $filename)) {
                if ($cv_name_mappings{$cv}->{'urltype'} ne "URL") {
                  # Fetch and cache OBO/OWL file
                  carp "Fetching ontology from " . $cv_name_mappings{$cv}->{'url'};
                  my $res = $ua->request(new HTTP::Request('GET' => $cv_name_mappings{$cv}->{'url'}));
                  croak "Couldn't fetch canonical source file" . $cv_name_mappings{$cv}->{'url'} . ", and no cached copy found: " . $res->status_line unless $res->is_success;
                  open FH, ">", $filename or croak "Couldn't open ontology cache file $filename for writing";
                  print FH $res->content;
                  close FH;
                } else {
                  # Just check to see if the URL exists
                  my $url = $cv_name_mappings{$cv}->{'url'} . $term;
                  my $res = $ua->request(new HTTP::Request('GET' => $url));
                  if ($res->is_success) {
                    print STDERR "$cv.$term is a valid term!\n";
                    $validated_cvterms{$cv}->{$term} = 1;
                  } else {
                    print STDERR "Couldn't verify cvterm with URL $url: " . $res->status_line;
                    $success = 0;
                    $validated_cvterms{$cv}->{$term} = 0;
                  }
                  next;
                }
              }
              # Parse OBO/OWL file
              if (!$cv_name_mappings{$cv}->{'graph_nodes'}) {
                my $parser;
                if ($cv_name_mappings{$cv}->{'urltype'} =~ /^OWL$/i) {
                  croak "Can't parse OWL files yet, sorry. Please update your IDF to point to an OBO file.";
                } elsif ($cv_name_mappings{$cv}->{'urltype'} =~ /^OBO$/i) {
                  $parser = new GO::Parser({
                      'format' => 'obo_text',
                      'handler' => 'obj',
                    });
                } else {
                  croak "Cannot find a parser for the CV at URL: '" . $cv_name_mappings{$cv}->{'url'} . "' of type: '" . $cv_name_mappings{$cv}->{'urltype'} . "'";
                }
                $parser->parse($filename);
                my $graph = $parser->handler->graph or croak "Cannot parse '" . $filename . "' using " . ref($parser);
                $cv_name_mappings{$cv}->{'graph_nodes'} = $graph->get_all_nodes;
              }
              # See if OBO/OWL file contains our term
              if (scalar(grep { $_->name =~ m/:?\Q$term\E$/ || $_->acc =~ m/:\Q$term\E$/ }  @{$cv_name_mappings{$cv}->{'graph_nodes'}})) {
                $validated_cvterms{$cv}->{$term} = 1;
              } else {
                print STDERR "Couldn't find cvterm '$cv.$term' in ontology file '" . $cv_name_mappings{$cv}->{'url'} . "\n";
                $success = 0;
                $validated_cvterms{$cv}->{$term} = 0;
              }
            }
          }
        }
      }
      # Second, special fields need to be dealt with:
      # * "input type" and "output type" are parameter definitions, and need to be validated against the IDF
      # definitions of the same and against the actual uses of them in the SDRF
    }
  }
  print STDERR "      Done.\n";
  print STDERR "    Verifying that IDF controlled vocabulary match SDRF controlled vocabulary.\n";
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

      # Fail if there's more than one unnamed input in the SDRF
      my @anonymous_data = grep { $_->is_anonymous() } @{$applied_protocol->get_input_data()};
      if (scalar(grep { !defined($_->get_name()) || length($_->get_name()) <= 0 } @{$applied_protocol->get_input_data()}) - scalar(@anonymous_data) > 1) {
        print STDERR "Cannot have more than one un-named input parameter (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_input_data()}) . ") for protocol " . $protocol->get_name() . " in the SDRF.\n";
        $success = 0;
        next;
      }
      # Fail if there's more than one unnamed input in the wiki
      if (scalar(grep { !defined($_->{'name'}) || length($_->{'name'}) <= 0 } @$input_type_defs_terms) > 1) {
        print STDERR "Cannot have more than one un-named input parameter (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$input_type_defs_terms) . ") for protocol " . $protocol->get_name() . " in the wiki.\n";
        $success = 0;
        next;
      }
      # Fail if the number of inputs in the SDRF is not equal to the number in the wiki
      if (
        scalar(@$input_type_defs_terms) != scalar(@{$applied_protocol->get_input_data()}) - scalar(@anonymous_data) # Everything but an un-needed anonymous one
        &&
        scalar(@$input_type_defs_terms) != scalar(@{$applied_protocol->get_input_data()}) # Everything accounted for
      ) {
        print STDERR "There are " . scalar(@$input_type_defs_terms) . " input parameters according to the wiki";
        print STDERR " (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$input_type_defs_terms) . ")";
        print STDERR ", and " . scalar(@{$applied_protocol->get_input_data()}) . " input parameters in the SDRF";
        print STDERR " (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_input_data()}) . ")";
        print STDERR " for protocol " . $protocol->get_name() . ".\n";
        print STDERR "Please correct one or the other.\n";
        $success = 0;
        next;
      }
      # Verify that any named inputs are also named in the $experiment
      # If there's only one unnamed one in the set, see if there's an unnamed type in the wiki for it?
      foreach my $wiki_term (@$input_type_defs_terms) {
        next unless (defined($wiki_term->{'name'}) && length($wiki_term->{'name'})); # Allowed to have one unnamed one
        if (!scalar(grep { $_->get_name() eq $wiki_term->{'name'} } @{$applied_protocol->get_input_data()})) {
          print STDERR "Can't find the input [" . $wiki_term->{'name'} . "] in the SDRF for protocol " . $protocol->get_name() . "\n";
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
        print STDERR "Cannot have more than one un-named output parameter (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_output_data()}) . ") for protocol " . $protocol->get_name() . " in the SDRF.\n";
        $success = 0;
        next;
      }
      # Fail if there's more than one unnamed output in the wiki
      if (scalar(grep { !defined($_->{'name'}) || length($_->{'name'}) <= 0 } @$output_type_defs_terms) > 1) {
        print STDERR "Cannot have more than one un-named output parameter (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$output_type_defs_terms) . ") for protocol " . $protocol->get_name() . " in the wiki.\n";
        $success = 0;
        next;
      }
      # Fail if the number of outputs in the SDRF is not equal to the number in the wiki
      if (
        scalar(@$output_type_defs_terms) != scalar(@{$applied_protocol->get_output_data()}) - scalar(@anonymous_data) # Everything but an un-needed anonymous one
        &&
        scalar(@$output_type_defs_terms) != scalar(@{$applied_protocol->get_output_data()}) # Everything accounted for
      ) {
        print STDERR "There are " . scalar(@$output_type_defs_terms) . " output parameters according to the wiki";
        print STDERR " (" . join(", ", map { $_->{'term'} . "[" . $_->{'name'} . "]" } @$output_type_defs_terms) . ")";
        print STDERR ", and " . scalar(@{$applied_protocol->get_output_data()}) . " output parameters in the SDRF";
        print STDERR " (" . join(", ", map { $_->get_heading() . "[" . $_->get_name() . "]" } @{$applied_protocol->get_output_data()}) . ")";
        print STDERR " for protocol " . $protocol->get_name() . ".\n";
        print STDERR "Please correct one or the other.\n";
        $success = 0;
        next;
      }
      # Verify that any named outputs are also named in the $experiment
      # If there's only one unnamed one in the set, see if there's an unnamed type in the wiki for it?
      foreach my $wiki_term (@$output_type_defs_terms) {
        next unless (defined($wiki_term->{'name'}) && length($wiki_term->{'name'})); # Allowed to have one unnamed one
        if (!scalar(grep { $_->get_name() eq $wiki_term->{'name'} } @{$applied_protocol->get_output_data()})) {
          print STDERR "Can't find the output [" . $wiki_term->{'name'} . "] in the SDRF for protocol " . $protocol->get_name() . "\n";
          $success = 0;
          next;
        }
      }

      #print $experiment->to_string();
      #my ($protocol_parameters) = grep { $_->get_heading() =~ m/^\s*Protocol Parameters?\s*$/ } @{$idf_protocol->get_attributes()};
      #print Dumper($input_type_defs);
    }
  }
  print STDERR "      Done.\n";
  print STDERR "    Done.\n";

  return $success;
}

1;

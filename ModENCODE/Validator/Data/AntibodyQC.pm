package ModENCODE::Validator::Data::AntibodyQC;

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
use ModENCODE::Validator::Wiki::URLValidator;
use Data::Dumper;

my %seen_urls   :ATTR( :default<{}> );

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

  log_error "Checking antibody QC status.", "notice", ">";

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

#  ModENCODE::ErrorHandler::set_loglevel(ModENCODE::ErrorHandler::DEBUG);
  my %pages;
  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    my ($name, $version) = ($datum->get_object->get_value() =~ /^(.*?)(?:&oldid=(\d*))?$/);
    $name =~ s/_/ /g;

    if (!defined($pages{"QC".$datum->get_object->get_value()})) {
      my $soap_data = SOAP::Data->name('query' => \SOAP::Data->value(
          SOAP::Data->name('name' => HTML::Entities::encode("QC".$name))->type('xsd:string'),
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
          my $qcinfo = {};
          foreach my $formvalues (@{$result_data->get_values()}) {
            my @keys = map { $_ =~ s/^\[|\]$//g; $_ } ($formvalues->get_name() =~ m/(^[^\[]+|\[[^\]]+\])/g);
            my $h = $qcinfo;
            my ($lasth, $lastkey);
            foreach my $key (@keys) {
              $lastkey = $key;
              $lasth = $h;
              $h->{$key} = {} unless defined($h->{$key});
              $h = $h->{$key};
            }
            $lasth->{$lastkey} = join(", ", @{$formvalues->get_values()});
          }

          if ($qcinfo->{"antibody_type"} eq "histone_modification") {
            $success &&= $self->check_histone_antibody($datum, $qcinfo);
          } else {
            $success &&= $self->check_generic_antibody($datum, $qcinfo);
          }

          $pages{$datum->get_object->get_value()} = $success;
        }
      }
    }
    if (!($pages{$datum->get_object->get_value()})) {
      if ($datum->get_object->get_value()) {
#        $success = 0; # XXX: TODO: Uncomment this line; this is just during the grace period!
        log_error "No valid QC info for " . $datum->get_object->get_value() . " in the " . $datum->get_object->get_heading() . " [" . $datum->get_object->get_name() . "] field with any attribute columns in the " . ref($self) . " validator.", "error";
      } else {
        log_error "Couldn't get QC info for the empty value in the " . $datum->get_object->get_heading() . " [" . $datum->get_object->get_name() . "] field with any attribute columns in the " . ref($self) . " validator.", "warning";
      }
    }
  }
  ModENCODE::ErrorHandler::set_loglevel(ModENCODE::ErrorHandler::NOTICE);

  return $success;
}

sub check_generic_antibody {
  my ($self, $datum, $qcinfo) = @_;

  my $success = 0;

  # Requirements:
  # One of either: Western or Immunofluorescence
  # If Western, then:
  # * Band size OK? Two images provided?
  # * Knockdown
  # ** RNAi
  # ** siRNA
  # ** Mutation
  # *** Band size OK, two images, strain/reagent page
  # * IP+Mass Spec
  # * IP+Multiple Antibodies
  # * IP+Epitope-tagged protein
  #print Dumper($qcinfo);

  my @check_urls;
  log_error "Beginning generic antibody QC check for " . $datum->get_object->get_value . ".", "notice", ">";
  # Western
  if ($qcinfo->{'immunoblot'}) {
    my $okay_immunoblot = 0;
    # Find a valid Western
    log_error "Looking for valid immunoblot/Western QC info.", "notice", ">";
    foreach my $ib_validation (values(%{$qcinfo->{'immunoblot'}})) {
      unless ($ib_validation->{'band_size_ok'} eq "yes") { log_error "Band size not ok.", "warning"; next; }
      unless ($ib_validation->{'band_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image URL not a wiki URL.", "warning"; next; }
      unless ($ib_validation->{'band_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image replicate URL not a wiki URL.", "warning"; next; }
      $okay_immunoblot = 1;
      push @check_urls, $ib_validation->{'band_image'}, $ib_validation->{'band_image_replicate'};
      last;
    }
    if ($okay_immunoblot) {
      log_error "Found a successful immunoblot validation.", "notice";
      # Western knockdown by RNAi
      if ($qcinfo->{'western_knockdown_rnai'}) {
        log_error "Looking for valid Knockdown+RNAi secondary assay.", "notice", ">";
        foreach my $ib_knockdown_rnai (values(%{$qcinfo->{'western_knockdown_rnai'}})) {
          unless ($ib_knockdown_rnai->{'band_size_ok'} eq "yes") { log_error "Band size not ok.", "warning"; next; }
          unless ($ib_knockdown_rnai->{'band_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image URL not a wiki URL.", "warning"; next; }
          unless ($ib_knockdown_rnai->{'band_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image replicate URL not a wiki URL.", "warning"; next; }
          unless ($ib_knockdown_rnai->{'rnai_reagent_page'} =~ m|^http://wiki.modencode.org/|) { log_error "RNAi reagent URL not a wiki URL.", "warning"; next; }
          push @check_urls, $ib_knockdown_rnai->{'band_image'}, $ib_knockdown_rnai->{'band_image_replicate'}, $ib_knockdown_rnai->{'rnai_reagent_page'};
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Western + RNAi Knockdown)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Western + RNAi Knockdown), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid Knockdown+RNAi secondary assay found.", "warning", "<";
      }
      # Western knockdown by siRNA
      if ($qcinfo->{'western_knockdown_sirna'}) {
        log_error "Looking for valid Knockdown+siRNA secondary assay.", "notice", ">";
        foreach my $ib_knockdown_sirna (values(%{$qcinfo->{'western_knockdown_sirna'}})) {
          unless ($ib_knockdown_sirna->{'band_size_ok'} eq "yes") { log_error "Band size not ok.", "warning"; next; }
          unless ($ib_knockdown_sirna->{'band_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image URL not a wiki URL.", "warning"; next; }
          unless ($ib_knockdown_sirna->{'band_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image replicate URL not a wiki URL.", "warning"; next; }
          unless ($ib_knockdown_sirna->{'sirna_reagent_page'} =~ m|^http://wiki.modencode.org/|) { log_error "siRNA reagent URL not a wiki URL.", "warning"; next; }
          push @check_urls, $ib_knockdown_sirna->{'band_image'}, $ib_knockdown_sirna->{'band_image_replicate'}, $ib_knockdown_sirna->{'sirna_reagent_page'};
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Western + siRNA Knockdown)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Western + siRNA Knockdown), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid Knockdown+siRNA secondary assay found.", "warning", "<";
      }
      # Western knockdown by Mutant
      if ($qcinfo->{'western_knockdown_mutant'}) {
        log_error "Looking for valid Knockdown+mutant secondary assay.", "notice", ">";
        foreach my $ib_knockdown_mutant (values(%{$qcinfo->{'western_knockdown_mutant'}})) {
          unless ($ib_knockdown_mutant->{'band_size_ok'} eq "yes") { log_error "Band size not ok.", "warning"; next; }
          unless ($ib_knockdown_mutant->{'band_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image URL not a wiki URL.", "warning"; next; }
          unless ($ib_knockdown_mutant->{'band_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Band image replicate URL not a wiki URL.", "warning"; next; }
          unless ($ib_knockdown_mutant->{'mutant_strain_page'} =~ m|^http://wiki.modencode.org/|) { log_error "Mutant strain URL not a wiki URL.", "warning"; next; }
          push @check_urls, $ib_knockdown_mutant->{'band_image'}, $ib_knockdown_mutant->{'band_image_replicate'}, $ib_knockdown_mutant->{'mutant_strain_page'};
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Western + Mutant Knockdown)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Western + Mutant Knockdown), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid Knockdown+mutant secondary assay found.", "warning", "<";
      }
      # IP+Mass Spec
      if ($qcinfo->{'ip_mass_spec'}) {
        log_error "Looking for valid IP+Mass Spec secondary assay.", "notice", ">";
        foreach my $ip_mass_spec (values(%{$qcinfo->{'ip_mass_spec'}})) {
          unless ($ip_mass_spec->{'sequences'} =~ m|^http://wiki.modencode.org/|) { log_error "Sequences URL not a wiki URL.", "warning"; next; }
          unless (length($ip_mass_spec->{'results'}) > 0) { log_error "No result summary provided.", "warning"; next; }
          push @check_urls, $ip_mass_spec->{'sequences'};
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Western + IP+Mass Spec)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Western + IP+Mass Spec), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid IP+Mass Spec secondary assay found.", "warning", "<";
      }
      # Multiple antibodies
      if ($qcinfo->{'ip_multiple_antibodies'}) {
        log_error "Looking for valid IP+Multiple Antibodies secondary assay.", "notice", ">";
        foreach my $ip_multiple_antibodies (values(%{$qcinfo->{'ip_multiple_antibodies'}})) {
          unless ($ip_multiple_antibodies->{'overlap_ok'} eq "yes") { log_error "Band overlap not ok.", "warning"; next; }
          unless ($ip_multiple_antibodies->{'qpcr_verified'} eq "yes") { log_error "IP+Mass Spec not qPCR-verified.", "warning"; next; }
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Western + IP+Multiple Antibodies)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Western + IP+Multiple Antibodies), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid IP+Multiple Antibodies secondary assay found.", "warning", "<";
      }
      # Epitope-tagged protein
      if ($qcinfo->{'ip_epitope-tagged_protein'}) {
        log_error "Looking for valid IP+Epitope-Tagged Protein secondary assay.", "notice", ">";
        foreach my $ip_epitope_tagged (values(%{$qcinfo->{'ip_epitope-tagged_protein'}})) {
          unless ($ip_epitope_tagged->{'overlap_ok'} eq "yes") { log_error "Band overlap not ok.", "warning"; next; }
          unless ($ip_epitope_tagged->{'qpcr_verified'} eq "yes") { log_error "IP+Mass Spec not qPCR-verified.", "warning"; next; }
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Western + IP+Eptitope-Tagged Protein)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Western + IP+Eptitope-Tagged Protein), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid IP+Epitope-Tagged Protein secondary assay found.", "warning", "<";
      }

      log_error "No successful secondary validation found for primary immunoblot assay(s).", "warning", "<";
    } else {
      log_error "No successful immunoblot validation found.", "warning", "<";
    }
  }
  # Immunofluorescence
  if ($qcinfo->{'immunofluorescence'}) {
    my $okay_immunofluorescence = 0;
    # Find a valid Immunofluorescence
    log_error "Looking for valid immunofluorescence QC info.", "notice", ">";
    foreach my $if_validation (values(%{$qcinfo->{'immunofluorescence'}})) {
      unless ($if_validation->{'staining_ok'} eq "yes") { log_error "Staining not ok.", "warning"; next; }
      unless ($if_validation->{'staining_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image URL not a wiki URL.", "warning"; next; }
      unless ($if_validation->{'staining_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image replicate URL not a wiki URL.", "warning"; next; }
      $okay_immunofluorescence = 1;
      push @check_urls, $if_validation->{'staining_image'}, $if_validation->{'staining_image_replicate'};
      last;
    }
    if ($okay_immunofluorescence) {
      log_error "Found a successful immunofluorescence validation.", "notice";
      # Immunofluorescence knockdown by RNAi
      if ($qcinfo->{'immunofluorescence_knockdown_rnai'}) {
        log_error "Looking for valid Knockdown+RNAi secondary assay.", "notice", ">";
        foreach my $if_knockdown_rnai (values(%{$qcinfo->{'immunofluorescence_knockdown_rnai'}})) {
          unless ($if_knockdown_rnai->{'staining_ok'} eq "yes") { log_error "Staining not ok.", "warning"; next; }
          unless (length($if_knockdown_rnai->{'results'}) > 0) { log_error "No result summary provided.", "warning"; next; }
          unless ($if_knockdown_rnai->{'staining_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image URL not a wiki URL.", "warning"; next; }
          unless ($if_knockdown_rnai->{'staining_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image replicate URL not a wiki URL.", "warning"; next; }
          unless ($if_knockdown_rnai->{'rnai_reagent_page'} =~ m|^http://wiki.modencode.org/|) { log_error "RNAi reagent URL not a wiki URL.", "warning"; next; }
          push @check_urls, $if_knockdown_rnai->{'staining_image'}, $if_knockdown_rnai->{'staining_image_replicate'}, $if_knockdown_rnai->{'rnai_reagent_page'};
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Immunofluorescence + RNAi Knockdown)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Immunofluorescence + RNAi Knockdown), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid Knockdown+RNAi secondary assay found.", "warning", "<";
      }
      # Immunofluorescence knockdown by siRNA
      if ($qcinfo->{'immunofluorescence_knockdown_sirna'}) {
        log_error "Looking for valid Knockdown+siRNA secondary assay.", "notice", ">";
        foreach my $if_knockdown_sirna (values(%{$qcinfo->{'immunofluorescence_knockdown_sirna'}})) {
          unless ($if_knockdown_sirna->{'staining_ok'} eq "yes") { log_error "Staining not ok.", "warning"; next; }
          unless (length($if_knockdown_sirna->{'results'}) > 0) { log_error "No result summary provided.", "warning"; next; }
          unless ($if_knockdown_sirna->{'staining_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image URL not a wiki URL.", "warning"; next; }
          unless ($if_knockdown_sirna->{'staining_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image replicate URL not a wiki URL.", "warning"; next; }
          unless ($if_knockdown_sirna->{'sirna_reagent_page'} =~ m|^http://wiki.modencode.org/|) { log_error "siRNA reagent URL not a wiki URL.", "warning"; next; }
          push @check_urls, $if_knockdown_sirna->{'staining_image'}, $if_knockdown_sirna->{'staining_image_replicate'}, $if_knockdown_sirna->{'sirna_reagent_page'};
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Immunofluorescence + siRNA Knockdown)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Immunofluorescence + siRNA Knockdown), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid Knockdown+siRNA secondary assay found.", "warning", "<";
      }
      # Immunofluorescence knockdown by Mutant
      if ($qcinfo->{'immunofluorescence_knockdown_mutant'}) {
        log_error "Looking for valid Knockdown+Mutant secondary assay.", "notice", ">";
        foreach my $if_knockdown_mutant (values(%{$qcinfo->{'immunofluorescence_knockdown_mutant'}})) {
          unless ($if_knockdown_mutant->{'staining_ok'} eq "yes") { log_error "Staining not ok.", "warning"; next; }
          unless (length($if_knockdown_mutant->{'results'}) > 0) { log_error "No result summary provided.", "warning"; next; }
          unless ($if_knockdown_mutant->{'staining_image'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image URL not a wiki URL.", "warning"; next; }
          unless ($if_knockdown_mutant->{'staining_image_replicate'} =~ m|^http://wiki.modencode.org/|) { log_error "Staining image replicate URL not a wiki URL.", "warning"; next; }
          unless ($if_knockdown_mutant->{'mutant_strain_page'} =~ m|^http://wiki.modencode.org/|) { log_error "Mutant reagent URL not a wiki URL.", "warning"; next; }
          push @check_urls, $if_knockdown_mutant->{'staining_image'}, $if_knockdown_mutant->{'staining_image_replicate'}, $if_knockdown_mutant->{'mutant_strain_page'};
          my @missing_urls = $self->check_urls(@check_urls);
          unless (@missing_urls) {
            log_error "Antibody is valid (Immunofluorescence + Mutant Knockdown)!", "notice", "<"; log_error "Done.", "notice", "<";
            $success = 1;
          } else {
            log_error "Antibody QC is filled in (Immunofluorescence + Mutant Knockdown), but provided URLs were not found: " . join(", ", @missing_urls) . ".", "error", "<"; log_error "Done.", "notice", "<";
            $success = 0;
          }
        }
        log_error "No valid Knockdown+Mutant secondary assay found.", "warning", "<";
      }

      log_error "No successful secondary validation found for primary immunofluorescence assay(s).", "warning", "<";
    } else {
      log_error "No successful immunofluorescence validation found.", "warning", "<";
    }
  }

  # Override!
  if ($qcinfo->{'exceptions'}) {
    if ($qcinfo->{'exceptions'}->{'known_good'} eq "yes") {
      unless (length($qcinfo->{'exceptions'}->{'prior_literature'}) > 0) {
        log_error "Antibody marked known good, but no prior literature referenced.", "warning"
      } else {
        if (!$success) {
          log_error "Marking an antibody as good (by prior literature) even though it failed/doesn't have other validation.", "warning";
          $success = 1;
        }
      }
    }
  }

  # Create attributes
  if ($success) {
    # Only necessary if this is going to have worked anyway
    my $qc_antibody_type = new ModENCODE::Chado::CVTerm({
        'name' => 'antibody_qc',
        'cv' => new ModENCODE::Chado::CV({ 'name' => 'modencode' }),
      });
    log_error "Creating attributes to attach to antibody", "notice";
    foreach my $assay (keys(%$qcinfo)) {
      my $rank = 0;
      my @assay_instances = values(%{$qcinfo->{$assay}});
      if (ref($assay_instances[0]) eq 'HASH') {
        foreach my $assay_instance (values(%{$qcinfo->{$assay}})) {
          foreach my $parameter (keys(%{$assay_instance})) {
            my $value = $assay_instance->{$parameter};
            my $attribute = new ModENCODE::Chado::DatumAttribute({
                'heading' => $assay,
                'name' => $parameter,
                'value' => $value,
                'rank' => $rank,
                'type' => $qc_antibody_type,
                'datum' => $datum,
              });
            $datum->get_object->add_attribute($attribute);
          }
        }
      } else {
        foreach my $parameter (keys(%{$qcinfo->{$assay}})) {
          my $assay_instance = $qcinfo->{$assay}->{$parameter};
          my $attribute = new ModENCODE::Chado::DatumAttribute({
              'heading' => $assay,
              'name' => $parameter,
              'value' => $assay_instance,
              'rank' => $rank,
              'type' => $qc_antibody_type,
              'datum' => $datum,
            });
          $datum->get_object->add_attribute($attribute);
        }
      }
      $rank++;
    }
  }

  log_error "Done with generic antibody QC check.", "notice", "<";
  return $success;
}

sub check_urls {
  my ($self, @urls) = @_;
  my $url_validator = new ModENCODE::Validator::Wiki::URLValidator({
      'username' => ModENCODE::Config::get_cfg()->val('wiki', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('wiki', 'password'),
      'domain' => ModENCODE::Config::get_cfg()->val('wiki', 'domain'),
      'wsdl' => ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'),
    });

  my @missing_urls;
  foreach my $url (@urls) {
    if (!defined($seen_urls{ident $self}->{$url})) {
      my $res = $url_validator->get_url($url);
      $seen_urls{ident $self}->{$url} = $res->is_success;
      if ($res->is_success) {
        if ($res->content =~ m/div class="noarticletext"/ || $res->content =~ m/<title>Error<\/title>/) {
          print "NOOOOOOOOOOOOO: $url\n";
          $seen_urls{ident $self}->{$url} = 0;
        }
      }
    }
    push(@missing_urls, $url) unless $seen_urls{ident $self}->{$url};
  }
  return @missing_urls;
}

1;

package ModENCODE::Validator::IDF_SDRF;

use strict;
use Class::Std;
use Carp qw(croak);
use ModENCODE::ErrorHandler qw(log_error);


my %idf_experiment   :ATTR( :name<idf_experiment> );
my %protocols        :ATTR( :name<protocols> );
my %termsources      :ATTR( :name<termsources> );

sub merge {
  my ($self, $sdrf_experiment) = @_;
  $sdrf_experiment = $sdrf_experiment->clone(); # Don't actually change the SDRF that was passed in
  croak "Can't merge IDF & SDRF unless they validated" unless $self->validate($sdrf_experiment);

  # Update IDF experiment properties with full term sources instead of just term source names
  foreach my $experiment_prop (@{$self->get_idf_experiment()->get_properties()}) {
    if ($experiment_prop->get_termsource()) {
      my ($full_termsource) = grep { $_->get_db()->get_name() eq $experiment_prop->get_termsource()->get_db()->get_name() } @{$self->get_termsources()};
      $experiment_prop->get_termsource()->set_db($full_termsource->get_db());
      $experiment_prop->get_termsource()->set_version($full_termsource->get_version());
    }
  }

  # Copy basic experiment attributes from IDF experiment object to SDRF experiment object
  $sdrf_experiment->add_properties($self->get_idf_experiment()->get_properties());
  $sdrf_experiment->set_uniquename($self->get_idf_experiment()->get_uniquename());

  # Update SDRF protocols with additional information from IDF
  my @sdrf_applied_protocols;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    push @sdrf_applied_protocols, (@$applied_protocol_slots);
  }
  my @sdrf_protocols = map { $_->get_protocol() } @sdrf_applied_protocols;;
  # Add any protocol attributes as an attribute (except for Protocol Parameters, which is special)
  foreach my $sdrf_protocol (@sdrf_protocols) {
    my ($idf_protocol) = grep { $_->get_name() eq $sdrf_protocol->get_name() } @{$self->get_protocols()};
    if (length($idf_protocol->get_description())) {
      $sdrf_protocol->set_description($idf_protocol->get_description());
      foreach my $attribute (@{$idf_protocol->get_attributes()}) {
        next if $attribute->get_heading() =~ m/^\s*Protocol *Parameters?/i;
        $sdrf_protocol->add_attribute($attribute);
      }
    }
  }
  # Parameters
  #   Remove any named "inputs" from applied protocols that aren't listed as protocol parameters in the IDF
  foreach my $sdrf_applied_protocol (@sdrf_applied_protocols) {
    my $sdrf_protocol = $sdrf_applied_protocol->get_protocol();
    my ($idf_protocol) = grep { $_->get_name() eq $sdrf_protocol->get_name() } @{$self->get_protocols()};
    my ($parameters) = grep { $_->get_heading() =~ m/^\s*Protocol Parameters?\s*$/ } @{$idf_protocol->get_attributes()};
    my @idf_params; @idf_params = split /;/, $parameters->get_value() if (defined($parameters));
    for (my $i = 0; $i < scalar(@idf_params); $i++) {
      $idf_params[$i] =~ s/^\s*|\s*$//g;
    }
    my @remove_these_data;
    foreach my $datum (@{$sdrf_applied_protocol->get_input_data()}) {
      if (defined($datum->get_name()) && length($datum->get_name())) {
        my @matching_params = grep { $_ eq $datum->get_name() } @idf_params;;
        if (!scalar(@matching_params)) {
          log_error "Removing datum '" . $datum->get_name . "' as input from '" . $sdrf_protocol->get_name() . "'; not found in IDF's Protocol Parameters.", "warning";
          $sdrf_applied_protocol->remove_input_datum($datum);
        }
      }
    }
  }

  # Update SDRF term sources (DBXrefs and their DBs) with information from IDF
  my @sdrf_terms;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      if ($applied_protocol->get_protocol()) {
        if ($applied_protocol->get_protocol()->get_termsource() && $applied_protocol->get_protocol()->get_termsource()->get_db()) {
          push @sdrf_terms, $applied_protocol->get_protocol()->get_termsource();
        }
        foreach my $attribute (@{$applied_protocol->get_protocol->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @sdrf_terms, $attribute->get_termsource();
          }
        }
      }
      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if ($datum->get_termsource() && $datum->get_termsource()->get_db()) {
          push @sdrf_terms, $datum->get_termsource();
        }
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @sdrf_terms, $attribute->get_termsource();
          }
        }
      }
    }
  }
  foreach my $sdrf_term (@sdrf_terms) {
    my ($idf_term) = grep { $_->get_db()->get_name() eq $sdrf_term->get_db()->get_name() } @{$self->get_termsources()};
    $sdrf_term->set_db($idf_term->get_db());
    $sdrf_term->set_version($idf_term->get_version());
  }

  return $sdrf_experiment;
}

sub validate {
  my ($self, $sdrf_experiment) = @_;
  my $success = 1;
  $sdrf_experiment = $sdrf_experiment->clone(); # Don't actually change the SDRF that was passed in
  # Protocols
  #   Get all the protocols from the sdrf_experiment and make sure they exist in the idf
  my @sdrf_protocols;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my @matching_protocols = grep { $_->equals($applied_protocol->get_protocol()) } @sdrf_protocols;
      if (!scalar(@matching_protocols)) {
        push @sdrf_protocols, $applied_protocol->get_protocol();
      }
    }
  }
  my @undefined_protocols;
  foreach my $sdrf_protocol (@sdrf_protocols) {
    next if $sdrf_protocol->get_name() eq "->"; # TODO: Handle -> protocols
    if (!scalar(grep { $_->get_name() eq $sdrf_protocol->get_name() } @{$self->get_protocols()})) {
      push @undefined_protocols, $sdrf_protocol;
    }
  }
  if (scalar(@undefined_protocols)) {
    log_error "The following protocol(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_name() } @undefined_protocols) . "'.";
    $success = 0;
  }
  # Parameters
  #   Make sure all the protocol parameters in the IDF exist in the SDRF and vice versa
  #   Collect all of the parameters (by protocol) used in the SDRF from Protocol Attributes, Data, and Data Attributes
  my %named_fields;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      my $protocol_name = $protocol->get_name();
      $named_fields{$protocol_name} = [] unless defined($named_fields{$protocol_name});
      foreach my $protocol_attribute (@{$protocol->get_attributes()}) {
        if (defined($protocol_attribute->get_name()) && length($protocol_attribute->get_name())) {
          push @{$named_fields{$protocol_name}}, $protocol_attribute->get_name();
        }
      }
      foreach my $datum (@{$applied_protocol->get_input_data()}) {
        if (defined($datum->get_name()) && length($datum->get_name())) {
          push @{$named_fields{$protocol_name}}, $datum->get_name();
        }
        foreach my $datum_attribute (@{$datum->get_attributes()}) {
          if (defined($datum_attribute->get_name()) && length($datum_attribute->get_name())) {
            push @{$named_fields{$protocol_name}}, $datum_attribute->get_name();
          }
        }
      }
    }
  }
  foreach my $idf_protocol (@{$self->get_protocols()}) {
    my ($parameters) = grep { $_->get_heading() =~ m/^\s*Protocol Parameters?\s*$/ } @{$idf_protocol->get_attributes()};
    my @idf_params; @idf_params = split /;/, $parameters->get_value() if (defined($parameters));
    for (my $i = 0; $i < scalar(@idf_params); $i++) {
      $idf_params[$i] =~ s/^\s*|\s*$//g;
    }
    my @sdrf_params = defined($named_fields{$idf_protocol->get_name()}) ? @{$named_fields{$idf_protocol->get_name()}} : ();
    # Make sure all IDF params are in the SDRF
    foreach my $idf_param (@idf_params) {
      my @matching_param = grep { $_ eq $idf_param } @sdrf_params;
      if (!scalar(@matching_param)) {
        log_error "Unable to find the '$idf_param' field in the SDRF even though it is defined in the IDF.";
        $success = 0;
      }
    }
  }
  # Term sources
  #   Collect term source DBXrefs from Protocols, Attributes, Datas
  my @term_source_dbs;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      if ($applied_protocol->get_protocol()) {
        if ($applied_protocol->get_protocol()->get_termsource() && $applied_protocol->get_protocol()->get_termsource()->get_db()) {
          push @term_source_dbs, $applied_protocol->get_protocol()->get_termsource()->get_db();
        }
        foreach my $attribute (@{$applied_protocol->get_protocol->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @term_source_dbs, $attribute->get_termsource()->get_db();
          }
        }
      }
      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if ($datum->get_termsource() && $datum->get_termsource()->get_db()) {
          push @term_source_dbs, $datum->get_termsource()->get_db();
        }
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @term_source_dbs, $attribute->get_termsource()->get_db();
          }
        }
      }
    }
  }
  # Filter to unique DBs
  { my @tmp = @term_source_dbs; @term_source_dbs = (); foreach my $db (@tmp) { if (!scalar(grep { $_->equals($db) } @term_source_dbs)) { push @term_source_dbs, $db; } } }

  my @sdrf_term_sources;
  my @idf_term_sources = map { $_->get_db() } @{$self->get_termsources()};
  foreach my $term_source (@term_source_dbs) {
    my @matching_term_sources = grep { $_->equals($term_source) } @sdrf_term_sources;
    if (!scalar(@matching_term_sources)) {
      push @sdrf_term_sources, $term_source;
    }
  }
  my @undefined_term_sources;
  foreach my $sdrf_term_source (@sdrf_term_sources) {
    if (!scalar(grep { $_->get_name() eq $sdrf_term_source->get_name() } @idf_term_sources)) {
      push @undefined_term_sources, $sdrf_term_source;
    }
  }
  if (scalar(@undefined_term_sources)) {
    log_error "The following term source(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_name() } @undefined_term_sources) . "'.";
    $success = 0;
  }

  return $success;
}

1;

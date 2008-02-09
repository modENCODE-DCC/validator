package ModENCODE::Validator::TermSources;

use strict;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Validator::CVHandler;
use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::DB;
use ModENCODE::ErrorHandler qw(log_error);

my %cvhandler                   :ATTR( :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cvhandler = $args->{'cvhandler'};
  if (ref($cvhandler) ne 'ModENCODE::Validator::CVHandler') {
    croak "Cannot create a ModENCODE::Validator::Wiki without a cvhandler of type ModENCODE::Validator::CVHandler";
  }
  $cvhandler{ident $self} = $cvhandler;
}

sub merge {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  $self->validate($experiment) or croak "Can't merge term sources if it doesn't validate!"; # Cache all the protocol definitions and stuff if they aren't already
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      # Protocol
      if ($protocol->get_termsource()) {
        my ($term, $accession) = $self->get_term_and_accession($protocol->get_termsource(), $protocol->get_name());
        $protocol->get_termsource()->get_db()->set_description(undef); # Remove description as it was just holding the type of ontology file
        $protocol->get_termsource()->set_accession($accession);
      }
      # Protocol attributes
      foreach my $attribute (@{$protocol->get_attributes()}) {
        if ($attribute->get_termsource()) {
          my ($term, $accession) = $self->get_term_and_accession($attribute->get_termsource(), $attribute->get_value());
          $attribute->get_termsource()->get_db()->set_description(undef); # Remove description as it was just holding the type of ontology file
          $attribute->get_termsource()->set_accession($accession);
        }
      }
      # Data
      my @data = (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()});
      foreach my $datum (@data) {
        if ($datum->get_termsource()) {
          my ($term, $accession) = $self->get_term_and_accession($datum->get_termsource, $datum->get_value());
          $datum->get_termsource()->get_db()->set_description(undef); # Remove description as it was just holding the type of ontology file
          $datum->get_termsource()->set_accession($accession);
        }
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_termsource()) {
            my ($term, $accession) = $self->get_term_and_accession($attribute->get_termsource(), $attribute->get_value());
            $attribute->get_termsource()->get_db()->set_description(undef); # Remove description as it was just holding the type of ontology file
            $attribute->get_termsource()->set_accession($accession);
          }
        }
      }
    }
  }

  log_error "Making sure that all CV and DB names are consistent.", "notice", ">";
  # experiment_prop (dbxref, type)
  foreach my $experiment_prop (@{$experiment->get_properties()}) {
    if ($experiment_prop->get_type()) {
      $experiment_prop->get_type()->get_cv()->set_name($cvhandler{ident $self}->get_cv_by_name($experiment_prop->get_type()->get_cv()->get_name())->{'names'}->[0]);
      if ($experiment_prop->get_type->get_dbxref()) {
        $experiment_prop->get_type()->get_dbxref->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($experiment_prop->get_type()->get_dbxref->get_db()->get_name()));
      } else {
        my $dbname = $cvhandler{ident $self}->get_cv_by_name($experiment_prop->get_type()->get_dbxref->get_db()->get_name())->{'names'}->[0];
        $experiment_prop->get_type()->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $cvhandler{ident $self}->get_accession_for_term($dbname, $experiment_prop->get_type()->get_name()), 'db' => new ModENCODE::Chado::DB({'name' => $dbname}) }));
      }
    }
    if ($experiment_prop->get_termsource()) {
      $experiment_prop->get_termsource()->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($experiment_prop->get_termsource()->get_db()->get_name()));
    }
  }
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      # protocol (dbxref)
      if ($protocol->get_termsource()) {
        $protocol->get_termsource()->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($protocol->get_termsource()->get_db()->get_name()));
      }
      # protocol attributes (dbxref, type)
      foreach my $attribute (@{$protocol->get_attributes()}) {
        if ($attribute->get_type()) {
          $attribute->get_type()->get_cv()->set_name($cvhandler{ident $self}->get_cv_by_name($attribute->get_type()->get_cv()->get_name())->{'names'}->[0]);
          if ($attribute->get_type->get_dbxref()) {
            $attribute->get_type()->get_dbxref->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($attribute->get_type()->get_dbxref->get_db()->get_name()));
          } else {
            my $dbname = $cvhandler{ident $self}->get_cv_by_name($attribute->get_type()->get_dbxref->get_db()->get_name())->{'names'}->[0];
            $attribute->get_type()->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $cvhandler{ident $self}->get_accession_for_term($dbname, $attribute->get_type()->get_name()), 'db' => new ModENCODE::Chado::DB({'name' => $dbname}) }));
          }
        }
        if ($attribute->get_termsource()) {
          $attribute->get_termsource()->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($attribute->get_termsource()->get_db()->get_name()));
        }
      }
      # data (dbxref, type)
      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if ($datum->get_type()) {
          $datum->get_type()->get_cv()->set_name($cvhandler{ident $self}->get_cv_by_name($datum->get_type()->get_cv()->get_name())->{'names'}->[0]);
          if ($datum->get_type->get_dbxref()) {
            $datum->get_type()->get_dbxref->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($datum->get_type()->get_dbxref->get_db()->get_name()));
          } else {
            my $dbname = $cvhandler{ident $self}->get_cv_by_name($datum->get_type()->get_dbxref->get_db()->get_name())->{'names'}->[0];
            $datum->get_type()->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $cvhandler{ident $self}->get_accession_for_term($dbname, $datum->get_type()->get_name()), 'db' => new ModENCODE::Chado::DB({'name' => $dbname}) }));
          }
        }
        if ($datum->get_termsource()) {
          $datum->get_termsource()->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($datum->get_termsource()->get_db()->get_name()));
        }
        # data attributes (dbxref, type)
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_type()) {
            $attribute->get_type()->get_cv()->set_name($cvhandler{ident $self}->get_cv_by_name($attribute->get_type()->get_cv()->get_name())->{'names'}->[0]);
            if ($attribute->get_type->get_dbxref()) {
              $attribute->get_type()->get_dbxref->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($attribute->get_type()->get_dbxref->get_db()->get_name()));
            } else {
              my $dbname = $cvhandler{ident $self}->get_cv_by_name($attribute->get_type()->get_dbxref->get_db()->get_name())->{'names'}->[0];
              $attribute->get_type()->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $cvhandler{ident $self}->get_accession_for_term($dbname, $attribute->get_type()->get_name()), 'db' => new ModENCODE::Chado::DB({'name' => $dbname}) }));
            }
          }
          if ($attribute->get_termsource()) {
            $attribute->get_termsource()->set_db($cvhandler{ident $self}->get_db_object_by_cv_name($attribute->get_termsource()->get_db()->get_name()));
          }
        }
      }
    }
  }
  log_error "Done.", "notice", "<";

  return $experiment;
}

sub validate {
  my ($self, $experiment) = @_;
  my $success = 1;
  $experiment = $experiment->clone(); # Don't do anything to change the experiment passed in
  log_error "Verifying term sources referenced in the SDRF against the terms they constrain.", "notice", ">";
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      # TERM SOURCES
      # Term sources can apply to protocols, data, and attributes (which is to say pretty much everything)
      # Protocol
      if ($protocol->get_termsource() && !($self->is_valid($protocol->get_termsource(), $protocol->get_name()))) {
        log_error "Term source '" . $protocol->get_termsource()->get_db()->get_name() . "' (" . $protocol->get_termsource()->get_db()->get_url() . ") does not contain a definition for protocol '" . $protocol->get_name() . "'.";
        $success = 0;
      }
      # Protocol attributes
      foreach my $attribute (@{$protocol->get_attributes()}) {
        if ($attribute->get_termsource() && !($self->is_valid($attribute->get_termsource(), $attribute->get_value()))) {
          log_error "Term source '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") does not contain a definition for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "' of protocol '" . $protocol->get_name() . "'.";
          $success = 0;
        }
      }
      # Data
      my @data = (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()});
      foreach my $datum (@data) {
        if ($datum->get_termsource() && !($self->is_valid($datum->get_termsource(), $datum->get_value()))) {
          log_error "Term source '" . $datum->get_termsource()->get_db()->get_name() . "' (" . $datum->get_termsource()->get_db()->get_url() . ") does not contain a definition for datum '" . $datum->get_heading() . " [" . $datum->get_name() . "]=" . $datum->get_value() . "' of protocol '" . $protocol->get_name() . "'.";
          $success = 0;
        }
        # Data attributes
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_termsource() && !($self->is_valid($attribute->get_termsource(), $attribute->get_value()))) {
            log_error "Term source '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") does not contain a definition for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "' of datum '" . $datum->get_heading() . " [" . $datum->get_name() . "]=" . $datum->get_value() . "' of protocol '" . $protocol->get_name() . "'.";
            $success = 0;
          }
        }
      }
    }
  }
  log_error "Done.", "notice", "<";
  log_error "Make sure all types and term sources are valid.", "notice", ">";
  # One last run through all CVTerms and DBXrefs to make we know all of them
  # There is some redundancy here, but it should be plenty fast
  # experiment_prop (dbxref, type)
  foreach my $experiment_prop (@{$experiment->get_properties()}) {
    if ($experiment_prop->get_type()) {
      if (!$cvhandler{ident $self}->is_valid_term($experiment_prop->get_type()->get_cv()->get_name(), $experiment_prop->get_type()->get_name())) {
        log_error "Type '" . $experiment_prop->get_type()->get_cv()->get_name() . ":" . $experiment_prop->get_type()->get_name() . "' is not a valid CVTerm for experiment_prop '" . $experiment_prop->get_name() . "=" . $experiment_prop->get_value() . "'.";
        $success = 0;
      }
    }
    if ($experiment_prop->get_termsource()) {
      if (!$self->is_valid($experiment_prop->get_termsource(), $experiment_prop->get_value())) {
        log_error "Termsource '" . $experiment_prop->get_termsource()->get_db()->get_name() . "' (" . $experiment_prop->get_termsource()->get_db()->get_url() . ") is not a valid term source/DBXref for experiment_prop '" . $experiment_prop->get_name() . "=" . $experiment_prop->get_value() . "'.";
        $success = 0;
      }
    }
  }
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my $protocol = $applied_protocol->get_protocol();
      # protocol (dbxref)
      if ($protocol->get_termsource()) {
        if (!$self->is_valid($protocol->get_termsource(), $protocol->get_name())) {
          log_error "Termsource '" . $protocol->get_termsource()->get_db()->get_name() . "' (" . $protocol->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for protocol '" . $protocol->get_name() . "'.";
          $success = 0;
        }
      }
      # protocol attributes (dbxref, type)
      foreach my $attribute (@{$protocol->get_attributes()}) {
        if ($attribute->get_type()) {
          if (!$cvhandler{ident $self}->is_valid_term($attribute->get_type()->get_cv()->get_name(), $attribute->get_type()->get_name())) {
            log_error "Type '" . $attribute->get_type()->get_cv()->get_name() . ":" . $attribute->get_type()->get_name() . "' is not a valid CVTerm for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
            $success = 0;
          }
        }
        if ($attribute->get_termsource()) {
          if (!$self->is_valid($attribute->get_termsource(), $attribute->get_value())) {
            log_error "Termsource '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
            $success = 0;
          }
        }
      }
      # data (dbxref, type)
      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if ($datum->get_type()) {
          if (!$cvhandler{ident $self}->is_valid_term($datum->get_type()->get_cv()->get_name(), $datum->get_type()->get_name())) {
            log_error "Type '" . $datum->get_type()->get_cv()->get_name() . ":" . $datum->get_type()->get_name() . "' is not a valid CVTerm for datum '" . $datum->get_heading() . "[" . $datum->get_name() . "]=" . $datum->get_value() . "'.";
            $success = 0;
          }
        }
        if ($datum->get_termsource()) {
          if (!$self->is_valid($datum->get_termsource(), $datum->get_value())) {
            log_error "Termsource '" . $datum->get_termsource()->get_db()->get_name() . "' (" . $datum->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for datum '" . $datum->get_heading() . "[" . $datum->get_name() . "]=" . $datum->get_value() . "'";
            $success = 0;
          }
        }
        # data attributes (dbxref, type)
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_type()) {
            if (!$cvhandler{ident $self}->is_valid_term($attribute->get_type()->get_cv()->get_name(), $attribute->get_type()->get_name())) {
              log_error "Type '" . $attribute->get_type()->get_cv()->get_name() . ":" . $attribute->get_type()->get_name() . "' is not a valid CVTerm for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
              $success = 0;
            }
          }
          if ($attribute->get_termsource()) {
            if (!$self->is_valid($attribute->get_termsource(), $attribute->get_value())) {
              log_error "Termsource '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
              $success = 0;
            }
          }
        }
      }
    }
  }

  log_error "Done.", "notice", "<";
  return $success;

}

sub get_term_and_accession : PRIVATE {
  my ($self, $termsource, $term, $accession) = @_;
  if (!$term && !$accession) {
    $accession = $termsource->get_accession();
  }
  if (!$accession) {
    $accession = $cvhandler{ident $self}->get_accession_for_term($termsource->get_db()->get_name(), $term);
  }
  if (!$term) {
    $term = $cvhandler{ident $self}->get_term_for_accession($termsource->get_db()->get_name(), $accession);
  }
  return (wantarray ? ($term, $accession) : { 'term' => $term, 'accession' => $accession });
}


sub is_valid : PRIVATE {
  my ($self, $termsource, $term, $accession) = @_;
  my $valid = 1;
  croak "Cannot validate a term against a termsource without a termsource object" unless $termsource && ref($termsource) eq "ModENCODE::Chado::DBXref";
  if (!$term && !$accession) {
    # Really shouldn't use is_valid with no term or accession like this
    log_error "Given a termsource to validate with no term or accession; testing accession built into termsource: " . $termsource->to_string(), "warning";
    $accession = $termsource->get_accession();
    if (!$accession) {
      log_error "Nothing to validate; no term or accession given, and no accession built into termsource: " . $termsource->to_string() . "\n";
      return 0;
    }
  }
  if (!$cvhandler{ident $self}->add_cv(
    $termsource->get_db()->get_name(),
    $termsource->get_db()->get_url(),
    $termsource->get_db()->get_description(),
  )) {
    log_error "Couldn't add the termsource specified by '" . $termsource->get_db()->get_name() . "' (" . $termsource->get_db()->get_url() . ").";
    $valid = 0;
  }
  if ($accession) {
    if (!$cvhandler{ident $self}->is_valid_accession($termsource->get_db()->get_name(), $accession)) {
      log_error "Couldn't find the accession $accession in '" . $termsource->get_db()->get_name() . "' (" . $termsource->get_db()->get_url() . ").";
      $valid = 0;
    }
  } 
  if ($term) {
    if (!$cvhandler{ident $self}->is_valid_term($termsource->get_db()->get_name(), $term)) {
      log_error "Couldn't find the term $term in '" . $termsource->get_db()->get_name() . "' (" . $termsource->get_db()->get_url() . ").";
      $valid = 0;
    }
  }
  return $valid;
}

1;

package ModENCODE::Validator::TermSources;
=pod

=head1 NAME

ModENCODE::Validator::TermSources - Validator that will validate a BIR-TAB
L<ModENCODE::Chado::Experiment> object by verifying all of the
L<ModENCODE::Chado::DBXref>s against the L<ModENCODE::Chado::DB> they are part
of.

=head1 SYNOPSIS

This class should be used to validate all of the
L<DBXrefs|ModENCODE::Chado::DBXref> attached to any
L<protocol|ModENCODE::Chado::Protocol>, L<experiment
property|ModENCODE::Chado::ExperimentProp>, L<datum|ModENCODE::Chado::Data>,
L<attribute|ModENCODE::Chado::Attribute>, L<controlled vocabulary
term|ModENCODE::Chado::CVTerm>, or L<feature|ModENCODE::Chado::Feature> in a
BIR-TAB L<ModENCODE::Chado::Experiment> object.

The validation is done by using
L<ModENCODE::Validator::CVHandler/is_valid_term($cvname, $term)> and assuming
that the L<DBXref's|ModENCODE::Chado::DBXref> accession is a valid term in a
controlled vocabulary identified by the name of the attached
L<DB|ModENCODE::Chado::DB>. Because of this, you should run this validator
before any validators that modify the experiment object by pulling in
L<DBXrefs|ModENCODE::Chado::DBXref> that are not verifiable by the
L<CVHandler|ModENCODE::Validator::CVHandler>.

=head1 USAGE

This validator will scan through all of the L<ModENCODE::Chado|index> object
types mentioned above that are part of an experiment, recursing from the
experiment object down through applied protocols to data, then to features, and
so forth. It will check every L<DBXref|ModENCODE::Chado::DBXref> it runs across
by calling L<is_valid_term($cvname,
$term)|ModENCODE::Validator::CVHandler/is_valid_term($cvname, $term)> with a
C<$cvname> equal to the L<DBXref's|ModENCODE::Chado::DBXref>
L<DB's|ModENCODE::Chado::DB> name and a C<$term> equal to the
L<DBXref's|ModENCODE::Chado::DBXref> accession. If any term is invalid, then an
error is printed and the experiment fails to validate. If it runs across a
L<CVTerm|ModENCODE::Chado::CVTerm> with no attached
L<DBXref|ModENCODE::Chado::DBXref>, then it will generate a new one for it and
validate it as well. Furthermore, if there is a DBXref with no accession, the
accession is assumed to be the value of the containing element (the name of a
protocol, value of a datum, etc.) and is validated as such.

If the experiment validates successfully, then any missing
L<DBXref|ModENCODE::Chado::DBXref> or missing accession is filled in. If there
are multiple names being used for the same L<CV|ModENCODE::Chado::CV> or
L<DB|ModENCODE::Chado::DB> as determined by
L<ModENCODE::Validator::CVHandler/get_cv_by_name($cvname)>, then the canonical
one is used to replace any of the synonyms so that the names are consistent.

To run the validator:

  my $termsource_validator = new ModENCODE::Validator::TermSources();
  if ($termsource_validator->validate($experiment)) {
    $experiment = $termsource_validator->merge($experiment);
    print $experiment->get_properties()->[0]->get_dbxref()->get_name();
  }

=head1 FUNCTIONS

=over

=item check_and_update_features($features)

Given an arrayref of L<Features|ModENCODE::Chado::Feature> in C<$feature>,
validate any L<DBXrefs|ModENCODE::Chado::DBXref> linked to them or any related
features, L<CVTerms|ModENCODE::Chado::CVTerm>, etc., then merge in any changes.
Return 1 on success or 0 on failure. (The features are merged in-place.)

=item validate($experiment)

Ensures that the L<Experiment|ModENCODE::Chado::Experiment> specified in
C<$experiment> contains only valid L<DBXrefs|ModENCODE::Chado::DBXref> as determined by
L<is_valid_term($cvname,
$term)|ModENCODE::Validator::CVHandler/is_valid_term($cvname, $term)>. Returns 1
on success, 0 on failure.

=item merge($experiment)

Updates any L<DBXrefs|ModENCODE::Chado::DBXref> to have an associated
L<DB|ModENCODE::Chado::DB> and accession. Also ensures that
L<DB|ModENCODE::Chado::DB> and L<CV|ModENCODE::Chado::CV> names are consistent
and synonyms are not being used. Returns the updated
L<ModENCODE::Chado::Experiment> object.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Validator::CVHandler>,
L<ModENCODE::Validator::Attributes>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::IDF_SDRF>, L<ModENCODE::Validator::CVHandler>,
L<ModENCODE::Validator::Wiki>, L<ModENCODE::Chado::Experiment>,
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
use ModENCODE::Validator::CVHandler;
use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::DB;
use ModENCODE::ErrorHandler qw(log_error);

sub check_and_update_features {
  my ($self, $features) = @_;
  foreach my $feature (@$features) {
    if ($self->validate_chado_feature($feature)) {
      $self->merge_chado_feature($feature);
    } else {
      return 0;
    }
  }
  return 1;
}

sub merge {
  my ($self, $experiment) = @_;
  log_error "Removing temporary definitions for term sources that were referenced in the SDRF.", "notice", ">";
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
  log_error "Done", "notice", "<";

  log_error "Making sure that all CV and DB names are consistent.", "notice", ">";
  # First, run through all the CVTerms to catch cases where we have a CVTerm with no DBXref
  my $all_cvterms = ModENCODE::Chado::CVTerm::get_all_cvterms();
  foreach my $cv (keys(%$all_cvterms)) {
    foreach my $term (keys(%{$all_cvterms->{$cv}})) {
      foreach my $is_obsolete (keys(%{$all_cvterms->{$cv}->{$term}})) {
        my $cvterm = $all_cvterms->{$cv}->{$term}->{$is_obsolete};
        my $dbxref = $cvterm->get_dbxref();
        if ($dbxref) {
          # If there's a dbxref for the cvterm, update the dbxref's DB and accession to match the cached copy in CVHandler (so URLs, names, etc, all match)
          # The name of the DB gets looked up by the existing DB object (if any), or the CV name (if no DB object is set for the dbxref)

          if (!$dbxref->get_db()) {
            $dbxref->set_db(ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($cvterm->get_cv()->get_name()));
          }

          if ($dbxref->get_accession() eq $cvterm->get_name() && $dbxref->get_db()) {
            # If there's no accession or the accession is the same as the term, then try to fetch an accession
            my $new_accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($cvterm->get_cv()->get_name(), $cvterm->get_name());
            $dbxref->set_accession($new_accession) if length($new_accession);
          }
        } else {
          # If there's not a dbxref for the cvterm, try to find one
          # First, get a DB based on the CV name
          my $db = ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($cvterm->get_cv()->get_name());
          my $accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($cvterm->get_cv()->get_name(), $cvterm->get_name()) if $db;
          if ($db && $accession) {
            # If there's a DB and accession, create a new DBXref and add it to the cvterm
            $cvterm->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $accession, 'db' => $db }));
          }
        }
      }
    }
  }
  # Now run through all of the DBXrefs and make sure their DB names are consistent
  my $all_dbxrefs = ModENCODE::Chado::DBXref::get_all_dbxrefs();
  foreach my $db (keys(%$all_dbxrefs)) {
    foreach my $accession (keys(%{$all_dbxrefs->{$db}})) {
      foreach my $version (keys(%{$all_dbxrefs->{$db}->{$accession}})) {
        my $dbxref = $all_dbxrefs->{$db}->{$accession}->{$version};
        next if $dbxref->get_accession() eq "__ignore";
        my $db_name = $dbxref->get_db()->get_name();
        my $new_db = ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($db_name);
        $dbxref->set_db($new_db) if $new_db;
      }
    }
  }
  log_error "Done.", "notice", "<";

  return $experiment;
}

sub merge_chado_feature : PRIVATE {
  my ($self, $feature, $seen_objects) = @_;

  $seen_objects = [] unless ref($seen_objects) eq "ARRAY";

  return 1 if scalar(grep { $feature == $_ } @$seen_objects);
  push @$seen_objects, $feature;

  if ($feature->get_type()) {
    $feature->get_type()->get_cv()->set_name(ModENCODE::Config::get_cvhandler()->get_cv_by_name($feature->get_type()->get_cv()->get_name())->{'names'}->[0]);
    if ($feature->get_type->get_dbxref()) {
      # If there's a dbxref for the feature type, update the dbxref's DB and accession to match the cached copy in CVHandler (so URLs, names, etc, all match)
      # The name of the DB gets looked up by the existing DB object (if any), or the CV name (if no DB object is set for the dbxref)
      my $db_name = ($feature->get_type()->get_dbxref->get_db() ? $feature->get_type()->get_dbxref->get_db()->get_name() : $feature->get_type()->get_cv()->get_name());
      $feature->get_type()->get_dbxref->set_db(ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($db_name));
      if (!$feature->get_type()->get_dbxref()->get_accession() && $feature->get_type()->get_dbxref()->get_db()) {
        # If the dbxref doesn't yet have an accession, and we managed to get a DB out of CVHandler with get_db_object_by_cv_name, then fetch the accession based on the CVTerm and CV name
        $feature->get_type()->get_dbxref()->set_accession(ModENCODE::Config::get_cvhandler()->get_accession_for_term($feature->get_type()->get_cv()->get_name(), $feature->get_type()->get_name()));
      }
    } else {
      # If there's not a dbxref for the feature type, try to find one
      # First, get a DB based on the CV name
      my $db = ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($feature->get_type()->get_cv()->get_name());
      my $accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($feature->get_type()->get_cv()->get_name(), $feature->get_type()->get_name()) if $db;
      if ($db && $accession) {
        # If there's a DB and accession, create a new DBXref and add it to the feature's type
        $feature->get_type()->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $accession, 'db' => $db }));
      }
    }
  }
  foreach my $relationship (@{$feature->get_relationships()}) {
    if ($relationship->get_type()) {
      if (ModENCODE::Config::get_cvhandler()->is_valid_term($relationship->get_type()->get_cv()->get_name(), $relationship->get_type()->get_name())) {
        if ($relationship->get_type()) {
          $relationship->get_type()->get_cv()->set_name(ModENCODE::Config::get_cvhandler()->get_cv_by_name($relationship->get_type()->get_cv()->get_name())->{'names'}->[0]);
          if ($relationship->get_type->get_dbxref()) {
            # If there's a dbxref for the relationship type, update the dbxref's DB and accession to match the cached copy in CVHandler (so URLs, names, etc, all match)
            # The name of the DB gets looked up by the existing DB object (if any), or the CV name (if no DB object is set for the dbxref)
            my $db_name = ($relationship->get_type()->get_dbxref->get_db() ? $relationship->get_type()->get_dbxref->get_db()->get_name() : $relationship->get_type()->get_cv()->get_name());
            $relationship->get_type()->get_dbxref->set_db(ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($db_name));
            if (!$relationship->get_type()->get_dbxref()->get_accession() && $relationship->get_type()->get_dbxref()->get_db()) {
              # If the dbxref doesn't yet have an accession, and we managed to get a DB out of CVHandler with get_db_object_by_cv_name, then fetch the accession based on the CVTerm and CV name
              $relationship->get_type()->get_dbxref()->set_accession(ModENCODE::Config::get_cvhandler()->get_accession_for_term($relationship->get_type()->get_cv()->get_name(), $relationship->get_type()->get_name()));
            }
          } else {
            # If there's not a dbxref for the relationship type, try to find one
            # First, get a DB based on the CV name
            my $db = ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($relationship->get_type()->get_cv()->get_name());
            my $accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($relationship->get_type()->get_cv()->get_name(), $relationship->get_type()->get_name()) if $db;
            if ($db && $accession) {
              # If there's a DB and accession, create a new DBXref and add it to the relationship's type
              $relationship->get_type()->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $accession, 'db' => $db }));
            }
          }
        }
      }
    }
    if ($relationship->get_object()) {
      $self->merge_chado_feature($relationship->get_object(), $seen_objects);
    }
    if ($relationship->get_subject()) {
      $self->merge_chado_feature($relationship->get_subject(), $seen_objects);
    }
    # Featureloc's srcfeature_id
    foreach my $featureloc (@{$feature->get_locations()}) {
      if ($featureloc->get_srcfeature()) {
        $self->merge_chado_feature($featureloc->get_srcfeature(), $seen_objects);
      }
    }
  }
}

sub validate_chado_feature : PRIVATE {
  my ($self, $feature, $seen_objects) = @_;
  my $success = 1;

  $seen_objects = [] unless ref($seen_objects) eq "ARRAY";

  return 1 if scalar(grep { $feature == $_ } @$seen_objects);
  push @$seen_objects, $feature;

  if ($feature->get_type()) {
    if (!ModENCODE::Config::get_cvhandler()->is_valid_term($feature->get_type()->get_cv()->get_name(), $feature->get_type()->get_name())) {
      my $feature_name = $feature->get_name() || $feature->get_uniquename();
      log_error "Type '" . $feature->get_type()->get_cv()->get_name() . ":" . $feature->get_type()->get_name() . "' is not a valid CVTerm for feature '" . $feature_name . "'";
      $success = 0;
    }
  }
  foreach my $relationship (@{$feature->get_relationships()}) {
    if ($relationship->get_type()) {
      if (!ModENCODE::Config::get_cvhandler()->is_valid_term($relationship->get_type()->get_cv()->get_name(), $relationship->get_type()->get_name())) {
        log_error "Relationship between '" . $relationship->get_subject()->get_name() . " and " . $relationship->get_object()->get_name() . "' doesn't have a valid CVTerm type '" . $relationship->get_type()->get_name() . "'";
        $success = 0;
      }
    }
    if ($relationship->get_object()) {
      $success = 0 unless $self->validate_chado_feature($relationship->get_object(), $seen_objects);
    }
    if ($relationship->get_subject()) {
      $success = 0 unless $self->validate_chado_feature($relationship->get_subject(), $seen_objects);
    }
  }
  # Featureloc's srcfeature_id
  foreach my $featureloc (@{$feature->get_locations()}) {
    if ($featureloc->get_srcfeature()) {
      $success = 0 unless $self->validate_chado_feature($featureloc->get_srcfeature(), $seen_objects);
    }
  }

  return $success;
}

sub validate {
  my ($self, $experiment) = @_;
  my $success = 1;
  log_error "Validating types and controlled vocabularies.", "notice", ">";
  # First, run through all the CVTerms to catch cases where we have a CVTerm with no DBXref
  my $all_cvterms = ModENCODE::Chado::CVTerm::get_all_cvterms();
  foreach my $cv (keys(%$all_cvterms)) {
    foreach my $term (keys(%{$all_cvterms->{$cv}})) {
      foreach my $is_obsolete (keys(%{$all_cvterms->{$cv}->{$term}})) {
        my $cvterm = $all_cvterms->{$cv}->{$term}->{$is_obsolete};
        if (!ModENCODE::Config::get_cvhandler()->is_valid_term($cvterm->get_cv()->get_name(), $cvterm->get_name())) {
          log_error "Type '" . $cvterm->get_cv()->get_name() . ":" . $cvterm->get_name() . "' is not a valid CVTerm.";
          $success = 0;
        }
        my $dbxref = $cvterm->get_dbxref();
        if (!$dbxref) {
          # If there's not a dbxref for the cvterm, try to find one
          # First, get a DB based on the CV name
          my $db = ModENCODE::Config::get_cvhandler()->get_db_object_by_cv_name($cvterm->get_cv()->get_name());
          my $accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($cvterm->get_cv()->get_name(), $cvterm->get_name()) if $db;
          if ($db && $accession) {
            # If there's a DB and accession, create a new DBXref and add it to the cvterm
            $cvterm->set_dbxref(new ModENCODE::Chado::DBXref({ 'accession' => $accession, 'db' => $db }));
          } else {
            log_error "Can't find accession for " . $cvterm->get_cv()->get_name . ":" . $cvterm->get_name(), "error";
            $success = 0;
          }
        }
      }
    }
  }
  log_error "Done.", "notice", "<";
  # Now run through all of the DBXrefs and make sure their DB names are consistent
  log_error "Validating term sources and term source references.", "notice", ">";
  my $all_dbxrefs = ModENCODE::Chado::DBXref::get_all_dbxrefs();
  foreach my $db (keys(%$all_dbxrefs)) {
    foreach my $accession (keys(%{$all_dbxrefs->{$db}})) {
      foreach my $version (keys(%{$all_dbxrefs->{$db}->{$accession}})) {
        my $dbxref = $all_dbxrefs->{$db}->{$accession}->{$version};
        next if $dbxref->get_accession() eq "__ignore";
        if (!$self->is_valid($dbxref, $dbxref->get_accession())) {
          log_error "Termsource '" . $dbxref->get_db()->get_name() . "' (" . $dbxref->get_db()->get_url() . ") is not a valid DB.";
          $success = 0;
        }
      }
    }
  }
  log_error "Done.", "notice", "<";

  return $success;
}
#sub validate {
#  my ($self, $experiment) = @_;
#  my $success = 1;
#  $experiment = $experiment->clone(); # Don't do anything to change the experiment passed in
#  log_error "Verifying term sources referenced in the SDRF against the terms they constrain.", "notice", ">";
#  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
#    foreach my $applied_protocol (@$applied_protocol_slots) {
#      my $protocol = $applied_protocol->get_protocol();
#      # TERM SOURCES
#      # Term sources can apply to protocols, data, and attributes (which is to say pretty much everything)
#      # Protocol
#      if ($protocol->get_termsource() && !($self->is_valid($protocol->get_termsource(), $protocol->get_name()))) {
#        log_error "Term source '" . $protocol->get_termsource()->get_db()->get_name() . "' (" . $protocol->get_termsource()->get_db()->get_url() . ") does not contain a definition for protocol '" . $protocol->get_name() . "'.";
#        $success = 0;
#      }
#      # Protocol attributes
#      foreach my $attribute (@{$protocol->get_attributes()}) {
#        if ($attribute->get_termsource() && !($self->is_valid($attribute->get_termsource(), $attribute->get_value()))) {
#          log_error "Term source '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") does not contain a definition for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "' of protocol '" . $protocol->get_name() . "'.";
#          $success = 0;
#        }
#      }
#      # Data
#      my @data = (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()});
#      foreach my $datum (@data) {
#        if ($datum->get_termsource() && !($self->is_valid($datum->get_termsource(), $datum->get_value()))) {
#          log_error "Term source '" . $datum->get_termsource()->get_db()->get_name() . "' (" . $datum->get_termsource()->get_db()->get_url() . ") does not contain a definition for datum '" . $datum->get_heading() . " [" . $datum->get_name() . "]=" . $datum->get_value() . "' of protocol '" . $protocol->get_name() . "'.";
#          $success = 0;
#        }
#        # Data attributes
#        foreach my $attribute (@{$datum->get_attributes()}) {
#          if ($attribute->get_termsource() && !($self->is_valid($attribute->get_termsource(), $attribute->get_value()))) {
#            log_error "Term source '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") does not contain a definition for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "' of datum '" . $datum->get_heading() . " [" . $datum->get_name() . "]=" . $datum->get_value() . "' of protocol '" . $protocol->get_name() . "'.";
#            $success = 0;
#          }
#        }
#        # Features
#        if (scalar(@{$datum->get_features()})) {
#          foreach my $feature (@{$datum->get_features()}) {
#            $success = 0 unless $self->validate_chado_feature($feature);
#          }
#        }
#      }
#    }
#  }
#  log_error "Done.", "notice", "<";
#  log_error "Make sure all types and term sources are valid.", "notice", ">";
#  # One last run through all CVTerms and DBXrefs to make we know all of them
#  # There is some redundancy here, but it should be plenty fast
#  # experiment_prop (dbxref, type)
#  foreach my $experiment_prop (@{$experiment->get_properties()}) {
#    if ($experiment_prop->get_type()) {
#      if (!ModENCODE::Config::get_cvhandler()->is_valid_term($experiment_prop->get_type()->get_cv()->get_name(), $experiment_prop->get_type()->get_name())) {
#        log_error "Type '" . $experiment_prop->get_type()->get_cv()->get_name() . ":" . $experiment_prop->get_type()->get_name() . "' is not a valid CVTerm for experiment_prop '" . $experiment_prop->get_name() . "=" . $experiment_prop->get_value() . "'.";
#        $success = 0;
#      }
#    }
#    if ($experiment_prop->get_termsource()) {
#      if (!$self->is_valid($experiment_prop->get_termsource(), $experiment_prop->get_value())) {
#        log_error "Termsource '" . $experiment_prop->get_termsource()->get_db()->get_name() . "' (" . $experiment_prop->get_termsource()->get_db()->get_url() . ") is not a valid term source/DBXref for experiment_prop '" . $experiment_prop->get_name() . "=" . $experiment_prop->get_value() . "'.";
#        $success = 0;
#      }
#    }
#  }
#  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
#    foreach my $applied_protocol (@$applied_protocol_slots) {
#      my $protocol = $applied_protocol->get_protocol();
#      # protocol (dbxref)
#      if ($protocol->get_termsource()) {
#        if (!$self->is_valid($protocol->get_termsource(), $protocol->get_name())) {
#          log_error "Termsource '" . $protocol->get_termsource()->get_db()->get_name() . "' (" . $protocol->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for protocol '" . $protocol->get_name() . "'.";
#          $success = 0;
#        }
#      }
#      # protocol attributes (dbxref, type)
#      foreach my $attribute (@{$protocol->get_attributes()}) {
#        if ($attribute->get_type()) {
#          if (!ModENCODE::Config::get_cvhandler()->is_valid_term($attribute->get_type()->get_cv()->get_name(), $attribute->get_type()->get_name())) {
#            log_error "Type '" . $attribute->get_type()->get_cv()->get_name() . ":" . $attribute->get_type()->get_name() . "' is not a valid CVTerm for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
#            $success = 0;
#          }
#        }
#        if ($attribute->get_termsource()) {
#          if (!$self->is_valid($attribute->get_termsource(), $attribute->get_value())) {
#            log_error "Termsource '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
#            $success = 0;
#          }
#        }
#      }
#      # data (dbxref, type)
#      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
#        if ($datum->get_type()) {
#          if (!ModENCODE::Config::get_cvhandler()->is_valid_term($datum->get_type()->get_cv()->get_name(), $datum->get_type()->get_name())) {
#            log_error "Type '" . $datum->get_type()->get_cv()->get_name() . ":" . $datum->get_type()->get_name() . "' is not a valid CVTerm for datum '" . $datum->get_heading() . "[" . $datum->get_name() . "]=" . $datum->get_value() . "'.";
#            $success = 0;
#          }
#        }
#        if ($datum->get_termsource()) {
#          if (!$self->is_valid($datum->get_termsource(), $datum->get_value())) {
#            log_error "Termsource '" . $datum->get_termsource()->get_db()->get_name() . "' (" . $datum->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for datum '" . $datum->get_heading() . "[" . $datum->get_name() . "]=" . $datum->get_value() . "'";
#            $success = 0;
#          }
#        }
#        # data attributes (dbxref, type)
#        foreach my $attribute (@{$datum->get_attributes()}) {
#          if ($attribute->get_type()) {
#            if (!ModENCODE::Config::get_cvhandler()->is_valid_term($attribute->get_type()->get_cv()->get_name(), $attribute->get_type()->get_name())) {
#              log_error "Type '" . $attribute->get_type()->get_cv()->get_name() . ":" . $attribute->get_type()->get_name() . "' is not a valid CVTerm for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
#              $success = 0;
#            }
#          }
#          if ($attribute->get_termsource()) {
#            if (!$self->is_valid($attribute->get_termsource(), $attribute->get_value())) {
#              log_error "Termsource '" . $attribute->get_termsource()->get_db()->get_name() . "' (" . $attribute->get_termsource()->get_db()->get_url() . ") is not a valid DBXref for attribute '" . $attribute->get_heading() . "[" . $attribute->get_name() . "]=" . $attribute->get_value() . "'";
#              $success = 0;
#            }
#          }
#        }
#      }
#    }
#  }
#
#  log_error "Done.", "notice", "<";
#  return $success;
#}

sub get_term_and_accession : PRIVATE {
  my ($self, $termsource, $term, $accession) = @_;
  if (!$term && !$accession) {
    $accession = $termsource->get_accession();
  }
  if (!$accession) {
    $accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($termsource->get_db()->get_name(), $term);
  }
  if (!$term) {
    $term = ModENCODE::Config::get_cvhandler()->get_term_for_accession($termsource->get_db()->get_name(), $accession);
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
  if (!ModENCODE::Config::get_cvhandler()->add_cv(
    $termsource->get_db()->get_name(),
    $termsource->get_db()->get_url(),
    $termsource->get_db()->get_description(),
  )) {
    log_error "Couldn't add the termsource specified by '" . $termsource->get_db()->get_name() . "' (" . $termsource->get_db()->get_url() . ").";
    $valid = 0;
  }
  if ($accession) {
    if (!ModENCODE::Config::get_cvhandler()->is_valid_accession($termsource->get_db()->get_name(), $accession)) {
      log_error "Couldn't find the accession $accession in '" . $termsource->get_db()->get_name() . "' (" . $termsource->get_db()->get_url() . ").";
      $valid = 0;
    }
  } 
  if ($term) {
    if (!ModENCODE::Config::get_cvhandler()->is_valid_term($termsource->get_db()->get_name(), $term)) {
      log_error "Couldn't find the term $term in '" . $termsource->get_db()->get_name() . "' (" . $termsource->get_db()->get_url() . ").";
      $valid = 0;
    }
  }
  return $valid;
}

1;

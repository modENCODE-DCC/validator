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

my %experiment                  :ATTR( :name<experiment> );

sub validate {
  my $self = shift;
  my $success = 1;
  my $experiment = $self->get_experiment;

  my @all_cvterms = ModENCODE::Cache::get_all_objects('cvterm');

  foreach my $cvterm (@all_cvterms) {
    my $cvterm_obj = $cvterm->get_object;
    my $cv = $cvterm_obj->get_cv;
    my $cv_obj = $cv->get_object;

    # Check that CV names are consistent
    my $canonical_cvname = ModENCODE::Config::get_cvhandler()->get_cv_by_name($cv_obj->get_name)->{'names'}->[0];
    if ($cv_obj->get_name ne $canonical_cvname) {
      # Update CV with new CV name
      my $new_cv = new ModENCODE::Chado::CV({
          'name' => $canonical_cvname || undef,
          'definition' => $cv_obj->get_definition || undef,
        });
      $cv = ModENCODE::Cache::update_cv($cv_obj, $new_cv->get_object);
      log_error "Updated CV " . $cv_obj->get_name . " with canonical name $canonical_cvname.", "notice";
      exit;
      $cv_obj = $cv->get_object;
    }
    next;

    # Check that this CVTerm has a DBXref
    if ($cvterm_obj->get_dbxref()) {
      # Check that there's an appropriate accession for the given term
      my $current_accession = $cvterm_obj->get_dbxref(1)->get_accession;
      log_error "Getting expected accession for " . $cv_obj->get_name . ":" . $cvterm_obj->get_name . ".", "debug";
      my $expected_accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($cv_obj->get_name, $cvterm_obj->get_name);
      if ($expected_accession && $current_accession ne $expected_accession) {
        my $new_dbxref = new ModENCODE::Chado::DBXref({
            'accession' => $expected_accession || undef,
            'version' => $cvterm_obj->get_dbxref(1)->get_version || undef,
            'db' => $cvterm_obj->get_dbxref(1)->get_db || undef,
          });
        $new_dbxref = ModENCODE::Cache::update_dbxref($cvterm_obj->get_dbxref(1), $new_dbxref->get_object);
        log_error "Updated DBXref $current_accession with real accession $expected_accession.", "debug";
        $cvterm->get_object->set_dbxref($new_dbxref);
      }
    } else {
      # Create a DBXref for this CVTerm since it doesn't have one yet
      log_error "Getting new accession for " . $cv_obj->get_name . ":" . $cvterm_obj->get_name . ".", "debug";
      my $accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($cv_obj->get_name, $cvterm_obj->get_name);
      my $db = new ModENCODE::Chado::DB({ 'name' => $canonical_cvname });
      my $dbxref = new ModENCODE::Chado::DBXref({
          'accession' => $accession,
          'db' => $db,
        });
      log_error "Adding DBXref " . $dbxref->get_object->to_string . " to CVTerm " . $cvterm->get_object->to_string . ".", "debug";
      $cvterm->get_object->set_dbxref($dbxref);
    }
  }

  my @all_dbxrefs = ModENCODE::Cache::get_all_objects('dbxref');

  foreach my $dbxref (@all_dbxrefs) {
    my $dbxref_obj = $dbxref->get_object;
    next if $dbxref_obj->get_accession eq "__ignore"; # Leftovers from SDRF parsing

    my $db = $dbxref_obj->get_db;
    my $db_obj = $db->get_object;

    # Attempt to canonicalize DB name (may fail, but that's okay)
    my $canonical_db = 
      ModENCODE::Config::get_cvhandler()->get_cv_by_name($db_obj->get_name) ||
      ModENCODE::Config::get_cvhandler()->get_cv_by_url($db_obj->get_url);

    if ($canonical_db) {
      my $canonical_dbname = $canonical_db->{'names'}->[0];
      if ($db_obj->get_name ne $canonical_dbname) {
        # Update DB with new DB name
        my $new_db = new ModENCODE::Chado::DB({
            'name' => $canonical_dbname || undef,
            'url' => $db_obj->get_url || undef,
            'description' => $db_obj->get_description || undef,
          });
        $db = ModENCODE::Cache::update_db($db_obj, $new_db->get_object);
        log_error "Updated DB " . $db_obj->get_name . " with canonical name $canonical_dbname.", "debug";
        $db_obj = $db->get_object;
      }

      # Verify accessions (can only do if DB name = CV name)
      if (!ModENCODE::Config::get_cvhandler()->is_valid_accession($canonical_dbname, $dbxref_obj->get_accession)) {
        # Not currently an accession, do we actually have a term instead of an accession,
        # and if so, can we find the actual accession?
        my $new_accession = ModENCODE::Config::get_cvhandler()->get_accession_for_term($canonical_dbname, $dbxref_obj->get_accession);
        if ($new_accession) {
          if ($new_accession ne $dbxref_obj->get_accession) {
            my $new_dbxref = new ModENCODE::Chado::DBXref({
                'accession' => $new_accession,
                'version' => $dbxref_obj->get_version,
                'db' => $dbxref_obj->get_db,
              });
            $dbxref = ModENCODE::Cache::update_dbxref($dbxref_obj, $new_dbxref->get_object);
            log_error "Updated DBXref " . $dbxref_obj->get_accession . " with real accession $new_accession.", "debug";
            $dbxref_obj = $dbxref->get_object;
          }
        } else {
          # Couldn't find a valid accession
          log_error $dbxref_obj->get_accession . " is not a valid accession in the database $canonical_dbname.", "error";
          $success = 0;
        }
      }
    } else {
      log_error "Didn't canonicalize DB " . $db_obj->get_name . "; no CV with the same name.", "notice";
    }
  }

  return $success;
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

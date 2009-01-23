package ModENCODE::Cache;

use strict;
use DBI;

use Class::Std;
use Carp qw(croak);
use File::Temp qw();
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Cache::CachedObject;
use ModENCODE::CacheSet;
use ModENCODE::Cache::CV;
use ModENCODE::Cache::CVTerm;
use ModENCODE::Cache::DB;
use ModENCODE::Cache::DBXref;
use ModENCODE::Cache::Data;
use ModENCODE::Cache::DatumAttribute;
use ModENCODE::Cache::Experiment;
use ModENCODE::Cache::ExperimentProp;
use ModENCODE::Cache::Organism;
use ModENCODE::Cache::Protocol;
use ModENCODE::Cache::ProtocolAttribute;
use ModENCODE::Cache::Wiggle_Data;
use ModENCODE::Cache::Feature;
use ModENCODE::Cache::Analysis;
use ModENCODE::Cache::FeatureRelationship;

use ModENCODE::Chado::Feature;
use ModENCODE::Chado::Protocol;
use ModENCODE::Chado::Analysis;
use ModENCODE::Chado::AnalysisFeature;
use ModENCODE::Chado::FeatureLoc;

use constant DEBUG => 0;

my $dbh;
my $db_tempfile;
my %queries;
my %cachesets;
my $query_count = 0;

sub dbh {
  unless ($dbh) {
    my ($undef, $filename) = File::Temp::tempfile( DIR => ModENCODE::Config::get_cfg()->val('cache', 'tmpdir'), SUFFIX => ".sqlite" );
#    $filename = "/tmp/useme.sql";
    if (-e $filename) { unlink $filename; }
    $db_tempfile = $filename;
    $dbh = DBI->connect("dbi:SQLite:dbname=$filename", '', '', { AutoCommit => 0 });
    $dbh->do("PRAGMA synchronous = OFF");
    $dbh->do("PRAGMA default_synchronous = OFF");
    $dbh->do("PRAGMA temp_store = MEMORY"); # Store indices in memory
    $dbh->do("PRAGMA count_changes = 0");
    $dbh->do("PRAGMA journal_mode = OFF");
  }
  return $dbh;
}

sub init {
  init_schema();
  my @cacheset_names = (
    'cv', 'cvterm', 'db', 'dbxref', 'experiment', 'experimentprop', 'protocol', 'organism', 'data', 'protocol_attribute', 'datum_attribute', 'wiggle_data',
    'feature', 'analysis', 'feature_relationship'
  );
  foreach my $cacheset_name (@cacheset_names) {
    $cachesets{$cacheset_name} = new ModENCODE::CacheSet({'name' => $cacheset_name});
  }
}

# TODO: Replace this with something better
sub get_all_objects {
  my $cacheset = shift;
  return $cachesets{$cacheset}->get_all_objects;
}

sub init_schema {
  my @create_tables = (
    'CREATE TABLE analysis (    
        analysis_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        description TEXT,
        program varchar(255),
        programversion varchar(255),
        algorithm varchar(255),
        sourcename varchar(255),
        sourceversion varchar(255),
        sourceuri text,
        timeexecuted timestamp
    )',
    'CREATE TABLE analysisfeature (
        analysisfeature_id INTEGER PRIMARY KEY,
        rawscore DOUBLE,
        normscore DOUBLE,
        significance DOUBLE,
        identity DOUBLE,
        feature_id INTEGER,
        analysis_id INTEGER
    )',
    'CREATE INDEX af_feature_idx ON analysisfeature(feature_id)',
    'CREATE TABLE applied_protocol (
        applied_protocol_id INTEGER PRIMARY KEY,
        protocol_id INTEGER
    )',
    'CREATE TABLE input_data (
        applied_protocol_id INTEGER,
        data_id INTEGER
    )',
    'CREATE TABLE output_data (
        applied_protocol_id INTEGER,
        data_id INTEGER
    )',
    'CREATE TABLE attribute (
        attribute_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        heading VARCHAR(255),
        value TEXT,
        rank INTEGER,
        termsource_id INTEGER,
        type_id INTEGER
    )',
    'CREATE TABLE attribute_organism (
        attribute_id INTEGER,
        organism_id INTEGER
    )',
    'CREATE TABLE cv (
        cv_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        definition TEXT
    )',
    'CREATE TABLE cvterm (
        cvterm_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        definition TEXT,
        is_obsolete INTEGER,
        cv_id INTEGER,
        dbxref_id INTEGER
    )',
    'CREATE TABLE data (
        data_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        heading VARCHAR(255),
        value TEXT,
        anonymous INTEGER,
        termsource_id INTEGER, 
        type_id INTEGER
    )',
    'CREATE TABLE data_attribute (
        data_id INTEGER,
        attribute_id INTEGER
    )',
    'CREATE TABLE data_feature (
        data_id INTEGER,
        feature_id INTEGER
    )',
    'CREATE TABLE data_wiggle (
        data_id INTEGER,
        wiggle_id INTEGER
    )',
    'CREATE TABLE data_organism (
        data_id INTEGER,
        organism_id INTEGER
    )',
    'CREATE TABLE db (
        db_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        url VARCHAR(255),
        description TEXT
    )',
    'CREATE TABLE dbxref (
        dbxref_id INTEGER PRIMARY KEY,
        accession VARCHAR(255),
        version INTEGER,
        db_id INTEGER
    )',
    'CREATE TABLE experiment (
        experiment_id INTEGER PRIMARY KEY,
        uniquename VARCHAR(255),
        description TEXT
    )',
    'CREATE TABLE experimentprop (
        experimentprop_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        value TEXT,
        rank INTEGER,
        experiment_id INTEGER,
        termsource_id INTEGER,
        type_id INTEGER
    )',
    'CREATE TABLE experiment_applied_protocol (
        experiment_id INTEGER,
        applied_protocol_id INTEGER,
        column_index INTEGER
    )',
    'CREATE TABLE feature (
        feature_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        uniquename VARCHAR(255),
        residues TEXT,
        seqlen INTEGER,
        timeaccessioned TIMESTAMP,
        timelastmodified TIMESTAMP,
        is_analysis INTEGER,
        dbxref_id INTEGER,
        organism_id INTEGER,
        type_id INTEGER,
        UNIQUE (uniquename, type_id)
    )',
    'CREATE TABLE featureloc (
        featureloc_id INTEGER PRIMARY KEY,
        feature_id INTEGER,
        fmin INTEGER,
        fmax INTEGER,
        rank INTEGER,
        strand INTEGER,
        srcfeature_id INTEGER
    )',
    'CREATE INDEX fl_feature_idx ON featureloc(feature_id)',
    'CREATE TABLE featureprop (
        featureprop_id INTEGER PRIMARY KEY,
        feature_id INTEGER,
        value INTEGER,
        rank INTEGER,
        type_id INTEGER
    )',
    'CREATE INDEX fp_feature_idx ON featureprop(feature_id)',
    'CREATE TABLE feature_feature_relationship (
        feature_id INTEGER,
        feature_relationship_id INTEGER
    )',
    'CREATE TABLE feature_relationship (
        feature_relationship_id INTEGER PRIMARY KEY,
        subject_id INTEGER,
        object_id INTEGER,
        type_id INTEGER,
        rank INTEGER
    )',
    'CREATE TABLE feature_dbxref (
        feature_id INTEGER,
        dbxref_id INTEGER,
        PRIMARY KEY(feature_id, dbxref_id)
    )',
    'CREATE TABLE organism (
        organism_id INTEGER PRIMARY KEY,
        genus VARCHAR(255),
        species VARCHAR(255)
    )',
    'CREATE TABLE protocol (
        protocol_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        version INTEGER,
        description TEXT,
        dbxref_id INTEGER
    )',
    'CREATE TABLE protocol_attribute (
        protocol_id  INTEGER,
        attribute_id INTEGER
    )',
    'CREATE TABLE wiggle_data (
        wiggle_data_id INTEGER PRIMARY KEY,
        name VARCHAR(255),
        type VARCHAR(255),
        visibility VARCHAR(255),
        color VARCHAR(255),
        altColor VARCHAR(255),
        priority VARCHAR(255),
        autoscale VARCHAR(255),
        gridDefault VARCHAR(255),
        maxHeightPixels VARCHAR(255),
        graphType VARCHAR(255),
        viewLimits VARCHAR(255),
        yLineMark VARCHAR(255),
        yLineOnOff VARCHAR(255),
        windowingFunction VARCHAR(255),
        smoothingWindow VARCHAR(255),
        data TEXT,
        datum_id INTEGER
    )',
    'CREATE TABLE data_wiggle_data (
        data_id INTEGER,
        wiggle_data_id INTEGER
    )',
  );
  foreach my $create_table (@create_tables) {
    ModENCODE::Cache::dbh->do($create_table) or croak "Failed to do: $create_table";
  }
}

sub destroy {
  foreach my $query (values(%queries)) {
    $query->finish if $query && $query->{Active};
  }
  $dbh->disconnect if ($dbh);
  foreach my $cacheset_name (keys(%cachesets)) {
    $cachesets{$cacheset_name} = undef;
  }
  if ($db_tempfile && -e $db_tempfile) {
    unlink($db_tempfile);
  }
}

############# DB ############### {
sub save_db {
  my $db = shift;
  $queries{'db_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO db (name, url, description) VALUES(?, ?, ?)') unless $queries{'db_ins'};
  $queries{'db_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE db SET name = ?, url = ?, description = ? WHERE db_id = ?') unless $queries{'db_upd'};
  modification_notification();
  if (!$db->get_id()) {
    $queries{'db_ins'}->execute($db->get_name, $db->get_url, $db->get_description);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $db->set_id($id);
    log_error "Saving db " . $db->get_name() . " with id $id.", "debug";
    return $id;
  } else {
    my $id = $db->get_id();
    $queries{'db_upd'}->execute($db->get_name, $db->get_url, $db->get_description, $id);
    log_error "Updating db " . $db->get_name() . " with id $id.", "debug";
    return $id;
  }
}

sub load_db {
  my $db_id = shift;
  $queries{'db_get'} = ModENCODE::Cache::dbh->prepare('SELECT db_id AS id, name, url, description FROM db WHERE db_id = ?') unless $queries{'db_get'};
  $queries{'db_get'}->execute($db_id);
  my $row = $queries{'db_get'}->fetchrow_hashref();
  my $db = ModENCODE::Chado::DB->new_no_cache($row);
  log_error "Loading DB " . $db->get_name . " from cache database (unshrinking).", "debug" if DEBUG;
  return $db;
}

sub get_cached_db {
  my $obj = shift;
  return $cachesets{'db'}->get_from_cache($obj->get_name);
}

sub update_db {
  my ($old_db, $new_db) = @_;
  croak "Can't use " . ref($old_db) . " as an old DB." unless $old_db->isa('ModENCODE::Chado::DB');
  croak "Can't use " . ref($new_db) . " as an new DB." unless $new_db->isa('ModENCODE::Chado::DB');
  $new_db->save unless $new_db->get_id;
  my @oldpath = ($old_db->get_name);
  my @newpath = ($new_db->get_name);
  my $cacheobj = $cachesets{'db'}->move_in_cache(\@oldpath, \@newpath, $new_db->get_id);
  $cacheobj->set_content($new_db);

  # Update DBXref cacheset to point at this DB
  my ($old_location, $new_location) = $cachesets{'dbxref'}->update_cache_to([ $old_db->get_id ], [ $new_db->get_id ]);
  foreach my $accession_key (keys(%$old_location)) {
    if (!$new_location->{$accession_key}) {
      # Move from old location to new location
      $new_location->{$accession_key} = $old_location->{$accession_key};
    } else {
      # Something already exists at the same key
      # For DBXrefs, this means a DBXref with the same accession ($accession_key)
      # since the cacheset looks like {$db_id}->{$accession}->{$version} = $dbxref
      foreach my $version_key (keys(%{$old_location->{$accession_key}})) {
        if (!$new_location->{$accession_key}->{$version_key}) {
          # If the versions are different, it's still a merge
          $new_location->{$accession_key}->{$version_key} = $old_location->{$accession_key}->{$version_key};
        } else {
          # The versions are the same, too; check and see if these are really the same DBXref but with different DBs
          my $in_place_dbxref = $new_location->{$accession_key}->{$version_key}->get_object;
          my $incoming_dbxref = $old_location->{$accession_key}->{$version_key}->get_object;
          if (
            $in_place_dbxref->get_accession eq $incoming_dbxref->get_accession &&
            $in_place_dbxref->get_version eq $incoming_dbxref->get_version &&
            $in_place_dbxref->get_db_id eq $old_db->get_id && $incoming_dbxref->get_db_id == $new_db->get_id
          ) {
            log_error "Replacing in_place_dbxref with incoming_dbxref because everything is the same except an out-of-date DB.", "debug";
            # Require that the existing one be reloaded as the new one, just in case
            $new_location->{$accession_key}->{$version_key}->set_content($old_location->{$accession_key}->{$version_key}->get_id);
            # Replace the existing one with the new one in the cache
            $new_location->{$accession_key}->{$version_key} = $old_location->{$accession_key}->{$version_key};
          }
        }
      }
    }
  }

  return $cacheobj;
}

sub add_db_to_cache {
  my $db = shift;
  $db->save unless $db->get_id;
  my $cacheobj = $cachesets{'db'}->add_to_cache(new ModENCODE::Cache::DB({'content' => $db }), $db->get_name);
  $cachesets{'db'}->add_to_id_cache($cacheobj, $db->get_id);
  return $cacheobj;
}
############# /DB ############### }
############# CV ############### {
sub load_cv {
  my $cv_id = shift;
  $queries{'cv_get'} = ModENCODE::Cache::dbh->prepare('SELECT cv_id AS id, name, definition FROM cv WHERE cv_id = ?') unless $queries{'cv_get'};
  $queries{'cv_get'}->execute($cv_id);
  my $row = $queries{'cv_get'}->fetchrow_hashref();
  my $cv = ModENCODE::Chado::CV->new_no_cache($row);
  log_error "Loading CV " . $cv->get_name . " from cache database (unshrinking).", "debug" if DEBUG;
  return $cv;
}

sub get_cached_cv {
  my $obj = shift;
  return $cachesets{'cv'}->get_from_cache($obj->get_name);
}

sub update_cv {
  my ($old_cv, $new_cv) = @_;
  croak "Can't use " . ref($old_cv) . " as an old CV." unless $old_cv->isa('ModENCODE::Chado::CV');
  croak "Can't use " . ref($new_cv) . " as an new CV." unless $new_cv->isa('ModENCODE::Chado::CV');
  $new_cv->save unless $new_cv->get_id;
  my @oldpath = ($old_cv->get_name);
  my @newpath = ($new_cv->get_name);
  my $cacheobj = $cachesets{'cv'}->move_in_cache(\@oldpath, \@newpath, $new_cv->get_id);
  $cacheobj->set_content($new_cv);

  # Update CVXref cacheset to point at this CV
  $cachesets{'cvterm'}->update_cache_to([ $old_cv->get_id ], [ $new_cv->get_id ]);
  # Update CVTerm cacheset to point at this CV
  my ($old_location, $new_location) = $cachesets{'cvterm'}->update_cache_to([ $old_cv->get_id ], [ $new_cv->get_id ]);
  foreach my $name_key (keys(%$old_location)) {
    if (!$new_location->{$name_key}) {
      # Move from old location to new location
      $new_location->{$name_key} = $old_location->{$name_key};
    } else {
      # Something already exists at the same key
      # For CVTerms, this means a DBXref with the same name ($name_key)
      # since the cacheset looks like {$cv_id}->{$name}->{$obsolete} = $cvterm
      foreach my $obsolete_key (keys(%{$old_location->{$name_key}})) {
        if (!$new_location->{$name_key}->{$obsolete_key}) {
          # If the obsoletes are different, it's still a merge
          $new_location->{$name_key}->{$obsolete_key} = $old_location->{$name_key}->{$obsolete_key};
        } else {
          # The obsoletes are the same, too; check and see if these are really the same DBXref but with different DBs
          my $in_place_cvterm = $new_location->{$name_key}->{$obsolete_key}->get_object;
          my $incoming_cvterm = $old_location->{$name_key}->{$obsolete_key}->get_object;
          if (
            $in_place_cvterm->get_name eq $incoming_cvterm->get_name &&
            $in_place_cvterm->get_is_obsolete eq $incoming_cvterm->get_is_obsolete &&
            $in_place_cvterm->get_cv_id eq $old_cv->get_id && $incoming_cvterm->get_cv_id == $new_cv->get_id
          ) {
            log_error "Replacing in_place_cvterm with incoming_cvterm because everything is the same except an out-of-date CV.", "debug";
            # Require that the existing one be reloaded as the new one, just in case
            $new_location->{$name_key}->{$obsolete_key}->set_content($old_location->{$name_key}->{$obsolete_key}->get_id);
            # Replace the existing one with the new one in the cache
            $new_location->{$name_key}->{$obsolete_key} = $old_location->{$name_key}->{$obsolete_key};
          }
        }
      }
    }
  }

  return $cacheobj;
}

sub add_cv_to_cache {
  my $cv = shift;
  $cv->save unless $cv->get_id;
  my $cacheobj = $cachesets{'cv'}->add_to_cache(new ModENCODE::Cache::CV({'content' => $cv }), $cv->get_name);
  $cachesets{'cv'}->add_to_id_cache($cacheobj, $cv->get_id);
  return $cacheobj;
}

sub save_cv {
  my $cv = shift;
  $queries{'cv_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO cv (name, definition) VALUES(?, ?)') unless $queries{'cv_ins'};
  $queries{'cv_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE cv SET name = ?, definition = ? WHERE cv_id = ?') unless $queries{'cv_upd'};
  modification_notification();
  if (!$cv->get_id()) {
    $queries{'cv_ins'}->execute($cv->get_name, $cv->get_definition);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $cv->set_id($id);
    log_error "Saving cv " . $cv->get_name() . " with id $id.", "debug";
    return $id;
  } else {
    my $id = $cv->get_id();
    $queries{'cv_upd'}->execute($cv->get_name, $cv->get_definition, $id);
    log_error "Updating cv " . $cv->get_name() . " with id $id.", "debug";
    return $id;
  }
}

############# /CV ############### }
############# DBXREF ########### {
sub add_dbxref_to_cache {
  my $dbxref = shift;
  $dbxref->save unless $dbxref->get_id;
  my $cacheobj = $cachesets{'dbxref'}->add_to_cache(new ModENCODE::Cache::DBXref({'content' => $dbxref }), $dbxref->get_db_id, $dbxref->get_accession, $dbxref->get_version);
  $cachesets{'dbxref'}->add_to_id_cache($cacheobj, $dbxref->get_id);
  return $cacheobj;
}

sub update_dbxref {
  my ($old_dbxref, $new_dbxref) = @_;
  croak "Can't use " . ref($old_dbxref) . " as an old DBXref." unless $old_dbxref->isa('ModENCODE::Chado::DBXref');
  croak "Can't use " . ref($new_dbxref) . " as an new DBXref." unless $new_dbxref->isa('ModENCODE::Chado::DBXref');
  $new_dbxref->save unless $new_dbxref->get_id;
  my @oldpath = ($old_dbxref->get_db_id, $old_dbxref->get_accession, $old_dbxref->get_version);
  my @newpath = ($new_dbxref->get_db_id, $new_dbxref->get_accession, $new_dbxref->get_version);
  my $cacheobj = $cachesets{'dbxref'}->move_in_cache(\@oldpath, \@newpath, $new_dbxref->get_id);
  $cacheobj->set_content($new_dbxref);
  return $cacheobj;
}


sub save_dbxref {
  my $dbxref = shift;
  $queries{'dbxref_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO dbxref (accession, version, db_id) VALUES(?, ?, ?)') unless $queries{'dbxref_ins'};
  $queries{'dbxref_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE dbxref SET accession = ?, version = ?, db_id = ? WHERE dbxref_id = ?') unless $queries{'dbxref_upd'};

  modification_notification();
  if (!$dbxref->get_id()) {
    $queries{'dbxref_ins'}->execute($dbxref->get_accession, $dbxref->get_version, $dbxref->get_db_id);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $dbxref->set_id($id);
    log_error "Saving dbxref " . $dbxref->get_accession() . " with id $id.", "debug" if DEBUG;
    return $id;
  } else {
    my $id = $dbxref->get_id();
    $queries{'dbxref_upd'}->execute($dbxref->get_accession, $dbxref->get_version, $dbxref->get_db_id, $id);
    log_error "Updating dbxref " . $dbxref->get_accession() . " with id $id.", "debug";
    return $id;
  }
}

sub get_cached_dbxref {
  my $obj = shift;
  return $cachesets{'dbxref'}->get_from_cache($obj->get_db_id, $obj->get_accession, $obj->get_version);
}

sub load_dbxref {
  my $dbxref_id = shift;
  $queries{'dbxref_get'} = ModENCODE::Cache::dbh->prepare('SELECT dbxref_id AS id, accession, version, db_id AS db FROM dbxref WHERE dbxref_id = ?') unless $queries{'dbxref_get'};
  $queries{'dbxref_get'}->execute($dbxref_id);
  my $row = $queries{'dbxref_get'}->fetchrow_hashref();
  $row->{'db'} = $cachesets{'db'}->get_from_id_cache($row->{'db'});
  my $dbxref = ModENCODE::Chado::DBXref->new_no_cache($row);
  $dbxref->clean();
  log_error "Loading DBXref " . $dbxref->get_accession . " from cache database (unshrinking).", "debug" if DEBUG;
  return $dbxref;
}
############# /DBXREF ########### }
############# CVTERM ########### {
sub add_cvterm_to_cache {
  my $cvterm = shift;
  $cvterm->save unless $cvterm->get_id;
  my $cacheobj = $cachesets{'cvterm'}->add_to_cache(new ModENCODE::Cache::CVTerm({'content' => $cvterm }), $cvterm->get_cv_id, $cvterm->get_name, $cvterm->get_is_obsolete);
  $cachesets{'cvterm'}->add_to_id_cache($cacheobj, $cvterm->get_id);
  return $cacheobj;
}

sub save_cvterm {
  my $cvterm = shift;
  $queries{'cvterm_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO cvterm (name, is_obsolete, definition, cv_id, dbxref_id) VALUES(?, ?, ?, ?, ?)') unless $queries{'cvterm_ins'};
  $queries{'cvterm_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE cvterm SET name = ?, is_obsolete = ?, definition = ?, cv_id = ?, dbxref_id = ? WHERE cvterm_id = ?') unless $queries{'cvterm_upd'};
  modification_notification();
  if (!$cvterm->get_id()) {
    $queries{'cvterm_ins'}->execute($cvterm->get_name, $cvterm->get_is_obsolete, $cvterm->get_definition, $cvterm->get_cv_id, $cvterm->get_dbxref_id);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $cvterm->set_id($id);
    log_error "Saving cvterm " . $cvterm->get_name() . " with id $id.", "debug";
    return $id;
  } else {
    my $id = $cvterm->get_id();
    $queries{'cvterm_upd'}->execute($cvterm->get_name, $cvterm->get_is_obsolete, $cvterm->get_definition, $cvterm->get_cv_id, $cvterm->get_dbxref_id, $id);
    log_error "Updating cvterm " . $cvterm->get_name() . " with id $id.", "debug";
    return $id;
  }
}

sub get_cached_cvterm {
  my $obj = shift;
  return $cachesets{'cvterm'}->get_from_cache($obj->get_cv_id, $obj->get_name, $obj->get_is_obsolete);
}

sub load_cvterm {
  my $cvterm_id = shift;
  $queries{'cvterm_get'} = ModENCODE::Cache::dbh->prepare('SELECT cvterm_id AS id, name, is_obsolete, definition, cv_id AS cv, dbxref_id AS dbxref FROM cvterm WHERE cvterm_id = ?') unless $queries{'cvterm_get'};
  $queries{'cvterm_get'}->execute($cvterm_id);
  my $row = $queries{'cvterm_get'}->fetchrow_hashref();
  $row->{'cv'} = $cachesets{'cv'}->get_from_id_cache($row->{'cv'});
  $row->{'dbxref'} = $cachesets{'dbxref'}->get_from_id_cache($row->{'dbxref'});
  my $cvterm = ModENCODE::Chado::CVTerm->new_no_cache($row);
  log_error "Loading cvterm " . $cvterm->get_name . " from cache database (unshrinking).", "debug" if DEBUG;
  return $cvterm;
}
############# /CVTERM ########### }
############# EXPERIMENTPROP ### {
sub add_experimentprop_to_cache {
  my $experimentprop = shift;
  $experimentprop->save unless $experimentprop->get_id;
  my $cacheobj = $cachesets{'experimentprop'}->add_to_cache(new ModENCODE::Cache::ExperimentProp({'content' => $experimentprop }), $experimentprop->get_experiment_id, $experimentprop->get_name, $experimentprop->get_rank);
  $cachesets{'experimentprop'}->add_to_id_cache($cacheobj, $experimentprop->get_id);
  return $cacheobj;
}

sub save_experimentprop {
  my $experimentprop = shift;
  $queries{'experimentprop_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO experimentprop (name, value, rank, termsource_id, type_id, experiment_id) VALUES(?, ?, ?, ?, ?, ?)') unless $queries{'experimentprop_ins'};
  $queries{'experimentprop_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE experimentprop SET name = ?, value = ?, rank = ?, termsource_id = ?, type_id = ?, experiment_id = ? WHERE experimentprop_id = ?') unless $queries{'experimentprop_upd'};
  modification_notification();
  if (!$experimentprop->get_id()) {
    $queries{'experimentprop_ins'}->execute($experimentprop->get_name, $experimentprop->get_value, $experimentprop->get_rank, $experimentprop->get_termsource_id, $experimentprop->get_type_id, $experimentprop->get_experiment_id);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $experimentprop->set_id($id);
    log_error "Saving experimentprop " . $experimentprop->get_name() . " with id $id.", "debug";
    return $id;
  } else {
    my $id = $experimentprop->get_id();
    $queries{'experimentprop_upd'}->execute($experimentprop->get_name, $experimentprop->get_value, $experimentprop->get_rank, $experimentprop->get_termsource_id, $experimentprop->get_type_id, $experimentprop->get_experiment_id, $id);
    log_error "Updating experimentprop " . $experimentprop->get_name() . " with id $id.", "debug";
    return $id;
  }
}

sub get_cached_experimentprop {
  my $obj = shift;
  return $cachesets{'experimentprop'}->get_from_cache($obj->get_experiment_id, $obj->get_name, $obj->get_rank);
}

sub load_experimentprop {
  my $experimentprop_id = shift;
  $queries{'experimentprop_get'} = ModENCODE::Cache::dbh->prepare('SELECT experimentprop_id AS id, name, value, rank, termsource_id AS termsource, type_id AS type, experiment_id AS experiment FROM experimentprop WHERE experimentprop_id = ?') unless $queries{'experimentprop_get'};
  $queries{'experimentprop_get'}->execute($experimentprop_id);
  my $row = $queries{'experimentprop_get'}->fetchrow_hashref();
  $row->{'termsource'} = $cachesets{'dbxref'}->get_from_id_cache($row->{'termsource'});
  $row->{'type'} = $cachesets{'cvterm'}->get_from_id_cache($row->{'type'});
  $row->{'experiment'} = $cachesets{'experiment'}->get_from_id_cache($row->{'experiment'});
  my $experimentprop = ModENCODE::Chado::ExperimentProp->new_no_cache($row);
  log_error "Loading ExperimentProp " . $experimentprop->get_name . " from cache database (unshrinking).", "debug" if DEBUG;
  return $experimentprop;
}
############# /EXPERIMENTPROP ## }
############# EXPERIMENT ####### {

# Note that there is only ever one cached experiment at a time, and since
# an experiment doesn't have to have any fields filled it at the beginning,
# we just use "1" as the index into the cache
sub add_experiment_to_cache {
  my $experiment = shift;
  $experiment->save unless $experiment->get_id;
  my $cacheobj = $cachesets{'experiment'}->add_to_cache(new ModENCODE::Cache::Experiment({'content' => $experiment }), 1);
  $cachesets{'experiment'}->add_to_id_cache($cacheobj, $experiment->get_id);
  return $cacheobj;
}

sub save_experiment {
  my $experiment = shift;
  $queries{'experiment_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO experiment (uniquename, description) VALUES(?, ?)') unless $queries{'experiment_ins'};
  $queries{'experiment_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE experiment SET uniquename = ?, description = ? WHERE experiment_id = ?') unless $queries{'experiment_upd'};
  modification_notification();
  if (!$experiment->get_id()) {
    $queries{'experiment_ins'}->execute($experiment->get_uniquename, $experiment->get_description);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $experiment->set_id($id);
    log_error "Saving experiment " . $experiment->get_uniquename() . " with id $id.", "debug";
    return $id;
  } else {
    my $id = $experiment->get_id();
    $queries{'experiment_upd'}->execute($experiment->get_uniquename, $experiment->get_description, $id);
    log_error "Updating experiment " . $experiment->get_uniquename() . " with id $id.", "debug";
    return $id;
  }
}

sub get_cached_experiment {
  my $obj = shift;
  return $cachesets{'experiment'}->get_from_cache(1);
}

sub load_experiment {
  my $experiment_id = shift;
  $queries{'experiment_get'} = ModENCODE::Cache::dbh->prepare('SELECT experiment_id AS id, uniquename FROM experiment WHERE experiment_id = ?') unless $queries{'experiment_get'};
  $queries{'experiment_get'}->execute($experiment_id);
  my $row = $queries{'experiment_get'}->fetchrow_hashref();
  my $experiment = ModENCODE::Chado::Experiment->new_no_cache($row);
  log_error "Loading Experiment " . $experiment->get_uniquename . " from cache database (unshrinking).", "debug" if DEBUG;
  return $experiment;
}
############# /EXPERIMENT ###### }
############# PROTOCOL ######### {
sub add_protocol_to_cache {
  my $protocol = shift;
  $protocol->save unless $protocol->get_id;
  my $cacheobj = $cachesets{'protocol'}->add_to_cache(new ModENCODE::Cache::Protocol({'content' => $protocol }), $protocol->get_name);
  $cachesets{'protocol'}->add_to_id_cache($cacheobj, $protocol->get_id);
  return $cacheobj;
}

sub save_protocol {
  my $protocol = shift;
  $queries{'protocol_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO protocol (name, version, description, dbxref_id) VALUES(?, ?, ?, ?)') unless $queries{'protocol_ins'};
  $queries{'protocol_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE protocol SET name = ?, version = ?, description = ?, dbxref_id = ? WHERE protocol_id = ?') unless $queries{'protocol_upd'};
  $queries{'get_protocol_attributes'} = ModENCODE::Cache::dbh->prepare('SELECT attribute_id FROM protocol_attribute WHERE attribute_id = ?') unless $queries{'get_protocol_attributes'};
  $queries{'del_protocol_attributes'} = ModENCODE::Cache::dbh->prepare('DELETE FROM protocol_attribute WHERE protocol_id = ?') unless $queries{'del_protocol_attributes'};
  $queries{'add_protocol_attribute'} = ModENCODE::Cache::dbh->prepare('INSERT INTO protocol_attribute (protocol_id, attribute_id) VALUES(?, ?)') unless $queries{'add_protocol_attribute'};
  modification_notification();
  if (!$protocol->get_id()) {
    $queries{'protocol_ins'}->execute($protocol->get_name, $protocol->get_version, $protocol->get_description, $protocol->get_termsource_id);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $protocol->set_id($id);
    log_error "Saving protocol " . $protocol->get_name() . " with id $id.", "debug";
  } else {
    my $id = $protocol->get_id();
    $queries{'protocol_upd'}->execute($protocol->get_name, $protocol->get_version, $protocol->get_description, $protocol->get_termsource_id, $id);
    log_error "Updating protocol " . $protocol->get_name() . " with id $id.", "debug";
  }
  # Update links to protocol attributes
  $queries{'del_protocol_attributes'}->execute($protocol->get_id);
  foreach my $attribute_id ($protocol->get_attribute_ids) {
    modification_notification();
    $queries{'add_protocol_attribute'}->execute($protocol->get_id, $attribute_id);
  }

  return $protocol->get_id;
}

sub get_cached_protocol {
  my $obj = shift;
  return $cachesets{'protocol'}->get_from_cache($obj->get_name);
}

sub load_protocol {
  my $protocol_id = shift;
  $queries{'protocol_get'} = ModENCODE::Cache::dbh->prepare('SELECT protocol_id AS id, name, version, description, dbxref_id AS termsource FROM protocol WHERE protocol_id = ?') unless $queries{'protocol_get'};
  $queries{'protocol_get'}->execute($protocol_id);
  $queries{'protocol_attributes_get'} = ModENCODE::Cache::dbh->prepare('SELECT attribute_id FROM protocol_attribute WHERE protocol_id = ?') unless $queries{'protocol_attributes_get'};
  my $row = $queries{'protocol_get'}->fetchrow_hashref();
  $row->{'dbxref'} = $cachesets{'dbxref'}->get_from_id_cache($row->{'dbxref'});
  my $protocol = ModENCODE::Chado::Protocol->new_no_cache($row);
  log_error "Loading protocol " . $protocol->get_name . " from cache database (unshrinking).", "debug" if DEBUG;
  
  $queries{'protocol_attributes_get'}->execute($protocol_id);
  my @attribute_ids;
  while (my ($attribute_id) = $queries{'protocol_attributes_get'}->fetchrow_array()) {
    push @attribute_ids, $cachesets{'protocol_attribute'}->get_from_id_cache($protocol_id, $attribute_id);
  }
  $protocol->set_attributes(\@attribute_ids);
  return $protocol;
}
############# /PROTOCOL ######### }
############# ORGANISM ############### {
sub load_organism {
  my $organism_id = shift;
  $queries{'organism_get'} = ModENCODE::Cache::dbh->prepare('SELECT organism_id AS id, genus, species FROM organism WHERE organism_id = ?') unless $queries{'organism_get'};
  $queries{'organism_get'}->execute($organism_id);
  my $row = $queries{'organism_get'}->fetchrow_hashref();
  my $organism = ModENCODE::Chado::Organism->new_no_cache($row);
  log_error "Loading organism " . $organism->get_genus . " " . $organism->get_species . " from cache database (unshrinking).", "debug" if DEBUG;
  return $organism;
}

sub get_cached_organism {
  my $obj = shift;
  return $cachesets{'organism'}->get_from_cache($obj->get_genus, $obj->get_species);
}

sub add_organism_to_cache {
  my $organism = shift;
  $organism->save unless $organism->get_id;
  my $cacheobj = $cachesets{'organism'}->add_to_cache(new ModENCODE::Cache::Organism({'content' => $organism }), $organism->get_genus, $organism->get_species);
  $cachesets{'organism'}->add_to_id_cache($cacheobj, $organism->get_id);
  return $cacheobj;
}

sub save_organism {
  my $organism = shift;
  $queries{'organism_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO organism (genus, species) VALUES(?, ?)') unless $queries{'organism_ins'};
  $queries{'organism_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE organism SET genus = ?, species = ? WHERE organism_id = ?') unless $queries{'organism_upd'};
  modification_notification();
  if (!$organism->get_id()) {
    $queries{'organism_ins'}->execute($organism->get_genus, $organism->get_species);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $organism->set_id($id);
    log_error "Saving organism " . $organism->get_genus() . " " . $organism->get_species() . " with id $id.", "debug";
    return $id;
  } else {
    my $id = $organism->get_id();
    $queries{'organism_upd'}->execute($organism->get_genus, $organism->get_species, $id);
    log_error "Updating organism " . $organism->get_genus() . " " . $organism->get_species() . " with id $id.", "debug";
    return $id;
  }
}

############# /ORGANISM ############### }
############# ATTRIBUTE ######## {
sub save_attribute {
  my $attribute = shift;
  $queries{'attribute_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO attribute (heading, name, value, rank, termsource_id, type_id) VALUES(?, ?, ?, ?, ?, ?)') unless $queries{'attribute_ins'};
  $queries{'attribute_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE attribute SET heading = ?, name = ?, value = ?, rank = ?, termsource_id = ?, type_id = ? WHERE attribute_id = ?') unless $queries{'attribute_upd'};
  $queries{'del_attribute_organisms'} = ModENCODE::Cache::dbh->prepare('DELETE FROM attribute_organism WHERE attribute_id = ?') unless $queries{'del_attribute_organisms'};
  $queries{'add_attribute_organisms'} = ModENCODE::Cache::dbh->prepare('INSERT INTO attribute_organism (attribute_id, organism_id) VALUES(?, ?)') unless $queries{'add_attribute_organisms'};
  modification_notification();
  if (!$attribute->get_id()) {
    $queries{'attribute_ins'}->execute($attribute->get_heading, $attribute->get_name, $attribute->get_value, $attribute->get_rank, $attribute->get_termsource_id, $attribute->get_type_id);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $attribute->set_id($id);
    log_error "Saving attribute " . $attribute->get_heading . " [" . $attribute->get_name() . "] with " . ($attribute->get_termsource(1) ? $attribute->get_termsource(1)->get_accession : '#') . " id $id.", "debug";
    $queries{'del_attribute_organisms'}->execute($attribute->get_id);
    foreach my $organism_id ($attribute->get_organism_ids) {
      $queries{'add_attribute_organisms'}->execute($attribute->get_id, $organism_id);
    }
    return $id;
  } else {
    my $id = $attribute->get_id();
    $queries{'attribute_upd'}->execute($attribute->get_heading, $attribute->get_name, $attribute->get_value, $attribute->get_rank, $attribute->get_termsource_id, $attribute->get_type_id, $id);
    log_error "Updating attribute " . $attribute->get_heading . " [" . $attribute->get_name() . "], " . ($attribute->get_termsource(1) ? $attribute->get_termsource(1)->get_accession : '#') . " with id $id.", "debug";
    $queries{'del_attribute_organisms'}->execute($attribute->get_id);
    foreach my $organism_id ($attribute->get_organism_ids) {
      modification_notification();
      $queries{'add_attribute_organisms'}->execute($attribute->get_id, $organism_id);
    }
    return $id;
  }
}

############# /ATTRIBUTE ######## }
###### PROTOCOL ATTRIBUTE ####### {
sub add_protocol_attribute_to_cache {
  my $protocol_attribute = shift;
  # Ugly hack to index by protocol & attribute
  $protocol_attribute->save unless $protocol_attribute->get_id;
  my $attr_id = $protocol_attribute->get_id;
  my $protocol_id = $protocol_attribute->get_protocol_id;
  my $cached_attr = $cachesets{'protocol_attribute'}->add_to_cache(new ModENCODE::Cache::ProtocolAttribute({'content' => $protocol_attribute }), $protocol_attribute->get_protocol_id, $protocol_attribute->get_heading, $protocol_attribute->get_name, $protocol_attribute->get_rank);
  $cachesets{'protocol_attribute'}->add_to_id_cache($cached_attr, $protocol_id, $attr_id);
  $protocol_attribute->save;
  return $cached_attr;
}

sub save_protocol_attribute {
  my $protocol_attribute = shift;

  my $attr_id = save_attribute($protocol_attribute);
  my $protocol_id = $protocol_attribute->get_protocol_id();

  $queries{'del_protocol_attribute'} = ModENCODE::Cache::dbh->prepare('DELETE FROM protocol_attribute WHERE protocol_id = ? AND attribute_id = ?') unless $queries{'del_protocol_attribute'};
  $queries{'ins_protocol_attribute'} = ModENCODE::Cache::dbh->prepare('INSERT INTO protocol_attribute (protocol_id, attribute_id) VALUES(?, ?)') unless $queries{'ins_protocol_attribute'};
  modification_notification();
  $queries{'del_protocol_attribute'}->execute($protocol_id, $attr_id);
  modification_notification();
  $queries{'ins_protocol_attribute'}->execute($protocol_id, $attr_id);

  return $attr_id;
}

sub get_cached_protocol_attribute {
  my $obj = shift;
  return $cachesets{'protocol_attribute'}->get_from_cache($obj->get_protocol_id, $obj->get_heading, $obj->get_name, $obj->get_rank);
}

sub load_protocol_attribute {
  my $protocol_attribute_id = shift;
  $queries{'protocol_attribute_get'} = ModENCODE::Cache::dbh->prepare('SELECT attribute_id AS id, heading, name, value, rank, termsource_id AS termsource, type_id AS type FROM attribute WHERE attribute_id = ?') unless $queries{'protocol_attribute_get'};
  $queries{'protocol_attribute_organisms_get'} = ModENCODE::Cache::dbh->prepare('SELECT organism_id FROM attribute_organism WHERE attribute_id = ?') unless $queries{'protocol_attribute_organisms_get'};
  $queries{'protocol_attribute_protocol_get'} = ModENCODE::Cache::dbh->prepare('SELECT protocol_id FROM protocol_attribute WHERE attribute_id = ?') unless $queries{'protocol_attribute_protocol_get'};
  $queries{'protocol_attribute_get'}->execute($protocol_attribute_id);
  my $row = $queries{'protocol_attribute_get'}->fetchrow_hashref();

  $row->{'termsource'} = $cachesets{'dbxref'}->get_from_id_cache($row->{'termsource'});
  $row->{'type'} = $cachesets{'cvterm'}->get_from_id_cache($row->{'type'});

  $queries{'protocol_attribute_protocol_get'}->execute($protocol_attribute_id);
  my ($protocol_id) = $queries{'protocol_attribute_protocol_get'}->fetchrow_array();
  $row->{'protocol'} = $cachesets{'protocol'}->get_from_id_cache($protocol_id);

  my $protocol_attribute = ModENCODE::Chado::ProtocolAttribute->new_no_cache($row);
  log_error "Loading protocol_attribute " . $protocol_attribute->get_heading . " [" . $protocol_attribute->get_name . "] from cache database (unshrinking).", "debug" if DEBUG;
  $queries{'protocol_attribute_organisms_get'}->execute($protocol_attribute_id);
  my @organism_ids;
  while (my ($organism_id) = $queries{'protocol_attribute_organisms_get'}->fetchrow_array()) {
    push @organism_ids, $cachesets{'organism'}->get_from_id_cache($organism_id);
  }
  $protocol_attribute->set_organisms(\@organism_ids);

  return $protocol_attribute;
}
###### /PROTOCOL ATTRIBUTE ####### }
###### DATUM ATTRIBUTE ####### {
sub add_datum_attribute_to_cache {
  my $datum_attribute = shift;
  $datum_attribute->save unless $datum_attribute->get_id;
  # Ugly hack to index by datum & attribute
  my $attr_id = $datum_attribute->get_id;
  my $datum_id = $datum_attribute->get_datum_id;
  my $cached_attr = $cachesets{'datum_attribute'}->add_to_cache(new ModENCODE::Cache::DatumAttribute({'content' => $datum_attribute }), $datum_attribute->get_datum_id, $datum_attribute->get_heading, $datum_attribute->get_name, $datum_attribute->get_rank);
  $cachesets{'datum_attribute'}->add_to_id_cache($cached_attr, $datum_id, $attr_id);
  return $cached_attr;
}

sub save_datum_attribute {
  my $datum_attribute = shift;

  if (!$datum_attribute->get_id()) {
    my $attr_id = save_attribute($datum_attribute);
    my $datum_id = $datum_attribute->get_datum_id();
    modification_notification();
    $queries{'ins_datum_attribute'} = ModENCODE::Cache::dbh->prepare('INSERT INTO data_attribute (data_id, attribute_id) VALUES(?, ?)') unless $queries{'ins_datum_attribute'};
    $queries{'ins_datum_attribute'}->execute($datum_id, $attr_id);
    return $attr_id;
  } else {
    my $attr_id = save_attribute($datum_attribute);
    return $attr_id;
  }
}

sub get_cached_datum_attribute {
  my $obj = shift;
  return $cachesets{'datum_attribute'}->get_from_cache($obj->get_datum_id, $obj->get_heading, $obj->get_name, $obj->get_rank);
}

sub load_datum_attribute {
  my $datum_attribute_id = shift;
  $queries{'datum_attribute_get'} = ModENCODE::Cache::dbh->prepare('SELECT attribute_id AS id, heading, name, value, rank, termsource_id AS termsource, type_id AS type FROM attribute WHERE attribute_id = ?') unless $queries{'datum_attribute_get'};
  $queries{'datum_attribute_organisms_get'} = ModENCODE::Cache::dbh->prepare('SELECT organism_id FROM attribute_organism WHERE attribute_id = ?') unless $queries{'datum_attribute_organisms_get'};
  $queries{'datum_attribute_datum_get'} = ModENCODE::Cache::dbh->prepare('SELECT data_id FROM data_attribute WHERE attribute_id = ?') unless $queries{'datum_attribute_datum_get'};
  $queries{'datum_attribute_get'}->execute($datum_attribute_id);
  my $row = $queries{'datum_attribute_get'}->fetchrow_hashref();

  $row->{'termsource'} = $cachesets{'dbxref'}->get_from_id_cache($row->{'termsource'});
  $row->{'type'} = $cachesets{'cvterm'}->get_from_id_cache($row->{'type'});

  $queries{'datum_attribute_datum_get'}->execute($datum_attribute_id);
  my ($datum_id) = $queries{'datum_attribute_datum_get'}->fetchrow_array();
  $row->{'datum'} = new ModENCODE::Cache::Data({'content' => $datum_id}) if $datum_id;

  my $datum_attribute = ModENCODE::Chado::DatumAttribute->new_no_cache($row);
  log_error "Loading datum_attribute " . $datum_attribute->get_name . " from cache database (unshrinking).", "debug" if DEBUG;
  $queries{'datum_attribute_organisms_get'}->execute($datum_attribute_id);
  my @organism_ids;
  while (my ($organism_id) = $queries{'datum_attribute_organisms_get'}->fetchrow_array()) {
    push @organism_ids, new ModENCODE::Cache::Organism({'content' => $organism_id });
  }
  $datum_attribute->set_organisms(\@organism_ids);

  return $datum_attribute;
}
###### /DATUM ATTRIBUTE ####### }
############# DATA ############# {
sub add_datum_to_cache {
  my $datum = shift;
  $datum->save unless $datum->get_id;
  my $cacheobj = $cachesets{'data'}->add_to_cache(new ModENCODE::Cache::Data({'content' => $datum }), $datum->get_heading, $datum->get_name, $datum->get_value);
  $cachesets{'data'}->add_to_id_cache($cacheobj, $datum->get_id);
  return $cacheobj;
}

sub update_datum {
  my ($old_datum, $new_datum) = @_;
  croak "Can't use " . ref($old_datum) . " as an old datum." unless $old_datum->isa('ModENCODE::Chado::Data');
  croak "Can't use " . ref($new_datum) . " as an new datum." unless $new_datum->isa('ModENCODE::Chado::Data');
  $new_datum->save unless $new_datum->get_id;
  my @oldpath = ($old_datum->get_heading, $old_datum->get_name, $old_datum->get_value);
  my @newpath = ($new_datum->get_heading, $new_datum->get_name, $new_datum->get_value);
  my $cacheobj = $cachesets{'data'}->move_in_cache(\@oldpath, \@newpath, $new_datum->get_id);
  $cacheobj->set_content($new_datum);
}

sub save_datum {
  my $datum = shift;
  $queries{'datum_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO data (heading, name, value, anonymous, termsource_id, type_id) VALUES(?, ?, ?, ?, ?, ?)') unless $queries{'datum_ins'};
  $queries{'datum_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE data SET heading = ?, name = ?, value = ?, anonymous = ?, termsource_id = ?, type_id = ? WHERE data_id = ?') unless $queries{'datum_upd'};
  $queries{'del_datum_attributes'} = ModENCODE::Cache::dbh->prepare('DELETE FROM data_attribute WHERE data_id = ?') unless $queries{'del_datum_attributes'};
  $queries{'add_datum_attributes'} = ModENCODE::Cache::dbh->prepare('INSERT INTO data_attribute (data_id, attribute_id) VALUES(?, ?)') unless $queries{'add_datum_attributes'};
  $queries{'del_datum_features'} = ModENCODE::Cache::dbh->prepare('DELETE FROM data_feature WHERE data_id = ?') unless $queries{'del_datum_features'};
  $queries{'add_datum_features'} = ModENCODE::Cache::dbh->prepare('INSERT INTO data_feature (data_id, feature_id) VALUES(?, ?)') unless $queries{'add_datum_features'};
  $queries{'del_datum_wiggle_datas'} = ModENCODE::Cache::dbh->prepare('DELETE FROM data_wiggle_data WHERE data_id = ?') unless $queries{'del_datum_wiggle_datas'};
  $queries{'add_datum_wiggle_datas'} = ModENCODE::Cache::dbh->prepare('INSERT INTO data_wiggle_data (data_id, wiggle_data_id) VALUES(?, ?)') unless $queries{'add_datum_wiggle_datas'};
  $queries{'del_datum_organisms'} = ModENCODE::Cache::dbh->prepare('DELETE FROM data_organism WHERE data_id = ?') unless $queries{'del_datum_organisms'};
  $queries{'add_datum_organisms'} = ModENCODE::Cache::dbh->prepare('INSERT INTO data_organism (data_id, organism_id) VALUES(?, ?)') unless $queries{'add_datum_organisms'};
  if (!$datum->get_id()) {
    modification_notification();
    $queries{'datum_ins'}->execute($datum->get_heading, $datum->get_name, $datum->get_value, $datum->is_anonymous, $datum->get_termsource_id, $datum->get_type_id);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $datum->set_id($id);
    log_error "Saving datum " . $datum->get_heading . "[" . $datum->get_name . "] with id $id.", "debug";
    $queries{'del_datum_attributes'}->execute($datum->get_id);
    foreach my $attribute_id ($datum->get_attribute_ids) {
      modification_notification();
      $queries{'add_datum_attributes'}->execute($datum->get_id, $attribute_id);
    }
    $queries{'del_datum_features'}->execute($datum->get_id);
    foreach my $feature_id ($datum->get_feature_ids) {
      modification_notification();
      $queries{'add_datum_features'}->execute($datum->get_id, $feature_id);
    }
    $queries{'del_datum_wiggle_datas'}->execute($datum->get_id);
    foreach my $wiggle_data_id ($datum->get_wiggle_data_ids) {
      modification_notification();
      $queries{'add_datum_wiggle_datas'}->execute($datum->get_id, $wiggle_data_id);
    }
    $queries{'del_datum_organisms'}->execute($datum->get_id);
    foreach my $organism_id ($datum->get_organism_ids) {
      modification_notification();
      $queries{'add_datum_organisms'}->execute($datum->get_id, $organism_id);
    }
    return $id;
  } else {
    my $id = $datum->get_id();
    $queries{'datum_upd'}->execute($datum->get_heading, $datum->get_name, $datum->get_value, $datum->is_anonymous, $datum->get_termsource_id, $datum->get_type_id, $id);
    log_error "Updating datum " . $datum->get_name() . " with id $id.", "debug";
    $queries{'del_datum_attributes'}->execute($datum->get_id);
    modification_notification();
    foreach my $attribute_id ($datum->get_attribute_ids) {
      modification_notification();
      $queries{'add_datum_attributes'}->execute($datum->get_id, $attribute_id);
    }
    $queries{'del_datum_features'}->execute($datum->get_id);
    foreach my $feature_id ($datum->get_feature_ids) {
      modification_notification();
      $queries{'add_datum_features'}->execute($datum->get_id, $feature_id);
    }
    $queries{'del_datum_wiggle_datas'}->execute($datum->get_id);
    foreach my $wiggle_data_id ($datum->get_wiggle_data_ids) {
      modification_notification();
      $queries{'add_datum_wiggle_datas'}->execute($datum->get_id, $wiggle_data_id);
    }
    $queries{'del_datum_organisms'}->execute($datum->get_id);
    foreach my $organism_id ($datum->get_organism_ids) {
      modification_notification();
      $queries{'add_datum_organisms'}->execute($datum->get_id, $organism_id);
    }
    return $id;
  }
}

sub get_cached_datum {
  my $obj = shift;
  return $cachesets{'data'}->get_from_cache($obj->get_heading, $obj->get_name, $obj->get_value);
}

sub load_datum {
  my $datum_id = shift;
  $queries{'datum_get'} = ModENCODE::Cache::dbh->prepare('SELECT data_id AS id, heading, name, value, anonymous, termsource_id AS termsource, type_id AS type FROM data WHERE data_id = ?') unless $queries{'datum_get'};
  $queries{'datum_attributes_get'} = ModENCODE::Cache::dbh->prepare('SELECT attribute_id FROM data_attribute WHERE data_id = ?') unless $queries{'datum_attributes_get'};
  $queries{'datum_features_get'} = ModENCODE::Cache::dbh->prepare('SELECT feature_id FROM data_feature WHERE data_id = ?') unless $queries{'datum_features_get'};
  $queries{'datum_wiggle_datas_get'} = ModENCODE::Cache::dbh->prepare('SELECT wiggle_data_id FROM data_wiggle_data WHERE data_id = ?') unless $queries{'datum_wiggle_datas_get'};
  $queries{'datum_organisms_get'} = ModENCODE::Cache::dbh->prepare('SELECT organism_id FROM data_organism WHERE data_id = ?') unless $queries{'datum_organisms_get'};
  $queries{'datum_get'}->execute($datum_id);
  my $row = $queries{'datum_get'}->fetchrow_hashref();

  $row->{'termsource'} = $cachesets{'dbxref'}->get_from_id_cache($row->{'termsource'});
  $row->{'type'} = $cachesets{'cvterm'}->get_from_id_cache($row->{'type'});

  my $datum = ModENCODE::Chado::Data->new_no_cache($row);
  log_error "Loading datum " . $datum->get_heading . " from cache database (unshrinking).", "debug" if DEBUG;
  $queries{'datum_organisms_get'}->execute($datum_id);
  my @attribute_ids;
  while (my ($attribute_id) = $queries{'datum_attributes_get'}->fetchrow_array()) {
    push @attribute_ids, $cachesets{'datum_attribute'}->get_from_id_cache($datum_id, $attribute_id);
  }
  $datum->set_attributes(\@attribute_ids);
  my @feature_ids;
  while (my ($feature_id) = $queries{'datum_features_get'}->fetchrow_array()) {
    push @feature_ids, new ModENCODE::Cache::CVTerm({'content' => $feature_id });
  }
  $datum->set_features(\@feature_ids);
  my @wiggle_data_ids;
  while (my ($wiggle_data_id) = $queries{'datum_wiggle_datas_get'}->fetchrow_array()) {
    push @wiggle_data_ids, new ModENCODE::Cache::CVTerm({'content' => $wiggle_data_id });
  }
  $datum->set_wiggle_datas(\@wiggle_data_ids);
  my @organism_ids;
  while (my ($organism_id) = $queries{'datum_organisms_get'}->fetchrow_array()) {
    push @organism_ids, new ModENCODE::Cache::Organism({'content' => $organism_id });
  }
  $datum->set_organisms(\@organism_ids);

  return $datum;
}
############# /DATA ############# }
###### WIGGLE DATA ####### {
sub add_wiggle_data_to_cache {
  my $wiggle_data = shift;
  $wiggle_data->save unless $wiggle_data->get_id;
  # Ugly hack to index by datum & wiggle_data
  my $wiggle_data_id = $wiggle_data->get_id;
  my $datum_id = $wiggle_data->get_datum_id;
  my $cached_wiggle_data = $cachesets{'wiggle_data'}->add_to_cache(new ModENCODE::Cache::Wiggle_Data({'content' => $wiggle_data }), $wiggle_data->get_datum_id, $wiggle_data->get_name);
  $cachesets{'wiggle_data'}->add_to_id_cache($cached_wiggle_data, $datum_id, $wiggle_data_id);
  return $cached_wiggle_data;
}

sub save_wiggle_data {
  my $wiggle_data = shift;

  $queries{'wiggle_data_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO wiggle_data (
    datum_id, name, type, visibility, color, altColor, priority, autoscale, gridDefault, maxHeightPixels, graphType, viewLimits, yLineMark, yLineOnOff, windowingFunction, smoothingWindow, data
    ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)') unless $queries{'wiggle_data_ins'};
  $queries{'wiggle_data_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE wiggle_data SET 
    datum_id = ?, name = ?, type = ?, visibility = ?, color = ?, altColor = ?, priority = ?, autoscale = ?, gridDefault = ?, maxHeightPixels = ?, graphType = ?, viewLimits = ?, yLineMark = ?, yLineOnOff = ?, windowingFunction = ?, smoothingWindow = ?, data = ?
    WHERE wiggle_data_id = ?') unless $queries{'wiggle_data_upd'};

  modification_notification();
  if (!$wiggle_data->get_id()) {
    $queries{'wiggle_data_ins'}->execute(
      $wiggle_data->get_datum_id, $wiggle_data->get_name, $wiggle_data->get_type, $wiggle_data->get_visibility, $wiggle_data->get_color, $wiggle_data->get_altColor, $wiggle_data->get_priority, $wiggle_data->get_autoscale, $wiggle_data->get_gridDefault, $wiggle_data->get_maxHeightPixels, $wiggle_data->get_graphType, $wiggle_data->get_viewLimits, $wiggle_data->get_yLineMark, $wiggle_data->get_yLineOnOff, $wiggle_data->get_windowingFunction, $wiggle_data->get_smoothingWindow, $wiggle_data->get_data
    );
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $wiggle_data->set_id($id);
    log_error "Saving wiggle_data " . $wiggle_data->get_name . " with id $id.", "debug";

    modification_notification();
    $queries{'ins_wiggle_data'} = ModENCODE::Cache::dbh->prepare('INSERT INTO data_wiggle_data (data_id, wiggle_data_id) VALUES(?, ?)') unless $queries{'ins_wiggle_data'};
    $queries{'ins_wiggle_data'}->execute($wiggle_data->get_datum_id, $id);

    return $id;
  } else {
    my $id = $wiggle_data->get_id();
    $queries{'wiggle_data_upd'}->execute(
      $wiggle_data->get_datum_id, $wiggle_data->get_name, $wiggle_data->get_type, $wiggle_data->get_visibility, $wiggle_data->get_color, $wiggle_data->get_altColor, $wiggle_data->get_priority, $wiggle_data->get_autoscale, $wiggle_data->get_gridDefault, $wiggle_data->get_maxHeightPixels, $wiggle_data->get_graphType, $wiggle_data->get_viewLimits, $wiggle_data->get_yLineMark, $wiggle_data->get_yLineOnOff, $wiggle_data->get_windowingFunction, $wiggle_data->get_smoothingWindow, $wiggle_data->get_data, $id
    );
    log_error "Updating wiggle_data " . $wiggle_data->get_name . " with id $id.", "debug";
    return $id;
  }
}

sub get_cached_wiggle_data {
  my $obj = shift;
  return $cachesets{'wiggle_data'}->get_from_cache($obj->get_datum_id, $obj->get_name);
}

sub load_wiggle_data {
  my $wiggle_data_id = shift;
  $queries{'wiggle_data_get'} = ModENCODE::Cache::dbh->prepare('SELECT 
    wiggle_data_id AS id, name, type, visibility, color, altColor, priority, autoscale, gridDefault, maxHeightPixels, graphType, viewLimits, yLineMark, yLineOnOff, windowingFunction, smoothingWindow, data
    FROM wiggle_data WHERE wiggle_data_id = ?') unless $queries{'wiggle_data_get'};
  $queries{'wiggle_data_datum_get'} = ModENCODE::Cache::dbh->prepare('SELECT data_id FROM data_wiggle_data WHERE wiggle_data_id = ?') unless $queries{'wiggle_data_datum_get'};
  $queries{'wiggle_data_get'}->execute($wiggle_data_id);
  my $row = $queries{'wiggle_data_get'}->fetchrow_hashref();

  $queries{'wiggle_data_datum_get'}->execute($wiggle_data_id);
  my ($datum_id) = $queries{'wiggle_data_datum_get'}->fetchrow_array();
  $row->{'datum'} = new ModENCODE::Cache::Data({'content' => $datum_id}) if $datum_id;

  my $wiggle_data = ModENCODE::Chado::Wiggle_Data->new_no_cache($row);
  log_error "Loading wiggle_data " . $wiggle_data->get_name . " from cache database (unshrinking).", "debug" if DEBUG;
  $queries{'wiggle_data_organisms_get'}->execute($wiggle_data_id);

  return $wiggle_data;
}
###### /WIGGLE DATA ####### }
############# FEATURE ######### {
sub add_feature_to_cache {
  my $feature = shift;
  $feature->save unless $feature->get_id;
  my $cacheobj = $cachesets{'feature'}->add_to_cache(new ModENCODE::Cache::Feature({'content' => $feature }), $feature->get_uniquename, $feature->get_type_id, $feature->get_organism_id);
  $cachesets{'feature'}->add_to_id_cache($cacheobj, $feature->get_id);
  return $cacheobj;
}

sub save_feature {
  my $feature = shift;
  $queries{'feature_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO feature (name, uniquename, residues, seqlen, timeaccessioned, timelastmodified, is_analysis, dbxref_id, organism_id, type_id) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)') unless $queries{'feature_ins'};
  $queries{'feature_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE feature SET name = ?, uniquename = ?, residues = ?, seqlen = ?, timeaccessioned = ?, timelastmodified = ?, is_analysis = ?, dbxref_id = ?, organism_id = ?, type_id = ?  WHERE feature_id = ?') unless $queries{'feature_upd'};

  # Featurelocs
  $queries{'del_feature_locs'} = ModENCODE::Cache::dbh->prepare('DELETE FROM featureloc WHERE feature_id = ?') unless $queries{'del_feature_locs'};
  $queries{'add_feature_loc'} = ModENCODE::Cache::dbh->prepare('INSERT INTO featureloc (feature_id, fmin, fmax, rank, strand, srcfeature_id) VALUES(?, ?, ?, ?, ?, ?)') unless $queries{'add_feature_loc'};

  # Featureprops
  $queries{'del_feature_props'} = ModENCODE::Cache::dbh->prepare('DELETE FROM featureprop WHERE feature_id = ?') unless $queries{'del_feature_props'};
  $queries{'add_feature_prop'} = ModENCODE::Cache::dbh->prepare('INSERT INTO featureprop (feature_id, value, rank, type_id) VALUES(?, ?, ?, ?)') unless $queries{'add_feature_prop'};

  # Analysisfeatures
  $queries{'del_analysisfeatures'} = ModENCODE::Cache::dbh->prepare('DELETE FROM analysisfeature WHERE feature_id = ?') unless $queries{'del_analysisfeatures'};
  $queries{'add_analysisfeature'} = ModENCODE::Cache::dbh->prepare('INSERT INTO analysisfeature (feature_id, analysis_id, rawscore, normscore, significance, identity) VALUES(?, ?, ?, ?, ?, ?)') unless $queries{'add_analysisfeature'};

  # DBXrefs
  $queries{'del_feature_dbxrefs'} = ModENCODE::Cache::dbh->prepare('DELETE FROM feature_dbxref WHERE feature_id = ?') unless $queries{'del_feature_dbxrefs'};
  $queries{'add_feature_dbxrefs'} = ModENCODE::Cache::dbh->prepare('INSERT INTO feature_dbxref (feature_id, dbxref_id) VALUES(?, ?)') unless $queries{'add_feature_dbxrefs'};

  # Feature relationships (linked through intermediate table so you don't have keep feature.relationships in sync on both sides)
  $queries{'del_feature_feature_relationship'} = ModENCODE::Cache::dbh->prepare('DELETE FROM feature_feature_relationship WHERE feature_id = ?') unless $queries{'del_feature_feature_relationship'};
  $queries{'add_feature_feature_relationship'} = ModENCODE::Cache::dbh->prepare('INSERT INTO feature_feature_relationship (feature_id, feature_relationship_id) VALUES(?, ?)') unless $queries{'add_feature_feature_relationship'};

  if (!$feature->get_id()) {
    modification_notification();
    $queries{'feature_ins'}->execute($feature->get_name, $feature->get_uniquename, $feature->get_residues, $feature->get_seqlen, $feature->get_timeaccessioned, $feature->get_timelastmodified, $feature->get_is_analysis, $feature->get_primary_dbxref_id, $feature->get_organism_id, $feature->get_type_id);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $feature->set_id($id);
    log_error "Saving feature " . $feature->get_uniquename() . " with id $id.", "debug" if DEBUG;
  } else {
    modification_notification();
    my $id = $feature->get_id();
    $queries{'feature_upd'}->execute($feature->get_name, $feature->get_uniquename, $feature->get_residues, $feature->get_seqlen, $feature->get_timeaccessioned, $feature->get_timelastmodified, $feature->get_is_analysis, $feature->get_primary_dbxref_id, $feature->get_organism_id, $feature->get_type_id, $id);
    log_error "Updating feature " . $feature->get_uniquename() . " with id $id.", "debug";
  }

  # Update links to feature locations
  $queries{'del_feature_locs'}->execute($feature->get_id);
  foreach my $featureloc (@{$feature->get_locations}) {
    modification_notification();
    $queries{'add_feature_loc'}->execute($feature->get_id, $featureloc->get_fmin, $featureloc->get_fmax, $featureloc->get_rank, $featureloc->get_strand, $featureloc->get_srcfeature_id);
  }

  # Update links to feature properties
  $queries{'del_feature_props'}->execute($feature->get_id);
  foreach my $featureprop (@{$feature->get_properties}) {
    modification_notification();
    $queries{'add_feature_prop'}->execute($feature->get_id, $featureprop->get_value, $featureprop->get_rank, $featureprop->get_type_id);
  }

  # Update links to analysisfeatures
  $queries{'del_analysisfeatures'}->execute($feature->get_id);
  foreach my $analysisfeature (@{$feature->get_analysisfeatures}) {
    modification_notification();
    $queries{'add_analysisfeature'}->execute($feature->get_id, $analysisfeature->get_analysis_id, $analysisfeature->get_rawscore, $analysisfeature->get_normscore, $analysisfeature->get_significance, $analysisfeature->get_identity);
  }

  # Update links to feature relationships
  $queries{'del_feature_feature_relationship'}->execute($feature->get_id);
  foreach my $feature_relationship_id ($feature->get_relationship_ids) {
    modification_notification();
    $queries{'add_feature_feature_relationship'}->execute($feature->get_id, $feature_relationship_id);
  }

  # Update links to DBXrefs
  $queries{'del_feature_dbxrefs'}->execute($feature->get_id);
  foreach my $dbxref_id ($feature->get_dbxref_ids) {
    modification_notification();
    $queries{'add_feature_dbxrefs'}->execute($feature->get_id, $dbxref_id);
  }

  return $feature->get_id;
}

sub get_cached_feature {
  my $obj = shift;
  return $cachesets{'feature'}->get_from_cache($obj->get_uniquename, $obj->get_type_id, $obj->get_organism_id);
}

sub load_feature {
  my $feature_id = shift;
  $queries{'feature_get'} = ModENCODE::Cache::dbh->prepare('SELECT feature_id AS id, name, uniquename, residues, seqlen, timeaccessioned, timelastmodified, is_analysis, dbxref_id AS primary_dbxref, organism_id AS organism, type_id AS type FROM feature WHERE feature_id = ?') unless $queries{'feature_get'};
  $queries{'feature_get'}->execute($feature_id);
  my $row = $queries{'feature_get'}->fetchrow_hashref();

  $row->{'primary_dbxref'} = $cachesets{'dbxref'}->get_from_id_cache($row->{'primary_dbxref'});
  $row->{'organism'} = $cachesets{'organism'}->get_from_id_cache($row->{'organism'});
  $row->{'type'} = $cachesets{'cvterm'}->get_from_id_cache($row->{'type'});

  my $feature = ModENCODE::Chado::Feature->new_no_cache($row);
  $feature->clean();
  log_error "Loading feature " . $feature->get_uniquename . " from cache database (unshrinking).", "debug" if DEBUG;

  $queries{'feature_dbxrefs_get'} = ModENCODE::Cache::dbh->prepare('SELECT dbxref_id AS dbxref FROM feature_dbxref WHERE feature_id = ?') unless $queries{'feature_dbxrefs_get'};
  $queries{'feature_dbxrefs_get'}->execute($feature_id);
  while (my ($dbxref_id) = $queries{'feature_dbxrefs_get'}->fetchrow_array()) {
    $feature->add_dbxref($cachesets{'dbxref'}->get_from_id_cache($dbxref_id));
  }

  # Feature locations
  $queries{'featurelocs_get'} = ModENCODE::Cache::dbh->prepare('SELECT fmin, fmax, rank, strand, srcfeature_id AS srcfeature FROM featureloc WHERE feature_id = ?') unless $queries{'featurelocs_get'};
  $queries{'featurelocs_get'}->execute($feature_id);
  while (my $row = $queries{'featurelocs_get'}->fetchrow_hashref()) {
    $row->{'srcfeature'} = $cachesets{'feature'}->get_from_id_cache($row->{'srcfeature'});
    my $featureloc = new ModENCODE::Chado::FeatureLoc($row);
    $feature->add_location($featureloc);
  }

  # Feature properties
  $queries{'featureprops_get'} = ModENCODE::Cache::dbh->prepare('SELECT value, rank, type_id AS type FROM featureprop WHERE feature_id = ?') unless $queries{'featureprops_get'};
  $queries{'featureprops_get'}->execute($feature_id);
  while (my $row = $queries{'featureprops_get'}->fetchrow_hashref()) {
    $row->{'type'} = $cachesets{'cvterm'}->get_from_id_cache($row->{'type'});
    my $featureprop = new ModENCODE::Chado::FeatureProp($row);
    $feature->add_property($featureprop);
  }

  # Analysis features
  $queries{'analysisfeatures_get'} = ModENCODE::Cache::dbh->prepare('SELECT feature_id AS feature, analysis_id AS analysis, rawscore, normscore, significance, identity FROM analysisfeature WHERE feature_id = ?') unless $queries{'analysisfeatures_get'};
  $queries{'analysisfeatures_get'}->execute($feature_id);
  while (my $row = $queries{'analysisfeatures_get'}->fetchrow_hashref()) {
    $row->{'feature'} = $cachesets{'feature'}->get_from_id_cache($row->{'feature'});
    $row->{'analysis'} = $cachesets{'analysis'}->get_from_id_cache($row->{'analysis'});
    my $analysisfeature = new ModENCODE::Chado::AnalysisFeature($row);
    $feature->add_analysisfeature($analysisfeature);
  }

  # Feature relationships
  $queries{'feature_relationships_get'} = ModENCODE::Cache::dbh->prepare('SELECT feature_relationship_id AS relationship FROM feature_feature_relationship WHERE feature_id = ?') unless $queries{'feature_relationships_get'};
  $queries{'feature_relationships_get'}->execute($feature_id);
  while (my ($relationship_id) = $queries{'feature_relationships_get'}->fetchrow_array()) {
    $feature->add_relationship($cachesets{'feature_relationship'}->get_from_id_cache($relationship_id));
  }

  return $feature;
}

sub get_feature_by_uniquename_and_type {
  my ($uniquename, $type) = @_;
  $queries{'feature_uniquename_get'} = ModENCODE::Cache::dbh->prepare('SELECT feature_id FROM feature WHERE uniquename = ? AND type_id = ?') unless $queries{'feature_uniquename_get'};
  $queries{'feature_uniquename_get'}->execute($uniquename, $type->get_id);
  my ($feature_id) = $queries{'feature_uniquename_get'}->fetchrow_array();
  if ($queries{'feature_uniquename_get'}->fetchrow_array()) {
    log_error "Found more than one feature with uniquename $uniquename in created features. Not using any of them.", "warning";
    return undef;
  }
  return $cachesets{'feature'}->get_from_id_cache($feature_id);
}
############# /FEATURE ######### }
############# ANALYSIS ############### {
sub load_analysis {
  my $analysis_id = shift;
  $queries{'analysis_get'} = ModENCODE::Cache::dbh->prepare('SELECT analysis_id AS id, program, programversion, sourcename, name, description, algorithm, sourceversion, sourceuri, timeexecuted FROM analysis WHERE analysis_id = ?') unless $queries{'analysis_get'};
  $queries{'analysis_get'}->execute($analysis_id);
  my $row = $queries{'analysis_get'}->fetchrow_hashref();
  my $analysis = ModENCODE::Chado::Analysis->new_no_cache($row);
  log_error "Loading analysis " . $analysis->program . " from cache database (unshrinking).", "debug" if DEBUG;
  return $analysis;
}

sub get_cached_analysis {
  my $obj = shift;
  return $cachesets{'analysis'}->get_from_cache($obj->get_program, $obj->get_programversion, $obj->get_sourcename);
}

sub add_analysis_to_cache {
  my $analysis = shift;
  $analysis->save unless $analysis->get_id;
  my $cacheobj = $cachesets{'analysis'}->add_to_cache(new ModENCODE::Cache::Analysis({'content' => $analysis }), $analysis->get_program, $analysis->get_programversion, $analysis->get_sourcename);
  $cachesets{'analysis'}->add_to_id_cache($cacheobj, $analysis->get_id);
  return $cacheobj;
}

sub save_analysis {
  my $analysis = shift;
  $queries{'analysis_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO analysis (program, programversion, sourcename, name, description, algorithm, sourceversion, sourceuri, timeexecuted) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)') unless $queries{'analysis_ins'};
  $queries{'analysis_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE analysis SET program = ?, programversion = ?, sourcename = ?, name = ?, description = ?, algorithm = ?, sourceversion = ?, sourceuri = ?, timeexecuted = ?  WHERE analysis_id = ?') unless $queries{'analysis_upd'};
  modification_notification();
  if (!$analysis->get_id()) {
    $queries{'analysis_ins'}->execute($analysis->get_program, $analysis->get_programversion, $analysis->get_sourcename, $analysis->get_name, $analysis->get_description, $analysis->get_algorithm, $analysis->get_sourceversion, $analysis->get_sourceuri, $analysis->get_timeexecuted);
    my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
    $analysis->set_id($id);
    log_error "Saving analysis " . $analysis->get_program() . " with id $id.", "debug";
    return $id;
  } else {
    my $id = $analysis->get_id();
    $queries{'analysis_upd'}->execute($analysis->get_program, $analysis->get_programversion, $analysis->get_sourcename, $analysis->get_name, $analysis->get_description, $analysis->get_algorithm, $analysis->get_sourceversion, $analysis->get_sourceuri, $analysis->get_timeexecuted, $id);
    log_error "Updating analysis " . $analysis->get_program() . " with id $id.", "debug";
    return $id;
  }
}

############# /ANALYSIS ############### }
############# FEATURE RELATIONSHIP ######### {
sub add_feature_relationship_to_cache {
  my $feature_relationship = shift;

  # Have to create a placeholder feature_relationship so that we can save the features
  # since they reference the feature_relationhip's ID (and vice versa)
  save_placeholder_feature_relationship($feature_relationship);
  # Add it to the cache so save_feature can reference it
  my $cacheobj = $cachesets{'feature_relationship'}->add_to_cache(new ModENCODE::Cache::FeatureRelationship({'content' => $feature_relationship }), $feature_relationship->get_subject_id, $feature_relationship->get_object_id, $feature_relationship->get_type_id, $feature_relationship->get_rank);
  $cachesets{'feature_relationship'}->add_to_id_cache($cacheobj, $feature_relationship->get_id);

  # Now save it for real
  $feature_relationship->save;

  return $cacheobj;
}

sub save_placeholder_feature_relationship {
  my $feature_relationship = shift;
  $queries{'feature_relationship_ins'} = ModENCODE::Cache::dbh->prepare('INSERT INTO feature_relationship (type_id, rank) VALUES(?, ?)') unless $queries{'feature_relationship_ins'};
  modification_notification();
  $queries{'feature_relationship_ins'}->execute($feature_relationship->get_type_id, $feature_relationship->get_rank);
  my $id = ModENCODE::Cache::dbh->func('last_insert_rowid');
  log_error "Saving placeholder relationship with id $id", "debug" if DEBUG;
  $feature_relationship->set_id($id);
}

sub save_feature_relationship {
  my $feature_relationship = shift;
  $queries{'feature_relationship_upd'} = ModENCODE::Cache::dbh->prepare('UPDATE feature_relationship SET subject_id = ?, object_id = ?, type_id = ?, rank = ? WHERE feature_relationship_id = ?') unless $queries{'feature_relationship_upd'};

  if (!$feature_relationship->get_id()) {
    croak "How did I get here?";
  } else {
    my $id = $feature_relationship->get_id();
    $queries{'feature_relationship_upd'}->execute($feature_relationship->get_subject_id, $feature_relationship->get_object_id, $feature_relationship->get_type_id, $feature_relationship->get_rank, $id);
    log_error "Updating relationship " . $feature_relationship->get_subject_id() . " " . $feature_relationship->get_type(1)->get_name . " " . $feature_relationship->get_object_id . " with id $id.", "debug" if DEBUG;
  }

  return $feature_relationship->get_id;
}

sub get_cached_feature_relationship {
  my $obj = shift;
  return $cachesets{'feature_relationship'}->get_from_cache($obj->get_subject_id, $obj->get_object_id, $obj->get_type_id, $obj->get_rank);
}

sub load_feature_relationship {
  my $feature_relationship_id = shift;
  $queries{'feature_relationship_get'} = ModENCODE::Cache::dbh->prepare('SELECT feature_relationship_id AS id, subject_id AS subject, object_id AS object, type_id AS type, rank FROM feature_relationship WHERE feature_relationship_id = ?') unless $queries{'feature_relationship_get'};
  $queries{'feature_relationship_get'}->execute($feature_relationship_id);
  my $row = $queries{'feature_relationship_get'}->fetchrow_hashref();

  $row->{'subject'} = $cachesets{'feature'}->get_from_id_cache($row->{'subject'});
  $row->{'object'} = $cachesets{'feature'}->get_from_id_cache($row->{'object'});
  $row->{'type'} = $cachesets{'cvterm'}->get_from_id_cache($row->{'type'});

  my $feature_relationship = ModENCODE::Chado::FeatureRelationship->new_no_cache($row);
  $feature_relationship->clean();
  log_error "Loading relationship " . $feature_relationship->get_subject_id() . " " . $feature_relationship->get_type(1)->get_name . " " . $feature_relationship->get_object_id . " from cache database (unshrinking).", "debug" if DEBUG;

  return $feature_relationship;
}
############# /FEATURE RELATIONSHIP ######### }


sub modification_notification {
  if ($query_count++ % 20000 == 0) {
    log_error "Beginning new transaction", "notice";
    ModENCODE::Cache::dbh->do("END TRANSACTION");
    ModENCODE::Cache::dbh->do("BEGIN TRANSACTION");
  }
}


1;

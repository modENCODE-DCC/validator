package ModENCODE::Validator::Data::SO_transcript;
=pod

=head1 NAME

ModENCODE::Validator::Data::SO_transcript - Class for validating and updating
BIR-TAB L<Data|ModENCODE::Chado::Data> objects containing transcript names to
include L<Features|ModENCODE::Chado::Feature> for those transcripts.

=head1 SYNOPSIS

This class is meant to be used to build a L<ModENCODE::Chado::Feature> object
(and associated L<CVTerms|ModENCODE::Chado::CVTerm>,
L<FeatureLocs|ModENCODE::Chado::FeatureLoc>,
L<Organisms|ModENCODE::Chado::Organism>, and
L<DBXrefs|ModENCODE::Chado::DBXref> for a provided transcript name (as
kept in the C<feature.name> field of a Chado database. Transcript information
will be fetched from either the local modENCODE Chado database defined in the
C<[databases modencode]> section of the ini-file loaded by
L<ModENCODE::Config>), or if not found there, then from the FlyBase database
defined in the C<[databases flybase]> section of the ini-file.

=head1 USAGE

When given L<ModENCODE::Chado::Data> objects with values that are transcript
names, this modules uses
L<ModENCODE::Parser::Chado/get_feature_id_by_name_and_type($name, $type,
$allow_isa)> to pull out C<feature_id>s for features of type C<SO:transcript> or
children of the C<SO:transcript> type like C<SO:mRNA>. (This is achieved by
passing in a value of 1 for C<$allow_isa>.) The C<feature_id>s are then used to
pull out full L<Feature|ModENCODE::Chado::Feature> objects using
L<ModENCODE::Parser::Chado/get_feature($feature_id)>, which can include other
attached features (genes, exons, etc.) as well as L<ModENCODE::Chado::CVTerm>s,
L<ModENCODE::Chado::DBXref>s, and so forth. The originally requested feature is
then added to the original datum (and by association, so are the other connected
objects).
 
To use this validator in a standalone way:

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'TranscriptName'
  });
  my $validator = new ModENCODE::Validator::Data::SO_transcript();
  $validator->add_datum($datum, $applied_protocol);
  if ($validator->validate()) {
    my $new_datum = $validator->merge($datum);
    print $new_datum->get_features()->[0]->get_name();
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Data>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> have values that exist as transcript names accession in the
C<feature.name> column of either the local modENCODE database or FlyBase.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>, returns a copy of
that datum with a newly attached feature based on a transcript record and other
attached features in either the local modENCODE database or FlyBase for the
value in that C<$datum>.

B<NOTE:> In addition to attaching features to the current C<$datum>, if there is
a GFF3 datum (as validated by L<ModENCODE::Validator::Data::GFF3>) attached to
the same C<$applied_protocol>, then the features within it are scanned for any
with the name equal to the transcript name - if these are found, they are
replaced (using L<ModENCODE::Chado::Feature/mimic($feature)>).

=back

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<ModENCODE::Chado::Feature>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Organism>,
L<ModENCODE::Chado::FeatureLoc>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::Result_File>,
L<ModENCODE::Validator::Data::dbEST_acc>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::GFF3>,
L<ModENCODE::Validator::Data::dbEST_acc_list>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use ModENCODE::Validator::Data::Data;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Parser::Chado;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Chado::Feature;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Organism;
use ModENCODE::Chado::FeatureLoc;
use ModENCODE::Config;

sub validate {
  my ($self) = @_;
  my $success = 1;

  log_error "Loading transcripts from Chado database(s).", "notice", ">";

  foreach my $parse (
    ['modENCODE', $self->get_modencode_chado_parser(), [ 'FlyBase Annotation IDs' ]],
    ['FlyBase', $self->get_flybase_chado_parser(), [ 'FlyBase Annotation IDs' ]],
    ['WormBase',  $self->get_wormbase_chado_parser(), [ 'Wormbase ID' ]],
  ) {
    my ($parser_name, $parser, $dbnames) = @$parse;
    if (!$parser) {
      log_error "Can't check transcripts against the $parser_name database; skipping.", "warning";
      next;
    }

    log_error "Checking for transcripts in the $parser_name database.", "notice";

    my ($genus, $species);
    if ($parser_name eq "FlyBase") {
      $genus = [ "Drosophila" ];
      $species = [ "melanogaster" ];
    } elsif ($parser_name eq "WormBase") {
      $genus = [ "Caenorhabditis" ];
      $species = [ "elegans" ];
    } else {
      $genus = [ "Drosophila", "Caenorhabditis" ];
      $species = [ "melanogaster", "elegans" ];
    }

    while (my $ap_datum = $self->next_datum) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;

      my $datum_obj = $datum->get_object;
      my $accession = $datum_obj->get_value;

      if (!length($accession)) {
        log_error "Empty value for EST accession in column " . $datum_obj->get_heading . " [" . $datum_obj->get_name . "].", "warning";
        $self->remove_current_datum;
        next;
      }


      my $feature = $parser->get_feature_by_organisms_and_uniquename($genus, $species, $accession);
      $feature = $parser->get_feature_by_dbs_and_accession($dbnames, $accession) unless $feature;
      next unless $feature;

      if ($feature->get_object->get_type(1)->get_name ne "transcript" && $feature->get_object->get_type(1)->get_name ne "mRNA") {
        log_error "Found a feature for $accession in $parser_name, but it is a " . $feature->get_object->get_type(1)->get_name . ", not a transcript. Skipping.", "warning";
        next;
      }

      # Don't need to revalidate if we've found it
      $self->remove_current_datum;

      log_error "Found transcript $accession in $parser_name.", "debug";
      $datum->get_object->add_feature($feature);
    }
    $self->rewind();
  }
  if ($self->num_data) {
    # Some transcripts weren't found in any parser
    my @accessions;
    while (my $ap_datum = $self->next_datum) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;
      push @accessions, $datum->get_object->get_value;
    }
    $success = 0;
    log_error "Couldn't find transcripts (" . join(", ", sort(@accessions)) . ") in any database.", "error";
  }

  log_error "Done.", "notice", "<";
  return $success;
}


sub get_flybase_chado_parser : PROTECTED {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases flybase', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases flybase', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases flybase', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases flybase', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases flybase', 'password'),
      'caching' => 0,
    });
  return undef unless $parser;
  $parser->set_no_relationships(1);
  return $parser;
}

sub get_wormbase_chado_parser : PROTECTED {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases wormbase', 'password'),
      'caching' => 0,
    });
  return undef unless $parser;
  $parser->set_no_relationships(1);
  return $parser;
}

sub get_modencode_chado_parser : PROTECTED {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases modencode', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases modencode', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases modencode', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases modencode', 'password'),
      'caching' => 0,
    });
  return undef unless $parser;
  $parser->set_no_relationships(1);
  return $parser;
}

1;

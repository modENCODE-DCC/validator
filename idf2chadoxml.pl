#!/usr/bin/perl

use strict;


my $root_dir;
BEGIN {
  $root_dir = $0;
  $root_dir =~ s/[^\/]*$//;
  $root_dir = "./" unless $root_dir =~ /\//;
  push @INC, $root_dir;
}
use Carp qw(croak carp);

use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;
use ModENCODE::Cache;
use ModENCODE::Parser::IDF;
use ModENCODE::Validator::IDF_SDRF;
use ModENCODE::Validator::ModENCODE_Projects;
use ModENCODE::Validator::ModENCODE_Dates;
use ModENCODE::Validator::Wiki;
use ModENCODE::Validator::Attributes;
use ModENCODE::Validator::Data;
use ModENCODE::Validator::ExperimentalFactorName;
use ModENCODE::Validator::TermSources;
use ModENCODE::Validator::FeatureExistence;
use ModENCODE::Validator::ReadCounts;
use ModENCODE::Chado::XMLWriter;
use Getopt::Long;

ModENCODE::ErrorHandler::set_logtype(ModENCODE::ErrorHandler::LOGGING_PREFIX_ON);
ModENCODE::Config::set_cfg($root_dir . 'validator.ini');
ModENCODE::Cache::init();


my $submission_name;
my $options = GetOptions(
  "submission_name|n=s" => sub { ModENCODE::Config::set_submission_pipeline_name($_[1]); },
  "embargo_date|d=s" => sub { ModENCODE::Config::set_embargo_date($_[1]); },
);

log_error "Validating submission...", "notice", ">";
# Get IDF file
my $idf = $ARGV[0];
{
  my ($path, $file) = ($idf =~ m/(.*?)([^\/]+$)/);
  $path = "." unless length($path);
  $path .= "/" unless $path =~ m/\/$/;
  chdir $path;
  $idf = $file;
}
log_error "Reading IDF and SDRF...", "notice", ">";

my $parser = new ModENCODE::Parser::IDF($idf);
my $result = $parser->parse();

if (!$result) {
  log_error "Failed.", "error", "<";
  exit;
}

log_error "Done.", "notice", "<";

my ($experiment, $protocols, $sdrfs, $termsources) = @$result;

log_error "Merging SDRF and IDF.", "notice", ">";
my $idf_validator = new ModENCODE::Validator::IDF_SDRF({
    'idf_experiment' => $experiment,
    'sdrf_experiment' => $sdrfs->[0],
    'protocols' => $protocols,
    'termsources' => $termsources,
  });
$experiment = $idf_validator->validate();
$idf_validator = undef;
$termsources = undef;
$sdrfs = undef;
$protocols = undef;
if (!$experiment) {
  log_error "Failed.", "error", "<";
  exit;
}
log_error "Done.", "notice", "<";

# Set the experiment uniquename to the submission pipeline name, if available
if (ModENCODE::Config::get_submission_pipeline_name) {
  $experiment->set_uniquename(ModENCODE::Config::get_submission_pipeline_name);
  log_error "Set submission name to \"" . ModENCODE::Config::get_submission_pipeline_name . "\".", "notice";
}

if (ModENCODE::Config::get_embargo_date) {
  $experiment->add_property(new ModENCODE::Chado::ExperimentProp({
        'experiment' => $experiment,
        'name' => 'Embargo Date',
        'type' => new ModENCODE::Chado::CVTerm({'name' => 'date', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
        'value' => ModENCODE::Config::get_embargo_date(),
      })
  );
  log_error "Set embargo date to \"" . ModENCODE::Config::get_embargo_date . "\".", "notice";
}

log_error "Validating presence of valid ModENCODE project/subproject names...", "notice", ">";
my $project_validator = new ModENCODE::Validator::ModENCODE_Projects({ 'experiment' => $experiment });
if (!$project_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$project_validator = undef;
log_error "Done.", "notice", "<";

log_error "Validating presence of public release and generation dates...", "notice", ">";
my $date_validator = new ModENCODE::Validator::ModENCODE_Dates({ 'experiment' => $experiment });
if (!$date_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$date_validator = undef;
log_error "Done.", "notice", "<";

log_error "Validating IDF and SDRF vs wiki...", "notice", ">";
my $wiki_validator = new ModENCODE::Validator::Wiki({ 'experiment' => $experiment });
if (!$wiki_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$wiki_validator = undef;
log_error "Done", "notice", "<";


log_error "Expanding attribute columns.", "notice", ">";
my $attribute_validator = new ModENCODE::Validator::Attributes({ 'experiment' => $experiment });
if (!$attribute_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$attribute_validator = undef;
log_error "Done.", "notice", "<";

log_error "Reading data files.", "notice", ">";
my $data_validator = new ModENCODE::Validator::Data({ 'experiment' => $experiment });
if (!$data_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$data_validator = undef;
log_error "Done.", "notice", "<";


log_error "Ensuring read counts are okay.", "notice", ">";
my $read_counts_validator = new ModENCODE::Validator::ReadCounts({ 'experiment' => $experiment });
if (!$read_counts_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
log_error "Done.", "notice", "<";

log_error "Validating Experimental Factor Name, if present.", "notice", ">";
my $factor_name_validator = new ModENCODE::Validator::ExperimentalFactorName({ 'experiment' => $experiment });
if (!$factor_name_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$factor_name_validator = undef;
log_error "Done.", "notice", "<";

log_error "Validating CVTerms and DBXrefs.", "notice", ">";
my $termsource_validator = new ModENCODE::Validator::TermSources({ 'experiment' => $experiment });
if (!$termsource_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$termsource_validator = undef;
log_error "Done.", "notice", "<";

log_error "Checking that features were created.", "notice", ">";
my $feature_existence_validator = new ModENCODE::Validator::FeatureExistence({ 'experiment' => $experiment });
if (!$feature_existence_validator->validate()) {
  log_error "Failed.", "error", "<";
  exit;
}
$feature_existence_validator = undef;
log_error "Done.", "notice", "<";

log_error "Validated successfully!", "notice", "<";

log_error "Writing ChadoXML; this may take a while...", "notice", ">";
my $xmlwriter = new ModENCODE::Chado::XMLWriter();
if ($ARGV[1] && !$xmlwriter->set_output_file($ARGV[1])) {
  log_error "Failed to open " . $ARGV[1] . " for writing.", "error", "<";
  exit;
}
$xmlwriter->write_chadoxml($experiment);
log_error "Done. All tasks complete.", "notice", "<";

#print $experiment->to_string() . "\n";
ModENCODE::Cache::destroy();


1;

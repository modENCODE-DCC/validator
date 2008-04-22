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
use ModENCODE::Parser::IDF;
use ModENCODE::Chado::XMLWriter;
use ModENCODE::Validator::IDF_SDRF;
use ModENCODE::Validator::ModENCODE_Projects;
use ModENCODE::Validator::Wiki;
use ModENCODE::Validator::TermSources;
use ModENCODE::Validator::CVHandler;
use ModENCODE::Validator::Attributes;
use ModENCODE::Validator::Data;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;

$ModENCODE::ErrorHandler::show_logtype = 1;

ModENCODE::Config::set_cfg($root_dir . 'validator.ini');

my $parser = new ModENCODE::Parser::IDF();

log_error "Parsing IDF and SDRF...", "notice", ">";

my $idf = $ARGV[0];
my ($path, $file) = ($idf =~ m/(.*?)([^\/]+$)/);
$path = "." unless length($path);
$path .= "/" unless $path =~ m/\/$/;

chdir $path;
$idf = $file;

my $result = $parser->parse($idf);
if (!$result) {
  log_error "Unable to parse IDF. Terminating.", "error", "<";
  exit;
}

my ($experiment, $protocols, $sdrfs, $termsources) = @$result;
log_error "Done.", "notice", "<";

  # Validate and merge IDF and SDRF
  log_error "Validating IDF vs SDRF...", "notice", ">";
  my $idf_validator = new ModENCODE::Validator::IDF_SDRF({
      'idf_experiment' => $experiment,
      'protocols' => $protocols,
      'termsources' => $termsources,
    });
  my $sdrf = @$sdrfs->[0];
  my $success = $idf_validator->validate($sdrf);
  $experiment = $idf_validator->merge($sdrf);
  log_error "Done.", "notice", "<";
  $sdrf = undef;

  log_error "Validating presence of valid ModENCODE project/subproject names...", "notice", ">";
  my $project_validator = new ModENCODE::Validator::ModENCODE_Projects();
  if (!$project_validator->validate($experiment)) {
    log_error "Refusing to continue validation without valid project/subproject names.";
    exit;
  }
  $experiment = $project_validator->merge($experiment);
  log_error "Done.", "notice", "<";

  log_error "Validating IDF and SDRF vs wiki...", "notice", ">";

  # Validate and merge wiki data
  my $wiki_validator = new ModENCODE::Validator::Wiki({ 
      'termsources' => $termsources,
    });
  $wiki_validator->validate($experiment);
  log_error "Done.", "notice", "<";
  log_error "Merging wiki data into experiment...", "notice", ">";
  $experiment = $wiki_validator->merge($experiment);
  log_error "Done.", "notice", "<";
  $wiki_validator = undef;
  
  # Validate and merge expanded columns (attributes, etc)
  log_error "Expanding attribute columns.", "notice", ">";
  my $attribute_validator = new ModENCODE::Validator::Attributes();
  $attribute_validator->validate($experiment);
  $experiment = $attribute_validator->merge($experiment);
  log_error "Done.", "notice", "<";
  $attribute_validator = undef;

  # Validate and merge attached data files and remote resources (BED, Wiggle, ASN.1, dbEST, etc.)
  log_error "Reading data files.", "notice", ">";
  my $data_validator = new ModENCODE::Validator::Data();
  if ($data_validator->validate($experiment)) {
    $experiment = $data_validator->merge($experiment);
  } else {
    log_error "Couldn't validate data columns!", "error";
    exit;
  }
  log_error "Done.", "notice", "<";
  $data_validator = undef;

  # Validate and merge term source (make sure terms exist in CVs, fetch missing accessions, etc.)
  log_error "Validating term sources (DBXrefs) against known ontologies.", "notice", ">";
  my $termsource_validator = new ModENCODE::Validator::TermSources();
  $termsource_validator->validate($experiment);
  log_error "Done.", "notice", "<";
  log_error "Merging missing accessions and/or term names from known ontologies.", "notice", ">";
  $experiment = $termsource_validator->merge($experiment);
  log_error "Done.", "notice", "<";

  my $writer = new ModENCODE::Chado::XMLWriter();
  my $fh;
  if ($ARGV[1]) {
    my $success = open($fh, "+>", $ARGV[1]);
    if (!$success) {
      log_error "Cannot write experiment to file $ARGV[1], defaulting to STDOUT. $!", "warning";
      exit;
    } else {
      $writer->set_output_handle($fh);
    }
  }
  $writer->write_chadoxml($experiment);
  close $fh if $fh;
#print $experiment->to_string();



#!/usr/bin/perl

use strict;
use Carp qw(croak carp);
use ModENCODE::Parser::IDF;
use ModENCODE::Chado::XMLWriter;
use ModENCODE::Validator::IDF_SDRF;
use ModENCODE::Validator::Wiki;
use ModENCODE::Validator::TermSources;
use ModENCODE::Validator::CVHandler;
use ModENCODE::Validator::Data;
use ModENCODE::ErrorHandler qw(log_error);

$ModENCODE::ErrorHandler::show_logtype = 1;

my $parser = new ModENCODE::Parser::IDF();
my $writer = new ModENCODE::Chado::XMLWriter();

my $cvhandler = new ModENCODE::Validator::CVHandler();
# Add some ontologies that get used for hardcoded cvterms (like MO:OntologyEntry or xsd:string or modencode:anonymous_datum)
$cvhandler->add_cv(
  'xsd',
  'http://wiki.modencode.org/project/extensions/DBFields/ontologies/xsd.obo',
  'OBO',
);
$cvhandler->add_cv(
  'modencode',
  'http://wiki.modencode.org/project/extensions/DBFields/ontologies/modencode-helper.obo',
  'OBO',
);
$cvhandler->add_cv(
  'MO',
  'http://www.berkeleybop.org/ontologies/obo-all/mged/mged.obo',
  'OBO',
);


log_error "Parsing IDF and SDRF...", "notice", ">";
my $result = $parser->parse($ARGV[0]);
if (!$result) {
  log_error "Unable to parse IDF. Terminating.", "error", "<";
  exit;
}

my ($experiment, $protocols, $sdrfs, $termsources) = @$result;
log_error "Done.", "notice", "<";

# Validate IDF vs. SDRF
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

  log_error "Validating IDF and SDRF vs wiki...", "notice", ">";
  my $wiki_validator = new ModENCODE::Validator::Wiki({ 
      'termsources' => $termsources,
      'cvhandler' => $cvhandler,
    });
  $wiki_validator->validate($experiment);
  log_error "Done.", "notice", "<";
  log_error "Merging wiki data into experiment...", "notice", ">";
  $experiment = $wiki_validator->merge($experiment);
  log_error "Done.", "notice", "<";

  log_error "Validating term sources (DBXrefs) against known ontologies.", "notice", ">";
  my $termsource_validator = new ModENCODE::Validator::TermSources({
      'cvhandler' => $cvhandler,
    });
  $termsource_validator->validate($experiment);
  log_error "Done.", "notice", "<";
  log_error "Merging missing accessions and/or term names from known ontologies.", "notice", ">";
  $experiment = $termsource_validator->merge($experiment);
  log_error "Done.", "notice", "<";

#  my $data_validator = new ModENCODE::Validator::Data();
#  $data_validator->validate($experiment);

$writer->write_chadoxml($experiment);
#print $experiment->to_string();



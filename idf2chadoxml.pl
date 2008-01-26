#!/usr/bin/perl

use strict;
use Carp qw(croak carp);
use ModENCODE::Parser::IDF;
use ModENCODE::Chado::XMLWriter;
use ModENCODE::Validator::IDF_SDRF;
use ModENCODE::Validator::Wiki;
use ModENCODE::Validator::TermSources;
use ModENCODE::Validator::CVHandler;


print STDERR "Parsing IDF and SDRF...\n";
my $parser = new ModENCODE::Parser::IDF();
my $writer = new ModENCODE::Chado::XMLWriter();

my ($experiment, $protocols, $sdrfs, $termsources) = @{$parser->parse($ARGV[0])};
print STDERR "Done.\n";

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

# Validate IDF vs. SDRF
  print STDERR "Validating IDF vs SDRF...\n";
  my $idf_validator = new ModENCODE::Validator::IDF_SDRF({
      'idf_experiment' => $experiment,
      'protocols' => $protocols,
      'termsources' => $termsources,
    });
  my $sdrf = @$sdrfs->[0];
  my $success = $idf_validator->validate($sdrf);
  $experiment = $idf_validator->merge($sdrf);
  print STDERR "Done.\n";

  print STDERR "Validating IDF and SDRF vs wiki...\n";
  my $wiki_validator = new ModENCODE::Validator::Wiki({ 
      'termsources' => $termsources,
      'cvhandler' => $cvhandler,
    });
  $wiki_validator->validate($experiment);
  print STDERR "Done.\n";
  print STDERR "Merging wiki data into experiment...\n";
  $experiment = $wiki_validator->merge($experiment);
  print STDERR "Done.\n";

  print STDERR "Validating term sources (DBXrefs) against known ontologies.\n";
  my $termsource_validator = new ModENCODE::Validator::TermSources({
      'cvhandler' => $cvhandler,
    });
  $termsource_validator->validate($experiment);
  print STDERR "Done.\n";
  print STDERR "Merging missing accessions and/or term names from known ontologies.\n";
  $experiment = $termsource_validator->merge($experiment);
  print STDERR "Done.\n";

#$writer->write_chadoxml($experiment);
#print STDERR $experiment->to_string();



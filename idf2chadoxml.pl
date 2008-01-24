#!/usr/bin/perl

use strict;
use Carp qw(croak carp);
use ModENCODE::Parser::IDF;
use ModENCODE::Chado::XMLWriter;
use ModENCODE::Validator::IDF_SDRF;
use ModENCODE::Validator::Wiki;
use ModENCODE::Validator::TermSources;


print "Parsing IDF and SDRF...\n";
my $parser = new ModENCODE::Parser::IDF();
my $writer = new ModENCODE::Chado::XMLWriter();

my ($experiment, $protocols, $sdrfs, $termsources) = @{$parser->parse($ARGV[0])};
print "Done.\n";

#print $experiment->to_string();
#print "\nPROTOCOLS:\n" . join("\n", map { $_->to_string() } @$protocols) . "\n";
#print "\nSDRF:\n" . join("\n", map { $_->to_string() } @$sdrfs) . "\n";
#print "\nTERMSOURCES:\n  " . join("\n  ", map { $_->to_string() } @$termsources) . "\n";

# Validate IDF vs. SDRF
print STDERR "Validating IDF vs SDRF...\n";
my $idf_validator = new ModENCODE::Validator::IDF_SDRF({
    'idf_experiment' => $experiment,
    'protocols' => $protocols,
    'termsources' => $termsources,
  });
my $merged_sdrf;
foreach my $sdrf (@$sdrfs) {
  my $success = $idf_validator->validate($sdrf);
  if ($success) { 
    $merged_sdrf = $idf_validator->merge($sdrf);
  } else {
    croak "Couldn't validate SDRF vs. IDF";
  }
}
print STDERR "Done.\n";

print STDERR "Validating IDF and SDRF vs wiki...\n";
my $wiki_validator = new ModENCODE::Validator::Wiki({ 
    'termsources' => $termsources 
  });
$wiki_validator->validate($merged_sdrf);
print STDERR "Done.\n";
print STDERR "Merging wiki data into experiment...\n";
my $wiki_merged_experiment = $wiki_validator->merge($merged_sdrf);
print STDERR "Done.\n";
print STDERR "Validating term sources (DBXrefs) against known ontologies.\n";
my $termsource_validator = new ModENCODE::Validator::TermSources({
    'termsources' => $termsources,
  });
$termsource_validator->validate($wiki_merged_experiment);
print STDERR "Done.\n";
print STDERR "Merging missing accessions and/or term names from known ontologies.\n";
my $termsource_merged_experiment = $termsource_validator->merge($wiki_merged_experiment);
print STDERR "Done.\n";
print $termsource_merged_experiment->to_string();

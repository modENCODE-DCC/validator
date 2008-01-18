#!/usr/bin/perl

use strict;
use Carp qw(croak carp);
use ModENCODE::Parser::IDF;
use ModENCODE::Chado::XMLWriter;
use ModENCODE::Validator::IDF_SDRF;
use ModENCODE::Validator::Wiki;


my $parser = new ModENCODE::Parser::IDF();
my $writer = new ModENCODE::Chado::XMLWriter();

my ($experiment, $protocols, $sdrfs, $termsources) = @{$parser->parse($ARGV[0])};

#print $experiment->to_string();
#print "\nPROTOCOLS:\n" . join("\n", map { $_->to_string() } @$protocols) . "\n";
#print "\nSDRF:\n" . join("\n", map { $_->to_string() } @$sdrfs) . "\n";
#print "\nTERMSOURCES:\n  " . join("\n  ", map { $_->to_string() } @$termsources) . "\n";

# Validate IDF vs. SDRF
print STDERR "Reading IDF...\n";
my $idf_validator = new ModENCODE::Validator::IDF_SDRF({
    'idf_experiment' => $experiment,
    'protocols' => $protocols,
    'termsources' => $termsources,
  });
print STDERR "  Done.\n";
print STDERR "Validating IDF vs SDRF...\n";
my $merged_sdrf;
foreach my $sdrf (@$sdrfs) {
  my $success = $idf_validator->validate($sdrf);
  if ($success) { 
    $merged_sdrf = $idf_validator->merge($sdrf);
  } else {
    croak "Couldn't validate SDRF vs. IDF";
  }
}
print STDERR "  Done.\n";

print STDERR "Validating IDF and SDRF vs wiki...\n";
my $wiki_validator = new ModENCODE::Validator::Wiki();
$wiki_validator->validate($merged_sdrf);
print STDERR "  Done.\n";

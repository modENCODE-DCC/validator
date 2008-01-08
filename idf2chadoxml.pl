#!/usr/bin/perl

use strict;
use ModENCODE::Parser::IDF;
use ModENCODE::Chado::XMLWriter;
use ModENCODE::Validator::IDF_SDRF;


my $parser = new ModENCODE::Parser::IDF();
my $writer = new ModENCODE::Chado::XMLWriter();

my ($experiment, $protocols, $sdrfs, $termsources) = @{$parser->parse($ARGV[0])};

#print $experiment->to_string();
#print "\nPROTOCOLS:\n" . join("\n", map { $_->to_string() } @$protocols) . "\n";
#print "\nSDRF:\n" . join("\n", map { $_->to_string() } @$sdrfs) . "\n";
#print "\nTERMSOURCES:\n  " . join("\n  ", map { $_->to_string() } @$termsources) . "\n";

# Validate IDF vs. SDRF
my $idf_validator = new ModENCODE::Validator::IDF_SDRF({
    'idf_experiment' => $experiment,
    'protocols' => $protocols,
    'termsources' => $termsources,
  });
foreach my $sdrf (@$sdrfs) {
  print $sdrf->to_string();
  print "--------------------------------------------------\n";
  $sdrf = $idf_validator->validate($sdrf);
  print "--------------------------------------------------\n";
  print $sdrf->to_string();
}

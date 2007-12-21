#!/usr/bin/perl

use strict;
use ModENCODE::Parser::SDRF;
use ModENCODE::Chado::XMLWriter;


my $parser = new ModENCODE::Parser::SDRF;
my $writer = new ModENCODE::Chado::XMLWriter;

my $experiment = $parser->parse($ARGV[0]);
#print $experiment->to_string();
$writer->write_chadoxml($experiment);

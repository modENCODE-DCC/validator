#!/usr/bin/perl

use strict;
my $root_dir;
BEGIN {
  $root_dir = $0;
  $root_dir =~ s/[^\/]*$//;
  $root_dir = "./" unless $root_dir =~ /\//;
  push @INC, $root_dir;
}
use ModENCODE::Parser::Chado;
use ModENCODE::Chado::XMLWriter;
use Data::Dumper;
use ModENCODE::Validator::Data;
use ModENCODE::Validator::Attributes;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;
use ModENCODE::Validator::TermSources;

$ModENCODE::ErrorHandler::show_logtype = 1;
ModENCODE::Config::set_cfg($root_dir . 'validator.ini');

my $experiment_id = $ARGV[0];

my $reader = new ModENCODE::Parser::Chado({ 
    'dbname' => 'mepipe' ,
    'host' => 'smaug.lbl.gov',
    'username' => 'db_public',
    'password' => 'pw',
  });
my $writer = new ModENCODE::Chado::XMLWriter();

if (!$experiment_id) {
  print "Available experiments are:\n";
  my @exp_strings = map { $_->{'experiment_id'} . "\t\"" . $_->{'uniquename'} . "\"" } @{$reader->get_available_experiments()};
  print "  ID\tName\n";
  print "  " . join("\n  ", @exp_strings);
  print "\n";
} else {
  $reader->load_experiment($experiment_id);
  my $experiment = $reader->get_experiment();

  # Do more merges/validations here
#  my $data_validator = new ModENCODE::Validator::Data();
#  $data_validator->validate($experiment);

  # Validate and merge attached data files and remote resources (BED, Wiggle, ASN.1, dbEST, etc.)
#  log_error "Reading data files.", "notice", ">";
#  my $data_validator = new ModENCODE::Validator::Data();
#  $data_validator->validate($experiment);
#  $experiment = $data_validator->merge($experiment);
#  log_error "Done.", "notice", "<";
#  $data_validator = undef;

#$writer->write_chadoxml($experiment);
#print "\n\n\n...................................................................................\n\n\n";

  # Validate and merge term source (make sure terms exist in CVs, fetch missing accessions, etc.)
#  log_error "Validating term sources (DBXrefs) against known ontologies.", "notice", ">";
#  my $termsource_validator = new ModENCODE::Validator::TermSources();
#  $termsource_validator->validate($experiment);
#  log_error "Done.", "notice", "<";
#  log_error "Merging missing accessions and/or term names from known ontologies.", "notice", ">";
#  $experiment = $termsource_validator->merge($experiment);
#  log_error "Done.", "notice", "<";


$writer->write_chadoxml($experiment);
#print $experiment->to_string();
}

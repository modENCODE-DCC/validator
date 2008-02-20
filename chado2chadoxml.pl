#!/usr/bin/perl

use strict;
use ModENCODE::Parser::Chado;
use ModENCODE::Chado::XMLWriter;
use Data::Dumper;
use ModENCODE::Validator::Data;
use ModENCODE::Validator::Attributes;
use ModENCODE::ErrorHandler qw(log_error);

$ModENCODE::ErrorHandler::show_logtype = 1;

my $experiment_id = $ARGV[0];

my $reader = new ModENCODE::Parser::Chado({ 
    'dbname' => 'mepipe' ,
    'host' => 'localhost',
    'username' => 'db_public',
    'password' => 'limecat',
  });

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

  # Validate and merge expanded columns (attributes, etc)
  log_error "Expanding attribute columns.", "notice", ">";
  my $attribute_validator = new ModENCODE::Validator::Attributes();
  $attribute_validator->validate($experiment);
  $experiment = $attribute_validator->merge($experiment);
  log_error "Done.", "notice", "<";

  my $writer = new ModENCODE::Chado::XMLWriter();
  $writer->write_chadoxml($experiment);
}

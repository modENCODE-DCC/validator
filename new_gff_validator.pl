#!/usr/bin/perl

use strict;

# a standalone gff validator since the old one seems incredibly out of date
# Usage: /new_gff_validator.pl gff_file_path


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

my $experiment = new ModENCODE::Chado::Experiment() ;

# so what i want to do is make some datums with applied_protocol, direction, and dataum

my $gff_file = $ARGV[0] ;

my $validator = new ModENCODE::Validator::Data::GFF3({ 'experiment' => $experiment});


log_error "Validating $gff_file as standalone", "notice", ">";

# make a fake datum

my $datum = new ModENCODE::Chado::Data({
  'chadoxml_id' => 'Data_1',
  'name' => 'whatever',
  'heading' => 'whatever',
  'value' =>  $gff_file,
  'anonymous' => 0
});

# create ap_datum from gff file
my $ap_datum = ["", "", $datum]  ; # =  TODO

$validator->add_datum_pair($ap_datum) ;

$validator->validate();

ModENCODE::Cache::destroy();

1;

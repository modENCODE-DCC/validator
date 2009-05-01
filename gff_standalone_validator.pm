#!/usr/bin/perl

# This is a helper module to specifically check the syntax of GFF3 files 
# for the modENCODE project.
# you will probably have to install some additional perl modules like 
# DBD::SQLite, and possibly others, using CPAN.

# use this like:  ./gff_standalone_validator.pm <path_to_file>

use strict;

my $root_dir;
BEGIN {
  $root_dir = $0;
  $root_dir =~ s/[^\/]*$//;
  $root_dir = "./" unless $root_dir =~ /\//;
  push @INC, $root_dir;
}

use Class::Std;
use Data::Dumper;
use Carp qw(croak carp);
use ModENCODE::Parser::GFF3;
use ModENCODE::Cache;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Validator::Data::GFF3;
use ModENCODE::Chado::Attribute;
use ModENCODE::Config;

ModENCODE::Config::set_cfg($root_dir . 'validator.ini');
ModENCODE::Cache::init();

my $config = ModENCODE::Config::get_cfg();
my @build_config_strings = $config->GroupMembers('genome_build');
my $build_config = {};
foreach my $build_config_string (@build_config_strings) {
	my (undef, $source, $build) = split(/ +/, $build_config_string);
	$build_config->{$source} = {} unless $build_config->{$source};
	$build_config->{$source}->{$build} = {} unless $build_config->{$source}->{$build};
	my @chromosomes = split(/, */, $config->val($build_config_string, 'chromosomes'));
	my $type = $config->val($build_config_string, 'type');
	foreach my $chr (@chromosomes) {
		$build_config->{$source}->{$build}->{$chr}->{'seq_id'} = $chr;
		$build_config->{$source}->{$build}->{$chr}->{'type'} = $type;
		$build_config->{$source}->{$build}->{$chr}->{'start'} = $config->val($build_config_string, $chr . '_start');
		$build_config->{$source}->{$build}->{$chr}->{'end'} = $config->val($build_config_string, $chr . '_end');
		$build_config->{$source}->{$build}->{$chr}->{'organism'} = $config->val($build_config_string, 'organism');
	}
}

my $gff_submission_name = ModENCODE::Config::get_submission_pipeline_name;
$gff_submission_name =~ s/[^0-9A-Za-z]/_/g;
my $gff_file_name = $ARGV[0];
croak "$gff_file_name is not readable" unless -r $gff_file_name;
#my $FH;
#open $FH, "<", $filename or croak "Can't open $filename for reading.";


#use ModENCODE::Parser::GFF3;
my $gff_counter = 1;
my $feature_types = {};

sub id_callback {
  my ($parser, $id, $name, $seqid, $source, $type, $start, $end, $score, $strand, $phase) = @_;
  $id ||= "gff_" . sprintf("ID%.6d", ++$gff_counter);
  if ($end < $start) {
      die "Your end coord $end is less than your start coord $start.\n  This is not allowed "
  }
  if ($type =~ m/\S+/) {
    if (!exists  $feature_types->{ $type }) {
        print STDERR $type . " feature type found\n";
        $feature_types->{ $type } = 0;
      }
    $feature_types->{ $type }+=1;
  }
  if ($type !~ /^(gene|transcript|CDS|EST|chromosome|chromosome_arm)$/) {
    $id = $parser->{'gff_submission_name'} . "." . $id;
  }
  return $id;
}

open(GFF, "$gff_file_name") or die "Couldn't open GFF file $gff_file_name";

my $parser = new ModENCODE::Parser::GFF3({
    'gff3' => \*GFF,
    'builds' => $build_config,
    'id_callback' => *id_callback,
    'source_prefix' => $gff_submission_name,
   });
$parser->{'gff_submission_name'} = $gff_submission_name;

my $group_iter = $parser->iterator();
my $group_num = 0;
while ($group_iter->has_next()) {
    print STDERR "Processing GFF feature group #$group_num.\n";
    $group_num++;
    my @features = $group_iter->next();
    print STDERR scalar(@features) . " features found.\n";
}
while ( my ($key, $value) = each(%$feature_types) ) {
        print STDERR "Processed $value $key features.\n";
    }
close GFF;

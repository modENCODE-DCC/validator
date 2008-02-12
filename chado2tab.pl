#!/usr/bin/perl

use strict;
use ModENCODE::Parser::Chado;
use Data::Dumper;
use DBI;
use ModENCODE::Chado::AppliedProtocol;
use ModENCODE::Chado::Protocol;
use ModENCODE::Chado::Data;
use ModENCODE::Chado::DB;
use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::Attribute;

my $dbh; # = DBI->connect("dbi:Pg:dbname=mepipe;host=localhost", "db_public", "limecat") or die "Couldn't connect to DB";

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
  #my $protocol_slots = $reader->get_normalized_protocol_slots();
  #foreach my $applied_protocols (@$protocol_slots) {
  #print join("\n", map { $_->to_string() } @$applied_protocols) . "\n";
  #}
  #print Dumper($reader->get_denormalized_protocol_slots());
  #print Dumper($reader->get_tsv_columns());
  print $reader->get_tsv();
  #print $reader->get_experiment()->to_string();
}

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
  my $experiment = $reader->get_experiment();
  
  print "digraph nodes {\n";
  print "  node [shape=record];\n";
  print "  experiment [label=\"<name> experiment|<value> " . $experiment->get_uniquename() . "\"];\n";
  my @seen_thing;
  for (my $i = 0; $i < $experiment->get_num_applied_protocol_slots(); $i++) {
    foreach my $ap (@{$experiment->get_applied_protocols_at_slot($i)}) {
      if ( !scalar(grep { $ap->equals($_) } @seen_thing) ) {
        push @seen_thing, $ap;
        print "  AP" . $ap->get_chadoxml_id() . " [label=\"<name> applied protocol|<value> " . $ap->get_protocol()->get_name() . "\"];\n";
      }
      foreach my $datum (@{$ap->get_input_data()}) {
        if ( !scalar(grep { $datum->equals($_) } @seen_thing) ) {
          push @seen_thing, $datum;
          print "  DT" . $datum->get_chadoxml_id() . " [label=\"<name> " . $datum->get_heading() . "|<value> " . substr($datum->get_value(), 0, 5) . "\"];\n";
        }
        print "  DT" . $datum->get_chadoxml_id() . " -> AP" . $ap->get_chadoxml_id() . ";\n";
      }
      foreach my $datum (@{$ap->get_output_data()}) {
        if ( !scalar(grep { $datum->equals($_) } @seen_thing) ) {
          push @seen_thing, $datum;
          print "  DT" . $datum->get_chadoxml_id() . " [label=\"<name> " . $datum->get_heading() . "|<value> " . substr($datum->get_value(), 0, 5) . "\"];\n";
        }
        print "  AP" . $ap->get_chadoxml_id() . " -> DT" . $datum->get_chadoxml_id() . ";\n";
      }
    }
  }
  foreach my $first_ap (@{$experiment->get_applied_protocols_at_slot(0)}) {
#    print "  experiment -> AP" . $first_ap->get_chadoxml_id() . ";\n";
  }
  print "}\n";
}



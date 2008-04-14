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
use ModENCODE::Config;
use ModENCODE::ErrorHandler qw(log_error);

$ModENCODE::ErrorHandler::show_logtype = 1;
ModENCODE::Config::set_cfg($root_dir . 'validator.ini');

my $experiment_id = $ARGV[0];

my $reader = new ModENCODE::Parser::Chado({ 
    'dbname' => ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname'),
    'host' => ModENCODE::Config::get_cfg()->val('databases modencode', 'host'),
    'port' => ModENCODE::Config::get_cfg()->val('databases modencode', 'port'),
    'username' => ModENCODE::Config::get_cfg()->val('databases modencode', 'username'),
    'password' => ModENCODE::Config::get_cfg()->val('databases modencode', 'password'),
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
  print "  experiment [rank=source,label=\"<name> experiment|<value> " . $experiment->get_uniquename() . "\"];\n";
  my @seen_thing;
  my @seen_rel;
  for (my $i = 0; $i < $experiment->get_num_applied_protocol_slots(); $i++) {
    foreach my $ap (@{$experiment->get_applied_protocols_at_slot($i)}) {
      my $ap_node = "AP" . $ap->get_protocol()->get_name();
      $ap_node = ($ap_node);
      if (!scalar(grep { $ap_node eq $_ } @seen_thing)) {
        push @seen_thing, $ap_node;
        print "  \"" . $ap_node . "\" [label=\"<name> Protocol|<value> " . $ap->get_protocol()->get_name() . "\"];\n";
        my $rel = "\"experiment\" -> \"$ap_node\" [minlen=2]";
        if (!scalar(grep { $rel eq $_ } @seen_rel)) {
          push @seen_rel, $rel;
          print "  $rel;\n" if $i == 0;
        }
      }
      foreach my $datum (@{$ap->get_output_data()}) {
        my $dt_node = "DT" . $datum->get_heading() . "_" . $datum->get_name() . "_" . $datum->get_type()->get_cv()->get_name() . "_" . $datum->get_type()->get_name();
        $dt_node = ($dt_node);
        my $dt_name = $datum->get_name() || $datum->get_heading();
        if (!scalar(grep { $dt_node eq $_ } @seen_thing)) {
          push @seen_thing, $dt_node;
          print "  \"" . $dt_node . "\" [label=\"<name> $dt_name\"];\n";
        }
        my $rel = "\"$ap_node\" -> \"$dt_node\"";
        if (!scalar(grep { $rel eq $_ } @seen_rel)) {
          push @seen_rel, $rel;
          print "  $rel;\n";
        }
      }
      foreach my $datum (@{$ap->get_input_data()}) {
        my $dt_node = "DT" . $datum->get_heading() . "_" . $datum->get_name() . "_" . $datum->get_type()->get_cv()->get_name() . "_" . $datum->get_type()->get_name();
        $dt_node = ($dt_node);
        my $dt_name = $datum->get_name() || $datum->get_heading();
        my $minlen = 2;
        if (!scalar(grep { $dt_node eq $_ } @seen_thing)) {
          push @seen_thing, $dt_node;
          print "  \"" . $dt_node . "\" [label=\"<name> $dt_name\"];\n";
          $minlen = 1;
        }
        my $rel = "\"$dt_node\" -> \"$ap_node\"";
        if (!scalar(grep { $rel eq $_ } @seen_rel)) {
          push @seen_rel, $rel;
          print "  $rel [minlen=$minlen];\n";
        }
      }
    }
  }
  print "}\n";
}

sub escape {
  my ($str) = @_;
  $str =~ s/\s/&nbsp;/g;
  $str =~ s/\(/&#40;/g;
  $str =~ s/\)/&#41;/g;
  return $str;
}



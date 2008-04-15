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
use ModENCODE::Config;
use ModENCODE::ErrorHandler qw(log_error);

$ModENCODE::ErrorHandler::show_logtype = 1;
ModENCODE::Config::set_cfg($root_dir . 'validator.ini');

my $argtype = $ARGV[0];
my $id = $ARGV[1];
my $datum_id = $ARGV[1];
if ($argtype eq "experiment" && $ARGV[1]) {
  my $experiment_id = $ARGV[1];
  my @seen_analyses;
  my $dbh = get_dbh();
  my $string = "ID\tProgram\tProgramversion\tSourcename\n";
  my $get_next_applied_protocols_sth = $dbh->prepare("SELECT 
    apd.applied_protocol_id 
    FROM applied_protocol_data apd 
    WHERE apd.data_id = ? AND apd.direction = 'input'
    ");
  my $get_first_protos_sth = $dbh->prepare("SELECT DISTINCT
    apd_output.data_id AS output_id,
    apd_input.data_id AS input_id
    FROM experiment_applied_protocol eap
    INNER JOIN applied_protocol ap ON eap.first_applied_protocol_id = ap.applied_protocol_id
    INNER JOIN applied_protocol_data apd_output ON ap.applied_protocol_id = apd_output.applied_protocol_id AND apd_output.direction = 'output'
    INNER JOIN applied_protocol_data apd_input ON ap.applied_protocol_id = apd_input.applied_protocol_id AND apd_input.direction = 'input'
    WHERE eap.experiment_id = ?
    ");
  my $get_analyses_sth = $dbh->prepare("SELECT
    DISTINCT a.analysis_id, a.program, a.programversion, a.sourcename 
    FROM data_feature df
    INNER JOIN analysisfeature af ON df.feature_id = af.feature_id
    INNER JOIN analysis a ON af.analysis_id = a.analysis_id
    WHERE df.data_id = ?
    ");
  $get_first_protos_sth->execute($ARGV[1]);
  my %analyses;
  my @output_data;
  while (my $row = $get_first_protos_sth->fetchrow_hashref()) {
    push @output_data, $row->{'output_id'} unless grep { $_ == $row->{'output_id'} } @output_data;
  }
  while (scalar(@output_data)) {
    # Get all analyses for this protocol
    while (my $data_id = shift @output_data) {
      $get_analyses_sth->execute($data_id);
      while (my $row = $get_analyses_sth->fetchrow_hashref()) {
        $analyses{$row->{'analysis_id'}} = $row->{'analysis_id'} . "\t" . $row->{'program'} . "\t" . $row->{'programversion'} . "\t" . $row->{'sourcename'};
      }
    }
  }

  $string .= join("\n", values(%analyses)) . "\n";
  $dbh->disconnect();

  print make_cols($string);
} elsif ($argtype eq "analysis" && $ARGV[1]) {
  my $dbh = get_dbh();
  my $sth_get_matches = $dbh->prepare("SELECT
    a.program, a.programversion, a.sourcename,
    match.feature_id AS match_id, match.name AS match_name, af_match.rawscore AS match_score,
    match_part.feature_id AS match_part_id, match_part.name as match_part_name, af_match_part.rawscore AS match_part_score
    FROM analysis a
    INNER JOIN analysisfeature af_match ON a.analysis_id = af_match.analysis_id
    INNER JOIN analysisfeature af_match_part ON a.analysis_id = af_match_part.analysis_id

    INNER JOIN feature match ON af_match.feature_id = match.feature_id
    INNER JOIN cvterm matchtype ON match.type_id = matchtype.cvterm_id

    INNER JOIN feature match_part ON af_match_part.feature_id = match_part.feature_id
    INNER JOIN cvterm match_parttype ON match_part.type_id = match_parttype.cvterm_id

    INNER JOIN feature_relationship fr ON match_part.feature_id = fr.subject_id AND match.feature_id = fr.object_id
    INNER JOIN cvterm frtype ON fr.type_id = frtype.cvterm_id

    WHERE 
    matchtype.name = 'match'
    AND match_parttype.name = 'match_part'
    AND frtype.name = 'part_of'
    AND a.analysis_id = ?

    ORDER BY match_id
    ");
  my $sth_get_locs = $dbh->prepare("SELECT
    fl.fmin, fl.fmax, fl.strand, fl.phase, fl.rank,
    f.name, f.uniquename, ftype.name AS type
    FROM featureloc fl
    INNER JOIN feature f ON fl.srcfeature_id = f.feature_id
    INNER JOIN cvterm ftype ON f.type_id = ftype.cvterm_id
    WHERE fl.feature_id = ?
    ");
  my @seen_matches;
  $sth_get_matches->execute($ARGV[1]);
  while (my $afrow = $sth_get_matches->fetchrow_hashref()) {
    if (!scalar(grep { $_ == $afrow->{'match_id'} } @seen_matches)) {
      # Write the GFF match
      push @seen_matches, $afrow->{'match_id'};
      $sth_get_locs->execute($afrow->{'match_id'});
      # Should be one row for chromosome and one for EST
      my $estrow = $sth_get_locs->fetchrow_hashref();
      my $chrrow = $sth_get_locs->fetchrow_hashref();
      if ($estrow->{'type'} ne "EST") { $_ = $estrow; $estrow = $chrrow; $chrrow = $_; }
      my @gff_cols = (
        $chrrow->{'name'},
        $afrow->{'program'} . "-" . $afrow->{'programversion'},
        $chrrow->{'type'},
        $chrrow->{'fmin'},
        $chrrow->{'fmax'},
        length($chrrow->{'score'}) ? $chrrow->{'score'} : '.',
        length($chrrow->{'strand'}) ? ($chrrow->{'strand'} > 0 ? '+' : '-') : '.',
        length($chrrow->{'phase'}) ? $chrrow->{'phase'} : '.',
        'ID=match_' . $afrow->{'match_id'} . ";Name=" . $afrow->{'match_name'} . 
        ";Target=" . $estrow->{'uniquename'} . " " . $estrow->{'fmin'} . " " . $estrow->{'fmax'} . " " . (length($chrrow->{'strand'}) ? ($chrrow->{'strand'} > 0 ? '+' : '-') : '.')
      );
      print "\n" . join("\t", @gff_cols) . "\n";
    }
    $sth_get_locs->execute($afrow->{'match_part_id'});
    my $estrow = $sth_get_locs->fetchrow_hashref();
    my $chrrow = $sth_get_locs->fetchrow_hashref();
    if ($estrow->{'type'} ne "EST") { $_ = $estrow; $estrow = $chrrow; $chrrow = $_; }
    my @gff_cols = (
      $chrrow->{'name'},
      $afrow->{'program'} . "-" . $afrow->{'programversion'},
      $chrrow->{'type'},
      $chrrow->{'fmin'},
      $chrrow->{'fmax'},
      length($chrrow->{'score'}) ? $chrrow->{'score'} : '.',
      length($chrrow->{'strand'}) ? ($chrrow->{'strand'} > 0 ? '+' : '-') : '.',
      length($chrrow->{'phase'}) ? $chrrow->{'phase'} : '.',
      'ID=match_part_' . $afrow->{'match_part_id'} . ";Name=" . $afrow->{'match_part_name'} . 
      ";Parent=match_" . $afrow->{'match_id'} .
      ";Target=" . $estrow->{'uniquename'} . " " . $estrow->{'fmin'} . " " . $estrow->{'fmax'} . " " . (length($chrrow->{'strand'}) ? ($chrrow->{'strand'} > 0 ? '+' : '-') : '.')
    );
    print join("\t", @gff_cols) . "\n";
  }
  $sth_get_matches->finish();
  $sth_get_locs->finish();
  $dbh->disconnect();
} else {
  my $reader = new ModENCODE::Parser::Chado({ 
      'dbname' => ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases modencode', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases modencode', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases modencode', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases modencode', 'password'),
    });
  print "Usage:\n";
  print "  ./chado2gff3.pl\n";
  print "  ./chado2gff3.pl experiment <experiment_id>\n";
  print "  ./chado2gff3.pl analysis <analysis_id>\n\n";
  print "Available experiments are:\n";
  my @exp_strings = map { $_->{'experiment_id'} . "\t\"" . $_->{'uniquename'} . "\"" } @{$reader->get_available_experiments()};
  print "  ID\tName\n";
  print "  " . join("\n  ", @exp_strings);
  print "\n";
}
  
  

sub make_cols {
  my ($string) = @_;
  my $newstring;
  my @coldefs;
  foreach my $line (split /\n/, $string) {
    my @terms = split /\t/, $line;
    for (my $i = 0; $i < scalar(@terms); $i++) {
      $coldefs[$i] = ($coldefs[$i] > length($terms[$i])) ? $coldefs[$i] : length($terms[$i]);
    }
  }
  foreach my $line (split /\n/, $string) {
    my @terms = split /\t/, $line;
    for (my $i = 0; $i < scalar(@terms); $i++) {
      while (length($terms[$i]) < $coldefs[$i] + 3) {
        $terms[$i] .= " ";
      }
      $newstring .= $terms[$i];
    }
    $newstring .= "\n";
  }
  return $newstring;
}

sub get_dbh {
  my $dbname = ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname');
  my $host = ModENCODE::Config::get_cfg()->val('databases modencode', 'host');
  my $port = ModENCODE::Config::get_cfg()->val('databases modencode', 'port');
  my $username = ModENCODE::Config::get_cfg()->val('databases modencode', 'username');
  my $password = ModENCODE::Config::get_cfg()->val('databases modencode', 'password');
  my $dsn = "dbi:Pg:dbname=$dbname";
  $dsn .= ";host=" . $host if length($host);
  $dsn .= ";port=" . $port if length($port);
  my $dbh;
  eval {
    $dbh = DBI->connect($dsn, $username, $password, { RaiseError => 1, AutoCommit => 0 });
  };

  if (!defined($dbh) || !$dbh) {
    log_error "Couldn't connect to data source \"$dsn\", using username \"$username\" and password \"$password\"\n  " . $DBI::errstr;
    exit;
  }
  return $dbh;
}

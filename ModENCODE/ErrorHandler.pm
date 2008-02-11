package ModENCODE::ErrorHandler;

use strict;
use Exporter 'import';

our @EXPORT_OK = qw(log_error);

my $show_logtype = 0;
my $seen_errors = {
  'warning' => [],
  'error' => [],
  'notice' => [],
};
my $indent = 0;

sub log_error {
  my ($message, $level, $change_indent) = @_;
  # change_indent:
  # blank means add newline
  # > means increase indent and add newline
  # < means decrease indent and add newline
  # . means do not change indent, do not print spaces, and do not add newline
  # = means do not change indent, do print spaces, and do not add newline
  $ModENCODE::ErrorHandler::indent-- if ($change_indent eq "<");
  STDERR->autoflush(1) if ($change_indent eq "." || $change_indent eq "=");

  # Standardize the level name
  $level = 'error' if ($level =~ m/error/i);
  $level = 'warning' if ($level =~ m/warning/i);
  $level = 'notice' if ($level =~ m/notice/i);
  $level = 'error' unless $level;
  my @seen_error = grep { $_ eq $message } @{$ModENCODE::ErrorHandler::seen_errors->{$level}};
  # Only print if we haven't seen this message before or if it's a notice
  if ((!scalar(@seen_error) || $level eq 'notice') && length($message)) {
    my $levelprefix;
    $levelprefix = "Warning: " if ($level eq 'warning');
    $levelprefix = "Error: " if ($level eq 'error');
    $levelprefix = "" if ($level eq 'notice');

    # Make indenting spaces
    my $spaces = "";
    for (my $i = 0; $i < $ModENCODE::ErrorHandler::indent; $i++) {
      $spaces .= "    ";
    }
    if ($ModENCODE::ErrorHandler::show_logtype) {
      my $logtype = uc($level . ":");
      while (length($logtype) < length("WARNING:    ")) {
        $logtype .= " ";
      }
      print STDERR $logtype unless $change_indent eq ".";
    }
    print STDERR $spaces unless $change_indent eq ".";
    print STDERR $levelprefix unless $change_indent eq "." || $change_indent eq "=";

    print STDERR $message;

    print STDERR "\n" unless $change_indent eq "." || $change_indent eq "=";

    # Turn off autoflushing
    STDERR->autoflush(0);

    # Record that this error message has been seen
    push(@{$ModENCODE::ErrorHandler::seen_errors->{$level}}, $message);
  }

  $ModENCODE::ErrorHandler::indent++ if ($change_indent eq ">");
}

1;

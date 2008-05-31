package ModENCODE::ErrorHandler;
=pod

=head1 NAME

ModENCODE::ErrorHandler - A utility class for logging errors in a nicely
formatted way.

=head1 SYNOPSIS

This class provides global/static access to a function L</log_error($message,
$level, $change_indent)> that allows unified logging. The default logger outputs
errors to STDOUT, but this class can be extended and a new logging scheme used
by calling L</set_logger($logger)>.

=head1 USAGE

This class exists as a self-creating factory; the default error handler is an
instance of ModENCODE::ErrorHandler, while actual logging should be done by
calling the static method L</log_error($message, $level, $change_indent)>.

  use ModENCODE::ErrorHandler qw(log_error);
  ModENCODE::ErrorHandler::set_logtype(
    ModENCODE::ErrorHandler::LOGGING_PREFIX_ON
  );

  log_error "Oh no, terrible things have happened.", "error";

=head2 Public Functions

=over

=item set_logger($logger)

Use a non-default C<$logger>, which must be a subclass of ModENCODE::ErrorHandler.

=item set_logtype($logtype)

The default logger supports two options:
C<ModENCODE::ErrorHandler::LOGGING_PREFIX_OFF> and  
C<ModENCODE::ErrorHandler::LOGGING_PREFIX_ON>. When turned on, prefixes each line
with the level of the error that occured (notice, warning, or error). 

=item log_error($message, $level, $change_indent)

Given a $message, with an optional level and change to indent style, log the
error using the current C<$logger>'s L<_log_error($message, $level,
$change_indent)> method. All arguments (C<@_>) are actually passed on to
C<_log_error>, which allows some flexibility in extensions.

=item _log_error($message, $level, $change_indent)

The default logging function. Logs C<$message> to B<C<STDERR>> with various
formatting. C<$level> is optional, and can be 'notice', 'warning', or 'error'.
The default is 'error'. If the error has been previously printed, it will not be
printed again unless the level is 'notice'; this is to prevent spamming of
syntax errors, among other things.

The error message is prefixed with the level (in all caps) if the
L<$logtype|/set_logtype($logtype)> is set to LOGGING_PREFIX_ON.

The optional C<$change_indent> argument allows the indenting to be changed, or
newlines to be temporarily omitted to allow multiple C<log_error> calls to
output on the same line (e.g. C<Parsing foo... Done.>).

=over

=over

=item C<blank> means add newline

=item C<E<gt>> means increase indent and add newline

=item C<E<lt>> means decrease indent and add newline

=item C<.> means do not change indent, do not print spaces, and do not add newline

=item C<=> means do not change indent, do print spaces, and do not add newline

=back

=back

=back

=head1 SEE ALSO

L<Class::Std>, L<All ModENCODE modules|index>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Exporter 'import';
use IO::Handle;
use Class::Std;

our @EXPORT_OK = qw(log_error);


use constant LOGGING_PREFIX_OFF => 0;
use constant LOGGING_PREFIX_ON => 1;

my %indent           :ATTR( :name<indent>,              :default<0> );
my %seen_errors      :ATTR( :name<seen_errors> );
my %show_logtype     :ATTR( :name<show_logtype>,        :default<0> );

my $logger;

sub BUILD {
  my ($self, $ident, $args) = @_;
  $seen_errors{$ident} = {
    'warning' => [],
    'error' => [],
    'notice' => [] 
  };
}

sub set_logger {
  my ($new_logger) = @_;
  if ($new_logger->isa('ModENCODE::ErrorHandler')) {
    $logger = $new_logger;
  } else {
    log_error("Unable to use a '" . ref($new_logger) . "' as a ModENCODE::ErrorHandler logger as it does not subclass ModENCODE::ErrorHandler. Reverting to default.", "warning");
  }
}

sub set_logtype {
  $logger = new ModENCODE::ErrorHandler() unless $logger;
  $logger->set_show_logtype(@_);
}

sub log_error {
  $logger = new ModENCODE::ErrorHandler() unless $logger;
  $logger->_log_error(@_);
}

sub _log_error {
  my ($self, $message, $level, $change_indent) = @_;
  # change_indent:
  # blank means add newline
  # > means increase indent and add newline
  # < means decrease indent and add newline
  # . means do not change indent, do not print spaces, and do not add newline
  # = means do not change indent, do print spaces, and do not add newline
  $indent{ident $self}-- if ($change_indent eq "<");
  STDERR->autoflush(1) if ($change_indent eq "." || $change_indent eq "=");

  # Standardize the level name
  $level = 'error' if ($level =~ m/error/i);
  $level = 'warning' if ($level =~ m/warning/i);
  $level = 'notice' if ($level =~ m/notice/i);
  $level = 'error' unless $level;
  my @seen_error = grep { $_ eq $message } @{$self->get_seen_errors()->{$level}};
  # Only print if we haven't seen this message before or if it's a notice
  if ((!scalar(@seen_error) || $level eq 'notice') && length($message)) {
    my $levelprefix;
    $levelprefix = "Warning: " if ($level eq 'warning');
    $levelprefix = "Error: " if ($level eq 'error');
    $levelprefix = "" if ($level eq 'notice');

    # Make indenting spaces
    my $spaces = "";
    for (my $i = 0; $i < $self->get_indent(); $i++) {
      $spaces .= "    ";
    }
    if ($self->get_show_logtype()) {
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
    push(@{$self->get_seen_errors()->{$level}}, $message);
  }

  $indent{ident $self}++ if ($change_indent eq ">");
}

1;

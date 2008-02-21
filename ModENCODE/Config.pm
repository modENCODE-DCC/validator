package ModENCODE::Config;

use strict;
use Carp qw(croak carp);
use Config::IniFiles;

my $config_object;

sub get_cfg {
  croak "The ModENCODE::Config object has not been initialized" unless $config_object;
  return $config_object;
}

sub set_cfg {
  my ($inifile) = @_;
  $inifile = "validator.ini" unless length($inifile);
  if (!$config_object) {
    # Create configuration object
    $config_object = new Config::IniFiles(
      -file => $inifile
    );
  }
}

1;

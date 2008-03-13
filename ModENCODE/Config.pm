package ModENCODE::Config;

use strict;
use Carp qw(croak carp);
use Config::IniFiles;
use ModENCODE::Validator::CVHandler;

my $config_object;
my $cvhandler;

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

sub get_cvhandler {
  if (!$cvhandler) {
    $cvhandler = new ModENCODE::Validator::CVHandler();
    my @default_cvs = get_cfg()->GroupMembers('default_cvs');
    foreach my $default_cv (@default_cvs) {
      my ($default_cv_name) = ($default_cv =~ m/^default_cvs\s*(\S+)\s*$/);
      my $default_cv_url = get_cfg()->val($default_cv, 'url');
      my $default_cv_type = get_cfg()->val($default_cv, 'type');
      $cvhandler->add_cv(
        $default_cv_name,
        $default_cv_url,
        $default_cv_type,
      );
    }
  }
  return $cvhandler;
}

1;

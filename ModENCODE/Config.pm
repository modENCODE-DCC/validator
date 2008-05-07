package ModENCODE::Config;
=pod

=head1 NAME

ModENCODE::Config - A utility class for accessing configurations (and configured
controlled vocabulary terms) in a L<Config::IniFiles> compatible ini-file.

=head1 SYNOPSIS

This class provides global/static access to a L<Config::IniFiles> object as well as
a utility function for loading default controlled vocabularies from a properly
formatted ini-file into a L<ModENCODE::Validator::CVHandler>.

=head1 USAGE

=head2 Configuration File Format

The following sections are known to be used by the BIR-TAB validation tool:

=over

=item [wiki]

  [wiki]
  soap_wsdl_url=http://wiki.url/DBFieldsService.wsdl
  cvterm_validator_url=http://wiki.url/DBFieldsCVTerm.php?get_canonical_url=
  username=MediaWikiUser
  password=MediaWikiPassword
  domain=MediaWikiDomain

The C<wiki> section is used by L<ModENCODE::Validator::Wiki> validator. The
C<soap_wsdl_url> should be a URL to a SOAP WSDL file defining the methods for
fetching wiki data based on the DBFields MediaWiki extension. It is expected to
use the C<username>, C<password>, and C<domain> to login to the wiki.

The C<cvterm_validator_url> option is used by L<ModENCODE::Validator::CVHandler>
to get a canonical URL for a given controlled vocabulary name. Since this
functionality is part of the same DBFields extension, it is inlcluded in the
C<wiki> section.

=item [databases ???]

  [database dbname]
  username=db_user
  password=db_user
  host=db_host
  port=db_port
  db_name=db_name

The C<databases> sections are used by a few different modules -
L<ModENCODE::Validator::CVHandler> and L<ModENCODE::Parser::Chado> among others.
The two databases known to be required in the current installation are FlyBase
(a PostgreSQL Chado database, defined in the section C<[databases flybase]>) and
the modENCODE database (a PostgreSQL Chado database with the BIR-TAB extension,
defined in the section C<[databases modencode]>). All of the fields except for
C<db_name> should be optional.

=item [default_cvs ???]

  [default_cvs cvname]
  type=OBO
  url=http://cv.url/cvname.obo

The C<default_cvs> sections are used by the L</get_cvhandler()> function in
ModENCODE::Config to load any controlled vocabularies that will be used
internally by any of the modules of the BIR-TAB validator. When
L</get_cvhandler()> is called, it loads each default_cvs section as a controlled
vocabulary named after the subsection name (in the example above, the subsection
name is "cvname"). That name can then be used when creating new
L<ModENCODE::Chado::CV> objects.

=item [modencode_project ???]

  [modencode_project ProjectName]
  url=http://project.description.url/page.html
  subgroups=ProjectName, GroupB, GroupC

The C<modencode_project> sections are used by the
L<ModENCODE::Validator::ModENCODE_Projects> validator module to validate the
project group and subgroup described in a BIR-TAB IDF document. One of the
subgroups should be the same as the ProjectName to allow the subgroup to
be automatically defined as the same as the parent group if no subgroup is
defined in the IDF, but it is okay for this not to be the case as long as the
subgroup is defined in the IDF.

If the L<ModENCODE_Projects|ModENCODE::Validator::ModENCODE_Projects> modules is
not being used, then these sections are unnecessary.

=back

=head1 FUNCTIONS

=over

=item get_cfg()

Return the L<Config::IniFiles> object associated with this ModENCODE::Config
object. This function dies (using C<croak>) if L</set_cfg()> has not yet been
called.

=item set_cfg($inifile)

Set the ini-file that this ModENCODE::Config object should read options from.

=item get_cvhandler()

Returns a L<ModENCODE::Validator::CVHandler> with any default controlled
vocabularies defined in configuration file already loaded.

=back

=head1 SEE ALSO

L<ModENCODE::Validator::CVHandler>, L<ModENCODE::Validator::Wiki>,
L<ModENCODE::Validator::ModENCODE_Projects>, L<ModENCODE::Parser::Chado>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
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

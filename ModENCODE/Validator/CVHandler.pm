package ModENCODE::Validator::CVHandler;
=pod

=head1 NAME

ModENCODE::Validator::CVHandler - Controlled vocabulary and ontology validator
module used by various other ModENCODE::Validator objects.

=head1 SYNOPSIS

This class is used as a helper class by several ModENCODE::Validator classes,
including L<ModENCODE::Validator::Attributes::URL_mediawiki_expansion>,
L<ModENCODE::Validator::CVHandler>, L<ModENCODE::Validator::TermSources>, and
L<ModENCODE::Validator::Wiki>. It provides methods for validating controlled
vocabulary terms against various types of controlled vocabulary (CV). Currently,
the types of CV supported are OBO-format files
(L<http://www.geneontology.org/GO.format.obo-1_2.shtml>), suffixed URLs (e.g.
C<http://web.site/terms/B<my_term>>), and MediaWiki URLs (where the presence of
a wiki page indicates a valid term).

=head1 USAGE

  use ModENCODE::Config;
  # Get a CVHandler with default controlled vocabulary already loaded
  my $cvhandler = ModENCODE::Config->get_cvhandler();

  # Load the Sequence Ontology into the CVHandler
  $cvhandler->add_cv(
    'SO',
    'http://www.sequenceontology.org/release/2.2/so_2_2.obo',
    'OBO'
  );

  # Parse a CV:term into components
  my $term = $cvhandler->parse_term('SO:transcript');

  # Check the validity of the term
  my $is_valid = $cvhandler->is_valid_term(
    $term->{'cv'},
    $term->{'term'}
  );

  # Does the SO:gene term have an 'isa' relationship to SO:region?
  my $gene_is_a_region = $cvhandler->term_isa('SO', 'gene', 'region');

=head1 FUNCTIONS

=over

=item parse_term($term)

Given a string, attempt to parse it into a CV, term, and BIR-TAB field name. If
used in an array context, the values are returned as C<($cv, $term, $name)>. If
used in a scalar context, a hashref is returned with the keys "cv", "term",
and "name".

=begin html

<dl>
 <dt>term</dt><dd>becomes <code>{ 'term' => "term", 'cv' => undef, 'name' => undef }</code></dd>
 <dt>CV:term</dt><dd>becomes <code>{ 'term' => "term", 'cv' => "CV", 'name' => undef }</code>
 <dt>CV:term [name]</dt><dd>becomes <code>{ 'term' => "term", 'cv' => "CV", 'name' => "name" }</code>
</dl><br/>

=end html

=begin roff

=over

=item C<"term"> becomes { 'term' => "term", 'cv' => undef, 'name' => undef }

=item C<"CV:term"> becomes { 'term' => "term", 'cv' => "CV", 'name' => undef }

=item C<"CV:term [name]"> becomes { 'term' => "term", 'cv' => "CV", 'name' => "name" }

=back

=end roff

=item add_cv($cv, $cvurl, $cvurltype)

Attempts to load a controlled vocabulary named C<$cv> into this CVHandler.

If only C<$cv> is specified, then the handler queries the the URL specified in
the C<cvterm_validator_url> of the C<wiki> section in the configuration file
loaded in ModENCODE::Config by appending C<$cv> to the C<cvterm_validator_url>.
It expects a response in the form:

  <result>
    <canonical_url>http://cvterm.url/cvterm.obo</canonical_url>
    <canonical_url_type>OBO</canonical_url_type>
  </result>

If there is no canonical URL handler, or no canonical URL is returned by the
handler, then C<add_cv> returns 0. Otherwise, it continues as if C<$cvurl> and
C<$cvtype> were specified.

If C<$cv> and one of C<$cvurl> and C<$cvurltype> are specified, then the
canonical URL handler is similarly queried to fill in the missing parameter.


The following values are supported for C<$cvurltype>:

=over

=begin html

<dl>

<dt>URL</dt><dd>terms are verified by appending the term to <code>$cvurl</code>.
If the URL exists, the term is valid.</dd>

<dt>URL_mediawiki/URL_mediawiki_expansion</dt><dd>terms are verified by
appending the term to <code>$cvurl</code>. If the URL exists, and there is a
wiki page at the URL (as opposed to the default "edit new page", then the term
is valid.</dd>

<dt>OBO</dt><dd>terms are verified by fetching the OBO file at
<code>$cvurl</code> and parsing it with L<GO::Parser>. If the terms exist in the
ontology, then they are valid.</dd>

<dt>URL_DBFields</dt><dd>terms are verified by using the MediaWiki DBFields
extension's CVTerm validator URL (the same as used by the wiki plugin). The term
is appended to the <code>$cvurl</code>. If the response contains the term within
a <code>&lt;name&gt;</code> tag, then it is valid.

</dl><br/>

=end html

=begin roff

=item URL

terms are verified by appending the term to C<$cvurl>. If the URL exists, the
term is valid.

=item URL_mediawiki/URL_mediawiki_expansion

terms are verified by appending the term to C<$cvurl>. If the URL exists, and
there is a wiki page at the URL (as opposed to the default "edit new page", then
the term is valid.

=item OBO

terms are verified by fetching the OBO file at C<$cvurl> and parsing it with
L<GO::Parser>. If the terms exist in the ontology, then they are valid.

=item URL_DBFields

terms are verified by using the MediaWiki DBFields extension's CVTerm validator
URL (the same as used by the wiki plugin). The term is appended to the
C<$cvurl>. If the response contains the term within a C<E<lt>nameE<gt>> tag, then
it is valid.

=end roff

=back

Support for OWL files is tentatively planned but not yet implemented.

B<NOTE:> Although it is possible to add the same controlled vocabulary multiple
times, if C<$cv> is the same and the C<$cvurl> differs then an error occurs and
C<add_cv> returns 0.

If a controlled vocabulary is added with a different C<$cv> but the same
C<$cvurl>, then C<$cv> is treated as a synonym for the same controlled
vocabulary. Further calls to functions that take a controlled vocabulary name
(like L<is_valid_term|/is_valid_term($cvname, $term)>) will work with either the
original name or any of the synonyms. The original name can be found by using
L<get_cv_by_name|/get_cv_by_name($cvname)>.

If no errors occur, C<add_cv> returns 1.

=item is_valid_term($cvname, $term)

Given the name of a controlled vocabulary in C<$cvname> and a term name in
C<$term>, returns 1 if the term is a member of the CV or 0 otherwise. If the
controlled vocabulary named by C<$cvname> has not yet been loaded, then an
attempt is made to load it by name (see the section on fetching canonical URLs
in the description of L<add_cv|/add_cv($cv, $cvurl, $cvurltype)>).

If the controlled vocabulary is of type I<URL>, then the term is valid if
appending C<$term> to the controlled vocabulary's URL results in an existing web
page (and not an error). If the controlled vocabulary is of type
I<URL_mediawiki> or I<URL_mediawiki_expansion>, then the term is valid if
appending C<$term> to the controlled vocabulary's URL results in an existing
wiki page (the page must both exist and not be the default MediaWiki "edit new
page" page). If the controlled vocabulary is of type I<URL_DBFields>, then the
term is valid if appending C<$term> to the controlled vocabulary's URL results
in a response (as that given by the MediaWiki DBFields extension) that contains
C<$term> in a C<E<lt>nameE<gt>> tag. If the controlled vocabulary is of type
I<OBO>, then the term is valid if there is an entry in the ontology file at the
controlled vocabulary's URL with I<either> a name or accession equal to C<$term>.

=item is_valid_accession($cvname, $accession)

Given the name of a controlled vocabulary in C<$cvname> and a term accession in
C<$accession>, returns 1 if the term is a member of the CV or 0 otherwise. If the
controlled vocabulary named by C<$cvname> has not yet been loaded, then an
attempt is made to load it by name (see the section on fetching canonical URLs
in the description of L<add_cv|/add_cv($cv, $cvurl, $cvurltype)>).

Unlike L<is_valid_term|/is_valid_term($cvname, $term)>, C<is_valid_accession>
will only work with controlled vocabularies that have been fully loaded (which
currently means only those from OBO files). The OBO file must contain an entry
with the accession equal to C<$accession>, otherwise 0 is returned.

=item get_accession_for_term($cvname, $term)

Return the accession for C<$term> in the controlled vocabulary C<$cvname>. If
the controlled vocabulary is of type I<URL>, I<URL_mediawiki>, or
I<URL_mediawiki_expansion> and the term is valid, then C<$term> is returned
unchanged since there are no accessions per se for URL-based controlled
vocabularies. If the controlled vocabulary is of type I<URL_DBFields>, then the
term is appended to the controlled vocabulary's URL and the response from the
Mediawiki DBFields term validator is parsed for an E<lt>accessionE<gt> tag, the
contents of which are returned. If the controlled vocabulary is of type I<OBO>,
then the ontology file is searched for either a name or accession matching
C<$term>, and the accession for the term is returned.

=item get_term_for_accession($cvname, $accession)

Return the term for C<$term> in the controlled vocabulary C<$cvname>. If the
controlled vocabulary is of type I<URL>, I<URL_mediawiki>,
I<URL_mediawiki_expansion>, or I<URL_DBFields> and the term is valid, then
C<$term> is returned unchanged since there are no accessions per se for
URL-based controlled vocabularies (except for URL_DBFields CVs, but no mechanism
for fetching terms by accession from a URL_DBFields source exists). If the
controlled vocabulary is of type I<OBO>, then the ontology file is searched for
a name matching C<$term>, and the accession for the term is returned.

=item get_db_object_by_cv_name($cvname)

Given a controlled vocabulary name, returns a L<ModENCODE::Chado::DB> object
with a L<name|ModENCODE::Chado::DB/get_name() | set_name($name)> equal to the
primary name of the controlled vocabulary identified by C<$cvname>, a
L<URL|ModENCODE::Chado::DB/get_url() | set_url($url)> equal to the controlled
vocabulary's canonical URL, and a
L<description|ModENCODE::Chado::DB/get_description() |
set_description($description)> equal to the type (I<URL>, I<URL_mediawiki>,
I<OBO>, etc.) of the controlled vocabulary.

=item get_cv_by_name($cvname)

Given the name of a controlled vocabulary, returns a hash describing the
controlled vocabulary (if any) identified by C<$cvname> in the form:

  {
    'url' => $cvurl,
    'urltype' => $cvurltype,
    'names' [ $primary_name, $another_name1, $another_name2, ... ]
  }

This is primarily useful for verifying that a controlled vocabulary is loaded or
fetching the primary name for a controlled vocabulary by
C<$obj-E<gt>get_cv_by_name($cvname)-E<gt>{'names'}-E<gt>[0]>.

=item cvname_has_synonym($cvname_one, $cvname_two)

Returns 1 if a single controlled vocabulary (one URL) has been added with both
C<$cvname_one> and C<$cvname_two> as names, otherwise returns 0.

=item term_isa($cvname, $term, $ancestor)

If the controlled vocabulary referenced by C<$cvname> contains relationship
information (as in an OBO file), and both C<$term> and C<$ancestor> are valid
terms within that controlled vocabulary, then returns 1 if C<$ancestor> can be
found by recursing upwards from C<$term> using
the function L<GO::Model::Graph/get_recursive_parent_terms_by_type>.

=back

=head1 SEE ALSO

L<ModENCODE::Validator::Attributes::URL_mediawiki_expansion>,
L<ModENCODE::Validator::CVHandler>, L<ModENCODE::Validator::TermSources>,
L<ModENCODE::Validator::Wiki>, L<ModENCODE::Config>, L<GO::Parser>,
L<ModENCODE::Chado::DB>, L<ModENCODE::Validator::Wiki::URLValidator>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);
use LWP::UserAgent;
use URI::Escape ();
use GO::Parser;
use ModENCODE::Validator::Wiki::URLValidator;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;

my %useragent                   :ATTR;
my %cvs                         :ATTR( :default<{}> );
my %mediawiki_url_validator     :ATTR;

sub BUILD {
  my ($self, $ident, $args) = @_;
  $useragent{$ident} = new LWP::UserAgent();
}

sub parse_term {
  my ($self, $term) = @_;
  my ($name, $cv, $term) = (undef, split(/:/, $term));
  if (!length($term)) {
    $term = $cv;
    $cv = undef;
  }
  ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
  $term =~ s/^\s*|\s*$//g;
  return (wantarray ? ( $cv, $term, $name) : { 'name' => $name, 'term' => $term, 'cv' => $cv });
}

sub add_cv {
  my ($self, $cv, $cvurl, $cvurltype) = @_;

  croak "Cannot add a new controlled vocabulary without naming it" unless $cv;

  if (!$cvurl || !$cvurltype) {

    my $existing_cv = $self->get_cv_by_name($cv);
    return 1 if ($existing_cv && !$cvurl);

    # Fetch canonical URL
    my $url = ModENCODE::Config::get_cfg()->val('wiki', 'cvterm_validator_url') . URI::Escape::uri_escape($cv);
    my $res = $useragent{ident $self}->request(new HTTP::Request('GET' => $url));
    if (!$res->is_success) { log_error "Couldn't connect to canonical URL source ($url): " . $res->status_line; return 0; }
    ($cvurl) = ($res->content =~ m/<canonical_url>\s*(.*)\s*<\/canonical_url>/) unless $cvurl;
    ($cvurltype) = ($res->content =~ m/<canonical_url_type>\s*(.*)\s*<\/canonical_url_type>/) unless $cvurltype;
    if ($cvurl && !$cvurltype) {
      log_error "Found a URL ($cvurl) but not a URL type ($cvurltype), for controlled vocabulary $cv. Please check DBFieldsConf.php", "error";
      return 0;
    } elsif ($cvurltype && !$cvurl) {
      log_error "Found a putative URL type ($cvurltype) but not a URL ($cvurl) for controlled vocabulary $cv. Assuming this is a CV we're not meant to check.", "warning";
      my $newcv = {};
      $newcv->{'names'} = [ $cv ];
      $cvs{ident $self}->{$cvurl} = $newcv;
      return 1;
    }   
  }

  if ($cvurl && $cv) {
    my $existing_cv = $self->get_cv_by_name($cv);
    if ($existing_cv->{'url'} && $existing_cv->{'url'} ne $cvurl) {
      log_error("  The CV name $cv is already used for " . $existing_cv->{'url'} . ", but at attempt has been made to redefine it for $cvurl. Please check your IDF.\n" .
      "  Also, please note that 'xsd', 'modencode', and 'MO' may already be predefined to refer to URLs:\n" .
      "    http://wiki.modencode.org/project/extensions/DBFields/ontologies/xsd.obo\n" .
      "    http://wiki.modencode.org/project/extensions/DBFields/ontologies/modencode-helper.obo\n" .
      "    http://www.berkeleybop.org/ontologies/obo-all/mged/mged.obo");
      return 0;
    }
  }


  if ($cvs{ident $self}->{$cvurl}) {
    # Already loaded
    if ($cv) {
      # Might need to add a new name/synonym for this URL
      return $self->add_cv_synonym_for_url($cv, $cvurl);
    }
    return 1;
  }

  my $newcv = {};
  $newcv->{'url'} = $cvurl;
  $newcv->{'urltype'} = $cvurltype;
  $newcv->{'names'} = [ $cv ];

  if ($cvurltype =~ m/^URL/i) {
    # URL-type controlled vocabs
    $cvs{ident $self}->{$cvurl} = $newcv;
    return 1;
  }

  # Have we already fetched this URL?
  my $root_dir = $0;
  $root_dir =~ s/[^\/]*$//;
  $root_dir = "./" unless $root_dir =~ /\//;
  my $cache_filename = $cvurl . "." . $cvurltype;
  $cache_filename =~ s/\//!/g;
  $cache_filename = $root_dir . "ontology_cache/" . $cache_filename;

  if (!(-d $root_dir . "ontology_cache/")) {
    mkdir $root_dir . "ontology_cache" or croak "Couldn't create cache directory ${root_dir}ontology_cache/ for caching ontology files";
  }


  # Fetch the file (mirror uses the If-Modified-Since header so we only fetch if needed)
  my $res = $self->mirror_url($cvurl, $cache_filename);
  if (!$res->is_success) {
    if ($res->code == 304) {
      log_error "Using cached copy of CV for $cv; no change on server.", "notice";
    } else {
      log_error "Can't fetch or check age of canonical CV source file for '$cv' at url '" . $newcv->{'url'} . "': " . $res->status_line, "warning";
      if (!(-r $cache_filename)) {
        log_error "Couldn't fetch canonical source file '" . $newcv->{'url'} . "', and no cached copy found.";
        return 0;
      }
    }
  }

  # Parse the ontology file
  if ($cvurltype =~ m/^OBO$/i) {
    my $parser = new GO::Parser({ 'format' => 'obo_text', 'handler' => 'obj' });
    # Disable warning outputs here
    log_error "(Parsing $cv...", "notice", "=";
    $parser->parse($cache_filename);
    log_error "Done.)\n", "notice", ".";
    if (!$parser->handler->graph) {
      log_error "Cannot parse OBO file '" . $cache_filename . "' using " . ref($parser);
      return 0;
    }
    $newcv->{'nodes'} = $parser->handler->graph->get_all_nodes;
    $newcv->{'graph'} = $parser->handler->graph;
  } elsif ($cvurltype =~ m/^OWL$/i) {
    log_error "Can't parse OWL files yet, sorry. Please update your IDF to point to an OBO file.";
    return 0;
  } elsif ($cvurl =~ m/^\s*$/ || $cvurltype =~ m/^\s*$/) {
    return 0;
  } else {
    log_error "Don't know how to parse the CV at URL: '" . $cvurl . "' of type: '" . $cvurltype . "'.";
    return 0;
  }

  $cvs{ident $self}->{$cvurl} = $newcv;
  return 1;
}

sub is_valid_term {
  my ($self, $cvname, $term) = @_;
  my $cv = $self->get_cv_by_name($cvname);
  if (!$cv) {
    # This CV isn't loaded, so attempt to load it
    my $cv_exists = $self->add_cv($cvname);
    if (!$cv_exists) {
      log_error "Cannot find the '$cvname' ontology, so '$term' is not valid.";
      return 0;
    }
    $cv = $self->get_cv_by_name($cvname);
  }

  if ($cv->{'urltype'} eq '') { return 1; } # Nothing doing if there's no associated CV (skip)

  if (!$cv->{'terms'}->{$term}) {
    # Haven't validated this term one way or the other
    if ($cv->{'urltype'} =~ m/^URL/) {
      # URL term; have to try to get it
      if ($cv->{'urltype'} =~ m/^URL$/) {
        my $tries = 0;
        while ($tries < 3) {
          my $res = $self->get_url($cv->{'url'} . $term);
          if ($res->is_success) {
            $cv->{'terms'}->{$term} = 1;
            last;
          } else {
            $cv->{'terms'}->{$term} = 0;
            $tries++;
            if ($tries < 3) {
              log_error "Couldn't tell if URL " . $cv->{'url'} . $term . " was valid. Retrying.";
              sleep 5;
            }
          }
        }
      } elsif ($cv->{'urltype'} =~ m/^URL_mediawiki(_expansion)?$/) {
        if (!$mediawiki_url_validator{ident $self}) {
          $mediawiki_url_validator{ident $self} = new ModENCODE::Validator::Wiki::URLValidator({
              'username' => ModENCODE::Config::get_cfg()->val('wiki', 'username'),
              'password' => ModENCODE::Config::get_cfg()->val('wiki', 'password'),
              'domain' => ModENCODE::Config::get_cfg()->val('wiki', 'domain'),
              'wsdl' => ModENCODE::Config::get_cfg()->val('wiki', 'soap_wsdl_url'),
            });
        }
        my $res = $mediawiki_url_validator{ident $self}->get_url($cv->{'url'} . $term);
        $cv->{'terms'}->{$term} = 0;
        if ($res->is_success) {
          if ($res->content !~ m/div class="noarticletext"/ && $res->content !~ m/<title>Error<\/title>/) {
            $cv->{'terms'}->{$term} = 1;
          }
        }
      } elsif ($cv->{'urltype'} =~ m/^URL_DBFields$/) {
        my $res = $self->get_url($cv->{'url'} . $term);
        if ($res->is_success) {
          if ($res->content =~ m/<name>.*\Q$term\E<\/name>/) {
            $cv->{'terms'}->{$term} = 1;
          } else {
            $cv->{'terms'}->{$term} = 0;
          }
        } else {
          $cv->{'terms'}->{$term} = 0;
        }
      } else {
        croak "Don't know how to parse the CV at URL: '" . $cv->{'url'} . "' of type: '" . $cv->{'urltype'} . "'";
      }
    } else {
      if (scalar(grep { $_->name =~ m/:?\Q$term\E$/ || $_->acc =~ m/:\Q$term\E$/ }  @{$cv->{'nodes'}})) {
        $cv->{'terms'}->{$term} = 1;
      } else {
        $cv->{'terms'}->{$term} = 0;
      }
    }
  }
  return $cv->{'terms'}->{$term};
}

sub is_valid_accession {
  my ($self, $cvname, $accession) = @_;
  my $cv = $self->get_cv_by_name($cvname);
  if (!$cv) {
    # This CV isn't loaded, so attempt to load it
    my $cv_exists = $self->add_cv($cvname);
    if ($cv_exists == 0) {
      log_error "Cannot find the '$cvname' ontology, so accession $accession is not valid.";
      return 0;
    }

    $cv = $self->get_cv_by_name($cvname);
  }
  if (!$cv->{'accessions'}->{$accession}) {
    # Haven't validated this accession one way or the other
    if (scalar(grep { $_->acc =~ m/:\Q$accession\E$/ }  @{$cv->{'nodes'}})) {
      $cv->{'accessions'}->{$accession} = 1;
    } else {
      $cv->{'accessions'}->{$accession} = 0;
    }
  }
  return $cv->{'accessions'}->{$accession};
}

sub get_accession_for_term {
  my ($self, $cvname, $term) = @_;
  my $cv = $self->get_cv_by_name($cvname);
  croak "Can't find CV $cvname, even though we should've validated by now" unless $cv;

  if ($cv->{'urltype'} eq '') { return ($term, $cvname); } # Nothing doing if there's no associated CV (skip)

  if ($cv->{'urltype'} =~ m/^URL_DBFields$/) {
    my $res = $self->get_url($cv->{'url'} . $term);
    if ($res->is_success) {
      if ($res->content =~ m/<name>.*\Q$term\E<\/name>/) {
        my ($accession) = ($res->content =~ m/<accession>([^<]+)<\/accession>/);
        if (!length($accession)) {
          log_error "Unable to find accession for $term in $cvname", "warning";
          $accession = $term;
        }
        return $accession;
      } else {
        log_error "Unable to find accession for $term in $cvname";
      }
    } else {
      log_error "Unable to find accession for $term in $cvname";
    }
  } elsif ($cv->{'urltype'} =~ m/^URL/i) {
    if ($self->is_valid_term($cvname, $term)) {
      return $term; # No accession other than the term for URL-based ontologies
    } else {
      return;
    }
  }
  my ($matching_node) = grep { $_->name =~ m/^(.*:)?\Q$term\E$/ || $_->acc =~ m/^(.*:)?\Q$term\E$/ } @{$cv->{'nodes'}};
  if (!$matching_node) {
    log_error "Unable to find accession for $term in $cvname" unless $matching_node;
    return;
  }
  my $accession = $matching_node->acc;
  $accession =~ s/^.*://;
  return $accession;
}

sub get_cvname_and_accession_for_term : PRIVATE {
  my ($self, $cvname, $term) = @_;
  my $cv = $self->get_cv_by_name($cvname);
  croak "Can't find CV $cvname, even though we should've validated by now" unless $cv;

  if ($cv->{'urltype'} eq '') { return ($term, $cvname); } # Nothing doing if there's no associated CV (skip)

  if ($cv->{'urltype'} =~ m/^URL_DBFields$/) {
    my $res = $self->get_url($cv->{'url'} . $term);
    if ($res->is_success) {
      if ($res->content =~ m/<name>.*\Q$term\E<\/name>/) {
        my ($accession) = ($res->content =~ m/<accession>([^<]+)<\/accession>/);
        if (!length($accession)) {
          log_error "Unable to find accession for $term in $cvname", "warning";
          $accession = $term;
        }
        return ($accession, $cvname);
      } else {
        log_error "Unable to find accession for $term in $cvname";
      }
    } else {
      log_error "Unable to find accession for $term in $cvname";
    }
  } elsif ($cv->{'urltype'} =~ m/^URL/i) {
    if ($self->is_valid_term($cvname, $term)) {
      return $term; # No accession other than the term for URL-based ontologies
    } else {
      return;
    }
  }
  my ($matching_node) = grep { $_->name =~ m/^(.*:)?\Q$term\E$/ || $_->acc =~ m/^(.*:)?\Q$term\E$/ } @{$cv->{'nodes'}};
  if (!$matching_node) {
    log_error "Unable to find accession for $term in $cvname" unless $matching_node;
    return;
  }
  my $accession = $matching_node->acc;
  ($cvname, $accession) = ($accession =~ /^(?:(.*):)?(.*)$/);
  return ($accession, $cvname);
}

sub get_term_for_accession {
  my ($self, $cvname, $accession) = @_;
  my $cv = $self->get_cv_by_name($cvname);
  croak "Can't find CV $cvname, even though we should've validated by now" unless $cv;

  if ($cv->{'urltype'} eq '') { return $accession; } # Nothing doing if there's no associated CV (skip)

  if ($cv->{'urltype'} =~ m/^URL_DBFields$/) {
    log_error "Can't get an accession for a CV of type URL_DBFields. Assuming term and accession are the same.", "warning";
  }
  if ($cv->{'urltype'} =~ m/^URL/i) {
    if ($self->is_valid_accession($cvname, $accession) || $self->is_valid_term($cvname, $accession)) {
      return $accession; # No term other than the accession for URL-based ontologies
    }
  }
  my ($matching_node) = grep { $_->acc =~ m/:\Q$accession\E$/ }  @{$cv->{'nodes'}};
  croak "Can't find matching node for accession $accession in $cvname" unless $matching_node;
  my $term = ($matching_node->name ? $matching_node->name : $matching_node->acc);
  $term =~ s/^.*://;
  return $term;
}

sub get_db_object_by_cv_name {
  my ($self, $cvname) = @_;
  #print STDERR "Get a DB by $cvname\n";
  foreach my $cvurl (keys(%{$cvs{ident $self}})) {
    my @names = @{$cvs{ident $self}->{$cvurl}->{'names'}};
    if (scalar(grep { $_ eq $cvname } @names)) {
      my $db = new ModENCODE::Chado::DB({
          'name' => $cvs{ident $self}->{$cvurl}->{'names'}->[0],
          'url' => $cvs{ident $self}->{$cvurl}->{'url'},
          'description' => $cvs{ident $self}->{$cvurl}->{'urltype'},
        });
      return $db;
    }
  }
}

sub get_cv_by_name {
  my ($self, $cvname) = @_;
  foreach my $cvurl (keys(%{$cvs{ident $self}})) {
    my @names = @{$cvs{ident $self}->{$cvurl}->{'names'}};
    if (scalar(grep{ lc($_) eq lc($cvname) } @names)) {
#    if (scalar(grep { $_ eq $cvname } @names)) {
      return $cvs{ident $self}->{$cvurl};
    }
  }
  return undef;
}

sub cvname_has_synonym {
  my ($self, $cvname_one, $cvname_two) = @_;
  my $cvone = $self->get_cv_by_name($cvname_one);
  my $cvtwo = $self->get_cv_by_name($cvname_two);
  if ($cvone && $cvtwo && $cvone == $cvtwo) {
    return 1;
  }
  return 0;
}

sub term_isa {
  my ($self, $cvname, $term, $ancestor) = @_;
  return 0 unless ($self->is_valid_term($cvname, $term) && $self->is_valid_term($cvname, $ancestor));
  my $cv = $self->get_cv_by_name($cvname);
  return 0 unless $cv->{'graph'};
  $cvname = $cv->{'names'}->[0];
  my ($child_acc, $cvname) = $self->get_cvname_and_accession_for_term($cvname, $term);
  my $parents = $cv->{'graph'}->get_recursive_parent_terms_by_type($cvname . ':' . $child_acc);
  my @matching_parents = grep { $_->name() eq $ancestor } @$parents;
  return (scalar(@matching_parents) ? 1 : 0);
}
  
sub add_cv_synonym_for_url : PRIVATE {
  my ($self, $synonym, $url) = @_;
  my $existing_url = $self->get_url_for_cv_name($synonym);
  # might need to add a new name/synonym for this url
  my $cv = $cvs{ident $self}->{$url};
  if (!$existing_url) {
    push @{$cvs{ident $self}->{$url}->{'names'}}, $synonym;
    return 1;
  } elsif ($existing_url ne $url) {
    log_error("  The CV name $synonym is already used for $existing_url, but at attempt has been made to redefine it for $url. Please check your IDF.\n" .
    "  Also, please note that 'xsd', 'modencode', and 'MO' may already be predefined to refer to URLs:\n" .
    "    http://wiki.modencode.org/project/extensions/DBFields/ontologies/xsd.obo\n" .
    "    http://wiki.modencode.org/project/extensions/DBFields/ontologies/modencode-helper.obo\n" .
    "    http://www.berkeleybop.org/ontologies/obo-all/mged/mged.obo");
    return 0;
  } else {
    if (!$cv) {
      log_error "Can't add synonym '$synonym' for missing CV identified by $url";
      return 0;
    }
    return 1;
  }
}

sub get_url : PRIVATE {
  my ($self, $url) = @_;
  sleep 1;
  return $useragent{ident $self}->request(new HTTP::Request('GET' => $url));
}

sub mirror_url : PRIVATE {
  my ($self, $url, $file) = @_;
  return $useragent{ident $self}->mirror($url, $file);
}

sub get_url_for_cv_name : PRIVATE {
  my ($self, $cv) = @_;
  foreach my $cvurl (keys(%{$cvs{ident $self}})) {
    my @names = @{$cvs{ident $self}->{$cvurl}->{'names'}};
    if (scalar(grep { $_ eq $cv } @names)) {
      return $cvurl;
    }
  }
  return undef;
}

1;

package ModENCODE::Validator::CVHandler;

use strict;
use Class::Std;
use Carp qw(croak carp);
use LWP::UserAgent;
use URI::Escape ();
use GO::Parser;
use ModENCODE::Validator::Wiki::URLValidator;
use ModENCODE::ErrorHandler qw(log_error);

my %useragent                   :ATTR;
my %cvs                         :ATTR( :default<{}> );
my %cv_synonyms                 :ATTR( :default<{}> );
my %mediawiki_url_validator     :ATTR;

sub BUILD {
  my ($self, $ident, $args) = @_;
  $useragent{$ident} = new LWP::UserAgent();
}

sub get_url : PRIVATE {
  my ($self, $url) = @_;
  return $useragent{ident $self}->request(new HTTP::Request('GET' => $url));
}

sub mirror_url : PRIVATE {
  my ($self, $url, $file) = @_;
  return $useragent{ident $self}->mirror($url, $file);
}

sub parse_term {
  my ($self, $term) = @_;
  my ($name, $cv, $term) = (undef, split(/:/, $term));
  if (!defined($term)) {
    $term = $cv;
    $cv = undef;
  }
  ($term, $name) = ($term =~ m/([^\[]*)(?:\[([^\]]*)\])?/);
  $term =~ s/^\s*|\s*$//g;
  return (wantarray ? ( $cv, $term, $name) : { 'name' => $name, 'term' => $term, 'cv' => $cv });
}

sub add_cv_synonym_for_url {
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

sub get_db_object_by_cv_name {
  my ($self, $name) = @_;
  foreach my $cvurl (keys(%{$cvs{ident $self}})) {
    my @names = @{$cvs{ident $self}->{$cvurl}->{'names'}};
    if (scalar(grep { $_ eq $name } @names)) {
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
  my ($self, $name) = @_;
  foreach my $cvurl (keys(%{$cvs{ident $self}})) {
    my @names = @{$cvs{ident $self}->{$cvurl}->{'names'}};
    if (scalar(grep { $_ eq $name } @names)) {
      return $cvs{ident $self}->{$cvurl};
    }
  }
  return undef;
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

sub add_cv {
  my ($self, $cv, $cvurl, $cvurltype) = @_;

  if (!$cvurl || !$cvurltype) {
    # Fetch canonical URL
    my $res = $useragent{ident $self}->request(new HTTP::Request('GET' => 'http://wiki.modencode.org/project/extensions/DBFields/DBFieldsCVTerm.php?get_canonical_url=' . URI::Escape::uri_escape($cv)));
    if (!$res->is_success) { log_error "Couldn't connect to canonical URL source: " . $res->status_line; return 0; }
    ($cvurl) = ($res->content =~ m/<canonical_url>\s*(.*)\s*<\/canonical_url>/);
    ($cvurltype) = ($res->content =~ m/<canonical_url_type>\s*(.*)\s*<\/canonical_url_type>/);
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
    open OLDERR, ">&", \*STDERR or croak "Can't hide STDERR output from GO::Parser";
    log_error "(Parsing $cv...", "notice", "=";
    close STDERR;
    $parser->parse($cache_filename);
    open STDERR, ">&", \*OLDERR or croak "Can't reopen STDERR output after closing before GO::Parser";
    log_error "Done.)\n", "notice", ".";
    croak "Cannot parse OBO file '" . $cache_filename . "' using " . ref($parser) unless $parser->handler->graph;
    $newcv->{'nodes'} = $parser->handler->graph->get_all_nodes;
  } elsif ($cvurltype =~ m/^OWL$/i) {
    croak "Can't parse OWL files yet, sorry. Please update your IDF to point to an OBO file.";
  } elsif ($cvurl =~ m/^\s*$/ || $cvurltype =~ m/^\s*$/) {
    return 0;
  } else {
    croak "Don't know how to parse the CV at URL: '" . $cvurl . "' of type: '" . $cvurltype . "'";
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
  if (!$cv->{'terms'}->{$term}) {
    # Haven't validated this term one way or the other
    if ($cv->{'urltype'} =~ m/^URL/) {
      # URL term; have to try to get it
      if ($cv->{'urltype'} =~ m/^URL$/) {
        my $res = $self->get_url($cv->{'url'} . $term);
        if ($res->is_success) {
          $cv->{'terms'}->{$term} = 1;
        } else {
          $cv->{'terms'}->{$term} = 0;
        }
      } elsif ($cv->{'urltype'} =~ m/^URL_mediawiki$/) {
        if (!$mediawiki_url_validator{ident $self}) {
          $mediawiki_url_validator{ident $self} = new ModENCODE::Validator::Wiki::URLValidator({
              'username' => 'Validator_Robot',
              'password' => 'vdate_358',
              'domain' => 'modencode_wiki',
            });
        }
        my $res = $mediawiki_url_validator{ident $self}->get_url($cv->{'url'} . $term);
        $cv->{'terms'}->{$term} = 0;
        if ($res->is_success) {
          if ($res->content !~ m/div class="noarticletext"/ && $res->content !~ m/<title>Error<\/title>/) {
            $cv->{'terms'}->{$term} = 1;
          }
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
  if ($cv->{'urltype'} =~ m/^URL/i) {
    return $term; # No accession other than the term for URL-based ontologies
  }
  my ($matching_node) = grep { $_->name =~ m/:?\Q$term\E$/ || $_->acc =~ m/:\Q$term\E$/ } @{$cv->{'nodes'}};
  croak "Unable to find accession for $term in $cvname" unless $matching_node;
  my $accession = $matching_node->acc;
  $accession =~ s/^.*://;
  return $accession;
}

sub get_term_for_accession {
  my ($self, $cvname, $accession) = @_;
  my $cv = $self->get_cv_by_name($cvname);
  croak "Can't find CV $cvname, even though we should've validated by now" unless $cv;
  if ($cv->{'urltype'} =~ m/^URL/i) {
    return $accession; # No term other than the accession for URL-based ontologies
  }
  my ($matching_node) = grep { $_->acc =~ m/:\Q$accession\E$/ }  @{$cv->{'nodes'}};
  croak "Can't find matching node for accession $accession in $cvname" unless $matching_node;
  my $term = ($matching_node->name ? $matching_node->name : $matching_node->acc);
  $term =~ s/^.*://;
  return $term;
}

1;

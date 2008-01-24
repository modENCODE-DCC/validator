package ModENCODE::Validator::CVHandler;

use strict;
use Class::Std;
use Carp qw(croak carp);
use LWP::UserAgent;
use URI::Escape ();
use GO::Parser;

my %useragent                   :ATTR;
my %cvs                         :ATTR( :default<{}> );
my %cv_synonyms                 :ATTR( :default<{}> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  $useragent{$ident} = new LWP::UserAgent();
}

sub get_url : PRIVATE {
  my ($self, $url) = @_;
  return $useragent{ident $self}->request(new HTTP::Request('GET' => $url));
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
  my $cv = $cvs{ident $self}->{$url};
  croak "Can't add synonym '$synonym' for missing CV identified by $url" unless $cv;
  push @{$cvs{ident $self}->{$url}->{'names'}}, $synonym;
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
    if (!$res->is_success) { carp "Couldn't connect to canonical URL source: " . $res->status_line; return 0; }
    ($cvurl) = ($res->content =~ m/<canonical_url>\s*(.*)\s*<\/canonical_url>/);
    ($cvurltype) = ($res->content =~ m/<canonical_url_type>\s*(.*)\s*<\/canonical_url_type>/);
  }

  if ($cvs{ident $self}->{$cvurl}) {
    # Already loaded
    if ($cv) {
      # Might need to add a new name/synonym for this URL
      if (!$self->get_url_for_cv_name($cv)) {
        $self->add_cv_synonym_for_url($cv, $cvurl);
      }
    }
    return 1;
  }

  my $newcv = {};
  $newcv->{'url'} = $cvurl;
  $newcv->{'urltype'} = $cvurltype;
  $newcv->{'names'} = [ $cv ];

  if ($cvurltype =~ m/^URL$/i) {
    # URL-type controlled vocabs
    $cvs{ident $self}->{$cvurl} = $newcv;
    return 1;
  }

  # Have we already fetched this URL?
  my $cache_filename = $cvurl . "." . $cvurltype;
  $cache_filename =~ s/\//!/g;
  $cache_filename = "ontology_cache/" . $cache_filename;
  if (!(-r $cache_filename)) {
    # No, fetch it
    my $res = $self->get_url($cvurl);
    if (!$res->is_success) {
      carp "Couldn't fetch canonical source file" . $newcv->{'url'} . ", and no cached copy found: " . $res->status_line;
      return 0;
    }
    open FH, ">", $cache_filename or croak "Couldn't open ontology cache file $cache_filename for writing";
    print FH $res->content;
    close FH;
  }

  # Parse the ontology file
  if ($cvurltype =~ m/^OBO$/i) {
    my $parser = new GO::Parser({ 'format' => 'obo_text', 'handler' => 'obj' });
    # Disable warning outputs here
    open OLDERR, ">&", \*STDERR or croak "Can't hide STDERR output from GO::Parser";
    print STDERR "(Parsing $cv...)";
    close STDERR;
    $parser->parse($cache_filename);
    open STDERR, ">&", \*OLDERR or croak "Can't reopen STDERR output after closing before GO::Parser";
    print STDERR "(Done.)";
    croak "Cannot parse '" . $cache_filename . "' using " . ref($parser) unless $parser->handler->graph;
    $newcv->{'nodes'} = $parser->handler->graph->get_all_nodes;
  } elsif ($cvurltype =~ m/^OWL$/i) {
    croak "Can't parse OWL files yet, sorry. Please update your IDF to point to an OBO file.";
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
      print STDERR "Cannot find the '$cvname' ontology, so $term is not valid.\n";
      return 0;
    }
    $cv = $self->get_cv_by_name($cvname);
  }
  if (!$cv->{'terms'}->{$term}) {
    # Haven't validated this term one way or the other
    if ($cv->{'urltype'} =~ m/^URL$/) {
      # URL term; have to try to get it
      my $res = $self->get_url($cv->{'url'} . $term);
      if ($res->is_success) {
        $cv->{'terms'}->{$term} = 1;
      } else {
        $cv->{'terms'}->{$term} = 0;
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
    if (!$cv_exists) {
      print STDERR "Cannot find the '$cvname' ontology, so accession $accession is not valid.\n";
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
  if ($cv->{'urltype'} =~ m/^URL$/i) {
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
  if ($cv->{'urltype'} =~ m/^URL$/i) {
    return $accession; # No term other than the accession for URL-based ontologies
  }
  my ($matching_node) = grep { $_->acc =~ m/:\Q$accession\E$/ }  @{$cv->{'nodes'}};
  croak "Can't find matching node for accession $accession in $cvname" unless $matching_node;
  my $term = ($matching_node->name ? $matching_node->name : $matching_node->acc);
  $term =~ s/^.*://;
  return $term;
}

1;

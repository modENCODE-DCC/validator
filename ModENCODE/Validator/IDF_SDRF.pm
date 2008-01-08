package ModENCODE::Validator::IDF_SDRF;

use strict;
use Class::Std;
use Carp qw(croak);


my %idf_experiment   :ATTR( :name<idf_experiment> );
my %protocols        :ATTR( :name<protocols> );
my %termsources      :ATTR( :name<termsources> );

sub validate {
  my ($self, $sdrf_experiment) = @_;
  my $success = 1;
  $sdrf_experiment = $sdrf_experiment->clone(); # Don't actually change the SDRF that was passed in
  # First, just copy over all the experiment attributes
  $sdrf_experiment->add_properties($self->get_idf_experiment()->get_properties());
  # Protocols
  #   Get all the protocols from the sdrf_experiment and make sure they exist in the idf
  my @sdrf_protocols;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my @matching_protocols = grep { $_->equals($applied_protocol->get_protocol()) } @sdrf_protocols;
      if (!scalar(@matching_protocols)) {
        push @sdrf_protocols, $applied_protocol->get_protocol();
      }
    }
  }
  my @undefined_protocols;
  foreach my $sdrf_protocol (@sdrf_protocols) {
    if (!scalar(grep { $_->get_name() eq $sdrf_protocol->get_name() } @{$self->get_protocols()})) {
      push @undefined_protocols, $sdrf_protocol;
    }
  }
  if (scalar(@undefined_protocols)) {
    print STDERR "The following protocol(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_name() } @undefined_protocols) . "'\n";
    $success = 0;
  }
  # Term sources
  # Collect term source DBXrefs from Protocols, Attributes, Datas
  my @term_source_dbs;
  foreach my $applied_protocol_slots (@{$sdrf_experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      if ($applied_protocol->get_protocol()) {
        if ($applied_protocol->get_protocol()->get_termsource() && $applied_protocol->get_protocol()->get_termsource()->get_db()) {
          push @term_source_dbs, $applied_protocol->get_protocol()->get_termsource()->get_db();
        }
        foreach my $attribute (@{$applied_protocol->get_protocol->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @term_source_dbs, $attribute->get_termsource()->get_db();
          }
        }
      }
      foreach my $datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if ($datum->get_termsource() && $datum->get_termsource()->get_db()) {
          push @term_source_dbs, $datum->get_termsource()->get_db();
        }
        foreach my $attribute (@{$datum->get_attributes()}) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            push @term_source_dbs, $attribute->get_termsource()->get_db();
          }
        }
      }
    }
  }
  # Filter to unique DBs
  { my @tmp = @term_source_dbs; @term_source_dbs = (); foreach my $db (@tmp) { if (!scalar(grep { $_->equals($db) } @term_source_dbs)) { push @term_source_dbs, $db; } } }

  my @sdrf_term_sources;
  my @idf_term_sources = map { $_->get_db() } @{$self->get_termsources()};
  foreach my $term_source (@term_source_dbs) {
    my @matching_term_sources = grep { $_->equals($term_source) } @sdrf_term_sources;
    if (!scalar(@matching_term_sources)) {
      push @sdrf_term_sources, $term_source;
    }
  }
  my @undefined_term_sources;
  foreach my $sdrf_term_source (@sdrf_term_sources) {
    if (!scalar(grep { $_->get_name() eq $sdrf_term_source->get_name() } @idf_term_sources)) {
      push @undefined_term_sources, $sdrf_term_source;
    }
  }
  if (scalar(@undefined_term_sources)) {
    print STDERR "The following term source(s) are referred to in the SDRF but not defined in the IDF!\n  '" . join("', '", map { $_->get_name() } @undefined_term_sources) . "'\n";
    $success = 0;
  }

  # Merge IDF data into the SDRF

  return $success;
}

1;

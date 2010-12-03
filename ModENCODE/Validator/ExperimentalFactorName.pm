package ModENCODE::Validator::ExperimentalFactorName;

use strict;
use Class::Std;
use ModENCODE::Parser::Chado;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %experiment                  :ATTR( :name<experiment> );

sub validate {
  my $self = shift;
  my $experiment = $self->get_experiment;

  my $success = 1;

  my @exp_factor_names = grep { $_->get_name eq "Experimental Factor Name" } ($experiment->get_properties(1));
  unless (scalar(@exp_factor_names)) {
    log_error "No Experimental Factor Name defined in the IDF, skipping check.", "notice";
    return $success;
  }

  my %seen;
  my @all_data;
  foreach my $applied_protocol_slot (@{$experiment->get_applied_protocol_slots}) {
    foreach my $applied_protocol (@$applied_protocol_slot) {
      push @all_data, map { [ $applied_protocol, 'input', $_ ] } $applied_protocol->get_input_data;
      push @all_data, map { [ $applied_protocol, 'output', $_ ] } $applied_protocol->get_output_data;
    }
  }
  @all_data = grep { !$seen{$_->[0]->get_id . '.' . $_->[1] . '.' . $_->[2]->get_id}++ } @all_data;
  my @all_attributes = map { $_->[2]->get_object->get_attributes } @all_data;
  %seen = {};
  @all_attributes = grep { !$seen{$_->get_id}++ } @all_attributes;

  my $parser = $self->get_modencode_chado_parser();

  # Check each experimental factor name
  EXP_NAME: foreach my $exp_factor_name_prop (@exp_factor_names) {
    my $exp_factor_name = $exp_factor_name_prop->get_value;
    next unless length($exp_factor_name);

    log_error "Looking for Experimental Factor \"$exp_factor_name\".", "notice", ">";
    foreach my $ap_datum (@all_data) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;
      if ($datum->get_object->get_name eq $exp_factor_name) {
        log_error "Found \"$exp_factor_name\" column, datum: " . $datum->get_object->get_heading . " [" . $datum->get_object->get_name . "].", "notice", "<";
        next EXP_NAME;
      }
    }


    # Check attribute columns
    foreach my $attribute (@all_attributes) {
      if ($attribute->get_object->get_name eq $exp_factor_name) {
        log_error "Found \"$exp_factor_name\" column, attribute: " . $attribute->get_object->get_heading . " [" . $attribute->get_object->get_name . "].", "notice", "<";
        next EXP_NAME;
      }
    }

    # Take off on a little tangent to look in the old submission(s)
    my $seen_old_instance_of_factor = 0;
    foreach my $ap_datum (@all_data) {
      my ($applied_protocol, $direction, $datum) = @$ap_datum;
      foreach my $attribute ($datum->get_object->get_attributes(1)) {
        if ($attribute->get_termsource() && $attribute->get_termsource(1)->get_db(1)->get_description() eq "modencode_submission") {
          my $version = $attribute->get_termsource(1)->get_db(1)->get_url;
          my $schema = "modencode_experiment_${version}_data";
          log_error "Looking in #$version.", "notice";
          if ($parser->get_schema() ne $schema) {
            log_error "Setting modENCODE Chado parser schema to '$schema' for " . $attribute->get_heading() . " [" . $attribute->get_name() . "].", "debug";
            my $experiment_name = $parser->set_schema($schema);
            #log_error "Experiment name is \"$experiment_name\".", "notice";
          }
          my @exp_prop_values = $parser->get_experiment_prop_values_by_name("Experimental Factor Name", new ModENCODE::Chado::Experiment({ 'experiment_id' => $schema }));
          foreach my $propval (@exp_prop_values) {
            if ($propval eq $exp_factor_name) {
              if ($exp_factor_name_prop->get_termsource() && $exp_factor_name_prop->get_termsource(1)->get_db(1)->get_name =~ /modencode_submission/) {
                # Already made this prop
                my @ranks = sort(map { $_->get_rank } grep { $_->get_name eq "Experimental Factor Name" } ($experiment->get_properties(1)));
                my $new_prop = new ModENCODE::Chado::ExperimentProp({
                    'experiment' => $experiment,
                    'value' => $exp_factor_name,
                    'type' => $exp_factor_name_prop->get_type,
                    'name' => $exp_factor_name_prop->get_name,
                    'rank' => $ranks[$#ranks]+1,
                    'termsource' => new ModENCODE::Chado::DBXref({
                      'accession' => $exp_factor_name,
                      'db' => $attribute->get_termsource(1)->get_db(),
                    })
                  });
                $experiment->add_property($new_prop);
                my @ranks = sort(map { $_->get_rank } grep { $_->get_name eq "Experimental Factor Name" } ($experiment->get_properties(1)));
              } else {
                $exp_factor_name_prop->set_termsource(
                  new ModENCODE::Chado::DBXref({
                      'accession' => $exp_factor_name,
                      'db' => $attribute->get_termsource(1)->get_db(),
                    })
                );
              }
              log_error "  Found $exp_factor_name in experiment: #" . $version . ".", "notice";
              $seen_old_instance_of_factor = 1;
            }
          }
        }
      }
    }
    if ($seen_old_instance_of_factor) {
      log_error "Found $exp_factor_name.", "notice", "<";
      next EXP_NAME;
    }

    log_error "Didn't find Experimental Factor Name column \"$exp_factor_name\" in data or attributes of data!", "error", "<";
    $success = 0;
  }

  return $success;

}

sub get_modencode_chado_parser : PROTECTED {
  my ($self) = @_;
  my $parser = new ModENCODE::Parser::Chado({
      'dbname' => ModENCODE::Config::get_cfg()->val('databases modencode', 'dbname'),
      'host' => ModENCODE::Config::get_cfg()->val('databases modencode', 'host'),
      'port' => ModENCODE::Config::get_cfg()->val('databases modencode', 'port'),
      'username' => ModENCODE::Config::get_cfg()->val('databases modencode', 'username'),
      'password' => ModENCODE::Config::get_cfg()->val('databases modencode', 'password'),
      'caching' => 0,
    });
  return undef unless $parser;
  $parser->set_no_relationships(1);
  $parser->set_child_relationships(1);
  return $parser;
}

1;

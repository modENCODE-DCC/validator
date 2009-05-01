package ModENCODE::Validator::Data::ReferencedData;


use strict;
use ModENCODE::Validator::Data::Data;
use base qw( ModENCODE::Validator::Data::Data );
use ModENCODE::Parser::Chado;
use ModENCODE::ErrorHandler qw(log_error);
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Config;

sub validate {
  my ($self) = @_;
  my $success = 1;

  log_error "Crossreferencing data from older submission(s).", "notice", ">";

  my $parser = $self->get_modencode_chado_parser();
  if (!$parser) {
    log_error "Can't check data against existing data in the modENCODE database; skipping.", "warning";
    next;
  }

  my $experiment_name;
  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    my $datum_obj = $datum->get_object;

    my $version = $datum_obj->get_termsource(1)->get_db(1)->get_url();
    if ($version !~ /^\d+$/) {
      log_error "Found a modencode_submission Term Source REF for " . $datum_obj->get_heading() . " [" . $datum_obj->get_name() . "], but it's $version when it should be a numeric project ID.", "error";
      $success = 0;
      last;
    }
    my $schema = "modencode_experiment_${version}_data";
    if ($parser->get_schema() ne $schema) {
      log_error "Setting modENCODE Chado parser schema to '$schema' for " . $datum_obj->get_heading() . " [" . $datum_obj->get_name() . "].", "notice";
      $experiment_name = $parser->set_schema($schema);
      log_error "Experiment name is \"$experiment_name\".", "notice";
    }

    log_error "Finding referenced datum: " . $datum_obj->get_value . " of type " . $datum_obj->get_type(1)->to_string . ".", "debug";
    my $new_datum = $parser->get_datum_id_by_value($datum_obj->get_value);
    if ($new_datum) {
      log_error "Found an old datum object for \"" . $datum_obj->get_value . "\".", "notice";
      log_error "Got datum: " . $new_datum->get_object->to_string() . ".", "debug";
      my $new_datum_obj = $new_datum->get_object;
      if (
        $datum_obj->get_type(1)->get_cv(1)->get_name ne $new_datum_obj->get_type(1)->get_cv(1)->get_name ||
        $datum_obj->get_type(1)->get_name ne $new_datum_obj->get_type(1)->get_name
      ) {
        log_error "Found datum object for \"" . $datum_obj->get_value . "\", but it is of a different type. The old type was " . $datum_obj->get_type(1)->to_string . ", but the new type is " . $new_datum_obj->get_type(1)->to_string . ".", "warning";
      }
      foreach my $attribute ($new_datum_obj->get_attributes()) {
        $datum_obj->add_attribute($attribute);
      }
      $datum_obj->add_attribute(new ModENCODE::Chado::DatumAttribute({
            'datum' => $datum,
            'heading' => 'modENCODE Reference',
            'value' => $version,
            'type' => new ModENCODE::Chado::CVTerm({
                'name' => 'reference',
                'cv' => new ModENCODE::Chado::CV({ 'name' => 'modencode' })
              }),
            'termsource' => $datum_obj->get_termsource
          })
      );

      $datum_obj->set_termsource($new_datum_obj->get_termsource);
    } else {
      log_error "Couldn't find referenced datum \"" . $datum_obj->get_value . "\" in #$version - \"$experiment_name\".", "error";
      $success = 0;
    }
  }
  log_error "Done.", "notice", "<";
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

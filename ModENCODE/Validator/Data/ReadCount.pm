package ModENCODE::Validator::Data::ReadCount;

# the read_count data type will create an experiment property (in addition to an attribute)
# of the total read count for an experiment - this will allow quick access to
# view the total number of reads from a sequencing reaction for an entire experiment
# whether or not the data submitter submitted individual lane counts, or a summed read count

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
  my $title = $self->get_title();

  log_error "Adding read count attribute to experiment", "notice", ">";
  my $experiment = $self->get_experiment();

  #create a read_count experiment prop, if one doesn't exist
  my ($exp_read_count) = grep { $_->get_object->get_name() eq $title } $experiment->get_properties();

  while (my $ap_datum = $self->next_datum) {
    my ($applied_protocol, $direction, $datum) = @$ap_datum;
    my $datum_obj = $datum->get_object;
    if (!$exp_read_count || !length($exp_read_count->get_object->get_value())) {
	log_error "No read count property found for this experiment.  Initializing...", "notice";
	$exp_read_count = new ModENCODE::Chado::ExperimentProp({
	    'name' => $title,
	    'value' => 0,
	    'termsource' => $datum_obj->get_termsource,
	    'experiment' => $experiment,
	    'type' => $datum_obj->get_type,
          });
	$experiment->add_property($exp_read_count);
    }


    # add the read_count value to the existing read_count value.  this will be
    # a summation of all lanes of sequence data.
    my $count = $exp_read_count->get_object->get_value() ;
    $count += $datum_obj->get_value;
    $exp_read_count->get_object->set_value($count);
    log_error "Setting Experiment Property Total Read Count to $count", "notice"; 

  }

  log_error "Done.", "notice", "<";

  return $success;
}


sub get_title {
    #this method should be subclassed
    return "My Title";

}

1;

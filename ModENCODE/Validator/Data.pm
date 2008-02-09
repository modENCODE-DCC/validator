package ModENCODE::Validator::Data;
use strict;
use ModENCODE::Validator::Data::BED;
#use ModENCODE::Validator::Data::NCBITrace;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %validators                  :ATTR( :default<{}> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  # TODO: Figure out how to be more canonical about CV names w/ respect to validation function identifiers
  $validators{$ident}->{'modencode:Browser_Extensible_Data_Format (BED)'} = 'ModENCODE::Validator::Data::BED';
  $validators{$ident}->{'modencode:WIG'} = 'ModENCODE::Validator::Data::WIG';
}

sub merge {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  croak "Cannot merge data columns if they do not validate" unless $self->validate($experiment);
  
  my %cached_merged_datum;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      foreach my $output_datum (@{$applied_protocol->get_output_data()}) {
        my $output_datum_type = $output_datum->get_type();
        my $parser_module = $validators{ident $self}->{$output_datum_type->get_cv()->get_name() . ":" . $output_datum_type->get_name()};
        my $require_ok = 0;
        eval "\$require_ok = require $parser_module;";
        if (length($parser_module) && $require_ok) {
          if (!defined($cached_merged_datum{$parser_module}) || !defined($cached_merged_datum{$parser_module}->{$output_datum->to_string()})) {
            $cached_merged_datum{$parser_module} = {} unless defined($cached_merged_datum{$parser_module});
            # Need to validate this datum
            my $merger;
            eval "\$merger = new $parser_module()";
            my $merged_datum = $merger->merge($output_datum);
            $cached_merged_datum{$parser_module}->{$output_datum->to_string()} = $merged_datum;
          }
          $output_datum->mimic($cached_merged_datum{$parser_module}->{$output_datum->to_string()});
        }
      }
    }
  }
  return $experiment;
}

sub validate {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  my $success = 1;

  # TODO
  # For any field that is a "* File" 
  # For any field with a DBxref's DB description of URL_*
  # Convert to a feature. Need some automatically-loaded handlers here

  # For any data field with a cvterm of type where there exists a file
  my %cached_is_valid;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      # Do we need to check input data? Maybe, but be careful of rescanning input/output data filling the same role
      foreach my $output_datum (@{$applied_protocol->get_output_data()}) {
        my $output_datum_type = $output_datum->get_type();
        my $parser_module = $validators{ident $self}->{$output_datum_type->get_cv()->get_name() . ":" . $output_datum_type->get_name()};
        my $require_ok = 0;
        eval "\$require_ok = require $parser_module;";
        if (length($parser_module) && $require_ok) {
          if (!defined($cached_is_valid{$parser_module}) || !defined($cached_is_valid{$parser_module}->{$output_datum->to_string()})) {
            $cached_is_valid{$parser_module} = {} unless defined($cached_is_valid{$parser_module});
            # Need to validate this datum
            my $validator;
            eval "\$validator = new $parser_module()";
            my $is_valid = $validator->validate($output_datum);
            $cached_is_valid{$parser_module}->{$output_datum->to_string()} = $is_valid;
          }
          if (!$cached_is_valid{$parser_module}->{$output_datum->to_string()}) {
            log_error "The following datum does not validate using $parser_module:\n  " . $output_datum->to_string();
            $success = 0;
            next;
          }
        } else {
          log_error "No validator for data type " . $output_datum_type->get_cv()->get_name() . "_" . $output_datum_type->get_name() . ".", "warning";
        }
      }
    }
  }

  return $success;
}

1;

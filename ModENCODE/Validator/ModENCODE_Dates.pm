package ModENCODE::Validator::ModENCODE_Dates;
=pod

=head1 NAME

ModENCODE::Validator::ModENCODE_Dates - modENCODE-specific validator to ensure
that a C<Public Release Date> and C<Date of Experiment> field exist in the IDF
and that they are either populated with dates or are blank, in which case the
date of validation is used.

=head1 SYNOPSIS

This class can be used to validate a BIR-TAB
L<Experiment|ModENCODE::Chado::Experiment> object to make sure that experiment
properties (from the IDF) exist for C<Public Release Date> and C<Date of
Experiment>. If either/both of the fields are blank, then they are filled in
with the date of validation and validation can succeed. The values of these
fields are then checked against the ISO 8601 date format (YYYY-MM-DD). If the
fields do not match the format, and cannot be coerced into a valid date, then
validation fails.

=head1 USAGE

Some attempts will be made (using L<Date::Parse/str2time(DATE [, ZONE])>) to
parse a date that is not in the YYYY-MM-DD format. In these cases, a warning is
displayed comparing the given string to the parsed date.

Once the data has been validated, the L</merge($experiment)> function can be
called to update the dates to either the current date (if the supplied date is
blank) or the ISO 8601 representation of the parsed date (if the supplied date
was not already in the correct format).

To call the validator on an L<Experiment|ModENCODE::Chado::Experiment> object:

  my $date_validator = new ModENCODE::Validator::ModENCODE_Dates();
  if ($date_validator->validate($experiment)) {
    $experiment = $date_validator->merge($experiment);
  }

=head1 FUNCTIONS

=over

=item validate($experiment)

Ensures that the L<Experiment|ModENCODE::Chado::Experiment> specified in
C<$experiment> contains L<experiment
properties|ModENCODE::Chado::ExperimentProp> named C<Public Release Date> and
C<Date of Experiment>. The values of these properties are then
checked against the ISO 8601 date format (YYYY-MM-DD) format if not blank. If
the dates are not ISO 8601, an attempt is made to parse them using
L<Date::Parse/str2time(DATE [, ZONE])>.

=item merge($experiment)

Updates the L<experiment properties|ModENCODE::Chado::ExperimentProp> named
C<Public Release Date> and C<Date of Experiment> for the 
L<Experiment|ModENCODE::Chado::Experiment> specified in C<$experiment> to match
the ISO 8601 format if necessary, and/or fills in the current date if the field
is blank.

=back

=head1 SEE ALSO

L<Class::Std>, L<Date::Parse>, L<ModENCODE::Validator::Attributes>,
L<ModENCODE::Validator::Data>, L<ModENCODE::Validator::IDF_SDRF>,
L<ModENCODE::Validator::TermSources>, L<ModENCODE::Validator::Wiki>,
L<ModENCODE::Chado::Experiment>, L<ModENCODE::Chado::ExperimentProp>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;

use ModENCODE::Chado::ExperimentProp;
use Date::Parse qw();
use Date::Format qw();
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %merged_data                :ATTR(                                   :default<{}> );

sub validate {
  my ($self, $experiment) = @_;

  my $current_time = time();
  my $current_date = Date::Format::time2str("%Y-%m-%d", $current_time, 'GMT');

  my ($public_release_date) = grep { $_->get_name() eq "Public Release Date" } @{$experiment->get_properties()};
  my ($date_of_experiment) = grep { $_->get_name() eq "Date of Experiment" } @{$experiment->get_properties()};

  $public_release_date = $public_release_date->clone() if $public_release_date;
  $date_of_experiment = $date_of_experiment->clone() if $date_of_experiment;

  if (!$public_release_date) {
    $public_release_date = new ModENCODE::Chado::ExperimentProp({
        'value' => '',
        'type' => new ModENCODE::Chado::CVTerm({'name' => 'date', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
        'name' => 'Public Release Date',
      });
  }

  if (!$date_of_experiment) {
    $date_of_experiment = new ModENCODE::Chado::ExperimentProp({
        'value' => '',
        'type' => new ModENCODE::Chado::CVTerm({'name' => 'date', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
        'name' => 'Date of Experiment',
      });
  }

  my $release_date = $public_release_date->get_value();
  if (!length($release_date)) {
    log_error "No Public Release Date provided in the IDF, assuming current date: " . Date::Format::time2str("%b %e, %Y", $current_time, 'GMT') . " GMT.", "warning";
    $public_release_date->set_value($current_date);
  }

  my $experiment_date = $date_of_experiment->get_value();
  if (!length($experiment_date)) {
    log_error "No Date of Experiment provided in the IDF, assuming current date: " . Date::Format::time2str("%b %e, %Y", $current_time, 'GMT') . " GMT.", "warning";
    $date_of_experiment->set_value($current_date);
  }

  $release_date = $public_release_date->get_value();
  if ($release_date !~ /^\d{4}-\d{2}-\d{2}/) {
    my $date = Date::Parse::str2time($release_date);
    if (!$date) {
      log_error "Could not parse '$release_date' as a date in format YYYY-MM-DD for the Public Release Date. Please correct your IDF.", "error";
      return 0;
    }
    my $human_date = Date::Format::time2str("%b %e, %Y", $date);
    my $parsed_date = Date::Format::time2str("%Y-%m-%d", $date);
    log_error "The Public Release Date '$release_date' was not in the format YYYY-MM-DD. It has been parsed as $parsed_date, i.e. $human_date.", "warning";
    $public_release_date->set_value($parsed_date);
  }

  $experiment_date = $date_of_experiment->get_value();
  if ($experiment_date !~ /^\d{4}-\d{2}-\d{2}/) {
    my $date = Date::Parse::str2time($experiment_date);
    if (!$date) {
      log_error "Could not parse '$experiment_date' as a date in format YYYY-MM-DD for the Date of Experiment. Please correct your IDF.", "error";
      return 0;
    }
    my $human_date = Date::Format::time2str("%b %e, %Y", $date);
    my $parsed_date = Date::Format::time2str("%Y-%m-%d", $date);
    log_error "The Date of Experiment '$experiment_date' was not in the format YYYY-MM-DD. It has been parsed as $parsed_date, i.e. $human_date.", "warning";
    $date_of_experiment->set_value($parsed_date);
  }

  $merged_data{ident $self}->{'Public Release Date'} = $public_release_date;
  $merged_data{ident $self}->{'Date of Experiment'} = $date_of_experiment;

  return 1;
}

sub merge {
  my ($self, $experiment) = @_;
  #$experiment = $experiment->clone();
  my ($public_release_date) = grep { $_->get_name() eq "Public Release Date" } @{$experiment->get_properties()};
  my ($date_of_experiment) = grep { $_->get_name() eq "Date of Experiment" } @{$experiment->get_properties()};

  if ($public_release_date) {
    $public_release_date->set_value($merged_data{ident $self}->{'Public Release Date'}->get_value());
  } else {
    $experiment->add_property($merged_data{ident $self}->{'Public Release Date'});
  }
  if ($date_of_experiment) {
    $date_of_experiment->set_value($merged_data{ident $self}->{'Date of Experiment'}->get_value());
  } else {
    $experiment->add_property($merged_data{ident $self}->{'Date of Experiment'});
  }
  return $experiment;
}

1;

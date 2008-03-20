package ModENCODE::Validator::Data::dbEST_acc_list;
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Validator::Data::dbEST_acc;
use ModENCODE::ErrorHandler qw(log_error);

my %sub_validator               :ATTR;
my %seen_est_files              :ATTR( :default<[]> );
my %features_by_acc             :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  log_error "Parsing list of ESTs.", "notice", ">";
  my $success = 1;

  my @est_list_file_data;
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum = $datum_hash->{'datum'}->clone();
    my $applied_protocol = $datum_hash->{'applied_protocol'}->clone();

    my $est_list_file = $datum_hash->{'datum'}->get_value();
    next unless length($est_list_file);
    log_error "Parsing list of ESTs from file " . $est_list_file . ".", "notice", ">";
    if (!-r $est_list_file) {
      log_error "Cannot read EST list file '$est_list_file'.";
      $success = 0;
      next;
    }
    if (!scalar(grep { $_ eq $est_list_file } @{$seen_est_files{ident $self}})) {
      my $est_validator = $self->get_sub_validator();
      unless (open ESTS, $est_list_file) {
        log_error "Cannot open EST list file '$est_list_file' for reading.";
        $success = 0;
        next;
      }

      while (defined(my $est = <ESTS>)) {
        $est =~ s/\s*//g;
        my $temp_datum = new ModENCODE::Chado::Data({
            'value' => $est
          });
        $est_validator->add_datum($temp_datum, $applied_protocol);
      }
      $success = 0 unless $est_validator->validate();
      my @temp_data = @{$est_validator->get_data()};
      foreach my $temp_datum (@temp_data) {
        foreach my $feature (@{$temp_datum->{'merged_datum'}->get_features()}) {
          $features_by_acc{ident $self}->{$temp_datum->{'datum'}->get_value()} = $feature;
          $datum->add_feature($feature);
        }
      }
      $datum_hash->{'merged_datum'} = $datum;
    }
    log_error "Done.", "notice", "<";
  }
  log_error "Done.", "notice", "<";
  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;

  my $validated_datum = $self->get_datum($datum, $applied_protocol)->{'merged_datum'};

  # If there's a GFF attached to this particular protocol, update any entries referencing this EST
  if (scalar(@{$validated_datum->get_features()})) {
    my @est_features;
    my $gff_validator = $self->get_data_validator()->get_validators()->{'modencode:GFF3'};
    if ($gff_validator) {
      foreach my $other_datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if (
          $other_datum->get_type()->get_name() eq "GFF3" && 
          ModENCODE::Config::get_cvhandler()->cvname_has_synonym($other_datum->get_type()->get_cv()->get_name(), "modencode")
        ) {
          if (defined($other_datum->get_value()) && length($other_datum->get_value())) {
            foreach my $est_feature_name (keys(%{$features_by_acc{ident $self}})) {
              my $est_feature = $features_by_acc{ident $self}->{$est_feature_name};
              my $gff_feature = $gff_validator->get_feature_by_id_from_file(
                $est_feature_name,
                $other_datum->get_value()
              );
              if ($gff_feature) {
                # Update the GFF feature to look like this feature (but don't break any links
                # it may have to other features in the GFF, then return the updated feature as
                # part of the validated_datum
                $gff_feature->mimic($est_feature);
                push @est_features, $gff_feature;
              } else {
                # If there's not a GFF complement to this feature, keep it around anyway
                push @est_features, $est_feature;
              }
            }
          }
        }
      }
    }
    $validated_datum->set_features(\@est_features);
  }
  return $validated_datum;
}

sub get_sub_validator {
  my ($self) = @_;
  if (!$sub_validator{ident $self}) {
    $sub_validator{ident $self} = new ModENCODE::Validator::Data::dbEST_acc({ 'data_validator' => $self->get_data_validator() });
  }
  return $sub_validator{ident $self};
}

1;

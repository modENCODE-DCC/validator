package ModENCODE::Validator::Data::SO_transcript;
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Parser::Chado;
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Chado::Feature;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Organism;
use ModENCODE::Chado::FeatureLoc;
use ModENCODE::Config;

my %parser                       :ATTR;
my %cached_feature_ids           :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  log_error "Loading transcripts from database.", "notice", ">";
  my $success = 1;

  my @ids;
  foreach my $datum_hash (@{$self->get_data()}) {
    if (length($datum_hash->{'datum'}->get_value())) {
      my $feature_id = $cached_feature_ids{ident $self}->{$datum_hash->{'datum'}->get_value()};
      if (!$feature_id) {
        log_error "Fetching feature " . $datum_hash->{'datum'}->get_value(), "notice";
        $feature_id = $self->get_parser()->get_feature_id_by_name_and_type(
          $datum_hash->{'datum'}->get_value(),
          new ModENCODE::Chado::CVTerm({
              'name' => 'transcript',
              'cv' => new ModENCODE::Chado::CV({ 'name' => 'SO' }),
            }),
          1,
        );
        $cached_feature_ids{ident $self}->{$datum_hash->{'datum'}->get_value()} = $feature_id;
      }
      if (!$feature_id) {
        log_error "Couldn't get a feature_id for supposed transcript " . $datum_hash->{'datum'}->get_value() . ".", "error";
        $success = 0;
        next;
      }
      log_error "Loading feature " . $datum_hash->{'datum'}->get_value(), "notice";
      my $feature = $self->get_parser()->get_feature($feature_id);
      if (!$feature) {
        log_error "Couldn't get a feature object for supposed transcript " . $datum_hash->{'datum'}->get_value() . " with feature_id $feature_id.", "error";
        $success = 0;
        next;
      }
      my $datum = $datum_hash->{'datum'}->clone();
      $datum->add_feature($feature);
      $datum_hash->{'merged_datum'} = $datum;
    }
  }

  log_error "Done.", "notice", "<";
  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;
  my $validated_datum = $self->get_datum($datum, $applied_protocol)->{'merged_datum'};


  # If there's a GFF attached to this particular protocol, update any entries referencing this transcript
  if ($validated_datum && scalar(@{$validated_datum->get_features()})) {
    my $gff_validator = $self->get_data_validator()->get_validators()->{'modencode:GFF3'};
    if ($gff_validator) {
      foreach my $other_datum (@{$applied_protocol->get_input_data()}, @{$applied_protocol->get_output_data()}) {
        if (
          $other_datum->get_type()->get_name() eq "GFF3" && 
          ModENCODE::Config::get_cvhandler()->cvname_has_synonym($other_datum->get_type()->get_cv()->get_name(), "modencode")
        ) {
          if (defined($other_datum->get_value()) && length($other_datum->get_value())) {
            my $gff_feature = $gff_validator->get_feature_by_id_from_file(
              $validated_datum->get_value(),
              $other_datum->get_value()
            );
            if ($gff_feature) {
              # Update the GFF feature to look like this feature (but don't break any links
              # it may have to other features in the GFF, then return the updated feature as
              # part of the validated_datum
              croak "Unable to continue; the validated dbEST_acc datum " . $validated_datum->to_string() . " has more than one associated feature!" if (scalar(@{$validated_datum->get_features()}) > 1);
              $gff_feature->mimic($validated_datum->get_features()->[0]);
              $validated_datum->set_features( [$gff_feature] );
            }
          }
        }
      }
    }
  }

  return $validated_datum;
}

sub get_parser : PRIVATE {
  my ($self) = @_;
  if (!$parser{ident $self}) {
    $parser{ident $self} = new ModENCODE::Parser::Chado({
        'dbname' => ModENCODE::Config::get_cfg()->val('databases flybase', 'dbname'),
        'host' => ModENCODE::Config::get_cfg()->val('databases flybase', 'host'),
        'port' => ModENCODE::Config::get_cfg()->val('databases flybase', 'port'),
        'username' => ModENCODE::Config::get_cfg()->val('databases flybase', 'username'),
        'password' => ModENCODE::Config::get_cfg()->val('databases flybase', 'password'),
      });
  }
  return $parser{ident $self};
}

1;

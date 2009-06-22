package ModENCODE::Validator::FeatureExistence;
use strict;
use Class::Std;
use ModENCODE::Cache;
use ModENCODE::ErrorHandler qw(log_error);

sub validate {
  my ($self, $experiment) = @_;
  my @all_features = ModENCODE::Cache::get_all_objects('feature');
  if (scalar(@all_features)) {
    log_error "Found approximately " . scalar(@all_features) . " unique features.", "notice";
  } else {
    log_error "NO FEATURES FOUND.", "warning", ">";
    log_error "If this submission should contain feature data (not counting WIG or SAM files), please check the types of fields in the SDRF (e.g. GFF, transcript) and contents of any GFF files.", "notice";
    log_error "Continuing...", "notice", "<";
  }
  return 1;
}

1;

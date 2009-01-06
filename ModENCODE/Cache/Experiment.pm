package ModENCODE::Cache::Experiment;

use strict;
use ModENCODE::Cache::CachedObject;
use base qw(ModENCODE::Cache::CachedObject);
use Class::Std;
use ModENCODE::Cache;

sub uncompress {
  my $self = shift;
  $self->set_content(ModENCODE::Cache::load_experiment($self->get_content));
}

1;


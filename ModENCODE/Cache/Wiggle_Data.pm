package ModENCODE::Cache::Wiggle_Data;

use strict;
use ModENCODE::Cache::CachedObject;
use base qw(ModENCODE::Cache::CachedObject);
use Class::Std;
use ModENCODE::Cache;

sub uncompress {
  my $self = shift;
  $self->set_content(ModENCODE::Cache::load_wiggle_data($self->get_content));
}

1;


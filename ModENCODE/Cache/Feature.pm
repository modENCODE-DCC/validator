package ModENCODE::Cache::Feature;

use strict;
use ModENCODE::Cache::CachedObject;
use base qw(ModENCODE::Cache::CachedObject);
use Class::Std;
use ModENCODE::Cache;

sub uncompress {
  my $self = shift;
  $self->set_content(ModENCODE::Cache::load_feature($self->get_content));
}

sub shrink {
  my $self = shift;
  if (ref($self->get_content)) {
    $self->get_content->save;
    my $id = $self->get_content->get_id;
    $self->get_content->DESTROY();
    $self->set_content($id);
    return 1;
  }
  return 0;
}

1;


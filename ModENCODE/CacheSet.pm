package ModENCODE::CacheSet;

use strict;
use Class::Std;
use Carp qw(croak confess);
use ModENCODE::Cache::CachedObject;
use ModENCODE::ErrorHandler qw(log_error);

use constant CACHE_SIZE => 300000;
use constant CACHE_SHRINK_AT => 1000000;
use constant DEBUG => 1;

my %name                :ATTR( :name<name> );
my %added_objects       :ATTR( :default<0> );
my %cacheobjs           :ATTR( :default<{}> );
my %cacheobjs_by_ids    :ATTR( :default<{}> );
my %cacheobjs_by_time   :ATTR( :default<[]> );

sub shrink_cache {
  my $self = shift;
  my $seen_big = 0;
  my @top_of_cache;
  # Pick off CACHE_SIZE elements w/ objects
  # Also include any found while traversing from the most recent that
  # may already be IDs
  while (my $recent_item = pop @{$cacheobjs_by_time{ident $self}}) {
    unshift @top_of_cache, $recent_item;
    if (ref($recent_item->get_object)) {
      $seen_big++;
      last if ($seen_big >= CACHE_SIZE);
    }
  }
  $added_objects{ident $self} = $seen_big;
  # Everything left needs to be converted to an ID
  my $shrunk_obj_count = 0;
  while (my $old_item = pop @{$cacheobjs_by_time{ident $self}}) {
    unshift @top_of_cache, $old_item;
    $shrunk_obj_count++ if $old_item->shrink;
  }
  $cacheobjs_by_time{ident $self} = \@top_of_cache;
  return ($shrunk_obj_count, $seen_big);
}

sub get_from_cache {
  my $self = shift;
  my $curcache = $cacheobjs{ident $self};
  while (scalar(@_)) {
    my $key = shift;
    $curcache = $curcache->{$key};
    return unless $curcache;
  }
  return $curcache;
}

sub update_cache_to {
  my ($self, $oldpath, $newpath) = @_;
  my $old_location = $self->get_from_cache(@$oldpath);
  my $new_location = $cacheobjs{ident $self};
  my @tmpnewpath = @$newpath;
  while (scalar(@tmpnewpath)) {
    my $key = shift @tmpnewpath;
    $new_location->{$key} = {} unless defined($new_location->{$key});
    $new_location = $new_location->{$key};
  }

  my @oldpath_parent = @$oldpath;
  my $key = pop @oldpath_parent;
  my $old_location_parent = $self->get_from_cache(@oldpath_parent);
  delete($old_location_parent->{$key});

  return ($old_location, $new_location);
}

sub move_in_cache {
  my ($self, $oldpath, $newpath, $new_id) = @_;
  my $curcache = $cacheobjs{ident $self};
  my $prevcache;
  my $key;
  my @path = @$oldpath;
  while (scalar(@path)) {
    $key = shift @path;
    $prevcache = $curcache;
    $curcache = $prevcache->{$key};
    return unless $curcache;
  }
  my $cacheobj = $prevcache->{$key};
  delete $prevcache->{$key};
  my $curcache = $cacheobjs{ident $self};

  @path = @$newpath;
  while (scalar(@path)) {
    my $key = shift @path;
    if (scalar(@path)) {
      $curcache->{$key} = {} unless defined($curcache->{$key});
      $curcache = $curcache->{$key};
    } else {
      if (defined($curcache->{$key})) {
        # Even if the item is already here; it's probably from caching the object created
        # Overwrite it if the content is the same
        if ($curcache->{$key}->get_id != $new_id) {
          croak "During update, tried to replace existing cache item with a different one."
        }
      }
      $curcache->{$key} = $cacheobj;
    }
  }
  return $cacheobj;
}


sub add_to_cache {
  my $self = shift;
  my $obj = shift;
  return $obj if ModENCODE::Cache::get_paused();
  my $curcache = $cacheobjs{ident $self};
  while (scalar(@_)) {
    my $key = shift;
    if (scalar(@_)) {
      $curcache->{$key} = {} unless defined($curcache->{$key});
      $curcache = $curcache->{$key};
    } else {
      if (defined($curcache->{$key})) {
        croak "Replacing a cache item on top of another";
      }
      $curcache->{$key} = $obj;
      push @{$cacheobjs_by_time{ident $self}}, $obj;
    }
  }
  $self->notify_object_loaded();
  return $obj;
}


sub get_from_id_cache {
  my $self = shift;
  my $curcache = $cacheobjs_by_ids{ident $self};
  while (scalar(@_)) {
    my $key = shift;
    $curcache = $curcache->{$key};
    return unless $curcache;
  }
  return $curcache;
}

sub add_to_id_cache {
  my $self = shift;
  my $obj = shift;
  my $curcache = $cacheobjs_by_ids{ident $self};
  while (scalar(@_)) {
    my $key = shift;
    if (scalar(@_)) {
      $curcache->{$key} = {} unless defined($curcache->{$key});
      $curcache = $curcache->{$key};
    } else {
      if (defined($curcache->{$key})) {
        croak "Replacing a cache item on top of another";
      }
      $curcache->{$key} = $obj;
    }
  }
  return $obj;
}

sub notify_object_loaded {
  my $self = shift;
  $added_objects{ident $self}++;
  if ($added_objects{ident $self} >= CACHE_SHRINK_AT) {
    log_error "Shrinking cache of " . $self->get_name() . " objects...", "notice";
    my ($shrunk_objs, $big_objs) = $self->shrink_cache();
    log_error "Shrunk $shrunk_objs " . $self->get_name() . " objects, left $big_objs expanded; total " . scalar(@{$cacheobjs_by_time{ident $self}}) . " cached objects.", "notice";
  }
}

sub get_all_objects {
  my $self = shift;
  return @{$cacheobjs_by_time{ident $self}};
}
  
1;

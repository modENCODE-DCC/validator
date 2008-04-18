package ModENCODE::Validator::ModENCODE_Projects;
use strict;

use ModENCODE::Chado::ExperimentProp;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);
use ModENCODE::Config;

my %merged_data                :ATTR(                                   :default<{}> );
my %project_names              :ATTR;

sub BUILD {
  my ($self, $ident, $args) = @_;
  my @modencode_projects = ModENCODE::Config::get_cfg()->GroupMembers('modencode_project');
  $project_names{$ident} = {};
  foreach my $modencode_project (@modencode_projects) {
    my ($project_name) = ($modencode_project =~ m/^modencode_project\s*(\S+)\s*$/);
    my $project_url = ModENCODE::Config::get_cfg()->val($modencode_project, 'url');
    my @project_subgroups = split /,\s*/, ModENCODE::Config::get_cfg()->val($modencode_project, 'subgroups');
    $project_names{$ident}->{$project_name} = {
      'url' => $project_url,
      'subgroups' => \@project_subgroups,
    };
  }
}

sub validate {
  my ($self, $experiment) = @_;
  my ($group) = grep { $_->get_name() eq "Project Group" } @{$experiment->get_properties()};
  my ($subgroup) = grep { $_->get_name() eq "Project Subgroup" } @{$experiment->get_properties()};

  $group = $group->clone() if $group;
  $subgroup = $subgroup->clone() if $subgroup;

  my $group_name = $group->get_value() if $group;
  if (!length($group_name)) {
    log_error "Can't find any modENCODE project group - should be defined in the IDF.";
    return 0;
  }
  my ($matching_group_name) = grep { $_ =~ m/^\s*\Q$group_name\E\s*$/i } keys(%{$project_names{ident $self}});
  if (!length($matching_group_name)) {
    log_error "Can't find a modENCODE project group matching '$group_name'. Options are: " . join(", ", keys(%{$project_names{ident $self}})) . ".";
    return 0;
  }
  $group->set_value($matching_group_name);

  if (!$subgroup || !length($subgroup->get_value())) {
    log_error "No modENCODE project sub-group defined - defaulting to main group '$matching_group_name'.", "warning";
    $subgroup = $group->clone();
    $subgroup->set_name('Project Subgroup');
  }
  my $subgroup_name = $subgroup->get_value();
  my ($matching_subgroup_name) = grep { $_ =~ m/^\s*\Q$subgroup_name\E\s*$/i } @{$project_names{ident $self}->{$matching_group_name}->{'subgroups'}};
  if (!length($matching_subgroup_name)) {
    log_error "Can't find a modENCODE project subgroup of $matching_group_name named '$subgroup_name'. Options are: " . join(", ", @{$project_names{ident $self}->{$matching_group_name}->{'subgroups'}}) . ".";
    return 0;
  }
  return 1;
}

sub merge {
  my ($self, $experiment) = @_;
  $experiment = $experiment->clone();
  my ($group) = grep { $_->get_name() eq "Project Group" } @{$experiment->get_properties()};
  my ($subgroup) = grep { $_->get_name() eq "Project Subgroup" } @{$experiment->get_properties()};
  my $group_name = $group->get_value() if $group;
  if (!length($group_name)) {
    log_error "Can't find any modENCODE project group - should be defined in the IDF.";
    return undef;
  }
  my ($matching_group_name) = grep { $_ =~ m/^\s*\Q$group_name\E\s*$/i } keys(%{$project_names{ident $self}});
  if (!length($matching_group_name)) {
    log_error "Can't find a modENCODE project group matching '$group_name'. Options are: " . join(", ", keys(%{$project_names{ident $self}})) . ".";
    return undef;
  }
  $group->set_value($matching_group_name);

  if (!$subgroup || !length($subgroup->get_value())) {
    log_error "No modENCODE project sub-group defined - defaulting to main group '$matching_group_name'.", "warning";
    $subgroup = $group->clone();
    $subgroup->set_name('Project Subgroup');
    $experiment->add_property($subgroup);
  }
  my $subgroup_name = $subgroup->get_value();
  my ($matching_subgroup_name) = grep { $_ =~ m/^\s*\Q$subgroup_name\E\s*$/i } @{$project_names{ident $self}->{$matching_group_name}->{'subgroups'}};
  if (!length($matching_subgroup_name)) {
    log_error "Can't find a modENCODE project subgroup of $matching_group_name named '$subgroup_name'. Options are: " . join(", ", @{$project_names{ident $self}->{$matching_group_name}->{'subgroups'}}) . ".";
    return undef;
  }
  $subgroup->set_value($matching_subgroup_name);
  my $group_url = new ModENCODE::Chado::ExperimentProp({
      'value' => $project_names{ident $self}->{$matching_group_name}->{'url'},
      'type' => new ModENCODE::Chado::CVTerm({'name' => 'anyURI', 'cv' => new ModENCODE::Chado::CV({'name' => 'xsd'})}),
      'name' => 'Project Group URL',
    });
  $experiment->add_property($group_url);
  return $experiment;
}



1;

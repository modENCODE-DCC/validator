package ModENCODE::Validator::ModENCODE_Projects;
=pod

=head1 NAME

ModENCODE::Validator::ModENCODE_Projects - modENCODE-specific validator to
ensure that a C<Project> and C<Lab> field exist in the IDF
and that they are populated with valid project names.

=head1 SYNOPSIS

This class can be used to validate a BIR-TAB
L<Experiment|ModENCODE::Chado::Experiment> object to make sure that experiment
properties (from the IDF) exist for C<Project> and C<Lab>.
The values of these fields are then checked against the projects configured in
the ini-file loaded by L<ModENCODE::Config>. The capitalization of the group
names is also normalized to match that in the ini-file.

=head1 USAGE

First, the proper entries in the ini-file must be created. For each project,
create a section like so:

  [modencode_project AProject]
  url=http://www.modencode.org/AProject.html
  subgroups=AProject, SubProject1, SubProject2

A C<Project> of "AProject" and a C<Lab> of "Subproject1" is
then valid. In most cases, you'll want to repeat the project group in the list
of subgroups, since the main group will be making at least some submissions. The
other reason to do this is that if no C<Lab> is specified in the
IDF, the subgroup will default to be the same as the main group. If you don't
have the main group in the list of subgroups, then not specifying a subgroup
will cause validation to fail.

Once the data has been validated, the L</merge($experiment)> function can be
called to normalize the group and subgroup names. The names are validated
case-insensitively, so during merge the names from the ini-file are used to
replace the ones in the L<experiment
properties|ModENCODE::Chado::ExperimentProp>. Additionally, if no subgroup was
specified, the main group name is used as the subgroup.

To call the validator on an L<Experiment|ModENCODE::Chado::Experiment> object:

  my $projects_validator = new ModENCODE::Validator::ModENCODE_Projects();
  if ($projects_validator->validate($experiment)) {
    $experiment = $projects_validator->merge($experiment);
  }

=head1 FUNCTIONS

=over

=item validate($experiment)

Ensures that the L<Experiment|ModENCODE::Chado::Experiment> specified in
C<$experiment> contains L<experiment
properties|ModENCODE::Chado::ExperimentProp> named C<Project> and
optionally C<Lab>. The values of these properties are then
checked against the projects configured in the ini-file loaded by
L<ModENCODE::Config> to make sure that a valid group and subgroup have been
specified.

=item merge($experiment)

Updates the L<experiment properties|ModENCODE::Chado::ExperimentProp> named
C<Project> and C<Lab> for the the
L<Experiment|ModENCODE::Chado::Experiment> specified in C<$experiment> to match
the project groups and subgroups specified in the ini-file loaded by
L<ModENCODE::Config> so that the capitalization is consistent.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Config>, L<ModENCODE::Validator::Attributes>,
L<ModENCODE::Validator::Data>, L<ModENCODE::Validator::IDF_SDRF>,
L<ModENCODE::Validator::TermSources>, L<ModENCODE::Validator::Wiki>,
L<ModENCODE::Chado::Experiment>, L<ModENCODE::Chado::ExperimentProp>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
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
  my ($group) = grep { $_->get_name() eq "Project" } @{$experiment->get_properties()};
  my ($subgroup) = grep { $_->get_name() eq "Lab" } @{$experiment->get_properties()};

  $group = $group->clone() if $group;
  $subgroup = $subgroup->clone() if $subgroup;

  my $group_name = $group->get_value() if $group;
  if (!length($group_name)) {
    log_error "Can't find any modENCODE project group - should be defined in the IDF.";
    return 0;
  }
  $group_name =~ s/^\s*|\s*$//g;
  my ($matching_group_name) = grep { $_ =~ m/^\s*\Q$group_name\E\s*$/i } keys(%{$project_names{ident $self}});
  if (!length($matching_group_name)) {
    log_error "Can't find a modENCODE project group matching '$group_name'. Options are: " . join(", ", keys(%{$project_names{ident $self}})) . ".";
    return 0;
  }
  $group->set_value($matching_group_name);

  if (!$subgroup || !length($subgroup->get_value())) {
    log_error "No modENCODE project sub-group defined - defaulting to main group '$matching_group_name'.", "warning";
    $subgroup = $group->clone();
    $subgroup->set_name('Lab');
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
  #$experiment = $experiment->clone();
  my ($group) = grep { $_->get_name() eq "Project" } @{$experiment->get_properties()};
  my ($subgroup) = grep { $_->get_name() eq "Lab" } @{$experiment->get_properties()};
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
    $subgroup->set_name('Lab');
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
      'name' => 'Project URL',
    });
  $experiment->add_property($group_url);
  return $experiment;
}

1;

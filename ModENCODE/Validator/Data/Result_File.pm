package ModENCODE::Validator::Data::Result_File;
=pod

=head1 NAME

ModENCODE::Validator::Data::Result_File - Class for verifying the existence of
result files referenced in  BIR-TAB data column objects.

=head1 SYNOPSIS

This class is meant to be used to verify the existence of the files referenced
(by path) when given L<ModENCODE::Chado::Data> objects with values that are
paths to result files. 

=head1 USAGE

A BIR-TAB data column should be run through this validator if it contains the
path to a result file. This is implemented in practice by a special case in
L<ModENCODE::Validator::Data> that checks any data column with a heading of
"Result File"  using this validtor.

The file at that given path is not parsed or opened, and currently the datum
itself is not even modified in any way. This should not be the final state of
affairs, see L</TODO>.

  my $datum = new ModENCODE::Chado::Data({
    'value' => 'relative/path/to/file'
  });
  my $applied_protocol = new ModENCODE::Chado::AppliedProtocol({
    'input_data' => [ $datum ],
  });
  my $validator = new ModENCODE::Validator::Data::Result_File();
  $validator->add_datum($datum, $applied_protocol);
  if ($validator->validate()) {
    my $new_datum = $validator->merge($datum); # Actually does nothing for now
    print $new_datum->get_value() . " is an existing file.\n";
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Data>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> have values that point to existing files.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>,
returns that same datum with no changes. This should eventually do something;
see L</TODO>.

=back

=head1 TODO

This class should eventually do something to ensure that the uploaded file is
either pushed into the L<Experiment|ModENCODE::Chado::Experiment> object or
saved somewhere outside of the submission path.

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<ModENCODE::Chado::CVTerm>,
L<ModENCODE::Validator::Data::GFF3>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::SO_transcript>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::dbEST_acc>,
L<ModENCODE::Validator::Data::dbEST_acc_list>,

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Chado::Wiggle_Data;
use ModENCODE::ErrorHandler qw(log_error);


sub validate {
  my ($self) = @_;
  my $success = 1;
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum = $datum_hash->{'datum'}->clone();
    if (length($datum->get_value())) {
      next if ($datum->get_value() =~ m/(http|ftp):\/\//);
      if (!-r $datum->get_value()) {
        log_error "Can't find Result File [" . $datum->get_name() . "]=" . $datum->get_value() . ".";
        $success = 0;
      }
    }
  }

  return $success;
}

sub merge {
  my ($self, $datum, $applied_protocol) = @_;
  return $datum;
}

1;

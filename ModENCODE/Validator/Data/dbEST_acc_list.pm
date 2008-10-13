package ModENCODE::Validator::Data::dbEST_acc_list;
=pod

=head1 NAME

ModENCODE::Validator::Data::dbEST_acc_list - Class for validating and updating
BIR-TAB L<Data|ModENCODE::Chado::Data> objects containing files that are lists
of ESTs to include L<Features|ModENCODE::Chado::Feature> for those ESTs.

=head1 SYNOPSIS

This class uses L<ModENCODE::Validator::Data::dbEST_acc> to validate a list of
ESTs stored in a file (one GenBank accession per line) rather than a list of
ESTs kept directly in the SDRF. When L</validate()> is called, this validator
creates a skeleton L<ModENCODE::Chado::Data> object for each EST accession in
each path referred to by a datum attached to this validator with
L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)>. It then creates an internal copy of the
L<dbEST_acc|ModENCODE::Validator::Data::dbEST_acc> validator and then and adds
each skeleton datum to the L<dbEST_acc|ModENCODE::Validator::Data::dbEST_acc>
validator with L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)>. Finally, it calls the
L<validate()|ModENCODE::Validator::Data::dbEST_acc/validate()> method of the
L<dbEST_acc|ModENCODE::Validator::Data::dbEST_acc> validator and returns the
result. If the EST file does not exist or cannot be parsed, then validate
returns 0.

=head1 USAGE

To use this validator in a standalone way:

  my $datum = new ModENCODE::Chado::Data({
    'value' => '/path/to/est_list.txt'
  });
  my $validator = new ModENCODE::Validator::Data::dbEST_acc_list();
  $validator->add_datum($datum, $applied_protocol);
  if ($validator->validate()) {
    my $new_datum = $validator->merge($datum);
    print $new_datum->get_features()->[0]->get_name();
  }

Note that this class is not meant to be used directly, rather it is mean to be
used within L<ModENCODE::Validator::Data>.

=head1 FUNCTIONS

=over

=item validate()

Makes sure that all of the data added using L<add_datum($datum,
$applied_protocol)|ModENCODE::Validator::Data::Data/add_datum($datum,
$applied_protocol)> have values that exist as files containing lists of GenBank
EST accessions as tested by L<ModENCODE::Validator::Data::dbEST_acc>.

=item merge($datum, $applied_protocol)

Given an original L<datum|ModENCODE::Chado::Data> C<$datum>, returns a copy of
that datum with a set of newly attached features based on EST records in either
the local modENCODE database, FlyBase, or GenBank for the list of EST accessions
in the file that is the value in that C<$datum>. Does this by calling
L<ModENCODE::Validator::Data::dbEST_acc/merge($datum, $applied_protocol)>, which
may make changes of its own.

=back

=head1 SEE ALSO

L<ModENCODE::Chado::Data>, L<ModENCODE::Validator::Data>,
L<ModENCODE::Validator::Data::Data>, L<ModENCODE::Chado::Feature>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Organism>,
L<ModENCODE::Chado::FeatureLoc>, L<ModENCODE::Validator::Data::BED>,
L<ModENCODE::Validator::Data::Result_File>,
L<ModENCODE::Validator::Data::SO_transcript>,
L<ModENCODE::Validator::Data::WIG>, L<ModENCODE::Validator::Data::GFF3>,
L<ModENCODE::Validator::Data::dbEST_acc>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use base qw( ModENCODE::Validator::Data::Data );
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Validator::Data::dbEST_acc;
use ModENCODE::ErrorHandler qw(log_error);

my %seen_est_files              :ATTR( :default<[]> );
my %features_by_acc             :ATTR( :default<{}> );

sub validate {
  my ($self) = @_;
  log_error "Parsing list of ESTs.", "notice", ">";
  my $success = 1;

  my $est_validator = new ModENCODE::Validator::Data::dbEST_acc({ 'data_validator' => $self->get_data_validator() });

  my @est_list_file_data;
  foreach my $datum_hash (@{$self->get_data()}) {
    my $datum = $datum_hash->{'datum'}->clone();
    my $applied_protocol = $datum_hash->{'applied_protocol'};

    my $est_list_file = $datum_hash->{'datum'}->get_value();
    next unless length($est_list_file);
    log_error "Parsing list of ESTs from file " . $est_list_file . ".", "notice", ">";
    if (!-r $est_list_file) {
      log_error "Cannot read EST list file '$est_list_file'.";
      $success = 0;
      next;
    }
    if (!scalar(grep { $_ eq $est_list_file } @{$seen_est_files{ident $self}})) {
      unless (open ESTS, $est_list_file) {
        log_error "Cannot open EST list file '$est_list_file' for reading.";
        $success = 0;
        next;
      }

      log_error "Reading file...", "notice", ">";
      my $i = 0;
      while (defined(my $est = <ESTS>)) {
        $i++;
        if (!($i % 1000)) { log_error "Parsed line $i.", "notice"; }
        $est =~ s/\s*//g;
        my $temp_datum = new ModENCODE::Chado::Data({
            'value' => $est
          });
	if (!($est =~ m/^\s*$/)) {  #skip blanks
        $est_validator->add_datum($temp_datum, $applied_protocol, 1); # Skip equality check
	} else {
	    log_error ("skipping blank line", "notice");
	}
	    
      }
      $success = 0 unless $est_validator->validate();
      log_error "Done.", "notice", "<";
      if ($success) {
        my @temp_data = @{$est_validator->get_data()};
        foreach my $temp_datum (@temp_data) {
          foreach my $feature (@{$temp_datum->{'merged_datum'}->get_features()}) {
            $features_by_acc{ident $self}->{$temp_datum->{'datum'}->get_value()} = $feature;
            $datum->add_feature($feature);
          }
        }
        $datum_hash->{'merged_datum'} = $datum;
      }
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

1;

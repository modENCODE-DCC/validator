package ModENCODE::Validator::Attributes;
=pod

=head1 NAME

ModENCODE::Validator::Attributes - Delegator used to apply validators to BIR-TAB
attribute columns.

=head1 SYNOPSIS

This class is designed to be run on an
L<Experiment|ModENCODE::Chado::Experiment> object. It will then call any of the
validators defined in the L<Class::Std> L<BUILD|/new(\%args)> method on the appropriate
attribute columns. To add new third-party attribute validators, you should
extend this class and just overried the C<BUILD> method to attach the
additional attribute validators.

=head1 USAGE

=head2 Extending for Other Modules

The L<constructor|/new(\%args)> sets the contents of the C<%validators{ident $self}>
hash. The keys of the hash are I<either> the BIR-TAB Term Source type (e.g.
C<URL_mediawiki>) or the L<CVTerm|ModENCODE::Chado::CVTerm> type of the
attribute column (e.g.  C<SO:transcript>). The value of the hash is the
validator that should be run on any columns with that Term Source or type. For
instance:

  $validators{$ident}->{'URL_mediawiki_expansion'} = new ModENCODE::Validator::Attributes::URL_mediawiki_expansion();

The above line specifies that the
L<ModENCODE::Validator::Attributes::URL_mediawiki_expansion> validator should be
used on any attribute column that is followed by a C<Term Source REF> column
containing a reference to a term source of type C<URL_mediawiki_expansion>. Each
value in the attribute column will be added to the validator using its
L<add_attribute|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
method. The syntax for validating based on the attribute type is very similar,
just replace the Term Source name (C<URL_mediawiki_expansion>) with a
colon-delimited controlled vocabulary and term, like so:

  $validators{$ident}->{'SO:transcript'} = new ModENCODE::Validator::Attributes::Transcript();

=head2 Running

  my $attribute_validator = new ModENCODE::Validator::Attributes();
  my $success = $attribute_validator->validate($experiment);
  if ($success) {
    $experiment = $attribute_validator->merge($experiment);
  }

Once a ModENCODE::Validator::Attributes object (or extending subclass) has been
created, you can validate the attribute columns associated with all L<applied
protocols|ModENCODE::Chado::AppliedProtocol> in an
L<Experiment|ModENCODE::Chado::Experiment> object by using the
</validate($experiment)> method and then merge in any changes made by the
validators using L</merge($experiment)>.

=head1 FUNCTIONS

=over

=item new(\%args)

Constructor called on any objects created by L<Class::Std> defined in the
C<BUILD> method. See the documentation for L<Class::Std/BUILD()> for more
information on when this method is called. In this class, it is used to define
which attribute validators should be used for which columns. (See L<Extending
for Other Modules|/Extending for Other Modules>.) Note that every C<BUILD>
method in the class hierarchy will be called, so if you don't want to use the
default validators in a subclass, you'll want to clean out the
C<%validators{ident $self}> hash.

=item validate($experiment)

Collects all of the attribute columns associated with any L<applied
protocols|ModENCODE::Chado::AppliedProtocol> or L<data|ModENCODE::Chado::Data>
in the L<Experiment|ModENCODE::Chado::Experiment> object in C<$experiment>. For
each L<ModENCODE::Chado::Attribute> found, it calls the
L<add_attribute|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
method of any validator defined in the C<%validators{ident $self}> hash for the
attribute's type or Term Source type. Once all attributes have been apportioned
to their appropriate validator(s), the
L<validate()|ModENCODE::Validator::Attributes::Attributes/validate()>
method of each validator is called. If all of the C<validate> calls return true,
then this C<validate($experiment)> call returns 1, otherwise it returns 0.

For any attribute with no validator associated for either the term source type
or attribute type, a warning is printed and the attribute is left untouched,
assumed to be a free text field.

=item merge($experiment)

Collects all of the attribute columns associated with any L<applied
protocols|ModENCODE::Chado::AppliedProtocol> or L<data|ModENCODE::Chado::Data>
in the L<Experiment|ModENCODE::Chado::Experiment> object in C<$experiment>. For
each L<ModENCODE::Chado::Attribute> found, it calls the
L<add_attribute|ModENCODE::Validator::Attributes::Attributes/add_attribute($attribute)>
method of any validator defined in the C<%validators{ident $self}> hash for the
attribute's type or Term Source type. Once all attributes have been apportioned
to their appropriate mergers(s), the
L<merge()|ModENCODE::Validator::Attributes::Attributes/merge()> method of each
validator is called. The C<merge> method of each validator should return an
arrayref of L<attributes|ModENCODE::Chado::Attribute> containing the
C<$attribute>, with any changes made, plus any new attributes that are being
added. The attribute object in the C<$experiment> is then replaced with with
updated attributes.

For any attribute with no validator associated for either the term source type
or attribute type, a warning is printed and the attribute is left untouched,
assumed to be a free text field.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Validator::Attributes::Attributes>,
L<ModENCODE::Validator::Attributes::Organism>,
L<ModENCODE::Validator::Attributes::URL_mediawiki_expansion>,
L<ModENCODE::Chado::Attribute>, L<ModENCODE::Chado::DBXref>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::Experiment>,
L<ModENCODE::Chado::AppliedProtocol>, L<ModENCODE::Validator::Data>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use ModENCODE::Validator::Attributes::URL_mediawiki_expansion;
use ModENCODE::Validator::Attributes::Organism;
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::ErrorHandler qw(log_error);

my %validators                  :ATTR( :default<{}> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  $validators{$ident}->{'URL_mediawiki_expansion'} = new ModENCODE::Validator::Attributes::URL_mediawiki_expansion();
  $validators{$ident}->{'organism'} = new ModENCODE::Validator::Attributes::Organism();
}

sub merge {
  my ($self, $experiment) = @_;
  #$experiment = $experiment->clone();
  
  # Get attributes for data only; don't expand protocol attributes
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      my @protocol_attributes = @{$applied_protocol->get_protocol()->get_attributes()};
      my @new_attributes;
      foreach my $attribute (@{$applied_protocol->get_protocol()->get_attributes()}) {
        if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
          my $attribute_termsource_type = $attribute->get_termsource()->get_db()->get_description();
          my $validator = $validators{ident $self}->{$attribute_termsource_type};
          if ($validator) {
            my $merged_attributes = $validator->merge($attribute);
	    if ($merged_attributes) {
              push @new_attributes, @$merged_attributes;
	    } else {
	    log_error ("Cannot merge attribute " . $attribute->get_name . " if they do not validate", "error" ) unless $merged_attributes;
	    }
          } else {
            # Just keep the original attribute
            push @new_attributes, $attribute;
          }
        } elsif ($attribute->get_type() && $attribute->get_type()->get_cv()) {
          my $attribute_type_source = $attribute->get_type->get_cv()->get_name();
          my $validator = $validators{ident $self}->{$attribute_type_source};
          if ($validator) {
            my $merged_attributes = $validator->merge($attribute);
	    if ($merged_attributes) {
              push @new_attributes, @$merged_attributes;
	    } else {
	    log_error ("Cannot merge attribute " . $attribute->get_name . " if they do not validate", "error" ) unless $merged_attributes;
	    }
          } else {
            # Just keep the original attribute
            push @new_attributes, $attribute;
          }
        }
      }
      $applied_protocol->get_protocol()->set_attributes(\@new_attributes);
      foreach my $datum (@{$applied_protocol->get_output_data()}, @{$applied_protocol->get_input_data()}) {
        # Get a copy of the array of attributes (so we can swap them out)
        my @datum_attributes = @{$datum->get_attributes()};
        my @new_attributes;
        foreach my $attribute (@datum_attributes) {
          if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
            my $attribute_termsource_type = $attribute->get_termsource()->get_db()->get_description();
            my $validator = $validators{ident $self}->{$attribute_termsource_type};
            if ($validator) {
              my $merged_attributes = $validator->merge($attribute);
	    if ($merged_attributes) {
              push @new_attributes, @$merged_attributes;
	    } else {
	    log_error ("Cannot merge attribute " . $attribute->get_name . " if they do not validate", "error" ) unless $merged_attributes;
	    }
            } else {
              # Just keep the original attribute
              push @new_attributes, $attribute;
            }
          } elsif ($attribute->get_type() && $attribute->get_type()->get_cv()) {
            my $attribute_type_source = $attribute->get_type->get_cv()->get_name();
            my $validator = $validators{ident $self}->{$attribute_type_source};
            if ($validator) {
              my $merged_attributes = $validator->merge($attribute);
	    if ($merged_attributes) {
              push @new_attributes, @$merged_attributes;
	    } else {
	    log_error ("Cannot merge attribute " . $attribute->get_name . " if they do not validate", "error" ) unless $merged_attributes;
	    }
            } else {
              # Just keep the original attribute
              push @new_attributes, $attribute;
            }
          }
        }
        $datum->set_attributes(\@new_attributes);
      }
    }
  }
  return $experiment;
}

sub validate {
  my ($self, $experiment) = @_;
  #$experiment = $experiment->clone();
  my $success = 1;

  my @unique_attributes;
  foreach my $applied_protocol_slots (@{$experiment->get_applied_protocol_slots()}) {
    foreach my $applied_protocol (@$applied_protocol_slots) {
      foreach my $attribute (@{$applied_protocol->get_protocol()->get_attributes()}) {
        if (!scalar(grep { $attribute == $_ } @unique_attributes)) {
          push @unique_attributes, $attribute;
        }
      }
      foreach my $datum (@{$applied_protocol->get_output_data()}, @{$applied_protocol->get_input_data()}) {
        foreach my $attribute (@{$datum->get_attributes()}) {
          # Actual equality, not ->equals, since we want to validate the attributes
          if (!scalar(grep { $attribute == $_ } @unique_attributes)) {
            push @unique_attributes, $attribute;
          }
        }
      }
    }
  }

  # For any attribute with a termsource of type where there exists a validator module
  foreach my $attribute (@unique_attributes) {
    if ($attribute->get_termsource() && $attribute->get_termsource()->get_db()) {
      my $attribute_termsource_type = $attribute->get_termsource()->get_db()->get_description();
      my $validator = $validators{ident $self}->{$attribute_termsource_type};
      if (!$validator) {
        log_error "No validator for attribute " . $attribute->get_heading() . " [" . $attribute->get_name() . "] with term source type $attribute_termsource_type.", "warning";
        next;
      }
      $validator->add_attribute($attribute);
    }
  }
  # For any attribute with a type where there exists a validator module
  foreach my $attribute (@unique_attributes) {
    if ($attribute->get_type() && $attribute->get_type()->get_cv()) {
      my $attribute_type_source = $attribute->get_type->get_cv()->get_name();
      my $validator = $validators{ident $self}->{$attribute_type_source};
      if (!$validator) {
        log_error "No validator for attribute of type $attribute_type_source.", "warning";
        next;
      }
      $validator->add_attribute($attribute);
    }
  }
  foreach my $validator (values(%{$validators{ident $self}})) {
    if (!$validator->validate()) {
      log_error "Attributes columns do not validate", "error";
      return 0;
    }
  }
  return 1;
}

1;

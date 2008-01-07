package ModENCODE::Parser::IDF;

use strict;

use Class::Std;
use Parse::RecDescent;
use Carp qw(croak carp);
use Data::Dumper;

use ModENCODE::Parser::SDRF;
use ModENCODE::Chado::Experiment;
use ModENCODE::Chado::ExperimentProp;
use ModENCODE::Chado::CVTerm;
use ModENCODE::Chado::CV;
use ModENCODE::Chado::Protocol;
use ModENCODE::Chado::Attribute;
use ModENCODE::Chado::DBXref;
use ModENCODE::Chado::DB;

my %grammar     :ATTR;

sub BUILD {
  my ($self, $ident, $args) = @_;

  $grammar{$ident} = <<'  GRAMMAR';
    {
      my $experiment = {};
      my $persons = {};
      my $instance = {};
      my $optional_metadata = {};
      my $protocols = {};
      my $term_sources = {};
    }
    IDF:                                experiment
                                        optional_metadata(?)
                                        contact
                                        experiment_instance(?)
                                        optional_metadata(?)
                                        protocol
                                        sdrf_file
                                        term_source
                                        end_of_file
                                        {
                                          my $experiment_obj = new ModENCODE::Chado::Experiment();
                                          $experiment_obj->add_properties($item[1]);
                                          if (defined($item[2])) { $experiment_obj->add_properties($item[2]->[0]); }
                                          $experiment_obj->add_properties($item[3]);
                                          if (defined($item[4])) { $experiment_obj->add_properties($item[4]->[0]); }
                                          if (defined($item[5])) { $experiment_obj->add_properties($item[5]->[0]); }
                                          return [$experiment_obj, $item[6], $item[7], $item[8]];
                                        }
                                        | <error>

  ##################################
  # Basic experiment metadata      #
  ##################################
  experiment:                           experiment_part(s)
                                        {
                                          # Convert experiment hash into experiment properties
                                          my @experiment_properties;
                                          my $modencode_cv = new ModENCODE::Chado::CV({'name' => 'modencode'});
                                          push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                              'value' => $experiment->{'Investigation Title'}->[0],
                                              'type' => new ModENCODE::Chado::CVTerm({'name' => 'Investigation Title', 'cv' => $modencode_cv}),
                                            });
                                          push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                              'value' => $experiment->{'Experimental Design'}->[0],
                                              'type' => new ModENCODE::Chado::CVTerm({'name' => 'Experimental Design', 'cv' => $modencode_cv}),
                                            });
                                          if (defined($experiment->{'Experimental Factor Name'})) {
                                            for (my $i = 0; $i < scalar(@{$experiment->{'Experimental Factor Name'}}); $i++) {
                                              my $factor_name = $experiment->{'Experimental Factor Name'}->[$i];
                                              my $factor_type = $experiment->{'Experimental Factor Type'}->[$i];
                                              my $factor_termsource = $experiment->{'Experimental Factor Term Source REF'}->[$i];
                                              if (length($factor_name)) {
                                                push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                    'value' => $factor_name,
                                                    'type' => new ModENCODE::Chado::CVTerm({'name' => 'Experimental Factor Name', 'cv' => $modencode_cv}),
                                                    'rank' => $i,
                                                  });
                                              }
                                              if (length($factor_type)) {
                                                push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                    'value' => $factor_type,
                                                    'type' => new ModENCODE::Chado::CVTerm({'name' => 'Experimental Factor Type', 'cv' => $modencode_cv}),
                                                    'rank' => $i,
                                                  });
                                              }
                                              if (length($factor_termsource)) {
                                                push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                    'value' => $factor_termsource,
                                                    'type' => new ModENCODE::Chado::CVTerm({'name' => 'Experimental Factor Term Source REF', 'cv' => $modencode_cv}),
                                                    'rank' => $i,
                                                  });
                                              }
                                            }
                                          }

                                          $return = \@experiment_properties;
                                        }
                                        | <error>

  experiment_part:                      investigation_title
                                        | experimental_design
                                        | experimental_factor
                                        | <error>

  investigation_title_heading:          /Investigation *Title/i
  investigation_title:                  <skip:'[\n \t]*'> investigation_title_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $experiment->{'Investigation Title'} = [] if (!defined($experiment->{'Investigation Title'}));
                                          push @{$experiment->{'Investigation Title'}}, @{$item[4]};
                                        }

  experimental_design_heading:          /Experimental *Design/i
  experimental_design:                  <skip:'[\n \t]*'> experimental_design_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $experiment->{'Experimental Design'} = [] if (!defined($experiment->{'Experimental Design'}));
                                          push @{$experiment->{'Experimental Design'}}, @{$item[4]};
                                        }

  experimental_factor:                  experimental_factor_name experimental_factor_type(?) experimental_factor_term_source_ref(?)

  experimental_factor_name_heading:     /Experimental *Factor *Name/i
  experimental_factor_name:             <skip:'[\n \t]*'> experimental_factor_name_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $experiment->{'Experimental Factor Name'} = [] if (!defined($experiment->{'Experimental Factor Name'}));
                                          push @{$experiment->{'Experimental Factor Name'}}, @{$item[4]};
                                        }

  experimental_factor_type_heading:     /Experimental *Factor *Type/i
  experimental_factor_type:             <skip:'[\n \t]*'> experimental_factor_type_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $experiment->{'Experimental Factor Type'} = [] if (!defined($experiment->{'Experimental Factor Type'}));
                                          push @{$experiment->{'Experimental Factor Type'}}, @{$item[4]};
                                        }

  experimental_factor_termsource_heading: /Experimental *Factor *Term *Source *REF/i
  experimental_factor_term_source_ref:  <skip:'[\n \t]*'> experimental_factor_termsource_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $experiment->{'Experimental Factor Term Source REF'} = [] if (!defined($experiment->{'Experimental Factor Term Source REF'}));
                                          push @{$experiment->{'Experimental Factor Term Source REF'}}, @{$item[4]};
                                        }

  ##################################
  # Contact information/people     #
  ##################################
  contact:                              person_info(s?) person_role(s?)
                                        {
                                          # Convert contacts hash into experiment properties
                                          my @experiment_properties;
                                          my $modencode_cv = new ModENCODE::Chado::CV({'name' => 'modencode'});
                                          if (defined($persons->{'Person Last Name'})) {
                                            for (my $i = 0; $i < scalar(@{$persons->{'Person Last Name'}}); $i++) {
                                              foreach my $person_attrib_name (keys(%$persons)) {
                                                my $person_attrib_value = $persons->{$person_attrib_name}->[$i];
                                                if (length($person_attrib_value)) {
                                                  push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                      'value' => $person_attrib_value,
                                                      'type' => new ModENCODE::Chado::CVTerm({'name' => $person_attrib_name, 'cv' => $modencode_cv}),
                                                      'rank' => $i,
                                                    });
                                                }
                                              }
                                            }
                                          }

                                          $return = \@experiment_properties;
                                        }
                                        | <error>

  person_info:                          person_name
                                        | person_email
                                        | person_phone
                                        | person_address
                                        | person_affiliation
                                        | person_role_name
                                        | person_role_term_source_ref
                                        | <error>

  person_name:                          person_last_name
                                        | person_first_name
                                        | person_mid_initial
  person_last_name_heading:             /Person *Last *Name/i
  person_last_name:                     <skip:'[\n \t]*'> person_last_name_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Last Name'} = [] if (!defined($persons->{'Person Last Name'}));
                                          push @{$persons->{'Person Last Name'}}, @{$item[4]};
                                        }
  person_first_name_heading:            /Person *First *Name/i
  person_first_name:                    <skip:'[\n \t]*'> person_first_name_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person First Name'} = [] if (!defined($persons->{'Person First Name'}));
                                          push @{$persons->{'Person First Name'}}, @{$item[4]};
                                        }
  person_mid_initial_heading:           /Person *Mid(dle)? *Initials?/i
  person_mid_initial:                   <skip:'[\n \t]*'> person_mid_initial_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Mid Initials'} = [] if (!defined($persons->{'Person Mid Initials'}));
                                          push @{$persons->{'Person Mid Initials'}}, @{$item[4]};
                                        }
  person_email_heading:                 /Person *Email *(Address)*/i
  person_email:                         <skip:'[\n \t]*'> person_email_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Email'} = [] if (!defined($persons->{'Person Email'}));
                                          push @{$persons->{'Person Email'}}, @{$item[4]};
                                        }
  person_phone_heading:                 /Person *Phone/i
  person_phone:                         <skip:'[\n \t]*'> person_phone_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Phone'} = [] if (!defined($persons->{'Person Phone'}));
                                          push @{$persons->{'Person Phone'}}, @{$item[4]};
                                        }
  person_address_heading:               /Person *Address/i
  person_address:                       <skip:'[\n \t]*'> person_address_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Address'} = [] if (!defined($persons->{'Person Address'}));
                                          push @{$persons->{'Person Address'}}, @{$item[4]};
                                        }
  person_affiliation_heading:           /Person *Affiliation/i
  person_affiliation:                   <skip:'[\n \t]*'> person_affiliation_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Affiliation'} = [] if (!defined($persons->{'Person Affiliation'}));
                                          push @{$persons->{'Person Affiliation'}}, @{$item[4]};
                                        }

  person_role:                          person_role_name
                                        | person_role_term_source_ref
  person_role_name_heading:             /Person *Roles?/i
  person_role_name:                     <skip:'[\n \t]*'> person_role_name_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Roles'} = [] if (!defined($persons->{'Person Roles'}));
                                          push @{$persons->{'Person Roles'}}, @{$item[4]};
                                        }
  person_role_termsource_heading:       /Person *Roles? *Term *Source *REF/i
  person_role_term_source_ref:          <skip:'[\n \t]*'> person_role_termsource_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $persons->{'Person Roles Term Source REF'} = [] if (!defined($persons->{'Person Roles Term Source REF'}));
                                          push @{$persons->{'Person Roles Term Source REF'}}, @{$item[4]};
                                        }

  ##################################
  # Experiment replicate info      #
  ##################################
  experiment_instance:                  experiment_instance_part(s)
                                        {
                                          # Convert experiment instances hash into experiment properties
                                          my @experiment_properties;
                                          my $modencode_cv = new ModENCODE::Chado::CV({'name' => 'modencode'});
                                          if (defined($instance->{'Quality Control Type'})) {
                                            for (my $i = 0; $i < scalar(@{$instance->{'Quality Control Type'}}); $i++) {
                                              my $qc_type = $instance->{'Quality Control Type'}->[$i];
                                              my $qc_termsource = $instance->{'Quality Control Term Source REF'}->[$i];
                                              if (length($qc_type)) {
                                                push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                    'value' => $qc_type,
                                                    'type' => new ModENCODE::Chado::CVTerm({'name' => 'Quality Control Type', 'cv' => $modencode_cv}),
                                                    'rank' => $i,
                                                  });
                                                }
                                              if (length($qc_termsource)) {
                                                push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                    'value' => $qc_termsource,
                                                    'type' => new ModENCODE::Chado::CVTerm({'name' => 'Quality Control Term Source REF', 'cv' => $modencode_cv}),
                                                    'rank' => $i,
                                                  });
                                              }
                                            }
                                          }
                                          if (defined($instance->{'Replicate Type'})) {
                                            for (my $i = 0; $i < scalar(@{$instance->{'Replicate Type'}}); $i++) {
                                              my $replicate_type = $instance->{'Replicate Type'}->[$i];
                                              my $replicate_termsource = $instance->{'Replicate Term Source REF'}->[$i];
                                              if (length($replicate_type)) {
                                                push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                    'value' => $replicate_type,
                                                    'type' => new ModENCODE::Chado::CVTerm({'name' => 'Replicate Type', 'cv' => $modencode_cv}),
                                                    'rank' => $i,
                                                  });
                                                }
                                              if (length($replicate_termsource)) {
                                                push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                    'value' => $replicate_termsource,
                                                    'type' => new ModENCODE::Chado::CVTerm({'name' => 'Replicate Term Source REF', 'cv' => $modencode_cv}),
                                                    'rank' => $i,
                                                  });
                                              }
                                            }
                                          }
                                          $return = \@experiment_properties;
                                        }
  experiment_instance_part:             quality_control
                                        | replicate
                                        | date_of_experiment
                                        | release_date
                                        | <error>

  quality_control:                      quality_control_type quality_control_term_source_ref(?)
  quality_control_type_heading:         /Quality *Control *Type/i
  quality_control_type:                 <skip:'[\n \t]*'> quality_control_type_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $instance->{'Quality Control Type'} = [] if (!defined($instance->{'Quality Control Type'}));
                                          push @{$instance->{'Quality Control Type'}}, @{$item[4]};
                                        }
  quality_control_termsource_heading:   /Quality *Control *(Type)? *Term *Source *REF/i
  quality_control_term_source_ref:      <skip:'[\n \t]*'> quality_control_termsource_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $instance->{'Quality Control Term Source REF'} = [] if (!defined($instance->{'Quality Control Term Source REF'}));
                                          push @{$instance->{'Quality Control Term Source REF'}}, @{$item[4]};
                                        }

  replicate:                            replicate_type replicate_term_source_ref(?)
  replicate_type_heading:               /Replicate *Type/i
  replicate_type:                       <skip:'[\n \t]*'> replicate_type_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $instance->{'Replicate Type'} = [] if (!defined($instance->{'Replicate Type'}));
                                          push @{$instance->{'Replicate Type'}}, @{$item[4]};
                                        }
  replicate_termsource_heading:         /Replicate *(Type)? *Term *Source *REF/i
  replicate_term_source_ref:            <skip:'[\n \t]*'> replicate_termsource_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $instance->{'Replicate Term Source REF'} = [] if (!defined($instance->{'Replicate Term Source REF'}));
                                          push @{$instance->{'Replicate Term Source REF'}}, @{$item[4]};
                                        }

  ##################################
  # Optional metadata              #
  ##################################
  optional_metadata:                    optional_metadata_part(s)
                                        {
                                          # Convert experiment optional_metadatas hash into experiment properties
                                          my @experiment_properties;
                                          my $modencode_cv = new ModENCODE::Chado::CV({'name' => 'modencode'});
                                          if (defined($optional_metadata->{'Date of Experiment'}) && length($optional_metadata->{'Date of Experiment'}->[0])) {
                                            push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                'value' => $optional_metadata->{'Date of Experiment'}->[0],
                                                'type' => new ModENCODE::Chado::CVTerm({'name' => 'Date of Experiment', 'cv' => $modencode_cv}),
                                              });
                                          }
                                          if (defined($optional_metadata->{'Public Release Date'}) && length($optional_metadata->{'Public Release Date'}->[0])) {
                                            push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                'value' => $optional_metadata->{'Public Release Date'}->[0],
                                                'type' => new ModENCODE::Chado::CVTerm({'name' => 'Public Release Date', 'cv' => $modencode_cv}),
                                              });
                                          }
                                          if (defined($optional_metadata->{'PubMed ID'}) && length($optional_metadata->{'PubMed ID'}->[0])) {
                                            push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                'value' => $optional_metadata->{'PubMed ID'}->[0],
                                                'type' => new ModENCODE::Chado::CVTerm({'name' => 'PubMed ID', 'cv' => $modencode_cv}),
                                              });
                                          }
                                          if (defined($optional_metadata->{'Experiment Description'}) && length($optional_metadata->{'Experiment Description'}->[0])) {
                                            push @experiment_properties, new ModENCODE::Chado::ExperimentProp({
                                                'value' => $optional_metadata->{'Experiment Description'}->[0],
                                                'type' => new ModENCODE::Chado::CVTerm({'name' => 'Experiment Description', 'cv' => $modencode_cv}),
                                              });
                                          }
                                          $return = \@experiment_properties;
                                        }
  optional_metadata_part:               pubmed_id | experiment_description_ref
                                        | <error>

  pubmed_id_heading:                    /PubMed *ID/i
  pubmed_id:                            <skip:'[\n \t]*'> pubmed_id_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $optional_metadata->{'PubMed ID'} = [] if (!defined($optional_metadata->{'PubMed ID'}));
                                          push @{$optional_metadata->{'PubMed ID'}}, @{$item[4]};
                                        }
  experiment_description_ref_heading:   /Experiment *Description *(REF)?/i
  experiment_description_ref:           <skip:'[\n \t]*'> experiment_description_ref_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $optional_metadata->{'Experiment Description'} = [] if (!defined($optional_metadata->{'Experiment Description'}));
                                          push @{$optional_metadata->{'Experiment Description'}}, @{$item[4]};
                                        }
  date_of_experiment_heading:           /Date *of *Experiment/i
  date_of_experiment:                   <skip:'[\n \t]*'> date_of_experiment_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $optional_metadata->{'Date of Experiment'} = [] if (!defined($optional_metadata->{'Date of Experiment'}));
                                          push @{$optional_metadata->{'Date of Experiment'}}, @{$item[4]};
                                        }
  release_date_heading:                 /(Public)? *Release *Date/i
  release_date:                         <skip:'[\n \t]*'> release_date_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $optional_metadata->{'Public Release Date'} = [] if (!defined($optional_metadata->{'Public Release Date'}));
                                          push @{$optional_metadata->{'Public Release Date'}}, @{$item[4]};
                                        }


  ##################################
  # Protocol information           #
  ##################################
  protocol:                             protocol_part(s)
                                        {
                                          # Convert protocols hash into protocol objects
                                          my @protocols;
                                          my $modencode_cv = new ModENCODE::Chado::CV({'name' => 'modencode'});
                                          if (defined($protocols->{'Protocol Name'})) {
                                            for (my $i = 0; $i < scalar(@{$protocols->{'Protocol Name'}}); $i++) {
                                              my $protocol_name = $protocols->{'Protocol Name'}->[$i];
                                              next unless length($protocol_name);
                                              my $protocol_obj = new ModENCODE::Chado::Protocol({'name' => $protocol_name});

                                              my $protocol_description = $protocols->{'Protocol Description'}->[$i];
                                              if (length($protocol_description)) {
                                                $protocol_obj->set_description($protocol_description);
                                              }

                                              my $protocol_type = $protocols->{'Protocol Type'}->[$i];
                                              if (length($protocol_type)) {
                                                my $protocol_type_obj = new ModENCODE::Chado::Attribute({
                                                    'heading' => 'Protocol Type',
                                                    'value' => $protocol_type,
                                                  });
                                                $protocol_obj->add_attribute($protocol_type_obj);
                                              }
                                              my $protocol_parameters = $protocols->{'Protocol Parameters'}->[$i];
                                              if (length($protocol_parameters)) {
                                                my $protocol_parameters_obj = new ModENCODE::Chado::Attribute({
                                                    'heading' => 'Protocol Parameters',
                                                    'value' => $protocol_parameters,
                                                  });
                                                $protocol_obj->add_attribute($protocol_parameters_obj);
                                              }
                                              my $protocol_type_termsource = $protocols->{'Protocol Type Term Source REF'}->[$i];
                                              if (length($protocol_type_termsource)) {
                                                my $protocol_type_termsource_obj = new ModENCODE::Chado::Attribute({
                                                    'heading' => 'Protocol Type Term Source REF',
                                                    'value' => $protocol_type_termsource,
                                                  });
                                                $protocol_obj->add_attribute($protocol_type_termsource_obj);
                                              }


                                              push @protocols, $protocol_obj;
                                            }
                                          }
                                          $return = \@protocols;
                                        }
  protocol_part:                        protocol_name
                                        | protocol_type
                                        | protocol_description
                                        | protocol_parameters
                                        | protocol_term_source_ref

  protocol_name_heading:                /Protocol *Name/i
  protocol_name:                        <skip:'[\n \t]*'> protocol_name_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $protocols->{'Protocol Name'} = [] if (!defined($protocols->{'Protocol Name'}));
                                          push @{$protocols->{'Protocol Name'}}, @{$item[4]};
                                        }
  protocol_type_heading:                /Protocol *Type/i
  protocol_type:                        <skip:'[\n \t]*'> protocol_type_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $protocols->{'Protocol Type'} = [] if (!defined($protocols->{'Protocol Type'}));
                                          push @{$protocols->{'Protocol Type'}}, @{$item[4]};
                                        }
  protocol_description_heading:         /Protocol *Description/i
  protocol_description:                 <skip:'[\n \t]*'> protocol_description_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $protocols->{'Protocol Description'} = [] if (!defined($protocols->{'Protocol Description'}));
                                          push @{$protocols->{'Protocol Description'}}, @{$item[4]};
                                        }
  protocol_parameters_heading:          /Protocol *Parameters?/i
  protocol_parameters:                  <skip:'[\n \t]*'> protocol_parameters_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $protocols->{'Protocol Parameters'} = [] if (!defined($protocols->{'Protocol Parameters'}));
                                          push @{$protocols->{'Protocol Parameters'}}, @{$item[4]};
                                        }
  protocol_ref_heading:                 /Protocol *(Type)? *Term *Source *REF/i
  protocol_term_source_ref:             <skip:'[\n \t]*'> protocol_ref_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $protocols->{'Protocol Type Term Source REF'} = [] if (!defined($protocols->{'Protocol Type Term Source REF'}));
                                          push @{$protocols->{'Protocol Type Term Source REF'}}, @{$item[4]};
                                        }

  ##################################
  # SDRF file                      #
  ##################################
  sdrf_file_heading:                    /SDRF *File/i
  sdrf_file:                            <skip:'[\n \t]*'> sdrf_file_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          my @sdrf_experiments;
                                          foreach my $sdrf_file (@{$item[4]}) {
                                            next unless (length($sdrf_file));
                                            my $sdrf_parser = new ModENCODE::Parser::SDRF();
                                            my $sdrf_experiment = $sdrf_parser->parse($sdrf_file);
                                            push @sdrf_experiments, $sdrf_experiment;
                                          }
                                          $return = \@sdrf_experiments;
                                        }

  ##################################
  # Term Source references         #
  ##################################
  term_source:                          term_source_part(s)
                                        {
                                          # Convert term sources hash into dbxref objects
                                          my @dbxrefs;
                                          my $modencode_cv = new ModENCODE::Chado::CV({'name' => 'modencode'});
                                          if (defined($term_sources->{'Term Source Name'})) {
                                            for (my $i = 0; $i < scalar(@{$term_sources->{'Term Source Name'}}); $i++) {
                                              my $term_source_name = $term_sources->{'Term Source Name'}->[$i];
                                              next unless length($term_source_name);
                                              my $term_source_obj = new ModENCODE::Chado::DB({'name' => $term_source_name});
                                              my $term_obj = new ModENCODE::Chado::DBXref();

                                              my $term_source_file = $term_sources->{'Term Source File'}->[$i];
                                              if (length($term_source_file)) {
                                                $term_source_obj->set_url($term_source_file);
                                              }
                                              my $term_source_type = $term_sources->{'Term Source Type'}->[$i];
                                              if (length($term_source_type)) {
                                                $term_source_obj->set_description($term_source_type);
                                              }

                                              my $term_source_version = $term_sources->{'Term Source Version'}->[$i];
                                              if (length($term_source_version)) {
                                                $term_obj->set_version($term_source_version);
                                              }

                                              $term_obj->set_db($term_source_obj);
                                              push @dbxrefs, $term_obj;
                                            }
                                          }
                                          $return = \@dbxrefs;
                                        }
  term_source_part:                     term_source_name
                                        | term_source_file
                                        | term_source_version
                                        | term_source_type
                                        | <error>
  term_source_name_heading:             /Term *Source *Name/i
  term_source_name:                     <skip:'[\n \t]*'> term_source_name_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $term_sources->{'Term Source Name'} = [] if (!defined($term_sources->{'Term Source Name'}));
                                          push @{$term_sources->{'Term Source Name'}}, @{$item[4]};
                                        }
  term_source_file_heading:             /Term *Source *(File|URL|URI)/i
  term_source_file:                     <skip:'[\n \t]*'> term_source_file_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $term_sources->{'Term Source File'} = [] if (!defined($term_sources->{'Term Source File'}));
                                          push @{$term_sources->{'Term Source File'}}, @{$item[4]};
                                        }
  term_source_version_heading:          /Term *Source *Version/i
  term_source_version:                  <skip:'[\n \t]*'> term_source_version_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $term_sources->{'Term Source Version'} = [] if (!defined($term_sources->{'Term Source Version'}));
                                          push @{$term_sources->{'Term Source Version'}}, @{$item[4]};
                                        }
  term_source_type_heading:             /Term *Source *Type/i
  term_source_type:                     <skip:'[\n \t]*'> term_source_type_heading <skip:'[ "]*\t[ "]*'> field_value(s)
                                        { 
                                          $term_sources->{'Term Source Type'} = [] if (!defined($term_sources->{'Term Source Type'}));
                                          push @{$term_sources->{'Term Source Type'}}, @{$item[4]};
                                        }

  ##################################
  # Basic parsing terms            #
  ##################################
  field_value:                          /([^\t"\n\r]*[ "]*)/
                                        { $return = $1; }

  end_of_file:                          <skip:'[\n \t]*'> /([\s\r\n]*)$/

  GRAMMAR

}
sub parse {
  my ($self, $document) = @_;
  if ( -r $document ) {
    local $/;
    open FH, "<$document" or croak "Couldn't read file $document";
    $document = <FH>;
    close FH;
  }
  $document =~ s/\A [" ]*/\t/gxms;
  my $parser = $self->_get_parser();
  
  return $parser->IDF($document);
}

sub _get_parser : RESTRICTED {
  my ($self) = @_;
  $::RD_ERRORS++;
  $::RD_WARN++;
  $::RD_HINT++;
  #$::RD_TRACE++;
  $::RD_AUTOSTUB++;
  $Parse::RecDescent::skip = '[ "]*\t[ "]*';
  my $parser = new Parse::RecDescent($grammar{ident $self});
}

1;

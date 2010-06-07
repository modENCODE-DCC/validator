package ModENCODE::Validator::Data::ReadCount::MultiiplyMappedReadCount;

# the ReadCount data type will create an experiment property (in addition to an attribute)
# of the total read count for an experiment - this will allow quick access to
# view the total number of reads from a sequencing reaction for an entire experiment
# whether or not the data submitter submitted individual lane counts, or a summed read count
#this specific subclass will set the title for the 


use strict;
use ModENCODE::Validator::Data::ReadCount;
use base qw( ModENCODE::Validator::Data::ReadCount );
use ModENCODE::Parser::Chado;
use ModENCODE::ErrorHandler qw(log_error);
use Class::Std;
use Carp qw(croak carp);
use ModENCODE::Config;


sub get_title {
    return "Multiply Mapped Read Count";
}

1;

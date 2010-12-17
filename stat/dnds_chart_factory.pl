#!/usr/bin/perl
use warnings;
use strict;

use Getopt::Long;
use Pod::Usage;

use FindBin;
use lib "$FindBin::Bin/../lib";
use AlignDB::Excel;
use AlignDB::Stopwatch;

#----------------------------------------------------------#
# GetOpt section
#----------------------------------------------------------#
my $infile        = '';
my $outfile       = '';
my $jc_correction = 0;
my $time_stamp    = 1;

my $man  = 0;
my $help = 0;

GetOptions(
    'help|?'       => \$help,
    'man'          => \$man,
    'infile=s'     => \$infile,
    'outfile=s'    => \$outfile,
    'jc=s'         => \$jc_correction,
    'time_stamp=s' => \$time_stamp,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;


#----------------------------------------------------------#
# Init section
#----------------------------------------------------------#
my $stopwatch = AlignDB::Stopwatch->new();
$stopwatch->start_message("Processing $infile...");

my $excel_obj;
if ($outfile) {
    $excel_obj = AlignDB::Excel->new(
        infile  => $infile,
        outfile => $outfile,
    );
}
else {
    $excel_obj = AlignDB::Excel->new( infile => $infile, );
    $outfile = $excel_obj->get_outfile;
}

#----------------------------------------------------------#
# START
#----------------------------------------------------------#
# jc
if ($jc_correction) {
    $excel_obj->jc_correction;
}

# add time stamp
if ($time_stamp) {
    $excel_obj->time_stamp("summary");
}

# draw charts section
#

{

    #----------------------------#
    # worksheet -- gene_ess, exon_ess, exon_gc
    #----------------------------#
    my @sheets = qw{
        distance
    };

    foreach (@sheets) {
        my $sheet_name = $_;
        #my $x_title = /gene/ ? "Distance to gene"
        #    : /exon/ ? "Distance to exon"
        #    :          "Distance to coding";
        my %option = (
            chart_serial => 1,
            x_column     => 1,
            y_column     => 3,
            y_last_column => 4,
            first_row    => 3,
            last_row     => 33,
            x_min_scale  => 0,
            x_max_scale  => 30,
            y_scale_unit => 0.005,
            x_title      => "Distance to indel",
            y_title      => "Syn - Non-syn",
            Height       => 283.7,
            Width        => 453.9,
            Top          => 12.75,
            Left         => 400,
        );

        $excel_obj->draw_y( $sheet_name, \%option );

        # chart 2
        $option{chart_serial}++;
        $option{y_column}     = 7;
        $option{y_last_column} = 7;
        $option{y_scale_unit} = 0.01;
        $option{y_title}      = "dn/ds";
        $option{Top} += $option{Height} + 12.75;
        $excel_obj->draw_y( $sheet_name, \%option );
    }
}

print "$outfile has been generated.\n";

$stopwatch->end_message();
exit;

__END__
    
=head1 NAME

    gc_chart_factory.pl - Use Win32::OLE to automate Excel chart

=head1 SYNOPSIS

    gc_chart_factory.pl [options]
     Options:
       --help            brief help message
       --man             full documentation
       --infile          input file name (full path)
       --outfile         output file name
       

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do someting
useful with the contents thereof.

=cut
#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use YAML qw(Dump Load DumpFile LoadFile);

use File::Find::Rule;
use File::Basename;

use AlignDB::Stopwatch;

use FindBin;
use lib "$FindBin::Bin/../lib";
use AlignDB::Util qw(:all);

#----------------------------------------------------------#
# GetOpt section
#----------------------------------------------------------#
my $axt_dir;
my $out_dir;

my $man  = 0;
my $help = 0;

GetOptions(
    'help|?'    => \$help,
    'man'       => \$man,
    'axt_dir=s' => \$axt_dir,
    'out_dir=s' => \$out_dir,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

$out_dir ||= $axt_dir . "_rev";

#----------------------------------------------------------#
# Init objects
#----------------------------------------------------------#
my $stopwatch = AlignDB::Stopwatch->new();
$stopwatch->start_message("Reverse .axt files from axt_dir...");

my @axt_files = File::Find::Rule->file()->name('*.axt')->in($axt_dir);
printf "\n----Total .AXT Files: %4s----\n\n", scalar @axt_files;

unless ( -e $out_dir ) {
    mkdir $out_dir, 0777
        or die qq{Cannot create directory: "$out_dir"};
}

#----------------------------------------------------------#
# Write .axt files
#----------------------------------------------------------#

my $process_axt = sub {
    my $infile = shift;

    my $stopwatch = AlignDB::Stopwatch->new();
    $stopwatch->block_message("Process $infile...");

    open my $axt_fh, '<', $infile
        or die "Cannot open file: $infile";

    my $out_file = basename($infile);
    $out_file =~ s/(\.axt)$/_rev$1/;
    open my $out_fh, '>', "$out_dir/$out_file";

    while (1) {
        my $summary_line = <$axt_fh>;
        unless ($summary_line) {
            last;
        }
        if ( $summary_line =~ /^#/ ) {
            next;
        }
        chomp $summary_line;
        chomp( my $first_line  = <$axt_fh> );
        chomp( my $second_line = <$axt_fh> );
        my $dummy = <$axt_fh>;

        my ($align_serial, $first_chr,    $first_start,
            $first_end,    $second_chr,   $second_start,
            $second_end,   $query_strand, $align_score,
        ) = split /\s+/, $summary_line;

        # append axt file
        {
            print {$out_fh} "$align_serial";
            print {$out_fh} " $second_chr";
            print {$out_fh} " $second_start $second_end";
            print {$out_fh} " $first_chr";
            print {$out_fh} " $first_start $first_end";
            print {$out_fh} " $query_strand $align_score\n";
            if ( $query_strand eq '-' ) {
                $first_line  = revcom($first_line);
                $second_line = revcom($second_line);
            }
            print {$out_fh} $second_line, "\n";
            print {$out_fh} $first_line,  "\n";
            print {$out_fh} "\n";
        }

    }
    close $out_fh;
    close $axt_fh;
};

foreach my $infile ( sort @axt_files ) {
    &{$process_axt}($infile);
}

$stopwatch->end_message();
exit;

__END__
=head1 NAME

    reverse_axt.pl - reverse target and query in .axt files

=head1 SYNOPSIS

    reverse_axt.pl [options]
      Options:
        --help          brief help message
        --man           full documentation
        --axt_dir       .axt files' directory
        --out_dir       output directory

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

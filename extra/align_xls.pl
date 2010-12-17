#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Config::Tiny;
use YAML qw(Dump Load DumpFile LoadFile);

use Spreadsheet::WriteExcel;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);

use FindBin;
use lib "$FindBin::Bin/../lib";
use AlignDB;
use AlignDB::Stopwatch;

#----------------------------------------------------------#
# GetOpt section
#----------------------------------------------------------#
my $Config = Config::Tiny->new();
$Config = Config::Tiny->read("$FindBin::Bin/../alignDB.ini");

# Database init values
my $server   = $Config->{database}->{server};
my $port     = $Config->{database}->{port};
my $username = $Config->{database}->{username};
my $password = $Config->{database}->{password};
my $db       = $Config->{database}->{db};

# format parameters
my $wrap    = 50;
my $spacing = 0;

my $align_id = 1;
my $outfile;

my $man  = 0;
my $help = 0;

GetOptions(
    'help|?'     => \$help,
    'man'        => \$man,
    'server=s'   => \$server,
    'db=s'       => \$db,
    'username=s' => \$username,
    'password=s' => \$password,
    'wrap=i'     => \$wrap,
    'spacing=i'  => \$spacing,
    'align_id=s' => \$align_id,
    'output=s'   => \$outfile,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

$outfile ||= "$db-align-$align_id.xls";

#----------------------------------------------------------#
# Init objects and SQL queries
#----------------------------------------------------------#
my $stopwatch = AlignDB::Stopwatch->new();
$stopwatch->start_message("Init objects...");

my $obj = AlignDB->new(
    mysql  => "$db:$server",
    user   => $username,
    passwd => $password,
);

my $dbh = $obj->dbh();

# get target, query and reference names via AlignDB methods
my ( $target_name, $query_name, $ref_name ) = $obj->get_names($align_id);
my $max_name_length
    = max( length $target_name, length $query_name, length $ref_name );

if ( !$ref_name or $ref_name eq 'NULL' ) {
    die "$db is not a three-way alignDB\n";
}

# get snp info
my $snp_query = q{
    SELECT s.snp_pos,
           s.snp_occured,
           s.target_base,
           s.query_base,
           s.ref_base
    FROM align a,
         snp s
    WHERE a.align_id = ? AND
          a.align_id = s.align_id
    ORDER BY s.snp_pos
};
my $snp_query_sth = $dbh->prepare($snp_query);

# select all isws in this alignment
my $indel_query = q{
    SELECT i.indel_start,
           i.indel_end,
           i.indel_length,
           i.indel_occured,
           i.indel_type
    FROM align a,
         indel i
    WHERE a.align_id = ? AND
          a.align_id = i.align_id
    ORDER BY i.indel_start
};
my $indel_query_sth = $dbh->prepare($indel_query);

# Create workbook and worksheet objects
my $workbook;
unless ( $workbook = Spreadsheet::WriteExcel->new($outfile) ) {
    die "Cannot create Excel file $outfile\n";
}
my $sheet = $workbook->add_worksheet();

#----------------------------------------------------------#
# Get data
#----------------------------------------------------------#
print "Get variation data...\n";

# store all variations, including indels and snps
my %variations;

# snp
$snp_query_sth->execute($align_id);
while ( my $hash_ref = $snp_query_sth->fetchrow_hashref ) {
    my $start_pos = $hash_ref->{snp_pos};
    $hash_ref->{var_type} = 'snp';
    $variations{$start_pos} = $hash_ref;
}

# indel
$indel_query_sth->execute($align_id);
while ( my $hash_ref = $indel_query_sth->fetchrow_hashref ) {
    my $start_pos = $hash_ref->{indel_start};
    $hash_ref->{var_type} = 'indel';
    $variations{$start_pos} = $hash_ref;
}

#DumpFile( "var.yaml", \%variations );

#----------------------------------------------------------#
# Excel format
#----------------------------------------------------------#
# species name format
my $name_format = $workbook->add_format(
    font => 'Courier New',
    size => 8,
);

# variation position format
my $pos_format = $workbook->add_format(
    font     => 'Courier New',
    size     => 8,
    align    => 'center',
    valign   => 'vcenter',
    rotation => 90,
);

# snp base format
my $snp_fg_of = {
    A   => { color => 'green', },
    C   => { color => 'blue', },
    G   => { color => 'pink', },
    T   => { color => 'red', },
    N   => { color => 'black' },
    '-' => { color => 'black' },
};

my $snp_bg_of = {
    T => { bg_color => 43, },    # lightyellow
    Q => { bg_color => 42, },    # lightgreen
    N => {},
};

my $snp_format = {};
for my $fg ( keys %{$snp_fg_of} ) {
    for my $bg ( keys %{$snp_bg_of} ) {
        $snp_format->{"$fg$bg"} = $workbook->add_format(
            font   => 'Courier New',
            size   => 8,
            bold   => 1,
            align  => 'center',
            valign => 'vcenter',
            %{ $snp_fg_of->{$fg} },
            %{ $snp_bg_of->{$bg} },
        );
    }
}

# indel format
my $indel_bg_of = {
    T => { bg_color => 'yellow', },
    Q => { bg_color => 11, },         # brightgreen, lime
    N => { bg_color => 'silver', },
    C => { bg_color => 'gray', },
};

my $indel_format = {};
my $merge_format = {};
for my $bg ( keys %{$indel_bg_of} ) {
    $indel_format->{$bg} = $workbook->add_format(
        font   => 'Courier New',
        size   => 8,
        bold   => 1,
        align  => 'center',
        valign => 'vcenter',
        %{ $indel_bg_of->{$bg} },
    );
    $merge_format->{$bg} = $workbook->add_format(
        font   => 'Courier New',
        size   => 8,
        bold   => 1,
        align  => 'center',
        valign => 'vcenter',
        %{ $indel_bg_of->{$bg} },
    );
}

#----------------------------------------------------------#
# write execel
#----------------------------------------------------------#
print "Write excel...\n";

my $col_cursor     = 1;
my $section        = 1;
my $section_height = 4 + $spacing;

for my $pos ( sort { $a <=> $b } keys %variations ) {
    my $var = $variations{$pos};
    my $pos_row = $section_height * ( $section - 1 );

    # write snp
    if ( $var->{var_type} eq 'snp' ) {
        my $snp_pos     = $var->{snp_pos};
        my $snp_occured = $var->{snp_occured};
        my $ref_base    = $var->{ref_base};
        my $target_base = $var->{target_base};
        my $query_base  = $var->{query_base};

        # write position
        $sheet->write( $pos_row, $col_cursor, $snp_pos, $pos_format );

        # write reference
        my $ref_occ = "$ref_base$snp_occured";
        $sheet->write( $pos_row + 1,
            $col_cursor, $ref_base, $snp_format->{$ref_occ} );

        # write target
        my $target_occ = "$target_base$snp_occured";
        $sheet->write( $pos_row + 2,
            $col_cursor, $target_base, $snp_format->{$target_occ} );

        # write query
        my $query_occ = "$query_base$snp_occured";
        $sheet->write( $pos_row + 3,
            $col_cursor, $query_base, $snp_format->{$query_occ} );

        $col_cursor++;
    }

    # write indel
    if ( $var->{var_type} eq 'indel' ) {
        my $indel_start   = $var->{indel_start};
        my $indel_end     = $var->{indel_end};
        my $indel_length  = $var->{indel_length};
        my $indel_occured = $var->{indel_occured};
        my $indel_type    = $var->{indel_type};

        # how many column does this indel take up
        my $col_takeup = min( $indel_length, 3 );

        # if exceed the wrap limit, start a new section
        if ( $col_cursor + $col_takeup > $wrap ) {
            $col_cursor = 1;
            $section++;
            $pos_row = $section_height * ( $section - 1 );
        }

        #print Dump($var);

        # offset from the pos_row
        my $indel_offset
            = $indel_occured eq "N" ? 1
            : $indel_occured eq "C" ? 1
            : $indel_occured eq "T" ? 2
            : $indel_occured eq "Q" ? 3
            :                         undef;

        my $indel_string = "$indel_type$indel_length";

        if ( $indel_length == 1 ) {

            # write position
            $sheet->write( $pos_row, $col_cursor, $indel_start, $pos_format );

            # write in indel occured lineage
            $sheet->write( $pos_row + $indel_offset,
                $col_cursor, $indel_string, $indel_format->{$indel_occured} );

            $col_cursor++;
        }
        elsif ( $indel_length == 2 ) {

            # write indel_start position
            my $start_col = $col_cursor;
            $sheet->write( $pos_row, $start_col, $indel_start, $pos_format );
            $col_cursor++;

            # write indel_end position
            my $end_col = $col_cursor;
            $sheet->write( $pos_row, $end_col, $indel_end, $pos_format );
            $col_cursor++;

            # merge two indel position
            $sheet->merge_range(
                $pos_row + $indel_offset, $start_col,
                $pos_row + $indel_offset, $end_col,
                $indel_string,            $merge_format->{$indel_occured},
            );
        }
        else {

            # write indel_start position
            my $start_col = $col_cursor;
            $sheet->write( $pos_row, $start_col, $indel_start, $pos_format );
            $col_cursor++;

            # write middle sign
            my $middle_col = $col_cursor;
            $sheet->write( $pos_row, $middle_col, '|', $pos_format );
            $col_cursor++;

            # write indel_end position
            my $end_col = $col_cursor;
            $sheet->write( $pos_row, $end_col, $indel_end, $pos_format );
            $col_cursor++;

            # merge two indel position
            $sheet->merge_range(
                $pos_row + $indel_offset, $start_col,
                $pos_row + $indel_offset, $end_col,
                $indel_string,            $merge_format->{$indel_occured},
            );
        }

    }

    if ( $col_cursor > $wrap ) {
        $col_cursor = 1;
        $section++;
    }
}

# write names
for ( 1 .. $section ) {
    my $pos_row = $section_height * ( $_ - 1 );

    $sheet->write( $pos_row + 1, 0, $ref_name,    $name_format );
    $sheet->write( $pos_row + 2, 0, $target_name, $name_format );
    $sheet->write( $pos_row + 3, 0, $query_name,  $name_format );
}

# format column
$sheet->set_column( 0, 0,         $max_name_length + 2 );
$sheet->set_column( 1, $wrap + 3, 1.6 );

$workbook->close();

$stopwatch->end_message();
exit;

__END__

=head1 NAME

    align_xls.pl - Generate a colorful excel file for one alignment in
                     a three-way alignDB

=head1 SYNOPSIS

    align_xls.pl [options]
     Options:
       --help            brief help message
       --man             full documentation
       --server          MySQL server IP/Domain name
       --db              database name
       --username        username
       --password        password
       --wrap            wrap number 
       --spacing         wrapped line spacing
       --align_id        align_id
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
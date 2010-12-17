#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Config::Tiny;
use YAML qw(Dump Load DumpFile LoadFile);

use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use List::MoreUtils qw(any all);
use Math::Combinatorics;
use Statistics::Descriptive;

use AlignDB::IntSpan;
use AlignDB::Stopwatch;
use AlignDB::Util qw(:all);

use FindBin;
use lib "$FindBin::Bin/../lib";
use AlignDB;
use AlignDB::Position;

#----------------------------------------------------------#
# GetOpt section
#----------------------------------------------------------#
my $Config = Config::Tiny->new;
$Config = Config::Tiny->read("$FindBin::Bin/../alignDB.ini");

# record ARGV and Config
my $stopwatch = AlignDB::Stopwatch->new(
    program_name => $0,
    program_argv => [@ARGV],
    program_conf => $Config,
);

# Database init values
my $server   = $Config->{database}{server};
my $port     = $Config->{database}{port};
my $username = $Config->{database}{username};
my $password = $Config->{database}{password};

# ref parameter
my $first_db         = $Config->{ref}{first_db};
my $second_db        = $Config->{ref}{second_db};
my $goal_db          = $Config->{ref}{goal_db};
my $outgroup         = $Config->{ref}{outgroup};
my $first            = $Config->{ref}{first};
my $second           = $Config->{ref}{second};
my $length_threshold = $Config->{ref}{length_threshold};
my $raw_fasta        = $Config->{ref}{raw_fasta};
my $trimmed_fasta    = $Config->{ref}{trimmed_fasta};
my $insert_ssw       = $Config->{ref}{insert_ssw};
my $reduce_end       = $Config->{ref}{reduce_end};
my $chr_id_runlist   = $Config->{ref}{chr_id_runlist};

# additional db
my $third_db = '';
my $third    = '1query';
my $forth_db = '';
my $forth    = '3query';
my $fifth_db = '';
my $fifth    = '4query';
my $sixth_db = '';
my $sixth    = '5query';

my $no_insert       = 0;
my $discard_paralog = 0;
my $discard_distant = 0;

# realign parameters
my $indel_expand = $Config->{ref}{indel_expand};
my $indel_join   = $Config->{ref}{indel_join};

# run init_alignDB.pl or not
my $init_db = 1;

my $man  = 0;
my $help = 0;

GetOptions(
    'help|?'            => \$help,
    'man'               => \$man,
    'server=s'          => \$server,
    'port=i'            => \$port,
    'username=s'        => \$username,
    'password=s'        => \$password,
    'first_db=s'        => \$first_db,
    'second_db=s'       => \$second_db,
    'third_db=s'        => \$third_db,
    'forth_db=s'        => \$forth_db,
    'fifth_db=s'        => \$fifth_db,
    'sixth_db=s'        => \$sixth_db,
    'goal_db=s'         => \$goal_db,
    'outgroup=s'        => \$outgroup,
    'target=s'          => \$first,
    'query=s'           => \$second,
    'third=s'           => \$third,
    'length=i'          => \$length_threshold,
    'raw_fasta=s'       => \$raw_fasta,
    'trimmed_fasta=s'   => \$trimmed_fasta,
    'insert_ssw=s'      => \$insert_ssw,
    'reduce_end=i'      => \$reduce_end,
    'chr_id_runlist=s'  => \$chr_id_runlist,
    'init_db=s'         => \$init_db,
    'no_insert=s'       => \$no_insert,
    'discard_paralog=s' => \$discard_paralog,
    'discard_distant=s' => \$discard_distant,
    'indel_expand=i'    => \$indel_expand,
    'indel_join=i'      => \$indel_join,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

my $chr_id_set = AlignDB::IntSpan->new($chr_id_runlist);
my @chr_ids    = $chr_id_set->elements();

#----------------------------------------------------------#
# perl init_alignDB.pl
#----------------------------------------------------------#
$stopwatch->start_message("ref_outgroup.pl...");

if ( !$no_insert and $init_db ) {
    my $cmd
        = "perl $FindBin::Bin/../init/init_alignDB.pl"
        . " -s=$server"
        . " --port=$port"
        . " -d=$goal_db"
        . " -u=$username"
        . " --password=$password";
    print "\n", "=" x 12, "CMD", "=" x 15, "\n";
    print $cmd , "\n";
    print "=" x 30, "\n";
    system($cmd);
}

#----------------------------------------------------------#
# Init objects
#----------------------------------------------------------#
my $first_obj = AlignDB->new(
    mysql  => "$first_db:$server",
    user   => $username,
    passwd => $password,
);

my $second_obj = AlignDB->new(
    mysql  => "$second_db:$server",
    user   => $username,
    passwd => $password,
);

my $goal_obj;
if ( !$no_insert ) {
    $goal_obj = AlignDB->new(
        mysql      => "$goal_db:$server",
        user       => $username,
        passwd     => $password,
        insert_ssw => $insert_ssw,
    );
}

# get dbh
my $first_dbh  = $first_obj->dbh();
my $second_dbh = $second_obj->dbh();

# position finder
my $first_pos_obj  = AlignDB::Position->new( dbh => $first_dbh );
my $second_pos_obj = AlignDB::Position->new( dbh => $second_dbh );

# db names
my @all_dbs = ( $first_db, $second_db );

# names
# e.g. 0target, 0query
my @all_names
    = ( $outgroup, $first, $second, $third, $forth, $fifth, $sixth );

# info hash
my %db_info_of = (
    $first_db => {
        target => {
            taxon_id => '',
            name     => '',
        },
        query => {
            taxon_id => '',
            name     => '',
        },
        obj     => $first_obj,
        dbh     => $first_dbh,
        pos_obj => $first_pos_obj,
    },
    $second_db => {
        target => {
            taxon_id => '',
            name     => '',
        },
        query => {
            taxon_id => '',
            name     => '',
        },
        obj     => $second_obj,
        dbh     => $second_dbh,
        pos_obj => $second_pos_obj,
    },
);

# Other dbs
foreach ( $third_db, $forth_db, $fifth_db, $sixth_db ) {
    if ($_) {
        my $cur_obj = AlignDB->new(
            mysql  => "$_:$server",
            user   => $username,
            passwd => $password,
        );
        my $cur_dbh = $cur_obj->dbh();
        my $cur_pos_obj = AlignDB::Position->new( dbh => $cur_dbh );
        push @all_dbs, $_;
        $db_info_of{$_} = {
            target => {
                taxon_id => '',
                name     => '',
            },
            query => {
                taxon_id => '',
                name     => '',
            },
            obj     => $cur_obj,
            dbh     => $cur_dbh,
            pos_obj => $cur_pos_obj,
        };
    }
}

# remove unnessary names
splice @all_names, scalar @all_dbs + 1;
my ( undef, @ingroup_names ) = @all_names;
my %ingroup_order;
for ( 0 .. @ingroup_names - 1 ) {
    $ingroup_order{ $ingroup_names[$_] } = $_;
}

#DumpFile(
#    'info.yaml',
#    {   all_dbs    => \@all_dbs,
#        all_names  => \@all_names,
#        db_info_of => \%db_info_of,
#    }
#);

#----------------------------------------------------------#
# Init
#----------------------------------------------------------#
{
    my $tvsq_query = qq{
        SELECT  target_taxon_id,
                target_name,
                query_taxon_id,
                query_name
        FROM tvsq
    };

    foreach my $db_name (@all_dbs) {
        my $cur_dbh  = $db_info_of{$db_name}->{dbh};
        my $tvsq_sth = $cur_dbh->prepare($tvsq_query);
        $tvsq_sth->execute();
        (   $db_info_of{$db_name}->{target}{taxon_id},
            $db_info_of{$db_name}->{target}{name},
            $db_info_of{$db_name}->{query}{taxon_id},
            $db_info_of{$db_name}->{query}{name},
        ) = $tvsq_sth->fetchrow_array;
    }
}

my $percentile_90;
if ($discard_distant) {
    $outgroup =~ /^(\d+)(.+)/;
    my $db_name_idx = $1;
    my $db_name     = $all_dbs[$db_name_idx];

    my $per_idn_query = qq{
        SELECT  a.identities / a.align_length
        FROM align a
    };

    my $dbh = $db_info_of{$db_name}->{dbh};
    my $sth = $dbh->prepare($per_idn_query);

    my @data;
    $sth->execute;
    while ( my @row = $sth->fetchrow_array ) {
        push @data, $row[0];
    }

    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@data);
    $percentile_90 = $stat->percentile($discard_distant);
}

#----------------------------------------------------------#
# Start
#----------------------------------------------------------#
foreach my $chr_id (@chr_ids) {
    my ($chr_name) = $first_obj->get_chr_info($chr_id);
    print "\nChr_id $chr_id\n";
    print "Chr_name $chr_name\n";

    #----------------------------#
    # build intersect set of first, second & third
    #----------------------------#
    my $inter_chr_set = AlignDB::IntSpan->new();
    foreach my $db_name (@all_dbs) {
        my $cur_dbh = $db_info_of{$db_name}->{dbh};
        my $cur_chr_set = &build_chr_set( $cur_dbh, $chr_id, $reduce_end );
        print "\n$db_name chr_set generated.\n";
        if ( $inter_chr_set->is_empty ) {
            $inter_chr_set = $cur_chr_set;
        }
        else {
            $inter_chr_set = $inter_chr_set->intersect($cur_chr_set);
        }
    }

    #----------------------------#
    # process each intersects
    #----------------------------#

    my @segments = $inter_chr_set->spans();
SEG: foreach (@segments) {
        my $seg_start  = $_->[0];
        my $seg_end    = $_->[1];
        my $seg_length = $seg_end - $seg_start + 1;
        next if $seg_length <= $length_threshold;

        print "\n$seg_length,$seg_start-$seg_end\n";

        # target chr position
        foreach my $db_name (@all_dbs) {
            $db_info_of{$db_name}->{target}{chr_start} = $seg_start;
            $db_info_of{$db_name}->{target}{chr_end}   = $seg_end;
        }

        foreach my $db_name (@all_dbs) {
            my $pos_obj = $db_info_of{$db_name}->{pos_obj};
            my ( $align_id, $dummy ) = @{
                $pos_obj->positioning_align_chr_id( $chr_id, $seg_start,
                    $seg_end )
                };

            if ( !defined $align_id ) {
                warn " " x 4, "Find no align in $db_name, jump to next\n";
                next SEG;
            }
            elsif ( defined $dummy ) {
                warn " " x 4, "Overlapped alignment in $db_name!\n";
                if ($discard_paralog) {
                    next SEG;
                }
            }
            $db_info_of{$db_name}->{align_id} = $align_id;
        }

        #----------------------------#
        # get seq, use align coordinates
        #----------------------------#
        foreach my $db_name (@all_dbs) {
            print " " x 4, "build $db_name seq\n";

            my $target_seq_query = q{
                SELECT  t.target_seq,
                        s.chr_id,
                        s.chr_strand
                FROM target t, sequence s
                WHERE t.seq_id = s.seq_id
                AND t.align_id = ?
            };
            my $query_seq_query = q{
                SELECT  q.query_seq,
                        q.query_strand,
                        s.chr_id,
                        s.chr_strand
                FROM query q, sequence s
                WHERE q.seq_id = s.seq_id
                AND q.align_id = ?
            };

            my $dbh      = $db_info_of{$db_name}->{dbh};
            my $pos_obj  = $db_info_of{$db_name}->{pos_obj};
            my $align_id = $db_info_of{$db_name}->{align_id};

            my $target_sth = $dbh->prepare($target_seq_query);
            $target_sth->execute($align_id);
            (   $db_info_of{$db_name}->{target}{full_seqs},
                $db_info_of{$db_name}->{target}{chr_id},
                $db_info_of{$db_name}->{target}{chr_strand},
            ) = $target_sth->fetchrow_array;

            my $query_sth = $dbh->prepare($query_seq_query);
            $query_sth->execute($align_id);
            (   $db_info_of{$db_name}->{query}{full_seqs},
                $db_info_of{$db_name}->{query}{query_strand},
                $db_info_of{$db_name}->{query}{chr_id},
                $db_info_of{$db_name}->{query}{chr_strand},
            ) = $query_sth->fetchrow_array;

            my $align_start = $pos_obj->at_align( $align_id, $seg_start );
            my $align_end   = $pos_obj->at_align( $align_id, $seg_end );

            # align_start and align_end should must be available
            unless ( $align_start and $align_end ) {
                warn " " x 8
                    . "align_start or align_end error"
                    . " in $db_name $align_id\n";
                next SEG;
            }

            my $align_length = $align_end - $align_start + 1;

            $db_info_of{$db_name}->{target}{seqs} = substr(
                $db_info_of{$db_name}->{target}{full_seqs},
                $align_start - 1,
                $align_length
            );
            $db_info_of{$db_name}->{query}{seqs} = substr(
                $db_info_of{$db_name}->{query}{full_seqs},
                $align_start - 1,
                $align_length
            );

            #DumpFile("$align_id-$db_name.yaml", $db_info_of{$db_name});
            unless (
                length $db_info_of{$db_name}->{target}{seqs}
                == length $db_info_of{$db_name}->{query}{seqs}
                and length $db_info_of{$db_name}->{target}{seqs} > 0 )
            {
                warn " " x 8
                    . "seq-length error"
                    . " in $db_name $align_id\n";
                next SEG;
            }

            delete $db_info_of{$db_name}->{target}{full_seqs};
            delete $db_info_of{$db_name}->{query}{full_seqs};
        }

        #----------------------------#
        # discard alignments which have low percentage identity to outgroup
        #----------------------------#
        if ($discard_distant) {
            $outgroup =~ /^(\d+)(.+)/;
            my $db_name_idx = $1;
            my $db_name     = $all_dbs[$db_name_idx];
            my $result      = &pair_seq_stat(
                $db_info_of{$db_name}->{target}{seqs},
                $db_info_of{$db_name}->{query}{seqs},
            );
            my $seq_legnth = $result->[0];
            my $identities = $result->[2];
            my $per_idn    = $identities / $seq_legnth;
            if ( $per_idn >= $percentile_90 ) {
                warn " " x 4 . "Low percentage identity with outgroup\n";
                next SEG;
            }
        }

        #----------------------------#
        # start peusdo-alignment, according to common sequences
        #----------------------------#
        print " " x 4, "start peusdo-alignment\n";
        my $pos_count = 0;
        while (1) {
            $pos_count++;
            my $max_length = 0;
            foreach my $db_name (@all_dbs) {
                $max_length = max( $max_length,
                    length $db_info_of{$db_name}->{target}{seqs} );
            }
            if ( $pos_count >= $max_length ) {
                last;
            }

            my @target_bases;
            foreach my $db_name (@all_dbs) {
                push @target_bases,
                    substr( $db_info_of{$db_name}->{target}{seqs},
                    $pos_count - 1, 1 );
            }

            if ( all { $_ eq $target_bases[0] } @target_bases ) {
                next;
            }
            elsif ( all { $_ ne '-' } @target_bases ) {
                warn " " x 8 . "align error in $pos_count, [@target_bases]\n";
                next SEG;
            }

            # insert a '-' in current position
            foreach ( 0 .. @all_dbs - 1 ) {
                my $db_name = $all_dbs[$_];
                if ( $target_bases[$_] eq '-' ) {
                    next;
                }
                else {
                    substr(
                        $db_info_of{$db_name}->{target}{seqs},
                        $pos_count - 1,
                        0, '-'
                    );
                    substr(
                        $db_info_of{$db_name}->{query}{seqs},
                        $pos_count - 1,
                        0, '-'
                    );
                }
            }
        }

        #----------------------------#
        # build %info_of all_names hash
        #----------------------------#
        my %info_of;
        for my $name (@all_names) {
            $name =~ /^(\d+)(.+)/;
            my $db_name_idx = $1;
            my $torq        = $2;
            if ( not( $torq eq 'target' or $torq eq 'query' ) ) {
                die "$torq is not equal to target or query\n";
            }
            my $db_name = $all_dbs[$db_name_idx];
            $info_of{$name} = $db_info_of{$db_name}->{$torq};
        }

        #----------------------------#
        # clustalw realign indel_flank region
        #----------------------------#
        {
            print " " x 4, "start finding realign region\n";

            # use AlignDB::IntSpan to find nearby indels
            #   expand indel by a range of $indel_expand
            print " " x 8, "union ingroup realign region\n";
            my %indel_sets;
            foreach (@all_names) {
                $indel_sets{$_}
                    = &find_indel_set( $info_of{$_}->{seqs}, $indel_expand );
            }

            my $realign_region = AlignDB::IntSpan->new();
            my $combinat       = Math::Combinatorics->new(
                count => 2,
                data  => \@all_names,
            );
            while ( my @combo = $combinat->next_combination ) {
                print " " x 8, "pairwise correction @combo\n";
                my $intersect_set = AlignDB::IntSpan->new();
                my $union_set     = AlignDB::IntSpan->new();
                $intersect_set = $indel_sets{ $combo[0] }
                    ->intersect( $indel_sets{ $combo[1] } );
                $union_set = $indel_sets{ $combo[0] }
                    ->union( $indel_sets{ $combo[1] } );

                foreach my $span ( $union_set->runlists() ) {
                    my $flag_set = $intersect_set->intersect($span);
                    if ( $flag_set->is_not_empty() ) {
                        $realign_region->add($span);
                    }
                }
            }

            # join adjacent realign regions
            $realign_region = $realign_region->join_span($indel_join);

            # realign all segments in realign_region
            my @realign_region_spans = $realign_region->spans();
            foreach ( reverse @realign_region_spans ) {
                my $seg_start = $_->[0];
                my $seg_end   = $_->[1];
                my @segments;
                foreach (@all_names) {
                    my $seg = substr(
                        $info_of{$_}->{seqs},
                        $seg_start - 1,
                        $seg_end - $seg_start + 1
                    );
                    push @segments, $seg;
                }

                my $realign_segments = &clustal_align( \@segments );

                foreach (@all_names) {
                    my $seg = shift @$realign_segments;
                    substr(
                        $info_of{$_}->{seqs},
                        $seg_start - 1,
                        $seg_end - $seg_start + 1, $seg
                    );
                }
            }
        }

        #----------------------------------------------------------#
        # output a raw fasta alignment for further use
        #----------------------------------------------------------#
        if ($raw_fasta) {
            unless ( -e $goal_db ) {
                mkdir $goal_db, 0777
                    or die "Cannot create \"$goal_db\" directory: $!";
            }
            my $first_taxon_id = $info_of{ $all_names[1] }->{taxon_id};
            my $outfile
                = "$goal_db/" . "raw_"
                . "id$first_taxon_id" . "_"
                . $chr_name . "_"
                . $seg_start . "_"
                . $seg_end . ".fas";
            print " " x 4, "$outfile\n";
            open my $out_fh, '>', $outfile
                or die("Cannot open OUT file $outfile");
            foreach my $name (@all_names) {
                my $seq = $info_of{$name}->{seqs};
                print {$out_fh} ">", $info_of{$name}->{name}, "\n";
                print {$out_fh} $seq, "\n";
            }
            close $out_fh;
        }

        #----------------------------------------------------------#
        # trim header and footer indels
        #----------------------------------------------------------#
        {

            # header indels
            while (1) {
                my @first_column;
                foreach (@all_names) {
                    my $first_base = substr( $info_of{$_}->{seqs}, 0, 1 );
                    push @first_column, $first_base;
                }
                if ( any { $_ eq '-' } @first_column ) {
                    foreach (@all_names) {
                        substr( $info_of{$_}->{seqs}, 0, 1, '' );
                    }
                    print " " x 4, "Trim header indel\n";
                }
                else {
                    last;
                }
            }

            # footer indels
            while (1) {
                my (@last_column);
                foreach (@all_names) {
                    my $last_base = substr( $info_of{$_}->{seqs}, -1, 1 );
                    push @last_column, $last_base;
                }
                if ( any { $_ eq '-' } @last_column ) {
                    foreach (@all_names) {
                        substr( $info_of{$_}->{seqs}, -1, 1, '' );
                    }
                    print " " x 4, "Trim footer indel\n";
                }
                else {
                    last;
                }
            }
        }

        #----------------------------------------------------------#
        # trim outgroup only sequence
        #----------------------------------------------------------#
        # if intersect is superset of union
        #   ref GAAAAC
        #   tar G----C
        #   que G----C
        {

            # add raw_seqs to outgroup info hash
            # it will be used in $goal_obj->add_align()
            $info_of{$outgroup}->{raw_seqs} = $info_of{$outgroup}->{seqs};

            # don't expand indel set
            my %indel_sets;
            foreach ( 1 .. @all_names - 1 ) {
                my $name = $all_names[$_];
                $indel_sets{$name}
                    = &find_indel_set( $info_of{$name}->{seqs} );
            }

            # find trim_region
            my $trim_region = AlignDB::IntSpan->new();

            my $union_set = AlignDB::IntSpan::union( values %indel_sets );
            my $intersect_set
                = AlignDB::IntSpan::intersect( values %indel_sets );

            foreach my $span ( $union_set->runlists() ) {
                if ( $intersect_set->superset($span) ) {
                    $trim_region->add($span);
                }
            }

            # trim all segments in trim_region
            foreach ( reverse $trim_region->spans() ) {
                my $seg_start = $_->[0];
                my $seg_end   = $_->[1];
                foreach (@all_names) {
                    substr(
                        $info_of{$_}->{seqs},
                        $seg_start - 1,
                        $seg_end - $seg_start + 1, ''
                    );
                }
                print " " x 4, "Delete trim region $seg_start - $seg_end\n";
            }
        }

        #----------------------------------------------------------#
        # record complex indels and ingroup indels
        #----------------------------------------------------------#
        # if intersect is subset of union
        #   ref GGAGAC
        #   tar G-A-AC
        #   que G----C
        {
            my $complex_region = AlignDB::IntSpan->new();

            # don't expand indel set
            my %indel_sets;
            foreach (@all_names) {
                $indel_sets{$_} = &find_indel_set( $info_of{$_}->{seqs} );
            }
            my $outgroup_indel_set = $indel_sets{$outgroup};
            delete $indel_sets{$outgroup};

            # all ingroup intersect sets are complex region after remove
            # uniform ingroup indels
            my $union_set = AlignDB::IntSpan::union( values %indel_sets );
            my $intersect_set
                = AlignDB::IntSpan::intersect( values %indel_sets );

            foreach ( reverse $intersect_set->spans() ) {
                my $seg_start = $_->[0];
                my $seg_end   = $_->[1];

                # trim sequence
                foreach (@all_names) {
                    substr(
                        $info_of{$_}->{seqs},
                        $seg_start - 1,
                        $seg_end - $seg_start + 1, ''
                    );
                }
                print " " x 4,
                    "Delete complex trim region $seg_start - $seg_end\n";

                # add to complex_region
                foreach my $span ( $union_set->runlists() ) {
                    my $sub_union_set = AlignDB::IntSpan->new($span);
                    if ( $sub_union_set->superset("$seg_start-$seg_end") ) {
                        $complex_region->merge($sub_union_set);
                    }
                }

                # modify all related set
                $union_set = $union_set->banish_span( $seg_start, $seg_end );
                foreach (@ingroup_names) {
                    $indel_sets{$_} = $indel_sets{$_}
                        ->banish_span( $seg_start, $seg_end );
                }
                $outgroup_indel_set->banish_span( $seg_start, $seg_end );
                $complex_region
                    = $complex_region->banish_span( $seg_start, $seg_end );
            }

            # add ingroup-outgroup complex indels to complex_region
            # and record ingroup indels
            my $all_indel_region = AlignDB::IntSpan->new();
            foreach my $name (@ingroup_names) {
                $all_indel_region->merge( $indel_sets{$name} );
                my $outgroup_intersect_set
                    = $outgroup_indel_set->intersect( $indel_sets{$name} );
                foreach my $out_span ( $outgroup_intersect_set->runlists() ) {

                    foreach my $union_span ( $union_set->runlists() ) {
                        my $sub_union_set
                            = AlignDB::IntSpan->new($union_span);

                        # union_set > intersect_set
                        if ( $sub_union_set->larger_than($out_span) ) {
                            $complex_region->merge($sub_union_set);
                        }
                    }
                }
            }

            # record complex indel info to $info{$outgroup}
            $info_of{$outgroup}->{complex} = $complex_region->runlist();

            # record all ingroup indel info to $info{$outgroup}
            $info_of{$outgroup}->{all_indel} = $all_indel_region->runlist();
        }

        #----------------------------------------------------------#
        # output a fasta alignment for further use
        #----------------------------------------------------------#
        if ($trimmed_fasta) {
            unless ( -e $goal_db ) {
                mkdir $goal_db, 0777
                    or die "Cannot create \"$goal_db\" directory: $!";
            }
            my $first_taxon_id = $info_of{ $all_names[1] }->{taxon_id};
            my $outfile
                = "$goal_db/"
                . "id$first_taxon_id" . "_"
                . $chr_name . "_"
                . $seg_start . "_"
                . $seg_end . ".fas";
            print " " x 4, "$outfile\n";
            open my $out_fh, '>', $outfile
                or die("Cannot open OUT file $outfile");
            foreach my $name (@all_names) {
                my $seq = $info_of{$name}->{seqs};
                print {$out_fh} ">", $info_of{$name}->{name}, "\n";
                print {$out_fh} $seq, "\n";
            }
            close $out_fh;
        }

        if ( !$no_insert ) {
            my @align_ids;
            my $combinat = Math::Combinatorics->new(
                count => 2,
                data  => \@ingroup_names,
            );
            while ( my @combo = $combinat->next_combination ) {
                @combo = sort { $ingroup_order{$a} <=> $ingroup_order{$b} }
                    @combo;
                my ( $tname, $qname ) = @combo;
                print "insert $tname $qname\n";
                my $cur_align_id
                    = $goal_obj->add_align( $info_of{$tname},
                    $info_of{$qname}, $info_of{$outgroup},
                    $info_of{$outgroup}->{all_indel} );
                push @align_ids, $cur_align_id;
            }
        }
    }
}

$stopwatch->end_message();

# store program running meta info to database
END {
    if ( !$no_insert ) {
        $goal_obj->add_meta_stopwatch($stopwatch);
    }
}
exit;

sub build_chr_set {
    my $dbh        = shift;
    my $chr_id     = shift;
    my $reduce_end = shift || 0;

    my $chr_set = AlignDB::IntSpan->new();

    my $chr_query = qq{
        SELECT  s.chr_start + $reduce_end,
                s.chr_end - $reduce_end
        FROM sequence s, chromosome c
        WHERE c.chr_id = ?
        AND s.chr_id = c.chr_id
    };

    # build $chr_set
    my $chr_sth = $dbh->prepare($chr_query);
    $chr_sth->execute($chr_id);
    while ( my @row = $chr_sth->fetchrow_array ) {
        my ( $chr_start, $chr_end ) = @row;
        next if $chr_start > $chr_end;
        $chr_set->add_range( $chr_start, $chr_end );
    }

    return $chr_set;
}

__END__

=head1 NAME

    ref_outgroup.pl - three-lineage test

=head1 SYNOPSIS

    ref_outgroup.pl [options]
        Options:
            --help              brief help message
            --man               full documentation
            --server            MySQL server IP/Domain name
            --port              MySQL server port
            --username          username
            --password          password
            --insert_gc         do GC related processes
            --insert_dG         do deltaG related processes
            --insert_segment    do segment related processes
            --first_db            aim database name
            --second_db            ref database name
            --goal_db           goal database name
            --outgroup          outgroup name (second_query)
            --target            target name (first_target)
            --query             query name (first_query)
            --length            threshold of alignment length
            --realign           correct pesudo-alignment error
            --raw_fasta         save raw fasta files
            --trimmed_fasta     save ref-trimmed fasta files
            --reduce_end        reduce align end to avoid some overlaps in
                                  BlastZ results (use 10 instead of 0)
                                For two independent datasets, use 10;
                                for two dependent datasets, use 0
            --chr_id_runlist    runlist of chr_id 

$ perl ref_outgroup.pl --first_db=S288CvsRM11 --second_db=S288CvsYJM789 \
--third_db=S288CvsSpar --goal_db=S288CvsSix --no_insert=1 --trimmed_fasta=1 \
--third=1query --outgroup=2query --forth_db=S288CvsSK1 --fifth_db=S288CvsY55 \
--sixth_db=S288CvsDBVPG6765

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
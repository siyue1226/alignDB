package AlignDB::Ofg;
use Moose;
use Carp;

use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use YAML qw(Dump Load DumpFile LoadFile);

use AlignDB::IntSpan;
use AlignDB::Window;

use FindBin;
use lib "$FindBin::Bin/..";
extends qw(AlignDB);
use AlignDB::Position;
use AlignDB::Stopwatch;
use AlignDB::Util qw(:all);

use version; our $VERSION = qv('0.1.0');

# max outside window distance
has 'max_out_distance' => (
    is      => 'rw',
    isa     => 'Int',
    default => 30,
);

# max inside window distance
has 'max_in_distance' => (
    is      => 'rw',
    isa     => 'Int',
    default => 30,
);

has 'window_maker' => ( is => 'ro', isa => 'object' );
has 'pos_finder'   => ( is => 'ro', isa => 'object' );

sub BUILD {
    my $self = shift;

    my $window_maker = AlignDB::Window->new(
        max_out_distance => $self->max_out_distance,
        max_in_distance  => $self->max_in_distance,
    );

    my $dbh = $self->dbh;
    my $pos_finder = AlignDB::Position->new( dbh => $dbh );

    $self->{window_maker} = $window_maker;
    $self->{pos_finder}   = $pos_finder;

    return;
}

sub empty_ofg_tables {
    my $self = shift;

    $self->empty_table( 'ofg',   'with_window' );
    $self->empty_table( 'ofgsw', 'with_window' );

    return;
}

sub align_seq {
    my $self     = shift;
    my $align_id = shift;

    my $dbh = $self->dbh;

    # alignments' chromosomal location, target_seq and query_seq
    my $align_seq_sth = $dbh->prepare(
        q{
        SELECT c.chr_name,
               a.align_length,
               s.chr_start,
               s.chr_end,
               t.target_seq,
               t.target_runlist,
               q.query_seq
        FROM align a, target t, query q, sequence s, chromosome c
        WHERE a.align_id = t.align_id
        AND t.seq_id = s.seq_id
        AND a.align_id = q.align_id
        AND s.chr_id = c.chr_id
        AND a.align_id = ?
        }
    );
    $align_seq_sth->execute($align_id);

    return $align_seq_sth->fetchrow_array;
}

sub insert_ofg {
    my $self        = shift;
    my $align_ids   = shift;
    my $all_ofgs    = shift;
    my $chr_ofg_set = shift;

    my $dbh        = $self->dbh;
    my $pos_finder = $self->pos_finder;

    # insert into ofg
    my $ofg_insert_sth = $dbh->prepare(
        q{
        INSERT INTO ofg (
            ofg_id, window_id, ofg_tag, ofg_type
        )
        VALUES (
            NULL, ?, ?, ?
        )
        }
    );

    # for each alignment
    for my $align_id (@$align_ids) {
        my ($chr_name,   $align_length,   $chr_start, $chr_end,
            $target_seq, $target_runlist, $query_seq
        ) = $self->align_seq($align_id);

        next if $chr_name =~ /rand|un|contig|hap|scaf/i;

        print "Prosess align $align_id in $chr_name $chr_start - $chr_end\n";

        $chr_name =~ s/chr0?//i;
        my $chr_set = AlignDB::IntSpan->new("$chr_start-$chr_end");

        # chr_ofg_set has intersect with chr_set
        #   ? there are ofgs in this alignmet
        #   : there is no ofg
        next if $chr_ofg_set->{$chr_name}->intersect($chr_set)->is_empty;
        my @align_ofg;
        for (@$all_ofgs) {
            next if $_->{chr} ne $chr_name;
            my $iset = $_->{set}->intersect($chr_set);
            if ( $iset->is_not_empty ) {
                print ' ' x 4, "Find ofg: $iset\n";
                push @align_ofg,
                    { set => $iset, tag => $_->{tag}, type => $_->{type} };
            }
        }
        if ( @align_ofg == 0 ) {
            warn "Match wrong gce positions\n";
            next;
        }

        # target runlist
        my $target_set = AlignDB::IntSpan->new($target_runlist);

        # insert internal indels, that are, indels in target_set
        # indels in query_set is equal to spans of target_set minus one
        my $internal_indel_flag = 1;

        #----------------------------#
        # INSERT INTO ofg
        #----------------------------#
        foreach my $ofg (@align_ofg) {
            my $ofg_set  = $ofg->{set};
            my $ofg_tag  = $ofg->{tag};
            my $ofg_type = $ofg->{type};

            # ofg position set
            my $ofg_start = $pos_finder->at_align( $align_id, $ofg_set->min );
            my $ofg_end   = $pos_finder->at_align( $align_id, $ofg_set->max );
            next if $ofg_start >= $ofg_end;
            $ofg_set   = AlignDB::IntSpan->new("$ofg_start-$ofg_end");
            $ofg_set   = $ofg_set->intersect($target_set);
            $ofg_start = $ofg_set->min;
            $ofg_end   = $ofg_set->max;

            # window
            my ($cur_window_id)
                = $self->insert_window( $align_id, $ofg_set,
                $internal_indel_flag );

            # insert to table
            $ofg_insert_sth->execute( $cur_window_id, $ofg_tag, $ofg_type );
        }

        #----------------------------#
        # INSERT INTO ofgsw
        #----------------------------#
        $self->insert_ofgsw($align_id);
    }

    return;
}

sub insert_ofgsw {
    my $self     = shift;
    my $align_id = shift;

    my $dbh          = $self->dbh;
    my $window_maker = $self->window_maker;

    my ($chr_name,   $align_length,   $chr_start, $chr_end,
        $target_seq, $target_runlist, $query_seq
    ) = $self->align_seq($align_id);

    # target runlist
    my $target_set = AlignDB::IntSpan->new($target_runlist);

    # insert internal indels, that are, indels in target_set
    # indels in query_set is equal to spans of target_set minus one
    my $internal_indel_flag = 1;

    # ofg_id
    my $fetch_ofg_id = $dbh->prepare(
        q{
        SELECT ofg_id
          FROM ofg o, window w
         WHERE o.window_id = w.window_id
           AND w.align_id = ?
        }
    );
    $fetch_ofg_id->execute($align_id);

    # ofg_info
    my $fetch_ofg_info = $dbh->prepare(
        q{
        SELECT w.window_runlist
          FROM ofg o, window w
         WHERE o.window_id = w.window_id
           AND o.ofg_id = ?
        }
    );

    # prepare ofgsw_insert
    my $ofgsw_insert = $dbh->prepare(
        q{
        INSERT INTO ofgsw (
            ofgsw_id, window_id, ofg_id,
            ofgsw_type, ofgsw_distance
        )
        VALUES (
            NULL, ?, ?,
            ?, ?
        )
        }
    );

    my $ofgsw_size = $window_maker->sw_size;

    while ( my ($ofg_id) = $fetch_ofg_id->fetchrow_array ) {

        $fetch_ofg_info->execute($ofg_id);
        my ($ofg_runlist) = $fetch_ofg_info->fetchrow_array;
        my $ofg_set = AlignDB::IntSpan->new($ofg_runlist);

        # outside rsw
        my @out_rsw
            = $window_maker->outside_window( $target_set, $ofg_set->min,
            $ofg_set->max );

        foreach my $outside_rsw (@out_rsw) {
            my ($cur_window_id)
                = $self->insert_window( $align_id, $outside_rsw->{set},
                $internal_indel_flag );

            $ofgsw_insert->execute( $cur_window_id, $ofg_id,
                $outside_rsw->{type}, $outside_rsw->{distance},
            );
        }

        # inside rsw
        my @in_rsw = $window_maker->inside_window( $target_set, $ofg_set->min,
            $ofg_set->max );

        foreach my $inside_rsw (@in_rsw) {
            my ($cur_window_id)
                = $self->insert_window( $align_id, $inside_rsw->{set},
                $internal_indel_flag );

            $ofgsw_insert->execute( $cur_window_id, $ofg_id,
                $inside_rsw->{type}, $inside_rsw->{distance},
            );
        }

        # inside rsw 2
        my @in_rsw2
            = $window_maker->inside_window2( $target_set, $ofg_set->min,
            $ofg_set->max );

        foreach my $inside_rsw (@in_rsw2) {
            my ($cur_window_id)
                = $self->insert_window( $align_id, $inside_rsw->{set},
                $internal_indel_flag );

            $ofgsw_insert->execute( $cur_window_id, $ofg_id,
                $inside_rsw->{type}, $inside_rsw->{distance},
            );
        }
    }

    return;
}

1;

__END__
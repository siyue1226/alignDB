#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Config::Tiny;
use YAML qw(Dump Load DumpFile LoadFile);

use Archive::Extract;
use File::Spec::Functions qw(rel2abs);
use File::Find::Rule;

use FindBin;
use AlignDB::Stopwatch;

#----------------------------------------------------------#
# GetOpt section
#----------------------------------------------------------#
my $Config = Config::Tiny->new;
$Config = Config::Tiny->read("$FindBin::Bin/../alignDB.ini");

# Database init values
my $server   = $Config->{database}->{server};
my $port     = $Config->{database}->{port};
my $username = $Config->{database}->{username};
my $password = $Config->{database}->{password};

my $do_checksum = 0;
my $do_init_db  = 1;

my $db          = "test";
my $ensembl_dir = q{F:/Downloads/human_48/};

my $man  = 0;
my $help = 0;

GetOptions(
    'help|?'     => \$help,
    'man'        => \$man,
    'server=s'   => \$server,
    'port=i'     => \$port,
    'username=s' => \$username,
    'password=s' => \$password,
    'db=s'       => \$db,
    'ensembl=s'  => \$ensembl_dir,
    'checksum=s' => \$do_checksum,
    'init_db=s'  => \$do_init_db,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

#----------------------------------------------------------#
# run
#----------------------------------------------------------#
my $stopwatch = AlignDB::Stopwatch->new;
$stopwatch->start_message("Build ensembl $db...");

if ($do_checksum) {

    #----------------------------#
    # checksum
    #----------------------------#
    print "Now checksums...\n";

    # Read in CHECKSUMS file
    my $sum_file    = rel2abs( "CHECKSUMS",     $ensembl_dir );
    my $sum_gz_file = rel2abs( q{CHECKSUMS.gz}, $ensembl_dir );
    if ( -e $sum_file ) {

        # just OK
    }
    elsif ( -e $sum_gz_file ) {

        # create an archive object
        my $archive = Archive::Extract->new( archive => $sum_gz_file, );
        $archive->extract( to => $ensembl_dir )
            or die "Can't extract: " . $archive->error;
        ($sum_file) = @{ $archive->files };
        $sum_file = rel2abs( $sum_file, $archive->extract_path );
    }
    else {
        $stopwatch->block_message( "NO Checksum file", 1 );
        exit;
    }

    my %checksum_of;
    open my $sum_fh, '<', $sum_file;
    while (<$sum_fh>) {
        chomp;
        my ( $checksum_value, $block_count, $filename ) = split /\s+/;
        $checksum_of{$filename} = $checksum_value;
    }

    my $checksum_error = 0;
    foreach my $file ( sort keys %checksum_of ) {
        my $abs_file = rel2abs( $file, $ensembl_dir );
        if ( !-e $abs_file ) {
            print "$file: file does not exist\n";
            $checksum_error++;
            next;
        }
        my $sum_output = `sum $abs_file`;
        my $run_sum_ok = $sum_output =~ m{^(\d+)\s+\d+\s+};
        my $actual_sum = $1;
        if ( !$run_sum_ok ) {
            print "$file: run checksum error\n";
            $checksum_error++;
        }
        elsif ( $actual_sum != $checksum_of{$file} ) {
            print "$file: wrong checksum value\n";
            $checksum_error++;
        }
        else {
            print "$file: checksum OK\n";
        }
    }

    if ( !$checksum_error ) {
        $stopwatch->block_message( "Checksum OK", 1 );
    }
    else {
        $stopwatch->block_message(
            "Checksum ERROR in $checksum_error file(s)", 1 );
    }
}
else {

    #----------------------------#
    # init database
    #----------------------------#
    if ($do_init_db) {

        # Ingore mysql 4.0 compatible file
        my @sql_files
            = File::Find::Rule->file->name('*.sql.gz')->in($ensembl_dir);
        my ($sql_file) = grep { $_ !~ /mysql40/ } @sql_files;
        if ( !$sql_file ) {
            die "Can not find the SQL file\n";
        }

        # create an archive object
        my $archive = Archive::Extract->new( archive => $sql_file, );
        $archive->extract( to => $ensembl_dir )
            or die "Can't extract: " . $archive->error;
        ($sql_file) = @{ $archive->files };
        $sql_file = rel2abs( $sql_file, $archive->extract_path );

        $stopwatch->block_message("SQL file: $sql_file");

        my $cmd    = "mysql -h$server -P$port -u$username -p$password ";
        my $drop   = "-e \"DROP DATABASE IF EXISTS $db;\"";
        my $create = "-e \"CREATE DATABASE $db;\"";

        print "#drop\n" . "$cmd $drop\n";
        system("$cmd $drop");
        print "#create\n" . "$cmd $create\n";
        system("$cmd $create");
        print "#init\n" . "$cmd $db < $sql_file\n";
        system("$cmd $db < $sql_file");
    }

    #----------------------------#
    # import into database
    #----------------------------#
    $stopwatch->block_message("import to $db");

    # ensembl has changed their naming rules
    my @table_files
        = File::Find::Rule->file->name( '*.txt.table.gz', '*.txt.gz' )
        ->in($ensembl_dir);

    foreach my $table_file ( sort @table_files ) {
        my $archive = Archive::Extract->new( archive => $table_file, );
        $archive->extract( to => $ensembl_dir )
            or die "Can't extract: " . $archive->error;
        my ($abs_table_file) = @{ $archive->files };
        $abs_table_file = rel2abs( $abs_table_file, $archive->extract_path );

        my $cmd
            = "mysqlimport -h$server -P$port -u$username -p$password --local";
        system("$cmd $db $abs_table_file");

        unlink $abs_table_file;
    }
}

$stopwatch->end_message;

__END__
    
=head1 NAME

    build_ensembl.pl - Build an ensembl database from mysqldump files

=head1 SYNOPSIS

    perl build_ensembl.pl [options]
      Options:
        --help          brief help message
        --man           full documentation
        --server        MySQL server IP/Domain name
        --port          MySQL server port
        --db            ensembl database name
        --username      username
        --password      password
        --checksum      do checksum
        --ensembl       dir stored ensembl mysqldump files
        --init_db       do init database

    # run the following command to check the downloaded files
    perl build_ensembl.pl --checksum=1
    
    # run the following command to build ensembl database
    perl build_ensembl.pl --db=human_48 --init_db=1 --ensembl=human_48/

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<build_ensembl.pl> will build an ensembl database from mysqldump files.

=cut
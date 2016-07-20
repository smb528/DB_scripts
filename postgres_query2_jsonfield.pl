#!/usr/bin/perl

use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;
use List::MoreUtils qw(first_index);

our ($opt_H, $opt_D, $opt_p, $opt_m, $opt_n, $opt_f);

getopts('H:D:p:m:n:f:');

if (!$opt_H || !$opt_D || !$opt_p || !$opt_m || !$opt_f || !$opt_n) {
    die "Must provide options -H (hostname), -D (database name), -p (db user password), -m (protocol name), -n (num reps), -f (out filename) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $protocol_name = $opt_m;
my $num_reps = $opt_n;
my $out_file = $opt_f;


my $start = Time::HiRes::time();

my $driver = "Pg";
my $dsn = "DBI:$driver:dbname=$dbname;host=$dbhost;port=5432";
my $userid = "postgres";
my $password = $dbpass;
my $dbh = DBI->connect($dsn,$userid, $password, {RaiseError => 1}) or die $DBI::errstr;

print "Opened database successfully\n";

open(my $fh, '>', $out_file);
print $fh "Stock ID, Number Deletions, Time\n";
my $start = Time::HiRes::time();

for (1..$num_reps) {

    my $n_start = Time::HiRes::time();
    #Get List of all Stocks that were genotyped using the protocol given.
    my $sth_stock = $dbh->prepare("SELECT stock.stock_id from stock join nd_experiment_stock using(stock_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) where nd_protocol.name = ?;");
        #or die "Couldn't prepare statement: " . $dbh->errstr;

    $sth_stock->execute($protocol_name);

    #Get List of markers that contain a '-' in ALT.
    my $sth_markers = $dbh->prepare("SELECT kv.key, kv.value->>'alt' from nd_protocol join nd_protocolprop AS a using(nd_protocol_id), json_each(a.value) kv WHERE nd_protocol.name = ? and kv.value::text LIKE '%-%';");
        #or die "Couldn't prepare statement: ".$dbh->errstr;

    $sth_markers->execute($protocol_name);

    my %del_markers;
    while (my ($marker, $alt) = $sth_markers->fetchrow_array) {
        $del_markers{$marker} = $alt;
    }

    #Count markers where GT is not 0/0 for an individual stock.
    my $sth_geno = $dbh->prepare("select kv.key, kv.value->>'GT' from stock join nd_experiment_stock using(stock_id) join nd_experiment_genotype using(nd_experiment_id) join genotype using(genotype_id) join genotypeprop AS a using(genotype_id), json_each(a.value) kv WHERE stock.stock_id = ? and not kv.value::text LIKE '%0/0%' and not kv.value::text LIKE '%./.%';")
    or die "Couldn't prepare statement: " . $dbh->errstr;

    #Loop over the list of stocks that we found.
    while (my $stock_id = $sth_stock->fetchrow_array) {

        my $deletion_count = 0;

        $sth_geno->execute($stock_id);

        while (my ($marker, $geno) = $sth_geno->fetchrow_array()) {

            if (exists $del_markers{$marker}) {
                my $alt = $del_markers{$marker};

                my @alt_array = split /,/, $alt;
                #print Dumper \@alt_array;

                my $del_index = (first_index { $_ eq '-' } @alt_array) + 1;

                if($geno =~ /$del_index/) {
                    $deletion_count++;
                }
                #else {
                #    $nondeletion_count++;
                #}

                #$mutations_count++;
            }
        }

        #print "DELETIONS: ".$deletion_count."\n";
        my $n_end = Time::HiRes::time();
        my $n_duration = $n_end - $n_start;
        #print "T: ".$n_duration."\n";

        print $fh "$stock_id, $deletion_count, $n_duration\n";
    }

}

close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;

print Dumper "Time: ".$duration;

#!/usr/bin/perl

use DBI;

use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;
use List::MoreUtils qw(first_index);

our ($opt_H, $opt_D, $opt_p, $opt_m, $opt_c, $opt_n, $opt_f, $opt_l);

getopts('H:D:p:m:n:f:c:l:');

if (!$opt_H || !$opt_D || !$opt_p || !$opt_m || !$opt_n || !$opt_f || (!$opt_c && !$opt_l)) {
    die "Must provide options -H (hostname), -D (database name), -p (db user password), -m (protocol name), -n (num reps), -f (out filename), -c (num markers to select), -l (OPTIONAL: list of markers to search over. Overrides -c) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $protocol_name = $opt_m;
my $num_markers = $opt_c;
my $num_reps = $opt_n;
my $out_file = $opt_f;
my @selected_markers;
if ($opt_l) {
    @selected_markers = split /,/, $opt_l;
}


my $start = Time::HiRes::time();
my $driver = "Pg";
my $dsn = "DBI:$driver:dbname=$dbname;host=$dbhost;port=5432";
my $userid = "postgres";
my $password = $dbpass;
my $dbh = DBI->connect($dsn,$userid, $password, {RaiseError => 1}) or die $DBI::errstr;
		       print "Opened database successfully\n";
open(my $fh, '>', $out_file);
print $fh "Run\tResult\tTime\n";

my $json = JSON->new();

my @marker_names;
if (!$opt_l) {

    my $sth = $dbh->prepare('select kv.key from nd_protocol join nd_protocolprop AS a using(nd_protocol_id), jsonb_each(a.value) AS kv where nd_protocol.name = ? ');
        #or die "Couldn't prepare statement: " . $dbh->errstr;

    $sth->execute($protocol_name);

    while (my $marker = $sth->fetchrow_array) {
        push @marker_names, $marker;
    }
}

for my $run (1..$num_reps) {

    if (!$opt_l) {
        @selected_markers = ();
        my @randomly_select_markers;
        for (1..$num_markers) {
            push @selected_markers, $marker_names[int rand(scalar(@marker_names))];
        }
    }
    #print Dumper \@selected_markers;

    my %selected_markers = map { $_ => 1 } @selected_markers;


    my $n_start = Time::HiRes::time();

    #Get List of all Stocks that were genotyped using the protocol given.
    my $sth_stock = $dbh->prepare("SELECT stock.stock_id from stock join nd_experiment_stock using(stock_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) where nd_protocol.name = ?;");
        #or die "Couldn't prepare statement: " . $dbh->errstr;

    $sth_stock->execute($protocol_name);

    #Selecting markers where GT is not 0/0 or ./. for an individual stock.
    my $sth_geno = $dbh->prepare("select kv.key from stock join nd_experiment_stock using(stock_id) join nd_experiment_genotype using(nd_experiment_id) join genotype using(genotype_id) join genotypeprop AS a using(genotype_id), jsonb_each(a.value) kv WHERE stock.stock_id = ? and not kv.value @> ? and not kv.value @> ?;");
        #or die "Couldn't prepare statement: " . $dbh->errstr;

    my @accessions_with_mutations;
    #Loop over the list of stocks that we found.
    while (my $stock_id = $sth_stock->fetchrow_array) {

        $sth_geno->execute($stock_id, '{"GT":"0/0"}', '{"GT":"./."}');

        my $mutations_count=0;
        while (my ($marker) = $sth_geno->fetchrow_array()) {
            if (exists($selected_markers{$marker})) {
                $mutations_count++;
            }
        }

        if ($mutations_count == scalar(@selected_markers)) {
            push @accessions_with_mutations, $stock_id;
        }
    }

    # print Dumper \@accessions_with_mutations;
    #print join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\n";
    my $n_end = Time::HiRes::time();
    my $n_duration = $n_end - $n_start;

    print $fh  $run."\t".join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\t".$n_duration."\n";

}

close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;
print "Time: ".$duration."\n";

#!/usr/bin/perl


use MongoDB;
use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;

our ($opt_H, $opt_D, $opt_m, $opt_n, $opt_f);

getopts('H:D:m:n:f:');

if (!$opt_H || !$opt_D || !$opt_m || !$opt_n || !$opt_f) {
    die "Must provide options -H (hostname), -D (database name), -m (protocol name), -n (num reps), -f (out filename) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $protocol_name = $opt_m;
my $num_reps = $opt_n;
my $out_file = $opt_f;

my $start = Time::HiRes::time();

open(my $fh, '>', $out_file);
print $fh "Run, Accession Name, Number Mutations, Time\n";

my $json = JSON->new();

for my $run (1..$num_reps) {
    my $client = MongoDB-> connect($dbhost);
    my $db = $client-> get_database($dbname);
    my $accession_collection = $db->get_collection('accession_collection');
    my $genotype_collection = $db->get_collection('genotype_collection');

    my $accession_cursor = $accession_collection->find({protocol_name => $protocol_name} );

    while(my $row = $accession_cursor->next){
        my $n_start = Time::HiRes::time();

        my $accession_name = $row->{'accession_name'};

        my $mutations_count = $genotype_collection->count({protocol_name => $protocol_name, accession_name=>$accession_name, 'marker_score.GT' => {'$nin' => ["0/0", "./."] } } );

        my $n_end = Time::HiRes::time();
        my $n_duration = $n_end-$n_start;
        print $fh "$run, $accession_name, $mutations_count, $n_duration\n";

    }
}

close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;

print Dumper "Time: ".$duration;

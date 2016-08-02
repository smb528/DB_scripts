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

my $client = MongoDB-> connect($dbhost);
my $db = $client-> get_database($dbname);
my $genotype_collection = $db->get_collection('genotype_collection');

open(my $fh, '>', $out_file);
print $fh "Run, Stock ID, Number Mutations, Time\n";

my $json = JSON->new();

for my $run (1..$num_reps) {
    my $n_start = Time::HiRes::time();

    my $cursor = $genotype_collection->find({protocol_name => $protocol_name});

    my %accession_mutations;

    while(my $row = $cursor->next){

        my $marker_score = $row->{'marker_score'};
        my $accession_name = $row->{'accession_name'};
        #print Dumper $marker_score;

        my $mutations_count = 1;
        #my $ref_count = 1;
        #my $bad_quality = 1;

        my $GT = $marker_score->{'GT'};
        #print $GT."\n";

        if ($GT ne '0/0' && $GT ne './.') {
            $accession_mutations{$accession_name}++;
        }

    }
    #print Dumper \%accession_mutations;

    #print "BAD COUNT: ".$bad_quality."\n";
    #print "MUTATIONS COUNT: ".$mutations_count."\n";
    #print "REF COUNT: ".$ref_count."\n\n";
    my $n_end = Time::HiRes::time();
    my $n_duration = $n_end-$n_start;
    #foreach my $accession_name (keys %accession_mutations) {
    #  print $fh "$run, $accession_name, $accession_mutations{$accession_name}, $n_duration\n";
    #}
    print $fh "$run,".Dumper \%accession_mutations.",$n_duration\n";

}

close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;

print Dumper "Time: ".$duration;

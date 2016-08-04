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
print $fh "Run Number, Stock ID, Number Mutations, Time\n";

my $json = JSON->new();

for my $run (1..$num_reps) {


    my $cursor = $genotype_collection->find({protocol_name => $protocol_name});

    while(my $row = $cursor->next){
        my $n_start = Time::HiRes::time();
        my $marker_scores = $row->{'marker_scores'};
        my $stock_id = $row->{'stock_id'};

        my $mutations_count = 1;
        #my $ref_count = 1;
        #my $bad_quality = 1;

        my $json_value = $json->decode($marker_scores);
        #print Dumper $json_value;

        foreach my $marker (keys %$json_value) {
          my $GT = $json_value->{$marker}->{'GT'};
          #my $GQ = $json_value->{$marker}->{'GQ'};

          if ($GT ne '0/0' && $GT ne './.') {
            $mutations_count++;
          }
          #else {
            #$ref_count++;
          #}

      #if ($GQ > 90) {
    	#    if ($GT ne '0/0') {
    	#	$mutations_count++;
    	#    } else {
    	#	$ref_count++;
    	#    }
    	#} else {
    	#    $bad_quality++;
    	#}
        }

        #print "BAD COUNT: ".$bad_quality."\n";
        #print "MUTATIONS COUNT: ".$mutations_count."\n";
        #print "REF COUNT: ".$ref_count."\n\n";
        my $n_end = Time::HiRes::time();
        my $n_duration = $n_end - $n_start;
        #print "T: ".$n_duration."\n";

        print $fh "$run,$stock_id, $mutations_count, $n_duration\n";

    }
}

close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;

print Dumper "Time: ".$duration;

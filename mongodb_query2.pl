#!/usr/bin/perl


use MongoDB;
use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;
use List::MoreUtils qw(first_index);

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

#my $start = Time::HiRes::time();

my $client = MongoDB-> connect($dbhost);
my $db = $client-> get_database($dbname);
my $genotype_collection = $db->get_collection('genotype_collection');
my $protocol_collection = $db->get_collection('protocol_collection');
open(my $fh, '>', $out_file);
print $fh "Stock ID, Number Mutations, Time\n";

my $json = JSON->new();

for (1..$num_reps) {
    my $n_start = Time::HiRes::time();
    #get json string for protocolprop and genotypeprop for an individual stock that was genotyped using the given protocol name
    #my $sth = db.genotype_collection.aggregate([
    #    {"$unwind": "protocol_collection" },
    #    {
    #        "$lookup":
    #        {
    #        "from": "protocol_collection",
    #        "localField": "alt",
    #        "foreignField": "GT",
    #        "as": "joined_genotype_alternate"
    #    }},

    #    {"$unwind": "joined_genotype_alternate"},

    #    {"$group": {
    #        "_id":"$_id",
    #        "protocol_collection": {"$push"}
    #    }}
    # }])

    my $protocol_cursor = $protocol_collection->find({protocol_name => $protocol_name});

    my %del_markers;
    while(my $row = $protocol_cursor->next){
        my $marker_string_json = $row->{'markers'};
        my $marker_hash = $json->decode($marker_string_json);


        foreach my $marker (keys %$marker_hash) {
            my $alt = $marker_hash->{$marker}->{'alt'};
            if ($alt =~ /-/) {
                $del_markers{$marker} = $alt;
            }
        }
    }

    my $genotype_cursor = $genotype_collection->find({protocol_name => $protocol_name});

    while(my $row = $genotype_cursor->next){

        my $deletion_count = 0;

        my $marker_scores_json = $row->{'marker_scores'};
        my $marker_score_hash = $json->decode($marker_scores_json);

        foreach my $marker (keys %$marker_score_hash) {

            my $GT = $marker_score_hash->{$marker}->{'GT'};

            if ($GT ne '0/0' && $GT ne './.' && exists($del_markers{$marker} ) ) {

                my $alt = $del_markers{$marker};
            	my @alt_array = split /,/, $alt;
            	#print Dumper \@alt_array;

            	my $del_index = (first_index { $_ eq '-' } @alt_array) + 1;

            	if($GT =~ /$del_index/) {
            		 $deletion_count++;
            	}
            }
        }

        #print "DEL: ".$deletion_count."\n";
        my $n_end = Time::HiRes::time();
        my $n_duration = $n_end - $n_start;
        #print "T: ".$n_duration."\n";

        print $fh "$row->{'stock_id'}, $deletion_count, $n_duration\n";

    }
}
close $fh;

#my $end = Time::HiRes::time();
#my $duration = $end - $start;
#print "Time: ".$duration."\n";

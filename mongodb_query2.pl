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
print $fh "Run, Stock ID and Number Mutations, Time\n";


for my $run (1..$num_reps) {
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

    #my %unique_alts;
    my %del_markers;
    while(my $row = $protocol_cursor->next){
        my $marker_name = $row->{'marker_name'};
        my $marker_info = $row->{'marker_info'};
        #print Dumper $marker_info;
        my $alt = $marker_info->{'alt'};
        #print $alt."\n";
        #$unique_alts{$alt} =1;
        if ($alt =~ /-/) {
            $del_markers{$marker_name} = $alt;
        }
    }
    #print Dumper \%unique_alts;
    #print Dumper \%del_markers;

    my $genotype_cursor = $genotype_collection->find({protocol_name => $protocol_name});

    my %accession_deletions;

    while(my $row = $genotype_cursor->next){

        my $deletion_count = 0;

        my $accession_name = $row->{'accession_name'};
        my $marker_score = $row->{'marker_score'};
        my $marker_name = $row->{'marker_name'};

        my $GT = $marker_score->{'GT'};

        if ($GT ne '0/0' && $GT ne './.' && exists($del_markers{$marker_name} ) ) {

            my $alt = $del_markers{$marker_name};
            my @alt_array = split /,/, $alt;
            #print Dumper \@alt_array;

            my $del_index = (first_index { $_ eq '-' } @alt_array) + 1;

            if($GT =~ /$del_index/) {
                $accession_deletions{$accession_name}++;
            }
        }
    }

    my $n_end = Time::HiRes::time();
    my $n_duration = $n_end-$n_start;
    #foreach my $accession (keys %accession_deletions) {
    #    print $fh "$accession, $accession_deletions{$accession}\n";
    #}
    print $fh "$run,".Dumper $accession_deletions.",$n_duration\n";
}
close $fh;

#my $end = Time::HiRes::time();
#my $duration = $end - $start;
#print "Time: ".$duration."\n";

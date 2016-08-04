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

my $start = Time::HiRes::time();

open(my $fh, '>', $out_file);
print $fh "Run, Accession Name, Number Mutations, Time\n";


for my $run (1..$num_reps) {
    my $n_connection_start = Time::HiRes::time();

    my $client = MongoDB-> connect($dbhost);
    my $db = $client-> get_database($dbname);
    my $accession_collection = $db->get_collection('accession_collection');
    my $genotype_collection = $db->get_collection('genotype_collection');
    my $protocol_collection = $db->get_collection('protocol_collection');

    my $n_connection_end = Time::HiRes::time();
    my $n_connection_duration = $n_connection_end - $n_connection_start;

    my $protocol_cursor = $protocol_collection->find({protocol_name => $protocol_name, "marker_info.alt" => { '$regex' => '-' } } );

    #my %unique_alts;
    my %del_markers;
    my @del_markers;
    while(my $row = $protocol_cursor->next){
        my $marker_name = $row->{'marker_name'};
        my $marker_info = $row->{'marker_info'};
        #print Dumper $marker_info;
        my $alt = $marker_info->{'alt'};
        #print $alt."\n";
        #$unique_alts{$alt} =1;
        $del_markers{$marker_name} = $alt;
        push @del_markers, $marker_name;
    }
    #print Dumper \%unique_alts;
    #print Dumper \%del_markers;

    my $accession_cursor = $accession_collection->find({protocol_name => $protocol_name} );

    while(my $row = $accession_cursor->next){
        my $n_start = Time::HiRes::time();

        my $accession_name = $row->{'accession_name'};

        my $genotype_cursor = $genotype_collection->find({protocol_name => $protocol_name, accession_name=>$accession_name, 'marker_score.GT' => {'$nin' => ["0/0", "./."] }, marker_name=> {'$in' => \@del_markers} });

        my $deletion_count = 0;

        while(my $row = $genotype_cursor->next){

            my $accession_name = $row->{'accession_name'};
            my $marker_score = $row->{'marker_score'};
            my $marker_name = $row->{'marker_name'};
            my $GT = $marker_score->{'GT'};

            my $alt = $del_markers{$marker_name};
            my @alt_array = split /,/, $alt;
            #print Dumper \@alt_array;

            my $del_index = (first_index { $_ eq '-' } @alt_array) + 1;

            if($GT =~ /$del_index/) {
                $deletion_count++;
            }
        }
        my $n_end = Time::HiRes::time();
        my $n_duration = $n_end-$n_start + $n_connection_duration;
        print $fh "$run,$accession_name,$deletion_count,$n_duration\n";
    }
}
close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;
print "Time: ".$duration."\n";

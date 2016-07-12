#!/usr/bin/perl



use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;
use List::MoreUtils qw(first_index);

our ($opt_H, $opt_D, $opt_p, $opt_m, $opt_c, $opt_n, $opt_f);

getopts('H:D:p:m:n:f:');

if (!$opt_H || !$opt_D || !$opt_p || !$opt_m || !$opt_n || !$opt_f) {
    die "Must provide options -H (hostname), -D (database name), -p (db user password), -m (protocol name), -n (num reps), -f (out filename) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $protocol_name = $opt_m;
my $count_deletion_in_either_chr = $opt_c || 0;
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
print $fh "Genotype ID, Number Mutations, Time\n";



my $json = JSON->new();

for (1..$num_reps) {

    #get json string for protocolprop and genotypeprop for an individual stock that was genotyped using the given protocol name
    my $sth = $dbh->prepare('select nd_protocolprop.value, genotypeprop.value, genotype.genotype_id from nd_experiment join nd_experiment_genotype using(nd_experiment_id) join genotype using(genotype_id) join genotypeprop using(genotype_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) join nd_protocolprop using(nd_protocol_id) where nd_protocol.name = ? ')
        or die "Couldn't prepare statement: " . $dbh->errstr;

    $sth->execute($protocol_name);

    my %unique_alts;

    while(my ($protocol_json, $genotype_json, $genotype_id) = $sth->fetchrow_array){
        my $n_start = Time::HiRes::time();

        my $deletion_count = 0;
        #my $nondeletion_count = 0;

        my $protocol_json_value = $json->decode($protocol_json);
        #print Dumper $protocol_json_value;
        my $genotype_json_value = $json->decode($genotype_json);
        #print Dumper $genotype_json_value;

        foreach my $marker (keys %$protocol_json_value ) {

        	my $alt = $protocol_json_value->{$marker}->{'alt'};
        	my $GT = $genotype_json_value->{$marker}->{'GT'};  ## '1/1', '1/3'
        	#my $GQ = $genotype_json_value->{$marker}->{'GQ'};

        	#print Dumper $alt;
        	#print Dumper $GT;

        	#$unique_alts{$alt} = $GT;

        	if ($alt =~ /-/ && $GT ne '0/0' && $GT ne './.') {

            	my @alt_array = split /,/, $alt;
            	#print Dumper \@alt_array;

            	my $del_index = (first_index { $_ eq '-' } @alt_array) + 1;

            	#if ($count_deletion_in_either_chr) {
                	if($GT =~ /$del_index/) {
                		 $deletion_count++;
                	}
                    #else {
                    #	$nondeletion_count++;
                    #}

                #}
                #else {
                    #my $del_mutation = "$del_index/$del_index";

                    #if ($GT eq $del_mutation) {
                    #   #print Dumper $del_mutation;
                    #   #print Dumper $GT;
                    #   $deletion_count++;
                    #}
                    #else {
                    #   #print Dumper $del_mutation;
                    #   #print Dumper $GT;
                    #   #$nondeletion_count++;
                    #}

                #}

        	}
            #else {
            #		$nondeletion_count++;
            #}

        }

        #print "NONDELETION COUNT: ".$nondeletion_count."\n";
        print "DEL: ".$deletion_count."\n";
        my $n_end = Time::HiRes::time();
        my $n_duration = $n_end - $n_start;
        print "T: ".$n_duration."\n";

        print $fh "$genotype_id, $deletion_count, $n_duration\n";
    }

    #print Dumper \%unique_alts;
}
close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;
print "Time: ".$duration."\n";

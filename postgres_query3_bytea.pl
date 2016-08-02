#!/usr/bin/perl



use DBI;
use strict;
#use Data::Dumper;
use Time::HiRes;
use Getopt::Std;
use List::MoreUtils qw(first_index);
use Storable qw(nfreeze thaw);

our ($opt_H, $opt_D, $opt_p, $opt_m, $opt_c, $opt_n, $opt_f, $opt_l);

getopts('H:D:p:m:n:f:c:l:');

if (!$opt_H || !$opt_D || !$opt_p || !$opt_m || !$opt_n || !$opt_f || (!$opt_c && !$opt_l)) {
    die "Must provide options -H (hostname), -D (database name), -p (db user password), -m (protocol name), -n (num reps), -f (out filename), -c (num markers to randomly select), -l (OPTIONAL: list of markers to search over. Overrides -c) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $protocol_name = $opt_m;
my $num_random_markers = $opt_c;
my $num_reps = $opt_n;
my $out_file = $opt_f;

my @selected_markers;
if ($opt_l) {
    @selected_markers = split /,/, $opt_l;
}
#print Dumper \@selected_markers;

#my $start = Time::HiRes::time();
my $driver = "Pg";
my $dsn = "DBI:$driver:dbname=$dbname;host=$dbhost;port=5432";
my $userid = "postgres";
my $password = $dbpass;
my $dbh = DBI->connect($dsn,$userid, $password, {RaiseError => 1}) or die $DBI::errstr;
		       print "Opened database successfully\n";
open(my $fh, '>', $out_file);
print $fh "Run\tResult\tTime\n";

my $sth = $dbh->prepare('select nd_protocolprop.value from nd_protocol join nd_protocolprop using(nd_protocol_id) where nd_protocol.name = ? ');

$sth->execute($protocol_name);

my @marker_names;
while (my $protocol_stored_value = $sth->fetchrow_array) {
    my $protocol_hash_ref = thaw($protocol_stored_value);
    foreach my $marker (keys $protocol_hash_ref) {
        push @marker_names, $marker;
    }
}

for my $run (1..$num_reps) {

    if (!$opt_l) {
        @selected_markers = ();

        for (1..$num_random_markers) {
            push @selected_markers, $marker_names[int rand(scalar(@marker_names))];
        }
    }

    my $n_start = Time::HiRes::time();

    my $sth = $dbh->prepare("select genotypeprop.value, genotype.genotype_id from nd_experiment join nd_experiment_genotype using(nd_experiment_id) join genotype using(genotype_id) join genotypeprop using(genotype_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) where nd_protocol.name = ?;");

    $sth->execute($protocol_name);

    my @accessions_with_mutations;
    my $num_selected_markers = scalar(@selected_markers);
    while(my ($genotypeprop, $genotype_id)=$sth->fetchrow_array){

        my $genotypeprop_hash_ref = thaw($genotypeprop);
        #print Dumper $genotypeprop_hash_ref;

        my $mutations_count=0;
        foreach my $marker (@selected_markers) {
            my $GT = $genotypeprop_hash_ref->{$marker}->{'GT'};
            #print $genotype_id."  ".$marker."  ".$GT."\n";

            if ($GT ne '0/0' && $GT ne './.') {
                #print $GT."\n";
                $mutations_count++;
           }
       }

       if ($mutations_count == $num_selected_markers) {
           push @accessions_with_mutations, $genotype_id;
       }
   }

   #print Dumper \@accessions_with_mutations;
   #print join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\n";
   my $n_end = Time::HiRes::time();
   my $n_duration = $n_end - $n_start;

   print $fh $run."\t".join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\t".$n_duration."\n";

}


close $fh;

#my $end = Time::HiRes::time();
#my $duration = $end - $start;
#print "Time: ".$duration."\n";

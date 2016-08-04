
use MongoDB;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;
use List::MoreUtils qw(first_index);

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

my $start = Time::HiRes::time();


open(my $fh, '>', $out_file);
print $fh "Run\tResult\tTime\n";


for my $run (1..$num_reps) {

    my $n_start = Time::HiRes::time();
    
    my $client = MongoDB-> connect($dbhost);
    my $db = $client-> get_database($dbname);
    my $accession_collection = $db->get_collection('accession_collection');
    my $genotype_collection = $db->get_collection('genotype_collection');
    my $protocol_collection = $db->get_collection('protocol_collection');

    my @marker_names;
    if (!$opt_l) {
        my $protocol_cursor = $protocol_collection->find({protocol_name => $protocol_name});

        while(my $row = $protocol_cursor->next){
            my $marker = $row->{'marker_name'};
            push @marker_names, $marker;
        }

        @selected_markers = ();

        for (1..$num_random_markers) {
            push @selected_markers, $marker_names[int rand(scalar(@marker_names))];
        }
    }

    my $accession_cursor = $accession_collection->find({protocol_name => $protocol_name} );

    my @accessions_with_mutations;
    while(my $row = $accession_cursor->next){
        my $accession_name = $row->{'accession_name'};

        my $selected_marker_mutation_count = $genotype_collection->count({protocol_name => $protocol_name, accession_name=>$accession_name, 'marker_score.GT' => {'$nin' => ["0/0", "./."] }, marker_name=> {'$in' => \@selected_markers}});

        if ($selected_marker_mutation_count == scalar(@selected_markers) ) {
            push @accessions_with_mutations, $accession_name;
        }

    }

   #print Dumper \@accessions_with_mutations;
   #print join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\n";
   my $n_end = Time::HiRes::time();
   my $n_duration = $n_end - $n_start;

   print $fh  $run."\t".join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\t".$n_duration."\n";

}


close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;
print "Time: ".$duration."\n";

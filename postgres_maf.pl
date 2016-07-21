#!/usr/bin/perl



use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;
use List::Util;

our ($opt_H, $opt_D, $opt_p, $opt_m, $opt_c, $opt_n, $opt_f, $opt_l, $opt_s);

getopts('H:D:p:m:n:f:c:l:s:');

if (!$opt_H || !$opt_D || !$opt_p || !$opt_m || !$opt_n || !$opt_f || (!$opt_c && !$opt_l)) {
    die "Must provide options -H (hostname), -D (database name), -p (db user password), -m (protocol name), -n (num reps), -f (out filename), -c (num markers to select 'all' for all markers), -l (OPTIONAL: list of markers to search over. Overrides -c), -s (OPTIONAL: threshold for reporting as a rare allele. default is 0.10 ) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $protocol_name = $opt_m;
my $num_markers = $opt_c;
my $num_reps = $opt_n;
my $out_file = $opt_f;
my $threshold = $opt_s || 0.10;
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
print $fh "Result\tTime\n";

my $json = JSON->new();

my @marker_names;
if (!$opt_l) {

    my $sth = $dbh->prepare('select kv.key from nd_protocol join nd_protocolprop AS a using(nd_protocol_id), jsonb_each(a.value) AS kv where nd_protocol.name = ? ');
    #    or die "Couldn't prepare statement: " . $dbh->errstr;

    $sth->execute($protocol_name);

    while (my $marker = $sth->fetchrow_array) {
        push @marker_names, $marker;
    }
}

for (1..$num_reps) {

    if (!$opt_l) {
        @selected_markers = ();
        if ($num_markers eq 'all') {
            $num_markers = scalar(@marker_names);
        }
        for (1..$num_markers) {
            push @selected_markers, $marker_names[int rand(scalar(@marker_names))];
        }
    }
    #print Dumper \@selected_markers;

    my $n_start = Time::HiRes::time();

    my %selected_marker_hash;
    foreach my $m (@selected_markers) {
        $selected_marker_hash{$m} = 1;
    }

    #Get number of stocks that were genotyped using the protocol given. Used to calculate allele frequencies.
    my $sth_stock = $dbh->prepare("SELECT count(stock.stock_id) from stock join nd_experiment_stock using(stock_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) where nd_protocol.name = ?;");
        #or die "Couldn't prepare statement: " . $dbh->errstr;

    $sth_stock->execute($protocol_name);
    my $stock_count = $sth_stock->fetchrow_array;

    #Get the marker's ALT and REF.
    my $sth_markers = $dbh->prepare("SELECT kv.key, kv.value->>'alt', kv.value->>'ref' from nd_protocol join nd_protocolprop AS a using(nd_protocol_id), jsonb_each(a.value) kv WHERE nd_protocol.name = ? ;");

    $sth_markers->execute($protocol_name);

    my %markers_info;
    while (my ($marker, $alt, $ref) = $sth_markers->fetchrow_array) {
        $markers_info{$marker} = [$alt, $ref];
    }

    #initialize allele count hash, for reference allele (r), missing (.), and for each allele in ALT
    my $allele_frequency_counts;
    foreach my $marker (@selected_markers) {
        my $alt = $markers_info{$marker}->[0];
        my $ref = $markers_info{$marker}->[1];
        my @alt_array = split /,/, $alt;
        
        $allele_frequency_counts->{$marker}->{'r'.$ref} = 0;
        $allele_frequency_counts->{$marker}->{'.'} = 0;
        
        foreach my $alt (@alt_array) {
            $allele_frequency_counts->{$marker}->{$alt} = 0;
        }
    }


    #Selecting all markerscores for given protocol.
    my $sth_geno = $dbh->prepare("select kv.key, kv.value->>'GT' from genotype join nd_experiment_genotype on (genotype.genotype_id=nd_experiment_genotype.genotype_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) join genotypeprop AS a on (genotype.genotype_id=a.genotype_id), jsonb_each(a.value) kv WHERE nd_protocol.name = ? ;");
        #or die "Couldn't prepare statement: " . $dbh->errstr;

    $sth_geno->execute($protocol_name);

    while (my ($marker, $geno) = $sth_geno->fetchrow_array()) {

        #check that marker is one we selected.
        if (exists($selected_marker_hash{$marker})) {

            my @score_array = split /\//, $geno;
            my $alt = $markers_info{$marker}->[0];
            my $ref = $markers_info{$marker}->[1];
            my @alt_array = split /,/, $alt;
            #print $geno."\n";
            #print $alt."\n";
            #print Dumper \@alt_array;

            foreach my $score (@score_array) {
                #print $score."\n";
                if ($score eq '.') {
                    $allele_frequency_counts->{$marker}->{'.'}++;
                } elsif ($score eq '0') {
                    $allele_frequency_counts->{$marker}->{'r'.$ref}++;
                } else {
                    my $a = $alt_array[$score-1];
                    $allele_frequency_counts->{$marker}->{$a}++;
                }
            }
        }
    }
    #print Dumper $allele_frequency_counts;

    my @rare_marker_alleles;
    foreach my $m (keys %$allele_frequency_counts) {
        my $count = 0;
        my $min_allele;
        my $min_value;
        foreach my $a (keys %{ $allele_frequency_counts->{$m} }) {
            my $val = $allele_frequency_counts->{$m}->{$a};
            #print $a." ".$val."\n";
            if ($count == 0) {
                $min_value = $val;
                $min_allele = $a;
            } else {
                if ($val < $min_value) {
                    $min_value = $val;
                    $min_allele = $a;
                }
            }
            $count++;
        }
        my $percentage = $min_value / ($stock_count * 2);
        if ($percentage < $threshold ) {
            push @rare_marker_alleles, [$m, $min_allele, $min_value, $percentage];
        }
    }

    print scalar(@rare_marker_alleles)."\n";
    #print Dumper \@rare_marker_alleles;

    # print Dumper \@accessions_with_mutations;
    #print join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\n";
    my $n_end = Time::HiRes::time();
    my $n_duration = $n_end - $n_start;

    #print $fh  join(",", @accessions_with_mutations)." are accessions with mutations in markers:  ".join(",", @selected_markers)."\t".$n_duration."\n";

}

close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;
print "Time: ".$duration."\n";

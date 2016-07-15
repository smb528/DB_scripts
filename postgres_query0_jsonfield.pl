#!/usr/bin/perl



use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;

our ($opt_H, $opt_D, $opt_p, $opt_m, $opt_n, $opt_f);

getopts('H:D:p:m:n:f:');

if (!$opt_H || !$opt_D || !$opt_p || !$opt_m || !$opt_n || !$opt_f) {
    die "Must provide options -H (hostname), -D (database name), -p (db user password), -m (protocol name), -n (num reps), -f (out filename) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $protocol_name = $opt_m;
my $num_reps = $opt_n;
my $out_file = $opt_f;

my $driver = "Pg";
my $dsn = "DBI:$driver:dbname=$dbname;host=$dbhost;port=5432";
my $userid = "postgres";
my $password = $dbpass;
my $dbh = DBI->connect($dsn,$userid, $password, {RaiseError => 1}) or die $DBI::errstr;

		       print "Opened database successfully\n";

open(my $fh, '>', $out_file);
print $fh "Stock ID, Number Mutations, Time\n";
my $start = Time::HiRes::time();

for (1..$num_reps) {
    my $n_start = Time::HiRes::time();

#Get List of all Stocks that were geotypes using the protocol given.
my $sth_stock = $dbh->prepare("SELECT stock.stock_id from stock join nd_experiment_stock using(stock_id) join nd_experiment using(nd_experiment_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) where nd_protocol.name = ?;")
    or die "Couldn't prepare stocks statement: " . $dbh->errstr;

$sth_stock->execute($protocol_name);

#Count markers where GT is not 0/0 for an individual stock.
my $sth_count = $dbh->prepare("select count(kv.key) from stock join nd_experiment_stock using(stock_id) join nd_experiment using(nd_experiment_id) join nd_experiment_genotype using(nd_experiment_id) join genotype using(genotype_id) join genotypeprop AS a using(genotype_id), json_each(a.value) kv WHERE stock.stock_id = ? and not kv.value::text LIKE '%0/0%' and not kv.value::text LIKE '%./.%'")
  or die "Couldn't prepare statement: " . $dbh->errstr;


#Loop over the list of stocks that we found.
while (my $stock_id = $sth_stock->fetchrow_array) {

  $sth_count->execute($stock_id);
  my $mutations_count = $sth_count->fetchrow_array();

  print "MUTATIONS COUNT: ".$mutations_count."\n";
  my $n_end = Time::HiRes::time();
  my $n_duration = $n_end - $n_start;
   print $fh "$stock_id, $mutations_count, $n_duration\n";

}

}

close $fh;

my $end = Time::HiRes::time();
my $duration = $end - $start;

print Dumper "Time: ".$duration;

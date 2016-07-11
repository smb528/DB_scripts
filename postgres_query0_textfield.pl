#!/usr/bin/perl



use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Getopt::Std;

our ($opt_H, $opt_D, $opt_p, $opt_m);

getopts('H:D:p:m:');

if (!$opt_H || !$opt_D || !$opt_p || !$opt_m) {
    die "Must provide options -H (hostname), -D (database name), -p (db user password), -m (protocol name) \n";
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $protocol_name = $opt_m;

my $start = Time::HiRes::time();

my $driver = "Pg";
my $dsn = "DBI:$driver:dbname=$dbname;host=$dbhost;port=5432";
my $userid = "postgres";
my $password = $dbpass;
my $dbh = DBI->connect($dsn,$userid, $password, {RaiseError => 1}) or die $DBI::errstr;

		       print "Opened database successfully\n";

my $sth = $dbh->prepare("select genotypeprop.value from nd_experiment join nd_experiment_genotype using(nd_experiment_id) join genotype using(genotype_id) join genotypeprop using(genotype_id) join nd_experiment_protocol using(nd_experiment_id) join nd_protocol using(nd_protocol_id) where nd_protocol.name = ?;")
    or die "Couldn't prepare statement: " . $dbh->errstr;

$sth->execute($protocol_name);

my $json = JSON->new();

while(my $row=$sth->fetchrow_arrayref){

    my $mutations_count = 1;
    my $ref_count = 1;
    my $bad_quality = 1;

    my $json_value = $json->decode(@$row);
    #print Dumper $json_value;

    foreach my $marker (keys %$json_value) {
      my $GT = $json_value->{$marker}->{'GT'};
    	my $GQ = $json_value->{$marker}->{'GQ'};

      if ($GT ne '0/0') {
        $mutations_count++;
      } else {
        $ref_count++;
      }

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
    print "MUTATIONS COUNT: ".$mutations_count."\n";
    #print "REF COUNT: ".$ref_count."\n\n";

}

my $end = Time::HiRes::time();
my $duration = $end - $start;

print Dumper "Time: ".$duration;

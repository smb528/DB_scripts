#!/usr/bin/perl



use DBI;
use strict;
use Data::Dumper;
use JSON;
use Time::HiRes;

my $start = Time::HiRes::time();

my $driver = "Pg";
my $database = "fixture";
my $dsn = "DBI:$driver:dbname=$database;host=127.0.0.1;port=5432";
my $userid = "postgres";
my $password = "postgres";
my $dbh = DBI->connect($dsn,$userid, $password, {RaiseError => 1}) or die $DBI::errstr;

		       print "Opened database successfully\n";

my $sth = $dbh->prepare('SELECT value FROM public.genotypeprop order by genotypeprop_id DESC limit 11;')
    or die "Couldn't prepare statement: " . $dbh->errstr;

my $rth = $dbh->prepare('SELECT value FROM public.nd_protocolprop order by nd_protocolprop_id DESC limit 11;')
    or die "didn't work: " . $dbh->errstr;

$sth->execute();
$rth->execute();

my $json = JSON->new();

my %unique_alts;

while(my $row=$sth->fetchrow_arrayref, my$row2=$rth->fetchrow_arrayref){


    my $deletion_count = 0;
    my $nondeletion_count = 0;

    my $json_value = $json->decode(@$row);
    #print Dumper $json_value;
    my $json_value2 = $json-> decode(@$row2);
		#print Dumper $json_value2;


    foreach my $marker (keys %$json_value ) {
	my $GT = $json_value->{$marker}->{'GT'};
	my $GQ = $json_value->{$marker}->{'GQ'};
	my $alt = $json_value2->{$marker}->{'alt'};

		$unique_alts{$alt} = $GT;

		  if ($alt eq '-' and $GT ne '0/0') {

		      $deletion_count++;
		  } elsif ($alt eq 'A,-' and $GT ne '0/0' and $GT ne '1/1') {
		      $deletion_count++;
		  } elsif ($alt eq '-,A' and $GT ne '0/0' and $GT ne '2/2') {
		      $deletion_count++;
		  } elsif ($alt eq '-,T' and $GT ne '0/0' and $GT ne '2/2') {
                      $deletion_count++;
		  } elsif ($alt eq 'T,-' and $GT ne '0/0' and $GT ne '1/1') {
		      $deletion_count++;
                  } elsif ($alt eq 'G,-' and $GT ne '0/0' and $GT ne '1/1') {
		      $deletion_count++;
		  } elsif ($alt eq '-,G' and $GT ne '0/0' and $GT ne '2/2') {
		      $deletion_count++;
		  } elsif ($alt eq 'C,-' and $GT ne '0/0' and $GT ne '1/1') {
		      $deletion_count++;
		  } elsif ($alt eq '-,C' and $GT ne '0/0' and $GT ne '2/2') {
		      $deletion_count++;
				  } else {


				      $nondeletion_count++;
				  } }


    print "DELETIONS COUNT: ".$deletion_count."\n";
    print "NONDELETION COUNT: ".$nondeletion_count."\n";
}

print Dumper \%unique_alts;

my $end = Time::HiRes::time();
my $duration = $end - $start;
print Dumper "Time: ".$duration;

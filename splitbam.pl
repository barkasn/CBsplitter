#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

## Read command line options
my $verbose = 1;
my $clustersFile = '';
my $bamfile = '';
my $outputPrefix='';
my $help=0;

GetOptions("bamfile=s" => \$bamfile,
	   "cluster-file=s" => \$clustersFile,
	   "output-prefix=s" => \$outputPrefix,
	   "verbose" => \$verbose,
	   "help" => \$help
)
    or die("Error in command line arguments\n");

if ($help) {
    my $usage = <<'END';

A utility for splitting a bam file with reads from multiple signle cells
into individual bam files on the basis of the CB tag.
	
      Usage: splitbam.pl --bamfile input.bam --cluster-file clusters.txt --verbose --output-prefix output/

END
    print ($usage);
    exit;
}

# my $clustersFile = 'clusters.txt';
# my $bamfile = 'A59.bam';

## Read clusters file
if ($verbose) {print("Reading clusters file...\n")};
my %clustersmap;
if (open(my $clustersFH, '<', $clustersFile)) {
    while (my $line = <$clustersFH>) {
	my $i = 0;
	chomp $line;
	my @entries = split /,/, $line;
	my $clname = shift @entries;
	$clustersmap{$clname} = {};
	while(my $e = shift @entries) {
	    $clustersmap{$clname}{$e} = 1;
	    $i++;
	}
	print ("\t $i cells in $clname\n");
    }
    close($clustersFH);
} else {
    warn "Could not open clusters file '$clustersFile' $!";
}


## open series of samfiles for output
my %clustersFileConn;
foreach my $ck (keys %clustersmap) {
    open(my $tmpcomm, '>', $outputPrefix.$ck.'.sam');
    $clustersFileConn{$ck} = $tmpcomm;
}

if ($verbose) {print "Processing bam file..."};
open(my $bampipe, "samtools view -h ".$bamfile." |");

my $i =1;
while(my $bamline = <$bampipe>) {
    if ($bamline =~ m/^\@SQ/) {
	foreach my $key (keys(%clustersFileConn)) {
	    print { $clustersFileConn{$key} } $bamline;
	}
    } else {
	my @tags = $bamline =~ m/CB:Z:([ATGC]*)\t/;
	my $cbtag = $tags[0];
	if (defined $cbtag) {
	    foreach my $key (keys %clustersmap) {
		if (exists $clustersmap{$key}{$cbtag}) {
		    print { $clustersFileConn{$key} } $bamline;
		}
	    }
	}
	if (($i % 1000000) == 0) {print('.'); select()->flush();};
	$i = $i + 1;
    }
}
print('\n');

## Close the main bam
close($bampipe);

## Close the open bams
foreach my $ck (keys %clustersFileConn) {
    close($clustersFileConn{$ck})
}

#!/bin/perl -w

# Taxallnomy - get_lineage

# This script retrieves the taxonomic lineage of taxIDs of interest. To use it,
# make sure that Taxallnomy database is properly loaded in a local MySQL.
# See README

##############################################################################
#                                                                            #
#    Copyright (C) 2017 Tetsu Sakamoto                                       #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.   #
#                                                                            #
##############################################################################

##############################################################################
#                                                                            #
#    Contacts:                                                               #
#                                                                            #
#    tetsufmbio@gmail.com (Tetsu Sakamoto)                                   #
#    miguel@icb.ufmg.br (J. Miguel Ortega)                                   #
#                                                                            #
##############################################################################

# Version 1.0

use FindBin qw($Bin);
use lib "$Bin/lib/perl5";
use Net::Wire10;
use Term::InKey;
use strict;
use Getopt::Long;
use Pod::Usage;

$| = (@ARGV > 0); 

my $txid;
my $txidFile;
my $rank = "common";
my $format = "tab";
my $selectedRank;
my $showcode;
my $userid;
my $outfile = "taxallnomy_result";
my $help = 0;
my $man	= 0;
my $database = "taxallnomy";
my $table = "taxallnomy_lin";
my $rankTable = "taxallnomy_rank";

GetOptions(
    'txid=s'	=> \$txid,
    'file=s'    => \$txidFile,
	'rank=s'	=> \$rank,
	'format=s'	=> \$format,
	'srank=s'	=> \$selectedRank,
	'showcode!'	=> \$showcode,
	'user=s'	=> \$userid,
	'out=s'		=> \$outfile,
	'database=s'=> \$database,
	'table=s'	=> \$table,
	'rankTable=s'	=> \$rankTable,
	'help!'		=> \$help,
	'man!'		=> \$man,
) or pod2usage(-verbose => 99, 
            -sections => [ qw(NAME SYNOPSIS) ] );

pod2usage(0) if $man;
pod2usage(2) if $help;

my %typeCode = (
	"1" => "",
	"2" => "of_",
	"3" => "in_",
);

# Check inputs

sub error{
	my $message = $_[0];
	print $message."\n";
	pod2usage(2);
	exit;
}

if(!$txid && !$txidFile){
	error("ERROR Please provide TaxIDs or a file containing a list of TaxIDs.");
}

my %rank_type = (
	"all" => 1,
	"common" => 1,
	"main" => 1,
	"custom" => 1,
);

if (!exists $rank_type{$rank}){
	error("ERROR: invalid rank provided. Use 'main', 'common', 'all' or 'custom'.");
} 

my %format_type = (
	"tab" => 1,
	"json" => 1,
	"xml" => 1,
);

if (!exists $format_type{$format}){
	error("ERROR: invalid format provided. Use 'tab', 'json' or 'xml'.");
}

open (OUT, "> $outfile") or die "ERROR: Could not create the file \'$outfile\'.\n";

# connect to the database
#
if(!$userid){
	print "Type MySQL user that have access to taxallnomy database:\n";
	chomp($userid = <STDIN>);
}

# get password for mysql
print "Type MySQL password for user \'$userid\':\n";
my $password = &ReadPassword;	
chomp $password;

my $wire = Net::Wire10->new(
	host     => "localhost",
	user     => $userid,
	port     => 3306,
	password => $password,
	database => $database
);

eval {$wire->connect;};
if ($@) {
	die "\nERROR: Could not connect to mysql database.\n";
} else {
	print "Connected to mysql database.\n";
}

my %ncbi_all_ranks = (
	"no rank" => -1,
);
my %taxAllnomy_ranks_code;
my @ncbi_all_ranks;

my $resultsRanks = $wire->query("SELECT * FROM ".$rankTable);
	while (my $row = $resultsRanks->next_array) {
		my @row = @$row;
		$row[0] =~ s/ /_/g;
		push(@ncbi_all_ranks, $row[0]);
		$taxAllnomy_ranks_code{$row[3]} = $row[4]."_";
		$ncbi_all_ranks{$row[0]} = $row[1] - 1;
	}

my @selectedRank = @ncbi_all_ranks;

if ($rank eq "common"){
my %commonRanks  = ("superkingdom"=>1,"kingdom"=>1,"phylum"=>1,"subphylum"=>1,"class"=>1,"superclass"=>1,"subclass"=>1,"order"=>1,"superorder"=>1,"suborder"=>1,"family"=>1,"superfamily"=>1,"subfamily"=>1,"genus"=>1,"subgenus"=>1,"species"=>1,"subspecies"=>1);
	my @newSelectedRanks;
	foreach my $rank2 (@selectedRank){
		push(@newSelectedRanks, $rank2) if (exists $commonRanks{$rank2});
	}
	@selectedRank = @newSelectedRanks;
} elsif ($rank eq "main"){
	my %mainRanks = ("superkingdom"=>1,"phylum"=>1,"class"=>1,"order"=>1,"family"=>1,"genus"=>1,"species"=>1);
	my @newSelectedRanks;
	foreach my $rank2 (@selectedRank){
		push(@newSelectedRanks, $rank2) if (exists $mainRanks{$rank2});
	}
	@selectedRank = @newSelectedRanks;
} elsif ($rank eq "custom"){
	#my $selectedRank = $cgi->param("srank") if ($cgi->param("srank"));
	
	if (!$selectedRank){
		my $errorMessage = "ERROR: select the ranks to be displayed using srank.\n";
		$errorMessage .= "Example: -rank custom -srank kingdom,class,family,species\n";
		$errorMessage .= "Valid ranks are:\n";
		$errorMessage .= join("\n", @ncbi_all_ranks);	
		error($errorMessage);
	} else {
		$selectedRank =~ s/ |\t//g;
		$selectedRank = lc $selectedRank;
		my @selectedRank2 = split(",", $selectedRank);
		my %selectedRank2;
		foreach my $srank(@selectedRank2){
			if(!exists $ncbi_all_ranks{$srank}){
				my $errorMessage = "ERROR: invalid rank selected: $srank\n";
				$errorMessage .= "Valid ranks are:\n";
				$errorMessage .= join("\n", @ncbi_all_ranks);	
				error($errorMessage);
			}
			$selectedRank2{$srank} = ();
		}
		@selectedRank = ();
		foreach my $singlerank(@ncbi_all_ranks){
			if (exists $selectedRank2{$singlerank}){
				push(@selectedRank, $singlerank);
			}
		}
	}
}

my @txid;

if($txid){
	$txid =~ s/ |\t//g;
	if($txid =~ /[^0-9,]/){
		print "Sorry, there is special characters in txid parameter. \nUse only numbers and commas.\n";
		exit;
	}

	@txid = split(",", $txid);
} elsif ($txidFile){
	open(IN, "< $txidFile") or die("ERROR: Can't open the file $txidFile.\n");
	my $control = 0;
	while(my $line = <IN>){
		chomp $line;
		next if ($line =~ /^$/);
		$line =~ s/ |\t|\r|\n//g;
		if($line =~ /[^0-9]/){
			print "Sorry, there is(are) special character(s) in your TaxIDs list file.";
			$control = 1;
		} else {
			push(@txid, $line);
		}
	}
	if ($control){
		error("ERROR: Some TaxIDs provided in the file were not validated. Use only numbers and provide one TaxIDs per line.\n");
	}
}

# avoid duplicated txid
my %txid;
@txid{@txid} = ();
@txid = keys %txid;

# retrieve txid from database;
my %hashTax;
my %hashTaxAll;
my $n = -1;
my $m = -100;
if (scalar @txid > 0){
	my $sth;
	do {
		$n = $n + 100;
		$m = $m + 100;
		$n = $#txid if ($n > $#txid);
		my $results = $wire->query("SELECT * FROM ".$table." WHERE txid in (\"".join('","', @txid[$m .. $n])."\")");
		while (my $row = $results->next_array) {
			my @row = @$row;
			my @ranksTxid;
			my $txid2 = $row[0];
			foreach my $taxRank(@selectedRank){
				my $taxallnomyID = $row[$ncbi_all_ranks{$taxRank} + 1];
				push(@ranksTxid, $taxallnomyID);
				$taxallnomyID =~ /^(\d+)\.\d{3}$/;
				$hashTaxAll{$1} = {};
			}
			$hashTax{$txid2}{"rank"} = \@ranksTxid;
			$hashTax{$txid2}{"sciname"} = $row[29];
		}
	} while ($n < $#txid);
}


if (!$showcode){
	my @taxAll = keys (%hashTaxAll);
	$n = -1;
	$m = -100;
	my $sth2;
	if (scalar @taxAll > 0){
		do {
			$n = $n + 100;
			$m = $m + 100;
			$n = $#taxAll if ($n > $#taxAll);
			
			my $results = $wire->query("SELECT txid,sciname FROM ".$table." WHERE txid in (\"".join('","', @taxAll[$m .. $n])."\")");
			while (my $row = $results->next_array) {
				my @row = @$row;
				my $txid2 = $row[0];
				my $name2 = $row[1];
				$hashTaxAll{$txid2}{"sciname"} = $name2;
			}
		} while ($n < $#taxAll);
	}
	#$sth2->finish();
	foreach my $keys(keys %hashTax){
		my $ref_ranksTxid = $hashTax{$keys}{"rank"};
		my @ranksTxid = @$ref_ranksTxid;
		my @nameTax;
		foreach my $tax(@ranksTxid){
			$tax =~ /^(\d+)\.(\d{2})(\d)$/;
			my $txidCode = $1;
			my $rankCode = $2;
			my $typeCode = $3;
			my $name = $hashTaxAll{$txidCode}{"sciname"};
			if($typeCode == 0){
				push(@nameTax, $name);
			} else {
				my $rank = $taxAllnomy_ranks_code{$rankCode};
				my $code = $typeCode{$typeCode};
				push(@nameTax, $rank.$code.$name);
			}
		}
		$hashTax{$keys}{"rank"} = \@nameTax;
	}
}

if ($format eq "tab"){

	print OUT "#Taxallnomy\n";
	print OUT "#taxid\t".join("\t", @selectedRank)."\n";
	foreach my $txid(@txid){
		print OUT $txid."\t";
		if (exists $hashTax{$txid}{"rank"}){
			print OUT join("\t", @{$hashTax{$txid}{"rank"}})."\n";
		} else {
			print OUT "\ttaxid not found in our database.\n";
		}
	}
} elsif ($format eq "json") {
	print OUT "{\n";
	foreach my $txid(@txid){
		print OUT "\t$txid:";
		if (exists $hashTax{$txid}{"rank"}){
			print OUT "{\n";
			my @txidranks = @{$hashTax{$txid}{"rank"}};		
			for(my $i = 0; $i < scalar @selectedRank; $i++){
				print OUT "\t\t\"". $selectedRank[$i]."\":\'".$txidranks[$i]."\',\n";
			}
			print OUT "\t},\n";
		} else {
			print OUT "\"taxid not found in our database.\",\n";
		}
		
		
	}
	print OUT "}";
	
} elsif ($format eq "xml"){
	print OUT "<taxallnomy>\n";
	foreach my $txid(@txid){
		print OUT "\t<species>\n";
		print OUT "\t\t<txid>$txid</txid>\n";
		print OUT "\t\t<ranks>";
		if (exists $hashTax{$txid}{"rank"}){
			print OUT "\n";
			my @txidranks = @{$hashTax{$txid}{"rank"}};		
			for(my $i = 0; $i < scalar @selectedRank; $i++){
				print OUT "\t\t\t<".$selectedRank[$i].">".$txidranks[$i]."</".$selectedRank[$i].">\n";
			}
			print OUT "\t\t";
		} else {
			print OUT "taxid not found in our database.";
		}
		print OUT "</ranks>\n";
		print OUT "\t</species>\n";
	}
	print OUT "</taxallnomy>";
}

print "Result was written in \'$outfile\'.\n";

=head1 NAME

get_lineage - retrieve taxonomic lineage of a set of organism from Taxallnomy database.

This script is part of Taxallnomy database project.

=head1 SYNOPSIS

perl get_lineage.pl -txid 9606,9595

perl get_lineage.pl -file <txid_list_file>

=item B<Inputs>:

[-txid set_of_taxids] [-file txids_list_file]
	
=item B<Other parameters>:

[-rank rank_code] [-srank ranks] [-format format_code] [-user mysql_user] [-showcode] [-out file_name] [-database database_name] [-table table_name]
		
=item B<Help>:

[-help] [-man]

Use -man for a detailed help.

=head1 OPTIONS

=over 8

=item B<-txid> <set of TaxIDs>

Set of NCBI TaxIDs to have their taxonomic lineages retrieved. For  multiple  taxids,  use  comma  to 
separate them.

=item B<-file> <taxids_list_file>

A file containing a list NCBI TaxIDs to have their taxonomic lineages retrieved. Please, provide  one 
TaxID per line.

=item B<-rank> <main|common|all|custom> Default: common

Set of taxonomic ranks that should comprise the taxonomic lineage. If you want to retrieve a set of 
taxonomic ranks different from those predefined set, set this parameter as 'custom' and provide the
rank names to be retrieved using -srank parameter.

main: retrieves Superkingdom, Phylum, Class, Order, Family, Genus, Species.

common: retrieves the "main" taxonomic ranks plus Kingdom, Subphylum, Super- and Sub- of Class, Order and Family; and Tribe.

all: retrieves all taxonomic ranks.

=item B<-srank> <rank_names>

Use this parameter with -rank set to 'custom'. Select the taxonomic ranks that will comprise the 
taxonomic lineage. Use comma to separate each rank. Valid taxonomic rank names are:

superkingdom, kingdom, subkingdom, superphylum, phylum, subphylum, superclass, class,
subclass, infraclass, superorder, order, suborder, infraorder, parvorder, superfamily, 
family, subfamily, tribe, subtribe, genus, subgenus, species_group, species_subgroup, 
species, subspecies, varietas, forma.

=item B<-format> <tab|json|xml> Default: tab

Format of output file.

=item B<-user> <mysql_user>

MySQL user that have access to a local Taxallnomy database.

=item B<-showcode>

Instead of displaying the taxa name, show Taxallnomy identifier code in the lineage.

=item B<-out> <output_file> Default: taxallnomy_result

Name of the output file.

=item B<-database> <database_name> Default: taxallnomy

Name of MySQL database with Taxallnomy data

=item B<-table> <table_name> Default: taxallnomy_lin

Name of MySQL table with Taxallnomy lineage data.

=item B<-rankTable> <table_name> Default: taxallnomy_rank

Name of MySQL table with Taxallnomy rank data.

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<Taxallnomy> is a balanced taxonomic database based on NCBI Taxonomy that provides taxonomic lineages according to the ranks used on Linnean classification system.
in a phylogenetic tree. 

=cut

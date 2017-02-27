#!/bin/perl -w

# This script creates all files necessary to load Taxallnomy database on MySQL.
# Be aware that  its  execution  requires  internet  connection  and  consumes
# approximately 1Gb of HD space.

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

# Version 1.2.1

##############################################################################
#                                                                            #
# Modification from version 1.2                                              #
#                                                                            #
# - Tables generated by the algorithm have changed.                          #
#   - taxallnomy_lin table will contain sciname and common name.             #
#   - taxallnomy_tree table will contain only the rank and parent columns.   #
#                                                                            #
##############################################################################

use strict;
use Data::Dumper;
use POSIX;

my $dir = "taxallnomy_data";

if(-d $dir){
	die "ERROR: Can't create the directory $dir. Probably because this directory exists in your current working directory.\n";
} 

# taxonomy table
print "Making Taxonomy table file...\n";
print "  Downloading taxdump.tar.gz... \n";
system("wget -Nnv ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz");
system("chmod u+w taxdump.tar.gz");
if (!-e "taxdump.tar.gz"){
	die "ERROR: Couldn't find/download the file taxdump.tar.gz.\n"
}
print "  Making table... \n";
system("mkdir $dir");
system("cp taxdump.tar.gz $dir");
chdir $dir;
system("tar -zxf taxdump.tar.gz");
open(TXID, "< nodes.dmp") or die; 

my %ncbi_all_ranks = (
	"no rank" => -1,
	"superkingdom" => 0,
	"kingdom" => 1,
	"subkingdom" => 2,
	"superphylum" => 3,
	"phylum" => 4,
	"subphylum" => 5,
	"superclass" => 6,
	"class" => 7,
	"subclass" => 8,
	"infraclass" => 9,
	"superorder" => 10,
	"order" => 11,
	"suborder" => 12,
	"infraorder" => 13,
	"parvorder" => 14,
	"superfamily" => 15,
	"family" => 16,	
	"subfamily" => 17,
	"tribe" => 18,
	"subtribe" => 19,
	"genus" => 20,	
	"subgenus" => 21,
	"species group" => 22,	
	"species subgroup" => 23,
	"species" => 24,
	"subspecies" => 25,
	"varietas" => 26,
	"forma" => 27
);

my @table;	# table[$txid][0] - parent 
			# table[$txid][1] - rank (integer)
			# table[$txid][2] - [children]
			# table[$txid][3] - name (0 - scientific name; 1 - genbank common name; 2 - common name)
			# table[$txid][4] - txid
			# table[$txid][5] - possibleRanks

my @txid;
while(my $line = <TXID>){
	my @line = split(/\t\|\t/, $line);
	$table[$line[0]][4] = $line[0]; # txid
	$table[$line[0]][0] = $line[1] if ($line[0] != $line[1]); # parent
	
	if (!exists $ncbi_all_ranks{$line[2]}){
		die "ERROR: new rank found. Script need update: ".$line[0]." ".$line[2]."\n";
	}
	
	$table[$line[0]][1] = $ncbi_all_ranks{$line[2]}; # rank
	
	if (!$table[$line[1]][2]){
		$table[$line[1]][2][0] = $line[0] if ($line[0] != $line[1]); # children
	} else {
		$table[$line[1]][2][scalar @{$table[$line[1]][2]}] = $line[0] if ($line[0] != $line[1]); # children
	}
	
	push(@txid, $line[0]);
	
} 
	
close TXID;

# merged
open(MERGED, "< merged.dmp") or die;
my %merged;
while(my $line = <MERGED>){
	chomp $line;
	my @line = split(/\t\|\t/, $line); 
	$line[1] =~ s/\t\|//g;
	$merged{$line[1]}{"merged"}{$line[0]} = 1;
}

close MERGED; 

open(TXIDNAME, "< names.dmp") or die; 

while(my $line = <TXIDNAME>){
	chomp $line;
	my @line = split(/\t\|\t/, $line); 
	next if ($line[3] ne "scientific name\t|" and $line[3] !~ m/common name/); 
	my $nameCode;
	if ($line[3] eq "scientific name\t|"){
		$nameCode = 0;
	} elsif ($line[3] eq "genbank common name\t|"){
		$nameCode = 1;
	} elsif ($line[3] eq "common name\t|"){
		$nameCode = 2;
	}

	$table[$line[0]][3][$nameCode] = $line[1];
} 
close TXIDNAME; 

my @ncbi_all_ranks = (
	"superkingdom",
	"kingdom",
	"subkingdom",
	"superphylum",
	"phylum",
	"subphylum",
	"superclass",
	"class",
	"subclass",
	"infraclass",
	"superorder",
	"order",
	"suborder",
	"infraorder",
	"parvorder",
	"superfamily",
	"family",	
	"subfamily",
	"tribe",
	"subtribe",
	"genus",	
	"subgenus",
	"species group",	
	"species subgroup",
	"species",
	"subspecies",
	"varietas",
	"forma"
);

my @taxAllnomy_ranks = (
	"superkingdom",
	"kingdom",
	"phylum",
	"subphylum",
	"superclass",
	"class",
	"subclass",
	"superorder",
	"order",
	"suborder",
	"superfamily",
	"family",
	"subfamily",
	"genus",
	"subgenus",
	"species",
	"subspecies"
);

my %taxAllnomy_ranks = (
	"superkingdom" 	=> 0.01,
	"kingdom"		=> 0.02,
	"subkingdom"	=> 0.03,
	"superphylum" 	=> 0.04,
	"phylum" 		=> 0.05,
	"subphylum" 	=> 0.06,
	"superclass" 	=> 0.07,
	"class" 		=> 0.08,
	"subclass" 		=> 0.09,
	"infraclass" 	=> 0.1,
	"superorder" 	=> 0.11,
	"order" 		=> 0.12,
	"suborder" 		=> 0.13,
	"infraorder" 	=> 0.14,
	"parvorder" 	=> 0.15,
	"superfamily" 	=> 0.16,
	"family" 		=> 0.17,
	"subfamily" 	=> 0.18,
	"tribe" 		=> 0.19,
	"subtribe" 		=> 0.20,
	"genus" 		=> 0.21,
	"subgenus" 		=> 0.22,
	"species group" => 0.23,
	"species subgroup" => 0.24,
	"species" 		=> 0.25,
	"subspecies" 	=> 0.26,
	"varietas" 		=> 0.27,
	"forma" 		=> 0.28,
);

my %taxAllnomy_ranks_code = (
	"superkingdom" 	=> "spk_",
	"kingdom"		=> "kin_",
	"subkingdom"	=> "sbk_",
	"superphylum" 	=> "spp_",
	"phylum" 		=> "phy_",
	"subphylum" 	=> "sbp_",
	"superclass" 	=> "spc_",
	"class" 		=> "cla_",
	"subclass" 		=> "sbc_",
	"infraclass" 	=> "ifc_",
	"superorder" 	=> "spo_",
	"order" 		=> "ord_",
	"suborder" 		=> "sbo_",
	"infraorder" 	=> "ifo_",
	"parvorder" 	=> "pvo_",
	"superfamily" 	=> "spf_",
	"family" 		=> "fam_",
	"subfamily" 	=> "sbf_",
	"tribe" 		=> "tri_",
	"subtribe" 		=> "sbt_",
	"genus" 		=> "gen_",
	"subgenus" 		=> "sbg_",
	"species group" => "grp_",
	"species subgroup" => "sbgrp_",
	"species" 		=> "spe_",
	"subspecies" 	=> "sbs_",
	"varietas" 		=> "var_",
	"forma" 		=> "for_",
);

my %rev_ncbi_all_ranks = ( 
	-1 => "no rank",
	0 => "superkingdom",
	1 => "kingdom",
	2 => "subkingdom",
	3 => "superphylum",
	4 => "phylum",
	5 => "subphylum",
	6 => "superclass",
	7 => "class",
	8 => "subclass",
	9 => "infraclass",
	10 => "superorder",
	11 => "order",
	12 => "suborder",
	13 => "infraorder",
	14 => "parvorder",
	15 => "superfamily",
	16 => "family",
	17 => "subfamily",
	18 => "tribe",
	19 => "subtribe",
	20 => "genus",
	21 => "subgenus",
	22 => "species group",
	23 => "species subgroup",
	24 => "species",
	25 => "subspecies",
	26 => "varietas",
	27 => "forma"
);


foreach my $rank2analyse(@ncbi_all_ranks){
	
	my @nodes2analyse;
	push (@nodes2analyse, 1);
	my $rank2analyseInt = $ncbi_all_ranks{$rank2analyse};
	#print $rank2analyse."\t".$rank2analyseInt."\n";
	while(scalar @nodes2analyse != 0){
	
		my $node = shift @nodes2analyse;
		if ($table[$node][1] != -1){ # ranked taxon
		
			next if ($rank2analyseInt <= $table[$node][1]);
			push(@nodes2analyse, @{$table[$node][2]}) if ($table[$node][2]);
			
		} else { # unranked taxon
			
			# pick max rank;
			my @nodes2analyse2;
			my $maxRank = -1;
			push(@nodes2analyse2, $table[$node][0]) if ($table[$node][0]);
			while(scalar @nodes2analyse2 != 0){
				my $node2 = shift @nodes2analyse2;
				if ($table[$node2][1] == -1){
					push(@nodes2analyse2, $table[$node2][0]) if ($table[$node2][0]);
				} else {
					$maxRank = $table[$node2][1];
				}
			}
			
			# pick min rank
			@nodes2analyse2 = @{$table[$node][2]} if ($table[$node][2]);
			my $minRank = 100;
			while(scalar @nodes2analyse2 != 0){
				my $node2 = shift @nodes2analyse2;
				if ($table[$node2][1] == -1){
					push(@nodes2analyse2, @{$table[$node2][2]}) if ($table[$node2][2]);
				} else {
					$minRank = $table[$node2][1] if ($minRank > $table[$node2][1]);
				}
			}
			
			if ($rank2analyseInt > $maxRank && $rank2analyseInt < $minRank){
				my @possibleRanks;
				@possibleRanks = @{$table[$node][5]} if ($table[$node][5]);
				push(@possibleRanks, $rank2analyseInt);				
				$table[$node][5] = \@possibleRanks;
			} else {
				push(@nodes2analyse, @{$table[$node][2]}) if ($table[$node][2]);
			} 
		}
	}
}

my @nodes2analyse3 = @{$table[1][2]};
while (scalar @nodes2analyse3 != 0){
	my $node = shift @nodes2analyse3;
	push (@nodes2analyse3, @{$table[$node][2]}) if $table[$node][2];
	next if($table[$node][1] != -1);
	next if(!$table[$node][5]);
	my @possibleRanks = @{$table[$node][5]};
	my $countRanks = scalar @possibleRanks;
	if ($countRanks == 1){
		next;
	} else {
		my @layer;
		push(@layer, @{$table[$node][2]}) if (exists $table[$node][2]);
		# verify if exist an unranked child taxon without possible ranks
		my $minPossibleRanks = 0;
		foreach my $node2(@layer){
			if (!exists $table[$node2][5]){
				if($table[$node2][3][0] !~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){ # verify if this represents an unclassified or an environmental sample.
					$minPossibleRanks = 1;
				} 
			}
		}
		#my $countLayer = 0;
		my $countDepth = 1;
		#my $control = 0;
		my $maxRankLevel = $possibleRanks[$#possibleRanks];
		while(scalar @layer != 0){
			my @layer2;	
			$maxRankLevel = $possibleRanks[$#possibleRanks];
			my $control = 0;
			while(scalar @layer != 0){
				my $layer2 = shift @layer;
				if ($table[$layer2][1] == -1){
					if($table[$layer2][3][0] !~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){ # verify if this represents an unclassified or an environmental sample.
						$control = 1;
						if (exists $table[$layer2][2]){
							push (@layer2, @{$table[$layer2][2]});
						}
						
						if (exists $table[$layer2][5]){
							my @possibleRanks2 = @{$table[$layer2][5]};
							if ($maxRankLevel <= $possibleRanks2[$#possibleRanks2]){
								$maxRankLevel = $possibleRanks2[$#possibleRanks2];
							}
						}
					}
				} 				
			}
			#$countLayer++ if (!$control);
			$countDepth++ if ($control);
			@layer = @layer2;
			#last if ($countDepth == $countRanks);
		}
		
		if ($countDepth > 1){
			my $ranksPerNode;
			#if ($maxRankLevel == -1){
			#	$ranksPerNode = ceil(($countRanks)/($countDepth + 1));
			#} else {
				$ranksPerNode = ceil(($maxRankLevel - $possibleRanks[0] + 1)/$countDepth);
			#}
			if ($ranksPerNode > $countRanks){
				$ranksPerNode = $countRanks;
			}
			
			# if exist an unranked child without possibleRanks, transfer at least one rank.
			if(scalar @possibleRanks == $ranksPerNode){
				if($minPossibleRanks){
					$ranksPerNode--;
				}
			}
			
			my @newPossibleRanks = splice(@possibleRanks, 0, $ranksPerNode);
			$table[$node][5] = \@newPossibleRanks;
			next if (scalar @possibleRanks == 0);
			my @childrenNodes = @{$table[$node][2]};
			foreach my $child(@childrenNodes){	
				my $lowerRank = $possibleRanks[$#possibleRanks];
				my @possibleRanks3 = @possibleRanks;
				if ($table[$child][1] == -1){
					if (exists $table[$child][5]){
						my @possibleRanks2 = @{$table[$child][5]};
						for(my $k = 0; $k < scalar @possibleRanks2; $k++){
							if ($possibleRanks2[$k] > $lowerRank){
								push (@possibleRanks3, $possibleRanks2[$k]);
							}
						}
					}
					$table[$child][5] = \@possibleRanks3;
				}
			}
		}
		
	}
}

print "  Writing table... \n";

open(DUMP, "> taxallnomy.sql") or die;
open(LIN, "> taxallnomy_lin.tab") or die;
open(NAME, "> taxallnomy_tree.tab") or die;
print DUMP '
-- MySQL dump 10.13  Distrib 5.6.25, for Linux (x86_64)
--
-- Host: localhost    Database: taxallnomy
-- ------------------------------------------------------
-- Server version	5.6.25

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE=\'+00:00\' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE=\'NO_AUTO_VALUE_ON_ZERO\' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `taxallnomy`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `taxallnomy` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `taxallnomy`;


--
-- Table structure for table `taxallnomy_lin`
--

DROP TABLE IF EXISTS `taxallnomy_lin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `taxallnomy_lin` (
  `txid` int(11) NOT NULL,
  `superkingdom` DECIMAL(20,3) NOT NULL,
  `kingdom` DECIMAL(20,3) NOT NULL,
  `subkingdom` DECIMAL(20,3) NOT NULL,
  `superphylum` DECIMAL(20,3) NOT NULL,
  `phylum` DECIMAL(20,3) NOT NULL,
  `subphylum` DECIMAL(20,3) NOT NULL,
  `superclass` DECIMAL(20,3) NOT NULL,
  `class` DECIMAL(20,3) NOT NULL,
  `subclass` DECIMAL(20,3) NOT NULL,
  `infraclass` DECIMAL(20,3) NOT NULL,
  `superorder` DECIMAL(20,3) NOT NULL,
  `order` DECIMAL(20,3) NOT NULL,
  `suborder` DECIMAL(20,3) NOT NULL,
  `infraorder` DECIMAL(20,3) NOT NULL,
  `parvorder` DECIMAL(20,3) NOT NULL,
  `superfamily` DECIMAL(20,3) NOT NULL,
  `family` DECIMAL(20,3) NOT NULL,
  `subfamily` DECIMAL(20,3) NOT NULL,
  `tribe` DECIMAL(20,3) NOT NULL,
  `subtribe` DECIMAL(20,3) NOT NULL,
  `genus` DECIMAL(20,3) NOT NULL,
  `subgenus` DECIMAL(20,3) NOT NULL,
  `species_group` DECIMAL(20,3) NOT NULL,
  `species_subgroup` DECIMAL(20,3) NOT NULL,
  `species` DECIMAL(20,3) NOT NULL,
  `subspecies` DECIMAL(20,3) NOT NULL,
  `varietas` DECIMAL(20,3) NOT NULL,
  `forma` DECIMAL(20,3) NOT NULL,
  `sciname` varchar(200) NOT NULL,
  `comname` varchar(200),
  `leaf` tinyint(1) NOT NULL,
  `unclassified` tinyint(1) NOT NULL,
  `merged` tinyint(1) NOT NULL,
  `rank` varchar(20) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `taxallnomy_tree`
--

DROP TABLE IF EXISTS `taxallnomy_tree`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `taxallnomy_tree` (
  `txid` DECIMAL(20,3) NOT NULL,
  `parent`DECIMAL(20,3) NOT NULL,
  `rank` varchar(20) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

ALTER TABLE `taxallnomy_tree` ADD INDEX `parent` (`parent`);

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_tree.tab\' INTO TABLE taxallnomy_tree;

LOAD DATA LOCAL INFILE \'taxallnomy_lin.tab\' INTO TABLE taxallnomy_lin;
';

my %typeCode = (
	1 => "",
	2 => "of_",
	3 => "in_",
);

my %taxallnomy_tree;
$taxallnomy_tree{1}{"parent"} = 0;
$taxallnomy_tree{1}{"sciname"} = "root";
$taxallnomy_tree{1}{"comname"} = "all";
$taxallnomy_tree{1}{"rank"} = "no rank";

my @insert;

foreach my $txid(@txid){
	my @lineage;
	my $species = $txid;
 	my $rank = $rev_ncbi_all_ranks{$table[$species][1]};
	my $leaf = 1;
	$leaf = 0 if ($table[$species][2]);
 	my $sciname = $table[$species][3][0];
 	my $parent = $table[$species][0];
	
	unshift (@lineage, [@{$table[$species]}]);
	my $unclassified = 0;
	while($species != 1){
		if($table[$species][3][0] =~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){ # verify if this represents an unclassified or an environmental sample.
			$unclassified = 1;
		}
		$species = $parent;
 		$parent = $table[$species][0];
		unshift (@lineage, [@{$table[$species]}]);
	}
	my $taxallnomyLineage = generate_taxallnomy(\@lineage);
	my @taxallnomyLineage = @$taxallnomyLineage;

	for(my $i = scalar @taxallnomyLineage - 1; $i >= 0; $i--){
		#next if ($taxallnomyLineage[$i] =~ /\.\d{2}3$/);
		last if (exists $taxallnomy_tree{$taxallnomyLineage[$i]});
		$taxallnomy_tree{$taxallnomyLineage[$i]} = 1;
		# parent
		my $parent2;
		if ($i - 1 >= 0){
			$parent2 = $taxallnomyLineage[$i - 1];
		} else {
			$parent2 = 1;
		}
		# rank
		my $rank2 = $ncbi_all_ranks[$i];
		
		my $txidCode2 = $taxallnomyLineage[$i];
		my $defLine = $txidCode2."\t".$parent2."\t".$rank2."\n";
		print NAME $defLine;
		
	}
	# scientific name and common name
	my $comname2;
	
	if (!$table[$txid][3][1] and !$table[$txid][3][2]){
		$comname2 = "NULL";
	} else {
		if ($table[$txid][3][1]){
			$comname2 = $table[$txid][3][1];
		} else {
			$comname2 = $table[$txid][3][2];
		}
	}
	$comname2 =~ s/\\/\\\\/g;
	$comname2 =~ s/'/\\'/g;
	$comname2 =~ s/%/\\%/g;
	
	my $taxallnomyLineage2 = join("\t", @taxallnomyLineage);
	$sciname =~ s/\\/\\\\/g;
	$sciname =~ s/'/\\'/g;
	$sciname =~ s/%/\\%/g;
	my $defLine = $txid."\t".$taxallnomyLineage2."\t".$sciname."\t".$comname2."\t$leaf\t$unclassified\t0\t$rank\n";
	print LIN $defLine;
	if (exists $merged{$txid}){
		foreach my $merged(keys %{$merged{$txid}{"merged"}}){
			my $defLine2 = $merged."\t".$taxallnomyLineage2."\t".$sciname."\t".$comname2."\t$leaf\t$unclassified\t1\t$rank\n";
			print LIN $defLine2;
		}
	}	
}

system ("mv taxallnomy* ..");
chdir "..";
system("rm -rf $dir");

print "All done!\n\n";
print "To load TaxAllnomy database in your MySQL just type the following command line:\n\n";
print "  > mysql -u <username> -p < taxallnomy.sql\n\n";
print "or in the MySQL environment:\n\n";
print "  mysql> source taxallnomy.sql\n\n";

sub generate_taxallnomy {

	my $or_lineage = $_[0];
	my @or_lineage = @$or_lineage;
	my @lineageEx;
	my @rankEx;
	my %lineageEx = ();
	my %lineageExRank = ();
	
	for (my $i = 0; $i < scalar @or_lineage; $i++){
		$lineageExRank{$rev_ncbi_all_ranks{$or_lineage[$i][1]}} = $i if ($or_lineage[$i][1] != -1);
		$lineageEx{$i}{"rank"} = $rev_ncbi_all_ranks{$or_lineage[$i][1]};
		$lineageEx{$i}{"name"} = $or_lineage[$i][4];
		$lineageEx{$i}{"possibleRanks"} = $or_lineage[$i][5] if (exists $or_lineage[$i][5]);
	}
	my $m = 0;
	my @lineageTaxAllnomy;
	for (my $i = 0; $i < scalar @ncbi_all_ranks; $i++){
		if (exists $lineageExRank{$ncbi_all_ranks[$i]}){ # ranked taxon
			$m = $lineageExRank{$ncbi_all_ranks[$i]};
			push (@lineageTaxAllnomy, $lineageEx{$m}{"name"});
			
		} else { # unranked taxon
			my $l = $m;
			my $append = 0.001;
			my $control = 0;
			while (exists($lineageEx{$l + 1}{"rank"})){
				if ($lineageEx{$l + 1}{"rank"} ne "no rank"){
					# verify if the searching rank level is below the current rank level
					if ($ncbi_all_ranks{$ncbi_all_ranks[$i]} < $ncbi_all_ranks{$lineageEx{$l + 1}{"rank"}}){
						$append = 0.002;
						$l++; # here
						$control = 1;
						last;
					} else {
						$l++;
					}
				} else {
					# verify if this no rank taxon can have the current rank level
					if (exists $lineageEx{$l + 1}{"possibleRanks"}){
						my @possibleRanks = @{$lineageEx{$l + 1}{"possibleRanks"}};
						my $maxPossibleRanks = $possibleRanks[0];
						my $minPossibleRanks = $possibleRanks[$#possibleRanks];
						
						if ($ncbi_all_ranks{$ncbi_all_ranks[$i]} >= $maxPossibleRanks and $ncbi_all_ranks{$ncbi_all_ranks[$i]} <= $minPossibleRanks){
							$l++;
							$control = 1;
							last;
						} elsif ($ncbi_all_ranks{$ncbi_all_ranks[$i]} < $maxPossibleRanks) {
							$l++; # here
							$control = 1;
							print $lineageEx{$l + 1}{"name"}."\n";
							last;
						} else {
							$l++;
						}
					} else {
						$l++;
					}
				}
			}
			if (!$control){
				$append = 0.003;
			}
			$append += $taxAllnomy_ranks{$ncbi_all_ranks[$i]};
			$append += $lineageEx{$l}{"name"};
			push (@lineageTaxAllnomy, $append);

		}
	}
		
	return \@lineageTaxAllnomy;
}
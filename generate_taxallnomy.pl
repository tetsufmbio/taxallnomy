#!/usr/bin/perl -w

# This script creates all files necessary to load Taxallnomy database on MySQL.
# Be aware that  its  execution  requires  internet  connection  and  consumes
# approximately 1Gb of HD space.

##############################################################################
#                                                                            #
#    Copyright (C) 2017-2020 Tetsu Sakamoto                                  #
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

# Version 1.7.1

##############################################################################
#                                                                            #
# Modification from version 1.4                                              #
#                                                                            #
# - Verify genus and species separatedely.                                   #
# - Rank priority.                                                           #
# - If there are more unranked node than rank to be assigned, evaluate if    #
# the node should have a rank assigned, or transfer rank to the next nodes.  #
# - Verifies redundant levels.                                               #
# - Verifies if there are unranked nodes with CR <= NP in the path to NA.    #
# - taxallnomy_lin_name table added.                                         #
# - script deal with rank update;                                            #
# - taxallnomy_tree_all table included;                                      #
# - taxallnomy_tree_original included;                                       #
# - taxallnomy_tax_data included;                                            #
# - generic input for local taxdump;                                         #
# - help added;                                                              #
# - Notifies if there is an inconsistency in the taxdump file;               #
# - tree_balanced table replaced by tree_complete;                           #
#                                                                            #
# Modification specific to version 1.6.0                                     #
# - "no rank" is considered as "clade"                                       #
#                                                                            #
# Modification specific to version 1.7.0                                     #
# - This version uses the rank order provided by NCBI Taxonomy in the paper  #
#   Schoch et al. (2020).                                                    #
#                                                                            #
#                                                                            #
# v1.7.1                                                                     #
# - Domain and Realm ranks included;                                         #
# - Superkingdom rank excluded.                                              #
#                                                                            #
##############################################################################

use strict;
use Data::Dumper;
use POSIX;
use Getopt::Long;
use Pod::Usage;

my $dir = "taxallnomy_data";
my $taxallnomy_version = "1.7.0";
my $version;
my $help;
my $man;
my $local_dump;

GetOptions(
    'local=s'=> \$local_dump,
	'out=s'=> \$dir,
    'help!'     	=> \$help,
	'version!'		=> \$version,
	'man!'			=> \$man,
) or pod2usage(-verbose => 99, 
            -sections => [ qw(NAME SYNOPSIS) ] );

pod2usage(0) if $man;
pod2usage(2) if $help;
if ($version){
	print $taxallnomy_version."\n";
	exit;
}

if(-d $dir){
	die "ERROR: Can't create the directory $dir. Probably because this directory exists in your current working directory.\n";
} else {
	system("mkdir $dir");
} 


if($local_dump){
	if (-e $local_dump){
		system("cp $local_dump $dir");
		chdir $dir;
		my @path = split(/\//, $local_dump);
		my $file_dump = pop(@path);
		if ($file_dump =~ /\.tar\.gz$/){
			system("tar -zxf $file_dump");
		} elsif ($file_dump =~ /\.zip$/){
			system("unzip $file_dump");
		} else {
			die "ERROR: Can't recognize as compressed file from NCBI Taxonomy.\n";
		}
		
	} else {
		die "ERROR: $local_dump is not a file.\n";
	}
} else {
	print "  Downloading taxdump.tar.gz... \n";
	system("wget -Nnv ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz");
	system("chmod u+w taxdump.tar.gz");
	if (!-e "taxdump.tar.gz"){
		die "ERROR: Couldn't find/download the file taxdump.tar.gz.\n"
	}
	print "  Making table... \n";
	system("cp taxdump.tar.gz $dir");
	chdir $dir;
	system("tar -zxf taxdump.tar.gz");
}

# verify files

if (-e "names.dmp" && -e "nodes.dmp" && -e "merged.dmp"){

} else {
	die "ERROR: Can't find one of those files: names.dmp, nodes.dmp or merged.dmp.\nPlease, check if those files are included in taxdump.tar.gz provided or downloaded.\n\n";
}

# taxonomy table

print "Making Taxonomy table file...\n";

# load rank info
my $ref_ncbi_ranks = rankOrder();
my %ncbi_ranks = %$ref_ncbi_ranks;

my @rankOrder =  @{$ncbi_ranks{"order"}};

my %ncbi_all_ranks = %{$ncbi_ranks{"name"}};

my %rev_ncbi_all_ranks = %{$ncbi_ranks{"level"}};

open(TXID, "< nodes.dmp") or die "ERROR: Can't open nodes.dmp"; 

my @table;	# table[$txid][0] - parent 
			# table[$txid][1] - rank (integer, start from 0) 
			# table[$txid][2] - [children]
			# table[$txid][3] - name (0 - scientific name; 1 - genbank common name; 2 - common name)
			# table[$txid][4] - txid
			# table[$txid][5] - possibleRanks (array, ranks start from 0)
			# table[$txid][6] - could be genus (position 0) or species (position 1)
			# table[$txid][7] - minRank (position 0) or maxRank (position 1)
			# table[$txid][8] - rank (text)
			# table[$txid][9] - 1 if unclassified txid

my @txid;
my %hash_rank;
my (%leaf, %parent); # determine leaf txid;

while(my $line = <TXID>){
	my @line = split(/\t\|\t/, $line);
	$table[$line[0]][4] = $line[0]; # txid
	$table[$line[0]][0] = $line[1] if ($line[0] != $line[1]); # parent
	
	$parent{$line[1]} = 1;
	if (!exists $parent{$line[0]}){
		$leaf{$line[0]} = 1;
	}
	if(exists $leaf{$line[1]}){
		delete $leaf{$line[1]};
	}
	
	if(exists $ncbi_all_ranks{$line[2]}){
		$table[$line[0]][8] = $ncbi_ranks{"level"}{$ncbi_all_ranks{$line[2]}{"level"}}; # rank name (synonymus replaced)
		$table[$line[0]][1] = $ncbi_all_ranks{$table[$line[0]][8]}{"level"}; # rank level
	} else {
		# new rank found;
		print "NOTE: new rank found on txid".$line[0].": ".$line[2]."\n";
		exit;
	}
	
	if (!$table[$line[1]][2]){
		$table[$line[1]][2][0] = $line[0] if ($line[0] != $line[1]); # children
	} else {
		$table[$line[1]][2][scalar @{$table[$line[1]][2]}] = $line[0] if ($line[0] != $line[1]); # children
	}
	
	push(@txid, $line[0]);
	
} 

close TXID;
my @leaf = keys %leaf;

open(TXIDNAME, "< names.dmp") or die "ERROR: Can't open names.dmp"; 

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

# Check if all taxonomic tree follows the rank hierarchy and annotate unclassified taxa
print "  Checking any inconsistence in taxonomic tree... \n";
my %rankCount;
my %inconsistence = ( "pair" => {}, "taxa" => {});
my $pairID = 1;

for(my $i = 0; $i < scalar @leaf; $i++){
	
	my $node = $leaf[$i];
	my $unclassControl = 0;
	my @ranksLineage;
	my @lineage;
	
	#next if ($table[$node][2]);
	#push(@leaf, $node); # store leaf txid
	
	my $rank2compare = $table[$node][1];
	my $nodeOfRank2compare = $node;
	if ($rank2compare == -1){
		$rank2compare = scalar @rankOrder;
	}
	
	while ($node != 1){	
		
		if(checkUnclass($table[$node][3][0])){
			$unclassControl = $node;
		}
		
		if ($table[$node][1] != -1){
			unshift(@ranksLineage, $table[$node][8]);			
			unshift(@lineage, $node);
		}
		
		if($table[$node][0]){
			my $parent = $table[$node][0];
			if ($table[$parent][1] != -1){
				if ($rank2compare <= $table[$parent][1]){
					# inconsistence found
					#print $nodeOfRank2compare."\t".$rev_ncbi_all_ranks{$rank2compare}."\t".$parent."\t".$rev_ncbi_all_ranks{$table[$parent][1]}."\n";
					$inconsistence{"pair"}{$pairID} = $parent.";".$nodeOfRank2compare;
					$inconsistence{"taxa"}{$parent}{"count"} += 1;
					$inconsistence{"taxa"}{$nodeOfRank2compare}{"count"} += 1;
					$inconsistence{"taxa"}{$parent}{"pair"} .= $pairID.";";
					$inconsistence{"taxa"}{$nodeOfRank2compare}{"pair"} .= $pairID.";";
					$pairID++;
					
				} else {
					$rank2compare = $table[$parent][1];
					$nodeOfRank2compare = $parent;
				}
			}
		}
				
		$node = $table[$node][0] if ($table[$node][0]);
	}
	
	# annotate unclassified txid
	if ($unclassControl){
		
		if (!$table[$leaf[$i]][9]){
			$node =  $unclassControl;
			$table[$node][9] = 1;
			my @unclassNodes;
			push(@unclassNodes, @{$table[$node][2]}) if ($table[$node][2]);
			while (scalar @unclassNodes > 0){
				$node = shift @unclassNodes;
				$table[$node][9] = 1;
				push(@unclassNodes, @{$table[$node][2]}) if ($table[$node][2]);
			}			
		}
	}
	
	if (scalar @ranksLineage > 0){ # changed here
		for(my $j = 0; $j < scalar @ranksLineage; $j++){
			# counting all and distinct taxa in each rank
			$rankCount{"all"}{$ranksLineage[$j]} += 1 if (!$unclassControl);
			$rankCount{"distinct"}{$ranksLineage[$j]}{$lineage[$j]} = 1 if (!$unclassControl);
			
			#for(my $k = $j+1; $k < scalar @ranksLineage; $k++){
			#	$rankOrder{$ranksLineage[$j]}{$ranksLineage[$k]} = 1;
			#	$stemOrder{$hash_allRankStem{$ranksLineage[$j]}}{$hash_allRankStem{$ranksLineage[$k]}} = 1 if ($hash_allRankStem{$ranksLineage[$j]} ne $hash_allRankStem{$ranksLineage[$k]});
			#}
		}
	} else {
		next;
	}
}

# establish rank priority
my @ncbi_rank_priority_general = sort {$rankCount{"all"}{$b} <=> $rankCount{"all"}{$a}} keys %{$rankCount{"all"}};
my %hash_rankPriority;
my $count2 = 1;
foreach my $rank(@ncbi_rank_priority_general){
	
	# for rank table;
	$hash_rankPriority{$rank} = $count2;
	$count2++;
}

# include zero ranks in @ncbi_rank_priority_general;
foreach my $rank(@rankOrder){
	if(!exists $hash_rankPriority{$rank}){
		$hash_rankPriority{$rank} = $count2;
		push(@ncbi_rank_priority_general, $rank);
		$count2++;
	}
}

# resolve inconsistence
while(scalar keys %{$inconsistence{"pair"}} > 0){
	
	# search for taxa which appears more in the inconsistence pairs
	my $n = 0;
	my $selectedTaxa;
	foreach my $taxa(keys %{$inconsistence{"taxa"}}){
		if($inconsistence{"taxa"}{$taxa}{"count"} > $n){
			$selectedTaxa = $taxa;
			$n = $inconsistence{"taxa"}{$taxa}{"count"};
		}
	}
	my @tax2remove;
	if ($n > 1){
		push(@tax2remove, $selectedTaxa);		
	} else {
		foreach my $pairID(keys %{$inconsistence{"pair"}}){
			my @taxa = split(";",$inconsistence{"pair"}{$pairID});
			my $taxa2remove;
			if ($hash_rankPriority{$ncbi_ranks{"level"}{$table[$taxa[0]][1]}} > $hash_rankPriority{$ncbi_ranks{"level"}{$table[$taxa[1]][1]}}){
				$taxa2remove = $taxa[0];
			} else {
				$taxa2remove = $taxa[1];
			}
			push(@tax2remove, $taxa2remove);
		}
	}
	
	foreach my $tax2remove(@tax2remove){
		my $pairIDset = $inconsistence{"taxa"}{$tax2remove}{"pair"};
		chop $pairIDset;
		my @pairIDset = split(";", $pairIDset);
		foreach my $pairID(@pairIDset){
			if (exists $inconsistence{"pair"}{$pairID}){
				my @taxa = split(";",$inconsistence{"pair"}{$pairID});
				$inconsistence{"taxa"}{$taxa[0]}{"count"} -= 1;
				$inconsistence{"taxa"}{$taxa[1]}{"count"} -= 1;
				delete $inconsistence{"taxa"}{$taxa[0]} if ($inconsistence{"taxa"}{$taxa[0]}{"count"} == 0);
				delete $inconsistence{"taxa"}{$taxa[1]} if ($inconsistence{"taxa"}{$taxa[1]}{"count"} == 0);
				delete $inconsistence{"pair"}{$pairID};
			}			
		}

		# correct count after checking inconsistence
		if (!$table[$tax2remove][9]){ # check if it is an unclassified taxon
			delete $rankCount{"distinct"}{$table[$tax2remove][8]}{$tax2remove};
			my $countLeaf = 0;
			if ($table[$tax2remove][2]){
				my @unclassNodes;
				push(@unclassNodes, @{$table[$tax2remove][2]});
				while (scalar @unclassNodes > 0){
					my $node = shift @unclassNodes;
					next if ($table[$node][9]);
					if ($table[$node][2]){
						push(@unclassNodes, @{$table[$node][2]});
					} else {
						$countLeaf++;
					}
				}
				
			} else {
				$countLeaf++;
			}
			$rankCount{"all"}{$table[$tax2remove][8]} -= $countLeaf;
			
		}
		print "NOTE: ".$tax2remove." had its rank (".$table[$tax2remove][8].") set to clade to avoid inconsistence in the rank hierarchy.\n";
		$table[$tax2remove][1] = -1;
		$table[$tax2remove][8] = "clade";
		
	}
}

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

my @genus2analyse;
my @species2analyse;

# Determine possible ranks to unranked taxa
print "  Determining possible ranks to unranked taxa...\n";
foreach my $rank2analyse(@rankOrder){
	
	my @nodes2analyse;
	push (@nodes2analyse, 1);
	my $rank2analyseInt = $ncbi_all_ranks{$rank2analyse}{"level"};
	
	while(scalar @nodes2analyse != 0){
	
		my $node = shift @nodes2analyse;
		
		if ($table[$node][1] != -1){ # ranked taxon
		
			next if ($rank2analyseInt <= $table[$node][1]);
			push(@nodes2analyse, @{$table[$node][2]}) if ($table[$node][2]);
			
		#} elsif (checkUnclass($table[$node][3][0])){ # unclassified taxon, keep it as no rank.
		
		#	push(@nodes2analyse, @{$table[$node][2]}) if ($table[$node][2]);
			
		} else { # unranked taxon
			
			if (!$table[$node][7][0]){
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
				my $minRank = scalar @rankOrder; 
				while(scalar @nodes2analyse2 != 0){
					my $node2 = shift @nodes2analyse2;
					if ($table[$node2][1] == -1){
						push(@nodes2analyse2, @{$table[$node2][2]}) if ($table[$node2][2]);
					} else {
						$minRank = $table[$node2][1] if ($minRank > $table[$node2][1]);
					}
				}
				
				$table[$node][7][0] = $maxRank;
				$table[$node][7][1] = $minRank;
			}
			my $maxRank2 = $table[$node][7][0];
			my $minRank2 = $table[$node][7][1];
			
			if ($rank2analyseInt > $maxRank2 && $rank2analyseInt < $minRank2){
				my @possibleRanks;
				@possibleRanks = @{$table[$node][5]} if ($table[$node][5]);
				push(@possibleRanks, $rank2analyseInt);				
				$table[$node][5] = \@possibleRanks;
				if ($rank2analyseInt == $ncbi_all_ranks{"genus"}{"level"}){
					push(@genus2analyse, $node);
				} elsif ($rank2analyseInt == $ncbi_all_ranks{"species"}{"level"}){
					push(@species2analyse, $node);
				}
			} else {
				push(@nodes2analyse, @{$table[$node][2]}) if ($table[$node][2]);
			} 
		}
	}
}

# verify genus
print "  Verifying genus...\n";
my (@yesGenus, @noGenus, @yesSpecies, @noSpecies);
while (scalar @genus2analyse > 0){
	my $node = shift @genus2analyse;
	# This node could be a genus	
	# pick its species
	my @nodes2analyse6;	
	push(@nodes2analyse6, $node);
	while(scalar @nodes2analyse6 > 0){
		my $node4 = shift @nodes2analyse6;
		#my $control = 0;
		my $controlSpecies = 0;
		my $genusName = $table[$node4][3][0];
		if(checkUnclass($genusName)){ # verify if this represents an unclassified or an environmental sample.
			my @nodes2analyse5;	
			push (@nodes2analyse5, @{$table[$node4][2]}) if $table[$node4][2];
			while(scalar @nodes2analyse5 > 0){
				my $node3 = shift @nodes2analyse5;
				if($table[$node3][1] != -1){
					# ranked taxon
					if ($table[$node3][1] < $ncbi_all_ranks{"species"}{"level"}){
						push (@nodes2analyse5, @{$table[$node3][2]}) if $table[$node3][2];
					} elsif ($table[$node3][1] == $ncbi_all_ranks{"species"}{"level"}){
						# it is a species
						$controlSpecies = 1;
						last;
					} else {
						next;
					}
				} else {
					push (@nodes2analyse6, $node3);
					push (@nodes2analyse5, @{$table[$node3][2]}) if $table[$node3][2];
				}
			}	
		}
		

		if($controlSpecies){
			# the node $node maybe a genus
			$table[$node4][6][0] = 1;
			push(@yesGenus, $table[$node4][3][0]);
		} else {
			$table[$node4][6][0] = 0;
			push(@noGenus, $table[$node4][3][0]);
			
			# modify the possible ranks of this node
			if ($table[$node4][5]){
				my @possibleRanksCurrent = @{$table[$node4][5]};
				my @newPossibleRanksCurrent;
				my @transferPossibleRanks;
				for(my $i = 0; $i < scalar @possibleRanksCurrent; $i++){
					if ($possibleRanksCurrent[$i] < $ncbi_all_ranks{"genus"}{"level"}) {
						push(@newPossibleRanksCurrent, $possibleRanksCurrent[$i]);
					} else {
						push(@transferPossibleRanks, $possibleRanksCurrent[$i]);
					}
				}
				$table[$node4][5] = undef;
				$table[$node4][5] = \@newPossibleRanksCurrent if (scalar @newPossibleRanksCurrent > 0);
				$table[$node4][7][1] = $ncbi_all_ranks{"genus"}{"level"};
				# transfer the ranks to child unranked nodes
				if ($table[$node4][2]){
					my @nodes2analyseChild;
					push(@nodes2analyseChild, @{$table[$node4][2]});
					while(scalar @nodes2analyseChild > 0){
						my $nodeChild = shift @nodes2analyseChild;
						if($table[$nodeChild][1] == -1){
							push(@nodes2analyseChild, @{$table[$nodeChild][2]}) if ($table[$nodeChild][2]);
							$table[$node4][7][1] = $ncbi_all_ranks{"genus"}{"level"};
							$table[$nodeChild][5] = undef;
						} else {
							next;
						}
					}			
				}
			}
		}
	}		
}

# verify species
print "  Verifying species...\n";
while (scalar @species2analyse > 0){
	my $node = shift @species2analyse;
	# This node could be a species
	# pick its genus
	my @nodes2analyse4;
	push(@nodes2analyse4, $table[$node][0]);
	my $genusName;
	my $control = 0;
	my $putativeSpeciesName = $table[$node][3][0];
	if(checkUnclass($putativeSpeciesName)){ # verify if this represents an unclassified or an environmental sample.
		while(scalar @nodes2analyse4 > 0){
			my $node2 = shift @nodes2analyse4;
			if($table[$node2][1] != -1){
				# ranked taxon
				if ($table[$node2][1] > $ncbi_all_ranks{"genus"}{"level"}){
					push (@nodes2analyse4, $table[$node2][0]);
				} elsif ($table[$node2][1] == $ncbi_all_ranks{"genus"}{"level"}){
					# it is a genus
					$genusName = $table[$node2][3][0];
					
					$control = 1;
					last;
				} else {
					last;
				}
			} else {
				if ($table[$node2][0]){
					push (@nodes2analyse4, $table[$node2][0]);
				} else {
					last;
				}
			}
		}
	}
	
	
	if($control){
		# genus found, verify if it can be species
		my @nodes2analyse6;	
		push(@nodes2analyse6, $node);
		while(scalar @nodes2analyse6 > 0){
			my $node4 = shift @nodes2analyse6;
			next if ($table[$node4][1] != -1);
			my $putativeSpeciesName = $table[$node4][3][0];
			# verify if it is in the group of unclassified
			if(checkUnclass($putativeSpeciesName)){ # verify if this represents an unclassified or an environmental sample.
				$table[$node4][6][0] = 0;
				push(@noSpecies, $table[$node4][3][0]);
				push (@nodes2analyse6, @{$table[$node4][2]}) if $table[$node4][2];
				$table[$node4][7][1] = $ncbi_all_ranks{"species"}{"level"};
				# modify the possible ranks of this node
				if ($table[$node4][5]){
					my @possibleRanksCurrent = @{$table[$node4][5]};
					my @newPossibleRanksCurrent;
					my @transferPossibleRanks;
					for(my $i = 0; $i < scalar @possibleRanksCurrent; $i++){
						if ($possibleRanksCurrent[$i] < $ncbi_all_ranks{"species"}{"level"}) {
							push(@newPossibleRanksCurrent, $possibleRanksCurrent[$i]);
						} else {
							push(@transferPossibleRanks, $possibleRanksCurrent[$i]);
						}
					}
					$table[$node4][5] = undef;
					$table[$node4][5] = \@newPossibleRanksCurrent if (scalar @newPossibleRanksCurrent > 0);
					
					# transfer the ranks to child unranked nodes
					if (scalar @transferPossibleRanks > 0){
						my @nodes2analyseChild;
						push(@nodes2analyseChild, @{$table[$node4][2]}) if ($table[$node4][2]);
						while(scalar @nodes2analyseChild > 0){
							my $nodeChild = shift @nodes2analyseChild;
							if($table[$nodeChild][1] == -1){
								#push(@nodes2analyseChild, @{$table[$nodeChild][2]}) if ($table[$nodeChild][2]);
								my @newPossibleRanks = @transferPossibleRanks;
								if($table[$nodeChild][5]){
									my @possibleRanksChild = @{$table[$nodeChild][5]};
									my $lowestRank = $newPossibleRanks[$#newPossibleRanks];
									for(my $j = 0; $j < scalar @possibleRanksChild; $j++){
										push(@newPossibleRanks, $possibleRanksChild[$j]) if ($possibleRanksChild[$j] > $lowestRank);
									}
									$table[$nodeChild][5] = undef;
								}
								$table[$nodeChild][5] = \@newPossibleRanks if (scalar @newPossibleRanks > 0);
							} else {
								next;
							}
						}			
					}
				}
				
			} else {
				$table[$node][6][0] = 1;
				push(@yesSpecies, $table[$node][3][0]);
			}
		}
	} else {
		$table[$node][6][0] = 0;
		push(@noSpecies, $table[$node][3][0]);
		$table[$node][7][1] = $ncbi_all_ranks{"species"}{"level"};
		# modify the possible ranks of this node
		if ($table[$node][5]){
			my @possibleRanksCurrent = @{$table[$node][5]};
			my @newPossibleRanksCurrent;
			my @transferPossibleRanks;
			for(my $i = 0; $i < scalar @possibleRanksCurrent; $i++){
				if ($possibleRanksCurrent[$i] < $ncbi_all_ranks{"species"}{"level"}) {
					push(@newPossibleRanksCurrent, $possibleRanksCurrent[$i]);
				} else {
					push(@transferPossibleRanks, $possibleRanksCurrent[$i]);
				}
			}
			$table[$node][5] = undef;
			$table[$node][5] = \@newPossibleRanksCurrent if (scalar @newPossibleRanksCurrent > 0);
			
			# transfer the ranks to child unranked nodes
			if (scalar @transferPossibleRanks > 0){
				my @nodes2analyseChild;
				push(@nodes2analyseChild, @{$table[$node][2]}) if ($table[$node][2]);
				while(scalar @nodes2analyseChild > 0){
					my $nodeChild = shift @nodes2analyseChild;
					if($table[$nodeChild][1] == -1){
						push(@nodes2analyseChild, @{$table[$nodeChild][2]}) if ($table[$nodeChild][2]);
						my @newPossibleRanks = @transferPossibleRanks;
						if($table[$nodeChild][5]){
							my @possibleRanksChild = @{$table[$nodeChild][5]};
							my $lowestRank = $newPossibleRanks[$#newPossibleRanks];
							for(my $j = 0; $j < scalar @possibleRanksChild; $j++){
								push(@newPossibleRanks, $possibleRanksChild[$j]) if ($possibleRanksChild[$j] > $lowestRank);
							}
							$table[$nodeChild][5] = undef;
						}
						$table[$nodeChild][5] = \@newPossibleRanks if (scalar @newPossibleRanks > 0);
					} else {
						next;
					}
				}			
			}
		}
		
	}
			
}

sub nodeTest {
	my $node2test = $_[0];
	my @node2test;
	push(@node2test, $node2test);
	while(scalar @node2test > 0){
		my $node = shift @node2test;
		push (@node2test, $table[$node][0]) if($table[$node][0]);
		print $table[$node][3][0]."\t";
		if ($table[$node][5]){
			my @possibleRanks = @{$table[$node][5]};
			print join(",", @possibleRanks);
		}
		print "\n";
	}
}

# Assign rank to unranked taxa
print "  Assigning rank to unranked taxa...\n";
my @nodes2analyse3 = @{$table[1][2]};
while (scalar @nodes2analyse3 != 0){
	my $node = shift @nodes2analyse3;
	push (@nodes2analyse3, @{$table[$node][2]}) if $table[$node][2];
	next if($table[$node][1] != -1); # next if ranked taxon

	next if(!$table[$node][5]); # next if it is an unranked taxon without possible ranks
	my @possibleRanks = @{$table[$node][5]};
	my $countRanks = scalar @possibleRanks;
	# in this point we are analyzing an unranked taxon with one or more possible ranks that it could be assigned.
	my @layer;
	push(@layer, @{$table[$node][2]}) if (exists $table[$node][2]);
			
	my $countDepth = 1; # store the number of level of the longest path of consecutive unranked taxa.
	my $countMinDepth = 1; # store the number of level of the shortest path of consecutive unranked taxa.
	my $minDepthRankLevel = 0; # store the max level on the shortest path of consecutive unranked taxa.
	my $controlMinDepth = 0;
	my $controlLeafUnranked = 0;
	my $controlRanked = 0;
	my $controlCandMinusUnRanked = 0;
	$controlCandMinusUnRanked = 1 if ($countRanks == 1);
	my $controlPossible = 0;
	my $depthPossible = 0; # store the number of level of unranked taxa without candidate ranks.
	my $maxRankLevel = $possibleRanks[0]; # highest level that this node can assume.
	my $minRankLevel = scalar @rankOrder - 1; # store the min level on the longest path of consecutive unranked taxa.
	while(scalar @layer != 0){
		my @layer2;	
		my $control = 0;
		my $minRankLevel2 = scalar @rankOrder - 1;
		while(scalar @layer != 0){
			my $layer2 = shift @layer;
			#if ($table[$layer2][1] == -1 && !$table[$layer2][6][0] && !$table[$layer2][6][1]){
			if ($table[$layer2][1] == -1){
				if(checkUnclass($table[$layer2][3][0])){ # verify if this represents an unclassified or an environmental sample.
					$control = 1;
					if (exists $table[$layer2][2]){
						push (@layer2, @{$table[$layer2][2]});
					} else {
						$controlLeafUnranked = 1;
					}
					my $rankLevel = scalar @rankOrder - 1;
					$rankLevel = $table[$layer2][7][1] if ($table[$layer2][7][1]);
					if ($minRankLevel2 > $rankLevel){
						$minRankLevel2 = $rankLevel;
					}
					if (!$controlCandMinusUnRanked){
						if ($rankLevel - $maxRankLevel + 1 - ($countDepth + 1) <= 0){
							$controlCandMinusUnRanked = 1;
						}
					}
							
					$controlPossible = 1 if ($table[$layer2][5]);
				}
			} else	{
				$controlPossible = 1;
				$controlRanked = 1;
				$controlMinDepth = 1 if (!$controlMinDepth);
				if ($controlMinDepth == 1){
					if ($minDepthRankLevel < $table[$layer2][1]){
						$minDepthRankLevel = $table[$layer2][1];
					}
				}
			}
		}
		$countDepth++ if ($control);
		$depthPossible++ if (!$controlPossible and $control);
		$countMinDepth++ if (!$controlMinDepth);
		$controlMinDepth++ if ($controlMinDepth);
		$minRankLevel = $minRankLevel2 if ($control);
		if ($controlLeafUnranked){
			$controlPossible = 1;
			$controlMinDepth = 1;
		}
		@layer = @layer2;
	}
	my $nPossibleRanks = $minRankLevel + 1 - $maxRankLevel;		
	#print $node."\t".$countDepth."\t".join(",",@possibleRanks)."\t".$depthPossible."\t".$countMinDepth."\t".$minRankLevel."\t".$maxRankLevel."\n" if ($depthPossible >= scalar @possibleRanks);
			
	if ($depthPossible >= scalar @possibleRanks){
		# transfer ranks to the children nodes;
		#print $node."\t".$countDepth."\t".join(",",@possibleRanks)."\t".$depthPossible."\t".$countMinDepth."\t".$minRankLevel."\t".$maxRankLevel."\n";
		$table[$node][5] = undef;
		if ($table[$node][2]){
			my $lowestRank = $possibleRanks[$#possibleRanks];
			my @ranks2transfer = @possibleRanks;
			my @childrenNodes = @{$table[$node][2]};
			foreach my $child(@childrenNodes){	
				my @possibleRanks3 = @ranks2transfer;
				if ($table[$child][1] == -1){
					if ($table[$child][5]){
						my @possibleRanks2 = @{$table[$child][5]};
						for(my $k = 0; $k < scalar @possibleRanks2; $k++){
							if ($possibleRanks2[$k] > $lowestRank){
								push (@possibleRanks3, $possibleRanks2[$k]);
							}
						}
					}
					$table[$child][5] = \@possibleRanks3;
				}
			}
		}
	} elsif ($controlCandMinusUnRanked){
		#print $node."\tcontrolCand\t".$table[$node][8]."\n" if (scalar @possibleRanks > 1);
		# assign the highest rank to the unranked taxon and transfer the other to its children unranked taxa
		my $highestRank = shift @possibleRanks;
		my @newPossibleRanks = ($highestRank);
		$table[$node][5] = \@newPossibleRanks;
		if ($table[$node][2] && scalar @possibleRanks > 0){
			my $lowestRank = $possibleRanks[$#possibleRanks];
			my @ranks2transfer = @possibleRanks;
			my @childrenNodes = @{$table[$node][2]};
			foreach my $child(@childrenNodes){	
				my @possibleRanks3 = @ranks2transfer;
				if ($table[$child][1] == -1){
					if ($table[$child][5]){
						my @possibleRanks2 = @{$table[$child][5]};
						for(my $k = 0; $k < scalar @possibleRanks2; $k++){
							if ($possibleRanks2[$k] > $lowestRank){
								push (@possibleRanks3, $possibleRanks2[$k]);
							}
						}
					}
					$table[$child][5] = \@possibleRanks3;
				}
			}
		}
		
	} else {
		# verify which rank should be assigned to this taxon according to the rank priority
		my %possibleRanks2analyse;
		
		for(my $i = $maxRankLevel; $i <= $minRankLevel; $i++){
			$possibleRanks2analyse{$i} = 1;
		}
		#print join(",",@possibleRanks)."\n" if ($node == 198600 or $node == 12877);
		#print "Depth: ".$countDepth."\n" if ($node == 198600 or $node == 12877);
		#print "minRankLevel: ".$minRankLevel."\n" if ($node == 198600 or $node == 12877);
		#print "nPossibleRanks: ".$nPossibleRanks."\n" if ($node == 198600 or $node == 12877);
		my %possibleRanksInNode;
		@possibleRanksInNode{@possibleRanks} = 1;
		my @rank2assign;
		my $control = 0;
		#my $nodeSuperkingdom = $table[$node][8];
		my @ncbi_rank_priority = @ncbi_rank_priority_general;
		foreach my $rankPrio(@ncbi_rank_priority){
			if (exists $possibleRanks2analyse{$ncbi_all_ranks{$rankPrio}{"level"}}){
				push(@rank2assign, $ncbi_all_ranks{$rankPrio}{"level"});
				$control = 1 if (exists $possibleRanksInNode{$ncbi_all_ranks{$rankPrio}{"level"}});
				last if (scalar @rank2assign >= $countDepth and $control);
			}
		}
		#print join(",",@rank2assign)."\n" if ($node == 198600 or $node == 12877);
		@rank2assign = sort { $a <=> $b } @rank2assign;
		my $rank2assign;
		foreach my $rank2assign2(@rank2assign){
			if (exists $possibleRanksInNode{$rank2assign2}){
				$rank2assign = $rank2assign2;
				last;
			}
		}
		my $lowestRank = $possibleRanks[$#possibleRanks];
		my @newPossibleRanks = ($rank2assign);
		$table[$node][5] = \@newPossibleRanks;
		if ($lowestRank > $rank2assign){			
			if ($table[$node][2]){
				my @ranks2transfer;
				for(my $i = $rank2assign + 1; $i <= $lowestRank; $i++){
					push(@ranks2transfer, $i);
				}
				#print join(",", @ranks2transfer)."\n" if ($node == 198600 or $node == 12877);
				my @childrenNodes = @{$table[$node][2]};
				foreach my $child(@childrenNodes){	
					my @possibleRanks3 = @ranks2transfer;
					if ($table[$child][1] == -1){
						if ($table[$child][5]){
							my @possibleRanks2 = @{$table[$child][5]};
							for(my $k = 0; $k < scalar @possibleRanks2; $k++){
								if ($possibleRanks2[$k] > $lowestRank){
									push (@possibleRanks3, $possibleRanks2[$k]);
								}
							}
						}
						$table[$child][5] = \@possibleRanks3;
						#print $table[$child][3][0]."," if ($node == 198600 or $node == 12877);
						#print join(",", @possibleRanks3)."\n" if ($node == 198600 or $node == 12877);
					}
				}
			}
		}
	}			
}

print "  Writing table... \n";

#open(DUMP, "> taxallnomy.sql") or die;
open(LIN, "> taxallnomy_lin.tab") or die;
open(LINSQL, "> taxallnomy_lin.sql") or die;
open(RANK, "> taxallnomy_rank.tab") or die;
open(RANKSQL, "> taxallnomy_rank.sql") or die;
open(LINNAME, "> taxallnomy_lin_name.tab") or die;
open(LINNAMESQL, "> taxallnomy_lin_name.sql") or die;
open(TREE, "> taxallnomy_tree_complete.tab") or die;
open(TREESQL, "> taxallnomy_tree_complete.sql") or die;
open(TREEORI, "> taxallnomy_tree_original.tab") or die;
open(TREEORISQL, "> taxallnomy_tree_original.sql") or die;
open(TREEUNB, "> taxallnomy_tree_all.tab") or die;
open(TREEUNBSQL, "> taxallnomy_tree_all.sql") or die;
open(TAXDATA, "> taxallnomy_tax_data.tab") or die;
open(TAXDATASQL, "> taxallnomy_tax_data.sql") or die;

my $dumpHead = '
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

';

# sql for lineage table
print LINSQL $dumpHead.'
--
-- Table structure for table `lin`
--

DROP TABLE IF EXISTS `lin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lin` (
  `txid` int(11) NOT NULL,
';
foreach my $rank(@rankOrder){
	print LINSQL "  `".$rank."` DECIMAL(20,3) NOT NULL,\n"
}

print LINSQL  '  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_lin.tab\' INTO TABLE lin;
';

# sql for lineage name table
print LINNAMESQL $dumpHead.'
--
-- Table structure for table `lin_name`
--

DROP TABLE IF EXISTS `lin_name`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lin_name` (
  `txid` int(11) NOT NULL,
';
foreach my $rank(@rankOrder){
	print LINNAMESQL "  `".$rank."` VARCHAR(200) NOT NULL,\n"
}

print LINNAMESQL  '  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_lin_name.tab\' INTO TABLE lin_name;
';

# sql for tree_complete table
print TREESQL $dumpHead.'
--
-- Table structure for table `tree_complete`
--

DROP TABLE IF EXISTS `tree_complete`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tree_complete` (
  `txid` DECIMAL(20,3) NOT NULL,
  `parent`DECIMAL(20,3) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

ALTER TABLE `tree_complete` ADD INDEX `parent` (`parent`);

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_tree_complete.tab\' INTO TABLE tree_complete;

';

# sql for tree_original table
print TREEORISQL $dumpHead.'
--
-- Table structure for table `tree_original`
--

DROP TABLE IF EXISTS `tree_original`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tree_original` (
  `txid` int(11) NOT NULL,
  `parent` int(11) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

ALTER TABLE `tree_original` ADD INDEX `parent` (`parent`);

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_tree_original.tab\' INTO TABLE tree_original;

';


# sql for tree with no candidate rank taxon table
print TREEUNBSQL $dumpHead.'
--
-- Table structure for table `tree_all`
--

DROP TABLE IF EXISTS `tree_all`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tree_all` (
  `txid` DECIMAL(20,3) NOT NULL,
  `parent` DECIMAL(20,3) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

ALTER TABLE `tree_all` ADD INDEX `parent` (`parent`);

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_tree_all.tab\' INTO TABLE tree_all;

';

# sql for tax data
print TAXDATASQL $dumpHead.'
--
-- Table structure for table `tax_data`
--

DROP TABLE IF EXISTS `tax_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tax_data` (
  `txid` int(11) NOT NULL,
  `rank` int(2) NOT NULL,
  `rank_type` tinyint(1) NOT NULL,
  `name` varchar(200) NOT NULL,
  `comname` varchar(200),
  `unclassified` int(11),
  `merged` int(11),
  `leaf` int(11),
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_tax_data.tab\' INTO TABLE tax_data;

';

# sql for rank table
print RANKSQL $dumpHead.'

--
-- Table structure for table `rank`
--

DROP TABLE IF EXISTS `rank`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rank` (
  `rank` VARCHAR(20) NOT NULL,
  `order` INT NOT NULL,
  `priority` INT NOT NULL,
  `code` VARCHAR(3) NOT NULL,
  `abbrev` VARCHAR(10) NOT NULL,
  `dcount_ncbi`INT NOT NULL,
  `dcount_type1`INT NOT NULL,
  `dcount_type2`INT NOT NULL,
  `dcount_type3`INT NOT NULL,
  `count_ncbi`INT NOT NULL,
  `count_type1`INT NOT NULL,
  `count_type2`INT NOT NULL,
  `count_type3`INT NOT NULL,
  PRIMARY KEY (`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_rank.tab\' INTO TABLE rank;

';


my %typeCode = (
	1 => "",
	2 => "of_",
	3 => "in_",
);

my %taxallnomy_tree;
#$taxallnomy_tree{1}{"parent"} = "\\N";
#$taxallnomy_tree{1}{"sciname"} = "root";
#$taxallnomy_tree{1}{"comname"} = "all";
#$taxallnomy_tree{1}{"rank"} = -1;

my %taxallnomy_treeAll;
#$taxallnomy_treeAll{1}{"parent"} = "\\N";
#$taxallnomy_treeAll{1}{"sciname"} = "root";
#$taxallnomy_treeAll{1}{"comname"} = "all";
#$taxallnomy_treeAll{1}{"rank"} = -1;

#my %taxallnomy_treeNoNode23;
#$taxallnomy_treeNoNode23{1}{"parent"} = "\\N";
#$taxallnomy_treeNoNode23{1}{"sciname"} = "root";
#$taxallnomy_treeNoNode23{1}{"comname"} = "all";
#$taxallnomy_treeNoNode23{1}{"rank"} = -1;

my @insert;
my %rankCountType;
foreach my $rank(@rankOrder){
	for(my $i = 0; $i < 4; $i++){
		$rankCountType{"all"}{$rank}{$i} = 0;
		$rankCountType{"distinct"}{$rank}{$i} = ();
	}
}

print TREEUNB "1\t\0\n";
print TREE "1\t\0\n";

my $nRanks = scalar @rankOrder;
my $nRanksLength = length $nRanks;
my $format = "%0".$nRanksLength."d";

foreach my $txid(@leaf){
	my @lineage;
	my $species = $txid;
 	my $rank = $rev_ncbi_all_ranks{$table[$species][1]};
	my $leaf = 0;
 	my $sciname = $table[$species][3][0];
 	my $parent = $table[$species][0];
	
	unshift (@lineage, [@{$table[$species]}]);
	#my $unclassified = 0;
	while($species != 1){
		#if(checkUnclass($table[$species][3][0])){ # verify if this represents an unclassified or an environmental sample.
		#	$unclassified = 1;
		#}
		$species = $parent;
 		$parent = $table[$species][0];
		unshift (@lineage, [@{$table[$species]}]);
	}
	
	my $currRank = 1;
	my @taxallnomyLineage;
	my @taxallnomyLineageUnb;
	for(my $i = 0; $i < scalar @lineage; $i++){
		if ($i == scalar @lineage - 1){
			$leaf = 1;
		}
		if ($lineage[$i][1] != -1){
			# ranked taxon
			while($currRank < $lineage[$i][1]+1){
				my $rankAdd = ($currRank/100)+0.002;
				my $taxonAdd = $lineage[$i][4] + $rankAdd;
				push(@taxallnomyLineage, $taxonAdd);
				push(@taxallnomyLineageUnb, $taxonAdd);
				$currRank++;
			}
			push(@taxallnomyLineage, $lineage[$i][4]);
			push(@taxallnomyLineageUnb, $lineage[$i][4]);
			$currRank++;
			
		} else {
			# unranked taxon
			if ($lineage[$i][5]){
				# unranked taxon with rank assigned
				my @possibleRank = @{$lineage[$i][5]};
				my $possibleRank = $possibleRank[0] + 1;
				while($currRank < $possibleRank){
					my $rankAdd = ($currRank/100)+0.002;
					my $taxonAdd = $lineage[$i][4] + $rankAdd;
					push(@taxallnomyLineage, $taxonAdd);
					push(@taxallnomyLineageUnb, $taxonAdd);
					$currRank++;
				}
				my $taxonAdd2 = ($possibleRank/100)+0.001+$lineage[$i][4];
				push(@taxallnomyLineage, $taxonAdd2);
				push(@taxallnomyLineageUnb, $lineage[$i][4]);
				$currRank++;
				
			} else {
				# unranked taxon without rank assigned
				#next;
				push(@taxallnomyLineageUnb, $lineage[$i][4]);
			}
		}
		
		if(!exists $taxallnomy_tree{$lineage[$i][4]}){
			$taxallnomy_tree{$lineage[$i][4]} = 1;
			my $parent2 = "\\N";
			my $txidCode2 = $lineage[$i][4];
			$parent2 = $table[$txidCode2][0] if ($table[$txidCode2][0]);
			my $rank2 = $table[$txidCode2][1];
			my $rankName2 = $rev_ncbi_all_ranks{$table[$txidCode2][1]};
			my $rankType = 0;
			if ($rank2 == -1){
				if ($table[$txidCode2][5]){
					my @possibleRanks = @{$table[$txidCode2][5]};
					$rank2 = $possibleRanks[0] + 1;
					$rankType = 1;
				}
			} else {
				$rank2++;
			}
			my $unclassified = 0;
			$unclassified = 1 if ($table[$txidCode2][9]);
			
			my $name2 = $table[$txidCode2][3][0];
			my $comname2 = "\\N";			
			if ($table[$txidCode2][3][1]){
				$comname2 = $table[$txidCode2][3][1];
			} elsif ($table[$txidCode2][3][2]) {
				$comname2 = $table[$txidCode2][3][2];
			}
			
			#my $defLine = $txidCode2."\t".$parent2."\t".$rank2."\t".$name2."\t".$parent_name."\t".$txid_syn."\t".$name_syn."\t".$parent_syn."\t".$parent_syn_name."\n";
			my $defLine = $txidCode2."\t".$parent2."\n";
			print TREEORI $defLine;
			$defLine = $txidCode2."\t".$rank2."\t".$rankType."\t".$name2."\t".$comname2."\t".$unclassified."\t\\N\t".$leaf."\n";
			print TAXDATA $defLine;
			my @taxallnomyLineage2 = @taxallnomyLineage;
			while(scalar @taxallnomyLineage2 < scalar @rankOrder){
				my $rank3txidCode = $txidCode2 + 0.003 + (scalar @taxallnomyLineage2 + 1)/100;
				push(@taxallnomyLineage2, $rank3txidCode);
			}
			my $taxallnomyLineage2 = join("\t", @taxallnomyLineage2);
			$defLine = $txidCode2."\t".$taxallnomyLineage2."\n";
			print LIN $defLine;
			
			my @taxallnomyLineageName;
			foreach my $taxon(@taxallnomyLineage2){
				my $name = getName($taxon);
				push(@taxallnomyLineageName, $name);
			}
			my $taxallnomyLineageName = join("\t", @taxallnomyLineageName);
			$defLine = $txidCode2."\t".$taxallnomyLineageName."\n";
			print LINNAME $defLine;
			
			if ($leaf and $unclassified == 0){
				for(my $j = 0; $j < scalar @taxallnomyLineage2; $j++){
					if ($taxallnomyLineage2[$j] =~ /\.(\d{2})(\d)$/){
						my $rankCode = $1;
						my $rankType = $2;
						#if ($rankType != 0){
						$rankCountType{"distinct"}{$ncbi_ranks{"code"}{$1}{"rank"}}{$2}{$taxallnomyLineage2[$j]} = 1;
						$rankCountType{"all"}{$ncbi_ranks{"code"}{$1}{"rank"}}{$2} += 1;
						#}
					} else {
						my $code = sprintf($format, $j+1);
						$rankCountType{"distinct"}{$ncbi_ranks{"code"}{$code}{"rank"}}{0}{$taxallnomyLineage2[$j]} = 1;
						$rankCountType{"all"}{$ncbi_ranks{"code"}{$code}{"rank"}}{0} += 1;
					}
				}
			}
			
			if (exists $merged{$txidCode2}){
				foreach my $merged(keys %{$merged{$txidCode2}{"merged"}}){
					my $defLine2 = $merged."\t".$taxallnomyLineage2."\n";
					print LIN $defLine2;
					$defLine2 = $merged."\t".$taxallnomyLineageName."\n";
					print LINNAME $defLine2;
					my $defLine4 = $merged."\t".$parent2."\n";
					print TREEORI $defLine4;
					my $defLine5 = $merged."\t".$rank2."\t".$rankType."\t".$name2."\t".$comname2."\t".$unclassified."\t".$txidCode2."\t".$leaf."\n";
					print TAXDATA $defLine5;
				}
			}	
		}
	}

	# generate tree_all and tree
	for(my $i = 1; $i < scalar @taxallnomyLineageUnb; $i++){
		next if (exists $taxallnomy_treeAll{$taxallnomyLineageUnb[$i]});
		$taxallnomy_treeAll{$taxallnomyLineageUnb[$i]} = 1;
		my $txid = $taxallnomyLineageUnb[$i];
		my $j = 1;
		my $parent = $taxallnomyLineageUnb[$i-$j];
		print TREEUNB $txid."\t".$parent."\n";
		while($parent != 1 and $table[$parent][1] == -1 and !$table[$parent][5]){
			$j++;
			$parent = $taxallnomyLineageUnb[$i-$j];
		}
		print TREE $txid."\t".$parent."\n";
	}	
}

# Generate rank table

my $count3 = 1;
foreach my $rank(@rankOrder){
	print RANK $rank."\t";
	print RANK $count3."\t";
	print RANK $hash_rankPriority{$rank}."\t";
	print RANK $ncbi_ranks{"name"}{$rank}{"code"}."\t";
	print RANK $ncbi_ranks{"name"}{$rank}{"abbrev"}."\t";
	print RANK scalar(keys %{$rankCountType{"distinct"}{$rank}{0}})."\t";
	print RANK scalar(keys %{$rankCountType{"distinct"}{$rank}{1}})."\t";
	print RANK scalar(keys %{$rankCountType{"distinct"}{$rank}{2}})."\t";
	print RANK scalar(keys %{$rankCountType{"distinct"}{$rank}{3}})."\t";
	print RANK $rankCountType{"all"}{$rank}{0}."\t";
	print RANK $rankCountType{"all"}{$rank}{1}."\t";
	print RANK $rankCountType{"all"}{$rank}{2}."\t";
	print RANK $rankCountType{"all"}{$rank}{3}."\n";
	$count3++;
}

system ("find . -type f -not -name 'taxallnomy*' -delete");
chdir "..";

print "All done!\n\n";
print "To load TaxAllnomy database in your MySQL just type the following command line:\n\n";
print "  > mysql -u <username> -p < taxallnomy_XXX.sql\n\n";
print "or in the MySQL environment:\n\n";
print "  mysql> source taxallnomy_XXX.sql\n\n";
print "XXX conrresponds to the table name of Taxallnomy database. They are lin, lin_name, tree_complete,
tree_all or rank. See README for a detailed description of each table.\n\n";

sub getName {
	my $name2determine = $_[0];
	my $nameDef;
	if ($name2determine =~ /^(\d+)\.(\d{2})(\d)$/){
		my $txidCode = $1;
		my $rankCode = $2;
		my $typeCode = $3;
		my $name3 = $table[$txidCode][3][0];
		if ($typeCode != 0) {
			my $rank = $ncbi_ranks{"code"}{$rankCode}{"abbrev"}."_";
			my $code = $typeCode{$typeCode};
			$nameDef = $rank.$code.$name3;
		} else {
			$nameDef = $table[$name2determine][3][0];
		}
	} else {
		$nameDef = $table[$name2determine][3][0];
	}
	return $nameDef;
}

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
		$lineageEx{$i}{"possibleRanks"} = $or_lineage[$i][5] if ($or_lineage[$i][5]);
	}
	my $m = 0;
	my @lineageTaxAllnomy;
	my %txidInTaxAllnomy;
	for (my $i = 0; $i < scalar @rankOrder; $i++){
		if (exists $lineageExRank{$rankOrder[$i]}){ # ranked taxon
			$m = $lineageExRank{$rankOrder[$i]};
			push (@lineageTaxAllnomy, $lineageEx{$m}{"name"});
			$txidInTaxAllnomy{$lineageEx{$m}{"name"}} = 1;
			#push (@lineageTaxAllnomyUnbalanced, $lineageEx{$m}{"name"}) if (!exists $lineageTaxAllnomyUnbalanced{$lineageEx{$m}{"name"}});
			#$lineageTaxAllnomyUnbalanced{$lineageEx{$m}{"name"}} = 1;
			
		} else { # unranked taxon
			my $l = $m;
			my $append = 0.001;
			my $control = 0;
			while (exists($lineageEx{$l + 1}{"rank"})){
				if ($lineageEx{$l + 1}{"rank"} ne "clade"){
					# verify if the searching rank level is below the current rank level
					if ($ncbi_all_ranks{$rankOrder[$i]}{"level"} < $ncbi_all_ranks{$lineageEx{$l + 1}{"rank"}}{"level"}){
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
						
						if ($ncbi_all_ranks{$rankOrder[$i]}{"level"} >= $maxPossibleRanks and $ncbi_all_ranks{$rankOrder[$i]}{"level"} <= $minPossibleRanks){
							$l++;
							$control = 1;
							last;
						} elsif ($ncbi_all_ranks{$rankOrder[$i]}{"level"} < $maxPossibleRanks) {
							$control = 1;
							$append = 0.002;
							#print $lineageEx{$l + 1}{"name"}."\n";
							$l++; # here
							last;
						} else {
							$l++;
							#push (@lineageTaxAllnomyUnbalanced, $lineageEx{$l}{"name"}) if (!exists $lineageTaxAllnomyUnbalanced{$lineageEx{$l}{"name"}});
							#$lineageTaxAllnomyUnbalanced{$lineageEx{$l}{"name"}} = 1;
						}
					} else {
						$l++;
						#push (@lineageTaxAllnomyUnbalanced, $lineageEx{$l}{"name"}) if (!exists $lineageTaxAllnomyUnbalanced{$lineageEx{$l}{"name"}});
						#$lineageTaxAllnomyUnbalanced{$lineageEx{$l}{"name"}} = 1;
					}
				}
			}
			if (!$control){
				$append = 0.003;
			}
			$append += $ncbi_ranks{"name"}{$rankOrder[$i]}{"dcode"};
			$append += $lineageEx{$l}{"name"};
			
			push (@lineageTaxAllnomy, $append);
			$txidInTaxAllnomy{$lineageEx{$l}{"name"}} = 1;
			#push (@lineageTaxAllnomyUnbalanced, $append) if (!exists $lineageTaxAllnomyUnbalanced{$append});
			#$lineageTaxAllnomyUnbalanced{$append} = 1;
		}
	}
	
	return (\@lineageTaxAllnomy);
	
	my @lineageTaxAllnomyUnbalanced;
	my %lineageTaxAllnomyUnbalanced;
	
	my $j = 0;
	for(my $i = 0; $i < scalar @or_lineage; $i++){
		my $txid = $or_lineage[$i][4];
		if (exists $txidInTaxAllnomy{$txid}){
			for(my $k = $j; $k < scalar @lineageTaxAllnomy; $k++){
				my $txidCode = $lineageTaxAllnomy[$k];
				$txidCode =~ s/\.\d+$//;
				if ($txid eq $txidCode){
					push(@lineageTaxAllnomyUnbalanced, $lineageTaxAllnomy[$k]);
				} else {
					$j = $k;
					last;
				}
			}
		} else {
			push(@lineageTaxAllnomyUnbalanced, $txid);
		}
	}
	
	my @lineageTaxallnomyNoNode23;
	for(my $i = 0; $i < scalar @lineageTaxAllnomyUnbalanced; $i++){
		my $txid = $lineageTaxAllnomyUnbalanced[$i];
		if ($txid !~ /\.\d{2}[23]$/){
			push(@lineageTaxallnomyNoNode23, $txid);
		}
	}
	
	return (\@lineageTaxAllnomy, \@lineageTaxAllnomyUnbalanced,\@lineageTaxallnomyNoNode23);
}

sub checkUnclass {
	my $name = $_[0];
	# verify if this represents an unclassified or an environmental sample.
	my $control;
	if ($name =~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){
		$control = 1;
	} else {
		$control = 0;
	}
	return $control;
}

sub rankOrder {

	my @rankOrder = (
		["domain","Dom"],
		["realm","Rea"],
		["kingdom","Kin"],
		["subkingdom","sbKin"],
		["superphylum","spPhy"],
		["phylum","Phy"],
		["subphylum","sbPhy"],
		["infraphylum","inPhy"],
		["superclass","spCla"],
		["class","Cla"],
		["subclass","sbCla"],
		["infraclass","inCla"],
		["cohort","Coh"],
		["subcohort","sbCoh"],
		["superorder","spOrd"],
		["order","Ord"],
		["suborder","sbOrd"],
		["infraorder","inOrd"],
		["parvorder","prOrd"],
		["superfamily","spFam"],
		["family","Fam"],
		["subfamily","sbFam"],
		["tribe","Tri"],
		["subtribe","sbTri"],
		["genus","Gen"],
		["subgenus","sbGen"],
		["section","Sec"],
		["subsection","sbSec"],
		["series","Ser"],
		["subseries","sbSer"],
		["species group","Sgr"],
		["species subgroup","sbSgr"],
		["species","Spe"],
		["forma specialis","Fsp"],
		["subspecies","sbSpe"],
		["varietas","Var"],
		["subvariety","sbVar"],
		["forma","For"],
		["serogroup","Srg"],
		["serotype","Srt"],
		["strain","Str"],
		["isolate","Iso"]
	);
	
	my %ncbi_ranks;
	
	my $nRanks = scalar @rankOrder;
	my $nRanksLength = length $nRanks;
	my $format = "%0".$nRanksLength."d";
	my @ranks;
	
	for(my $i = 0; $i < scalar @rankOrder; $i++){
		push(@ranks, $rankOrder[$i][0]);
		$ncbi_ranks{"level"}{$i} = $rankOrder[$i][0];
		$ncbi_ranks{"name"}{$rankOrder[$i][0]}{"level"} = $i;
		
		my $rankLevel = $i + 1;
		my $code = sprintf($format, $rankLevel);
		$ncbi_ranks{"name"}{$rankOrder[$i][0]}{"code"} = $code;
		$ncbi_ranks{"name"}{$rankOrder[$i][0]}{"abbrev"} = $rankOrder[$i][1];
		$ncbi_ranks{"name"}{$rankOrder[$i][0]}{"dcode"} = $rankLevel/100; # taxAllnomy_ranks
		$ncbi_ranks{"code"}{$code}{"abbrev"} = $rankOrder[$i][1];
		$ncbi_ranks{"code"}{$code}{"rank"} = $rankOrder[$i][0];
	}
	
	$ncbi_ranks{"order"} = \@ranks;
	
	# add "no rank" info
	$ncbi_ranks{"level"}{-1} = "clade";
	$ncbi_ranks{"name"}{"clade"}{"level"} = -1;
	$ncbi_ranks{"name"}{"no rank"}{"level"} = -1;
	$ncbi_ranks{"name"}{"no_rank"}{"level"} = -1;
	
	# add synonymus ranks
	my @synonymus = (
		["superdivision", "superphylum"],
		["division", "phylum"],
		["subdivision", "subphylum"],
		["infradivision", "infraphylum"],
		["special form", "forma specialis"],
		["morph", "varietas"],
		["form", "varietas"],
		["pathogroup", "serogroup"],
		["biotype", "serotype"],
		["genotype", "serotype"],
	);
	
	for(my $i = 0; $i < scalar @synonymus; $i++){
		$ncbi_ranks{"name"}{$synonymus[$i][0]}{"level"} = $ncbi_ranks{"name"}{$synonymus[$i][1]}{"level"};
	}

	return (\%ncbi_ranks);
}

=head1 NAME

generate_taxallnomy - script for generating Taxallnomy database.

=head1 SYNOPSIS

perl generate_taxallnomy

perl generate_taxallnomy -local </path/to/taxdump_file>

perl generate_taxallnomy -local </path/to/taxdump_file> -out <dir>

=item B<Inputs>:

[-local]
	
=item B<Other parameters>:

[-dir]
		
=item B<Help>:

[-help] [-man]

Use -man for a detailed help.

=head1 OPTIONS

=over 8

=item B<-local> </path/to/taxdump_file>

Generate Taxallnomy database using a local taxdump file. If this parameter is ommited, the script will download the latest taxdump file from NCBI.

=item B<-out> <dir> [default: taxallnomy_data]

Name of the output directory.

=item B<-version>

Print the version of the script and exit.

=item B<-help>

Print a brief help message and exit.

=item B<-man>

Prints the manual page and exit.

=back

=head1 DESCRIPTION

B<Taxallnomy> is a hierarchically complete taxonomic database based on NCBI Taxonomy that provides taxonomic lineages according to the ranks used on Linnean classification system.
in a phylogenetic tree. 

=cut

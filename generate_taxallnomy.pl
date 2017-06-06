#!/usr/bin/perl -w

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

# Version 1.4.11

##############################################################################
#                                                                            #
# Modification from version 1.4                                              #
#                                                                            #
# - Verify genus and species separatedely.                                   #
# - Rank priority.                                                           #
# - If there are more unranked node than rank to be assigned, evaluate if    #
# the node should have a rank assigned, or transfer the to the next nodes.   #
# - Verifies redundant levels.                                               #
# - Verifies if there are unranked nodes with CR <= NP in the path to NA.    #
# - taxallnomy_lin_name table added.                                         #
# - script deal with rank update;                                            #
# - it also generates a tree without deleting unranked nodes without         #
# candidate ranks;                                                           #
#                                                                            #
##############################################################################

use strict;
use Data::Dumper;
use POSIX;
use Getopt::Long;
use Pod::Usage;

my $dir = "taxallnomy_data";
my $taxallnomy_version = "1.4.10";
my $version;
my $help;
my $man;
my $local_dump;

GetOptions(
    'local=s'=> \$local_dump,
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
		system("tar -zxf $local_dump");
	} else {
		die "ERROR: Can't find the taxdump.tar.gz";
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

open(TXID, "< nodes.dmp") or die "ERROR: Can't open nodes.dmp"; 

my %ncbi_all_ranks = (
	"no rank" => -1,
);
my $ncbi_all_ranks = \%ncbi_all_ranks;
my @table;	# table[$txid][0] - parent 
			# table[$txid][1] - rank (integer)
			# table[$txid][2] - [children]
			# table[$txid][3] - name (0 - scientific name; 1 - genbank common name; 2 - common name)
			# table[$txid][4] - txid
			# table[$txid][5] - possibleRanks
			# table[$txid][6] - could be genus (position 0) or species (position 1)
			# table[$txid][7] - minRank (position 0) or maxRank (position 1)
			# table[$txid][8] - rank (text)

my @txid;
my %hash_rank;
while(my $line = <TXID>){
	my @line = split(/\t\|\t/, $line);
	$table[$line[0]][4] = $line[0]; # txid
	$table[$line[0]][0] = $line[1] if ($line[0] != $line[1]); # parent
	
	#if (!exists $ncbi_all_ranks{$line[2]}){
	#	die "ERROR: new rank found. Script need update: ".$line[0]." ".$line[2]."\n";
	#}
	#$ncbi_all_ranks{$line[2]} = 1 if ($line[2] ne "no rank");
	$table[$line[0]][8] = $line[2]; # rank
	$hash_rank{$line[2]} = 1 if ($line[2] ne "no rank");
	if (!$table[$line[1]][2]){
		$table[$line[1]][2][0] = $line[0] if ($line[0] != $line[1]); # children
	} else {
		$table[$line[1]][2][scalar @{$table[$line[1]][2]}] = $line[0] if ($line[0] != $line[1]); # children
	}
	
	push(@txid, $line[0]);
	
} 

close TXID;

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

# determine rank radical and stem
print "  Determining rank radicals and stem... \n";

my %hash_radical;
my %hash_allRankRadical;
my %hash_allRankStem;
my %hash_withRadical;
my %hash_stem;
foreach my $rank1(keys %hash_rank){
	my @words1 = split(" ", $rank1);
	my $control_noRadical = 0;
	foreach my $rank2(keys %hash_rank){
		next if ($rank1 eq $rank2);
		my @words2 = split(" ", $rank2);
		next if (scalar @words1 ne scalar @words2);
		my $control = 1;
		my @radical;
		for(my $i = 0; $i < scalar @words1; $i++){
			if ($words2[$i] !~ /$words1[$i]/){
				$control = 0;
			} else {
				$words2[$i] =~ s/$words1[$i]//;
				if ($words2[$i] ne ""){
					push(@radical, $words2[$i]);
				}
			}
		}
		if ($control){
			
			my $radical = join(" ", @radical);
			$hash_stem{$rank1}{$rank2} = $radical;
			$hash_stem{$rank1}{$rank1} = "stem";
			$hash_allRankRadical{$rank1} = "stem";
			$hash_allRankRadical{$rank2} = $radical;
			$hash_allRankStem{$rank1} = $rank1;
			$hash_allRankStem{$rank2} = $rank1;
			$hash_radical{$radical}{$rank1} = 1;
			$hash_radical{"stem"}{$rank1} = 1;
			$hash_withRadical{$rank1} = 1;
			$hash_withRadical{$rank2} = 1;
		}
	}
}

foreach my $rank(keys %hash_rank){
	if (!exists $hash_withRadical{$rank}){
		$hash_stem{$rank}{$rank} = "stem";
		$hash_radical{"stem"}{$rank} = 1;
		$hash_allRankRadical{$rank} = "stem";
		$hash_allRankStem{$rank} = $rank;
	}
}

# determine rank order
print "  Determining rank order... \n";
my %rankOrder;
my %rankCount;
for(my $i = 0; $i < scalar @txid; $i++){
	my $node = $txid[$i];
	next if ($table[$node][2]);
	my @ranksLineage;
	my @lineage;
	my $unclassControl = 0;
	while ($node != 1){	
		
		if($table[$node][3][0] =~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){
			$unclassControl = 1;
		}
		if ($table[$node][8] ne "no rank"){
			unshift(@ranksLineage, $table[$node][8]);			
			unshift(@lineage, $node);			
		}
		
		$node = $table[$node][0] if ($table[$node][0]);
	}
	
	if (scalar @ranksLineage > 1){
		for(my $j = 0; $j < scalar @ranksLineage; $j++){
			$rankCount{"all"}{$ranksLineage[$j]} += 1 if (!$unclassControl);
			$rankCount{"distinct"}{$ranksLineage[$j]}{$lineage[$j]} = 1 if (!$unclassControl);
			for(my $k = $j+1; $k < scalar @ranksLineage; $k++){
				$rankOrder{$ranksLineage[$j]}{$ranksLineage[$k]} = 1;
			}
		}
	} else {
		next;
	}
}

my %radicalOrder;
foreach my $stem(keys %hash_stem){
	my @ranks = keys %{$hash_stem{$stem}};
	next if (scalar @ranks == 1);
	for(my $i = 0; $i < scalar @ranks; $i++){
		for(my $j = $i + 1; $j < scalar @ranks; $j++){
			if (exists $rankOrder{$ranks[$i]}{$ranks[$j]}){
				$radicalOrder{$hash_stem{$stem}{$ranks[$i]}}{$hash_stem{$stem}{$ranks[$j]}} = 1;
			} elsif (exists $rankOrder{$ranks[$j]}{$ranks[$i]}){
				$radicalOrder{$hash_stem{$stem}{$ranks[$j]}}{$hash_stem{$stem}{$ranks[$i]}} = 1;
			}
		}
	}
}

my %hashRankScore;
foreach my $radical(keys %hash_radical){
	if (exists $radicalOrder{$radical}){
		$hashRankScore{$radical} = scalar(keys %{$radicalOrder{$radical}});
	} else {
		$hashRankScore{$radical} = 0;
	}
}

my @rankOrder;
while (scalar(keys %hash_rank) > 0){
	my @ranks = keys %hash_rank;
	my %hash_rank2 = map { $_ => 1 } @ranks;
	foreach my $rank (keys %rankOrder) {
		foreach my $rank2(keys %{$rankOrder{$rank}}){
			if (exists $hash_rank2{$rank2}){
				delete $hash_rank2{$rank2};
			}
		}
	}
	my @rank3 = keys %hash_rank2;
	if (scalar(@rank3) == 1){
		#print $rank3[0]."\n";
		push(@rankOrder, $rank3[0]);
		delete $hash_rank{$rank3[0]};
		delete $hash_rank2{$rank3[0]};
		delete $rankOrder{$rank3[0]};
	} else {
		# verify if they are from the same stem of the last rank
		my $lastRank = $rankOrder[$#rankOrder];
		$lastRank = $hash_allRankStem{$lastRank};
		my @newRank3;
		my @noNewRank3;
		foreach my $rank4(@rank3){
			my $radical = $rank4;
			$radical = $hash_allRankStem{$radical};
			if ($radical eq $lastRank){
				push (@newRank3,$rank4);
			} else {
				push (@noNewRank3,$rank4);
			}
		}
		if (scalar @newRank3 == 1){
			#print $rank3[0]."\n";
			push(@rankOrder, $newRank3[0]);
			delete $hash_rank{$newRank3[0]};
			delete $hash_rank2{$newRank3[0]};
			delete $rankOrder{$newRank3[0]};
		} elsif (scalar @newRank3 > 1) {
			# verify their radicals to determine the order
			my %hash_score;
			for(my $i = 0; $i < scalar @newRank3; $i++){
				my $radicalScore = $hashRankScore{$hash_allRankStem{$newRank3[$i]}};
				$hash_score{$radicalScore} = $newRank3[$i];
			}
			
			foreach my $score(sort {$b <=> $a} keys %hash_score){
				push(@rankOrder, $hash_score{$score});
				delete $hash_rank{$hash_score{$score}};
				delete $hash_rank2{$hash_score{$score}};
				delete $rankOrder{$hash_score{$score}};
			}
		} else {
			# verify if they are from the same stem
			my $control = 0;
			for(my $i = 0; $i < scalar @noNewRank3; $i++){
				my $stem1 = $hash_allRankStem{$noNewRank3[$i]};
				for(my $j = $i+1; $j < scalar @noNewRank3; $j++){
					my $stem2 = $hash_allRankStem{$noNewRank3[$j]};
					if ($stem1 ne $stem2){
						$control = 1;
						last;
					}
				}
			}
			if (!$control){
				# verify their radicals to determine the order
				my %hash_score;
				for(my $i = 0; $i < scalar @noNewRank3; $i++){
					my $radicalScore = $hashRankScore{$hash_allRankStem{$noNewRank3[$i]}};
					$hash_score{$radicalScore} = $noNewRank3[$i];
				}
				
				foreach my $score(sort {$b <=> $a} keys %hash_score){
					push(@rankOrder, $hash_score{$score});
					delete $hash_rank{$hash_score{$score}};
					delete $hash_rank2{$hash_score{$score}};
					delete $rankOrder{$hash_score{$score}};
				}
			} else {
				print Dumper(\@rank3);
				die "Can't determine rank order.\nPlease notify me about this error (tetsufmbio\@gmail.com).\n\n";
			}
		}
	}
}

my %taxAllnomy_ranks;
my %rev_ncbi_all_ranks = ( 
	-1 => "no rank"
);
my $count = 0;
foreach my $rank(@rankOrder){
	$ncbi_all_ranks{$rank} = $count;
	$ncbi_all_ranks->{$rank} = $count;
	$taxAllnomy_ranks{$rank} = ($count+1)/100;
	$rev_ncbi_all_ranks{$count} = $rank;
	$count++;
	
}

for(my $i = 0; $i < scalar @txid; $i++){
	my $node = $txid[$i];
	$table[$node][1] = $ncbi_all_ranks{$table[$node][8]};
}

# establish rank priority
my %ncbi_rank_priority;
my @ncbi_rank_priority_general = sort {$rankCount{"all"}{$b} <=> $rankCount{"all"}{$a}} keys %{$rankCount{"all"}};

# make radical and rank abbreviation
my %hash_radicalAbbrev;
$hash_radicalAbbrev{"stem"} = "";
my %hash_revRadicalAbbrev;
foreach my $radical(keys %hash_radical){
	if ($radical ne "stem"){
		my @letter = split("", $radical);
		my $firstLetter = shift @letter;
		my $control = 0;
		for(my $i = 0; $i < scalar @letter; $i++){
			if ($letter[$i] !~ /[aeiou]/){
				if (!exists $hash_revRadicalAbbrev{$firstLetter.$letter[$i]}){
					$hash_revRadicalAbbrev{$firstLetter.$letter[$i]} = $radical;
					$hash_radicalAbbrev{$radical} = $firstLetter.$letter[$i];
					$control = 1;
					last;
				}
			}
		}
		if (!$control){
			die "Could not determine an abbreviation for this radical: $radical.\nPlease notify me about this error (tetsufmbio\@gmail.com).\n\n";
		}
	}	
}

my %hash_stemAbbrev;
my %hash_revStemAbbrev;
my %hash_rankPriority;
my $count2 = 1;
foreach my $rank(@ncbi_rank_priority_general){
	
	# for rank table;
	$hash_rankPriority{$rank} = $count2;
	$count2++;
	
	my $stem = $hash_allRankStem{$rank};
	next if (exists $hash_stemAbbrev{$stem});
	my @words = split(" ", $stem);
	my $control = 0;
	for(my $i = 0; $i < scalar @words; $i++){
		my $abbrev1 = substr($words[$i], 0, 1);
		$abbrev1 = uc($abbrev1);
		my $abbrev2 = substr($words[$i], 1, 2);
		$abbrev2 = lc($abbrev2);
		my $abbrev = $abbrev1.$abbrev2;
		if (!exists $hash_revStemAbbrev{$abbrev}){
			$hash_revStemAbbrev{$abbrev} = $stem;
			$hash_stemAbbrev{$stem} = $abbrev;
			$control = 1;
			last;
		}
	}
	if (!$control){
		die "Could not determine an abbreviation for this rank: $stem.\nPlease notify me about this error (tetsufmbio\@gmail.com).\n\n";
	}
}

my @ncbi_all_ranks = @rankOrder;

# Determine rank code for all ranks

my %taxallnomy_ranks_code;
my %taxallnomy_ranks_code2;

my $nRanks = scalar @rankOrder;
my $nRanksLength = length $nRanks;
my $format = "%0".$nRanksLength."d";
my $rankLevel = 1;
foreach my $rank(@rankOrder){
	my $stem = $hash_stemAbbrev{$hash_allRankStem{$rank}};
	my $radical = $hash_radicalAbbrev{$hash_allRankRadical{$rank}};
	
	my $code = sprintf($format, $rankLevel);
	$taxallnomy_ranks_code{"rank"}{$rank}{"code"} = $code;
	$taxallnomy_ranks_code{"rank"}{$rank}{"abbrev"} = $radical.$stem;
	$taxallnomy_ranks_code{"code"}{$code}{"abbrev"} = $radical.$stem;
	$taxallnomy_ranks_code{"code"}{$code}{"rank"} = $rank;
	$taxallnomy_ranks_code2{$code} = $radical.$stem."_";
	$rankLevel++;
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

foreach my $rank2analyse(@ncbi_all_ranks){
	
	my @nodes2analyse;
	push (@nodes2analyse, 1);
	my $rank2analyseInt = $ncbi_all_ranks{$rank2analyse};
	
	while(scalar @nodes2analyse != 0){
	
		my $node = shift @nodes2analyse;
		
		if ($table[$node][1] != -1){ # ranked taxon
		
			next if ($rank2analyseInt <= $table[$node][1]);
			push(@nodes2analyse, @{$table[$node][2]}) if ($table[$node][2]);
			
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
				my $minRank = scalar @ncbi_all_ranks; 
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
				if ($rank2analyseInt == $ncbi_all_ranks{"genus"}){
					push(@genus2analyse, $node);
				} elsif ($rank2analyseInt == $ncbi_all_ranks{"species"}){
					push(@species2analyse, $node);
				}
			} else {
				push(@nodes2analyse, @{$table[$node][2]}) if ($table[$node][2]);
			} 
		}
	}
}

# verify genus
print "verify genus...\n";
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
		if($genusName !~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){ # verify if this represents an unclassified or an environmental sample.
			my @nodes2analyse5;	
			push (@nodes2analyse5, @{$table[$node4][2]}) if $table[$node4][2];
			while(scalar @nodes2analyse5 > 0){
				my $node3 = shift @nodes2analyse5;
				if($table[$node3][1] != -1){
					# ranked taxon
					if ($table[$node3][1] < $ncbi_all_ranks{"species"}){
						push (@nodes2analyse5, @{$table[$node3][2]}) if $table[$node3][2];
					} elsif ($table[$node3][1] == $ncbi_all_ranks{"species"}){
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
					if ($possibleRanksCurrent[$i] < $ncbi_all_ranks{"genus"}) {
						push(@newPossibleRanksCurrent, $possibleRanksCurrent[$i]);
					} else {
						push(@transferPossibleRanks, $possibleRanksCurrent[$i]);
					}
				}
				$table[$node4][5] = undef;
				$table[$node4][5] = \@newPossibleRanksCurrent if (scalar @newPossibleRanksCurrent > 0);
				$table[$node4][7][1] = $ncbi_all_ranks{"genus"};
				# transfer the ranks to child unranked nodes
				if ($table[$node4][2]){
					my @nodes2analyseChild;
					push(@nodes2analyseChild, @{$table[$node4][2]});
					while(scalar @nodes2analyseChild > 0){
						my $nodeChild = shift @nodes2analyseChild;
						if($table[$nodeChild][1] == -1){
							push(@nodes2analyseChild, @{$table[$nodeChild][2]}) if ($table[$nodeChild][2]);
							$table[$node4][7][1] = $ncbi_all_ranks{"genus"};
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
print "verify species...\n";
while (scalar @species2analyse > 0){
	my $node = shift @species2analyse;
	# This node could be a species
	# pick its genus
	my @nodes2analyse4;
	push(@nodes2analyse4, $table[$node][0]);
	my $genusName;
	my $control = 0;
	my $putativeSpeciesName = $table[$node][3][0];
	if($putativeSpeciesName !~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){ # verify if this represents an unclassified or an environmental sample.
		while(scalar @nodes2analyse4 > 0){
			my $node2 = shift @nodes2analyse4;
			if($table[$node2][1] != -1){
				# ranked taxon
				if ($table[$node2][1] > $ncbi_all_ranks{"genus"}){
					push (@nodes2analyse4, $table[$node2][0]);
				} elsif ($table[$node2][1] == $ncbi_all_ranks{"genus"}){
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
			if($putativeSpeciesName =~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){ # verify if this represents an unclassified or an environmental sample.
				$table[$node4][6][0] = 0;
				push(@noSpecies, $table[$node4][3][0]);
				push (@nodes2analyse6, @{$table[$node4][2]}) if $table[$node4][2];
				$table[$node4][7][1] = $ncbi_all_ranks{"species"};
				# modify the possible ranks of this node
				if ($table[$node4][5]){
					my @possibleRanksCurrent = @{$table[$node4][5]};
					my @newPossibleRanksCurrent;
					my @transferPossibleRanks;
					for(my $i = 0; $i < scalar @possibleRanksCurrent; $i++){
						if ($possibleRanksCurrent[$i] < $ncbi_all_ranks{"species"}) {
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
		$table[$node][7][1] = $ncbi_all_ranks{"species"};
		# modify the possible ranks of this node
		if ($table[$node][5]){
			my @possibleRanksCurrent = @{$table[$node][5]};
			my @newPossibleRanksCurrent;
			my @transferPossibleRanks;
			for(my $i = 0; $i < scalar @possibleRanksCurrent; $i++){
				if ($possibleRanksCurrent[$i] < $ncbi_all_ranks{"species"}) {
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
	my $minRankLevel = scalar @ncbi_all_ranks - 1; # store the min level on the longest path of consecutive unranked taxa.
	while(scalar @layer != 0){
		my @layer2;	
		my $control = 0;
		my $minRankLevel2 = scalar @ncbi_all_ranks - 1;
		while(scalar @layer != 0){
			my $layer2 = shift @layer;
			#if ($table[$layer2][1] == -1 && !$table[$layer2][6][0] && !$table[$layer2][6][1]){
			if ($table[$layer2][1] == -1){
				if($table[$layer2][3][0] !~ m/unpublished|unidentified|unclassified|environmental|unassigned|incertae sedis|other sequences/i){ # verify if this represents an unclassified or an environmental sample.
					$control = 1;
					if (exists $table[$layer2][2]){
						push (@layer2, @{$table[$layer2][2]});
					} else {
						$controlLeafUnranked = 1;
					}
					my $rankLevel = scalar @ncbi_all_ranks - 1;
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
			if (exists $possibleRanks2analyse{$ncbi_all_ranks{$rankPrio}}){
				push(@rank2assign, $ncbi_all_ranks{$rankPrio});
				$control = 1 if (exists $possibleRanksInNode{$ncbi_all_ranks{$rankPrio}});
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
open(TREE, "> taxallnomy_tree.tab") or die;
open(TREESQL, "> taxallnomy_tree.sql") or die;
open(TREEUNB, "> taxallnomy_tree_withNoRank.tab") or die;
open(TREEUNBSQL, "> taxallnomy_tree_withNoRank.sql") or die;

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

print LINSQL  '`sciname` varchar(200) NOT NULL,
  `comname` varchar(200),
  `leaf` tinyint(1) NOT NULL,
  `unclassified` tinyint(1) NOT NULL,
  `merged` tinyint(1) NOT NULL,
  `rank` varchar(20) NOT NULL,
  PRIMARY KEY (`txid`)
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

print LINNAMESQL  '`sciname` varchar(200) NOT NULL,
  `comname` varchar(200),
  `leaf` tinyint(1) NOT NULL,
  `unclassified` tinyint(1) NOT NULL,
  `merged` tinyint(1) NOT NULL,
  `rank` varchar(20) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_lin_name.tab\' INTO TABLE lin_name;
';

# sql for tree table
print TREESQL $dumpHead.'
--
-- Table structure for table `tree`
--

DROP TABLE IF EXISTS `tree`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tree` (
  `txid` DECIMAL(20,3) NOT NULL,
  `parent`DECIMAL(20,3) NOT NULL,
  `rank` varchar(20) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

ALTER TABLE `tree` ADD INDEX `parent` (`parent`);

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_tree.tab\' INTO TABLE tree;

';

# sql for tree with no candidate rank taxon table
print TREEUNBSQL $dumpHead.'
--
-- Table structure for table `tree_withNoRank`
--

DROP TABLE IF EXISTS `tree_withNoRank`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tree_withNoRank` (
  `txid` DECIMAL(20,3) NOT NULL,
  `parent`DECIMAL(20,3) NOT NULL,
  `rank` varchar(20) NOT NULL,
  PRIMARY KEY (`txid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

ALTER TABLE `tree_withNoRank` ADD INDEX `parent` (`parent`);

--
-- Dumping data for table `taxallnomy`
--

LOAD DATA LOCAL INFILE \'taxallnomy_tree_withNoRank.tab\' INTO TABLE tree_withNoRank;

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
$taxallnomy_tree{1}{"parent"} = 0;
$taxallnomy_tree{1}{"sciname"} = "root";
$taxallnomy_tree{1}{"comname"} = "all";
$taxallnomy_tree{1}{"rank"} = "no rank";

my %taxallnomy_treeNoRank;
$taxallnomy_treeNoRank{1}{"parent"} = 0;
$taxallnomy_treeNoRank{1}{"sciname"} = "root";
$taxallnomy_treeNoRank{1}{"comname"} = "all";
$taxallnomy_treeNoRank{1}{"rank"} = "no rank";

my @insert;
my %rankCountType;
foreach my $rank(@rankOrder){
	for(my $i = 1; $i < 4; $i++){
		$rankCountType{"all"}{$rank}{$i} = 0;
		$rankCountType{"distinct"}{$rank}{$i} = ();
	}
}
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
	my ($taxallnomyLineage, $taxallnomyLineageNoRank) = generate_taxallnomy(\@lineage);
	my @taxallnomyLineage = @$taxallnomyLineage;

	for(my $i = scalar @taxallnomyLineage - 1; $i >= 0; $i--){
		#next if ($taxallnomyLineage[$i] =~ /\.\d{2}3$/);
		
		if($leaf and !$unclassified){
			if ($taxallnomyLineage[$i] =~ /\.(\d{2})(\d)$/){
				my $rankCode = $1;
				my $rankType = $2;
				if ($rankType != 0){
					$rankCountType{"distinct"}{$taxallnomy_ranks_code{"code"}{$1}{"rank"}}{$2}{$taxallnomyLineage[$i]} = 1;
					$rankCountType{"all"}{$taxallnomy_ranks_code{"code"}{$1}{"rank"}}{$2} += 1;
				}
			}			
		}
		
		next if (exists $taxallnomy_tree{$taxallnomyLineage[$i]});
		next if (!$leaf);
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
		print TREE $defLine;
		
	}
	
	my @taxallnomyLineageNoRank = @$taxallnomyLineageNoRank;

	if ($leaf){
		for(my $i = scalar @taxallnomyLineageNoRank - 1; $i >= 0; $i--){
			next if (exists $taxallnomy_treeNoRank{$taxallnomyLineageNoRank[$i]});
			$taxallnomy_treeNoRank{$taxallnomyLineageNoRank[$i]} = 1;
			# parent
			my $parent2;
			if ($i - 1 >= 0){
				$parent2 = $taxallnomyLineageNoRank[$i - 1];
			} else {
				$parent2 = 1;
			}
			# rank
			my $rank2;
			if ($taxallnomyLineageNoRank[$i] =~ /\.(\d{2})(\d)$/){
				my $rankCode = $1;
				my $rankType = $2;
				$rank2 = $ncbi_all_ranks[$rankCode - 1];
			} else {
				$rank2 = $table[$taxallnomyLineageNoRank[$i]][8];
			}
			
			my $txidCode2 = $taxallnomyLineageNoRank[$i];
			my $defLine = $txidCode2."\t".$parent2."\t".$rank2."\n";
			print TREEUNB $defLine;
		}
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
	
	# data for LINNAME
	my @taxallnomyLineageName;
	for(my $i = 0; $i < scalar @taxallnomyLineage; $i++){
		if ($taxallnomyLineage[$i] =~ /^(\d+)\.(\d{2})(\d)$/){
			my $txidCode = $1;
			my $rankCode = $2;
			my $typeCode = $3;
			my $name3 = $table[$txidCode][3][0];
		
			my $rank = $taxallnomy_ranks_code{"code"}{$rankCode}{"abbrev"}."_";
			my $code = $typeCode{$typeCode};
			push(@taxallnomyLineageName, $rank.$code.$name3);
	
		} else {
			my $name3 = $table[$taxallnomyLineage[$i]][3][0];
			push(@taxallnomyLineageName, $name3);
		}
		
	}
	my $taxallnomyLineageName2 = join("\t", @taxallnomyLineageName);
	$taxallnomyLineageName2 =~ s/\\/\\\\/g;
	$taxallnomyLineageName2 =~ s/'/\\'/g;
	$taxallnomyLineageName2 =~ s/%/\\%/g;
	
	my $defLine3 = $txid."\t".$taxallnomyLineageName2."\t".$sciname."\t".$comname2."\t$leaf\t$unclassified\t0\t$rank\n";
	print LINNAME $defLine3;
	if (exists $merged{$txid}){
		foreach my $merged(keys %{$merged{$txid}{"merged"}}){
			my $defLine2 = $merged."\t".$taxallnomyLineage2."\t".$sciname."\t".$comname2."\t$leaf\t$unclassified\t1\t$rank\n";
			print LIN $defLine2;
			my $defLine4 = $merged."\t".$taxallnomyLineageName2."\t".$sciname."\t".$comname2."\t$leaf\t$unclassified\t1\t$rank\n";
			print LINNAME $defLine4;
		}
	}	
}

# Generate rank table

my $count3 = 1;
foreach my $rank(@rankOrder){
	print RANK $rank."\t";
	print RANK $count3."\t";
	print RANK $hash_rankPriority{$rank}."\t";
	print RANK $taxallnomy_ranks_code{"rank"}{$rank}{"code"}."\t";
	print RANK $taxallnomy_ranks_code{"rank"}{$rank}{"abbrev"}."\t";
	print RANK scalar(keys %{$rankCount{"distinct"}{$rank}})."\t";
	print RANK scalar(keys %{$rankCountType{"distinct"}{$rank}{1}})."\t";
	print RANK scalar(keys %{$rankCountType{"distinct"}{$rank}{2}})."\t";
	print RANK scalar(keys %{$rankCountType{"distinct"}{$rank}{3}})."\t";
	print RANK $rankCount{"all"}{$rank}."\t";
	print RANK $rankCountType{"all"}{$rank}{1}."\t";
	print RANK $rankCountType{"all"}{$rank}{2}."\t";
	print RANK $rankCountType{"all"}{$rank}{3}."\n";
	$count3++;
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
		$lineageEx{$i}{"possibleRanks"} = $or_lineage[$i][5] if ($or_lineage[$i][5]);
	}
	my $m = 0;
	my @lineageTaxAllnomy;
	my @lineageTaxAllnomyUnbalanced;
	my %lineageTaxAllnomyUnbalanced;
	for (my $i = 0; $i < scalar @ncbi_all_ranks; $i++){
		if (exists $lineageExRank{$ncbi_all_ranks[$i]}){ # ranked taxon
			$m = $lineageExRank{$ncbi_all_ranks[$i]};
			push (@lineageTaxAllnomy, $lineageEx{$m}{"name"});
			push (@lineageTaxAllnomyUnbalanced, $lineageEx{$m}{"name"}) if (!exists $lineageTaxAllnomyUnbalanced{$lineageEx{$m}{"name"}});
			$lineageTaxAllnomyUnbalanced{$lineageEx{$m}{"name"}} = 1;
			
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
							$control = 1;
							$append = 0.002;
							#print $lineageEx{$l + 1}{"name"}."\n";
							$l++; # here
							last;
						} else {
							$l++;
						}
					} else {
						$l++;
						push (@lineageTaxAllnomyUnbalanced, $lineageEx{$l}{"name"}) if (!exists $lineageTaxAllnomyUnbalanced{$lineageEx{$l}{"name"}});
						$lineageTaxAllnomyUnbalanced{$lineageEx{$l}{"name"}} = 1;
					}
				}
			}
			if (!$control){
				$append = 0.003;
			}
			$append += $taxAllnomy_ranks{$ncbi_all_ranks[$i]};
			$append += $lineageEx{$l}{"name"};
			push (@lineageTaxAllnomy, $append);
			push (@lineageTaxAllnomyUnbalanced, $append) if (!exists $lineageTaxAllnomyUnbalanced{$append});
			$lineageTaxAllnomyUnbalanced{$append} = 1;
		}
	}
		
	return (\@lineageTaxAllnomy, \@lineageTaxAllnomyUnbalanced);
}
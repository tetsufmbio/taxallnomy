# Taxallnomy
    
##  Introduction

Taxallnomy is a taxonomic database that provides taxonomic lineages  according  to 
the ranks used on Linnean classification system (e.g. Kingdom, Phylum, Class etc.). 

In this package you will find the following files/folder.

    * generate_taxallnomy   - a script that will generate files for Taxallnomy 
                              database;
    * get_lineage           - a script that will access the Taxallnomy database 
                              to retrieve the taxonomic lineage of TaxIDs of interest;
    * lib/                  - lib folder containing a PERL module required by the 
                              script 'get_lineage'.
    
All scripts were developed to be executed in a UNIX environment.


##  Installing database    


The script generate_taxallnomy will generate all necessary file to load the Taxallnomy
database in a local MySQL. The execution of this script requires internet  connection. 
To run the script, just type in a UNIX terminal the following command:

    > ./generate_taxallnomy

The script will basically download the latest NCBI Taxonomy database and construct the
Taxallnomy hierarchical structure from it. After the running, it will  generate  three 
files:

    * taxallnomy.sql      - MySQL dump file with all commands to create the Taxallnomy 
                            database;
    * taxallnomy_lin.tab  - Tab-delimited file containing the Taxallnomy lineage for 
                            all taxonomy id;
    * taxallnomy_tree.tab - Tab-delimited file containing the name for all taxon code 
                            in Taxallnomy lineage;

To load Taxallnomy database in your local MySQL, go to the path where the three files 
are located and type the following command line:

    > mysql -u <username> -p < taxallnomy.sql

or go to MySQL environment and type:

    mysql> source taxallnomy.sql

Loading Taxallnomy database to MySQL may take several minutes, so be patient.

After the loading procedure, your MySQL should have a database called "taxallnomy" and,
in the taxallnomy database, two tables called "taxallnomy_lin" and "taxallnomy_tree".


###  Table descriptions


1) taxallnomy_lin - this table contains all taxonomic lineages of Taxallnomy  database. 
From this table, you can query for a taxonomic rank of an organism by  its  taxonomy ID 
(primary key). Each one of 28 taxonomic ranks are represented in a column of this table. 
Keep in mind that the content of the taxonomic rank columns is not a taxon name,  but a 
taxon code used by Taxallnomy (See the section "Taxallnomy taxon code"). The taxon names 
can be programmatically generated from the taxon code. Use the script "get_lineage"  to 
retrieve lineages with taxon name.

* taxallnomy_lin table content:

Column          | Description
----------------|---------------------------------------------------
txid            | NCBI taxonomy ID of a organism (primary key)
superkingdom    | Taxon code for Superkingdom rank                
kingdom         | Taxon code for Kingdom rank                     
subkingdom      | Taxon code for Subkingdom rank                  
superphylum     | Taxon code for Superphylum rank                 
phylum          | Taxon code for Phylum rank                      
subphylum       | Taxon code for Subphylum rank                   
superclass      | Taxon code for Superclass rank                  
class           | Taxon code for Class rank                       
subclass        | Taxon code for Subclass rank                    
infraclass      | Taxon code for Infraclass rank                  
superorder      | Taxon code for Superorder rank                  
order           | Taxon code for Order rank                       
suborder        | Taxon code for Suborder rank                    
infraorder      | Taxon code for Infraorder rank                  
parvorder       | Taxon code for Parvorder rank                   
superfamily     | Taxon code for Superfamily rank                 
family          | Taxon code for Family rank                      
subfamily       | Taxon code for Subfamily rank                   
tribe           | Taxon code for Tribe rank                       
subtribe        | Taxon code for Subtribe rank                    
genus           | Taxon code for Genus rank                       
subgenus        | Taxon code for Subgenus rank                    
species_group   | Taxon code for Species Group rank               
species_subgroup| Taxon code for Species Subgroup rank            
species         | Taxon code for Species rank                     
subspecies      | Taxon code for Subspecies rank                  
varietas        | Taxon code for Varietas rank                    
forma           | Taxon code for Forma rank                       
name            | Scientific name of txid                         
comname         | Common name of txid                             
leaf            | 1 if txid is a leaf taxon                       
unclassified    | 1 if txid is part of unclassified group*        
merged          | 1 if this txid was merged to another txid       
rank            | taxonomic rank of txid in the original database 

\* includes txid in unpublished/unidentified/unclassified/environmental/unassigned/
  incertae sedis/other sequences groups.

2) taxallnomy_tree - this table provides the hierarchical structure of Taxallnomy database.

* taxallnomy_tree table content:

Column    | Description
--------|---------------------------------------------------------
txid    | Taxon code used by Taxallnomy (primary key)             
parent  | Taxon code its parent taxon (indexed)                   
rank    | taxonomic rank of taxon code                            


## Taxallnomy taxon code


Taxallnomy primarily uses the Taxonomy ID provided by  NCBI  Taxonomy  database  to 
identify all nodes comprising its hierarchical structure. However, since Taxallnomy 
algorithm creates new nodes, we included in the identifier a code to identify  them 
properly.

The Taxallnomy "code" is added to the NCBI taxonomy ID as decimal number  of  three 
digits. For example, in the taxon code 8287.071,  8287  is  the  NCBI  Taxonomy  ID 
(Sarcopterygii) and 071 is the code added by Taxallnomy algorithm. In the code, the 
first two digits indicates the taxonomic rank in which it belongs. It goes  through 
the code "01" to "28", in which the first rank is Superkingdom ("01") and the  last 
one is Forma ("28"). The third digit indicates how the algorithm created this  node. 
This can be done in three ways:

  1 - (type 1) This taxon is originally unranked on NCBI Taxonomy tree and it was 
      ranked by Taxallnomy algorithm. 
  2 - (type 2) This taxon was created by Taxallnomy algorithm and the name of one 
      of its descendant taxon was used to name it.
  3 - (type 3) This taxon was created by Taxallnomy algorithm and the name of one 
      of its ascendant taxon was used to name it. 


We use the following rules to name the nodes of each type:

 - For type 1, we use the abbreviation of the rank name followed by the  scientific 
   name of the NCBI Taxonomy ID. E.g. For  taxon  code  8287.071,  we  name  it  as 
   spc_Sarcopterygii;
 - For type 2, we use the abbreviation of the rank name followed by the preposition 
   "of" and followed by the scientific name of the NCBI Taxonomy ID. E.g. For taxon 
   code 9605.192, we name it as tri_of_Homo;
 - For type 3, we use the abbreviation of the rank name followed by the preposition 
   "in" and followed by the scientific name of the NCBI Taxonomy ID. E.g. For taxon 
   code 9606.263, we name it as sbs_in_Homo sapiens;

Obs.: Taxa originally ranked in NCBI Taxonomy database have the code 000 and we use 
their own scientific name to name them.


## Retrieving taxonomic lineage


After loading the Taxallnomy database, you can use  the  script  'get_lineage'  to 
programatically retrieve the taxonomic lineage of TaxIDs of interest. To  test  if 
the script is running properly on your system, type the following command:

    > ./get_lineage 

If all goes well, this will show a message like this:


    ERROR Please provide TaxIDs or a file containing a list of TaxIDs.            
    Usage:                                                                        
       ./get_lineage -txid 9606,9595                                              
                                                                                
       ./get_lineage -file <txid_list_file>                                       
                                                                                
       Inputs:                                                                    
           [-txid set_of_taxids] [-file txids_list_file]                          
                                                                                
       Other parameters:                                                          
           [-rank rank_code] [-srank ranks] [-format format_code] [-user          
           mysql_user] [-showcode] [-out file_name]                               
                                                                                
       Help:                                                                      
           [-help] [-man]                                                         
                                                                                
           Use -man for a detailed help.                                          
                                                                                

Detailed instruction for running this script can be accessed by typing:
 
    > ./get_lineage -man
  
This script uses the Perl module 'Net::Wire10' located in the folder 'lib/' that 
accompanies this package. If you want to execute this script in  other  location, 
install this module on your system. The easiest way to install a Perl module  is 
using CPAN. For this, login as root user and type the command:

    > cpan
  
After entering the CPAN environment, type:

    cpan> install Net::Wire10
  
This will install the module Net::Wire10 and its dependencies.

After the module installation, leave the CPAN environment and test the script.
 

## Contact


If you have any suggestion to improve our work  or  any  question,  feel  free  to 
contact us by these email addresses: 

  tetsufmbio@gmail.com (PhD. Tetsu Sakamoto) 

  miguel@icb.ufmg.br (PhD. J. Miguel Ortega)

See also the Taxallnomy website at biodados.icb.ufmg.br/taxallnomy

Laboratorio de Biodados
Universidade Federal de Minas Gerais (UFMG)
Belo Horizonte - MG, Brazil

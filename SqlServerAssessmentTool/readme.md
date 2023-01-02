The SqlAssessment tool is a free lightweight tool that simplifies the assessment of your SQL Server workloads on premise to determine system utilization required for
right sizing on Amazon RDS.
The tool captures CPU, Memory, IOPS and Throughput utilization based on predefined timeframe and make RDS Suggestion on how to right size on AWS.
The tool can be run against a single or multiple MS SQL Server instances.

⚠️ Although this is a non invasive script , make sure you test and run in Dev before you run the script in Prod 

##License
This library is licensed under the MIT-0 License. See the LICENSE file.

##Contact 
For help and support reach out to bacrifai@amazon.com or grab a 30 minutes slot on my calendar:
https://calendly.com/rdstools/30min.

## Installation
1.Download the Tool on c:\ drive 

2.extract the zip file on c:\RDSTools

3.Once unzipped it should look like this:

     c:\RDSTools
     
    \c:\RDSDTools\IN
    
    \c:\RDSTools\Out
    
    \c:\RDSTools\upload
     
The Tool can run in automated mode or Manaul :

## Automated Assessment 
The tool runs from the cmd prompt:
The Tool  by default take in the output from RdsDiscovery tool "c:\RDSTool\out\RdsDiscovery.CSV" and only run assessmnet against server that are ##RDS or RDS Custom compatible .

You can as well create your own sql server list using "Serverstemplate" in c:\RDSTools\in as a guide and pass it on as a paramter to the tool .
Please note that the crreated file has to be .txt format( more about that later) 

For Sql server authentication:

C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -collectiontime 60 
## -- The assessmnet will run against c:\RDSTool\out\RdsDiscovery.CSV
C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -collectiontime 60 -sqlserverendpoint c:\RDSTools\in\server.txt 
##-- the assessmnet will run againt list of servers in  server.txt

for Windows authentication:

C:\RDSTools>SqlServerAssessment.bat -auth W -collectiontime 60
## -- The assessmnet will run against c:\RDSTool\out\RdsDiscovery.CSV
C:\RDSTools>SqlServerAssessment.bat -auth W -collectiontime 60 -sqlserverendpoint c:\RDSTools\in\server.txt
##-- the assessmnet will run againt list of servers in  server.txt

input Paramters:

* auth    . S for Sql server , W for windows Authentication
* login   . Sql server login ( if option is 'S')
* password . Sql server password ( if option is 'S')
* collectiontime . Collectiontime in minutes 
* sqlserverendpoint='C:\RDSTools\out\RdsDiscovery.csv'  . Server list to be assessed by defualt the Tool will read the output from rdsdiscovery tool .
* options  . 
* upload , for manual assessmnet upload ( more about this option , in the manual assessmnet section)
    * C  , cleanup
    * T , Terminate the assessment before the collectiontime end .
    
The Tool will create a Sqlagent Job that will run every minutes to populate 5 tables created in msdb:

* Sql_collectnioStatus: this table will have the collection job information, start time finish time and status.
* Sql_CPucollection: this table will collect 3 key metrics Sql server CPU utilization, system Idle, and other Process Utilization. All 3 metrics are captured as percentage
* Sql_DbIO: this table will capture user DB IO between each collection time (the Delta)
* Sql DBIoTotal: this table will capture user DB Total IO (Read, Write)
* Sql_MemCollection: the table will capture Sql Server Memory Usage, Sql MaxMemory target, os Total Memory OS Available Memory and PLE (more about those metrics in Appendix A).

You can re-run command C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -collectiontime 60  anytime to check on status and remaining time 
If collection still running the tool will tell you how many minutes is left  otherwise it will generate the output files and recommendation
Output and Recommendation:
The tool will generate 4 files per Server in CSV format, th files will be placed in c:\RDSTools\out\:

* CPUCollection: Sql server CPU utilization, System Idle Percentage, Other CPU utlization (OS) per collection time (collection time is one minute)
* Memcollection: Memory usage, Target Memory, Total Memory and PLE per collection time (collection time is one minute)
* SQLDB_IO: User and tempdb, Total IOPS, MB Read and Write per collection time (collection time is one minute)
* CPUinfo: Server CPU Information 

One “SQLAssessmentOutput” file  is generated as well for all  sql servers assessed , the tool will anaylze CPU and Memory data collected during the timeframe and make recommendation .
Each Metric will have one of the 3 recommendations (Fig 4):
1-sacle up
2-scale down
3-Load is acceptable

Scaling up or down matrix.
CPU&Memory scaling up or down matrix
CPU&Memory >= 30 Scale Down
CPU&Memory >=30<=50 Load acceptable
CPU&Memory >=50<=80 Scale Up

The tool will make RDS recommendation based on current on prem architecture and  based on CPU,Memory and IOPS utilization.
 

## Cleanup
To cleanup tables and Sql agent Job run the same command C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -options C . The tool will regenerate all the CSV files and the sqlserverassessmentouput and place them in c:\RDSTools\out and delete the Sql agent job and all tables from all Sql servers.

## Terminate 
To terminate the jobs before  collection is done  C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -collectiontime -options T , Note that terminating the job will not cleanup  the tables and sql server agent job.

## Manual  Assessment 

If you would rather use your preferred third party tool to collect the assessment or maybe due to strict security requirement your are not able to run the automated collections .The tool has the capabilities to manually read csv files as long as they have certain fromat.

The Tool came with a Sql Script that  you can run from query analyzer or  you can schedule it  . c:\RDsTools\in\Sqlassessmentmanaulcollection.sql , the script will mimic the same automated collections that runs through the tool . 

the script will create temp table to store the data as supposed to regular tables 

the script wil take collectiontime as an input .

Once the collectiontime is  done , the script will generate the output 

Save the output as CSV , without the headers ,and place the file in C:\RdsTool\upload 

once you have all files created and placed in the .\upload dir  run the tool with -options upload 

c:\RDSTools\SqlServerAssessment.bat  -options upload

The Tool will read all files in the .\upload dir and generate the SQLAssessmentOutput  and place it in .\IN directory

If you would rather use your third party tool to generate the assessment  you can do so just make sure that the CSV file is created as below and placed in .\upload

Sample File :servername_sample.csv

Columns:

A :ServerName

C: CpuUtilization

D: Cpu95percentile

E: VCPU count

F: Sql server Max Mem setting

H: Memory utilization

I:Throughput

G:TotalIOPS

K: Sql server Edition

L : Sql server Version

M: CollectionTime

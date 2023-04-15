## SQLServerAssessment Tool 
SQLServerAssessment Tool is a lightweight, free tool that simplifies the assessment of your SQL Server workloads on premise to determine system utilization required for right sizing on Amazon RDS. The tool captures CPU, Memory, IOPS, and Throughput utilization based on a predefined timeframe and makes RDS suggestions on how to right size on AWS. This manual provides guidance on how to install, use, and troubleshoot the tool.

⚠️ Although this is a non-invasive script , make sure you test and run in Dev before you run the script in Prod 


##License
This library is licensed under the MIT-0 License. See the LICENSE file.

##Contact 
For help and support reach out to bacrifai@amazon.com or grab a 30 minutes slot on my calendar:
https://calendly.com/rdstools/30min.

## Prerequisites
The tool only works on Windows with PowerShell Script and Excel Sheet. The Excel sheet is needed for the RDS recommendation. You can still run the tool without the Excel Sheet; however, it will not generate the RDS instance recommendation. The Sqlserver Module needs to be imported and installed into your PowerShell. TCP port needs to be opened to your Sql Server(s).
## Installation
1. Download the tool to the C:\  drive.
2. Extract the zip file to  C:\RDSTools.
3. Once unzipped, it should look  like this:
    c:\RDSTools
    c:\RDSTools\IN
    c:\RDSTools\Out
    c:\RDSTools\upload
     
The Tool can run in automated mode or Manual :

## Automated Assessment 
The tool runs from the cmd prompt:
The Tool  by default take in the output from RdsDiscovery tool "c:\RDSTool\out\RdsDiscovery.CSV" and only run assessment against server that are **RDS or RDS Custom compatible.**

You can as well create your own sql server list using "Serverstemplate" in c:\RDSTools\in as a guide and pass it on as a parameter to the tool .
Please note that the created file has to be .txt format( more about that later) 

For Sql server authentication:

**C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -collectiontime 60**

 -- The assessment will run against c:\RDSTool\out\RdsDiscovery.CSV
 
 **C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -collectiontime 60 -sqlserverendpoint c:\RDSTools\in\server.txt** 

-- the assessment will run againt list of servers in  server.txt

for Windows authentication:

 **C:\RDSTools>SqlServerAssessment.bat -auth W -collectiontime 60**

 -- The assessment will run against c:\RDSTools\out\RdsDiscovery.CSV
 
**C:\RDSTools>SqlServerAssessment.bat -auth W -collectiontime 60 -sqlserverendpoint c:\RDSTools\in\server.txt**

-- the assessment will run against list of servers in  server.txt

Input Parameters:

* auth    : S for Sql server , W for windows Authentication
* login   : Sql server login ( if option is 'S')
* password:  Sql server password ( if option is 'S')
* collectiontime : Collectiontime in minutes 
* sqlserverendpoint:'C:\RDSTools\out\RdsDiscovery.csv' . Server list to be assessed by defualt the Tool will read the output from rdsdiscovery tool .
* options  : 
    * upload , for manual assessmnet upload ( more about this option , in the manual assessmnet section)
    * C  , cleanup
    * T , Terminate the assessment before the collectiontime end .
    * 'dbmem' to generate Memory allocation per db . it sill be inb c:\rdstools\in 
    * '95'   to generate RDS insance using  CPu 95 percentile metrics .
    
   i.e  C:\RDSTools>SqlServerAssessment.bat -auth S -login sql -password password -options 'dbmem','95'
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

One “SQLAssessmentOutput” file  is generated as well for all  sql servers assessed , the tool will analyze CPU and Memory data collected during the timeframe and make recommendation .
![image](https://user-images.githubusercontent.com/95581204/210282135-52584f43-32f0-4fb0-8477-8f954e3ba892.png)

Each Metric will have one of the 3 recommendations :

1-sacle up

2-scale down

3-Load is acceptable

Scaling up or down matrix.
* CPU&Memory scaling up or down matrix
* CPU&Memory >= 30 Scale Down
* CPU&Memory >=30<=50 Load acceptable
* CPU&Memory >=50<=80 Scale Up

The tool will make RDS recommendation based on current on prem architecture and  based on CPU,Memory and IOPS utilization.
 

## Cleanup
To cleanup tables and Sql agent Job run the same command C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -options C . The tool will regenerate all the CSV files and the sqlserverassessmentouput and place them in c:\RDSTools\out and delete the Sql agent job and all tables from all Sql servers.

## Terminate 
To terminate the jobs before  collection is done  C:\RDSTools>SqlServerAssessment.bat -auth S -login Sql -Password Password -collectiontime -options T , Note that terminating the job will not cleanup  the tables and sql server agent job.

## Manual  Assessment 

If you would rather use your preferred third party tool to collect the assessment or maybe due to strict security requirement your are not able to run the automated collections .The tool has the capabilities to manually read csv files as long as they have certain format.

The Tool comes with a Sql Script that you can run from query analyzer or  you can schedule it  . c:\RDsTools\in\Sqlassessmentmanaulcollection.sql , the script will mimic the same automated collections that runs through the tool . 

the script will create temp table to store the data as supposed to regular tables 

the script will take collectiontime as an input .
![image](https://user-images.githubusercontent.com/95581204/210281908-bc6d8423-6cf2-4235-a62a-17b2945e6f13.png)


Once the collectiontime is  done , the script will generate below output 
![image](https://user-images.githubusercontent.com/95581204/210281948-f8bcbea9-b32e-4525-b0b6-6836588ff27c.png)

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

**This Tool has very low footprint on your SQl server and it is safe to run against your Production server, to verify run it against any server with no load an observer the CPU memory and IOPS collected.**

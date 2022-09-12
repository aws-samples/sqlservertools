## RDS Discovery Tool 

RDS Discovery Tool is a lightweight ,it provides a capability to scan a fleet of on-prem SQl Servers  and does
automated checks for 20+features , validates supportability of the  enabled features on RDS, and generates a
report which provides recommendation to migrate to RDS, RDS Custom or EC2 compatible. 

:warning: Although this is a on noninvasive script , make sure you test and run in Dev before you run the scrip in Prod 
## License
This library is licensed under the MIT-0 License. See the LICENSE file.

## Installation
1.Download the Tool on c:\ drive 

2.extract the zip file on c:\RDSDiscoveryGuide

3.Once unzipped it should look like this:

     c:\RDSDiscoveryGuide
     
    \c:\RDSDiscoveryGuide\IN
    
     \c:\RDSDiscoveryGuide\Out
      
  "In" Directory will have 3 files "Serverstemplate" , RDSSQLInstances.xlsx  and LimitationQueries.sql.
  
   using the Server Template as a guide create a list of all our servers , you can use IP  or ServerName and if your port is not Default port 
   enter the port as well  i.e. servername,1435 or xxx.xxx.xxx.xxx,1435.                                                                                                    Save the file in the "In" directory. once the server list has been created, you should be ready to run the tool .
   LimitationQueries.sql is the Sql that is used in the Tool , you can take this SQl and run it locally on your server to get a feel of the script.
   

 ## Prerequisites
  The Script will only works on windows with PowerShell Script and Excel Sheet . The Excel sheet is needed for the rds. recommendation.
  You can still run the Tool without excel Sheet it will just not generate the RDS instance. Recommendation 
  ## Execution
  
  The tool will run from cmd prompt in 2 different modes Windows or Sql server :

   - **Windows Authentication** 	

      c:\RDSDiscoveryGuide\RDSDiscovery.exe -auth W -Sqlserverendpoint c:\RDSDiscoveryGuide\in\servers.txt
   - **Sql Server Authentication**
   
     c:\RDSDiscoveryGuide\RDSDiscovery.exe -auth S -login Login -password Password -Sqlserverendpoint c:\RDSDiscoveryGuide\in\servers.txt  
     
			   "Login"  should be member of the Admin Group.
 **By Default the Tool will run and generate all the data without RDS Recommendation , for recommendation run the tool with -options RDS**
 
   - **Windows Authentication** 	

     c:\RDSDiscoveryGuide\RDSDiscovery.exe -auth W -Sqlserverendpoint c:\RDSDiscoveryGuide\in\servers.txt -options rds
     
   - **Sql Server Authentication**
   
    c:\RDSDiscoveryGuide\RDSDiscovery.exe -auth S -login Login -password Password -Sqlserverendpoint c:\RDSDiscoveryGuide\in\servers.txt  -options rds

   For Help with Commands:
   
   c:\RDSDiscoveryGuide\RDSDiscovery.exe -options help
   **Or you can run the Bat file if you can'r or you don;t want to run exe .
   
  
## Ouput 	  
    
The discovery will take few minutes and will generate an excel sheet ( note that the Tool will take a little longer with RDS recommendation included) 

The excel sheet will be  placed in c:\RDSDiscoveryGuide\out

## RDS Discovery Tool 

RDS Discovery Tool is a lightweight ,it provides a capability to scan a fleet of on-prem SQl Servers  and does
automated checks for 20+features , validates supportability of the the enabled features on RDS, and generates a
report which provides recommendation to migrate to RDS, RDS Custom or EC2 compatible. 

:warning: Although this is a on non invasive script , make sure you test and run in Dev before you run the scrip in Prod 
## License
This library is licensed under the MIT-0 License. See the LICENSE file.

## Installation
1.Download the Tool on c:\ drive 

2.extract the zip file on c:\RDSDiscoveryGuide

3.Once unzipped it should look like this:

     c:\RDSDiscoveryGuide
     
    \c:\RDSDiscoveryGuide\IN
    
     \c:\RDSDiscoveryGuide\Out
      
  "In" Directory will have 2 files "Serverstemplate" and RDSSQLInstances.xlsx .
  
   using the ServerTemplate as a guide create a list of all our serevers , you can use IP  or servername and if your port is not Default port 
   enter the port as well  i.e servername,1435 or xxx.xxx.xxx.xxx,1435.                                                                                                    Save the file in the "In" directory. once the server list has been created, you should be ready to run the tool .


 ## Prerequisites
  The Script will only works on windows with Powershell Script and Excel Sheet . The Excel sheet is needed for the rds recommendation.
  You can still run the Tool without excel Sheet it will just not generate the RDS instance. Recomendation 
  ## Execution
  
  The tool will run from cmd prompt in 2 different modes Windows or Sql server :
  
  
	  
   - **Winsows Authentication** 	

      c:\RDSDiscoveryGuide\RDSDiscovery.exe W c:\RDSDiscoveryGuide\in\servers.txt
   - **Sql Server Authentication**
   
     c:\RDSDiscoveryGuide\RDSDiscovery.exe S Login Password c:\RDSDiscoveryGuide\in\servers.txt  
     
			   "Login"  should be member of the Admin Group.
      
    
The discovery will take few minutes and will generate an excel sheet .

The excel sheet will be  placed in c:\RDSDiscoveryGuide\out


  

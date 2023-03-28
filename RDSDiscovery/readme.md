## RDS Discovery Tool 

RDS Discovery Tool is a lightweight ,it provides a capability to scan a fleet of on-prem SQl Servers  and does
automated checks for 20+features , validates supportability of the  enabled features on RDS, and generates a
report which provides recommendation to migrate to RDS, RDS Custom or EC2 compatible. 

:warning: Although this is a noninvasive script , make sure you test and run in Dev before you run the scrip in Prod 
## License
This library is licensed under the MIT-0 License. See the LICENSE file.

## Contact 
For help and support reach out to bacrifai@amazon.com or grab a 30 minutes slot  on my calendar:
https://calendly.com/rdstools/30min.

## Installation
1.Download the Tool on c:\ drive 

2.extract the zip file on c:\RDSTools

3.Once unzipped it should look like this:

     c:\RDSTools
     
    \c:\RDSTools\IN
    
     \c:\RDSTools\Out
      
  "In" Directory will have 3 files "Serverstemplate" , AWSInstances.xlsx  and LimitationQueries.sql.
  
   using the Server Template as a guide create a list of all your servers , you can use IP  or ServerName and if your port is not Default port 
   enter the port as well  i.e. servername,1435 or xxx.xxx.xxx.xxx,1435.                                                                                                    Save the file in the "In" directory. once the server list has been created, you should be ready to run the tool.
   LimitationQueries.sql is the Sql that is used in the Tool, you can take this SQl and run it locally on your server to get a feel of the script.
   

 ## Prerequisites
  The Script will only work on windows with PowerShell Script and Excel Sheet. The Excel sheet is needed for the rds recommendation.
  You can still run the Tool without excel Sheet it will just not generate the RDS instance Recommendation.
  Sqlserver Module needed to be imported and installed into your powershell.
  TCP port has to be opened to your Sql Server(s).
  ## Execution
  
  The tool will run from cmd prompt in 2 different modes Windows or Sql server :

   - **Windows Authentication** 	

      c:\RDSTools\Rdsdiscovery.bat -auth W -Sqlserverendpoint c:\RDSTools\in\servers.txt
   - **Sql Server Authentication**
   
     c:\RDSTools\Rdsdiscovery.bat -auth S -login Login -password Password -Sqlserverendpoint c:\RDSTools\in\servers.txt  
     
			   "Login"  should be member of the Admin Group.
 **By Default the Tool will run and generate all the data without RDS Recommendation , for recommendation run the tool with -options RDS**
 
   - **Windows Authentication** 	

     C:\RDSTools\Rdsdiscovery.bat -auth W -Sqlserverendpoint c:\RDSTools\in\servers.txt -options rds
     
   - **Sql Server Authentication**
   
    C:\RDSTools\Rdsdiscovery.bat -auth S -login Login -password Password -Sqlserverendpoint c:\RDSTools\in\servers.txt  -options rds

   For Help with Commands:
   
   C:\RDSTools\Rdsdiscovery.bat -options help
   **Or you can run the Bat file if you can't or you don't want to run exe .
   
  
## Output 	  
    
The discovery will take few minutes and will generate an excel sheet ( note that the Tool will take a little longer with RDS recommendation included) 

The excel sheet will be  placed in c:\RDSTools\out

## Troubleshooting
If you receive error similar to the one below , that means the sqlserver PS module is not loaded into your system 
![image](https://user-images.githubusercontent.com/95581204/194915978-410cd417-9dec-4a83-a4c5-9030cd8942fd.png)
To install the Powershell module for sql server ,first make sure you start powershell as admin .
then run below command seperatley

1-Set-ExecutionPolicy RemoteSigned

2-Install-module -Name sqlserver

3-Import-Module sqlserver -DisableNameChecking;

Once this is done and to verify sqlserver module has been successfuly loaded run below command
 ## Get-Module -name sqlserver 
 ![image](https://user-images.githubusercontent.com/95581204/194916928-de163bf1-6106-4fb4-ad33-187bc11afa0c.png)





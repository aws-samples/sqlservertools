## RDS Discovery Tool 

The RDS Discovery Tool is a lightweight tool that provides the capability to scan a fleet of on-prem SQL Servers and does automated checks for 20+ features. It validates supportability of the enabled features on RDS and generates a report which provides recommendations to migrate to RDS, RDS Custom, or EC2 compatible.

:warning: Although this is a non-invasive script, make sure you test and run it in Dev before you run the script in Prod.

## License
This library is licensed under the MIT-0 License. See the LICENSE file.

## Contact 
For help and support reach out to bacrifai@amazon.com or grab a 30 minutes slot  on my calendar:
https://calendly.com/rdstools/30min.

## Installation
1. Download the zip file **RDSTools.zip** on c:\ drive 

2. Extract the zip file to the **C:\RDSTools**

3. Verify the following directory structure: (sub-folders should exist)

    - C:\RDSTools 
    - C:\RDSTools\IN 
    - C:\RDSTools\Out
    - C:\RDSTools\upload

      
4. Update the server template **c:\RDSTools\in\servers.txt** 

Use the provided Server Template to create your server list

Format entries as:
FQDN
servername
servername,1435
xxx.xxx.xxx.xxx
xxx.xxx.xxx.xxx,1435

Server Template file located at  **c:\Rdstools\In\serverstemplate** as a guide.

### Example to create a list of all your servers using FQDN
- mysqlserver01.example.com
- mysqlserver02.example.com
- mysqlserver03.example.com,1435


### Example to create a list of all your servers using Hostname
- mysqlserver01
- mysqlserver02
- mysqlserver03,1435

### Example to create a list of all your servers using IP ADDRESSES
- 10.0.0.101
- 10.0.0.102
- 10.0.0.103,1435


### Prerequisites
 The script will only work on Windows with PowerShell Script ,Sqlserver module needs to be imported and installed into your PowerShell. TCP port has to be opened to your SQL Server(s) , and Sql Server sysadmin login is  needed for your fleet of Sql Server.

### Execution
  
  The tool will run from the CMD prompt in 2 different modes, Windows authentication mode or SQL server authentication mode:

   - **Windows Authentication** 	
	Use the W switch to enable Windows authentication mode. By default, the tool will read the SQL server endpoint from C:\RDSTools\IN\servers.txt.
	
	c:\RDSTools\Rdsdiscovery.bat -auth W 
	
	otherwise if your serverlist sits on another Direcory you can pass the location as shown below 
	
        c:\RDSTools\Rdsdiscovery.bat -auth W -Sqlserverendpoint c:\RDSTools\in\servers.txt
     
   - **Sql Server Authentication**
   Use the S switch to enable SQL Server authentication mode and provide a valid SQL Server login and password as shown below:
   
        c:\RDSTools\Rdsdiscovery.bat -auth S -login Login -password Password  
	c:\RDSTools\Rdsdiscovery.bat -auth S -login Login -password Password  -sqlserverendpoint c:\RDSTools\in\servers.txt
     
          Note:	   The "Login" should be a member of the Admin Group. 
	   
 **By default, the tool will run and generate a report without RDS Recommendation. For recommendations, run the tool with -options RDS.**
 
   - **Windows Authentication** 	

     C:\RDSTools\Rdsdiscovery.bat -auth W -Sqlserverendpoint c:\RDSTools\in\servers.txt -options rds
     
   - **Sql Server Authentication**
   
    C:\RDSTools\Rdsdiscovery.bat -auth S -login Login -password Password -Sqlserverendpoint c:\RDSTools\in\servers.txt  -options rds

   For Help with Commands:
   
   C:\RDSTools\Rdsdiscovery.bat -options help
   
   
  
## Output 	  
    
The discovery will take few minutes and will generate an excel sheet ( note that the Tool will take a little longer with RDS recommendation included) 

The excel sheet will be  placed in c:\RDSTools\out
![image](https://github.com/aws-samples/sqlservertools/assets/95581204/76df621b-8a8f-4e3c-ae93-9ab3e711b561)


## Troubleshooting
If you receive error similar to the one below , that means the sqlserver PS module is not loaded into your system 
![image](https://user-images.githubusercontent.com/95581204/194915978-410cd417-9dec-4a83-a4c5-9030cd8942fd.png)
To install the PowerShell module for SQl server, first make sure you start PowerShell as admin.
then run below command separately

1-Set-ExecutionPolicy RemoteSigned

2-Install-module -Name sqlserver

3-Import-Module sqlserver -DisableNameChecking;

Once this is done and to verify sqlserver module has been successfuly loaded run below command
  Get-Module -name sqlserver 
 ![image](https://user-images.githubusercontent.com/95581204/194916928-de163bf1-6106-4fb4-ad33-187bc11afa0c.png)

 





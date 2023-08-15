
Param (
[Parameter()][string]$auth,
[Parameter()][string]$login,
[Parameter()][string]$password,
[Parameter()]$SqlserverEndpoint='c:\rdstools\in\servers.txt',
[parameter()]$options 
 
)
Function TCO
{
$standalonecount=0
$Primarycount=0
$Secondarycount=0
$Readablecount=0
$standaloneSTcount=0
$PrimarySTcount=0
$SecondarySTcount=0
$EEVCPU=0
$STVCPU=0
$total=0
$TotalST=0
$row=1
$FilePath = "c:\rdstools\out\TCO_Calculator_Business_Case_Tool.xlsx"
try{
$objExcel = New-Object -ComObject Excel.Application 
$WorkBook = $objExcel.Workbooks.Open("$FilePath")
$ExcelWorkSheet = $workbook.Sheets.Item("Discovery-Input")
$tcocsv=import-csv C:\RDSTools\out\RdsDiscovery.csv
Foreach ($server in $tcocsv)
{   $servername=$server.'Server Name'
    $serverAG=$server.'Always ON AG enabled'
    $serverAGFCI=$server.'Always ON FCI enabled'
    $dbsize=$server.'Total DB Size in GB'
    $ServerRole=$server.'server role desc'
    $servercpu=$server.'cpu'
    $servermemory=$server.'Memory'
    $serverDBsize=$server.'Total DB Size in GB'
    $serverEdition=$Server.'SQL Server Current Edition'
    $serverInstance=$server.'RDS Compatible'
    $serverEF=$server.'Enterprise Level Feature Used '
    $serverRDSInstance=$server.'Instance Type'
    $serverRDSInstance=$serverRDSInstance
    $serverRDSInstance=$serverRDSInstance.TrimEnd()
        $row++
if ($servername )
{
    if ($serveredition -match 'Enterprise Edition')
        {
            if ($server.'DB Role Desc' -like 'Standalone'){ $standalonecount ++ 
                    $total++}
            elseif ($server.'DB Role Desc' -like 'Primary') { $Primarycount ++ 
                    $total++}
            elseif ($server.'DB Role Desc' -like 'Readable')  { $Readablecount ++ 
                    $total++}
                else  { $Secondarycount ++}
                $EEVCPU=$EEVCPU+$servercpu
                
 
       }
    else 
    {
            if ($server.'DB Role Desc' -like 'Standalone'){ $standaloneSTcount ++
                    $TotalST++}
            elseif ($server.'DB Role Desc' -like 'Primary') { $PrimarySTcount ++
                    $TotalST++}
               elseif ($server.'DB Role Desc' -like 'Secondary')  { $SecondarySTcount ++
                    $TotalST++}
               $STVCPU=$STVCPU+$servercpu
               
    }
 
$ExcelWorkSheet.Cells.Item($row,1)=$servername
$ExcelWorkSheet.Cells.Item($row,2)=$servercpu
$ExcelWorkSheet.Cells.Item($row,3)=$servermemory
$ExcelWorkSheet.Cells.Item($row,4)=$serverDBsize
if ($serverEdition -match 'Enterprise')
{$ExcelWorkSheet.Cells.Item($row,5) ='Enterprise'}
elseif ($serverEdition -match 'Standard')
{$ExcelWorkSheet.Cells.Item($row,5) ='Standard'}
if (($serverAG -eq 'N') -and ($serverAGFCI -eq 'N'))
{$ExcelWorkSheet.Cells.Item($row,6)='N'}
Else {$ExcelWorkSheet.Cells.Item($row,6)='Y'}
$ExcelWorkSheet.Cells.Item($row,7)=$serverAGFCI
$ExcelWorkSheet.Cells.Item($row,8)=$serverAG
$ExcelWorkSheet.Cells.Item($row,9)=$ServerRole
if ($ServerRole -eq 'Readable')
   { $ExcelWorkSheet.Cells.Item($row,10)='Y'
    $ExcelWorkSheet.Cells.Item($row,9)='Secondary'}
else {$ExcelWorkSheet.Cells.Item($row,10)='N'}
$ExcelWorkSheet.Cells.Item($row,11)=$serverRDSInstance
$ExcelWorkSheet.Cells.Item($row,12)=100
if ($serveref )
{$ExcelWorkSheet.Cells.Item($row,13)='Y'}
else {$ExcelWorkSheet.Cells.Item($row,13)='N'}
$ExcelWorkSheet.Cells.Item($row,14)=$serverRDSInstance
}
}#foreach
$workbook.Close($true)
 }#try
catch
{ Write-Host 'Excel Sheet has not been detected on this Machine ,TCO will not be updated' -ForegroundColor Magenta
}
}

Function Executive_summary {
param(
[Parameter(Mandatory=$True)]$report
)
$i=6
$head = @"
<style>
    body
  {
      background-color: Gainsboro;
  }
    table, th, td{
      border: 1px solid;
    }
    h1{
        background-color:Blue;
        color:white;
        text-align: center;
    }
</style>
"@
#$servercount=(Get-Content C:\RDSTools\In\servers.txt).Length
#$FilePath = "c:\rdstools\out\TCO Calculator_Business Case Tool.xlsx"
#$objExcel = New-Object -ComObject Excel.Application 
#$WorkBook = $objExcel.Workbooks.Open("$FilePath")
#$ExcelWorkSheet = $workbook.Sheets.Item("Input ( Discovery)")

$reportheader=$report|select-object @{Name="ServerName";Expression={$_.'server name'}},@{Name=" VCPU ";Expression={$_.'CPU'}},@{Name="Memory";Expression={$_.'Memory'}},@{Name=" Total DB Size in GB ";Expression={$_.'Total DB Size in GB'}},@{Name="Server Role ";Expression={$_.'Server Role Desc'}},@{Name="Read Only Replica ";Expression={$_.'Read Only Replica'}},@{Name="SQL Server Edition ";Expression={$_.'SQL Server Current Edition'}},@{Name=" RDS Compatible ";Expression={$_.'RDS Compatible'}},@{Name=" RDS Custom Compatible ";Expression={$_.'RDS Custom Compatible'}},
@{Name=" EC2 Compatible  ";Expression={$_.'EC2 Compatible'}},@{Name=" Enterprise Level Feature Used";Expression={$_.'Enterprise Level Feature Used '}},@{Name=" Instance Type  ";Expression={$_.'Instance Type'}}
#@{Name="RDSRightSizing";Expression={$ExcelWorkSheet.Cells.Item($i,15).Text}};($i++)
$reportheader |convertto-html  -Title "report" -PreContent "<H1>SQL Server Discovery Report</H1>" -PostContent "<H5><i>$(get-date)</></h5>" -Head $head|out-file C:\RDSTools\out\RDSDiscoveryreport.html  
Invoke-Item C:\RDSTools\out\RDSDiscoveryreport.html 

}
Function EC2Instance

{

Param(

        [Parameter(Mandatory=$True)]$EC2orRDS,

        [Parameter(Mandatory=$True)]$cpuonprem,

        [Parameter(Mandatory=$True)]$Memoryprem,

        [Parameter(Mandatory=$false)]$cpuutlization,

        [Parameter(Mandatory=$false)]$Memutlization

       )

$fileec2=import-csv "C:\RDSTools\in\AwsInstancesec2csv.csv"

$rowMax = ($fileec2).Count

[System.Collections.ArrayList]$RDSArray = @()

$objTemp=''

     $RdsArray.add($RDSval) | Out-Null

     $val=$null

for ($i = 2; $i -le $rowMax ; $i++)

{

   $InstanceName = $fileec2[$i]."instance type"

    $csvmemory = $fileec2[$i].memory

    $csvvcpu = $fileec2[$i].vcpu

  # if ([int]$csvvcpu  -ge [int]$cpuonprem -and $InstanceName -like "m6i*" )

   if ([int]$csvvcpu  -ge [int]$cpuonprem -and $csvvcpu  -lt [int]$cpuonprem )

  

    {

    

    $RDSval = [pscustomobject]@{'InstanceName'=$InstanceName}

    $RDSArray.add($RDSval) | Out-Null

      $val=$null

      $RDSInstance= $RDSArray.instancename

       # $RDSInstance= $RDSArray.instancename| Select-Object -Unique|where {$_ -like "m6i*" }

break

    }

        }

         #}

       

 

$RDSInstance=($RDSInstance -join ",")

$RDSInstance

 

       }#function EC2Instance
Function RDSInstance
{
Param(
        [Parameter(Mandatory=$True)]$EC2orRDS,
        [Parameter(Mandatory=$True)]$cpuonprem,
        [Parameter(Mandatory=$True)]$Memoryprem,
        [Parameter(Mandatory=$false)]$cpuutlization,
        [Parameter(Mandatory=$false)]$Memutlization
       )
$class=''
$RDSInstance=''
$rdsval=''
if ($SqlEditionProduct.edition -like 'Enterprise Edition*')
    {       $edition='EE'}
else {$edition ='SE'}    
$version=$SqlEditionProduct.productversion.substring(0,2)
if ($Memoryprem -gt '1025') {$Memoryprem =1025}
$cpuonprem=[math]::ceiling($cpuonprem/4)
if ($Memoryprem -lt '1025')
{
          if ($cpuonprem  -ge  25)
                  {$class='32xlarge'}
           if ($cpuonprem  -le 24 -and $cpuonprem -gt 16)
                {$class='24xlarge'}
           if ($cpuonprem -le 16 -and $cpuonprem -gt 12)
                {$class='16xlarge'}
           if ($cpuonprem -le 12 -and $cpuonprem -gt 8)
                {$class='12xlarge'}
           if ($cpuonprem -le 8 -and $cpuonprem -gt 4)
                {$class='8xlarge' }
           if ($cpuonprem -le 4 -and $cpuonprem -gt 2)
                {$class='4xlarge' }
           if ($cpuonprem -le 2 -and $cpuonprem -gt 1)
                {$class='2xlarge'}
           if ($cpuonprem -le 1 )
                 {$class='xlarge'}
            if ($cpuonprem -eq 0  )
                {$class='large'}
                }
if ($cpuutlization -ge '80' -and  $Memutlization -ge '80')
      {  $CLASS=switch ($class)
                {'2Xlarge' {'4xlarge'}
                '4Xlarge' {'8xlarge'}
                '8Xlarge' {'12xlarge'}
                '12Xlarge' {'16xlarge'}
                '16Xlarge' {'24xlarge'}
                '24Xlarge' {'32xlarge'}
                '32Xlarge' {'32xlarge'}
          }
          $type='M'
         }
elseif ($cpuutlization -ge '80' -and $Memutlization -le '80')
    {  $CLASS=switch ($class)
                {'2Xlarge' {'4xlarge'}
                '4Xlarge' {'8xlarge'}
                '8Xlarge' {'12xlarge'}
                '12Xlarge' {'16xlarge'}
                '16Xlarge' {'24xlarge'}
                '24Xlarge' {'32xlarge'}
                '32Xlarge' {'32xlarge'}
          }
       $type='G' }
elseif  ($cpuutlization -le '80' -and $Memutlization -ge '80')
    {  
       $type='M' }
  elseif  ($cpuutlization -lt '50' -and $Memutlization -lt '50') #scale Down.
    {   if ($class -ne 'Xlrage')
            {  $CLASS=switch ($class)
                {'2Xlarge' {'xlarge'}
                '4Xlarge' {'2xlarge'}
                '8Xlarge' {'4xlarge'}
                '12Xlarge' {'8xlarge'}
                '16Xlarge' {'12xlarge'}
                '24Xlarge' {'16xlarge'}
                '32Xlarge' {'24xlarge'}
                  }
             }
       $type='G' }
  else {  $type='G'}
if ($Memoryprem -ge 1025 )
{ $class='32xlarge'
}
$file=import-csv "C:\RDSTools\in\AwsInstancescsv.csv"

$rowMax = ($file).Count
[System.Collections.ArrayList]$RDSArray = @()
$objTemp=''
     $RdsArray.add($RDSval) | Out-Null
     $val=$null
for ($i = 2; $i -le $rowMax ; $i++)
{
   $InstanceName = $file[$i]."instance type"
    $csvversion = $file[$i].version
    $csvedition = $file[$i].edition
    $csviops = [int]$file[$i].iops
    $csvthroughput = [int]$file[$i].throughput
     if ($InstanceName -like "*.$class*" -and $csvedition -eq $edition  -and $csvversion -match $version )
  
{
    $RDSval = [pscustomobject]@{'InstanceName'=$InstanceName;'Version'=$version;'Edition'=[string]$edition}
    $RDSArray.add($RDSval) | Out-Null
      $val=$null
    }
   
         }
         
 
       
if ($Memoryprem -le 1024)
{
   if ($type -eq 'M')
       {       
        $RDSInstance= $RDSArray.instancename| Select-Object -Unique|where {$_ -notlike "db.m*" -and $_ -notlike "db.r3*" -and $_  -notlike "db.r4*" -and $_ -notlike "db.t3*" -and $_ -notlike "db.x1*"-and $_ -notlike "db.x1e*"}
       } 
 
    elseif ($type -eq 'G')
      {
       $RDSInstance=$RDSArray.instancename| Select-Object -Unique|where {$_ -like "db.m*" }#-and $_ -notlike "db.r3*" -and $_  -notlike "db.r4*" -and $_ -notlike "db.t3*"}
      }
}
Elseif ($Memoryprem -gt 1024)
{
$RDSInstance= $RDSArray.instancename| Select-Object -Unique|where {$_ -like "db.x*" }
  }
$RDSInstance=($RDSInstance -join ",")
$instance=$RDSInstance.split(",")
$RDSInstance=$instance[0]
$RDSInstance
}#rdsinstance.
function L100Questions
{
    $SQLServerLocation=read-host "Where is the current SQL Server workload running on, OnPrem[1], EC2[2], or another Cloud[3]?"
    $License=read-host "Do you currently own any SQL Server licenses that you could bring to the Cloud?Y\N"
        if ($license -eq'Y')
                {
                    $perpetual=read-host "Are you using perpetual license and paying software assurance? Y\N"
                    $subscription=read-host  "Are you using subscription license and paying subscription cost? Y\N"
                    $BYOL=read-host "will you be open to consider using a managed service with License Included, assuming we could make the economics work? Y\N"
                }
    $RDSValue=read-host "Do you see value of having AWS manage your SQL databases? Y\N"
       if ($rdsValue -eq 'Y')
                {
                    $RdsMotivation=read-host "then what are the primary motivations (e.g. cost saving, staff productivity, operational resilience, business agility)?"
                }
    $Migrationtimeframe=Read-host "What is the timeline for SQL Server migration to the Cloud? (Please input an estimated target date in No of Months )"
    return $SQLServerLocation,$License,$perpetual,$subscription,$BYOL,$RDSValue,$RdsMotivation,$Migrationtimeframe
    
}
function SqlserverDiscovery
  {
$sqlVE='select SERVERPROPERTY(''Edition'') AS Edition ,SERVERPROPERTY (''productversion'') AS ProductVersion,SERVERPROPERTY (''IsClustered'') as [Clustered]'
if ($auth -eq 'W') 
{ 
$SQLVEresult=invoke-sqlcmd -serverInstance $server -Database master  -query $sqlVE
}
else 
{
$SQLVEresult=invoke-sqlcmd -serverInstance $server -Database master -user $login -query $sqlVE -password $password
}
return $sqlveresult
      
}#sqlserverdiscovery Function
function L200Discovery
{
    Param(
        [Parameter(Mandatory=$True)]$dbserver,
        [Parameter(Mandatory=$True)]$DBName,
        [Parameter(Mandatory=$false)]$User,
        [Parameter(Mandatory=$false)]$password
       )
if ($auth -eq 'W') 
{
$sqlLfeatures=invoke-sqlcmd -serverInstance $server -Database master  -inputfile "C:\RDSTools\In\LimitationQueries.sql" #-query $sql 
}
else 
{
$sqlLfeatures=invoke-sqlcmd -serverInstance $server -Database master -user $login  -inputfile "C:\RDSTools\In\LimitationQueries.sql" -password $password
}
return $sqlLfeatures
}
function Test-SQLConnection
{    
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    Position=0)]
        $ConnectionString
    )
    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString;
        $sqlConnection.Open();
        $sqlConnection.Close();
        return $true;
    }
    catch
    {
        return $false;
    }
}
    
# Main  Function ****************************************************************************************************************
if ($options -eq 'help')
  { write-host " To run the Tool you can either run it using Sql Server Authentication or windows authentication"
    Write-host "   For Sql Server Auth :"
    Write-host "     Rdsdiscoveryguide.exe -Auth s -login ''login'' -password ''password'' -sqlserverendpoint C:\RDSTools\in\server.txt" -ForegroundColor Green
    Write-host "   For Windows authentication"
    Write-host "     Rdsdiscoveryguide.exe -Auth W -sqlserverendpoint C:\RDSTools\in\server.txt" -ForegroundColor Green
    Write-host " By the default the tool will run without RDS Recommendation"
    write-host " To include recommendation run this tool with -option rds"
    Write-host " i.e Rdsdiscoveryguide.exe -Auth W -sqlserverendpoint C:\RDSTools\in\server.txt -options rds" -ForegroundColor Green
    Write-host " OR instead of the exe you can run the bat file "
    Write-host " Rdsdiscovery.bat -Auth s -login ''login'' -password ''password'' -sqlserverendpoint C:\RDSTools\in\server.txt" -ForegroundColor green
    exit
  }
[System.Collections.ArrayList]$RDSArray = @()
        [System.Collections.ArrayList]$ArrayWithHeader = @()
        $RdsArray.add($RDSval) | Out-Null
        $val=$null
         $RDSval=''
         $rdsCustomcompatible='Y'
         $rdscompatible='Y'
        $EC2orRDS=''
        $cpuonprem=''
        $Memoryprem=''
$objTemp=''
$copywrite =[char]0x00A9 
Write-Host 'RdsDiscovery Ver 3.00' $copywrite 'BobTheRdsMan.' -ForegroundColor Magenta
Write-Host 'Disclaimer: This Tool is not created or supported by AWS. ' -ForegroundColor Magenta
Write-Host 'Although it is a low risk please make sure  you test in dev before running it in prod.' -ForegroundColor Magenta
Write-Host '  For Help run the tool with -options help i.e Rdsdiscoveryguide.bat -options help' -ForegroundColor green
Write-Host 'To report Bugs or issues please email bacrifai@amazon.com'-ForegroundColor Magenta
$CpuSql ="SELECT cpu_count AS CPU FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);"
$MemSql="SELECT  convert(int,value_in_use)/1024 as MaxMemory FROM sys.configurations
WHERE name like 'max server memory%' "
$FileExists=Test-Path -Path $SqlserverEndpoint
if (-Not $FileExists)
  {
   Write-host " Input file  Doesn't exists, Make sure you update the server.txt in Rdstools\in" -ForegroundColor red
  exit
  } # $fileexists
  
  # L100Questions
   $SQLServerLocation=read-host "Where is the current SQL Server workload running on, OnPrem[1], EC2[2], or another Cloud[3]?"
    $License=read-host "Do you currently own any SQL Server licenses that you could bring to the Cloud?Y\N"
        if ($license -eq'Y')
                {
                    $perpetual=read-host "Are you using perpetual license and paying software assurance? Y\N"
                    $subscription=read-host  "Are you using subscription license and paying subscription cost? Y\N"
                    $BYOL=read-host "will you be open to consider using a managed service with License Included, assuming we could make the economics work? Y\N"
                }
    $RDSValue=read-host "Do you see value of having AWS manage your SQL databases? Y\N"
       if ($rdsValue -eq 'Y')
                {
                    $RdsMotivation=read-host "then what are the primary motivations (e.g. cost saving, staff productivity, operational resilience, business agility)?"
                }
    $Migrationtimeframe=Read-host "What is the timeline for SQL Server migration to the Cloud? (Please input an estimated target date in No of Months )"
$SqlserverEndpoint=Get-Content $SqlserverEndpoint
foreach ($server in $SqlserverEndpoint)
  {
  $rdscompatible='Y'
  $rdsCustomcompatible='Y'
  if ($auth -eq 'W')
       {
            $Conn="Data Source=$server;database=master;Integrated Security=True;" 
        }
    else {
            $Conn="Data Source=$server;User ID=$login;Password=$password;" 
         }
     if (Test-SqlConnection $Conn)
    { 
      if ($auth -eq 'W' )
         {  
            $L200Result=L200Discovery -dbserver $server -DBName master 
            $SqlEditionProduct=SqlserverDiscovery -dbserver $server -DBName master 
            $cpuresult=invoke-sqlcmd -serverInstanc $server -Database master  -query $CpuSql 
            $Memresult=invoke-sqlcmd -serverInstance $server -Database master  -query $Memsql 
            
             }
       Else {
             $L200Result=L200Discovery -dbserver $server -DBName master -user $login -password $password 
             $SqlEditionProduct=SqlserverDiscovery -dbserver $server -DBName master -user $login -password $password 
             $cpuresult=invoke-sqlcmd -serverInstanc $server -Database master -user $login -query $CpuSql -password $password
             $Memresult=invoke-sqlcmd -serverInstance $server -Database master -user $login -query $Memsql -password $password
            }
If ($options -eq 'RDS')
    {$Ec2orrds='RDS'
     $Instance=Rdsinstance $Ec2orrds $cpuresult.CPU $memresult.MAXMemory 50 50
         }
if ($options -eq 'TCO')
    {$Ec2orrds='RDS'
     #$Instance=Rdsinstance $Ec2orrds $cpuresult.CPU $memresult.MAXMemory 50 50
   
     #Tco
     }
           if ($L200Result.dbcount -eq 'Y' -or $L200Result.islinkedserver -eq 'Y' -or $L200Result.issqlTLShipping -eq 'Y' -or $L200Result.isFilestream -eq 'Y' -or $L200Result.isResouceGov -eq 'Y' -or $L200Result.issqlTranRepl -eq 'Y'`
            -or $l200Result.isextendedProc -eq 'Y'  -or $L200Result.istsqlendpoint -eq 'Y'         -or $L200Result.ispolybase -eq 'Y' -or $L200Result.isfiletable -eq 'Y' -or $L200Result.isbufferpoolextension -eq 'Y'`
              -or $L200Result.isstretchDB -eq 'Y' -or $L200Result.UsedSpaceGB -eq 'Y' -or $L200Result.istrustworthy -eq 'Y' -or $L200Result.Isservertrigger -eq 'Y'`  -or $L200Result.isRMachineLearning -eq 'Y' -or $L200Result.ISPolicyBased -eq 'Y' `
              -or $L200Result.isdqs  -eq 'Y' -or $L200Result.isfree  -eq 'Y') 
           {$rdscompatible='N' }
             else {$rdscompatible='Y'}
    if ($SQLServerLocation -eq 1 )
         { $SQLServerLocation='ONPrem'}
     elseif  ($SQLServerLocation -eq 2 )
          { $SQLServerLocation='EC2'}
     elseif ($SQLServerLocation -eq 3 )
          { $SQLServerLocation='Another Cloud'}
if ( $L200Result.UsedSpaceGB  -gt 14901.161)
    {$rdscompatible='N'
     $rdsCustomcompatible='N'
       if ($options -eq 'RDS') 
          {$Ec2orrds='Ec2'
           $Instance=EC2Instance  $Ec2orrds $cpuresult.CPU $memresult.MAXMemory 50 50
          }
    }

if ($rdscompatible -eq 'N')
      {
   
        $val = [pscustomobject]@{'Server Name'=$server;'Where is the current SQL Server workload running on, OnPrem[1], EC2[2], or another Cloud[3]?'=[string]$SQLServerLocation;
                'Do you currently own any SQL Server licenses that you could bring to the Cloud?Y\N'=[string]$License ;
                'Are you using perpetual license and paying software assurance? Y\N'=[string]$perpetual;
                'Are you using subscription license and paying subscription cost? Y\N'=[string]$subscription;
                'will you be open to consider using a managed service with License Included, assuming we could make the economics work? Y\N'=[string]$BYOL;
                'Do you see value of having AWS manage your SQL databases? Y\N'=[string]$RDSValue;
                'Then what are the primary motivations (e.g. cost saving, staff productivity, operational resilience, business agility)?'=[string]$RdsMotivation;
               'What is the timeline for SQL Server migration to the Cloud? (Please input an estimated target date in No of Months )'=[string]$migrationtimeframe;
                'SQL Server Current Edition'=   $SqlEditionProduct.edition;
                'SQL Server current Version'=   $SqlEditionProduct.productversion;
                'Sql server Source'=$L200Result.source;
                'SQL Server Replication'= [string]$L200Result.issqlTranRepl;
                'Heterogeneous linked server'=[string]$L200Result.islinkedserver;
                'Database Log Shipping '=[string]$L200Result.issqlTLShipping ;
                'FILESTREAM'=[string]$L200Result.isFilestream;
                'Resource Governor'=[string]$L200Result.isResouceGov;
                'Service Broker Endpoints '=[string]$L200Result.issqlServiceBroker;
                'Non Standard Extended Proc'=[string]$L200Result.isextendedProc;
                'TSQL Endpoints' =[string]$L200Result.istsqlendpoint;
                'PolyBase'=[string]$L200Result.ispolybase;
                'File Tabel'=[string]$L200Result.isfiletable;
                'buffer Pool Extension'=[string]$L200Result.isbufferpoolextension;
                'Stretch DB'=[string]$L200Result.isstretchDB;
                'Trust Worthy On'= [String]$L200Result.istrustworthy;
                'Server Side Trigger'=[string]$L200Result.Isservertrigger;
                'R & Machine Learning'=[string]$L200Result.isRMachineLearning;
                'Data Qulaity Services'=[string]$L200Result.isDQS;
                'Policy Based Management'=[string]$L200Result.ISPolicyBased; 
                'CLR Enabled (only supportd in Ver 2016)'=[String]$L200Result.isCLREnabled;
                ' Free Check'=[string]$L200Result.isfree;
                'DB count Over 100'=[string]$L200Result.dbcount;
                'Total DB Size in GB'=[String]$L200Result.UsedSpaceGB;
                'Always ON AG enabled'=[String]$L200Result.IsAlwaysOnAG;
                'Always ON FCI enabled'=[String]$L200Result.isalwaysonFCI;
                'Server Role Desc'=[string]$l200Result.DBRole;
                'Read Only Replica'=[String]$L200Result.IsReadReplica;
                'RDS Compatible' =$rdscompatible;
                'RDS Custom Compatible'=$rdsCustomcompatible;
                'EC2 Compatible'='Y';
                'Enterprise Level Feature Used '=[string]$L200Result.isEEFeature;
                'Memory'=$memresult.MAXMemory;
                'CPU'   =$cpuresult.CPU;
                 'Instance Type'=[string]$instance;
                'Note'=[string]'***** Plase Note That the Discovery Tool will only detect if a feature is turned on or not ,a feature may be turned on but not used .Use the Queries found in the IN directory to investigate'
                } #@val
    }#if $Rdscompatible
    else 
       {
   
        $val = [pscustomobject]@{'Server Name'=$server;'Where is the current SQL Server workload running on, OnPrem[1], EC2[2], or another Cloud[3]?'=[string]$SQLServerLocation;
                'Do you currently own any SQL Server licenses that you could bring to the Cloud?Y\N'=[string]$License;
                'Are you using perpetual license and paying software assurance? Y\N'=[string]$perpetual;
                'Are you using subscription license and paying subscription cost? Y\N'=[string]$subscription;
                'will you be open to consider using a managed service with License Included, assuming we could make the economics work? Y\N'=[string]$BYOL;
                'Do you see value of having AWS manage your SQL databases? Y\N'=[string]$RDSValue;
                'Then what are the primary motivations (e.g. cost saving, staff productivity, operational resilience, business agility)?'=[string]$RdsMotivation;
                'What is the timeline for SQL Server migration to the Cloud? (Please input an estimated target date in No of Months )'=[string]$migrationtimeframe;
                'SQL Server Current Edition'=   $SqlEditionProduct.edition;
                'SQL Server current Version'=   $SqlEditionProduct.productversion;
                'Sql server Source'=$L200Result.source;
                'SQL Server Replication'= [string]$L200Result.issqlTranRepl;
                'Heterogeneous linked server'=[string]$L200Result.islinkedserver;
                'Database Log Shipping '=[string]$L200Result.issqlTLShipping ;
                'FILESTREAM'=[string]$L200Result.isFilestream;
                'Resource Governor'=[string]$L200Result.isResouceGov;
                'Service Broker Endpoints '=[string]$L200Result.issqlServiceBroker;
                'Non Standard Extended Proc'=[string]$L200Result.isextendedProc;
                'TSQL Endpoints' =[string]$L200Result.istsqlendpoint;
                'PolyBase'=[string]$L200Result.ispolybase;
                'File Tabel'=[string]$L200Result.isfiletable;
                'buffer Pool Extension'=[string]$L200Result.isbufferpoolextension;
                'Stretch DB'=[string]$L200Result.isstretchDB;
                'Trust Worthy On'= [String]$L200Result.istrustworthy;
                'Server Side Trigger'=[string]$L200Result.Isservertrigger;
                'R & Machine Learning'=[string]$L200Result.isRMachineLearning;
                'Data Qulaity Services'=[string]$L200Result.isDQS;
                'Policy Based Management'=[string]$L200Result.ISPolicyBased; 
                'CLR Enabled (only supportd in Ver 2016)'=[String]$L200Result.isCLREnabled;
                ' Free Check'=[string]$L200Result.isfree;
                'DB count Over 100'=[string]$L200Result.dbcount;
                'Total DB Size in GB'=[String]$L200Result.UsedSpaceGB;
                'Always ON AG enabled'=[String]$L200Result.IsAlwaysOnAG;
                'Always ON FCI enabled'=[String]$L200Result.isalwaysonFCI;
                'Server Role Desc'=[string]$l200Result.DBRole;
                'Read Only Replica'=[String]$L200Result.IsReadReplica;
                'RDS Compatible' =$rdscompatible;
                'RDS Custom Compatible'=$rdsCustomcompatible;
                'EC2 Compatible'='Y';
                'Enterprise Level Feature Used'=[string]$L200Result.isEEFeature;
                'Memory'=$memresult.MAXMemory;
                'CPU'   =$cpuresult.CPU;
                'Instance Type'=[string]$instance
                } #@val
    }#else $Rdscompatible
         
            $ArrayWithHeader.add($val)| Out-Null
              $val=$null
         
    
             }#if
    else 
    {    #write-host $server
          write-host "***** Can't connect to $server"
          }#else
             $ArrayWithHeader|export-Csv -LiteralPath "C:\RDSTools\out\RdsDiscovery.csv" -NoTypeInformation -Force
       }#foreach
  if ($options -eq 'TCO')
    {TCO} 
 Executive_summary $ArrayWithHeader
$val = [pscustomobject]@{'Server Name'=''}
             #      $val =[pscustomobject]@{'Note'=$Note}
          $ArrayWithHeader.add($val)| Out-Null
          $val = [pscustomobject]@{'Where is the current SQL Server workload running on, OnPrem[1], EC2[2], or another Cloud[3]?'='****Note: Instance recommendation is general purpose based on server CPU and Memory capacity , and it is matched by CPU '}
             #      $val =[pscustomobject]@{'Note'=$Note}
          $ArrayWithHeader.add($val)| Out-Null
               $val=$null
              # $ArrayWithHeader.columns.item("A:AQ").EntireColumn.AutoFit() | out-null
            $ArrayWithHeader|export-Csv -LiteralPath "C:\RDSTools\out\RdsDiscovery.csv" -NoTypeInformation -Force
         


      
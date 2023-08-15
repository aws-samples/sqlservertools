Param (
[Parameter()][string]$auth,
[Parameter()][string]$login,
[Parameter()][string]$password,
[Parameter()]$collectiontime=60,
[Parameter()]$sqlserverendpoint='C:\RDSTools\out\RdsDiscovery.csv',
[Parameter()]$sa='sa',
[parameter()][array]$options 
 
) 
Function TCO
{
try{
#cmd.exe /c "copy c:\rdstools\out\TCO_Calculator_Business_Case_Tool.xlsx  c:\rdstools\out\TCO_Calculator_Business_Case_Tool+$timestamp.xlsx"
$row=1
$i=1
$servercount=(Get-Content $sqlserverendpoint).Length
$FilePath = "c:\rdstools\out\TCO_Calculator_Business_Case_Tool.xlsx"
$FileExists=Test-Path -Path $Filepath
if ( -not $FileExists) {exit}
$objExcel = New-Object -ComObject Excel.Application 
$WorkBook = $objExcel.Workbooks.Open("$FilePath")
$ExcelWorkSheet = $workbook.Sheets.Item("Discovery-Input")
$tcocsv=import-csv C:\RDSTools\out\SQLAssesmentOutput.csv
Foreach ($server in $tcocsv)
{ 
    $servercpu=$server.'CPU Pressure Utilization(%)'
    $serverRDSInstance=$server.'RDS Recommendation based on load'
    $serverRDSInstance=$serverRDSInstance
    $instance=$serverRDSInstance.split(",")
    $serverRDSInstance=$instance[0]
    $serverRDSInstance=$serverRDSInstance.TrimEnd()
     $row=2
for ($i = 1; $i -le $servercount; $i++)
    {
        $servername=$ExcelWorkSheet.Cells.Item($row,1).text
        if ($servername -eq $server.'Server Name')
        {$ExcelWorkSheet.Cells.Item($row,12)=$servercpu
         $ExcelWorkSheet.Cells.Item($row,14)=$serverRDSInstance
         }
        $row++
    }
}
$workbook.Close($true)
 }#try
catch
{ Write-Host 'Excel Sheet has not been detected on this Machine ,TCO will not be updated' -ForegroundColor Magenta
}

}#foreach
Function Executive_summary {
param(
[Parameter(Mandatory=$True)]$report
)
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
        background-color:Tomato;
        color:white;
        text-align: center;
    }
</style>
"@
$reportheader=$report|select-object @{Name="ServerName";Expression={$_.'server name'}},@{Name=" VCPU ";Expression={$_.'Logical CPU Count'}},@{Name=" Memory(GB) ";Expression={$_.'MaxMemorySettings GB'}},
@{Name="  CPU Utilization ";Expression={$_.'CPU Pressure Utilization(%)'}},@{Name=" CPU 95 Percentile ";Expression={$_.'CPu95Percentile'}},@{Name=" Memory Utlization ";Expression={$_.'Server Memory Utlization%'}},
@{Name=" Total iops ";Expression={$_.'Totaliops'}},@{Name="Throughput";Expression={$_.'ThroughPut(MB)'}},@{Name=" SQl server edition ";Expression={$_.'SQl server edition'}},@{Name=" SQl server Version ";Expression={$_.'Sql server version'}},
@{Name=" RDS Instance ";Expression={$_.'RDS Recommendation based on load'}}
$reportheader |convertto-html  -Title "report" -PreContent "<H1>SQLAssessment Report</H1>" -PostContent "<H5><i>$(get-date) </></h5>" -Head $head| foreach {$PSItem -replace "<td>100</td>", "<td style='background-color:#FF8080'>100</td>" }|out-file C:\RDSTools\out\SqlAssessmentReport.html  
 
Invoke-Item C:\RDSTools\out\SqlAssessmentReport.html 
#-CssUri C:\RDSTools\in\style.css 
#<H5>this report was produced by <a href="https://rdstools.d1m9acb3dnc55n.amplifyapp.com/ " RDStools </a></H5> 
 
}
Function Terminate_Job {
Param(
        [Parameter(Mandatory=$True)]$dbserver,
        [Parameter(Mandatory=$True)]$DBName,
        [Parameter(Mandatory=$False)]$User,
        [Parameter(Mandatory=$False)]$password 
        )
         write-host "Terminate Collection Job for Server $dbServer"
                   $sql = "update msdb.dbo.SQL_CollectionStatus set jobstatus='Finished'  ,Current_Sample_ID=Max_Sample_ID"
if ( $auth -eq 'W')
         {$SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database msdb -query $sql }
else   {$SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database msdb -user $User -query $sql -password $password}
}#terminate Job
function DB_memory {
Param(
        [Parameter(Mandatory=$True)]$dbserver,
        [Parameter(Mandatory=$True)]$DBName,
        [Parameter(Mandatory=$False)]$User,
        [Parameter(Mandatory=$False)]$Password
    )
    
    $db_memsql='-- Note: querying sys.dm_os_buffer_descriptors
                -- requires the VIEW_SERVER_STATE permission.
                    DECLARE @total_buffer INT;
                    SELECT @total_buffer = cntr_value
                    FROM sys.dm_os_performance_counters 
                    WHERE RTRIM([object_name]) LIKE ''%Buffer Manager''
                    AND counter_name = ''Database Pages'';
                    ;WITH src AS
                    (
                      SELECT 
                      database_id, db_buffer_pages = COUNT_BIG(*)
                      FROM sys.dm_os_buffer_descriptors
                      --WHERE database_id BETWEEN 5 AND 32766
                     GROUP BY database_id
                    )
                    SELECT
                    [db_name] = CASE [database_id] WHEN 32767 
                    THEN ''Resource DB'' 
                    ELSE DB_NAME([database_id]) END,
                    db_buffer_pages,
                    db_buffer_MB = db_buffer_pages / 128,
                    db_buffer_percent = CONVERT(DECIMAL(6,3), 
                    db_buffer_pages * 100.0 / @total_buffer)
                    FROM src
                    WHERE DB_NAME([database_id]) NOT IN (''master'',''model'',''msdb'', ''distribution'', ''ReportServer'',''ReportServerTempDB'')
                    ORDER BY db_buffer_MB DESC;'
                   if ($auth -eq 'W')
                      {$dbmem = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -query $db_memsql}
                   else {$dbmem = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $db_memsql -password $Password}
                   $targetfile="c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_dbmem.csv" 
                   $dbmem|Export-Csv -Path  $targetfile
                  
    }#function db_memory
function RDSInstance {
Param (
[Parameter()][int]$cpuonprem,
[Parameter()][int]$Memoryprem,
[Parameter()][int ]$cpuutlization,
[Parameter()][int]$Memutlization,
[Parameter()][int]$TotalIOPS,
[Parameter()][int]$Throughput,
[parameter()]$options 
 
)
$class=''
$RDSInstance=''
$rdsval=''
$cpuonprem=[math]::ceiling($cpuonprem/4)
if ($Memoryprem -gt '1025')
{$Memoryprem =1025}
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
    {  #$cpuonprem=$cpuonprem+4
       $type='M' }
  elseif  ($cpuutlization -lt '50' -and $Memutlization -lt '50') #scale Down.
    {   if ($class -ne 'xlarge')
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
      # write-host "Instance type:$type"
if ($Memoryprem -ge 1025 )
{ $class='32xlarge'
}
return $class
}
function rds-lookup{
Param(
        [Parameter(Mandatory=$True)]$throughput,
        [Parameter(Mandatory=$True)]$Totaliops
        
    )
#**************************RDS Lookup*************************************
      #select excel file you want to read
# this needs to be enabled for RDS.
$file=import-csv "C:\RDSTools\in\AwsInstancescsv.csv"
#$file = "C:\RDSTools\in\AwsInstances.xlsx"
#$sheetName = "Sheet2"
#create new excel COM object
#try{
#$excel = New-Object -com Excel.Application
#open excel file
#$wb = $excel.workbooks.open($file)
#select excel sheet to read data
#$sheet = $wb.Worksheets.Item($sheetname)
#select total rows
$rowMax = ($file).Count
#create new object with Name, Address, Email properties.
#$myData = New-Object -TypeName psobject
#$myData | Add-Member -MemberType NoteProperty -Name InstanceName -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name Version -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name Edition -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name IOPS -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name Throughput -Value $null
[System.Collections.ArrayList]$RDSArray = @()
$RDSval=''
$objTemp=''
     $RdsArray.add($RDSval) | Out-Null
     $val=$null
for ($i = 2; $i -le $rowMax ; $i++)
{
    #$objTemp = $file | Select-Object * 
     
    #read data from each cell
   $InstanceName = $file[$i]."instance type"
    $version = $file[$i].version
    $edition = $file[$i].edition
    $csviops = [int]$file[$i].iops
    if ($csviops -ge 65000)
    {$csviops=65000}
    if ($totaliops -ge 65000)
    {$totaliops =65000}
        $csvthroughput = [int]$file[$i].throughput
   # $objTemp.version =$objTemp.version.substring(2,2)
   if ($InstanceName -like "*.$classonaws*" -and $edition -eq $SQLVEresult.edition  -and $version -match $SQLVEresult.productversion -and $csviops -ge $totaliops -and $csvthroughput -ge $throughput)
  
{
    
    
            $RDSval = [pscustomobject]@{'InstanceName'=$InstanceName;'Version'=$version;'Edition'=[string]$edition}
            $RDSArray.add($RDSval) | Out-Null
            $val=$null
            # $rdsarray
      
       }
    
         } #for
    #$excel.Quit() #this needs to be enabled for RDS.
        return $rdsarray
           #}#try
#catch
#{ Write-Host 'Excel Sheet has not been detected on this Machine , No RDS instance will be provided in the SqlAssessment output' -ForegroundColor Magenta
#}
}
function Generate-recommendation {
  Param(
        [Parameter(Mandatory=$True)]$dbserver,
        [Parameter(Mandatory=$True)]$DBName,
        [Parameter(Mandatory=$False)]$User,
        [Parameter(Mandatory=$False)]$Savepass,
        [parameter (Mandatory=$False)] $collectiontime
    )
$CpuRecomm="
            declare @cpuutilization int
            declare @one_or_zero int
        with  Cpu_util (one_or_zero) as
                (
                    SELECT  case when sqlsercpUut>=80  then 1 else 0 end FROM [msdb].[dbo].[SQL_CPUCollection] 
                ) 
            select   @cpuutilization=count(*)*100/(select count(*)  from Cpu_util )  , @one_or_zero=one_or_zero from cpu_util where one_or_zero=1
                group by one_or_zero
                order by 2 desc
                set @cpuutilization=isnull(@cpuutilization,0)
                if  @cpuutilization>=80  
                    select 'Need To scale compute  UP'  as cpuRecomme,@cpuutilization  as utilization
                else If @cpuutilization<80  and @cpuutilization >=30 
                    select 'compute Load is acceptable'  as cpuRecomme,@cpuutilization  as utilization
                else   select 'compute can be scaled down ' as cpuRecomme ,@cpuutilization  as utilization
      " # this what we use for scaling up or down.
$cpuTUtilization=" declare @cpuutilization int
                   declare @one_or_zero int
                   select @cpuutilization=sum([sqlsercpUut])/count(*) FROM [msdb].[dbo].[SQL_CPUCollection]
                        if  @cpuutilization>=80 
                                select 'Need To scale compute  UP'  as cpuRecomme,@cpuutilization  as 'Totalutilization'
                        else If @cpuutilization<80  and @cpuutilization >=30 
                                select 'compute Load is acceptable'  as cpuRecomme,@cpuutilization  as 'Totalutilization'
                        else   select 'compute can be scaled down ' as cpuRecomme ,@cpuutilization  as 'Totalutilization'" # this is is just an avg utilization.
$cpu95percentile='declare @95Percentile int 
                    select @95Percentile=count(*)* 0.95 from [msdb].[dbo].[SQL_CPUCollection]
                    ;with cpupercentile as 
                    (SELECT row_number () over (order by sqlsercpuUt asc) as rownum,
                               [SqlSerCpuUT]
                              ,[SystemIdle]
                              ,[OtherProCpuUT]
                              ,[Collectiontime]
                              FROM [msdb].[dbo].[SQL_CPUCollection]
                     ) select [SqlSerCpuUT] as Cpupercentile  from cpupercentile  where rownum =@95Percentile'
$CpuSql ="SELECT cpu_count AS [Logical CPU Count],  hyperthread_ratio AS [Hyperthread Ratio],cpu_count/hyperthread_ratio AS [Physical CPU Count] FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);"
$MemSql="SELECT top 1 [SQLMaxMemTargetMB] as MaxMemory   FROM [msdb].[dbo].[SQL_MemCollection] "
$MemRecomm=" declare @count int
             declare @MemUtilization int
                with Memory_intensive (one_or_zero) as 
                    (
                    select ((case when ([SQLCurrMemUsageMB]*100)/[SQLMaxMemTargetMB]>=80   then 1 else 0 end) 
                             &(case when (([SQLCurrMemUsageMB]/1024)/4)*300< PLE then 0 else 1 end )) FROM [msdb].[dbo].[SQL_MemCollection] 
                    )
                             select @count=count(*) from Memory_intensive where one_or_zero=1 group by one_or_zero
                             select @memutilization=isnull(@count*100/(select count(*) from [msdb].[dbo].[SQL_MemCollection]),0)
                        if  @MemUtilization>=80  
                            select 'Need To scale Memory UP'  as MemRecomme,@MemUtilization  as utilization
                        else If @MemUtilization<80  and @MemUtilization >=50 
                            select 'Memory Load is acceptable'  as MemRecomme,@MemUtilization  as utilization
                        else   select 'Memory can be scaled down ' as MemRecomme ,@MemUtilization  as utilization
"
$ThroughputIOPS="SELECT isnull(sum(Totaliops)/60,0) as totaliops,isnull(((sum(bread+bwritten)/60)/1048576),0) as [Throughput]
              FROM [msdb].[dbo].[SQL_DBIO]"
#PLE should be 300 for every 4 GB of RAM on your server. That means for 64 GB of memory you should be looking at closer to 4,800 as what you should view as a critical point.
   #---------------------Pull Sql server Version and edition---------------------------------
   $sqlVE='SELECT   case  WHEN CONVERT(VARCHAR(128),SERVERPROPERTY(''Edition'')) like ''Standard%'' Then ''SE''
            WHEN CONVERT(VARCHAR(128),SERVERPROPERTY(''Edition'')) like ''Enterprise%'' Then ''EE''
    end  Edition,
        CASE 
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''11%'' THEN ''11''
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''12%'' THEN ''12''
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''13%'' THEN ''13''     
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''14%'' THEN ''14'' 
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''15%'' THEN ''15'' 
               Else ''12''
        end AS ProductVersion'
if ($auth -eq 'W')
       {
      $ThroughputIOPS = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $throughputIOPS 
      $CPURecoResult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $CpuRecomm 
      $cpuperentile=invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $cpu95percentile
      $cpuresult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $CpuSql 
      $Memresult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $Memsql 
      $MemRecoResult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $MemRecomm 
      $SQLVEresult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $sqlVE 
      $cpuTUtilization=invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $CpuTutilization 
       }
else 
{
      $ThroughputIOPS= invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $throughputIOPS -password $Savepass
      $CPURecoResult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $CpuRecomm -password $Savepass
      $cpuresult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $CpuSql -password $Savepass
      $cpuperentile=invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $cpu95percentile -password $Savepass
      $Memresult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $Memsql -password $Savepass
      $MemRecoResult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $MemRecomm -password $Savepass
      $SQLVEresult=invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $sqlVE -password $Savepass
      $cpuTUtilization=invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $CpuTutilization -password $Savepass
}
     $cpuonPrem=[int]$cpuresult.'Logical CPU Count'
      $RamonPrem=[int]$Memresult.Maxmemory/1024
      $RamonPrem=([Math]::Round($RamonPrem, 0))
      $Memutlization=$MemRecoResult.utilization
      $cpuutlization=$CPURecoResult.utilization
      $Cpupercentile=$cpuperentile.Cpupercentile
      $cpuTUtilization=$cpuTUtilization.totalutilization
      $totaliops=[int]$ThroughputIOPS.totaliops
      $throughput=[int]$ThroughputIOPS.Throughput
      if ( $options -contains '95')
        { $classonaws=RDSInstance  $cpuonPrem $RamonPrem $Cpupercentile $Memutlization 
        }
      else
        {$classonaws=RDSInstance  $cpuonPrem $RamonPrem $cpuutlization $Memutlization 
        }
$classonprem=RDSInstance  $cpuonPrem $RamonPrem 50 50 
$rdsArray=rds-lookup $throughput $totaliops
if ($rdscustom -contains $server) # this is needed for the IOPS Scalling 
{$rdsinstance=$RDSArray.instancename| Select-Object -Unique|where {$_ -like "db.m5.*" -or $_ -like "db.r5.*"}}
else 
{$rdsinstance=$RDSArray.instancename}
if (-Not $rdsinstance)
{
       $classonaws=switch ($classonaws)
                {'2Xlarge' {'4xlarge'}
                '4Xlarge' {'8xlarge'}
                '8Xlarge' {'12xlarge'}
                '12Xlarge' {'16xlarge'}
                '16Xlarge' {'24xlarge'}
                '24Xlarge' {'32xlarge'}
                '32Xlarge' {'32xlarge'}
          }
          $rdsArray=Rds-lookup $throughput $totaliops
          $Scaledupiops='Y'
       }
  
if ($Memutlization -gt 80)
{
if ($rdscustom -contains $server)
   {$rdsinstance= $RDSArray.instancename| Select-Object -Unique|where {$_ -like "db.r5.*"} 
     }#if
  else {             
  $rdsinstance= $RDSArray.instancename| Select-Object -Unique|where {$_ -notlike "db.m*" -and $_ -notlike "db.r3*" -and $_  -notlike "db.r4*" -and $_ -notlike "db.t3*"}
    }#else
    }# if $mem >80
elseif ($Memutlization -le 80)
{
  if ($rdscustom -contains $server)
     {$rdsinstance=$RDSArray.instancename| Select-Object -Unique|where {$_ -like "db.m5.*" }  #-and $_ -notlike "db.r3*" -and $_  -notlike "db.r4*" -and $_ -notlike "db.t3*"} 
     }#if
  else
    {$rdsinstance=$RDSArray.instancename| Select-Object -Unique|where {$_ -like "db.m*"  }  #-and $_ -notlike "db.r3*" -and $_  -notlike "db.r4*" -and $_ -notlike "db.t3*"} 
    }
}#else
if (-not $rdsinstance -and $rdscustom )
{$rdsinstance='db.m5.'+$classonaws}
elseif  (-not $rdsinstance  )
{$rdsinstance=$RDSArray.instancename}
$RDSInstance=($RDSInstance -join ",")
    #$excel.Quit() #this needs to be enabled for RDS.
if ($Scaledupiops -eq 'Y')
{$totaliops=[string]$ThroughputIOPS.totaliops+'(Scalled up)'}
if ($options -contains '95')
{$val = [pscustomobject]@{'Server Name'=$dbserver;'Logical CPU Count'=$cpuonPrem;'MaxMemorySettings GB'=$RamonPrem;'Collection Time'=$collectiontime ;
'CPU Recommendation'=$CPURecoResult.CpuRecomme;'CPU Pressure Utilization(%)'=$CPURecoResult.utilization;'CPu95Percentile'=$Cpupercentile; 'Total CPU Utilization(%)'=$cpuTUtilization;'Mem Recommendation'=$MemRecoResult.MemRecomme;
'Server Memory Utlization%'=$MemRecoResult.utilization;'Totaliops'=$totaliops;'ThroughPut(MB)'=$ThroughputIOPS.throughput;'Bandwith'='coming Soon';'SQl server edition'=$SQLVEresult.edition;'Sql server version'=$SQLVEresult.productversion;
'RDS Recommendation based on current configuration'="m5."+$Classonprem;'RDS Recommendation based on load'=$rdsinstance
}
}
else 
{
$val = [pscustomobject]@{'Server Name'=$dbserver;'Logical CPU Count'=$cpuonPrem;'MaxMemorySettings GB'=$RamonPrem;'Collection Time'=$collectiontime ;
'CPU Recommendation'=$CPURecoResult.CpuRecomme;'CPU Pressure Utilization(%)'=$CPURecoResult.utilization;'CPu95Percentile'=$cpupercentile; 'Total CPU Utilization(%)'=$cpuTUtilization;'Mem Recommendation'=$MemRecoResult.MemRecomme;
'Server Memory Utlization%'=$MemRecoResult.utilization;'Totaliops'=$totaliops;'ThroughPut(MB)'=$ThroughputIOPS.throughput;'Bandwith'='coming Soon';'SQl server edition'=$SQLVEresult.edition;'Sql server version'=$SQLVEresult.productversion;
'RDS Recommendation based on current configuration'="m5."+$Classonprem;'RDS Recommendation based on load'=$rdsinstance;'RDS Recommendation based on 95 percentile'=$class95
}
}
    
     $ArrayWithHeader.add($val)| Out-Null
     $val=$null
    $ArrayWithHeader|export-Csv -LiteralPath "C:\rdstools\out\SQLAssesmentOutput.csv" -NoTypeInformation -Force
    }
function Create-SQLtables {
    Param(
        [Parameter(Mandatory=$True)]$dbserver,
        [Parameter(Mandatory=$True)]$DBName,
        [Parameter(Mandatory=$False)]$User,
        [Parameter(Mandatory=$False)]$Savepass,
        [Parameter(Mandatory=$False)]$samples
    )
           #There is a variable for $samples in the SQL statement below. 
           #write-host "Calling Create-SQLTables for server $dbserver"
           
           $sql = "
           
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIORaw'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIOTotal];
                      END
                 IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIO'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIO];
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CollectionStatus'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CollectionStatus];
                      END
                      If (EXISTS(SELECT * FROM msdb.dbo.sysjobs WHERE (name = N'SQL_IOCollection')))
                      BEGIN
                                 EXEC msdb.dbo.sp_delete_job @job_name=N'SQL_IOCollection'
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_MemCollection'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_MemCollection];
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CPUCollection'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CPUCollection];
                     END
        /*******Memory collection table ****/
            create table SQL_MemCollection
            (
            SQL_ColletionTime  Datetime,
           SQLCurrMemUsageMB  decimal(12,2),
            SQLMaxMemTargetMB int,
            OSTotalMemoryMB    int,
            OSAVAMemoryMB      int,
            PLE               int
            )
        /*****Cpu collection table *****/
        create table SQL_CPUCollection
        (
         SqlSerCpuUT int,
         SystemIdle int,
         OtherProCpuUT int,
         Collectiontime datetime
         )
      
                      /****** Create SQL_CollectionStatus Table ******/
                      CREATE TABLE [dbo].[SQL_CollectionStatus](
                                [JobStatus] [nvarchar](10) NOT NULL,
                                 [SPID] [int] NOT NULL,
                                 [CollectionStartTime] [datetime] NOT NULL,
                                 [CollectionEndTime] [datetime] NULL,
                                 [Max_Sample_ID] [bigint] NOT NULL,
                                 [Current_Sample_ID] [bigint] NOT NULL
                      ) ON [PRIMARY]
                      /****** Insert Data -- INCLUDES VARIABLE FROM PARENT SCRIPT -- ******/
                      Declare @Total_Samples bigint
                      Select @Total_Samples = $Samples
                      INSERT dbo.SQL_CollectionStatus (JobStatus, SPID, CollectionStartTime, Max_Sample_ID, Current_Sample_ID)
                      SELECT 'Running',@@SPID,GETDATE(),@Total_Samples,0;
                      /****** Create SQL_DBIOTotal Table  ******/
                      CREATE TABLE [dbo].[SQL_DBIOTotal](
                                 [Sample_ID] [bigint] NOT NULL,
                                 [Database_ID] [int] NULL,
                                 [DBName] [nvarchar](400) NOT NULL,
                                 [Read] [bigint] NOT NULL,
                                 [Written] [bigint] NOT NULL,
                                 [BRead] [bigint] NOT NULL,
                                 [BWritten] [bigint] NOT NULL,
                                 [Throughput] [bigint] NOT NULL,
                                 [TotalIOPs] [bigint] NOT NULL,
                                 [NetPackets] bigint,
                                 [CollectionTime] [datetime] NOT NULL
                                 ) ON [PRIMARY]
                      /****** Create SQL_DBIO Table  ******/
                      CREATE TABLE [dbo].[SQL_DBIO](
                                 [Sample_ID] [bigint] NOT NULL,
                                 [Database_ID] [bigint] NOT NULL,
                                 [DBName] [nvarchar](400) NOT NULL,
                                -- [MBRead] [real] NOT NULL,
                                 --[MBWritten] [real] NOT NULL,
                                 [Read] [bigint] NOT NULL,
                                 [Written] [bigint] NOT NULL,
                                 [BRead] [bigint] NOT NULL,
                                 [BWritten] [bigint] NOT NULL,
                                 [TotalB] [bigint] NOT NULL,
                                 [TotalIOPs] [bigint] NOT NULL,
                                 [Throuput] [bigint] Not Null,
                                 [Netpackets] bigint ,
                                 [CollectionTime] [datetime] NOT NULL
                                  ) ON [PRIMARY]
                      /****** Create SQL_IOCollection Agent  ******/
                      BEGIN TRANSACTION
                      DECLARE @ReturnCode INT
                      SELECT @ReturnCode = 0
                      /****** Object:  JobCategory [[Uncategorized (Local)]]]                     ******/
                      IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
                      BEGIN
                      EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                      END
                      DECLARE @jobId BINARY(16)
                      EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQL_IOCollection',
                                            @enabled=1,
                                            @notify_level_eventlog=0,
                                            @notify_level_email=0,
                                            @notify_level_netsend=0,
                                           @notify_level_page=0,
                                            @delete_level=0,
                                           @category_name=N'[Uncategorized (Local)]',
                                            @owner_login_name=$sa, @job_id = @jobId OUTPUT
                   IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                      /****** Object:  Step [Check_Status]                                                                  ******/
                      EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_Status',
                                           @step_id=1,
                                            @cmdexec_success_code=0,
                                            @on_success_action=1,
                                         @on_success_step_id=0,
                                           @on_fail_action=2,
                                            @on_fail_step_id=0,
                                            @retry_attempts=0,
                                           @retry_interval=0,
                                           @os_run_priority=0, @subsystem=N'TSQL',
                                            @command=N'SET QUOTED_IDENTIFIER ON
GO 
                     Declare @Current_Sample_ID Bigint
                      If (Select Max_Sample_ID - Current_Sample_ID  from SQL_CollectionStatus) >  0
                                 BEGIN
                                 update dbo.SQL_CollectionStatus
                                 set Current_Sample_ID  = Current_Sample_ID  + 1
                                 Set @Current_Sample_ID = (Select Current_Sample_ID from SQL_CollectionStatus);
                                 INSERT dbo.SQL_DBIOTotal
                                            SELECT
                                           @Current_Sample_ID,
                                            d.Database_ID,
                                          d.name,
                                            SUM(fs.num_of_reads ),
                                            SUM(fs.num_of_writes),
                                            SUM(fs.num_of_bytes_read ),
                                            SUM(fs.num_of_bytes_written),
                                            SUM((fs.num_of_bytes_read)+(fs.num_of_bytes_written)) ,
                                            SUM(fs.num_of_reads + fs.num_of_writes) ,
                                            (select Sum(net_packet_size) as Total_net_packets_used from sys.dm_exec_connections),
                                            GETDATE()
                                 FROM sys.dm_io_virtual_file_stats(default, default) AS fs
                                            INNER JOIN sys.databases d (NOLOCK) ON d.Database_ID = fs.Database_ID
                                 WHERE d.name NOT IN (''master'',''model'',''msdb'', ''distribution'', ''ReportServer'',''ReportServerTempDB'')
                                 and d.state = 0
                                 GROUP BY d.name, d.Database_ID;
                                 Insert into SQL_DBIO
                                 Select @Current_Sample_ID,
                                DR1.Database_ID,
                                 DR1.DBName,
                                 DR2.[Read] - DR1.[Read],
                                 DR2.[Written] - DR1.[Written],
                                 DR2.[BRead] - DR1.[BRead],
                                 DR2.[BWritten] - DR1.[BWritten],
                                 DR2.Throughput - DR1.Throughput,
                                 DR2.TotalIOPs - DR1.TotalIOPs,
                                 ((DR2.TotalIOPs - DR1.TotalIOPs)*64)/1024,
                                 DR2.NetPackets - DR1.NetPackets,
                                 DR2.CollectionTime
                                 from dbo.SQL_DBIOTotal as DR1
                                 Inner Join dbo.SQL_DBIOTotal as DR2 ON DR1.Database_ID = DR2.Database_ID
                                 where DR1.Sample_ID = @Current_Sample_ID -1
                                 and DR2.Sample_ID = @Current_Sample_ID;
                                 END
                      Else
                                 BEGIN
                                 update dbo.SQL_CollectionStatus
                                 set [JobStatus] = ''Finished'',
                                 [CollectionEndTime] = GETDATE()
                                 EXEC msdb.dbo.sp_update_job @job_name=N''SQL_IOCollection'',
                                 @enabled=0
                     END
                            go
                        DECLARE @ts_now bigint = (SELECT ms_ticks FROM sys.dm_os_sys_info WITH (NOLOCK)); 
                            insert into SQL_CPUCollection
                        SELECT TOP(1) SQLProcessUtilization AS [SQL Server Process CPU Utilization], 
                                       SystemIdle AS [System Idle Process], 
                                       100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization], 
                                       DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time] 
                        FROM (SELECT record.value(''(./Record/@id)[1]'', ''int'') AS record_id, 
                                      record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'',''int'') 
                                              AS [SystemIdle], 
                                      record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'', ''int'') 
                                              AS [SQLProcessUtilization], [timestamp] 
                                 FROM (SELECT [timestamp], CONVERT(xml, record) AS [record] 
                                              FROM sys.dm_os_ring_buffers WITH (NOLOCK)
                                              WHERE ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR'' 
                                              AND record LIKE N''%<SystemHealth>%'') AS x) AS y 
                        ORDER BY record_id DESC
                        go
                        insert into SQL_MemCollection
                        select x.*,y.*,z.* from (SELECT       getdate() as collectionTime,(committed_kb/1024) as Commited,(committed_target_kb/1024)  as targetcommited FROM sys.dm_os_sys_info)  as x,
                           (   SELECT        (total_physical_memory_kb/1024) as totalMem,(available_physical_memory_kb/1024) as AvaiMem FROM sys.dm_os_sys_memory) as y,
                           (SELECT sum(cntr_value)/count(*)  as PLE FROM sys.dm_os_performance_counters WHERE counter_name = ''Page Life expectancy''    AND object_name LIKE ''%buffer node%'') as Z',
                                            @database_name=N'msdb',
                                            @flags=0
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'EveryMinute',
                                 @enabled=1,
                                @freq_type=4, 
                                 @freq_interval=1, 
                                 @freq_subday_type=4, 
                                 @freq_subday_interval=1, 
                                 @freq_relative_interval=0, 
                                 @freq_recurrence_factor=0,
                                 @active_start_date=20160426,
                                 @active_end_date=99991231,
                                 @active_start_time=0,
                                @active_end_time=235959
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 COMMIT TRANSACTION
                                 GOTO EndSave
                                 QuitWithRollback:
                      IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
                      EndSave:
                      /********* End ************/
           "
        if ($auth -eq 'W')
          { $SQLCreateStatusTable = Invoke-Sqlcmd -server $dbserver -Database $DBName  -query $sql }
        else 
          { $SQLCreateStatusTable = Invoke-Sqlcmd -server $dbserver -Database $DBName -user $User -query $sql -password $Savepass}
         
 
          #Write-host "All SQL Collection objects created"
} #Create-SQLtables
function Get-SQLStatus {
    Param(
        [Parameter(Mandatory=$True)]$dbserver,
       [Parameter(Mandatory=$True)]$DBName,
        [Parameter(Mandatory=$False)]$User,
        [Parameter(Mandatory=$False)]$password
    )
           write-host "Checking collection status  for Server $dbServer"
           $sql = "
                      if (exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'SQL_CollectionStatus' ) )
                                 begin
                                            select JobStatus,SPID,CollectionStartTime,CollectionEndTime,Max_Sample_ID,Current_Sample_ID,Max_Sample_ID-Current_Sample_ID as TimeRemaining  from SQL_CollectionStatus
                                 end
                                 else
                                            select 'New' as JobStatus, 0 as Current_Sample_ID, 0 as Max_Sample_ID
           "
  if ($auth -eq 'W')
  {$SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -query $sql }
  else 
  {$SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password}
if ($SQLStatus.JobStatus -match "New") { $action = "S" }
if ($SQLStatus.JobStatus -match "Running") { $action = "R" }
if ($SQLStatus.JobStatus -match "Finished") { $action = "F" }
return $action, [int]$SQLStatus.TimeRemaining 
}#Function status
function Cleanup-SQLObjects {
    Param(
        [Parameter(Mandatory=$True)]$dbserver,
                      [Parameter(Mandatory=$True)]$DBName,
       [Parameter(Mandatory=$False)]$User,
                      [Parameter(Mandatory=$False)]$Savepass
    )
           $sql = "
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIOTotal'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIOTotal];
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIO'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIO];
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CollectionStatus'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CollectionStatus];
                      END
                        IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CPUCollection'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CPUCollection];
                      END
                       IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_MemCollection'))
                     BEGIN
                                 DROP TABLE [dbo].[SQL_MemCollection];
                      END
                      If (EXISTS(SELECT * FROM msdb.dbo.sysjobs WHERE (name = N'SQL_IOCollection')))
                      BEGIN
                                 EXEC msdb.dbo.sp_delete_job @job_name=N'SQL_IOCollection'
                      END
        "
       if ($auth -eq 'W')
              { $SQLCleanup = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $sql }
       else
              { $SQLCleanup = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password}
       
 
           Write-host "Cleanup Completed"
}# Function cleanup
function Get-SQLTargetData {
    Param(
        [Parameter(Mandatory=$True)]$dbserver,
        [Parameter(Mandatory=$True)]$DBName,
        [Parameter(Mandatory=$False)]$User,
        [Parameter(Mandatory=$False)]$Savepass
    )
           #write-host "Calling Get-SQLTargetData"
          $sql = "SELECT  [Sample_ID]
                          ,[DBName]
                          ,[Read]
                          ,[Written]
                          ,[BRead]
                          ,[BWritten]
                          ,[TotalIOPs]
                          ,[Throuput]
                          ,[Netpackets]
                          ,convert(varchar, CollectionTime, 121) as CollectionTime
                      FROM [msdb].[dbo].[SQL_DBIO];
           "
       $cpusql ="SELECT cpu_count AS [Logical CPU Count],
       hyperthread_ratio AS [Hyperthread Ratio],
    cpu_count/hyperthread_ratio AS [Physical CPU Count]
       FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);
       "
       $memcollectionsql="SELECT * FROM [msdb].[dbo].[SQL_MemCollection]"
       $cpucollectionsql="SELECT *  FROM [msdb].[dbo].[SQL_CPUCollection]"
        $ation=''
  if ($auth -eq 'W')
       {
  
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $memcollectionsql 
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_memcollection.csv"
           $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
           #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $cpucollectionsql 
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_cpucollection.csv"
           $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
           #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $cpusql
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_cpuinfo.csv"
           $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
           #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $sql
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_SQL_DBIO.csv"
           $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
          #Write-host "SQLTargetdata written to $($TargetOutFile)"
          }
else 
{
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $memcollectionsql -password $password
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_memcollection.csv"
           $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
           #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $cpucollectionsql -password $password
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_cpucollection.csv"
           $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
           #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $cpusql -password $password
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_cpuinfo.csv"
           $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
           #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password
           $TargetOutFile = "c:\rdstools\out\"+($dbserver.replace('\','~').Toupper())+"_"+$dbtypeExt+"_"+$timestamp+"_SQL_DBIO.csv"
          $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"', ''} | out-file $TargetOutFile
          #Write-host "SQLTargetdata written to $($TargetOutFile)"
}
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
function Generate-ManualRecommendation{
$cpuonPrem=[int]$dataupload.E
$RamonPrem=[int]$dataupload.F/1024
$RamonPrem=([Math]::Round($RamonPrem, 0))
$Memutlization=$dataupload.H
$cpuutlization=$dataupload.C
$Cpupercentile=$dataupload.D
#$cpuTUtilization=$cpuTUtilization.totalutilization
$totaliops=[int]$dataupload.J
$throughput=[int]$dataupload.I
if ($options -contains '95')
  {$classonaws=RDSInstance  $cpuonPrem $RamonPrem $Cpupercentile $Memutlization } 
else
{$classonaws=RDSInstance  $cpuonPrem $RamonPrem $cpuutlization $Memutlization }
 
$classonprem=RDSInstance  $cpuonPrem $RamonPrem 50 50 
#**************************RDS Lookup*************************************
      #select excel file you want to read
# this needs to be enabled for RDS.
$file=import-csv "C:\RDSTools\in\AwsInstancescsv.csv"
#$file = "C:\RDSTools\in\AwsInstances.xlsx"
#$sheetName = "Sheet2"
#create new excel COM object
#try{
#$excel = New-Object -com Excel.Application
#open excel file
#$wb = $excel.workbooks.open($file)
#select excel sheet to read data
#$sheet = $wb.Worksheets.Item($sheetname)
#select total rows
$rowMax = ($file).Count
#create new object with Name, Address, Email properties.
#$myData = New-Object -TypeName psobject
#$myData | Add-Member -MemberType NoteProperty -Name InstanceName -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name Version -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name Edition -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name IOPS -Value $null
#$myData | Add-Member -MemberType NoteProperty -Name Throughput -Value $null
[System.Collections.ArrayList]$RDSArray = @()
$RDSval=''
$objTemp=''
     $RdsArray.add($RDSval) | Out-Null
     $val=$null
for ($i = 2; $i -le $rowMax ; $i++)
{
    #$objTemp = $file | Select-Object * 
     
    #read data from each cell
   $InstanceName = $file[$i]."instance type"
    $version = $file[$i].version
    $edition = $file[$i].edition
    $csviops = [int]$file[$i].iops
    if ($csviops -ge 65000)
    {$csviops=65000}
    if ($totaliops -ge 65000)
    {$totaliops =65000}
        $csvthroughput = [int]$file[$i].throughput
   # $objTemp.version =$objTemp.version.substring(2,2)
  if ($InstanceName -like "*.$classonaws*" -and $edition -eq $dataupload.K  -and $version -match $dataupload.L -and $csviops -ge $totaliops -and $csvthroughput -ge $throughput)
    {
    
    
    
            $RDSval = [pscustomobject]@{'InstanceName'=$InstanceName;'Version'=$version;'Edition'=[string]$edition}
            $RDSArray.add($RDSval) | Out-Null
            $val=$null
      
       }
     
         } #for 
 
 
if ($Memutlization -gt 80)
{
           
  $rdsinstance= $RDSArray.instancename| Select-Object -Unique|where {$_ -notlike "db.m*" -and $_ -notlike "db.r3*" -and $_  -notlike "db.r4*" -and $_ -notlike "db.t3*"}
     }# if $mem >80
elseif ($Memutlization -le 80)
{
$rdsinstance=$RDSArray.instancename| Select-Object -Unique|where {$_ -like "db.m*" }  #-and $_ -notlike "db.r3*" -and $_  -notlike "db.r4*" -and $_ -notlike "db.t3*"} 
}
$RDSInstance=($RDSInstance -join ",")
    
if ($options -contains'95')
{$val = [pscustomobject]@{'Server Name'=$dataupload.A;'Logical CPU Count'=$cpuonPrem;'MaxMemorySettings GB'=$RamonPrem;'Collection Time'=$dataupload.M ;
'CPU Recommendation'=$dataupload.B;'CPU Pressure Utilization(%)'=$dataupload.C;'CPu95Percentile'=$cpupercentile; 'Total CPU Utilization(%)'=$cpuTUtilization;'Mem Recommendation'=$dataupload.G;
'Server Memory Utlization%'=$dataupload.H;'Totaliops'=$Totaliops;'ThroughPut(MB)'=$throughput;'Bandwith'='coming Soon';'SQl server Edition'=$dataupload.K;'Sql server Version'=$dataupload.L;
'RDS Recommendation based on current configuration'="m5."+$Classonprem;'RDS Recommendation based on load'=$rdsinstance
}
}
else 
{
$val = [pscustomobject]@{'Server Name'=$dataupload.A;'Logical CPU Count'=$cpuonPrem;'MaxMemorySettings GB'=$RamonPrem;'Collection Time'=$dataupload.M ;
'CPU Recommendation'=$dataupload.B;'CPU Pressure Utilization(%)'=$dataupload.C;'CPu95Percentile'=$cpupercentile; 'Total CPU Utilization(%)'=$cpuTUtilization;'Mem Recommendation'=$dataupload.G;
'Server Memory Utlization%'=$dataupload.H;'Totaliops'=$totaliops;'ThroughPut(MB)'=$throughput;'Bandwith'='coming Soon';'SQl server Edition'=$dataupload.K;'Sql server Version'=$dataupload.L;
'RDS Recommendation based on current configuration'="m5."+$Classonprem;'RDS Recommendation based on load'=$rdsinstance;'RDS Recommendation based on 95 percentile'=$class95
}
}
     $ArrayWithHeader.add($val)| Out-Null
     $val=$null
    $ArrayWithHeader|export-Csv -LiteralPath "C:\rdstools\out\SQLAssesmentOutput.csv" -NoTypeInformation -Force
    }
$rdscustom='' 
$timestamp=Get-Date -Format "MMddyyyyHHmm "
$FileExists=Test-Path -Path $SqlserverEndpoint
$copywrite =[char]0x00A9 
Write-Host ' SQLAssessmentTool Ver 2.00' $copywrite 'BobTheRdsMan' -ForegroundColor Magenta
# set variable to be used in Targetdata function
[System.Collections.ArrayList]$ArrayWithHeader = @() # initialize the array that will store the final recommendation.
if ($options -eq 'upload')
        {
            if (Test-Path C:\RDSTools\upload\*)
                    {
                     $uploadfile=Get-ChildItem C:\RDSTools\upload\* -Filter *.csv
                     $uploadfile=$uploadfile.Name
                     foreach ($infile in $uploadFile)
                     {
                     $dataupload=  import-csv C:\RDSTools\upload\$infile  -Header A,B,C,D,E,F,G,H,I,J,K,L,M
                          Generate-ManualRecommendation     
 
 
                                  
                      }#foreach
                       TCO
                       Executive_summary $ArrayWithHeader
                       exit
                    }  #if test-path
                else {
                  write-host " No input file in upload dir"
            }
         }#options -eq 'upload'
if (-Not $FileExists)
  {
   Write-host " Input file Doesn't exists"
  exit
  } 
  if ($sqlserverendpoint -eq 'C:\RDSTools\out\RdsDiscovery.csv')
  {   $rdscustom=@()
      $servers=@()
      $servers
      $data=import-csv C:\RDSTools\out\RdsDiscovery.csv  
      $data|foreach {
   if ($_.'RDS compatible'  -eq 'Y')
       {$servers=$servers+$_.'server name'}
   elseif ($_.'RDS compatible'  -eq 'N' -and  $_.'RDS custom compatible' -eq 'Y') 
      {
       $rdscustom= $rdscustom+$_.'server name' 
       $servers=$servers+$_.'server name'
       }
  }#foreach
  }#if 
  
else {$servers=Get-Content $SqlserverEndpoint}
foreach ($server in $servers)
  {  $status=''
     $ation=''
    if ($auth -eq 'W')
       {
            $Conn="Data Source=$server;database=master;Integrated Security=True;" 
        }
    else {
            $Conn="Data Source=$server;User ID=$login;Password=$password;" 
         }
     if (Test-SqlConnection $Conn)
    {   if ($auth -eq 'W')
          {$status=Get-SQLStatus -dbserver $server -DBName msdb }
        else {$Status=Get-SQLStatus -dbserver $server -DBName msdb -user $login -password $password}
if ($Status[0] -eq "S" -and $options -ne 'C') 
    {write-host "Action: Start Collection for server $Server"
       if ($auth -eq 'W' )
          {create-SQLtables -dbserver $server -DBName msdb -samples $collectiontime}
        else {create-SQLtables -dbserver $server -DBName msdb -user $login -savepass $password -samples $collectiontime}
        #write-host "The SQL collection process has started and will run for $collectiontime minutes. (Note: 1440 mins = 24 hours) Run this script again with -dbtype [t]arget to get the latest status, or to download the data when complete. Check the documentation to cancel, cleanup or run a collection with different parameters."
                      }
if ($status[0] -eq "F" -or $options -eq 'T') 
     {
        if ($options -eq 'T')
           {Terminate_job -dbserver $server -DBName msdb -user $login -password $password}
       write-host "Collection completed, getting data for Server $server"
         if ($auth -eq 'W' )
           {  Get-SQLTargetData -dbserver $server -DBName msdb 
              Generate-recommendation -dbserver $server -DBName msdb  -collectiontime $collectiontime
                 if ($options -contains 'dbmem') {$mem=DB_memory -dbserver $server -DBName master }
                       }
         else {Get-SQLTargetData -dbserver $server -DBName msdb -user $login -savepass $password
               Generate-recommendation -dbserver $server -DBName msdb -user $login -savepass $password -collectiontime $collectiontime
                if ($options -contains 'dbmem') {$mem=DB_memory -dbserver $server -DBName master -user $login -password $password}
                }
        if ( $options -eq 'C')
                       { Write-host "Cleanup"
                          if ($auth -eq 'W' )
                            {Cleanup-SQLObjects -dbserver $server -DBName msdb }
                          else {Cleanup-SQLObjects -dbserver $server -DBName msdb -user $login -savepass $password}
                         
                        }
                     }
if ($status[0] -eq "R")
  {$minutesremaining=$status[1]
   write-host "Collection Still running $minutesremaining minutes remaining."
  }
      
  }
      else 
    {    #write-host $server
          write-host "***** Can't connect to $server"
          }#else
  }#foreach
   if ($status[0] -eq 'F')
     { Executive_summary $ArrayWithHeader
        TCO}
      

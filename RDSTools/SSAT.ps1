 
Param (
  [Parameter()][string]$auth,
  [Parameter()][string]$login,
  [Parameter()][string]$password,
  [Parameter()]$collectiontime = 60,
  [Parameter()]$sqlserverendpoint = 'C:\RDSTools\out\RdsDiscovery.csv',
  [Parameter()]$sa = 'sa',
  [Parameter()]$DBName = 'sample',
  [parameter()][array]$options,
  [parameter()][String] $Elasticache='N'
)
Function ElasticacheAssessment
{
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Password
  )
  
$ReadOverall='  SELECT 
      case when (sum(convert(bigint,[read]))*100)/(sum(convert(bigint,[read]))+sum(convert(bigint,[written]))) > 90 
      then ''Server qualify for Elasticache'' else ''Not Elasticache compatible,but check the detailed report for db level Metrics''
        end as Elasticache
      FROM [dbo].[SQL_DBIO]
      where [read]>0 and dbname <>''tempdb''
        '

$readPerDB='SELECT 
     sum(convert(int,[read])) as [read] 
      ,sum(convert(int,[Written])) as write
	  ,(sum(convert(int,[read]))+sum(convert(int,[written]))) as total
	  ,(sum(convert(bigint,[read]))*100)/(sum(convert(bigint,[read]))+sum(convert(bigint,[written]))) AS ''PercentageofRead''
	  ,dbname
      
  FROM [dbo].[SQL_DBIO]
  where [read]>0 and dbname <>''tempdb''
  group by dbname '
  if ($auth -eq 's')
      {$ElasticAssessoutput= invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $ReadOverall -password $password
       $Elasticreport= invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $readPerDB -password $password
      
      }
  else {$ElasticAssessoutput= invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $ReadOverall 
        $Elasticreport= invoke-sqlcmd -serverInstance $dbserver -Database $dbname -query $readPerDB 
   }

  $targetfile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_Elasticache.csv"
   #$Elasticreport | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $targetfile
   $Elasticreport|Export-Csv -Path  $targetfile  


  return $ElasticAssessoutput
}

Function TCO {
  try {
    #cmd.exe /c "copy c:\rdstools\out\TCO_Calculator_Business_Case_Tool.xlsx  c:\rdstools\out\TCO_Calculator_Business_Case_Tool+$timestamp.xlsx"
    $row = 1
    $i = 1
    $servercount = (Get-Content $sqlserverendpoint).Length
    $FilePath = "c:\rdstools\out\TCO_Calculator_Business_Case_Tool.xlsx"
    $FileExists = Test-Path -Path $Filepath
    if ( -not $FileExists) { exit }
    $objExcel = New-Object -ComObject Excel.Application
    $WorkBook = $objExcel.Workbooks.Open("$FilePath")
    $ExcelWorkSheet = $workbook.Sheets.Item("Discovery-Input")
    $tcocsv = import-csv C:\RDSTools\out\SQLAssesmentOutput.csv
    Foreach ($server in $tcocsv) {
      $servercpu = $server.'CPU Pressure Utilization(%)'
      $serverRDSInstance = $server.'RDS Recommendation based on load'
      $serverRDSInstance = $serverRDSInstance
      $instance = $serverRDSInstance.split(",")
      $serverRDSInstance = $instance[0]
      $serverRDSInstance = $serverRDSInstance.TrimEnd()
      $row = 2
      for ($i = 1; $i -le $servercount; $i++) {
        $servername = $ExcelWorkSheet.Cells.Item($row, 1).text
        if ($servername -eq $server.'Server Name') {
          $ExcelWorkSheet.Cells.Item($row, 12) = $servercpu
          $ExcelWorkSheet.Cells.Item($row, 14) = $serverRDSInstance
        }
        $row++
      }
    }
    $workbook.Close($true)
  }#try
  catch {
    Write-Host 'Excel Sheet has not been detected on this Machine ,TCO will not be updated' -ForegroundColor Magenta
  }
}#foreach
Function Executive_summary {
  param(
    [Parameter(Mandatory = $True)]$report
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
  $reportheader = $report | select-object @{Name = "ServerName"; Expression = { $_.'server name' } }, @{Name = " VCPU "; Expression = { $_.'Logical CPU Count' } }, @{Name = " Memory(GB) "; Expression = { $_.'MaxMemorySettings GB' } },
  @{Name = "  CPU Utilization "; Expression = { $_.'CPU Pressure Utilization(%)' } }, @{Name = " CPU 95 Percentile "; Expression = { $_.'CPu95Percentile' } }, @{Name = " Memory Utlization "; Expression = { $_.'Server Memory Utlization%' } },
  @{Name = " MAX_Totaliops "; Expression = { $_.'MAX_Totaliops(AWS Optimized)' } }, @{Name = "Throughput"; Expression = { $_.'MAX_ThroughPut(MB)' } }, @{Name = " SQl server edition "; Expression = { $_.'SQl server edition' } }, @{Name = " SQl server Version "; Expression = { $_.'Sql server version' } },
  @{Name = " RDS Instance "; Expression = { $_.'RDS Recommendation based on load' } }
  $reportheader | convertto-html  -Title "report" -PreContent "<H1>SQLAssessment Report</H1>" -PostContent "<H5><i>$(get-date) </></h5>" -Head $head | ForEach-Object { $PSItem -replace "<td>100</td>", "<td style='background-color:#FF8080'>100</td>" } | out-file C:\RDSTools\out\SqlAssessmentReport.html
  Invoke-Item C:\RDSTools\out\SqlAssessmentReport.html
  #-CssUri C:\RDSTools\in\style.css
  #<H5>this report was produced by <a href="https://rdstools.d1m9acb3dnc55n.amplifyapp.com/ " RDStools </a></H5>
}
Function Terminate_Job {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$password
  )
  write-host "Terminate Collection Job for Server $dbServer"
  $sql = "update $DBName.dbo.SQL_CollectionStatus set jobstatus='Finished'  ,Current_Sample_ID=Max_Sample_ID"
  if ( $auth -eq 'W')
  { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -query $sql }
  else { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password }
}#terminate Job
function DB_level {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Password
  )
  
$DBLEVELsql='dECLARE @total_buffer INT;
                    SELECT @total_buffer = cntr_value
                    FROM sys.dm_os_performance_counters
                    WHERE RTRIM([object_name]) LIKE ''%Buffer Manager''
                    AND counter_name = ''Database Pages'';
                    ;with DBSize (DBNAME,database_id,Size)
                    as
                    (
                    sELECT db_name(database_id),database_id,sum(size*8)/1024/1024.0
                    FROM master.sys.master_files where database_id>4
                    group by database_id
                    ),
                    src AS
                    (
                      SELECT
                      database_id, db_buffer_pages = COUNT_BIG(*)
                      FROM sys.dm_os_buffer_descriptors
                      --WHERE database_id BETWEEN 5 AND 32766
                      GROUP BY database_id
                    ),
                     latency as
                    (
                    SELECT  DB_NAME(vfs.database_id) as dbname,
      UM( CAST((io_stall_read_ms + io_stall_write_ms)/(1.0 + num_of_reads + num_of_writes) AS NUMERIC(10,1)) )AS [Average Total Latency]
                    FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
                    where database_id>4 and database_id<32760
                    group by DB_NAME(vfs.database_id)
                    ),
                    IOPs as
                    (
                    SELECT --top (select  count(distinct database_id) from [$DBName].[dbo].[SQL_DBIO])
                    database_id,sample_id,isnull(sum(Totaliops)/60,0) as Max_IOPS,
                    isnull(((sum(bread+bwritten)/60)/1048576),0) as Max_Throughput
                           FROM [$DBName].[dbo].[SQL_DBIO]
						    where Totaliops>0
            roup by database_id,sample_id
                        --    order by Max_IOPS desc
                    )
					
                    SELECT d.database_id,
                    [db_name] = CASE s.[database_id] WHEN 32767
                    THEN ''Resource DB''
                    ELSE DB_NAME(s.[database_id]) END,
                    db_buffer_pages,
                    db_buffer_MB = db_buffer_pages / 128,
                    db_buffer_percent = CONVERT(DECIMAL(6,3),
                    db_buffer_pages * 100.0 / @total_buffer),
                    d.Size,
                    isnull(i.Max_IOPS,0) as TotalIops,
                    isnull(i.Max_Throughput,0)as Throughput,
                    l.[Average Total Latency]
                    FROM src s left join dbsize d on S.database_id=d.database_id left join latency L  on d.database_id=db_id(l.dbname)
                    left join iops i on db_id(l.dbname)=i.Database_ID
					where d.database_id is not null
                    ORDER BY db_buffer_MB DESC;'   
                                         
  if ($auth -eq 'W')
  { $DBLEVEL = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -query $dblevelsql }
  else { $dblevel = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $dblevelsql -password $Password }
  $targetfile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_dbmem.csv"
 # $dblevel | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $targetfile
  $DBLEVEL |Export-Csv -Path  $targetfile    
      
      #$TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpuinfo.csv"
    #$SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile



  
}#function db_memory
function RDSInstance {
  Param (
    [Parameter()][int]$cpuonprem,
    [Parameter()][int]$Memoryprem,
    [Parameter()][int ]$cpuutlization,
    [Parameter()][int]$Memutlization,
    [Parameter()][int]$Throughput,
    [Parameter()][int]$TotalIOPS,
    [parameter()]$options
  )
   #for Debugging
  #$Memoryprem=1350
  #$cpuonprem=48
  #$cpuutlization=8
  #$Memutlization=100
  #$rdscustom='Y'
  #$throughput=371
  #[int]$Totaliops=33424


  $classonaws = ''
  $class = ''
  if ($options -eq 'upload') {
    $Edition = $Edition
    $version = $version
  }
  else {
    $Edition = $SQLVEresult.edition
    $version = $SQLVEresult.productversion
  }
  $remark = ' '
  $vcpu = $cpuonprem
  if ($Cpuonprem -lt 2 ) { $cpuonprem = 4 }
  $Ratio = $Memoryprem / $cpuonprem
  $cpuonprem = [math]::ceiling($cpuonprem / 4)
  if ($ratio -le 4) {
    $Ratio = 4
    $type = 'G'
  }
  elseif ($ratio -gt 4 -and $ratio -le 8) {
    $ratio = 8
    $type = 'M'
  }
  elseif ($ratio -gt 8 -and $ratio -le 15) {
    $ratio = 15
    $type = 'M'
  }
  elseif ($ratio -gt 15) {
    $ratio = 30
    $type = 'M'
  }
  if ( $ratio -eq 15 -and $vcpu -lt 64)
  { $ratio = 30 }
  if ($ratio -lt 15 ) {
    #new
    if ($cpuonprem -ge 25)
    { $class = '32xlarge' }
    if ($cpuonprem -le 24 -and $cpuonprem -gt 16)
    { $class = '24xlarge' }
    if ($cpuonprem -le 16 -and $cpuonprem -gt 12)
    { $class = '16xlarge' }
    if ($cpuonprem -le 12 -and $cpuonprem -gt 8)
    { $class = '12xlarge' }
    if ($cpuonprem -le 8 -and $cpuonprem -gt 4)
    { $class = '8xlarge' }
    if ($cpuonprem -le 4 -and $cpuonprem -gt 2)
    { $class = '4xlarge' }
    if ($cpuonprem -le 2 -and $cpuonprem -gt 1)
    { $class = '2xlarge' }
    if ($cpuonprem -le 1 )
    { $class = 'xlarge' }
    if ($cpuonprem -eq 0  )
    { $class = 'large' }
  }
  if ($ratio -gt 15 ) {
    #new
    if ($cpuonprem -ge 25)
    { $class = '32xlarge' }
    if ($cpuonprem -le 24 -and $cpuonprem -gt 16)
    { $class = '24xlarge' }
    if ($cpuonprem -le 16 -and $cpuonprem -gt 12)
    { $class = '16xlarge' }
    if ($cpuonprem -le 12 -and $cpuonprem -gt 8)
    { $class = '12xlarge' }
    if ($cpuonprem -le 8 -and $cpuonprem -gt 4)
    { $class = '8xlarge' }
    if ($cpuonprem -le 4 -and $cpuonprem -gt 2)
    { $class = '4xlarge' }
    if ($cpuonprem -le 2 -and $cpuonprem -gt 1)
    { $class = '2xlarge' }
    if ($cpuonprem -le 1 )
    { $class = 'xlarge' }
    if ($cpuonprem -eq 0  )
    { $class = 'large' }
  }
  if ($ratio -eq 15 ) {
    #new
    if ($cpuonprem -gt 16)
    { $class = '32xlarge' }
    if ($cpuonprem -le 16 )
    { $class = '16xlarge' }
  }
  if ($cpuutlization -ge '80' -and $Memutlization -ge '80') {
    $CLASS = switch ($class) {
      'Xlarge' { '2xlarge' }
      '2Xlarge' { '4xlarge' }
      '4Xlarge' { '8xlarge' }
      '8Xlarge' { '12xlarge' }
      '12Xlarge' { '16xlarge' }
      '16Xlarge' { '24xlarge' }
      '24Xlarge' { '32xlarge' }
      '32Xlarge' { '32xlarge' }
    }
    $type = 'M'
    $Scale = 'U'
    $remark = 'Scaled up due to High Memory and High CPU'
    $ratio = 8   
  }
  elseif ($cpuutlization -ge '80' -and $Memutlization -le '80') {
    $CLASS = switch ($class) {
      'Xlarge' { '2xlarge' }
      '2Xlarge' { '4xlarge' }
      '4Xlarge' { '8xlarge' }
      '8Xlarge' { '12xlarge' }
      '12Xlarge' { '16xlarge' }
      '16Xlarge' { '24xlarge' }
      '24Xlarge' { '32xlarge' }
      '32Xlarge' { '32xlarge' }
    }
    $Scale = 'U'
    $remark = 'Scaled up due to High CPU'
  }
  elseif ($cpuutlization -le '80' -and $Memutlization -ge '80' -and $ratio -Le '8') {
    $type = 'M'
    $scale = 'N'
    $ratio = 8
    $remark = 'Scaled up due to High Memory '
  }
  elseif ($cpuutlization -lt '50' -and $Memutlization -lt '50') {
    #scale Down.  
    if ($class -ne 'Xlarge') 
    {  $CLASS=switch ($class) {
    'Xlarge' { 'xlarge' }
    '2Xlarge' { 'xlarge' }
    '4Xlarge' { '2xlarge' }
    '8Xlarge' { '4xlarge' }
    '12Xlarge' { '8xlarge' }
    '16Xlarge' { '12xlarge' }
    '24Xlarge' { '16xlarge' }
    '32Xlarge' { '24xlarge' }
  }
  $Scale = 'D'
}
$remark = 'Scaled Down '
}
if ($ratio -eq 15) {
  # if scaled down and it is 12 then 8 ,if scaled up and it is 12 then 16
  $remark = ' Memory to CPU ratio is 15 , only db.x1e.16xlarge  and db.x1e.32xlarge  is available.Be aware of the low Througput for those instances '
  if ( $class -match '12xlarge' -and $scale -eq 'N') { $class = '16xlarge' }
  elseif ( $class -match '12xlarge' -and $scale -eq 'D') {
    $class = '8xlarge'
    $ratio = 30
  }
  elseif ( $class -match '16xlarge' -and $scale -eq 'D') {
    $class = '8xlarge'
    $ratio = 30
  }
  elseif ($class -match '24xlarge' -and $sclae -eq 'U') { $class = '32xlarge' }
  elseif ( $class -match '24xlarge' -and $scale -eq 'D') { $class = '16xlarge' }
  $type = 'M'
}
if ($ratio -eq 30 ) {
  # if scaled down and it is 12 then 8
  $remark = ' Memory to CPU ratio is 30 , only x1e is avialable . Be aware of the low Througput for those instances '
  if ( $class -match '12xlarge' -and $scale -eq 'N') { $class = '16xlarge' }
  elseif ( $class -match '12xlarge' -and $scale -eq 'D') { $class = '8xlarge' }
  elseif ($class -match '24xlarge' -and $sclae -eq 'U') { $class = '32xlarge' }
  elseif ( $class -match '24xlarge' -and $scale -eq 'D') { $class = '16xlarge' }
  $type = 'M' 
}
if ($rdscustom -contains $server)
{ $custom = 'Y' }
Else { $custom = 'N' }
$fileoriginal = import-csv "C:\RDSTools\in\AwsInstancescsv.csv"
if ($Custom -eq 'Y') {
  $file = $fileoriginal | where-Object { $_.RDSCustom -like 'Y' -and $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq $edition -and $_.version -match $version }
}
elseif ($Custom -eq 'N' -and $ratio -lt 15) {
  $file = $fileoriginal | where-Object { $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.edition -eq $edition -and $_.version -match $version }
}
elseif ($Custom -eq 'N' -and $ratio -ge 15) {
  $file = $fileoriginal | where-Object { [int]$_.ratio -eq [int]$ratio -and [int]$_.vcpu -ge [int] $VCPU -and [int]$_.memory -ge [int]$Memoryprem -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq $edition -and $_.version -match $version }
}
#if ( $file) {$file=$file[0]}
#$file|select-object -unique
while ( -not $file ) {
  #sclae up
  $CLASS=switch ($class) {
  'Xlarge' { '2xlarge' }
  '2Xlarge' { '4xlarge' }
  '4Xlarge' { '8xlarge' }
  '8Xlarge' { '12xlarge' }
  '12Xlarge' { '16xlarge' }
  '16Xlarge' { '24xlarge' }
  '24Xlarge' { '32xlarge' }
  '32Xlarge' { '32xlarge' }
}
$remark = ' Instance was scalled up due to IOPS requirement'
$scale = 'I'
#$classonaws=$CLASS
if ($Custom -eq 'Y') {
  $file = $fileoriginal | where-Object { $_.RDSCustom -like 'Y' -and $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.edition -eq $edition -and $_.version -match $version }
  #$file=$fileoriginal| where-Object {[int]$_.ratio -eq [int]$ratio -and $_.size -eq $classonaws -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq  $SQLVEresult.edition  -and $_.version -match $SQLVEresult.productversion }
}
else {
  $file = $fileoriginal | where-Object { $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.edition -eq $edition -and $_.version -match $version }
  # $file=$fileoriginal| where-Object {[int]$_.ratio -eq [int]$ratio -and $_.size -eq $classonaws -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq  $SQLVEresult.edition  -and $_.version -match $SQLVEresult.productversion }
}
# $file|select-object -unique
if ($class -match '32xlarge' -and -not $file) {
  $remark = 'No Instance that match your IOPS Requirment'
  if ($Custom -eq 'Y') {
    $file = $fileoriginal | where-Object { $_.RDSCustom -like 'Y' -and $_.size -eq '24xlarge' -and $_.edition -eq $edition -and $_.version -match $version }
  }
  elseif ($Custom -eq 'N') {
    $file = $fileoriginal | where-Object { $_.size -eq $class -and $_.edition -eq $edition -and $_.version -match $Version }
  }
}
}
return $type, $remark, $file
}
function Generate-recommendation {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Savepass,
    [parameter (Mandatory = $False)] $collectiontime
  )
  $classonaws = ''
  $classonprem = ''
  $CpuRecomm = "
            declare @cpuutilization int
            declare @one_or_zero int
        with  Cpu_util (one_or_zero) as
                ( SELECT  case when sqlsercpUut>=80  then 1 else 0 end FROM [$DBName].[dbo].[SQL_CPUCollection]
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
  $cpuTUtilization = " declare @cpuutilization int
                   declare @one_or_zero int
                   select @cpuutilization=sum([sqlsercpUut])/count(*) FROM [$DBName].[dbo].[SQL_CPUCollection]
                        if  @cpuutilization>=80
                                select 'Need To scale compute  UP'  as cpuRecomme,@cpuutilization  as 'Totalutilization'
                        else If @cpuutilization<80  and @cpuutilization >=30
                                select 'compute Load is acceptable'  as cpuRecomme,@cpuutilization  as 'Totalutilization'
                        else   select 'compute can be scaled down ' as cpuRecomme ,@cpuutilization  as 'Totalutilization'" # this is is just an avg utilization.
  $cpu95percentile = 'declare @95Percentile int
                    select @95Percentile=count(*)* 0.95 from [$DBName].[dbo].[SQL_CPUCollection]
                    ;with cpupercentile as
                    (SELECT row_number () over (order by sqlsercpuUt asc) as rownum,
                                [SqlSerCpuUT]
                              ,[SystemIdle]
                              ,[OtherProCpuUT]
                              ,[Collectiontime]
                              FROM [$DBName].[dbo].[SQL_CPUCollection]
                     ) select [SqlSerCpuUT] as Cpupercentile  from cpupercentile  where rownum =@95Percentile'
  $CpuSql = "SELECT cpu_count AS [Logical CPU Count],  hyperthread_ratio AS [Hyperthread Ratio],cpu_count/hyperthread_ratio AS [Physical CPU Count],virtual_machine_type_desc AS VM_type FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);"
    $MemSql = "SELECT  convert(int,value_in_use) as MaxMemory FROM sys.configurations WHERE name like 'max server memory%' "
  $MemRecomm = " declare @count int
             declare @MemUtilization int
                with Memory_intensive (one_or_zero) as
                    (
                    select ((case when ([SQLCurrMemUsageMB]*100)/[SQLMaxMemTargetMB]>=80   then 1 else 0 end)
                             &(case when (([SQLCurrMemUsageMB]/1024)/4)*300< PLE then 0 else 1 end )) FROM [$DBName].[dbo].[SQL_MemCollection]
                    )
                             select @count=count(*) from Memory_intensive where one_or_zero=1 group by one_or_zero
                             select @memutilization=isnull(@count*100/(select count(*) from [$DBName].[dbo].[SQL_MemCollection]),0)
                        if  @MemUtilization>=80
                            select 'Need To scale Memory UP'  as MemRecomme,@MemUtilization  as utilization
                        else If @MemUtilization<80  and @MemUtilization >=50
                            select 'Memory Load is acceptable'  as MemRecomme,@MemUtilization  as utilization
                        else   select 'Memory can be scaled down ' as MemRecomme ,@MemUtilization  as utilization
"
  $ThroughputIOPS = "With AVGIO (Totaliops,Throughput)
	                    as 
	                        ( SELECT  isnull(sum(Totaliops)/60,0) as totaliops,isnull(((sum(bread+bwritten)/60)/1048576),0) as [Throughput]
                                FROM [$DBName].[dbo].[SQL_DBIO]
                                  where Totaliops>0
			                    group by sample_id
					        ) 
			        select  Maxiops.*,Miniops.*,AVGIOP.*
                            from (SELECT top 1 isnull(sum(Totaliops)/60,0)*4 as Max_IOPS,isnull(((sum(bread+bwritten)/60)/1048576),0) as Max_Throughput
                                    FROM [$DBName].[dbo].[SQL_DBIO]
                                      where Totaliops>0
			                        group by sample_id
			                        order by Max_IOPS desc ) as Maxiops,
                                (SELECT top 1 isnull(sum(Totaliops)/60,0)*4 as Min_IOPS,isnull(((sum(bread+bwritten)/60)/1048576),0) as Min_Throughput
                                    FROM [$DBName].[dbo].[SQL_DBIO]
                                      where Totaliops>0
			                        group by sample_id
			                        order by Min_iops asc ) as Miniops,
	                        (
                    SELECT avg(totaliops)*4 as AVG_IOPS,avg(throughput) as AVG_Throughput from  AVGIO) as AVGIOP"


  #PLE should be 300 for every 4 GB of RAM on your server. That means for 64 GB of memory you should be looking at closer to 4,800 as what you should view as a critical point.
  #---------------------Pull Sql server Version and edition---------------------------------
  $sqlVE = 'SELECT   case  WHEN CONVERT(VARCHAR(128),SERVERPROPERTY(''Edition'')) like ''Standard%'' Then ''SE''
                         when CONVERT(VARCHAR(128),SERVERPROPERTY(''Edition'')) like  ''Developer%'' then ''SE''
            WHEN CONVERT(VARCHAR(128),SERVERPROPERTY(''Edition'')) like ''Enterprise%'' Then ''EE''
    end  Edition,
        CASE
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''11%'' THEN ''11''
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''12%'' THEN ''12''
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''13%'' THEN ''13''
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''14%'' THEN ''14''
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''15%'' THEN ''15''
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY (''productversion'')) like ''16%'' THEN ''15''
               Else ''12''
        end AS ProductVersion'
  if ($auth -eq 'W') {
    $ThroughputIOPS = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $throughputIOPS
    $CPURecoResult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $CpuRecomm
    $cpuperentile = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $cpu95percentile
    $cpuresult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $CpuSql
    $Memresult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $Memsql
    $MemRecoResult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $MemRecomm
    $SQLVEresult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $sqlVE
    $cpuTUtilization = invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $CpuTutilization
  }
  else {
    $ThroughputIOPS = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $throughputIOPS -password $Savepass
    $CPURecoResult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $CpuRecomm -password $Savepass
    $cpuresult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $CpuSql -password $Savepass
    $cpuperentile = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $cpu95percentile -password $Savepass
    $Memresult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $Memsql -password $Savepass
    $MemRecoResult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $MemRecomm -password $Savepass
    $SQLVEresult = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $sqlVE -password $Savepass
    $cpuTUtilization = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $CpuTutilization -password $Savepass

  }
  $classtemp = ''
  $cpuonPrem = [int]$cpuresult.'Logical CPU Count'
  $RamonPrem = [int]$Memresult.Maxmemory / 1024
  $RamonPrem = ([Math]::Round($RamonPrem, 0))
  $Memutlization = $MemRecoResult.utilization
  $cpuutlization = $CPURecoResult.utilization
  $Cpupercentile = $cpuperentile.Cpupercentile
  $cpuTUtilization = $cpuTUtilization.totalutilization
  $totaliops = [int]$ThroughputIOPS.MAX_iops
  $throughput = [int]$ThroughputIOPS.MAX_Throughput
  if ( $options -contains '95') {
    $classonaws = RDSInstance  $cpuonPrem $RamonPrem $Cpupercentile $Memutlization $throughput $totaliops
  }
  else {
    $classonaws = RDSInstance  $cpuonPrem $RamonPrem $cpuutlization $Memutlization $throughput $totaliops
  }
  $classtemp = $classonaws[2]
  $type = $classonaws[0]
  $Note = $classonaws[1]
  $classonaws = $classonaws[2]

  if ($type -eq 'M') {
    $classonaws = $Classonaws."Instance Type" | Select-Object -Unique | Where-Object { $_ -like "db.r*" -or $_ -like "db.x*" -or $_ -like "db.z*" }
    if (-not $classonaws)
    { $classonaws = $classtemp."Instance Type" | Select-Object -Unique } 
  }
  if ($type -eq 'G' ) {
    $classonaws = $Classonaws."Instance Type" | Select-Object -Unique | Where-Object { $_  -like "db.m*" -or $_ -like "db.t*"  }
    if (-not $classonaws)
    { $classonaws = $classtemp."Instance Type" | Select-Object -Unique } 
  }
  #$classonaws=$Classonaws."Instance Type"| Select-Object -Unique
  $classonprem = RDSInstance  $cpuonPrem $RamonPrem 50 50
  $classonprem = $Classonprem."Instance Type" | Select-Object -Unique | Where-Object { $_  -like "db.m*" -or $_ -like "db.t*" -or $_ -like "db.r*" -or $_ -like "db.x*" -or $_ -like "db.z*"  }
  $RDSInstance = ($classonaws -join ",")
  if ($Scaledupiops -eq 'Y') {
    $remark = 'Instance Scalled up to match IOPS or throughput'
  }
  IF ($classonprem.COUNT -GT 1)
  {  $classonprem=$classonprem[0]}
  #call Elasticache Function
  if ($elasticache -eq 'Y')
  {   $Elasticoutput = ElasticacheAssessment  $server '$DBName' $user $password
      $val = [pscustomobject]@{'Server Name' = $dbserver; 'Logical CPU Count' = $cpuonPrem; 'MaxMemorySettings GB' = $RamonPrem; 'Collection Time' = $collectiontime ;
      'CPU Recommendation' = $CPURecoResult.CpuRecomme; 'CPU Pressure Utilization(%)' = $CPURecoResult.utilization; 'CPu95Percentile' = $Cpupercentile; 'Total CPU Utilization(%)' = $cpuTUtilization; 'Mem Recommendation' = $MemRecoResult.MemRecomme;
      'Server Memory Utlization%' = $MemRecoResult.utilization;'MAX_Totaliops(AWS Optimized)' = $Totaliops; 'MAX_ThroughPut(MB)' = $throughput;'MIN_Totaliops(AWS Optimized)' = $ThroughputIOPS.MINIOPS; 'MIN_ThroughPut(MB)' = $ThroughputIOPS.MIN_Throughput;'AVG_Totaliops(AWS Optimized)' = $ThroughputIOPS.AVG_IOPS; 'AVG_ThroughPut(MB)' = $ThroughputIOPS.AVG_Throughput; 'SQl server edition' = $SQLVEresult.edition; 'Sql server version' = $SQLVEresult.productversion;
      'Elasticache'=$Elasticoutput.elasticache;
      'RDS Recommendation based on current configuration' = $Classonprem; 'RDS Recommendation based on load' = $rdsinstance; 'Note' = 'Check the detailed Elasticache report for the Read over write per DB in rdstools\out'}
   }

 
   else {
  if ($options -contains '95') {
    $val = [pscustomobject]@{'Server Name' = $dbserver; 'Logical CPU Count' = $cpuonPrem; 'MaxMemorySettings GB' = $RamonPrem; 'Collection Time' = $collectiontime ;
      'CPU Recommendation' = $CPURecoResult.CpuRecomme; 'CPU Pressure Utilization(%)' = $CPURecoResult.utilization; 'CPu95Percentile' = $Cpupercentile; 'Total CPU Utilization(%)' = $cpuTUtilization; 'Mem Recommendation' = $MemRecoResult.MemRecomme;
      'Server Memory Utlization%' = $MemRecoResult.utilization;'MAX_Totaliops(AWS Optimized)' = $Totaliops; 'MAX_ThroughPut(MB)' = $throughput;'MIN_Totaliops(AWS Optimized)' = $ThroughputIOPS.MINIOPS; 'MIN_ThroughPut(MB)' = $ThroughputIOPS.MIN_Throughput;'AVG_Totaliops(AWS Optimized)' = $ThroughputIOPS.AVG_IOPS; 'AVG_ThroughPut(MB)' = $ThroughputIOPS.AVG_Throughput; 'SQl server edition' = $SQLVEresult.edition; 'Sql server version' = $SQLVEresult.productversion;
      'Elasticache'='';
      'RDS Recommendation based on current configuration' = $Classonprem; 'RDS Recommendation based on load' = $rdsinstance; 'Note' = $Note}
  }#if
  else {
    $val = [pscustomobject]@{'Server Name' = $dbserver; 'Logical CPU Count' = $cpuonPrem; 'MaxMemorySettings GB' = $RamonPrem; 'Collection Time' = $collectiontime ;
      'CPU Recommendation' = $CPURecoResult.CpuRecomme; 'CPU Pressure Utilization(%)' = $CPURecoResult.utilization; 'CPu95Percentile' = $cpupercentile; 'Total CPU Utilization(%)' = $cpuTUtilization; 'Mem Recommendation' = $MemRecoResult.MemRecomme;
      'Server Memory Utlization%' = $MemRecoResult.utilization;'MAX_Totaliops(AWS Optimized)' = $Totaliops; 'MAX_ThroughPut(MB)' = $throughput;'MIN_Totaliops(AWS Optimized)' = $ThroughputIOPS.MIN_IOPS; 'MIN_ThroughPut(MB)' = $ThroughputIOPS.MIN_Throughput;'AVG_Totaliops(AWS Optimized)' = $ThroughputIOPS.AVG_IOPS; 'AVG_ThroughPut(MB)' = $ThroughputIOPS.AVG_Throughput; 'SQl server edition' = $SQLVEresult.edition; 'Sql server version' = $SQLVEresult.productversion;
      'RDS Recommendation based on current configuration' = $Classonprem; 'RDS Recommendation based on load' = $rdsinstance; 'RDS Recommendation based on 95 percentile' = $class95; 'Note' = $Note}
  }#else
  }#top else
  $ArrayWithHeader.add($val) | Out-Null
  $val = $null
  $ArrayWithHeader | export-Csv -LiteralPath "C:\rdstools\out\SQLAssesmentOutput.csv" -NoTypeInformation -Force
}
function Create-SQLtables {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Savepass,
    [Parameter(Mandatory = $False)]$samples
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
                                           @job_id = @jobId OUTPUT
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
                                            @database_name=N'$DBName',
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
  { $SQLCreateStatusTable = Invoke-Sqlcmd -server $dbserver -Database $DBName -user $User -query $sql -password $Savepass }
  #Write-host "All SQL Collection objects created"
} #Create-SQLtables
function Get-SQLStatus {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$password
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
  { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -query $sql }
  else
  { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password }
  if ($SQLStatus.JobStatus -match "New") { $action = "S" }
  if ($SQLStatus.JobStatus -match "Running") { $action = "R" }
  if ($SQLStatus.JobStatus -match "Finished") { $action = "F" }
  return $action, [int]$SQLStatus.TimeRemaining
}#Function status
function Cleanup-SQLObjects {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Savepass
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
  { $SQLCleanup = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password }
  Write-host "Cleanup Completed"
}# Function cleanup
function Get-SQLTargetData {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Savepass
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
                      FROM [$DBName].[dbo].[SQL_DBIO];
           "
  $cpusql = "SELECT cpu_count AS [Logical CPU Count],  hyperthread_ratio AS [Hyperthread Ratio],cpu_count/hyperthread_ratio AS [Physical CPU Count],virtual_machine_type_desc AS VM_type FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);"
  $memcollectionsql = "SELECT * FROM [$DBName].[dbo].[SQL_MemCollection]"
  $cpucollectionsql = "SELECT *  FROM [$DBName].[dbo].[SQL_CPUCollection]"
  $ation = ''
  if ($auth -eq 'W') {
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $memcollectionsql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_memcollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $cpucollectionsql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpucollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $cpusql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpuinfo.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $sql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_SQL_DBIO.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
  }
  else {
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $memcollectionsql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_memcollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $cpucollectionsql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpucollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $cpusql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpuinfo.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_SQL_DBIO.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
  }
}
function Test-SQLConnection {
  [OutputType([bool])]
  Param
  (
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      Position = 0)]
    $ConnectionString
  )
  try {
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString;
    $sqlConnection.Open();
    $sqlConnection.Close();
    return $true;
  }
  catch {
    return $false;
  }
}
function Generate-ManualRecommendation {
  $classtemp = ''
  $remark = ''
  $server = $dataupload.A
  $cpuonPrem = [int]$dataupload.E
  $RamonPrem = [int]$dataupload.F / 1024
  $RamonPrem = ([Math]::Round($RamonPrem, 0))
  $Memutlization = $dataupload.H
  $cpuutlization = $dataupload.C
  $Cpupercentile = $dataupload.D
  #$cpuTUtilization=$cpuTUtilization.totalutilization
  $totaliops = [int]$dataupload.J
  $throughput = [int]$dataupload.I
  $edition = $dataupload.K
  $version = $dataupload.L
  if ($options -contains '95')
  { $classonaws = RDSInstance  $cpuonPrem $RamonPrem $Cpupercentile $Memutlization }
  else
  { $classonaws = RDSInstance  $cpuonPrem $RamonPrem $cpuutlization $Memutlization $throughput $totaliops $options }
  #**************************RDS Lookup*************************************
  $classtemp = $classonaws[2]
  $type = $classonaws[0]
  $Note = $classonaws[1]
  $classonaws = $classonaws[2]

  if ($type -eq 'M') {
    $classonaws = $Classonaws."Instance Type" | Select-Object -Unique | Where-Object { $_ -like "db.r*" -or $_ -like "db.x*" -or $_ -like "db.z*" }
    if (-not $classonaws)
    { $classonaws = $classtemp."Instance Type" | Select-Object -Unique } 
  }
  if ($type -eq 'G' ) { 
    $classonaws = $Classonaws."Instance Type" | Select-Object -Unique | Where-Object { $_ -like "db.m*" -or $_ -like "db.t*"}
    if (-not $classonaws)
    { $classonaws = $classtemp."Instance Type" | Select-Object -Unique } 
  }
  #$classonaws=$Classonaws."Instance Type"| Select-Object -Unique
  $classonprem = RDSInstance  $cpuonPrem $RamonPrem 50 50 $throughput $totaliops $options
  $classonprem = $Classonprem."Instance Type" | Select-Object -Unique | Where-Object { $_ -like "db.m5.*" -or $_ -like "db.r*" -or $_ -like "db.x*" -or $_ -like "db.z*" -or $_ -like "db.t*" }
  $RDSInstance = ($classonaws -join ",")
  if ($Scaledupiops -eq 'Y') {
    $remark = 'Instance Scalled up to match IOPS or throughput'
  }
  #$RDSInstance=$classonaws
  if ($options -contains '95') {
    $val = [pscustomobject]@{'Server Name' = $dataupload.A; 'Logical CPU Count' = $cpuonPrem; 'MaxMemorySettings GB' = $RamonPrem; 'Collection Time' = $dataupload.M ;
      'CPU Recommendation' = $dataupload.B; 'CPU Pressure Utilization(%)' = $dataupload.C; 'CPu95Percentile' = $cpupercentile; 'Total CPU Utilization(%)' = $cpuTUtilization; 'Mem Recommendation' = $dataupload.G;
      'Server Memory Utlization%' = $dataupload.H; 'MAX_Totaliops' = $Totaliops; 'MAX_ThroughPut(MB)' = $throughput; 'SQl server Edition' = $dataupload.K; 'Sql server Version' = $dataupload.L;
      'RDS Recommendation based on current configuration' = $Classonprem; 'RDS Recommendation based on load' = $rdsinstance; 'Note' = $note
    }
  }
  else {
    $val = [pscustomobject]@{'Server Name' = $dataupload.A; 'Logical CPU Count' = $cpuonPrem; 'MaxMemorySettings GB' = $RamonPrem; 'Collection Time' = $dataupload.M ;
      'CPU Recommendation' = $dataupload.B; 'CPU Pressure Utilization(%)' = $dataupload.C; 'CPu95Percentile' = $cpupercentile; 'Total CPU Utilization(%)' = $cpuTUtilization; 'Mem Recommendation' = $dataupload.G;
      'Server Memory Utlization%' = $dataupload.H;'MAX_Totaliops' = $Totaliops; 'MAX_ThroughPut(MB)' = $throughput; 'SQl server Edition' = $dataupload.K; 'Sql server Version' = $dataupload.L;
      'RDS Recommendation based on current configuration' = $Classonprem; 'RDS Recommendation based on load' = $rdsinstance; 'RDS Recommendation based on 95 percentile' = $class95; 'Note' = $note
    }
  }
  $ArrayWithHeader.add($val) | Out-Null
  $val = $null
  $ArrayWithHeader | export-Csv -LiteralPath "C:\rdstools\out\SQLAssesmentOutput.csv" -NoTypeInformation -Force
}
$rdscustom = ''
$timestamp = Get-Date -Format "MMddyyyyHHmm "
$FileExists = Test-Path -Path $SqlserverEndpoint
$copywrite = [char]0x00A9
Write-Host ' SQLAssessmentTool Ver 3.00' $copywrite 'BobTheRdsMan' -ForegroundColor Magenta
# set variable to be used in Targetdata function
[System.Collections.ArrayList]$ArrayWithHeader = @() # initialize the array that will store the final recommendation.
if ($options -eq 'upload') {
  if (Test-Path C:\RDSTools\upload\*) {
    $uploadfile = Get-ChildItem C:\RDSTools\upload\* -Filter *.csv
    $uploadfile = $uploadfile.Name
    foreach ($infile in $uploadFile) {
      $dataupload = import-csv C:\RDSTools\upload\$infile  -Header A, B, C, D, E, F, G, H, I, J, K, L, M
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
if (-Not $FileExists) {
  Write-host " Input file Doesn't exists"
  exit
}
if ($sqlserverendpoint -eq 'C:\RDSTools\out\RdsDiscovery.csv') {
  $custom = ''
  $rdscustom = @()
  $servers = @()
  $servers
  $data = import-csv C:\RDSTools\out\RdsDiscovery.csv
  $data | ForEach-Object {
    if ($_.'RDS compatible' -eq 'Y')
    { $servers = $servers + $_.'server name' }
    elseif ($_.'RDS compatible' -eq 'N' -and $_.'RDS custom compatible' -eq 'Y') {
      $rdscustom = $rdscustom + $_.'server name'
      $servers = $servers + $_.'server name'
    }
  }#foreach
}#if
else { $servers = Get-Content $SqlserverEndpoint }
foreach ($server in $servers) {
  if ($auth -eq 'W') {
    $Conn = "Data Source=$server;database=master;Integrated Security=True;"
  }
  else {
    $Conn = "Data Source=$server;User ID=$login;Password=$password;"
  }
  if (Test-SqlConnection $Conn) {
    $status = ''
    $ation = ''
    if ($auth -eq 'W')
    { $status = Get-SQLStatus -dbserver $server -DBName $DBName }
    else { $Status = Get-SQLStatus -dbserver $server -DBName $DBName -user $login -password $password }
    if ($Status[0] -eq "S" -and $options -ne 'C') {
      write-host "Action: Start Collection for server $Server"
      if ($auth -eq 'W' )
      { create-SQLtables -dbserver $server -DBName $DBName -samples $collectiontime }
      else { create-SQLtables -dbserver $server -DBName $DBName -user $login -savepass $password -samples $collectiontime }
      #write-host "The SQL collection process has started and will run for $collectiontime minutes. (Note: 1440 mins = 24 hours) Run this script again with -dbtype [t]arget to get the latest status, or to download the data when complete. Check the documentation to cancel, cleanup or run a collection with different parameters."
    }
    if ($status[0] -eq "F" -or $options -eq 'T') {
      if ($options -eq 'T')
      { Terminate_job -dbserver $server -DBName $DBName -user $login -password $password }
      write-host "Collection completed, getting data for Server $server"
      if ($auth -eq 'W' ) {
        Get-SQLTargetData -dbserver $server -DBName $DBName
        Generate-recommendation -dbserver $server -DBName $DBName  -collectiontime $collectiontime
        if ($options -contains 'dblevel') { $dblevel = DB_level -dbserver $server -DBName master }
      }
      else {
        Get-SQLTargetData -dbserver $server -DBName $DBName -user $login -savepass $password
        Generate-recommendation -dbserver $server -DBName $DBName -user $login -savepass $password -collectiontime $collectiontime
        if ($options -contains 'dblevel') { $dblevel = DB_level -dbserver $server -DBName master -user $login -password $password }
      }
      if ( $options -eq 'C') {
        Write-host "Cleanup"
        if ($auth -eq 'W' )
        { Cleanup-SQLObjects -dbserver $server -DBName $DBName }
        else { Cleanup-SQLObjects -dbserver $server -DBName $DBName -user $login -savepass $password }
      }
    }
    if ($status[0] -eq "R") {
      $minutesremaining = $status[1]
      if ($options -eq 'L')
      { Generate-recommendation -dbserver $server -DBName $DBName -user $login -savepass $password -collectiontime $collectiontime }
      write-host "Collection Still running $minutesremaining minutes remaining."
    }
  }
  else {
    #write-host $server
    write-host "***** Can't connect to $server"
  }#else
}#foreach
if ($status[0] -eq 'F') {
  Executive_summary $ArrayWithHeader
  TCO
}  
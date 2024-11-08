[CmdletBinding()] 
 Param  
   (
    [Int]$warning = 1,
    [Int]$critical = 7,
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") | Out-Null

try {
    # FULL backup checks 
    $strquerysql = "IF EXISTS( SELECT hars.role_desc FROM sys.DATABASES d INNER JOIN sys.dm_hadr_availability_replica_states hars ON d.replica_id = hars.replica_id WHERE hars.role_desc = 'SECONDARY' )
BEGIN
	SELECT  convert(datetime, convert(char(8), MAX(SJH.run_date))) as LastMaintenanceIndex
    FROM msdb.dbo.sysjobhistory SJH, msdb.dbo.sysjobs SJ
    WHERE SJH.job_id = SJ.job_id and SJ.name = 'DBA Maintenance Index Secondary' and SJH.run_status=1   
END
ELSE
BEGIN
	SELECT  convert(datetime, convert(char(8), MAX(SJH.run_date))) as LastMaintenanceIndex
    FROM msdb.dbo.sysjobhistory SJH, msdb.dbo.sysjobs SJ
    WHERE SJH.job_id = SJ.job_id and SJ.name = 'DBA Maintenance Index' and SJH.run_status=1   
END
"

    $password = Get-Content 'C:\Program Files\NSClient++\scripts\pwd2023' | ConvertTo-SecureString -Key (Get-Content 'C:\Program Files\NSClient++\scripts\aes2023.key')
    #$credential = New-Object System.Management.Automation.PsCredential("SQL-CENTREON",$password)
    $password2= [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR(($password)))

    $HOSTNAME=Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name

    $srvr = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $computerName
    $instances = $srvr | ForEach-Object {$_.ServerInstances} |  select Name     
    #echo $instances     
    $results = @()

    Foreach($Inst in $instances) {
    #echo $Inst
        if ($Inst.NAME -eq 'MSSQLSERVER') 
        {  $INSTANCE=$HOSTNAME
     
        }
        else 
        {  $INSTANCE=$HOSTNAME+"\"+$Inst.name
       
        } 

    $results += Invoke-Sqlcmd -Query $strquerysql -ConnectionString "Data Source=$INSTANCE;Initial Catalog=master;User Id=SQL-CENTREON;Password=$password2;TrustServerCertificate=True"
  
    #$results += Invoke-Sqlcmd -Query $strquerysql -ServerInstance $INSTANCE -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
  
    }

    # $results
    $EndDate=(GET-DATE)

    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $warningvalue =""
        $criticalvalue = ""
        $warningCount = 0
        $criticalCount = 0
        foreach ($line in $results) {
              $StartDate=[datetime]$line.LastMaintenanceIndex
              $ts = NEW-TIMESPAN -Start $StartDate -End $EndDate
              $DayNumber=$ts.Days
          
              if ($DayNumber -gt $critical) {
                $criticalCount++
              }
              else {if ($DayNumber -le $critical -and $DayNumber -gt $warning) {
                $warningCount++
              }}
        }
    }

    if ($criticalCount -ne 0) {
        echo "CRITICAL - Last maintenance Index older than $critical day(s): $DayNumber days"
	    exit 2
    }

    if ($warningCount -ne 0) {
        echo "WARNING - Last maintenance Index older than $warning day(s): $DayNumber days"
        exit 1
    }

    echo "OK - All Maintenance Index are in time"
    exit 0

}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}



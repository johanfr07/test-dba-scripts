[CmdletBinding()] 
 Param  
   (
    [Int]$warning = 7,
    [Int]$critical = 14,
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") | Out-Null

try {
    #Get-DbaLastGoodCheckDb

    $strquerysql = "SELECT DatabaseName,MAX([StartTime]) as LastGoodCheckDb  FROM [DBAdb].[dbo].[CommandLog]WHERE [CommandType] ='DBCC_CHECKDB' AND ErrorNumber=0
     and DatabaseName in (SELECT name FROM sys.databases where state_desc = 'ONLINE' and name not in ('tempdb'))
    group by DatabaseName;"
    
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
  
    # $results += Invoke-Sqlcmd -Query $strquerysql -ServerInstance $INSTANCE -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
    }
  
  
    # echo $results
    $EndDate=(GET-DATE)

    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $warningvalue =""
        $criticalvalue = ""
        $warningCount = 0
        $criticalCount = 0
        foreach ($line in $results) {
              $StartDate=[datetime]$line.LastGoodCheckDb
              $ts = NEW-TIMESPAN -Start $StartDate -End $EndDate
          
              if ($ts.Days -gt $critical) {
                $criticalvalue += $line.DatabaseName +"; "
                $criticalCount++
              }
              else {if ($ts.Days -le $critical -and $ts.Days -gt $warning) {
                $warningvalue += $line.DatabaseName +"; "
                $warningCount++
              }}
        }
    }

    if ($criticalCount -ne 0 -and $criticalvalue -ne $null -and $criticalvalue -ne "") {
        echo "CRITICAL - Last dbcc check older than $critical day(s): $criticalvalue"
        exit 2
    }

    if ($warningCount -ne 0 -and $warningvalue -ne $null -and $warningvalue -ne "") {
        echo "WARNING - Last dbcc check older than $warning day(s): $warningvalue"
        exit 1
    }

    echo "OK - All DBCC checks are in time"
    exit 0

}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}


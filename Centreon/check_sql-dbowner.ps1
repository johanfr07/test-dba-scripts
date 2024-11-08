[CmdletBinding()] 
 Param  
   (
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") | Out-Null

$strquerysql = "IF SERVERPROPERTY ('IsHadrEnabled') = 0  OR (SERVERPROPERTY ('IsHadrEnabled') = 1 
AND EXISTS(SELECT 1 FROM sys.availability_groups_cluster AS AGC
  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS ON  RCS.group_id = AGC.group_id
  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS ON ARS.replica_id = RCS.replica_id
  INNER JOIN sys.availability_group_listeners AS AGL ON AGL.group_id = ARS.group_id
WHERE  ARS.role_desc = 'PRIMARY' AND RCS.replica_server_name = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) ))
BEGIN
    select name as dbname, SUSER_SNAME(owner_sid) as dbowner from sys.databases
where SUSER_SNAME(owner_sid) NOT IN ('sa', 'EU\p1aadm','EU\d1eadm','EU\d1aadm','EU\t1eadm','EU\p1eadm','EU\q1eadm','EU\adminldk','EU\adminkas')
and SUSER_SNAME(owner_sid) NOT LIKE'EU\SVC%'
and SUSER_SNAME(owner_sid) LIKE'%\%'
and state <> 1; -- RESTORING/MIRRORING
END"

try {
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

    $results += Invoke-Sqlcmd -Query $strquerysql -ServerInstance $INSTANCE  -Username 'ITReader' -Password 'xxx' -QueryTimeout $timeout -ErrorAction Stop
  
    }

    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $diffvalue = ""
        $criticalCount = 0
        foreach ($line in $results) {
                $diffvalue += $line.dbname +": "+ $line.dbowner +"; "
                $criticalCount++
        }
    }

    $diffvalue = $diffvalue -replace 'EU\\','EU/'


    if ($criticalCount -ne 0 -and $diffvalue -ne $null -and $diffvalue -ne "") {
        echo "WARNING - Owner not valid on DB: $diffvalue"
        exit 1
    }

    echo "OK - All DBs have valid owner"
    exit 0
}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}




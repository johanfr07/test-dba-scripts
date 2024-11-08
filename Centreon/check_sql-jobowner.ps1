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

$strquerysql = "select name as jobname, SUSER_SNAME(owner_sid) as jobowner 
from msdb.dbo.sysjobs
where enabled = 1
and SUSER_SNAME(owner_sid) NOT IN ('sa', 'EU\p1aadm', 'EU\d1eadm', 'EU\d1aadm', 'EU\t1eadm', 'EU\p1eadm', 'EU\q1eadm','EU\adminldk','EU\adminkas')
and SUSER_SNAME(owner_sid) NOT LIKE'EU\SVC%' 
and SUSER_SNAME(owner_sid) NOT LIKE'EU\SAPService%'
and SUSER_SNAME(owner_sid) LIKE'%\%';"


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
                $diffvalue += $line.jobname +": "+ $line.jobowner +"; "
                $criticalCount++
        }
    }

    $diffvalue = $diffvalue -replace 'EU\\','EU/'


    if ($criticalCount -ne 0 -and $diffvalue -ne $null -and $diffvalue -ne "") {
        echo "WARNING - Owner not valid : $diffvalue"
        exit 1
    }

    echo "OK - All Jobs have valid owner"
    exit 0

}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}

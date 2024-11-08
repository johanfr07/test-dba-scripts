[CmdletBinding()] 
 Param  
   ( 
    [String]$InstanceName = "DEFAULT"
   )#End Param
 

Import-Module Sqlps
cd "SQLSERVER:\Sql\localhost\$InstanceName\AvailabilityGroups"
[String]$AGName = Get-ChildItem "SQLSERVER:\Sql\localhost\$InstanceName\AvailabilityGroups"
$AGName = $AGName.Replace("[", "")
$AGName = $AGName.Replace("]", "")

$agReplicas= dir ".\$AGName\AvailabilityReplicas"

$isPrimary = $false
if (($agReplicas | Where {$_.name -like "$env:COMPUTERNAME*" -and $_.role -eq "Primary"}).count -ne 0) {
    $isPrimary = $true
}

$notconnected = $agReplicas | Where {$_.ConnectionState -ne "Connected"}
if ($isPrimary -eq $false) {
    $notconnected = $agReplicas | Where {$_.Role -ne "Unknown" -and $_.ConnectionState -ne "Connected"}
}
if ($notconnected.count) {
    $count = $notconnected.count
    echo "AG $AGName status: $count node(s) not connected - CRITICAL"
    exit 2
}

$notsynced = $agReplicas | Where {$_.RollupSynchronizationState -ne "Synchronized" -and $_.RollupSynchronizationState -ne "Synchronizing"}
if ($isPrimary -eq $false) {
    $notsynced = $agReplicas | Where {$_.Role -ne "Unknown" -and $_.RollupSynchronizationState -ne "Synchronized" -and $_.RollupSynchronizationState -ne "Synchronizing"}
}
if ($notsynced.count) {
    $count = $notsynced.count
    echo "AG $AGName status: $count node(s) not correctly synchronized - CRITICAL"
    exit 2
}

$agDatabases= dir ".\$AGName\availabilityDatabases"
$notsynced = $agDatabases | Where {($_.SynchronizationState -ne "Synchronized" -and $_.SynchronizationState -ne "Synchronizing") -or $_.IsSuspended -eq $true -or $_.IsJoined -eq $false}
if ($notsynced.count) {
    $count = $notsynced.count
    echo "AG $AGName status: $count databases(s) not correctly synchronized - CRITICAL"
    exit 2
}

if ($isPrimary -eq $false) {
    echo "AG $AGName status: OK - Secondary node"
}
else {
	echo "AG $AGName status: OK - Primary node"
}

exit 0

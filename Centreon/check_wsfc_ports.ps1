
<# Param (
    [string[]]$exclusion = @("")
) #>

$returnCode = 0
$returnMessage = ""

$clusterresults = Get-ClusterResource | where {$_.Name -like 'Cluster IP*'} | Get-ClusterParameter | where-Object {$_.Name -eq "ProbePort" }
$clusterProbePort = $clusterresults.Value
if ($clusterProbePort -ne 58888) {
    $returnCode = 1
    $returnMessage += "WARNING - Cluster Probe port not correctly set ! Now is $clusterProbePort "
}
else {
    $returnMessage += "OK - Cluster Probe port correctly set"
}

$returnMessage += "
"

$listenerresults = Get-ClusterResource | where {$_.Name -like 'IP Address*'} | Get-ClusterParameter | where-Object {$_.Name -eq "ProbePort" }
$listenerProbePort = $listenerresults.Value
if ($listenerProbePort -ne 59999) {
    $returnCode = 2
    $returnMessage += "WARNING - Listener Probe port not correctly set ! Now is $listenerProbePort "
}
else {
    $returnMessage += "OK - Listener Probe port correctly set"
}

Write-Output $returnMessage
$clusterProbePort | ft
$listenerProbePort | ft
exit $returnCode

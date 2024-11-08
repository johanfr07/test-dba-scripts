
# powershell script to get AAG primary and secondary network latency - CC 20210504
# -show parameter takes 3 different values: "primary"(default), "secondary", or "logsendqueue"

[CmdletBinding()] 
 Param
   (
    [String]$show = "primary"
   )#End Param

if ($show -eq "primary") {
    $counters = (Get-Counter -ListSet "Network Interface", "SQLServer:Databases").PathsWithInstances | Where-Object { ($_ -like "*HPE Ethernet*Adapter*" -and ($_ -like "*Bytes Sent/sec*" -or $_ -like "*Idle Time*")) -or ($_ -like "*Reporting)*" -and $_ -like "*Log Bytes Flushed/sec*") } | Get-Counter
}
elseif ($show -eq "secondary") {
    $counters = (Get-Counter -ListSet "SQLServer:Database Replica").PathsWithInstances | Where-Object { ($_ -like "*Reporting)*" -and $_ -like "*Log Bytes Received/sec*") -or ($_ -like "*Reporting)*" -and $_ -like "*Recovery Queue*") } | Get-Counter
}
else {
    $counters = (Get-Counter -ListSet "SQLServer:Database Replica").PathsWithInstances | Where-Object { ($_ -like "*Reporting)*" -and $_ -like "*Log Send Queue Counter*") } | Get-Counter
}

if ($counters -eq $null) {
    echo "CRITICAL: Could not get counters";
    exit 2 # "critical"
}

$output = "OK: "
$output1 = "";
$output2 = "";

foreach ($currentSample in $counters.CounterSamples) {
    $path = [regex]::match($currentSample.Path,'.*\((.*)').Groups[1].Value
    $path = $path.Replace(")\", " ")
    $value = [math]::Round($currentSample.CookedValue, 2)
    
    # Log Send Queue and Bytes/s
        if ($path -like "*bytes*") {
            $value = [math]::Round($value, 0)
            $output1 += $path + " = " + $value + " bytes/s, "
            $output2 += "'" + $path + "'=" + $value + " bytes/s;0;0 "
        }
        else {
            $output1 += $path + " = " + $value + ", "
            $output2 += "'" + $path + "'=" + $value + ";0;0 "
        }
}
$output = "OK: " + $output1 + "|" + $output2
echo $output


#desired format
#OK: hpe ethernet 1gb 4-port 331flr adapter _4 bytes sent/sec = 303 bytes/s, reporting log bytes flushed/sec = 0 bytes/s, |'hpe ethernet 1gb 4-port 331flr adapter _4 bytes sent/sec'=303 bytes/s;0;0 'reporting log bytes flushed/sec'=0 bytes/s;0;0 
#part after | (pipe) is for graph data
#ref: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-counter?view=powershell-7

[CmdletBinding()] 
 Param  
   (
    [Int]$warning = 180,
    [Int]$critical = 300,
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null

try {
    $strquerysql = "SELECT  job.name	
		    , DATEDIFF(MINUTE, activity.run_requested_date, GETDATE()) as running_time_in_minutes
		    , activity.run_requested_date
    FROM    msdb.dbo.sysjobs job
		    INNER JOIN msdb.dbo.sysjobactivity activity ON job.job_id = activity.job_id
		    INNER JOIN msdb.dbo.syssessions sess ON sess.session_id = activity.session_id
		    INNER JOIN ( SELECT   MAX(agent_start_date) AS max_agent_start_date
				    FROM     msdb.dbo.syssessions
				    ) sess_max ON sess.agent_start_date = sess_max.max_agent_start_date
		    INNER JOIN [DBAdb].[dbo].[LongRunningJobs] ON [JobName] = job.name 
			    AND [StartExecutionTime]  = convert(smallint,left(replace(convert(varchar, activity.run_requested_date, 108),  ':', ''),4))
    WHERE   run_requested_date IS NOT NULL
		    AND stop_execution_date IS NULL
		    AND [DurationLimit] < DATEDIFF(MINUTE, activity.run_requested_date, GETDATE());"

    $results = Invoke-Sqlcmd -Query $strquerysql -ServerInstance localhost -Username 'ITReader' -Password 'xxx' -QueryTimeout $timeout -ErrorAction Stop

    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $diffvalue = ""
        $criticalCount = 0
        foreach ($line in $results) {
                $diffvalue += $line.name +"- running time " + $line.running_time_in_minutes + " minutes since " + $line.run_requested_date +"; "
                $criticalCount++
        }
    }

    if ($criticalCount -ne 0 -and $diffvalue -ne $null -and $diffvalue -ne "") {
        echo "CRITICAL - Long job: $diffvalue"
        exit 2
    }

    echo "OK - All Jobs are in time"
    exit 0    

}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}


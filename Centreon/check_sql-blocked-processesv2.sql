

USE [DBAdb]
go

/****** Object:  StoredProcedure [dbo].[usp_GetBlockedProcesses]    Script Date: 21/10/2024 16:49:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_GetBlockedProcesses]
AS
BEGIN

SET NOCOUNT ON;

WITH Processes (spid, BlockingSPID , Hostname, DatabaseName, ProgramName, LoginName, WaitType, LastBatchDate, SQLStatement )
AS(
SELECT
             s.spid, BlockingSPID = s.blocked, s.hostname, DatabaseName = DB_NAME(s.dbid),
             s.program_name as ProgramName, s.loginame as LoginName, s.lastwaittype, s.last_batch,
			 SQLStatement = CAST(text AS VARCHAR(MAX))			  
 FROM      sys.sysprocesses s
 CROSS APPLY sys.dm_exec_sql_text (sql_handle)
 WHERE
            s.spid > 50
) ,
Blocking(SPID, BlockingSPID, HostName, DatabaseName, ProgramName, LoginName, WaitType, LastBatchDate, SQLStatement, RowNo, LevelRow)
 AS
 (
      SELECT
       s.SPID, s.BlockingSPID, s.Hostname, s.DatabaseName, s.ProgramName, s.LoginName, s.WaitType, s.LastBatchDate, s.SQLStatement, 
       ROW_NUMBER() OVER(ORDER BY s.SPID),
       0 AS LevelRow
     FROM
       Processes s
       JOIN Processes s1 ON s.SPID = s1.BlockingSPID
     WHERE
       s.BlockingSPID = 0
     UNION ALL
     SELECT
       r.SPID,  r.BlockingSPID, r.Hostname, r.DatabaseName, r.ProgramName, r.LoginName, r.WaitType, r.LastBatchDate, r.SQLStatement, 
       d.RowNo,
       d.LevelRow + 1
     FROM
       Processes r
      JOIN Blocking d ON r.BlockingSPID = d.SPID
     WHERE
       r.BlockingSPID > 0
 )
 SELECT ('NbBlockedProcesses: '+ (SELECT convert(varchar(20),count(*)) FROM Blocking)) +
		(', SPID: '+ convert(varchar(20), SPID)) +
		(', BlockingSPID: '+ convert(varchar(20), BlockingSPID)) +
		(', HostName: '+ convert(varchar(100), HostName)) +
		(', DatabaseName: '+ convert(varchar(100), DatabaseName)) +
		(', ProgramName: '+ convert(varchar(100), ProgramName)) +
		(', LoginName: '+ convert(varchar(100), LoginName)) +
		(', WaitType: '+ convert(varchar(70), WaitType)) +
		(', LastBatchDate: '+ convert(varchar(50), LastBatchDate, 121)) +
		(', SQLStatement: '+ convert(varchar(2000), SQLStatement)) as BlockDescription, RowNo, LevelRow FROM Blocking
 UNION ALL
 SELECT '0' as BlockDescription, 9999 as RowNo, 9999 as LevelRow
 ORDER BY RowNo, LevelRow;
 -- SPID , BLOCKING & BLOCKED , HOSTNAME, LOGIN, WAITTYPE, START TIME, SQL STATEMENT

 END

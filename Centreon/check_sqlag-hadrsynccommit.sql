SET NOCOUNT ON;
select count(session_id) as nb from sys.dm_exec_requests where session_id>=50 and wait_type= 'HADR_SYNC_COMMIT';

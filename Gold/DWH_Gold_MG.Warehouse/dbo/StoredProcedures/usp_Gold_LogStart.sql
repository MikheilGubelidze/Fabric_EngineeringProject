CREATE   PROCEDURE dbo.usp_Gold_LogStart(
      @RunID        UNIQUEIDENTIFIER
    , @PipelineName VARCHAR(100)
    , @TableName    VARCHAR(100) )
AS
BEGIN
    INSERT INTO dbo.Gold_Load_Log(RunID, PipelineName, TableName, LoadStartTime, Status)
    VALUES (@RunID, @PipelineName, @TableName, GETDATE(), 'Running');
END

GO
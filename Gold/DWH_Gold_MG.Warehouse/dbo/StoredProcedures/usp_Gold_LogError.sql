CREATE   PROCEDURE dbo.usp_Gold_LogError(
      @RunID        UNIQUEIDENTIFIER
    , @ErrorMessage VARCHAR(4000) )
AS
BEGIN
    UPDATE dbo.Gold_Load_Log
    SET   LoadEndTime  = GETDATE()
        , Status       = 'Failed'
        , ErrorMessage = LEFT(@ErrorMessage, 4000)
    WHERE RunID = @RunID;
END

GO
CREATE   PROCEDURE dbo.usp_Gold_LogSuccess(
      @RunID            UNIQUEIDENTIFIER
    , @LoadMode         VARCHAR(20)
    , @WmFrom           DATETIME2(6)
    , @WmTo             DATETIME2(6)
    , @DatesAffected    INT
    , @FactRowsWritten  INT
    , @NewCustomers     INT
    , @CustomerVersions INT
    , @NewProducts      INT
    , @ProductVersions  INT
    , @Status           VARCHAR(20) )
AS
BEGIN
    UPDATE dbo.Gold_Load_Log
    SET   LoadEndTime      = GETDATE()
        , LoadMode         = @LoadMode
        , WmFrom           = @WmFrom
        , WmTo             = @WmTo
        , DatesAffected    = @DatesAffected
        , FactRowsWritten  = @FactRowsWritten
        , NewCustomers     = @NewCustomers
        , CustomerVersions = @CustomerVersions
        , NewProducts      = @NewProducts
        , ProductVersions  = @ProductVersions
        , Status           = @Status
    WHERE RunID = @RunID;
END

GO
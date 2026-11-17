CREATE TABLE [dbo].[Gold_Load_Log] (
    [RunID]            UNIQUEIDENTIFIER NULL,
    [PipelineName]     VARCHAR (100)    NULL,
    [TableName]        VARCHAR (100)    NULL,
    [LoadStartTime]    DATETIME2 (6)    NULL,
    [LoadEndTime]      DATETIME2 (6)    NULL,
    [LoadMode]         VARCHAR (20)     NULL,
    [WmFrom]           DATETIME2 (6)    NULL,
    [WmTo]             DATETIME2 (6)    NULL,
    [DatesAffected]    INT              NULL,
    [FactRowsWritten]  INT              NULL,
    [NewCustomers]     INT              NULL,
    [CustomerVersions] INT              NULL,
    [NewProducts]      INT              NULL,
    [ProductVersions]  INT              NULL,
    [Status]           VARCHAR (20)     NULL,
    [ErrorMessage]     VARCHAR (4000)   NULL
);


GO
CREATE TABLE [dbo].[Gold_Watermark] (
    [TableName]         VARCHAR (100) NOT NULL,
    [LastChangeLogTime] DATETIME2 (6) NOT NULL,
    [UpdatedAt]         DATETIME2 (6) NULL
);


GO
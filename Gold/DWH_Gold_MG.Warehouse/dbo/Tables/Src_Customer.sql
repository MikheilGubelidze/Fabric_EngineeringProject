CREATE TABLE [dbo].[Src_Customer] (
    [CustomerID]       VARCHAR (50)  NOT NULL,
    [CustomerName]     VARCHAR (200) NULL,
    [Segment]          VARCHAR (100) NULL,
    [City]             VARCHAR (100) NULL,
    [LastModifiedTime] DATETIME2 (6) NULL,
    [LoadedAt]         DATETIME2 (6) NULL
);


GO
CREATE TABLE [dbo].[Src_Product] (
    [ProductID]        VARCHAR (20)  NOT NULL,
    [ProductName]      VARCHAR (200) NULL,
    [Category]         VARCHAR (100) NULL,
    [SubCategory]      VARCHAR (100) NULL,
    [Brand]            VARCHAR (100) NULL,
    [LastModifiedTime] DATETIME2 (6) NULL,
    [LoadedAt]         DATETIME2 (6) NULL
);


GO
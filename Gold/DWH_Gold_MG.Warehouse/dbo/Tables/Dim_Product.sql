CREATE TABLE [dbo].[Dim_Product] (
    [ProductKey]  BIGINT           NOT NULL,
    [ProductID]   VARCHAR (20)     NOT NULL,
    [ProductName] VARCHAR (200)    NOT NULL,
    [Category]    VARCHAR (100)    NOT NULL,
    [SubCategory] VARCHAR (100)    NOT NULL,
    [Brand]       VARCHAR (100)    NOT NULL,
    [ValidFrom]   DATE             NOT NULL,
    [ValidTo]     DATE             NOT NULL,
    [IsCurrent]   BIT              NOT NULL,
    [IsUnknown]   BIT              NOT NULL,
    [RunID]       UNIQUEIDENTIFIER NULL,
    [CreatedAt]   DATETIME2 (6)    NOT NULL,
    [UpdatedAt]   DATETIME2 (6)    NOT NULL
);


GO

ALTER TABLE [dbo].[Dim_Product]
    ADD CONSTRAINT [PK_Dim_Product] PRIMARY KEY NONCLUSTERED ([ProductKey] ASC) NOT ENFORCED;


GO
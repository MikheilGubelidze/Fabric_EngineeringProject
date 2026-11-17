CREATE TABLE [dbo].[Dim_Customer] (
    [CustomerKey]  BIGINT           NOT NULL,
    [CustomerID]   VARCHAR (50)     NOT NULL,
    [CustomerName] VARCHAR (200)    NOT NULL,
    [Segment]      VARCHAR (100)    NOT NULL,
    [City]         VARCHAR (100)    NOT NULL,
    [ValidFrom]    DATE             NOT NULL,
    [ValidTo]      DATE             NOT NULL,
    [IsCurrent]    BIT              NOT NULL,
    [IsUnknown]    BIT              NOT NULL,
    [RunID]        UNIQUEIDENTIFIER NULL,
    [CreatedAt]    DATETIME2 (6)    NOT NULL,
    [UpdatedAt]    DATETIME2 (6)    NOT NULL
);


GO

ALTER TABLE [dbo].[Dim_Customer]
    ADD CONSTRAINT [PK_Dim_Customer] PRIMARY KEY NONCLUSTERED ([CustomerKey] ASC) NOT ENFORCED;


GO
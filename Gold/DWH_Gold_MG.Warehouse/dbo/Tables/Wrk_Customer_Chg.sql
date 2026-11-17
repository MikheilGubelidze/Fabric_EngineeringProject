CREATE TABLE [dbo].[Wrk_Customer_Chg] (
    [OldKey]       BIGINT        NOT NULL,
    [CustomerID]   VARCHAR (50)  NOT NULL,
    [CustomerName] VARCHAR (200) NOT NULL,
    [Segment]      VARCHAR (100) NOT NULL,
    [City]         VARCHAR (100) NOT NULL,
    [OldValidFrom] DATE          NOT NULL
);


GO
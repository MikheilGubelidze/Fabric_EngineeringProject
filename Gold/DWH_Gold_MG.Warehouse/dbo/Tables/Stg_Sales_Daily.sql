CREATE TABLE [dbo].[Stg_Sales_Daily] (
    [TransactionDate]      DATE            NOT NULL,
    [CustomerID]           VARCHAR (50)    NOT NULL,
    [ProductID]            VARCHAR (20)    NOT NULL,
    [SalesQuantity]        INT             NULL,
    [ReturnQuantity]       INT             NULL,
    [NetQuantity]          INT             NULL,
    [GrossSalesAmount]     DECIMAL (18, 2) NULL,
    [DiscountAmount]       DECIMAL (18, 2) NULL,
    [SalesAmount]          DECIMAL (18, 2) NULL,
    [ReturnAmount]         DECIMAL (18, 2) NULL,
    [NetAmount]            DECIMAL (18, 2) NULL,
    [TransactionCount]     INT             NULL,
    [LineCount]            INT             NULL,
    [AvgUnitPrice]         DECIMAL (18, 2) NULL,
    [FirstTransactionTime] DATETIME2 (6)   NULL,
    [LastTransactionTime]  DATETIME2 (6)   NULL
);


GO
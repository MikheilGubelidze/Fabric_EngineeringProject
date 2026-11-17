CREATE TABLE [dbo].[Fact_Sales_Daily] (
    [DateKey]              INT              NOT NULL,
    [CustomerKey]          BIGINT           NOT NULL,
    [ProductKey]           BIGINT           NOT NULL,
    [SalesQuantity]        INT              NULL,
    [ReturnQuantity]       INT              NULL,
    [NetQuantity]          INT              NULL,
    [GrossSalesAmount]     DECIMAL (18, 2)  NULL,
    [DiscountAmount]       DECIMAL (18, 2)  NULL,
    [SalesAmount]          DECIMAL (18, 2)  NULL,
    [ReturnAmount]         DECIMAL (18, 2)  NULL,
    [NetAmount]            DECIMAL (18, 2)  NULL,
    [TransactionCount]     INT              NULL,
    [LineCount]            INT              NULL,
    [AvgUnitPrice]         DECIMAL (18, 2)  NULL,
    [FirstTransactionTime] DATETIME2 (6)    NULL,
    [LastTransactionTime]  DATETIME2 (6)    NULL,
    [RunID]                UNIQUEIDENTIFIER NULL,
    [LoadTime]             DATETIME2 (6)    NULL
);


GO
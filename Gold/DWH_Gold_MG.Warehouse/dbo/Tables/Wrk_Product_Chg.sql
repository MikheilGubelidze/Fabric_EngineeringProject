CREATE TABLE [dbo].[Wrk_Product_Chg] (
    [OldKey]       BIGINT        NOT NULL,
    [ProductID]    VARCHAR (20)  NOT NULL,
    [ProductName]  VARCHAR (200) NOT NULL,
    [Category]     VARCHAR (100) NOT NULL,
    [SubCategory]  VARCHAR (100) NOT NULL,
    [Brand]        VARCHAR (100) NOT NULL,
    [OldValidFrom] DATE          NOT NULL
);


GO
CREATE TABLE [dbo].[Dim_Date] (
    [DateKey]     INT          NOT NULL,
    [Date]        DATE         NOT NULL,
    [Year]        INT          NOT NULL,
    [Quarter]     INT          NOT NULL,
    [QuarterName] VARCHAR (2)  NOT NULL,
    [Month]       INT          NOT NULL,
    [MonthName]   VARCHAR (20) NOT NULL,
    [MonthShort]  VARCHAR (3)  NOT NULL,
    [YearMonth]   VARCHAR (7)  NOT NULL,
    [WeekOfYear]  INT          NOT NULL,
    [DayOfMonth]  INT          NOT NULL,
    [DayOfWeek]   INT          NOT NULL,
    [DayName]     VARCHAR (20) NOT NULL,
    [IsWeekend]   BIT          NOT NULL
);


GO
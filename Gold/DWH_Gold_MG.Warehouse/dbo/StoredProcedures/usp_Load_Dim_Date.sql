CREATE   PROCEDURE dbo.usp_Load_Dim_Date
AS
BEGIN
    DECLARE @MinDate DATE = (SELECT MIN(TransactionDate) FROM dbo.Stg_Sales_Daily);
    DECLARE @MaxDate DATE = (SELECT MAX(TransactionDate) FROM dbo.Stg_Sales_Daily);
    IF @MinDate IS NULL RETURN;
 
    DECLARE @Start   DATE = DATEFROMPARTS(YEAR(@MinDate), 1, 1);
    DECLARE @EndYear INT  = CASE WHEN YEAR(@MaxDate) > YEAR(GETDATE())
                                 THEN YEAR(@MaxDate) ELSE YEAR(GETDATE()) END + 1;
    DECLARE @End     DATE = DATEFROMPARTS(@EndYear, 12, 31);
 
    WITH digits AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS v(n)),
         nums   AS (SELECT a.n + b.n * 10 + c.n * 100 + d.n * 1000 + e.n * 10000 AS n
                    FROM digits a CROSS JOIN digits b CROSS JOIN digits c
                         CROSS JOIN digits d CROSS JOIN digits e),
         cal    AS (SELECT DATEADD(DAY, n, @Start) AS [Date]
                    FROM nums WHERE n <= DATEDIFF(DAY, @Start, @End))
    INSERT INTO dbo.Dim_Date
        (DateKey, [Date], [Year], [Quarter], QuarterName, [Month], MonthName,
         MonthShort, YearMonth, WeekOfYear, DayOfMonth, DayOfWeek, DayName, IsWeekend)
    SELECT CONVERT(INT, CONVERT(CHAR(8), cal.[Date], 112)),
           cal.[Date],
           YEAR(cal.[Date]),
           DATEPART(QUARTER, cal.[Date]),
           CONCAT('Q', DATEPART(QUARTER, cal.[Date])),
           MONTH(cal.[Date]),
           DATENAME(MONTH, cal.[Date]),
           LEFT(DATENAME(MONTH, cal.[Date]), 3),
           CONVERT(CHAR(7), cal.[Date], 126),
           DATEPART(ISO_WEEK, cal.[Date]),
           DAY(cal.[Date]),
           DATEDIFF(DAY, '19000101', cal.[Date]) % 7 + 1,          -- 1 = ორშაბათი
           DATENAME(WEEKDAY, cal.[Date]),
           CASE WHEN DATEDIFF(DAY, '19000101', cal.[Date]) % 7 + 1 >= 6 THEN 1 ELSE 0 END
    FROM cal
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Date x WHERE x.[Date] = cal.[Date]);
END

GO
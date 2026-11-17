CREATE   PROCEDURE dbo.usp_Load_Dim_Customer
      @RunID       UNIQUEIDENTIFIER
    , @LoadDate    DATE
    , @NewMembers  INT OUTPUT
    , @NewVersions INT OUTPUT
AS
BEGIN
    DECLARE @NA          VARCHAR(20)  = 'Not Available';
    DECLARE @Now         DATETIME2(6) = GETDATE();
    DECLARE @LoadDateKey INT          = CONVERT(INT, CONVERT(CHAR(8), @LoadDate, 112));
    DECLARE @MaxKey      BIGINT;
 
    ------------------------------------------------------------------
    -- 1. ახალი წევრები: მხოლოდ Master Data-ს ასლიდან (dbo.Src_Customer).
    --    გაყიდვებიდან (Fact / Stg_Sales_Daily) წევრი არ იქმნება:
    --    Master Data-ში არარსებული ID-ის ფაქტი Unknown-ს (-1) მიება.
    ------------------------------------------------------------------
    SET @MaxKey = (SELECT CASE WHEN MAX(CustomerKey) > 0 THEN MAX(CustomerKey) ELSE 0 END
                   FROM dbo.Dim_Customer);
 
    INSERT INTO dbo.Dim_Customer
        (CustomerKey, CustomerID, CustomerName, Segment, City,
         ValidFrom, ValidTo, IsCurrent, IsUnknown, RunID, CreatedAt, UpdatedAt)
    SELECT @MaxKey + ROW_NUMBER() OVER (ORDER BY n.CustomerID),
           n.CustomerID, n.CustomerName, n.Segment, n.City,
           '1900-01-01', '9999-12-31', 1, 0, @RunID, @Now, @Now
    FROM (
        SELECT m.CustomerID,
               COALESCE(m.CustomerName, @NA) AS CustomerName,
               COALESCE(m.Segment, @NA)      AS Segment,
               COALESCE(m.City, @NA)         AS City
        FROM dbo.Src_Customer m
    ) n
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Customer d WHERE d.CustomerID = n.CustomerID);
 
    SET @NewMembers = @@ROWCOUNT;
 
    ------------------------------------------------------------------
    -- 2. ცვლილების აღმოჩენა: მიმდინარე ვერსია (IsCurrent = 1) ≠ Master Data
    ------------------------------------------------------------------
    DELETE FROM dbo.Wrk_Customer_Chg;
 
    INSERT INTO dbo.Wrk_Customer_Chg
        (OldKey, CustomerID, CustomerName, Segment, City, OldValidFrom)
    SELECT d.CustomerKey, d.CustomerID,
           COALESCE(r.CustomerName, @NA),
           COALESCE(r.Segment, @NA),
           COALESCE(r.City, @NA),
           d.ValidFrom
    FROM dbo.Dim_Customer d
    JOIN dbo.Src_Customer r ON r.CustomerID = d.CustomerID
    WHERE d.IsCurrent = 1 AND d.IsUnknown = 0
      AND (   d.CustomerName <> COALESCE(r.CustomerName, @NA)
           OR d.Segment      <> COALESCE(r.Segment, @NA)
           OR d.City         <> COALESCE(r.City, @NA) );
 
    -- 2a. იმავე დღის მეორე ცვლილება: ვერსია დღეს შეიქმნა → ადგილზე განახლება
    MERGE INTO dbo.Dim_Customer AS d
    USING (SELECT * FROM dbo.Wrk_Customer_Chg WHERE OldValidFrom = @LoadDate) AS c
       ON d.CustomerKey = c.OldKey
    WHEN MATCHED THEN UPDATE SET
         d.CustomerName = c.CustomerName,
         d.Segment      = c.Segment,
         d.City         = c.City,
         d.RunID        = @RunID,
         d.UpdatedAt    = @Now;
 
    DELETE FROM dbo.Wrk_Customer_Chg WHERE OldValidFrom = @LoadDate;
 
    ------------------------------------------------------------------
    -- 3. SCD2 ①: ძველი ვერსიის დახურვა
    ------------------------------------------------------------------
    UPDATE dbo.Dim_Customer
    SET   ValidTo   = DATEADD(DAY, -1, @LoadDate)
        , IsCurrent = 0
        , RunID     = @RunID
        , UpdatedAt = @Now
    WHERE CustomerKey IN (SELECT OldKey FROM dbo.Wrk_Customer_Chg);
 
    ------------------------------------------------------------------
    -- 4. SCD2 ②: ახალი ვერსიის ჩაწერა (ახალი surrogate key)
    ------------------------------------------------------------------
    SET @MaxKey = (SELECT MAX(CustomerKey) FROM dbo.Dim_Customer);
 
    INSERT INTO dbo.Dim_Customer
        (CustomerKey, CustomerID, CustomerName, Segment, City,
         ValidFrom, ValidTo, IsCurrent, IsUnknown, RunID, CreatedAt, UpdatedAt)
    SELECT @MaxKey + ROW_NUMBER() OVER (ORDER BY c.CustomerID),
           c.CustomerID, c.CustomerName, c.Segment, c.City,
           @LoadDate, '9999-12-31', 1, 0, @RunID, @Now, @Now
    FROM dbo.Wrk_Customer_Chg c;
 
    SET @NewVersions = @@ROWCOUNT;
 
    ------------------------------------------------------------------
    -- 5. SCD2 ③: დღევანდელი ფაქტების გადაბმა ახალ ვერსიაზე
    ------------------------------------------------------------------
    MERGE INTO dbo.Fact_Sales_Daily AS f
    USING (SELECT c.OldKey, d.CustomerKey AS NewKey
           FROM dbo.Wrk_Customer_Chg c
           JOIN dbo.Dim_Customer d
             ON d.CustomerID = c.CustomerID
            AND d.IsCurrent = 1
            AND d.ValidFrom = @LoadDate) AS v
       ON f.CustomerKey = v.OldKey AND f.DateKey >= @LoadDateKey
    WHEN MATCHED THEN UPDATE SET f.CustomerKey = v.NewKey;
END

GO
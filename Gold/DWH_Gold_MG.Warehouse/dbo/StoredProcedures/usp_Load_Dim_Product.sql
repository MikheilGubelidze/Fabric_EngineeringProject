CREATE   PROCEDURE dbo.usp_Load_Dim_Product
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
    -- 1. ახალი წევრები: მხოლოდ Master Data-ს ასლიდან (dbo.Src_Product).
    --    გაყიდვებიდან (Fact / Stg_Sales_Daily) წევრი არ იქმნება:
    --    Master Data-ში არარსებული ID-ის ფაქტი Unknown-ს (-1) მიება.
    ------------------------------------------------------------------
    SET @MaxKey = (SELECT CASE WHEN MAX(ProductKey) > 0 THEN MAX(ProductKey) ELSE 0 END
                   FROM dbo.Dim_Product);
 
    INSERT INTO dbo.Dim_Product
        (ProductKey, ProductID, ProductName, Category, SubCategory, Brand,
         ValidFrom, ValidTo, IsCurrent, IsUnknown, RunID, CreatedAt, UpdatedAt)
    SELECT @MaxKey + ROW_NUMBER() OVER (ORDER BY n.ProductID),
           n.ProductID, n.ProductName, n.Category, n.SubCategory, n.Brand,
           '1900-01-01', '9999-12-31', 1, 0, @RunID, @Now, @Now
    FROM (
        SELECT m.ProductID,
               COALESCE(m.ProductName, @NA) AS ProductName,
               COALESCE(m.Category, @NA)    AS Category,
               COALESCE(m.SubCategory, @NA) AS SubCategory,
               COALESCE(m.Brand, @NA)       AS Brand
        FROM dbo.Src_Product m
    ) n
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Product d WHERE d.ProductID = n.ProductID);
 
    SET @NewMembers = @@ROWCOUNT;
 
    ------------------------------------------------------------------
    -- 2. ცვლილების აღმოჩენა: მიმდინარე ვერსია (IsCurrent = 1) ≠ Master Data
    ------------------------------------------------------------------
    DELETE FROM dbo.Wrk_Product_Chg;
 
    INSERT INTO dbo.Wrk_Product_Chg
        (OldKey, ProductID, ProductName, Category, SubCategory, Brand, OldValidFrom)
    SELECT d.ProductKey, d.ProductID,
           COALESCE(r.ProductName, @NA),
           COALESCE(r.Category, @NA),
           COALESCE(r.SubCategory, @NA),
           COALESCE(r.Brand, @NA),
           d.ValidFrom
    FROM dbo.Dim_Product d
    JOIN dbo.Src_Product r ON r.ProductID = d.ProductID
    WHERE d.IsCurrent = 1 AND d.IsUnknown = 0
      AND (   d.ProductName <> COALESCE(r.ProductName, @NA)
           OR d.Category    <> COALESCE(r.Category, @NA)
           OR d.SubCategory <> COALESCE(r.SubCategory, @NA)
           OR d.Brand       <> COALESCE(r.Brand, @NA) );
 
    -- 2a. იმავე დღის მეორე ცვლილება: ვერსია დღეს შეიქმნა → ადგილზე განახლება
    MERGE INTO dbo.Dim_Product AS d
    USING (SELECT * FROM dbo.Wrk_Product_Chg WHERE OldValidFrom = @LoadDate) AS c
       ON d.ProductKey = c.OldKey
    WHEN MATCHED THEN UPDATE SET
         d.ProductName = c.ProductName,
         d.Category    = c.Category,
         d.SubCategory = c.SubCategory,
         d.Brand       = c.Brand,
         d.RunID        = @RunID,
         d.UpdatedAt    = @Now;
 
    DELETE FROM dbo.Wrk_Product_Chg WHERE OldValidFrom = @LoadDate;
 
    ------------------------------------------------------------------
    -- 3. SCD2 ①: ძველი ვერსიის დახურვა
    ------------------------------------------------------------------
    UPDATE dbo.Dim_Product
    SET   ValidTo   = DATEADD(DAY, -1, @LoadDate)
        , IsCurrent = 0
        , RunID     = @RunID
        , UpdatedAt = @Now
    WHERE ProductKey IN (SELECT OldKey FROM dbo.Wrk_Product_Chg);
 
    ------------------------------------------------------------------
    -- 4. SCD2 ②: ახალი ვერსიის ჩაწერა (ახალი surrogate key)
    ------------------------------------------------------------------
    SET @MaxKey = (SELECT MAX(ProductKey) FROM dbo.Dim_Product);
 
    INSERT INTO dbo.Dim_Product
        (ProductKey, ProductID, ProductName, Category, SubCategory, Brand,
         ValidFrom, ValidTo, IsCurrent, IsUnknown, RunID, CreatedAt, UpdatedAt)
    SELECT @MaxKey + ROW_NUMBER() OVER (ORDER BY c.ProductID),
           c.ProductID, c.ProductName, c.Category, c.SubCategory, c.Brand,
           @LoadDate, '9999-12-31', 1, 0, @RunID, @Now, @Now
    FROM dbo.Wrk_Product_Chg c;
 
    SET @NewVersions = @@ROWCOUNT;
 
    ------------------------------------------------------------------
    -- 5. SCD2 ③: დღევანდელი ფაქტების გადაბმა ახალ ვერსიაზე
    ------------------------------------------------------------------
    MERGE INTO dbo.Fact_Sales_Daily AS f
    USING (SELECT c.OldKey, d.ProductKey AS NewKey
           FROM dbo.Wrk_Product_Chg c
           JOIN dbo.Dim_Product d
             ON d.ProductID = c.ProductID
            AND d.IsCurrent = 1
            AND d.ValidFrom = @LoadDate) AS v
       ON f.ProductKey = v.OldKey AND f.DateKey >= @LoadDateKey
    WHEN MATCHED THEN UPDATE SET f.ProductKey = v.NewKey;
END

GO
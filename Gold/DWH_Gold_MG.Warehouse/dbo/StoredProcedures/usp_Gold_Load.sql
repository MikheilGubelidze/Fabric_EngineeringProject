CREATE   PROCEDURE dbo.usp_Gold_Load
      @RunID  UNIQUEIDENTIFIER
    , @WmFrom VARCHAR(30)
    , @WmTo   VARCHAR(30)
AS
BEGIN
    DECLARE @From     DATETIME2(6) = CAST(@WmFrom AS DATETIME2(6));
    DECLARE @To       DATETIME2(6) = CAST(@WmTo   AS DATETIME2(6));
    DECLARE @LoadDate DATE         = CAST(GETDATE() AS DATE);
    DECLARE @LoadMode VARCHAR(20)  = 'INCREMENTAL';
    DECLARE @MaxIncrementalDates INT = 60;
    DECLARE @DatesAffected INT = 0, @FactRows INT = 0;
    DECLARE @NewCustomers INT = 0, @CustomerVersions INT = 0;
    DECLARE @NewProducts  INT = 0, @ProductVersions  INT = 0;
    DECLARE @Status VARCHAR(20);
 
    ------------------------------------------------------------------
    -- A. დაზარალებული დღეები Silver_Change_Log-იდან, ფანჯარა (WmFrom, WmTo]
    ------------------------------------------------------------------
    DELETE FROM dbo.Wrk_Gold_Dates;
 
    INSERT INTO dbo.Wrk_Gold_Dates (TransactionDate)
    SELECT DISTINCT TransactionDate
    FROM lh_Silver_MG.dbo.silver_change_log
    WHERE LoggedAt > @From AND LoggedAt <= @To
      AND TransactionDate IS NOT NULL;
 
    ------------------------------------------------------------------
    -- A2. Late-arriving dimension: Master Data-ში ახლად გამოჩენილი ID-ები.
    --     მათი გაყიდვები აქამდე Unknown-ზე (-1) იყო მიბმული, ამიტომ
    --     ამ ID-ების დღეები თავიდან დაითვლება და ფაქტი სწორ key-ს მიება.
    --     (Dim-ის წევრი აქაც Master Data-დან იქმნება — ნაბიჯი E.)
    ------------------------------------------------------------------
    INSERT INTO dbo.Wrk_Gold_Dates (TransactionDate)
    SELECT DISTINCT s.TransactionDate
    FROM lh_Silver_MG.dbo.silver_sales s
    WHERE (   s.CustomerID IN (SELECT m.CustomerID
                               FROM dbo.Src_Customer m
                               WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Customer d
                                                 WHERE d.CustomerID = m.CustomerID))
           OR s.ProductID  IN (SELECT m.ProductID
                               FROM dbo.Src_Product m
                               WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Product d
                                                 WHERE d.ProductID = m.ProductID)) )
      AND NOT EXISTS (SELECT 1 FROM dbo.Wrk_Gold_Dates w
                      WHERE w.TransactionDate = s.TransactionDate);
 
    SET @DatesAffected = (SELECT COUNT(*) FROM dbo.Wrk_Gold_Dates);
 
    ------------------------------------------------------------------
    -- B. რეჟიმი: FULL / INCREMENTAL / NONE
    ------------------------------------------------------------------
    IF @From <= '1900-01-01'
       OR @DatesAffected > @MaxIncrementalDates
       OR NOT EXISTS (SELECT 1 FROM dbo.Fact_Sales_Daily)
        SET @LoadMode = 'FULL';
    ELSE IF @DatesAffected = 0
        SET @LoadMode = 'NONE';
 
    ------------------------------------------------------------------
    -- C. აგრეგაცია: დღე × მომხმარებელი × პროდუქტი → Stg_Sales_Daily
    ------------------------------------------------------------------
    DELETE FROM dbo.Stg_Sales_Daily;
 
    WITH src AS (
        SELECT s.TransactionDate,
               COALESCE(s.CustomerID, 'UNKNOWN') AS CustomerID,
               s.ProductID, s.TransactionID, s.TransactionDateTime,
               s.Quantity, s.UnitPrice, s.TotalAmount, s.IsReturn
        FROM lh_Silver_MG.dbo.silver_sales s
        WHERE @LoadMode = 'FULL'
           OR (@LoadMode = 'INCREMENTAL'
               AND s.TransactionDate IN (SELECT TransactionDate FROM dbo.Wrk_Gold_Dates))
    ),
    agg AS (
        SELECT TransactionDate, CustomerID, ProductID,
               SUM(CASE WHEN IsReturn = 0 THEN Quantity ELSE 0 END)    AS SalesQuantity,
               SUM(CASE WHEN IsReturn = 1 THEN -Quantity ELSE 0 END)   AS ReturnQuantity,
               SUM(Quantity)                                           AS NetQuantity,
               SUM(CASE WHEN IsReturn = 0
                        THEN Quantity * UnitPrice ELSE 0 END)          AS GrossSalesAmount,
               SUM(CASE WHEN IsReturn = 0
                        THEN Quantity * UnitPrice - TotalAmount
                        ELSE 0 END)                                    AS DiscountAmount,
               SUM(CASE WHEN IsReturn = 0 THEN TotalAmount ELSE 0 END) AS SalesAmount,
               SUM(CASE WHEN IsReturn = 1 THEN -TotalAmount ELSE 0 END) AS ReturnAmount,
               SUM(TotalAmount)                                        AS NetAmount,
               COUNT(DISTINCT TransactionID)                           AS TransactionCount,
               COUNT(*)                                                AS LineCount,
               MIN(TransactionDateTime)                                AS FirstTransactionTime,
               MAX(TransactionDateTime)                                AS LastTransactionTime
        FROM src
        GROUP BY TransactionDate, CustomerID, ProductID
    )
    INSERT INTO dbo.Stg_Sales_Daily
    SELECT TransactionDate, CustomerID, ProductID,
           SalesQuantity, ReturnQuantity, NetQuantity,
           CAST(GrossSalesAmount AS DECIMAL(18,2)), CAST(DiscountAmount AS DECIMAL(18,2)),
           CAST(SalesAmount      AS DECIMAL(18,2)), CAST(ReturnAmount   AS DECIMAL(18,2)),
           CAST(NetAmount        AS DECIMAL(18,2)),
           TransactionCount, LineCount,
           CASE WHEN SalesQuantity > 0
                THEN CAST(GrossSalesAmount / SalesQuantity AS DECIMAL(18,2)) END,
           FirstTransactionTime, LastTransactionTime
    FROM agg;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        --------------------------------------------------------------
        -- D. Dim_Date
        --------------------------------------------------------------
        EXEC dbo.usp_Load_Dim_Date;
 
        --------------------------------------------------------------
        -- E. Dimension-ები: SCD Type 2 (წყარო: Master Data, არა Fact)
        --------------------------------------------------------------
        EXEC dbo.usp_Load_Dim_Customer @RunID, @LoadDate,
             @NewCustomers OUTPUT, @CustomerVersions OUTPUT;
        EXEC dbo.usp_Load_Dim_Product  @RunID, @LoadDate,
             @NewProducts  OUTPUT, @ProductVersions  OUTPUT;
 
        --------------------------------------------------------------
        -- F. Fact: დაზარალებული დღეების ჩანაცვლება + SCD2 point-in-time key
        --------------------------------------------------------------
        IF @LoadMode = 'FULL'
            DELETE FROM dbo.Fact_Sales_Daily;
        ELSE IF @LoadMode = 'INCREMENTAL'
            DELETE FROM dbo.Fact_Sales_Daily
            WHERE DateKey IN (SELECT CONVERT(INT, CONVERT(CHAR(8), TransactionDate, 112))
                              FROM dbo.Wrk_Gold_Dates);
 
        INSERT INTO dbo.Fact_Sales_Daily
            (DateKey, CustomerKey, ProductKey,
             SalesQuantity, ReturnQuantity, NetQuantity,
             GrossSalesAmount, DiscountAmount, SalesAmount, ReturnAmount, NetAmount,
             TransactionCount, LineCount, AvgUnitPrice,
             FirstTransactionTime, LastTransactionTime, RunID, LoadTime)
        SELECT CONVERT(INT, CONVERT(CHAR(8), s.TransactionDate, 112)),
               COALESCE(c.CustomerKey, -1),
               COALESCE(p.ProductKey,  -1),
               s.SalesQuantity, s.ReturnQuantity, s.NetQuantity,
               s.GrossSalesAmount, s.DiscountAmount, s.SalesAmount, s.ReturnAmount, s.NetAmount,
               s.TransactionCount, s.LineCount, s.AvgUnitPrice,
               s.FirstTransactionTime, s.LastTransactionTime, @RunID, GETDATE()
        FROM dbo.Stg_Sales_Daily s
        LEFT JOIN dbo.Dim_Customer c
               ON c.CustomerID = s.CustomerID
              AND s.TransactionDate BETWEEN c.ValidFrom AND c.ValidTo
        LEFT JOIN dbo.Dim_Product p
               ON p.ProductID = s.ProductID
              AND s.TransactionDate BETWEEN p.ValidFrom AND p.ValidTo;
        SET @FactRows = @@ROWCOUNT;
        --------------------------------------------------------------
        -- G. Watermark — იმავე ტრანზაქციაში
        --------------------------------------------------------------
        UPDATE dbo.Gold_Watermark
        SET   LastChangeLogTime = @To
            , UpdatedAt         = GETDATE()
        WHERE TableName = 'Gold_Star'
          AND LastChangeLogTime < @To;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
    ------------------------------------------------------------------
    -- H. ლოგი
    ------------------------------------------------------------------
    SET @Status = CASE WHEN @LoadMode = 'NONE'
                        AND @NewCustomers + @CustomerVersions
                          + @NewProducts  + @ProductVersions = 0
                       THEN 'NoData' ELSE 'Success' END;
    EXEC dbo.usp_Gold_LogSuccess @RunID, @LoadMode, @From, @To, @DatesAffected, @FactRows,
         @NewCustomers, @CustomerVersions, @NewProducts, @ProductVersions, @Status;
END

GO
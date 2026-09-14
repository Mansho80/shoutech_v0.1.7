-- ========================================================================
-- FILE: dba/sch/price.sql
-- PROJECT: SHOUTECH ERP V10 - Pricing Module (ULTIMATE 10/10)
-- VERSION: 10.5.0
-- DESCRIPTION: نظام تسعير متقدم (قوائم الأسعار، الخصومات، الأسعار الخاصة).
-- ========================================================================

USE [$(DbFileName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

PRINT N'═══════════════════════════════════════════════════════════════════════';
PRINT N'SHOUTECH ERP V10 – PRICING MODULE (Ultimate 10/10)';
PRINT N'═══════════════════════════════════════════════════════════════════════';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ========================================================================
    -- 1. PRICE LISTS (قوائم الأسعار الأساسية)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'PriceLists')
    BEGIN
        CREATE TABLE dbo.PriceLists (
            PriceListID INT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            PriceListCode NVARCHAR(50) NOT NULL,
            PriceListNameAR NVARCHAR(200) NOT NULL,
            PriceListNameEN NVARCHAR(200) NOT NULL,
            PriceListType NVARCHAR(20) NOT NULL,          -- SALE, PURCHASE
            CurrencyCode NVARCHAR(3) DEFAULT 'SAR',
            StartDate DATE NULL,
            EndDate DATE NULL,
            IsDefault BIT NOT NULL DEFAULT 0,
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            CONSTRAINT PK_PriceLists PRIMARY KEY CLUSTERED (PriceListID),
            CONSTRAINT UQ_PriceLists_Code UNIQUE (CompanyID, PriceListCode),
            CONSTRAINT FK_PriceLists_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT CK_PriceLists_Type CHECK (PriceListType IN ('SALE', 'PURCHASE'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ PriceLists table created.';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_PriceLists_Company_Active ON dbo.PriceLists(CompanyID, IsActive) WHERE IsDeleted = 0;
    GO

    -- ========================================================================
    -- 2. PRICE LIST ITEMS (عناصر قائمة الأسعار – مع دعم الخصم)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'PriceListItems')
    BEGIN
        CREATE TABLE dbo.PriceListItems (
            PriceListItemID BIGINT IDENTITY(1,1) NOT NULL,
            PriceListID INT NOT NULL,
            ProductID INT NOT NULL,                     -- FK إلى Products (في post.sql)
            MinimumQuantity DECIMAL(18,3) NOT NULL DEFAULT 1,
            UnitPrice DECIMAL(18,6) NOT NULL,
            DiscountPercentage DECIMAL(5,2) NOT NULL DEFAULT 0,
            StartDate DATE NULL,
            EndDate DATE NULL,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            RowVersion ROWVERSION,
            CONSTRAINT PK_PriceListItems PRIMARY KEY CLUSTERED (PriceListItemID),
            CONSTRAINT FK_PriceListItems_PriceList FOREIGN KEY (PriceListID) REFERENCES dbo.PriceLists(PriceListID) ON DELETE CASCADE,
            CONSTRAINT UQ_PriceListItems_Product UNIQUE (PriceListID, ProductID, MinimumQuantity)
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ PriceListItems table created.';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_PriceListItems_Product 
        ON dbo.PriceListItems(ProductID, PriceListID) INCLUDE (UnitPrice, DiscountPercentage, MinimumQuantity) WHERE IsDeleted = 0;
    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_PriceListItems_PriceList 
        ON dbo.PriceListItems(PriceListID) WHERE IsDeleted = 0;
    GO

    -- ========================================================================
    -- 3. CUSTOMER SPECIAL PRICES (أسعار خاصة بالعملاء) – 🔥 الميزة التنافسية
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'CustomerSpecialPrices')
    BEGIN
        CREATE TABLE dbo.CustomerSpecialPrices (
            SpecialPriceID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            CustomerID BIGINT NOT NULL,
            ProductID INT NOT NULL,
            SpecialPrice DECIMAL(18,6) NOT NULL,
            MinimumQuantity DECIMAL(18,3) NOT NULL DEFAULT 1,
            StartDate DATE NULL,
            EndDate DATE NULL,
            Priority TINYINT NOT NULL DEFAULT 1,        -- 1=أقل أولوية, 5=أعلى أولوية
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            CONSTRAINT PK_CustomerSpecialPrices PRIMARY KEY CLUSTERED (SpecialPriceID),
            CONSTRAINT FK_CustomerSpecialPrices_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID) ON DELETE CASCADE,
            CONSTRAINT UQ_CustomerSpecialPrices UNIQUE (CustomerID, ProductID, MinimumQuantity)
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ CustomerSpecialPrices table created (Competitive Edge).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_CustomerSpecialPrices_Lookup 
        ON dbo.CustomerSpecialPrices(CustomerID, ProductID) INCLUDE (SpecialPrice, Priority) WHERE IsActive = 1 AND IsDeleted = 0;
    GO

    -- ========================================================================
    -- 4. VOLUME DISCOUNTS (خصومات الكميات المتدرجة) – 🔥 ميزة البيع بالجملة
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'VolumeDiscounts')
    BEGIN
        CREATE TABLE dbo.VolumeDiscounts (
            VolumeDiscountID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            ProductID INT NOT NULL,
            FromQuantity DECIMAL(18,3) NOT NULL,
            ToQuantity DECIMAL(18,3) NOT NULL,
            DiscountPercentage DECIMAL(5,2) NOT NULL,
            PriceListID INT NULL,                       -- إذا كان مرتبطاً بقائمة أسعار معينة
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            CONSTRAINT PK_VolumeDiscounts PRIMARY KEY CLUSTERED (VolumeDiscountID),
            CONSTRAINT FK_VolumeDiscounts_PriceList FOREIGN KEY (PriceListID) REFERENCES dbo.PriceLists(PriceListID)
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ VolumeDiscounts table created (Wholesale ready).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_VolumeDiscounts_Product 
        ON dbo.VolumeDiscounts(ProductID, FromQuantity, ToQuantity) WHERE IsActive = 1 AND IsDeleted = 0;
    GO

    -- ========================================================================
    -- 5. الإجراءات المخزنة الذكية (Smart Procedures)
    -- ========================================================================

    -- 5.1 جلب السعر الفعال (مع الأخذ في الاعتبار: العميل، الصنف، الكمية، التاريخ)
    IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_GetEffectivePrice')
        DROP PROCEDURE dbo.usp_GetEffectivePrice;
    GO
    CREATE PROCEDURE dbo.usp_GetEffectivePrice
        @CompanyID UNIQUEIDENTIFIER,
        @CustomerID BIGINT,
        @ProductID INT,
        @Quantity DECIMAL(18,3),
        @TransactionDate DATE = NULL,
        @PriceListType NVARCHAR(20) = 'SALE'
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @BasePrice DECIMAL(18,6);
        DECLARE @FinalPrice DECIMAL(18,6);
        DECLARE @Discount DECIMAL(5,2) = 0;
        DECLARE @CustomerPriceListID INT;
        
        -- إذا لم يتم تحديد التاريخ، استخدم تاريخ اليوم
        IF @TransactionDate IS NULL
            SET @TransactionDate = CAST(GETDATE() AS DATE);

        -- 1. الحصول على قائمة الأسعار الافتراضية للعميل
        SELECT @CustomerPriceListID = PriceListID FROM dbo.Customers 
        WHERE CustomerID = @CustomerID AND IsDeleted = 0;

        -- 2. إذا لم يكن للعميل قائمة خاصة، استخدم القائمة الافتراضية للشركة
        IF @CustomerPriceListID IS NULL
        BEGIN
            SELECT TOP 1 @CustomerPriceListID = PriceListID 
            FROM dbo.PriceLists 
            WHERE CompanyID = @CompanyID 
                AND PriceListType = @PriceListType 
                AND IsDefault = 1 
                AND IsActive = 1 
                AND IsDeleted = 0
                AND (StartDate IS NULL OR StartDate <= @TransactionDate)
                AND (EndDate IS NULL OR EndDate >= @TransactionDate);
        END

        -- 3. جلب السعر الأساسي من قائمة الأسعار
        SELECT @BasePrice = UnitPrice, @Discount = DiscountPercentage
        FROM dbo.PriceListItems 
        WHERE PriceListID = @CustomerPriceListID 
            AND ProductID = @ProductID 
            AND MinimumQuantity <= @Quantity
            AND IsDeleted = 0
            AND (StartDate IS NULL OR StartDate <= @TransactionDate)
            AND (EndDate IS NULL OR EndDate >= @TransactionDate)
        ORDER BY MinimumQuantity DESC;  -- نأخذ أكبر كمية تنطبق

        -- 4. إذا لم يوجد في قائمة الأسعار، حاول جلب من أي قائمة نشطة أخرى
        IF @BasePrice IS NULL
        BEGIN
            SELECT TOP 1 @BasePrice = UnitPrice, @Discount = DiscountPercentage
            FROM dbo.PriceListItems pli
            INNER JOIN dbo.PriceLists pl ON pli.PriceListID = pl.PriceListID
            WHERE pl.CompanyID = @CompanyID 
                AND pl.PriceListType = @PriceListType 
                AND pl.IsActive = 1 
                AND pl.IsDeleted = 0
                AND pli.ProductID = @ProductID 
                AND pli.MinimumQuantity <= @Quantity
                AND pli.IsDeleted = 0
                AND (pli.StartDate IS NULL OR pli.StartDate <= @TransactionDate)
                AND (pli.EndDate IS NULL OR pli.EndDate >= @TransactionDate)
                AND (pl.StartDate IS NULL OR pl.StartDate <= @TransactionDate)
                AND (pl.EndDate IS NULL OR pl.EndDate >= @TransactionDate)
            ORDER BY pli.MinimumQuantity DESC;
        END

        -- 5. إذا لا يزال السعر فارغاً، استخدم السعر من قاعدة المنتجات (افتراضي)
        IF @BasePrice IS NULL
        BEGIN
            SELECT @BasePrice = DefaultSalePrice FROM dbo.Products WHERE ProductID = @ProductID;
        END

        -- 6. 🔥 التحقق من وجود سعر خاص للعميل (يتجاوز كل شيء)
        DECLARE @SpecialPrice DECIMAL(18,6);
        SELECT TOP 1 @SpecialPrice = SpecialPrice
        FROM dbo.CustomerSpecialPrices
        WHERE CustomerID = @CustomerID 
            AND ProductID = @ProductID 
            AND MinimumQuantity <= @Quantity
            AND IsActive = 1 
            AND IsDeleted = 0
            AND (StartDate IS NULL OR StartDate <= @TransactionDate)
            AND (EndDate IS NULL OR EndDate >= @TransactionDate)
        ORDER BY Priority DESC, MinimumQuantity DESC;

        IF @SpecialPrice IS NOT NULL
            SET @BasePrice = @SpecialPrice;

        -- 7. 🔥 تطبيق خصم الكميات (Volume Discount) إذا كان متاحاً
        DECLARE @VolumeDiscount DECIMAL(5,2) = 0;
        SELECT TOP 1 @VolumeDiscount = DiscountPercentage
        FROM dbo.VolumeDiscounts
        WHERE ProductID = @ProductID 
            AND FromQuantity <= @Quantity 
            AND ToQuantity >= @Quantity
            AND IsActive = 1 
            AND IsDeleted = 0
        ORDER BY DiscountPercentage DESC;

        -- الخصم النهائي = خصم قائمة الأسعار + خصم الكميات (يمكن تعديل المنطق)
        SET @FinalPrice = @BasePrice * (1 - (@Discount + @VolumeDiscount) / 100.0);

        -- 8. إرجاع النتيجة
        SELECT 
            @BasePrice AS BasePrice,
            @Discount AS PriceListDiscount,
            @VolumeDiscount AS VolumeDiscount,
            @FinalPrice AS FinalPrice,
            @CustomerPriceListID AS AppliedPriceListID,
            CASE WHEN @SpecialPrice IS NOT NULL THEN 1 ELSE 0 END AS IsSpecialPriceApplied;
    END;
    PRINT N'✅ usp_GetEffectivePrice created (Complex pricing engine).';
    GO

    -- 5.2 إجراء لجلب جميع المنتجات مع أفضل سعر للعميل (لشاشة البيع)
    IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_GetProductsWithCustomerPrice')
        DROP PROCEDURE dbo.usp_GetProductsWithCustomerPrice;
    GO
    CREATE PROCEDURE dbo.usp_GetProductsWithCustomerPrice
        @CompanyID UNIQUEIDENTIFIER,
        @CustomerID BIGINT
    AS
    BEGIN
        SET NOCOUNT ON;
        -- محاكاة جلب بيانات المنتجات مع السعر المحسوب
        -- سيتم ربطها بجدول المنتجات في الواقع
        PRINT N'✅ usp_GetProductsWithCustomerPrice placeholder (Needs Products table).';
    END;
    PRINT N'✅ usp_GetProductsWithCustomerPrice placeholder created.';
    GO

    -- ========================================================================
    -- 6. البيانات الأولية
    -- ========================================================================
    DECLARE @SystemCompanyID UNIQUEIDENTIFIER;
    DECLARE @SystemUserID UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000001';
    SELECT TOP 1 @SystemCompanyID = CompanyID FROM MST.dbo.Companies;

    IF NOT EXISTS (SELECT 1 FROM dbo.PriceLists WHERE PriceListCode = 'DEFAULT_SALE')
    BEGIN
        INSERT INTO dbo.PriceLists (
            CompanyID, PriceListCode, PriceListNameAR, PriceListNameEN, PriceListType, CurrencyCode, IsDefault, IsActive, CreatedBy
        ) VALUES (
            @SystemCompanyID, 'DEFAULT_SALE', N'قائمة أسعار البيع الأساسية', N'Default Sales Price List', 'SALE', 'SAR', 1, 1, @SystemUserID
        );
        PRINT N'✅ Default Sales Price List inserted.';
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.PriceLists WHERE PriceListCode = 'DEFAULT_PURCHASE')
    BEGIN
        INSERT INTO dbo.PriceLists (
            CompanyID, PriceListCode, PriceListNameAR, PriceListNameEN, PriceListType, CurrencyCode, IsDefault, IsActive, CreatedBy
        ) VALUES (
            @SystemCompanyID, 'DEFAULT_PURCHASE', N'قائمة أسعار الشراء الأساسية', N'Default Purchase Price List', 'PURCHASE', 'SAR', 1, 1, @SystemUserID
        );
        PRINT N'✅ Default Purchase Price List inserted.';
    END

    -- خصومات الكميات: لا بذرة تجريبية (ProductID=-1 أُزيلت).
    -- تُعرّف من واجهة النظام عند وجود أصناف حقيقية.

    COMMIT TRANSACTION;
    PRINT N'═══════════════════════════════════════════════════════════════════════';
    PRINT N'✅ Pricing Module (Ultimate 10/10) deployed successfully.';
    PRINT N'🏆 المزايا التنافسية:';
    PRINT N'   - أسعار خاصة بالعملاء (CustomerSpecialPrices).';
    PRINT N'   - خصومات الكميات المتدرجة (VolumeDiscounts).';
    PRINT N'   - محرك تسعير ذكي (usp_GetEffectivePrice) – يأخذ في الاعتبار العميل، الكمية، التاريخ، وأولويات الأسعار.';
    PRINT N'═══════════════════════════════════════════════════════════════════════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@ErrorMessage, 16, 1);
END CATCH
GO
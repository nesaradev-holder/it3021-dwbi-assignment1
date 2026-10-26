USE BankingDW;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
CREATE OR ALTER PROCEDURE etl.PrepareCore
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE stg.Branch;
    TRUNCATE TABLE stg.Customer;
    TRUNCATE TABLE stg.Account;
    TRUNCATE TABLE stg.Deposit;
    TRUNCATE TABLE stg.CustomerChange;
END;
GO
CREATE OR ALTER PROCEDURE etl.PrepareCompletion
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE stg.Completion;
END;
GO
CREATE OR ALTER PROCEDURE etl.LoadWarehouse
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET ARITHABORT ON;
    SET ANSI_WARNINGS ON;
    SET NUMERIC_ROUNDABORT OFF;
    INSERT etl.Run(package_name,status) VALUES(N'BankingWarehouse','Running');
    DECLARE @run BIGINT=SCOPE_IDENTITY(), @inserted INT=0, @updated INT=0;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM stg.Deposit)
            THROW 51020,'No staged deposits; refusing an empty source load.',1;
        IF EXISTS(SELECT transaction_id FROM stg.Deposit GROUP BY transaction_id HAVING COUNT(*)>1)
            THROW 51021,'Duplicate staged deposit IDs; warehouse transaction rolled back.',1;
        IF EXISTS(SELECT account_id FROM stg.Account GROUP BY account_id HAVING COUNT(*)>1)
            THROW 51022,'Duplicate staged account IDs; warehouse transaction rolled back.',1;
        IF EXISTS(SELECT customer_id FROM stg.Customer GROUP BY customer_id HAVING COUNT(*)>1)
            THROW 51023,'Duplicate staged customer IDs; warehouse transaction rolled back.',1;
        IF EXISTS(SELECT branch_id FROM stg.Branch GROUP BY branch_id HAVING COUNT(*)>1)
            THROW 51024,'Duplicate staged branch IDs; warehouse transaction rolled back.',1;

        ;WITH calendar AS (
            SELECT CONVERT(DATE,'20260101') AS FullDate
            UNION ALL SELECT DATEADD(DAY,1,FullDate) FROM calendar WHERE FullDate<'20261231'
        )
        INSERT dbo.DimDate(DateKey,FullDate,CalendarYear,CalendarQuarter,MonthNumber,YearMonth,DayOfMonth)
        SELECT YEAR(FullDate)*10000+MONTH(FullDate)*100+DAY(FullDate), FullDate,
               YEAR(FullDate),DATEPART(QUARTER,FullDate),MONTH(FullDate),CONVERT(CHAR(7),FullDate,126),DAY(FullDate)
        FROM calendar WHERE NOT EXISTS(SELECT 1 FROM dbo.DimDate d WHERE d.FullDate=calendar.FullDate)
        OPTION(MAXRECURSION 0);

        UPDATE d SET BranchName=s.branch_name,City=s.city
        FROM dbo.DimBranch d JOIN stg.Branch s ON s.branch_id=d.BranchID
        WHERE d.BranchName<>s.branch_name OR d.City<>s.city;
        INSERT dbo.DimBranch(BranchID,BranchName,City)
        SELECT s.branch_id,s.branch_name,s.city FROM stg.Branch s
        WHERE NOT EXISTS(SELECT 1 FROM dbo.DimBranch d WHERE d.BranchID=s.branch_id);

        UPDATE d SET CustomerID=s.customer_id,HomeBranchID=s.branch_id
        FROM dbo.DimAccount d JOIN stg.Account s ON s.account_id=d.AccountID
        WHERE d.CustomerID<>s.customer_id OR d.HomeBranchID<>s.branch_id;
        INSERT dbo.DimAccount(AccountID,CustomerID,HomeBranchID)
        SELECT s.account_id,s.customer_id,s.branch_id FROM stg.Account s
        WHERE NOT EXISTS(SELECT 1 FROM dbo.DimAccount d WHERE d.AccountID=s.account_id);

        INSERT dbo.DimCustomer(CustomerID,CustomerName,City,ValidFrom,ValidTo,IsCurrent)
        SELECT s.customer_id,s.customer_name,s.city,'20260101',NULL,1 FROM stg.Customer s
        WHERE NOT EXISTS(SELECT 1 FROM dbo.DimCustomer d WHERE d.CustomerID=s.customer_id);

        SELECT customer_id,city,TRY_CONVERT(DATE,effective_from,23) AS change_date,
               CASE
                 WHEN customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM stg.Customer c WHERE c.customer_id=h.customer_id)
                   THEN N'Unknown customer ID'
                 WHEN NULLIF(LTRIM(RTRIM(city)),N'') IS NULL OR LEN(city)>100
                   THEN N'Invalid city text'
                 WHEN TRY_CONVERT(DATE,effective_from,23) IS NULL
                   OR TRY_CONVERT(DATE,effective_from,23)<'20260101'
                   OR TRY_CONVERT(DATE,effective_from,23)>'20261231'
                   THEN N'Invalid history effective date'
                 WHEN COUNT(*) OVER(PARTITION BY customer_id,effective_from)>1
                   THEN N'Duplicate customer/effective-date history rows'
               END AS rejection
        INTO #History FROM stg.CustomerChange h;
        INSERT etl.Reject(run_id,feed,business_key,reason)
        SELECT @run,N'CustomerHistory',customer_id,rejection FROM #History WHERE rejection IS NOT NULL;

        DECLARE @customer VARCHAR(10),@city NVARCHAR(100),@effective DATE,
                @oldKey INT,@oldTo DATE,@name NVARCHAR(100);
        DECLARE changes CURSOR LOCAL FAST_FORWARD FOR
            SELECT customer_id,city,change_date FROM #History WHERE rejection IS NULL ORDER BY customer_id,change_date;
        OPEN changes;
        FETCH NEXT FROM changes INTO @customer,@city,@effective;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF EXISTS(SELECT 1 FROM dbo.DimCustomer WHERE CustomerID=@customer AND ValidFrom=@effective)
            BEGIN
                IF NOT EXISTS(SELECT 1 FROM dbo.DimCustomer WHERE CustomerID=@customer AND ValidFrom=@effective AND City=@city)
                    INSERT etl.Reject(run_id,feed,business_key,reason)
                    VALUES(@run,N'CustomerHistory',@customer,N'Conflicting existing history version');
            END
            ELSE
            BEGIN
                SET @oldKey=NULL;
                SELECT @oldKey=CustomerKey,@oldTo=ValidTo,@name=CustomerName
                FROM dbo.DimCustomer WHERE CustomerID=@customer AND ValidFrom<@effective
                    AND (ValidTo IS NULL OR ValidTo>@effective);
                IF @oldKey IS NULL
                    INSERT etl.Reject(run_id,feed,business_key,reason)
                    VALUES(@run,N'CustomerHistory',@customer,N'No matching history interval');
                ELSE
                BEGIN
                    UPDATE dbo.DimCustomer SET ValidTo=@effective,IsCurrent=0 WHERE CustomerKey=@oldKey;
                    INSERT dbo.DimCustomer(CustomerID,CustomerName,City,ValidFrom,ValidTo,IsCurrent)
                    VALUES(@customer,@name,@city,@effective,@oldTo,CASE WHEN @oldTo IS NULL THEN 1 ELSE 0 END);
                END;
            END;
            FETCH NEXT FROM changes INTO @customer,@city,@effective;
        END;
        CLOSE changes;
        DEALLOCATE changes;

        IF EXISTS(
            SELECT 1 FROM dbo.DimCustomer a JOIN dbo.DimCustomer b
                ON a.CustomerID=b.CustomerID AND a.CustomerKey<b.CustomerKey
                AND a.ValidFrom<ISNULL(b.ValidTo,'99991231') AND b.ValidFrom<ISNULL(a.ValidTo,'99991231')
        ) THROW 51025,'Overlapping Customer history intervals; warehouse transaction rolled back.',1;

        SELECT s.transaction_id,s.transaction_date,s.amount,d.DateKey,b.BranchKey,a.AccountKey,c.CustomerKey
        INTO #Resolved
        FROM stg.Deposit s
        LEFT JOIN stg.Account source_account ON source_account.account_id=s.account_id
        LEFT JOIN dbo.DimDate d ON d.FullDate=s.transaction_date
        LEFT JOIN dbo.DimBranch b ON b.BranchID=s.transaction_branch_id
        LEFT JOIN dbo.DimAccount a ON a.AccountID=s.account_id
        LEFT JOIN dbo.DimCustomer c ON c.CustomerID=source_account.customer_id
            AND s.transaction_date>=c.ValidFrom AND (c.ValidTo IS NULL OR s.transaction_date<c.ValidTo);
        INSERT etl.Reject(run_id,feed,business_key,reason)
        SELECT @run,N'Deposit',transaction_id,
            CASE WHEN amount IS NULL OR amount<=0 THEN N'Invalid deposit amount'
                 WHEN DateKey IS NULL THEN N'Date lookup failed'
                 WHEN BranchKey IS NULL THEN N'Handling branch lookup failed'
                 WHEN AccountKey IS NULL THEN N'Account lookup failed'
                 ELSE N'Customer history lookup failed' END
        FROM #Resolved WHERE amount IS NULL OR amount<=0 OR DateKey IS NULL OR BranchKey IS NULL
            OR AccountKey IS NULL OR CustomerKey IS NULL;
        DELETE FROM #Resolved WHERE amount IS NULL OR amount<=0 OR DateKey IS NULL OR BranchKey IS NULL
            OR AccountKey IS NULL OR CustomerKey IS NULL;

        UPDATE f SET DateKey=r.DateKey,BranchKey=r.BranchKey,AccountKey=r.AccountKey,
                     CustomerKey=r.CustomerKey,Amount=r.amount
        FROM dbo.FactDeposit f JOIN #Resolved r ON r.transaction_id=f.TransactionID
        WHERE f.DateKey<>r.DateKey OR f.BranchKey<>r.BranchKey OR f.AccountKey<>r.AccountKey
            OR f.CustomerKey<>r.CustomerKey OR f.Amount<>r.amount;
        SET @updated=@@ROWCOUNT;
        DECLARE @created DATETIME2(7)=SYSDATETIME();
        INSERT dbo.FactDeposit(TransactionID,DateKey,BranchKey,CustomerKey,AccountKey,Amount,DepositCount,accm_txn_create_time)
        SELECT r.transaction_id,r.DateKey,r.BranchKey,r.CustomerKey,r.AccountKey,r.amount,1,@created
        FROM #Resolved r WHERE NOT EXISTS(SELECT 1 FROM dbo.FactDeposit f WHERE f.TransactionID=r.transaction_id);
        SET @inserted=@@ROWCOUNT;
        UPDATE etl.Run SET completed_at=SYSDATETIME(),facts_inserted=@inserted,facts_updated=@updated,
            rejected_rows=(SELECT COUNT(*) FROM etl.Reject WHERE run_id=@run),
            status=CASE WHEN EXISTS(SELECT 1 FROM etl.Reject WHERE run_id=@run) THEN 'CompletedWithRejects' ELSE 'Completed' END
        WHERE run_id=@run;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        UPDATE etl.Run SET completed_at=SYSDATETIME(),status='Failed',error_message=ERROR_MESSAGE() WHERE run_id=@run;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE etl.ApplyCompletions
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET ARITHABORT ON;
    SET ANSI_WARNINGS ON;
    SET NUMERIC_ROUNDABORT OFF;
    INSERT etl.Run(package_name,status) VALUES(N'CompletionUpdates','Running');
    DECLARE @run BIGINT=SCOPE_IDENTITY(),@updated INT=0;
    BEGIN TRY
        BEGIN TRANSACTION;
        ;WITH parsed AS (
            SELECT transaction_id,TRY_CONVERT(DATETIME2(7),complete_time,126) AS completed,
                   COUNT(*) OVER(PARTITION BY transaction_id) AS copies FROM stg.Completion
        )
        SELECT p.*,f.DepositKey,
               CASE WHEN p.copies>1 THEN N'Duplicate completion transaction ID'
                    WHEN f.DepositKey IS NULL THEN N'Unknown transaction ID'
                    WHEN p.completed IS NULL THEN N'Invalid completion timestamp'
                    WHEN p.completed<f.accm_txn_create_time THEN N'Completion precedes create time'
                    WHEN f.accm_txn_complete_time IS NOT NULL AND f.accm_txn_complete_time<>p.completed
                      THEN N'Conflicting existing completion timestamp' END AS rejection
        INTO #Completion FROM parsed p LEFT JOIN dbo.FactDeposit f ON f.TransactionID=p.transaction_id;
        INSERT etl.Reject(run_id,feed,business_key,reason)
        SELECT @run,N'Completion',transaction_id,rejection FROM #Completion WHERE rejection IS NOT NULL;
        UPDATE f SET accm_txn_complete_time=c.completed,
            txn_process_time_hours=CONVERT(DECIMAL(18,6),DATEDIFF_BIG(MICROSECOND,f.accm_txn_create_time,c.completed)/3600000000.0)
        FROM dbo.FactDeposit f JOIN #Completion c ON c.DepositKey=f.DepositKey
        WHERE c.rejection IS NULL AND f.accm_txn_complete_time IS NULL;
        SET @updated=@@ROWCOUNT;
        UPDATE etl.Run SET completed_at=SYSDATETIME(),facts_updated=@updated,
            rejected_rows=(SELECT COUNT(*) FROM etl.Reject WHERE run_id=@run),
            status=CASE WHEN EXISTS(SELECT 1 FROM etl.Reject WHERE run_id=@run) THEN 'CompletedWithRejects' ELSE 'Completed' END
        WHERE run_id=@run;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        UPDATE etl.Run SET completed_at=SYSDATETIME(),status='Failed',error_message=ERROR_MESSAGE() WHERE run_id=@run;
        THROW;
    END CATCH;
END;
GO

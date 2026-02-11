USE Bank;
GO

-- 1. Stergerea obiectelor existente

-- Stergem mai intai obiectele dependente
DROP TRIGGER IF EXISTS dbo.tr_Transaction;
GO

DROP PROCEDURE IF EXISTS dbo.p_Withdraw;
DROP PROCEDURE IF EXISTS dbo.p_Deposit;
DROP PROCEDURE IF EXISTS dbo.p_AddAccount;
GO

DROP FUNCTION IF EXISTS dbo.f_CalculateTotalBalance;
GO

DROP VIEW IF EXISTS dbo.v_ClientAccounts;
GO

-- Stergem tabelele copil (cele care au chei straine)
DROP TABLE IF EXISTS dbo.Transactions;
DROP TABLE IF EXISTS dbo.Accounts;
GO

-- Stergem tabelele parinte (referite prin chei straine)
DROP TABLE IF EXISTS dbo.AccountTypes;
DROP TABLE IF EXISTS dbo.Clients;
GO

-- 2. Recrearea tuturor obiectelor

-- Creare tabel Clients
CREATE TABLE dbo.Clients (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL
);
GO

-- Creare tabel AccountTypes
DROP TABLE IF EXISTS dbo.AccountTypes;
GO
CREATE TABLE dbo.AccountTypes (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(50) NOT NULL
);
GO

-- Creare tabel Accounts
CREATE TABLE dbo.Accounts (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AccountTypeId INT NOT NULL,
    Balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    ClientId INT NOT NULL,
    CONSTRAINT FK_Accounts_AccountTypes FOREIGN KEY (AccountTypeId) 
        REFERENCES dbo.AccountTypes(Id),
    CONSTRAINT FK_Accounts_Clients FOREIGN KEY (ClientId) 
        REFERENCES dbo.Clients(Id)
);
GO

-- Creare tabel Transactions
CREATE TABLE dbo.Transactions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AccountId INT NOT NULL,
    OldBalance DECIMAL(15,2) NOT NULL,
    NewBalance DECIMAL(15,2) NOT NULL,
    Amount AS (NewBalance - OldBalance),
    [DateTime] DATETIME2 NOT NULL,
    CONSTRAINT FK_Transactions_Accounts FOREIGN KEY (AccountId) 
        REFERENCES dbo.Accounts(Id)
);
GO

-- 3. Inserare date initiale

-- Inserare clienti
INSERT INTO dbo.Clients (FirstName, LastName) 
VALUES 
    ('Gosho', 'Ivanov'),
    ('Pesho', 'Petrov'),
    ('Ivan', 'Iliev'),
    ('Merry', 'Ivanova');
GO

-- Inserare tipuri de cont
INSERT INTO dbo.AccountTypes (Name) 
VALUES 
    ('Checking'),
    ('Savings');
GO

-- Inserare conturi
INSERT INTO dbo.Accounts (AccountTypeId, ClientId, Balance) 
VALUES 
    (1, 1, 175.00),
    (2, 1, 275.56),
    (1, 2, 138.01),
    (1, 3, 40.30);
GO

-- Verificare date introduse
SELECT * FROM dbo.Clients;
SELECT * FROM dbo.AccountTypes;
SELECT * FROM dbo.Accounts;
GO

-- 4. Creare view

CREATE VIEW dbo.v_ClientAccounts AS
SELECT 
    CONCAT(c.FirstName, ' ', c.LastName) AS [Name],
    at.Name AS [Account Type],
    a.Balance
FROM dbo.Clients c
JOIN dbo.Accounts a ON c.Id = a.ClientId
JOIN dbo.AccountTypes at ON a.AccountTypeId = at.Id;
GO

-- Testare view
SELECT * FROM dbo.v_ClientAccounts;
GO

-- 5. Creare functie

CREATE FUNCTION dbo.f_CalculateTotalBalance(@ClientID INT)
RETURNS DECIMAL(15,2)
AS
BEGIN
    DECLARE @TotalBalance DECIMAL(15,2);
    
    SELECT @TotalBalance = SUM(Balance)
    FROM dbo.Accounts
    WHERE ClientId = @ClientID;
    
    -- Daca nu exista conturi, returnam 0
    IF @TotalBalance IS NULL
        SET @TotalBalance = 0;
    
    RETURN @TotalBalance;
END;
GO

-- Testare functie
SELECT dbo.f_CalculateTotalBalance(1) AS Balance;
SELECT dbo.f_CalculateTotalBalance(4) AS Balance;
GO

-- 6. Creare proceduri

-- Procedura pentru adaugare cont nou
CREATE PROCEDURE dbo.p_AddAccount
    @ClientID INT,
    @AccountTypeID INT
AS
BEGIN
    INSERT INTO dbo.Accounts (ClientId, AccountTypeId, Balance)
    VALUES (@ClientID, @AccountTypeID, 0);
    
    PRINT 'Account created successfully!';
END;
GO

-- Testare procedura
EXEC dbo.p_AddAccount 2, 2;
GO

SELECT * FROM dbo.Accounts;
GO

-- Procedura pentru depunere bani
CREATE PROCEDURE dbo.p_Deposit
    @AccountID INT,
    @Amount DECIMAL(15,2)
AS
BEGIN
    IF @Amount <= 0
    BEGIN
        PRINT 'Deposit amount must be positive!';
        RETURN;
    END
    
    UPDATE dbo.Accounts
    SET Balance = Balance + @Amount
    WHERE Id = @AccountID;
    
    PRINT 'Deposit successful!';
END;
GO

-- Procedura pentru retragere bani
CREATE PROCEDURE dbo.p_Withdraw
    @AccountID INT,
    @Amount DECIMAL(15,2)
AS
BEGIN
    DECLARE @CurrentBalance DECIMAL(15,2);
    
    IF @Amount <= 0
    BEGIN
        PRINT 'Withdrawal amount must be positive!';
        RETURN;
    END
    
    -- Preluam soldul curent
    SELECT @CurrentBalance = Balance
    FROM dbo.Accounts
    WHERE Id = @AccountID;
    
    -- Verificam daca exista fonduri suficiente
    IF @CurrentBalance >= @Amount
    BEGIN
        UPDATE dbo.Accounts
        SET Balance = Balance - @Amount
        WHERE Id = @AccountID;
        
        PRINT 'Withdrawal successful!';
    END
    ELSE
    BEGIN
        PRINT 'Insufficient funds!';
    END
END;
GO

-- 7. Creare trigger

-- Trigger pentru inregistrarea tranzactiilor
CREATE TRIGGER tr_Transaction ON dbo.Accounts
AFTER UPDATE
AS
BEGIN
    INSERT INTO dbo.Transactions (AccountId, OldBalance, NewBalance, [DateTime])
    SELECT 
        inserted.Id,
        deleted.Balance,
        inserted.Balance,
        GETDATE()
    FROM inserted
    JOIN deleted ON inserted.Id = deleted.Id
    WHERE inserted.Balance <> deleted.Balance;
END;
GO

-- Testare tranzactii

EXEC dbo.p_Deposit 1, 25.00;
GO

EXEC dbo.p_Deposit 1, 40.00;
GO

EXEC dbo.p_Withdraw 2, 200.00;
GO

EXEC dbo.p_Deposit 4, 180.00;
GO

-- Afisare tranzactii
SELECT * FROM dbo.Transactions;
GO

-- Interogari suplimentare utile

-- Afisare conturi impreuna cu datele clientilor
SELECT 
    c.FirstName + ' ' + c.LastName AS ClientName,
    at.Name AS AccountType,
    a.Balance,
    a.Id AS AccountId
FROM dbo.Accounts a
JOIN dbo.Clients c ON a.ClientId = c.Id
JOIN dbo.AccountTypes at ON a.AccountTypeId = at.Id
ORDER BY c.LastName, c.FirstName;
GO

-- Afisare sold total pentru fiecare client
SELECT 
    c.FirstName + ' ' + c.LastName AS ClientName,
    dbo.f_CalculateTotalBalance(c.Id) AS TotalBalance
FROM dbo.Clients c
ORDER BY TotalBalance DESC;
GO

-- Istoric tranzactii cu detalii
SELECT 
    t.Id AS TransactionId,
    c.FirstName + ' ' + c.LastName AS ClientName,
    at.Name AS AccountType,
    t.OldBalance,
    t.NewBalance,
    t.Amount,
    CASE 
        WHEN t.Amount > 0 THEN 'Deposit'
        ELSE 'Withdrawal'
    END AS TransactionType,
    t.[DateTime]
FROM dbo.Transactions t
JOIN dbo.Accounts a ON t.AccountId = a.Id
JOIN dbo.Clients c ON a.ClientId = c.Id
JOIN dbo.AccountTypes at ON a.AccountTypeId = at.Id
ORDER BY t.[DateTime] DESC;
GO

PRINT 'Bank Database Lab Completed Successfully!';

SET NOCOUNT ON;
GO
CREATE DATABASE migration
ON
PRIMARY ( NAME = migration_data,
    FILENAME = 'C:\App\Microsoft SQL Server\Data14\migration_data.mdf'),
-- Dodanie grupy FILESTREAM
FILEGROUP FileStreamGroup1 CONTAINS FILESTREAM( NAME = migration_filestream1,
    FILENAME = 'C:\App\Microsoft SQL Server\Data14\filestream1')
LOG ON  ( NAME = migration_log,
    FILENAME = 'C:\App\Microsoft SQL Server\Data14\migration_log.ldf')
GO
GO
USE migration
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'lHFjW7t2hLcGm0LOGIWR';
GO
CREATE SCHEMA sql
GO
/*
  Table z typami danych dostêpnymi w SQL Server 2008
*/
DROP TABLE IF EXISTS sql.DataType;
CREATE TABLE sql.DataType
([Bigint]           BIGINT, 
 [Int]              INT, 
 [Smallint]         SMALLINT, 
 [Tinyint]          TINYINT, 
 [Bit]              BIT, 
 [Decimal]          DECIMAL, 
 [Numeric]          NUMERIC, 
 [Money]            MONEY, 
 [Smallmoney]       SMALLMONEY, 
 [Float]            FLOAT, 
 [Real]             REAL, 
 [Datetime]         DATETIME, 
 [Smalldatetime]    SMALLDATETIME, 
 [Date]             DATE, 
 [Time]             TIME, 
 [Datetime2]        DATETIME2, 
 [Datetimeoffset]   DATETIMEOFFSET, 
 [Char]             CHAR(100), 
 [Varchar]          VARCHAR(100), 
 [Varchar(max)]     VARCHAR(100), 
 [Text]             TEXT, 
 [Nchar]            NCHAR(100), 
 [Nvarchar]         NVARCHAR(100), 
 [Nvarchar(max)]    NVARCHAR(MAX), 
 [Ntext]            NTEXT, 
 [Binary]           BINARY, 
 [Varbinary]        VARBINARY(100), 
 [Varbinary(max)]   VARBINARY(MAX), 
 [Image]            IMAGE, 
 [Sql_variant]      SQL_VARIANT, 
 [Timestamp]        TIMESTAMP, 
 [Uniqueidentifier] UNIQUEIDENTIFIER, 
 [Xml]              XML
);

/*
  Cell Level Encryption
*/

-- Stworzenie klucza asymetrycznego
CREATE ASYMMETRIC KEY AsymmetricCellLevelKey WITH ALGORITHM = RSA_2048;
GO
SELECT *
FROM sys.asymmetric_keys
WHERE NAME = 'AsymmetricCellLevelKey';
GO

-- Klucz symetryczny 
CREATE SYMMETRIC KEY SymmetricKey WITH ALGORITHM = AES_256 ENCRYPTION BY ASYMMETRIC KEY AsymmetricCellLevelKey;
GO

-- Utworzenie tabeli
DROP TABLE IF EXISTS sql.Cell_Level_Encryption
CREATE TABLE sql.Cell_Level_Encryption
(id        INT
 PRIMARY KEY IDENTITY, 
 sensitive VARBINARY(MAX)
);
GO

-- Otwarcie klucza symetrycznego
OPEN SYMMETRIC KEY SymmetricKey DECRYPTION BY ASYMMETRIC KEY AsymmetricCellLevelKey;
GO
SELECT database_name, 
       key_name, 
       status
FROM sys.openkeys;
GO

-- Wstawienie testowych danych
INSERT INTO sql.Cell_Level_Encryption
VALUES(ENCRYPTBYKEY(KEY_GUID('SymmetricKey'), 'przykadlowe dane wrazliwe'));
GO 5
INSERT INTO sql.Cell_Level_Encryption
VALUES(CAST('dane nie wra¿liwe' AS VARBINARY(MAX))); 
GO 5

SELECT ID, 
       Sensitive AS VarbinaryType,
       CASE
           WHEN(CAST(DECRYPTBYKEY([sensitive]) AS VARCHAR(MAX))) IS NULL
           THEN(CAST([sensitive] AS VARCHAR(MAX)))
           ELSE(CAST(DECRYPTBYKEY([sensitive]) AS VARCHAR(MAX)))
       END AS Sensitive
FROM sql.Cell_Level_Encryption;
GO

--Zamkniêcie klucza
CLOSE SYMMETRIC KEY SymmetricKey;
GO

/*
  Dynamic Data Masking
*/

DROP TABLE IF EXISTS sql.Dynamic_Data_Masking;
CREATE TABLE sql.Dynamic_Data_Masking
(
  FirstName  NVARCHAR(100) MASKED WITH(FUNCTION = 'partial(1,"*****",1)'),
  LastName   NVARCHAR(100) MASKED WITH(FUNCTION = 'default()'),
  Email      NVARCHAR(100) MASKED WITH(FUNCTION = 'email()'),
  DateTime   DATETIME  MASKED WITH(FUNCTION = 'default()'),
  PESEL      BIGINT MASKED WITH(FUNCTION = 'default()'),
  CreditCard BIGINT MASKED WITH(FUNCTION = 'random(1000,9999)'),
  Phone      INT MASKED WITH(FUNCTION = 'default()'),
  Addresss   NVARCHAR(200) MASKED WITH(FUNCTION = 'partial(2,"_____",2)'),
  Photo      VARBINARY(MAX) MASKED WITH(FUNCTION = 'default()'));
 
INSERT INTO sql.Dynamic_Data_Masking
VALUES
(
  'Wojciech', 'Wojciechowski', 'some_mail@gmail.com', '2017-11-11', 55062317115, 2201220100201233, '899119553', 'Czysta 22',
(
  SELECT BulkColumn
  FROM OPENROWSET( BULK N'C:\Photo\photo.jpg', SINGLE_BLOB )
  AS Photo
));
 
INSERT INTO sql.Dynamic_Data_Masking
VALUES
(
  'Adam', 'Adam', 'adam_adam@gmail.com', '2017-11-20', 57062317115, 2205280100601242, '899119988', 'B³otna 88A',
(
  SELECT BulkColumn
  FROM OPENROWSET( BULK N'C:\Photo\photo.jpg', SINGLE_BLOB )
  AS Photo
));
GO

SELECT * FROM sql.Dynamic_Data_Masking
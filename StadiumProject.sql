CREATE DATABASE Stadium_DB
USE Stadium_DB

CREATE TABLE [tblCustomer] (
	[CustUserName] VARCHAR(20) NOT NULL,
	[FName] VARCHAR(20) NOT NULL,
	[LName] VARCHAR(20) NOT NULL,
	[Address] VARCHAR(20) NOT NULL,
	[PhoneNo] VARCHAR(20) NOT NULL,
	[Balance] MONEY NOT NULL CHECK ([Balance] >= 0) DEFAULT 0,
	PRIMARY KEY ([CustUserName])
);

CREATE TABLE [tblEvent] (
	[eventID] INT NOT NULL IDENTITY,
	[Title] VARCHAR(20) NOT NULL,
	[DateTime] DATETIME NOT NULL CHECK (DATEDIFF(DD, GETDATE(), [DateTime]) > 0 ),
	PRIMARY KEY ([eventID])
);

CREATE TABLE [tblSeat] (
	[Group] INT NOT NULL CHECK([Group] > 0),
	[Row] INT NOT NULL CHECK([Row] > 0),
	[Column] INT NOT NULL CHECK([Column] > 0),
	[Ranking] VARCHAR(10),
	PRIMARY KEY ([Group], [Row], [Column]),
);

CREATE TABLE [tblReservedSeat] (
	[CustUserName] VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES tblCustomer([CustUserName]) ON DELETE CASCADE,
	[eventID] INT NOT NULL CHECK([eventID] > 0),
	[Group] INT NOT NULL CHECK([Group] > 0),
	[Row] INT NOT NULL CHECK([Row] > 0),
	[Column] INT NOT NULL CHECK([Column] > 0),
	PRIMARY KEY ([eventID], [Group], [Row], [Column]),
	CONSTRAINT [FK_ReservedSeat_tblSeat] FOREIGN KEY ([Group], [Row], [Column]) REFERENCES tblSeat([Group], [Row], [Column]),
	CONSTRAINT [FK_ReservedSeat_tblEvent] FOREIGN KEY ([eventID]) REFERENCES tblEvent([eventID])
);

CREATE TABLE [tblSeatPrice] (
	[Group] INT CHECK([Group] > 0) NOT NULL,
	[Price] MONEY CHECK([Price] > 0) NOT NULL,
	PRIMARY KEY([Group])
);

CREATE TABLE [tblCustomerLogin] (
	[CustUsername] VARCHAR(20) NOT NULL PRIMARY KEY,
	[Password] VARCHAR(MAX)  NOT NULL CHECK(LEN([Password]) >= 8),
	[LastLogin] DATETIME DEFAULT NULL,
	CONSTRAINT [FK_CustomerLogin_tblCustomer] FOREIGN KEY ([CustUsername]) REFERENCES tblCustomer([CustUserName]) ON DELETE CASCADE
);

CREATE TABLE [tblEmployee] (
	[EmpUserName] VARCHAR(20) NOT NULL,
	[FName] VARCHAR(20) NOT NULL,
	[LName] VARCHAR(20) NOT NULL,
	PRIMARY KEY ([EmpUserName])
);

CREATE TABLE [tblEmployeeLogin] (
	[EmpUserName] VARCHAR(20) NOT NULL PRIMARY KEY,
	[Password] VARCHAR(MAX) NOT NULL,
	[lastLogin] DATETIME DEFAULT NULL,
	CONSTRAINT [FK_EmployeeLogin_UserName] FOREIGN KEY ([EmpUserName]) REFERENCES tblEmployee([EmpUserName]) ON DELETE CASCADE
);

CREATE TABLE ReserverTemp (
	[Row] INT,
	[CustUserName] VARCHAR(20),
	[Balance] MONEY,
	[Group] INT,
	[Price] MONEY,
	[eventID] INT
);

GO
--Check Available Seat
CREATE FUNCTION CheckSeat(@eventID INT, @group INT, @row INT, @column INT)
	RETURNS INT
AS
BEGIN
	IF EXISTS(SELECT [CustUserName] FROM [tblReservedSeat] WHERE [eventID] = @eventID AND [Group] = @group AND [Row] = @row AND [Column] = @column)
		RETURN 1
	RETURN 0
END 

GO
--Check Deposit Then Withdraw
CREATE FUNCTION CheckBalance(@customerUserName VARCHAR(20), @group INT)
	RETURNS INT
AS
BEGIN
	DECLARE @totalPrice MONEY = (SELECT [Price] FROM [tblSeatPrice] WHERE [Group] = @group)
	DECLARE @balance MONEY = (SELECT [Balance] FROM tblCustomer WHERE [CustUserName] = @customerUserName)
	IF(@totalPrice > @balance)
		RETURN 1
	RETURN 0
END

--How to calculate remaining seats
GO
ALTER FUNCTION ListEvents()
	RETURNS TABLE
AS
	RETURN (SELECT  MIN([tblEvent].[eventID]), MIN([tblEvent].Title), (50000 - SUM([tblReservedSeat].eventID)) AS RemainingSeat FROM [tblEvent]
	JOIN [tblReservedSeat]
	ON [tblEvent].[eventID] = [tblReservedSeat].[eventID]
	GROUP BY [tblEvent].[eventID])

SELECT * FROM dbo.ListEvents()

GO
CREATE FUNCTION CheckStadiumFull(@eventID INT)
	RETURNS INT
AS
BEGIN
	DECLARE @eventAttenders INT = (SELECT COUNT(eventID) FROM [tblReservedSeat] WHERE eventID = @eventID)
	IF @eventAttenders > 50000
		RETURN 1
	RETURN 0
END

GO
CREATE FUNCTION GetFullName(@CustUserName VARCHAR(20))
	RETURNS VARCHAR(50)
AS
BEGIN
	RETURN (SELECT CONCAT(FName, ' ' ,LName) FROM [tblCustomer] WHERE [CustUserName] = @CustUserName)
END

GO
CREATE FUNCTION GetFName(@CustUserName VARCHAR(20))
	RETURNS VARCHAR(50)
AS
BEGIN
	RETURN (SELECT FName FROM [tblCustomer] WHERE [CustUserName] = @CustUserName)
END

GO
CREATE FUNCTION GetLName(@CustUserName VARCHAR(20))
	RETURNS VARCHAR(50)
AS
BEGIN
	RETURN (SELECT LName FROM [tblCustomer] WHERE [CustUserName] = @CustUserName)
END

GO
CREATE FUNCTION GetAddress(@CustUserName VARCHAR(20))
	RETURNS VARCHAR(50)
AS
BEGIN
	RETURN (SELECT Address FROM [tblCustomer] WHERE [CustUserName] = @CustUserName)
END

GO
CREATE FUNCTION GetBalance(@CustUserName VARCHAR(20))
	RETURNS VARCHAR(50)
AS
BEGIN
	RETURN (SELECT CAST(Balance AS INT) FROM [tblCustomer] WHERE [CustUserName] = @CustUserName)
END

GO
CREATE FUNCTION GetPhoneNo(@CustUserName VARCHAR(20))
	RETURNS VARCHAR(50)
AS
BEGIN
	RETURN (SELECT PhoneNo FROM [tblCustomer] WHERE [CustUserName] = @CustUserName)
END

GO
--Make Reservation (Stored Procedure)
CREATE PROC MakeReservation 
	@custUserName VARCHAR(20),
	@eventID INT,
	@group INT,
	@row INT,
	@column INT
AS
BEGIN
	DECLARE @checkSeat INT = dbo.CheckSeat(@eventID, @group, @row, @column)
	DECLARE @checkBalance INT =  dbo.CheckBalance(@custUserName, @group)
	DECLARE @price MONEY =  (SELECT [Price] FROM tblSeatPrice WHERE [Group] = @group)
	DECLARE @eventTitle VARCHAR(20) = (SELECT [Title] FROM [tblEvent] WHERE eventID = @eventID)
	DECLARE @balance MONEY = (SELECT [Balance] FROM tblCustomer WHERE [CustUserName] = @custUserName)	

	IF(@checkSeat <> 0)
	BEGIN
		PRINT 'Seat Group ' + CAST(@group AS VARCHAR(MAX)) + ' Row ' + CAST(@row AS VARCHAR(MAX)) + ' Column ' + CAST(@column AS VARCHAR(MAX)) + ' is reserved for ' + @eventTitle + CHAR(10) + 'Please reserve another seat.'
		RETURN 1
	END
	ELSE IF(@checkBalance <> 0)
	BEGIN
		PRINT 'Not Enough Balance' + CHAR(10) + 'Please Recharge more $' + CAST((@price - @balance) AS VARCHAR(20))
		RETURN 1
	END
	ELSE IF(dbo.CheckStadiumFull(@eventID) <> 0)
	BEGIN
		PRINT 'Stadium is fully reserved. Please reserve for another event.'
		RETURN 1
	END
	ELSE IF(@checkSeat = 0 AND @checkBalance = 0 AND dbo.CheckStadiumFull(@eventID) = 0)
	BEGIN
		UPDATE [tblCustomer] SET [Balance] -= @price
		INSERT INTO [tblReservedSeat] VALUES (@custUserName, @eventID, @group, @row, @column)
		RETURN 0
	END
END

GO
--Make Refund (Stored Procedure)
CREATE PROC MakeRefund
	@custUserName VARCHAR(20),
	@eventID INT,
	@group INT,
	@row INT,
	@column INT
AS
BEGIN
	IF(dbo.CheckSeat(@eventID, @group, @row, @column) = 1)
	BEGIN
		DECLARE @eventDateTime VARCHAR(20) = (SELECT [DateTime] FROM [tblEvent] WHERE eventID = @eventID)
		DECLARE @eventExpiry INT = (DATEDIFF(DD, GETDATE(), @eventDateTime))
		DECLARE @reservedSeatPrice MONEY = (SELECT [Price] FROM tblSeatPrice WHERE [Group] = @group)
		DECLARE @refundBalance MONEY = @reservedSeatPrice - (0.20 * @reservedSeatPrice)
		IF(@eventExpiry < 1)
		BEGIN
			PRINT 'You cant make refund because the event refund duration has passed the deadline.'
			RETURN 1
		END
		ELSE
		BEGIN
			DELETE [tblReservedSeat] WHERE [eventID] = @eventID AND [Group] = @group AND [Row] = @row AND [Column] = @column
			UPDATE [tblCustomer] SET [Balance] = @refundBalance WHERE [CustUserName] = @custUserName
			RETURN 0
		END
	END
	ELSE
	BEGIN
		PRINT 'You cant make refund because the seat you are trying to make refund is not reserved.'
		RETURN 1
	END
END

GO
--Make Refund (Stored Procedure)
CREATE PROC ChangeSeat
	@custUserName VARCHAR(20),
	@eventID INT,
	@group INT,
	@row INT,
	@column INT,
	@newGroup INT,
	@newRow INT,
	@newColumn INT
AS
BEGIN
	IF(dbo.CheckSeat(@eventID, @group, @row, @column) = 1)
	BEGIN
		DECLARE @eventDateTime VARCHAR(20) = (SELECT [DateTime] FROM [tblEvent] WHERE eventID = @eventID)
		DECLARE @eventExpiry INT = (DATEDIFF(DD, GETDATE(), @eventDateTime))
		DECLARE @eventTitle VARCHAR(20) = (SELECT [Title] FROM [tblEvent] WHERE eventID = @eventID)
		IF(@eventExpiry < 1)
		BEGIN
			PRINT 'You cant change seat for' + @eventTitle + 'because the event change seat duration has passed the deadline.'
			RETURN 1
		END
		ELSE
		BEGIN
			EXEC MakeRefund @custUserName, @eventID, @group, @row, @column
			EXEC MakeReservation @custUserName, @eventID, @group, @row, @column
			RETURN 0
		END
	END
	ELSE
	BEGIN
		PRINT 'You cant change seat because the you havent researved it.'
		RETURN 1
	END
END

GO
CREATE PROC EventCancellation
	@eventID INT
AS
BEGIN
	DECLARE @numofReservedEvent INT = (SELECT COUNT([eventID]) FROM [tblReservedSeat] WHERE [eventID] = @eventID)
	DECLARE @counter INT = 1

	INSERT INTO ReserverTemp
	SELECT ROW_NUMBER() OVER (ORDER BY [tblCustomer].[CustUserName]) AS [Row], [tblCustomer].CustUserName, [tblCustomer].Balance, [tblReservedSeat].[Group], [tblSeatPrice].Price, [tblEvent].eventID
	FROM [tblCustomer] 
	JOIN [tblReservedSeat]
	ON [tblReservedSeat].CustUserName = [tblCustomer].CustUserName
	JOIN [tblSeatPrice]
	ON [tblReservedSeat].[Group] = [tblSeatPrice].[Group]
	JOIN [tblEvent]
	ON [tblReservedSeat].eventID = 2

	WHILE @counter <= @numofReservedEvent
	BEGIN
		TRUNCATE TABLE ReserverTemp
		DECLARE @refundBalance MONEY = (SELECT [Price] FROM ReserverTemp), @custUserName VARCHAR = (SELECT [CustUserName] FROM ReserverTemp)
		UPDATE [tblCustomer] SET [Balance] = @refundBalance WHERE [CustUserName] = @custUserName 
		SET @counter += 1
	END
	DELETE [tblReservedSeat] WHERE [eventID] = @eventID 
	DELETE [tblEvent] WHERE [eventID] = @eventID 
END

GO
CREATE PROC MakeDeposit
	@CustUserName VARCHAR(20),
	@depositBalance MONEY
AS
BEGIN
	UPDATE [tblCustomer] SET [Balance] += @depositBalance WHERE [CustUserName] = @CustUserName
END

GO
CREATE PROC CreateUserAccount
	@CustUserName VARCHAR(20),
	@FName VARCHAR(20),
	@LName VARCHAR(20),
	@Address VARCHAR(20),
	@PhoneNo VARCHAR(10),
	@Password VARCHAR(20),
	@status VARCHAR(MAX) OUTPUT,
	@Balance MONEY = 0
AS
BEGIN
	DECLARE  @position INT = 1, @LetterCnt SMALLINT = 0, @NumberCnt SMALLINT = 0, @SpecialCharCnt SMALLINT = 0

	WHILE @position <= DATALENGTH(@password)
	BEGIN
		IF SUBSTRING(@password, @position, 1) LIKE '[a-z]'
		BEGIN
			SET @LetterCnt = @LetterCnt + 1
			SET @position = @position + 1
		END
	
		IF SUBSTRING(@password, @position, 1) LIKE '[0-9]'
		BEGIN
			SET @NumberCnt = @NumberCnt + 1
			SET @position = @position + 1
		END
	
		IF  SUBSTRING(@password, @position, 1) NOT LIKE '[0-9]' 
			AND SUBSTRING(@password, @position, 1) NOT LIKE '[a-z]' 
		BEGIN
			SET @SpecialCharCnt = @SpecialCharCnt + 1
			SET @position = @position + 1
		END
	END

	IF EXISTS(SELECT [CustUserName] FROM [tblCustomer] WHERE @CustUserName = [CustUserName])
	BEGIN
		SET @status = 'Username exists please enter another username'
		RETURN 1
	END
	ELSE IF (LEN(@CustUserName) < 4)
	BEGIN
		SET @status = 'Username must be greater than 4 characters.'
		RETURN 1
	END
	ELSE IF(@LetterCnt = 0 OR @NumberCnt = 0 OR @SpecialCharCnt = 0 OR LEN(@Password) < 8)
	BEGIN
		SET @status = 'Password must me greater than 8 characters.' + CHAR(10) + 
		'A mixture of both uppercase and lowercase letters.'  + CHAR(10) + 
		'A mixture of letters and numbers'  + CHAR(10) + 
		'Inclusion of at least one special character, e.g., ! @ # ? ]'
		RETURN 1
	END
	BEGIN
		SET @status = @CustUserName + ' is registered.'
		INSERT INTO [tblCustomer] VALUES(@CustUserName, @FName, @LName, @Address, @PhoneNo, DEFAULT)
		INSERT INTO [tblCustomerLogin] VALUES(@CustUserName, @Password, DEFAULT)
		RETURN 0
	END
END

GO
CREATE PROC CustLogin
	@CustUserName VARCHAR(20),
	@Password VARCHAR(20),
	@status VARCHAR(MAX) OUTPUT
AS
BEGIN
	IF NOT EXISTS(SELECT * FROM [tblCustomerLogin] WHERE [CustUserName] = @CustUserName AND [Password] = @Password)
	BEGIN
		SET @status = 'Username or Password is not correct. Please try again.'
	END
	ELSE
	BEGIN
		UPDATE [tblCustomerLogin] SET [LastLogin] = GETDATE()
		SET @status = '0'
	END
END

GO
CREATE PROC RegisterEvent
	@eventTitle VARCHAR(20),
	@eventDateTime DATETIME
AS
BEGIN
	IF EXISTS(SELECT [DateTime] FROM [tblEvent] WHERE [DateTime] = @eventDateTime)
	BEGIN
		PRINT 'There is an event registered at ' + @eventDateTime
		RETURN 1
	END
	ELSE
	BEGIN
		INSERT INTO [tblEvent] VALUES(@eventTitle, @eventDateTime)
	END
END

GO
CREATE PROC RemoveExpiredEvents
-- Automatically Runs Every Hour
AS
BEGIN
	DELETE [tblEvent] WHERE (DATEDIFF(DD, GETDATE(), [DateTime]) < 0)
END

GO
--Validate Event to be inserted is expired or not
CREATE TRIGGER CheckEventExpiry
ON [tblEvent]
AFTER INSERT
AS
BEGIN
	DECLARE @eventDateTime VARCHAR(20) = (SELECT [DateTime] FROM inserted)
	IF(DATEDIFF(DD, GETDATE(), @eventDateTime) < 0)
	BEGIN
		RAISERROR('Expired Event Inserted. Please enter correct event date.', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END
END

GO
--Check when user deletes account balance must be zero (All Withdrawed)
CREATE TRIGGER CheckBalanceWithdrawed
ON [tblCustomer]
AFTER DELETE
AS
BEGIN
	DECLARE @balance VARCHAR(20) = (SELECT [Balance] FROM inserted)
	IF(@balance > 0)
	BEGIN
		RAISERROR('Please Withdraw your balance before deletion.', 16, 2)
		ROLLBACK TRANSACTION
		RETURN
	END
END

GO
--Error When Stadium is full
CREATE TRIGGER StadiumFull
ON [tblReservedSeat]
AFTER INSERT
AS
BEGIN
	DECLARE @eventID INT = (SELECT [eventID] FROM inserted)
	DECLARE @numofReservedSeat INT = (SELECT COUNT([eventID]) FROM [tblReservedSeat] WHERE [eventID] = @eventID)
	IF(@numofReservedSeat > 50000)
	BEGIN
		RAISERROR('Stadium is fully reserved. Please reserve for another event', 16, 2)
		ROLLBACK TRANSACTION
		RETURN
	END
END

INSERT INTO [tblSeat] VALUES(1, 1, 3, 'Good')
INSERT INTO [tblSeatPrice] VALUES(1, 50)

EXEC RegisterEvent 'Man City vs Wolves', '2022-01-03' 

EXEC CreateUserAccount 'user1', 'Westpoint', 'Galanz', 'Ethiopia', '251911121314', 'Test_1234'
EXEC RegisterEvent 'Man Utd vs Man City', '2022-01-02 12:00'
EXEC MakeReservation 'user1', 2, 1, 1, 1
EXEC MakeDeposit 'user1', 100
EXEC EventCancellation 1

SELECT * FROM [tblCustomer]
SELECT * FROM [tblCustomerLogin]
SELECT * FROM [tblReservedSeat]
SELECT * FROM [tblEvent]
SELECT * FROM [tblSeat]
SELECT * FROM [tblSeatPrice]

DELETE [tblReservedSeat] WHERE [CustUserName] = 'user1'
DELETE [tblEvent] WHERE [eventID] = 3

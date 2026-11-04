DROP DATABASE IF EXISTS ITDS242_BookShop;
CREATE DATABASE ITDS242_BookShop;
USE ITDS242_BookShop;

CREATE TABLE `ADMIN` (
  `AdminID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `Username` varchar(100) NOT NULL UNIQUE,
  `Password` varchar(255) NOT NULL,
  `Status` varchar(20) NOT NULL COMMENT 'ACTIVE or SUSPENDED',
  CONSTRAINT chk_admin_status CHECK (Status = 'ACTIVE' OR Status = 'SUSPENDED')
);

CREATE TABLE `LOGINLOG` (
  `LoginLogID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `Timestamp` datetime NOT NULL,
  `Status` varchar(20) NOT NULL COMMENT 'SUCCESS or FAILED',
  `AdminID` int NOT NULL,
  CONSTRAINT chk_loginlog_status CHECK (Status = 'SUCCESS' OR Status = 'FAILED')
);

CREATE TABLE `USERTRANSACTION` (
  `UserTransactionID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `Timestamp` datetime NOT NULL,
  `TargetField` varchar(100) NOT NULL,
  `Operation` varchar(20) NOT NULL COMMENT 'INSERT, UPDATE, or DELETE',
  `OldValue` text,
  `NewValue` text,
  `MakeAdminID` int NOT NULL,
  `AffectAdminID` int NOT NULL,
  CONSTRAINT chk_usertransaction_operation CHECK (Operation = 'INSERT' or Operation = 'UPDATE' or Operation = 'DELETE')
);

CREATE TABLE `BOOK` (
  `BookID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `BookName` varchar(255) NOT NULL,
  `QuantityInStock` int NOT NULL COMMENT '0 or greater',
  `ISBNCode` char(17) UNIQUE,
  `Price` decimal(10,2) NOT NULL COMMENT '0 or greater',
  `Description` text,
  `PublishDate` date,
  `Size` varchar(15) NOT NULL,
  `PublisherID` int NOT NULL,
  CONSTRAINT chk_book_quanity_in_stock CHECK (QuantityInStock >= 0),
  CONSTRAINT chk_book_price CHECK (Price >= 0)
);

CREATE TABLE `PUBLISHER` (
  `PublisherID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `PublisherName` varchar(150) UNIQUE NOT NULL
);

CREATE TABLE `CATEGORY` (
  `CategoryID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `CategoryName` varchar(100) UNIQUE NOT NULL
);

CREATE TABLE `AUTHOR` (
  `AuthorID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `AuthorName` varchar(150) UNIQUE NOT NULL
);

CREATE TABLE `PICTURE` (
  `PicID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) NOT NULL,
  `URL` varchar(500) NOT NULL,
  `BookID` int NOT NULL
);

CREATE TABLE `BOOKTRANSACTION` (
  `BookTransactionID` int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `Timestamp` datetime NOT NULL,
  `TargetField` varchar(100) NOT NULL,
  `Operation` varchar(20) NOT NULL COMMENT 'INSERT, UPDATE, or DELETE',
  `OldValue` text,
  `NewValue` text,
  `AdminID` int NOT NULL,
  `BookID` int NOT NULL,
  CONSTRAINT chk_booktransaction_operation CHECK (Operation = 'INSERT' or Operation = 'UPDATE' or Operation = 'DELETE')
);

CREATE TABLE `IN` (
  `BookID` int NOT NULL ,
  `CategoryID` int NOT NULL,
  PRIMARY KEY (`BookID`, `CategoryID`)
);

CREATE TABLE `WRITE` (
  `BookID` int NOT NULL,
  `AuthorID` int NOT NULL,
  PRIMARY KEY (`BookID`, `AuthorID`)
);

ALTER TABLE `LOGINLOG` ADD FOREIGN KEY (`AdminID`) REFERENCES `ADMIN` (`AdminID`);

ALTER TABLE `USERTRANSACTION` ADD FOREIGN KEY (`MakeAdminID`) REFERENCES `ADMIN` (`AdminID`);

ALTER TABLE `USERTRANSACTION` ADD FOREIGN KEY (`AffectAdminID`) REFERENCES `ADMIN` (`AdminID`);

ALTER TABLE `BOOK` ADD FOREIGN KEY (`PublisherID`) REFERENCES `PUBLISHER` (`PublisherID`);

ALTER TABLE `PICTURE` ADD FOREIGN KEY (`BookID`) REFERENCES `BOOK` (`BookID`);

ALTER TABLE `BOOKTRANSACTION` ADD FOREIGN KEY (`AdminID`) REFERENCES `ADMIN` (`AdminID`);

ALTER TABLE `BOOKTRANSACTION` ADD FOREIGN KEY (`BookID`) REFERENCES `BOOK` (`BookID`);

ALTER TABLE `IN` ADD FOREIGN KEY (`BookID`) REFERENCES `BOOK` (`BookID`);

ALTER TABLE `IN` ADD FOREIGN KEY (`CategoryID`) REFERENCES `CATEGORY` (`CategoryID`);

ALTER TABLE `WRITE` ADD FOREIGN KEY (`BookID`) REFERENCES `BOOK` (`BookID`);

ALTER TABLE `WRITE` ADD FOREIGN KEY (`AuthorID`) REFERENCES `AUTHOR` (`AuthorID`);

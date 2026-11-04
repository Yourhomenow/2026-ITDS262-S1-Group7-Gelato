INSERT INTO admin (Username, Password, Status) VALUE
("Kason_w", 11111111, "ACTIVE"),
("Yoimiya", "Firework123", "ACTIVE");

INSERT INTO loginlog (Timestamp, Status, AdminID) VALUE
('2026-09-30 15:42:21', "SUCCESS", 1);

INSERT INTO usertransaction (Timestamp, TargetField, Operation, OldValue, NewValue, MakeAdminID, AffectAdminID) VALUE
('2026-09-30 15:59:21', "Username", "UPDATE", "Yoimiya", "YoiYoi", 1, 2);

INSERT INTO publisher (PublisherName) VALUE
("HappyPrinter");

INSERT INTO category (CategoryName) VALUE
("General"),
("Novel"),
("Comic&Manga"),
("Study"),
("Magazine");

INSERT INTO author (AuthorName) VALUE
("SuperCool PenName");

INSERT INTO book (BookName, QuantityInStock, Price, Size, PublisherID) VALUES 
("The Stranger", 10, 30.99 , 999, 1);

INSERT INTO picture (`Name`, `URL`, BookID) VALUE
("cover.png", "https://www.xxx", 1);

INSERT INTO booktransaction (Timestamp, TargetField, Operation, OldValue, NewValue, AdminID, BookID) VALUE
('2026-09-30 15:42:21', "BookName", "UPDATE", "The strang", "The Stranger", 2, 1);

INSERT INTO `in` (BookID, CategoryID) VALUE
(1,2); 

INSERT INTO `write` (BookID, AuthorID) VALUE
(1,1);

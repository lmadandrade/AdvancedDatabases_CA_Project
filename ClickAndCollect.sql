drop database if exists ClickAndCollect;
create database ClickAndCollect;
use ClickAndCollect;

CREATE TABLE Customers (
    CustomerID INT NOT NULL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL,
    PreferredPickupTimestamp DATETIME NOT NULL,
    LoyaltyPoints INT NOT NULL
);


CREATE TABLE Orders (
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderTimestamp DATETIME NOT NULL,
    OrderStatus VARCHAR(25) NOT NULL,
    TotalAmount INT NOT NULL,
    PriorityLevel VARCHAR(20) NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE Items (
    ItemID INT NOT NULL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Price INT NOT NULL,
    StockLevel INT NOT NULL,
    LocationInWarehouse VARCHAR(50) NOT NULL
);

CREATE TABLE OrderItems (
    OrderItemID INT NOT NULL PRIMARY KEY,
    OrderID INT NOT NULL,
    ItemID INT NOT NULL,
    Quantity INT NOT NULL,
    TotalPrice INT NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ItemID) REFERENCES Items(ItemID)
);

CREATE TABLE Zone (
    ZoneID CHAR(1) NOT NULL PRIMARY KEY,
    Capacity INT NOT NULL,
    CurrentUtilization INT NOT NULL,
    ZoneType VARCHAR(20) NOT NULL
);

CREATE TABLE Appointments (
    AppointmentID INT NOT NULL PRIMARY KEY,
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    AppointmentTime DATETIME NOT NULL,
    Status VARCHAR(20) NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE Staff (
    StaffID INT NOT NULL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Role VARCHAR(50) NOT NULL,
    ZoneID CHAR(1) NOT NULL,
    FOREIGN KEY (ZoneID) REFERENCES Zone(ZoneID)
);


CREATE TABLE Notifications (
    NotificationID INT NOT NULL PRIMARY KEY,
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    NotificationType VARCHAR(50) NOT NULL,
    SentTimestamp DATETIME NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

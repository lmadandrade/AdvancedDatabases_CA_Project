-- Click-and-Collect Database

-- Create or reset the ClickAndCollect database.
-- This ensures a fresh start by dropping any existing database with the same name.
DROP DATABASE IF EXISTS ClickAndCollect;
CREATE DATABASE ClickAndCollect;
USE ClickAndCollect;

-- Customers table
-- This table holds details about customers who use the Click-and-Collect service.
-- It includes personal details and preferences like their preferred pickup times.
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL,
    PreferredPickupTimestamp DATETIME NOT NULL,
    LoyaltyPoints INT NOT NULL);

-- Zone table
-- Defines storage or pickup zones within the warehouse or store.
-- Each zone has specific capacity limits and utilization to organize order handling.
CREATE TABLE Zone (
    ZoneID CHAR(1) PRIMARY KEY,
    Capacity INT NOT NULL,
    CurrentUtilization INT NOT NULL,
    ZoneType VARCHAR(20) NOT NULL);

-- Zone values
INSERT INTO Zone (ZoneID, Capacity, CurrentUtilization, ZoneType) VALUES
('A', 100, 50, 'Priority'),
('B', 200, 120, 'Medium'),
('C', 150, 90, 'Low');

-- Orders table
-- This table stores information about customer orders.
-- It includes the customer, order status, total amount, and assigned zone.
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderTimestamp DATETIME NOT NULL,
    OrderStatus VARCHAR(25) NOT NULL,
    TotalAmount DECIMAL(10, 2) NOT NULL,
    PriorityLevel VARCHAR(20) NOT NULL,
    ZoneID CHAR(1),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    FOREIGN KEY (ZoneID) REFERENCES Zone(ZoneID));

-- Trigger to assign ZoneID
-- Automatically assigns a zone to an order based on its priority level.
-- Updates the zone's utilization to keep track of available space.
DELIMITER $$
CREATE TRIGGER AssignZone
BEFORE INSERT ON Orders
FOR EACH ROW
BEGIN
    DECLARE assignedZone CHAR(1);
    
    -- Allocate ZoneID based on PriorityLevel and current utilization
    IF NEW.PriorityLevel = 'High' THEN
        SELECT ZoneID INTO assignedZone FROM Zone
        WHERE ZoneType = 'Priority' AND Capacity > CurrentUtilization
        ORDER BY Capacity - CurrentUtilization DESC
        LIMIT 1;
    ELSEIF NEW.PriorityLevel = 'Medium' THEN
        SELECT ZoneID INTO assignedZone FROM Zone
        WHERE ZoneType = 'Medium' AND Capacity > CurrentUtilization
        ORDER BY Capacity - CurrentUtilization DESC
        LIMIT 1;
    ELSEIF NEW.PriorityLevel = 'Low' THEN
        SELECT ZoneID INTO assignedZone FROM Zone
        WHERE ZoneType = 'Low' AND Capacity > CurrentUtilization
        ORDER BY Capacity - CurrentUtilization DESC
        LIMIT 1;
    END IF;
    
    SET NEW.ZoneID = assignedZone;

    -- Update Zone utilization
    UPDATE Zone SET CurrentUtilization = CurrentUtilization + 1
    WHERE ZoneID = NEW.ZoneID;
END $$
DELIMITER ;

-- Items table
-- Stores information about items available for purchase.
-- Tracks stock levels and warehouse locations for efficient inventory management.
CREATE TABLE Items (
    ItemID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    StockLevel INT NOT NULL,
    LocationInWarehouse VARCHAR(50) NOT NULL);

-- OrderItems table
-- Links orders to the items they contain.
-- Tracks quantities and calculates total prices for each item in an order.
CREATE TABLE OrderItems (
    OrderItemID INT PRIMARY KEY,
    OrderID INT NOT NULL,
    ItemID INT NOT NULL,
    Quantity INT NOT NULL,
    TotalPrice DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ItemID) REFERENCES Items(ItemID));

-- Appointments table
-- Manages scheduled pickup appointments for customers.
-- Tracks the status of the appointment and links it to customers and orders.

CREATE TABLE Appointments (
    AppointmentID INT PRIMARY KEY AUTO_INCREMENT,
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    AppointmentTime DATETIME NOT NULL,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Scheduled', 'Completed', 'Canceled')),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID));

-- Staff table
-- Stores information about staff members responsible for various tasks.
-- Includes their roles and assigned zones for streamlined operations.

CREATE TABLE Staff (
    StaffID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Role VARCHAR(50) NOT NULL,
    ZoneID CHAR(1) NOT NULL,
    FOREIGN KEY (ZoneID) REFERENCES Zone(ZoneID));

-- Notifications table
-- Tracks notifications sent to customers regarding their orders and appointments.
-- Helps maintain communication about updates and reminders.

CREATE TABLE Notifications (
    NotificationID INT PRIMARY KEY,
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    NotificationType VARCHAR(50) NOT NULL,
    SentTimestamp DATETIME NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID));

-- TimeSlots Table
-- Manages time slots for scheduling pickup appointments.
-- Includes capacity and keeps track of booked slots.
CREATE TABLE TimeSlots (
    SlotID INT PRIMARY KEY AUTO_INCREMENT,
    SlotStartTime TIME NOT NULL,
    SlotEndTime TIME NOT NULL,
    SlotCapacity INT NOT NULL,
    SlotBooked INT DEFAULT 0);

INSERT INTO TimeSlots (SlotStartTime, SlotEndTime, SlotCapacity) VALUES
('08:00:00', '09:00:00', 10),
('09:00:00', '10:00:00', 15),
('10:00:00', '11:00:00', 20),
('11:00:00', '12:00:00', 20),
('13:00:00', '14:00:00', 15),
('14:00:00', '15:00:00', 10);

-- AppointmentAssignments Table
-- Links appointments to specific time slots and staff members.
-- Ensures proper scheduling and allocation of resources.

CREATE TABLE AppointmentAssignments (
    AssignmentID INT PRIMARY KEY AUTO_INCREMENT,
    AppointmentID INT NOT NULL,
    SlotID INT NOT NULL,
    StaffID INT NOT NULL,
    FOREIGN KEY (AppointmentID) REFERENCES Appointments(AppointmentID),
    FOREIGN KEY (SlotID) REFERENCES TimeSlots(SlotID),
    FOREIGN KEY (StaffID) REFERENCES Staff(StaffID));


-- This trigger automatically decreases the utilization count for a zone when an order's status is marked as 'Completed.'
-- It ensures accurate tracking of zone capacity after an order is fulfilled.

DELIMITER $$
CREATE TRIGGER DecrementZoneUtilization
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF NEW.OrderStatus = 'Completed' AND OLD.OrderStatus != 'Completed' THEN
        UPDATE Zone
        SET CurrentUtilization = CurrentUtilization - 1
        WHERE ZoneID = NEW.ZoneID;
    END IF;
END $$
DELIMITER ;

-- This trigger prevents overbooking of appointment slots by checking the remaining capacity before booking.
-- If the slot is already full, it raises an error to inform the user.

DELIMITER $$
CREATE TRIGGER CheckSlotCapacity
BEFORE INSERT ON AppointmentAssignments
FOR EACH ROW
BEGIN
    DECLARE slotRemaining INT;

    -- Check available capacity for the time slot
    SELECT SlotCapacity - SlotBooked INTO slotRemaining 
    FROM TimeSlots WHERE SlotID = NEW.SlotID;

    IF slotRemaining <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'This time slot is fully booked. Please select a different slot.';
    END IF;

    -- Increment the booked count for the time slot
    UPDATE TimeSlots
    SET SlotBooked = SlotBooked + 1
    WHERE SlotID = NEW.SlotID;
END $$
DELIMITER ;


-- This trigger decreases the booked count for a time slot when an appointment assignment is deleted.
-- It ensures the time slot availability is accurately updated.

DELIMITER $$
CREATE TRIGGER ReleaseSlotCapacity
AFTER DELETE ON AppointmentAssignments
FOR EACH ROW
BEGIN
    UPDATE TimeSlots
    SET SlotBooked = SlotBooked - 1
    WHERE SlotID = OLD.SlotID;
END $$
DELIMITER ;

-- Create indexes on frequently queried columns to speed up search and join operations.


-- Index to quickly locate orders by their assigned zone.
CREATE INDEX idx_orders_zoneid ON Orders (ZoneID);

-- Index to quickly locate staff members by their assigned zone.
CREATE INDEX idx_staff_zoneid ON Staff (ZoneID);

-- Index to quickly find appointments by customer.
CREATE INDEX idx_appointments_customerid ON Appointments (CustomerID);

-- Index to quickly locate orders by customer.
CREATE INDEX idx_orders_customerid ON Orders (CustomerID);

-- Index to quickly find notifications for a specific customer.
CREATE INDEX idx_notifications_customerid ON Notifications (CustomerID);


-- Populate the Customers table with sample data.
-- Each entry represents a customer using the Click-and-Collect service.

INSERT INTO Customers (CustomerID, Name, Email, PhoneNumber, PreferredPickupTimestamp, LoyaltyPoints) VALUES
(918393, 'Alice Johnson', 'alice.johnson@example.com', '123-456-7890', '2024-12-23 10:00:00', 100),
(918394, 'John Smith', 'john.smith@example.com', '123-555-1234', '2024-12-23 11:00:00', 120),
(918395, 'Jane Doe', 'jane.doe@example.com', '456-789-2345', '2024-12-24 09:30:00', 95),
(918396, 'Michael Brown', 'michael.brown@example.com', '789-456-3456', '2024-12-25 15:00:00', 200),
(918397, 'Sarah Johnson', 'sarah.johnson@example.com', '321-654-9876', '2024-12-26 08:15:00', 80),
(918398, 'David Wilson', 'david.wilson@example.com', '654-321-1234', '2024-12-27 14:45:00', 150),
(918399, 'Emily Davis', 'emily.davis@example.com', '987-123-4567', '2024-12-28 17:30:00', 75),
(918400, 'Chris Taylor', 'chris.taylor@example.com', '123-987-6543', '2024-12-29 10:00:00', 110),
(918401, 'Jessica Martinez', 'jessica.martinez@example.com', '789-654-3210', '2024-12-30 13:20:00', 130),
(918402, 'Kevin Moore', 'kevin.moore@example.com', '456-123-7890', '2025-01-01 12:10:00', 150),
(918403, 'Megan Anderson', 'megan.anderson@example.com', '321-987-4567', '2025-01-02 14:00:00', 85),
(918404, 'Daniel Thompson', 'daniel.thompson@example.com', '654-789-3210', '2025-01-03 11:50:00', 140),
(918405, 'Laura Lee', 'laura.lee@example.com', '123-456-7890', '2025-01-04 16:40:00', 125),
(918406, 'Steven Clark', 'steven.clark@example.com', '987-654-3210', '2025-01-05 18:00:00', 160),
(918407, 'Rachel Walker', 'rachel.walker@example.com', '456-789-1234', '2025-01-06 09:15:00', 100),
(918408, 'Andrew Young', 'andrew.young@example.com', '789-321-4567', '2025-01-07 10:30:00', 90);

-- Populate the Orders table with sample data.
INSERT INTO Orders (OrderID, CustomerID, OrderTimestamp, OrderStatus, TotalAmount, PriorityLevel) VALUES
(101, 918393, '2024-12-22 15:00:00', 'Preparing', 120.50, 'High'),
(102, 918394, '2024-12-23 16:00:00', 'Preparing', 89.99, 'Medium'),
(103, 918395, '2024-12-24 10:30:00', 'Ready for Pickup', 150.00, 'High'),
(104, 918396, '2024-12-25 15:45:00', 'Completed', 200.75, 'Low'),
(105, 918397, '2024-12-26 08:45:00', 'Preparing', 59.50, 'Medium'),
(106, 918398, '2024-12-27 12:00:00', 'Ready for Pickup', 100.00, 'High'),
(107, 918399, '2024-12-28 17:50:00', 'Completed', 175.25, 'Low'),
(108, 918400, '2024-12-29 10:15:00', 'Preparing', 120.99, 'Medium'),
(109, 918401, '2024-12-30 14:30:00', 'Ready for Pickup', 89.00, 'High'),
(110, 918402, '2025-01-01 12:20:00', 'Completed', 145.50, 'Low'),
(111, 918403, '2025-01-02 14:45:00', 'Preparing', 72.80, 'Medium'),
(112, 918404, '2025-01-03 10:50:00', 'Ready for Pickup', 50.00, 'High'),
(113, 918405, '2025-01-04 16:10:00', 'Completed', 135.99, 'Low'),
(114, 918406, '2025-01-05 18:20:00', 'Preparing', 90.50, 'Medium'),
(115, 918407, '2025-01-06 09:00:00', 'Ready for Pickup', 160.25, 'High'),
(116, 918408, '2025-01-07 10:45:00', 'Completed', 190.10, 'Low');

-- Populate the Items table with sample product data.
INSERT INTO Items (ItemID, Name, Category, Price, StockLevel, LocationInWarehouse) VALUES
(201, 'Bluetooth Headphones', 'Electronics', 35, 49, 'Zone A - Rack 1'),
(202, 'Wireless Mouse', 'Electronics', 20, 35, 'Zone A - Rack 2'),
(203, 'Gaming Keyboard', 'Electronics', 50, 25, 'Zone B - Shelf 1'),
(204, 'USB-C Charger', 'Accessories', 15, 80, 'Zone C - Bin 5'),
(205, 'LED Monitor', 'Electronics', 120, 10, 'Zone A - Rack 3'),
(206, 'Laptop Stand', 'Office Supplies', 30, 45, 'Zone B - Shelf 2'),
(207, 'Noise-Canceling Headphones', 'Electronics', 100, 20, 'Zone C - Bin 6'),
(208, 'Portable Speaker', 'Electronics', 40, 55, 'Zone A - Rack 4'),
(209, 'Wireless Earbuds', 'Electronics', 60, 70, 'Zone B - Shelf 4'),
(210, 'External Hard Drive', 'Storage', 90, 15, 'Zone C - Bin 7'),
(211, 'Office Chair', 'Furniture', 150, 5, 'Zone A - Rack 5'),
(212, 'Desk Lamp', 'Home Office', 25, 60, 'Zone B - Shelf 5'),
(213, 'Smartwatch', 'Electronics', 200, 30, 'Zone C - Bin 8'),
(214, 'Printer Ink', 'Office Supplies', 40, 50, 'Zone A - Rack 6'),
(215, 'Tablet Cover', 'Accessories', 20, 90, 'Zone B - Shelf 6'),
(216, 'HDMI Cable', 'Electronics', 10, 100, 'Zone C - Bin 9');

-- Insert data for OrderItems
INSERT INTO OrderItems (OrderItemID, OrderID, ItemID, Quantity, TotalPrice) VALUES
(301, 101, 201, 1, 35),
(302, 102, 202, 2, 40),
(303, 103, 203, 1, 50),
(304, 104, 204, 3, 45),
(305, 105, 205, 1, 120),
(306, 106, 206, 2, 60),
(307, 107, 207, 1, 100),
(308, 108, 208, 4, 160),
(309, 109, 209, 2, 120),
(310, 110, 210, 1, 90),
(311, 111, 211, 1, 150),
(312, 112, 212, 3, 75),
(313, 113, 213, 1, 200),
(314, 114, 214, 2, 80),
(315, 115, 215, 5, 100),
(316, 116, 216, 3, 30);

-- Insert data for Appointments
INSERT INTO Appointments (AppointmentID, OrderID, CustomerID, AppointmentTime, Status) VALUES
(401, 101, 918393, '2024-12-23 10:00:00', 'Scheduled'),
(402, 102, 918394, '2024-12-23 11:00:00', 'Scheduled'),
(403, 103, 918395, '2024-12-24 09:30:00', 'Completed'),
(404, 104, 918396, '2024-12-25 15:00:00', 'Scheduled'),
(405, 105, 918397, '2024-12-26 08:15:00', 'Scheduled'),
(406, 106, 918398, '2024-12-27 14:45:00', 'Scheduled'),
(407, 107, 918399, '2024-12-28 17:30:00', 'Completed'),
(408, 108, 918400, '2024-12-29 10:00:00', 'Scheduled'),
(409, 109, 918401, '2024-12-30 13:20:00', 'Completed'),
(410, 110, 918402, '2025-01-01 12:10:00', 'Scheduled'),
(411, 111, 918403, '2025-01-02 14:00:00', 'Completed'),
(412, 112, 918404, '2025-01-03 11:50:00', 'Scheduled'),
(413, 113, 918405, '2025-01-04 16:40:00', 'Completed'),
(414, 114, 918406, '2025-01-05 18:00:00', 'Scheduled'),
(415, 115, 918407, '2025-01-06 09:15:00', 'Completed'),
(416, 116, 918408, '2025-01-07 10:30:00', 'Scheduled');


-- Insert data for Staff
INSERT INTO Staff (StaffID, Name, Role, ZoneID) VALUES
(502, 'Emma White', 'Picker', 'A'),
(503, 'John Miller', 'Coordinator', 'B'),
(504, 'Sarah Johnson', 'Picker', 'C'),
(505, 'David Smith', 'Coordinator', 'A'),
(506, 'Emily Davis', 'Picker', 'B'),
(507, 'Michael Brown', 'Coordinator', 'C'),
(508, 'Laura Wilson', 'Picker', 'A'),
(509, 'Kevin Moore', 'Coordinator', 'B'),
(510, 'Megan Anderson', 'Picker', 'C'),
(511, 'Chris Taylor', 'Coordinator', 'A'),
(512, 'Jessica Martinez', 'Picker', 'B'),
(513, 'Daniel Thompson', 'Coordinator', 'C'),
(514, 'Rachel Walker', 'Picker', 'A'),
(515, 'Steven Clark', 'Coordinator', 'B'),
(516, 'Andrew Young', 'Picker', 'A'),
(517, 'Laura Lee', 'Coordinator', 'C');

-- Insert data for Notifications
INSERT INTO Notifications (NotificationID, OrderID, CustomerID, NotificationType, SentTimestamp) VALUES
(601, 101, 918393, 'Order Ready', '2024-12-22 17:00:00'),
(602, 102, 918394, 'Order Ready', '2024-12-23 16:00:00'),
(603, 103, 918395, 'Appointment Reminder', '2024-12-24 09:00:00'),
(604, 104, 918396, 'Pickup Confirmation', '2024-12-25 15:30:00'),
(605, 105, 918397, 'Order Ready', '2024-12-26 08:00:00'),
(606, 106, 918398, 'Appointment Reminder', '2024-12-27 14:30:00'),
(607, 107, 918399, 'Pickup Confirmation', '2024-12-28 18:00:00'),
(608, 108, 918400, 'Order Ready', '2024-12-29 10:30:00'),
(609, 109, 918401, 'Appointment Reminder', '2024-12-30 13:00:00'),
(610, 110, 918402, 'Pickup Confirmation', '2025-01-01 12:30:00'),
(611, 111, 918403, 'Order Ready', '2025-01-02 14:15:00'),
(612, 112, 918404, 'Appointment Reminder', '2025-01-03 10:45:00'),
(613, 113, 918405, 'Pickup Confirmation', '2025-01-04 15:20:00'),
(614, 114, 918406, 'Order Ready', '2025-01-05 17:00:00'),
(615, 115, 918407, 'Appointment Reminder', '2025-01-06 09:30:00'),
(616, 116, 918408, 'Pickup Confirmation', '2025-01-07 11:00:00');

INSERT INTO AppointmentAssignments (AssignmentID, AppointmentID, SlotID, StaffID) VALUES
(1, 401, 1, 502),  -- Alice Johnson, assigned to Emma White
(2, 402, 2, 503),  -- John Smith, assigned to John Miller
(3, 403, 3, 504),  -- Jane Doe, assigned to Sarah Johnson
(4, 404, 4, 505),  -- Michael Brown, assigned to David Smith
(5, 405, 5, 506),  -- Sarah Johnson, assigned to Emily Davis
(6, 406, 6, 507),  -- David Wilson, assigned to Michael Brown
(7, 408, 1, 508),  -- Chris Taylor, assigned to Laura Wilson
(8, 410, 3, 510),  -- Kevin Moore, assigned to Megan Anderson
(9, 412, 4, 511),  -- Daniel Thompson, assigned to Chris Taylor
(10, 414, 6, 512); -- Steven Clark, assigned to Jessica Martinez


-- This query calculates the total number of orders in each zone by priority level and provides insights into space utilization for tracking porpuses.
-- It demonstrates which zones are most used based on the current capacity and the priority levels of the orders they store
SELECT 
    z.ZoneID,
    z.ZoneType AS ZonePriorityLevel,
    z.Capacity,
    z.CurrentUtilization,
    COUNT(o.OrderID) AS TotalOrders,
    ROUND((z.CurrentUtilization / z.Capacity) * 100, 2) AS UtilizationPercentage
FROM Zone z
LEFT JOIN Orders o ON z.ZoneID = o.ZoneID
GROUP BY z.ZoneID, z.ZoneType, z.Capacity, z.CurrentUtilization
ORDER BY UtilizationPercentage DESC;

-- This query lists all customers who have scheduled appointments within specific time slots. It also shows the assigned staff members for each appointment. 
-- This demonstrates the system's ability to manage time slots and allocate staff efficiently.

SELECT c.Name AS CustomerName, a.AppointmentTime, ts.SlotStartTime, ts.SlotEndTime, s.Name AS AssignedStaff
FROM AppointmentAssignments aa
JOIN Appointments a ON aa.AppointmentID = a.AppointmentID
JOIN TimeSlots ts ON aa.SlotID = ts.SlotID
JOIN Customers c ON a.CustomerID = c.CustomerID
JOIN Staff s ON aa.StaffID = s.StaffID
WHERE ts.SlotStartTime >= '09:00:00' AND ts.SlotEndTime <= '12:00:00';

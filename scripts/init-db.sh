#!/bin/bash
# Wait for SQL Server to be ready
echo "Waiting for SQL Server to be ready..."
for i in {1..60}; do
    /opt/mssql-tools18/bin/sqlcmd -S sqlserver -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "SQL Server is ready!"
        break
    fi
    echo "Waiting... ($i/60)"
    sleep 1
done

# Create the database if it doesn't exist
echo "Creating SafeShip database..."
/opt/mssql-tools18/bin/sqlcmd -S sqlserver -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'SafeShip')
BEGIN
    CREATE DATABASE SafeShip;
    PRINT 'Database SafeShip created successfully.';
END
ELSE
BEGIN
    PRINT 'Database SafeShip already exists.';
END
"

# Create the Products table
echo "Creating Products table..."
/opt/mssql-tools18/bin/sqlcmd -S sqlserver -U sa -P "$MSSQL_SA_PASSWORD" -C -d SafeShip -Q "
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Products')
BEGIN
    CREATE TABLE Products (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(MAX) NOT NULL,
        Price DECIMAL(18,2) NOT NULL
    );
    
    -- Insert sample data
    INSERT INTO Products (Name, Price) VALUES
        ('Life Jacket', 49.99),
        ('Fire Extinguisher', 34.99),
        ('First Aid Kit', 29.99),
        ('Flare Gun', 89.99),
        ('Anchor', 79.99);
    
    PRINT 'Products table created and sample data inserted.';
END
ELSE
BEGIN
    PRINT 'Products table already exists.';
END
"

echo "Database initialization complete!"

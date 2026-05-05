using OhMyCH
using Dates

# Connect to ClickHouse
client = connect("http://127.0.0.1:8123")

# Create a table
execute(client, """
    CREATE TABLE IF NOT EXISTS employees
    (
         name     String
        ,age      Int32
        ,position String
        ,salary   Float64
        ,hired    Date
    )
    ENGINE = MergeTree()
    ORDER BY name
""")

# Insert data
insert(client, "employees", [
    (name = "Alice",   age = Int32(29), position = "Developer", salary = 75000.5,  hired = Date(2021, 3, 15)),
    (name = "Bob",     age = Int32(35), position = "Manager",   salary = 92000.75, hired = Date(2019, 7, 1)),
    (name = "Charlie", age = Int32(42), position = "Architect", salary = 110000.0, hired = Date(2018, 1, 10)),
])

# Query all rows
result = query(client, "SELECT * FROM employees")

for row in result
    println(row.name, " — ", row.position, ", \$", row.salary)
end

# Fetch with typed deserialization
struct Employee
    name::String
    age::Int32
    position::String
    salary::Float64
    hired::Date
end

employees = fetch_all(client, "SELECT * FROM employees", Employee)

# Fetch single row
top = fetch_one(client, "SELECT name, salary FROM employees ORDER BY salary DESC LIMIT 1")
println("Top earner: ", top.name)

# Parameterized query
row = fetch_optional(client, """
    SELECT name, salary FROM employees WHERE name = {name:String}
""", (name = "Alice",))

# Cleanup
execute(client, "DROP TABLE IF EXISTS employees")
close(client)

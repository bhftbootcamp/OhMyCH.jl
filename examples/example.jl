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

# Define row type
struct Employee
    name::String
    age::Int32
    position::String
    salary::Float64
    hired::Date
end

# Insert data
insert(client, "employees", [
    Employee("Alice",   Int32(29), "Developer", 75000.5,  Date(2021, 3, 15)),
    Employee("Bob",     Int32(35), "Manager",   92000.75, Date(2019, 7, 1)),
    Employee("Charlie", Int32(42), "Architect", 110000.0, Date(2018, 1, 10)),
])

# Query all rows
result = query(client, "SELECT * FROM employees")

for row in result
    println(row.name, " — ", row.position, ", \$", row.salary)
end

# Fetch with typed deserialization
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

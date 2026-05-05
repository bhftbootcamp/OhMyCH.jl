using Test
using Dates, NanoDates, UUIDs
import Sockets: IPv4, IPv6
using OhMyCH

const CH_URL = get(ENV, "CLICKHOUSE_URL", "http://127.0.0.1:18123")

@testset "Integration tests" begin

    @testset "connect / ping / server_version / close" begin
        client = connect(CH_URL)
        @test isopen(client)
        @test ping(client)
        v = server_version(client)
        @test !isempty(v)
        @test occursin('.', v)
        close(client)
    end

    @testset "connect do-block" begin
        result = connect(CH_URL) do c
            @test isopen(c)
            ping(c)
        end
        @test result == true
    end

    @testset "execute / insert / query / fetch" begin
        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_test")
        execute(client, """
            CREATE TABLE _ohmych_test (
                id     UInt64,
                name   String,
                score  Float64,
                active Bool
            ) ENGINE = MergeTree() ORDER BY id
        """)

        insert(client, "_ohmych_test", [
            (id = UInt64(1), name = "Alice",   score = 95.5,  active = true),
            (id = UInt64(2), name = "Bob",     score = 87.3,  active = false),
            (id = UInt64(3), name = "Charlie", score = 91.0,  active = true),
        ])

        rows = fetch_all(client, "SELECT * FROM _ohmych_test ORDER BY id")
        @test length(rows) == 3
        @test rows[1].name == "Alice"
        @test rows[2].name == "Bob"
        @test rows[3].name == "Charlie"
        @test rows[1].active == true
        @test rows[2].active == false

        top = fetch_one(client, "SELECT name, score FROM _ohmych_test ORDER BY score DESC LIMIT 1")
        @test top.name == "Alice"
        @test top.score == 95.5

        nobody = fetch_optional(client, "SELECT * FROM _ohmych_test WHERE name = 'Nobody'")
        @test nobody === nothing

        alice = fetch_optional(client, "SELECT name FROM _ohmych_test WHERE name = 'Alice'")
        @test alice.name == "Alice"

        execute(client, "DROP TABLE _ohmych_test")
        close(client)
    end

    @testset "Typed deserialization" begin
        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_typed")
        execute(client, """
            CREATE TABLE _ohmych_typed (
                x Int32,
                y Float64
            ) ENGINE = MergeTree() ORDER BY x
        """)

        insert(client, "_ohmych_typed", [
            (x = Int32(10), y = 1.5),
            (x = Int32(20), y = 2.5),
        ])

        struct TypedRow
            x::Int32
            y::Float64
        end

        rows = fetch_all(client, "SELECT * FROM _ohmych_typed ORDER BY x", TypedRow)
        @test length(rows) == 2
        @test rows[1] == TypedRow(10, 1.5)
        @test rows[2] == TypedRow(20, 2.5)

        execute(client, "DROP TABLE _ohmych_typed")
        close(client)
    end

    @testset "Parameterized queries" begin
        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_params")
        execute(client, """
            CREATE TABLE _ohmych_params (
                id   UInt32,
                name String
            ) ENGINE = MergeTree() ORDER BY id
        """)

        insert(client, "_ohmych_params", [
            (id = UInt32(1), name = "one"),
            (id = UInt32(2), name = "two"),
            (id = UInt32(3), name = "three"),
        ])

        rows = fetch_all(client, "SELECT * FROM _ohmych_params WHERE id >= {min_id:UInt32} ORDER BY id", (min_id = UInt32(2),))
        @test length(rows) == 2
        @test rows[1].name == "two"
        @test rows[2].name == "three"

        execute(client, "DROP TABLE _ohmych_params")
        close(client)
    end

    @testset "All ClickHouse types" begin
        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_types")
        execute(client, """
            CREATE TABLE _ohmych_types (
                col_bool     Bool,
                col_u8       UInt8,
                col_u16      UInt16,
                col_u32      UInt32,
                col_u64      UInt64,
                col_i8       Int8,
                col_i16      Int16,
                col_i32      Int32,
                col_i64      Int64,
                col_f32      Float32,
                col_f64      Float64,
                col_str      String,
                col_date     Date,
                col_dt       DateTime,
                col_uuid     UUID,
                col_ipv4     IPv4,
                col_arr      Array(Int32),
                col_nullable Nullable(String),
                col_map      Map(String, Int32),
                col_tuple    Tuple(Int32, String)
            ) ENGINE = MergeTree() ORDER BY col_u64
        """)

        # Use explicit type to ensure Nullable field has Union{Nothing,String}
        RowType = NamedTuple{
            (:col_bool, :col_u8, :col_u16, :col_u32, :col_u64,
             :col_i8, :col_i16, :col_i32, :col_i64,
             :col_f32, :col_f64, :col_str, :col_date, :col_dt,
             :col_uuid, :col_ipv4, :col_arr, :col_nullable, :col_map, :col_tuple),
            Tuple{Bool, UInt8, UInt16, UInt32, UInt64,
                  Int8, Int16, Int32, Int64,
                  Float32, Float64, String, Date, DateTime,
                  UUID, IPv4, Vector{Int32}, Union{Nothing,String}, Dict{String,Int32}, Tuple{Int32,String}}
        }

        insert(client, "_ohmych_types", RowType[(
            col_bool     = true,
            col_u8       = UInt8(255),
            col_u16      = UInt16(65535),
            col_u32      = UInt32(100),
            col_u64      = UInt64(1),
            col_i8       = Int8(-128),
            col_i16      = Int16(-1),
            col_i32      = Int32(42),
            col_i64      = Int64(-999),
            col_f32      = Float32(3.14),
            col_f64      = 2.718281828,
            col_str      = "hello world",
            col_date     = Date(2025, 1, 15),
            col_dt       = DateTime(2025, 1, 15, 10, 30, 0),
            col_uuid     = UUID("550e8400-e29b-41d4-a716-446655440000"),
            col_ipv4     = IPv4("192.168.1.1"),
            col_arr      = Int32[1, 2, 3],
            col_nullable = "present",
            col_map      = Dict("a" => Int32(1), "b" => Int32(2)),
            col_tuple    = (Int32(10), "ten"),
        )])

        row = fetch_one(client, "SELECT * FROM _ohmych_types")
        @test row.col_bool == true
        @test row.col_u8 == UInt8(255)
        @test row.col_u16 == UInt16(65535)
        @test row.col_u32 == UInt32(100)
        @test row.col_u64 == UInt64(1)
        @test row.col_i8 == Int8(-128)
        @test row.col_i16 == Int16(-1)
        @test row.col_i32 == Int32(42)
        @test row.col_i64 == Int64(-999)
        @test row.col_f32 == Float32(3.14)
        @test row.col_f64 == 2.718281828
        @test row.col_str == "hello world"
        @test row.col_date == Date(2025, 1, 15)
        @test row.col_dt == DateTime(2025, 1, 15, 10, 30, 0)
        @test row.col_uuid == UUID("550e8400-e29b-41d4-a716-446655440000")
        @test row.col_ipv4 == IPv4("192.168.1.1")
        @test row.col_arr == Int32[1, 2, 3]
        @test row.col_nullable == "present"
        @test row.col_tuple == (Int32(10), "ten")

        # Nullable with NULL
        execute(client, "INSERT INTO _ohmych_types VALUES (false, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, '', '2025-01-01', '2025-01-01 00:00:00', '00000000-0000-0000-0000-000000000000', '0.0.0.0', [], NULL, {}, (0, ''))")

        rows = fetch_all(client, "SELECT col_nullable FROM _ohmych_types ORDER BY col_u64")
        @test rows[1].col_nullable == "present"
        @test rows[2].col_nullable === nothing

        execute(client, "DROP TABLE _ohmych_types")
        close(client)
    end

    @testset "query_binary / insert_binary round-trip" begin
        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_rb_src")
        execute(client, "DROP TABLE IF EXISTS _ohmych_rb_dst")
        execute(client, "CREATE TABLE _ohmych_rb_src (id UInt32, val String) ENGINE = MergeTree() ORDER BY id")
        execute(client, "CREATE TABLE _ohmych_rb_dst (id UInt32, val String) ENGINE = MergeTree() ORDER BY id")

        insert(client, "_ohmych_rb_src", [
            (id = UInt32(1), val = "alpha"),
            (id = UInt32(2), val = "beta"),
        ])

        bin = query_binary(client, "SELECT * FROM _ohmych_rb_src ORDER BY id")
        @test bin isa RowBinary

        struct BinRow
            id::UInt32
            val::String
        end

        rows = collect(BinRow, bin)
        @test length(rows) == 2
        @test rows[1].val == "alpha"

        bin2 = query_binary(client, "SELECT * FROM _ohmych_rb_src ORDER BY id")
        insert_binary(client, "INSERT INTO _ohmych_rb_dst", bin2)

        dst_rows = fetch_all(client, "SELECT * FROM _ohmych_rb_dst ORDER BY id")
        @test length(dst_rows) == 2
        @test dst_rows[1].val == "alpha"
        @test dst_rows[2].val == "beta"

        execute(client, "DROP TABLE _ohmych_rb_src")
        execute(client, "DROP TABLE _ohmych_rb_dst")
        close(client)
    end

    @testset "Compression: LZ4 vs NoCompression" begin
        client_lz4 = connect(CH_URL; compression = :lz4)
        client_none = connect(CH_URL; compression = :none)

        execute(client_lz4, "DROP TABLE IF EXISTS _ohmych_compress")
        execute(client_lz4, "CREATE TABLE _ohmych_compress (id UInt32, data String) ENGINE = MergeTree() ORDER BY id")

        data = [(id = UInt32(i), data = "row_$i") for i in 1:100]
        insert(client_lz4, "_ohmych_compress", data)

        rows_lz4 = fetch_all(client_lz4, "SELECT * FROM _ohmych_compress ORDER BY id")
        rows_none = fetch_all(client_none, "SELECT * FROM _ohmych_compress ORDER BY id")
        @test length(rows_lz4) == 100
        @test length(rows_none) == 100
        @test rows_lz4[1].data == "row_1"
        @test rows_none[50].data == "row_50"

        execute(client_lz4, "DROP TABLE _ohmych_compress")
        close(client_lz4)
        close(client_none)
    end

    @testset "Inserter" begin
        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_inserter")
        execute(client, "CREATE TABLE _ohmych_inserter (id UInt32, val String) ENGINE = MergeTree() ORDER BY id")

        T = NamedTuple{(:id, :val), Tuple{UInt32, String}}

        stats = inserter(client, "_ohmych_inserter", T; max_rows = 50) do ins
            for i in 1:120
                write(ins, (id = UInt32(i), val = "v$i"))
                commit!(ins)
            end
        end

        @test stats.rows == 120
        @test stats.transactions >= 2

        rows = fetch_all(client, "SELECT count() as cnt FROM _ohmych_inserter")
        @test rows[1].cnt == 120

        execute(client, "DROP TABLE _ohmych_inserter")
        close(client)
    end

    @testset "Tables.jl integration" begin
        using Tables

        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_tables")
        execute(client, "CREATE TABLE _ohmych_tables (a Int32, b String) ENGINE = MergeTree() ORDER BY a")

        insert(client, "_ohmych_tables", [
            (a = Int32(1), b = "x"),
            (a = Int32(2), b = "y"),
        ])

        result = query(client, "SELECT * FROM _ohmych_tables ORDER BY a")
        @test Tables.istable(typeof(result))

        sch = Tables.schema(result)
        @test sch.names == (:a, :b)
        @test sch.types == (Int32, String)

        rt = Tables.rowtable(result)
        @test length(rt) == 2
        @test rt[1] == (a = Int32(1), b = "x")

        execute(client, "DROP TABLE _ohmych_tables")
        close(client)
    end

    @testset "Large insert with chunking" begin
        client = connect(CH_URL)

        execute(client, "DROP TABLE IF EXISTS _ohmych_large")
        execute(client, "CREATE TABLE _ohmych_large (id UInt64, payload String) ENGINE = MergeTree() ORDER BY id")

        data = [(id = UInt64(i), payload = repeat("x", 1000)) for i in 1:5000]
        insert(client, "_ohmych_large", data; chunk_size = 64 * 1024)

        row = fetch_one(client, "SELECT count() as cnt FROM _ohmych_large")
        @test row.cnt == 5000

        execute(client, "DROP TABLE _ohmych_large")
        close(client)
    end

    @testset "Error handling" begin
        client = connect(CH_URL)

        @test_throws CHServerException execute(client, "SELECT * FROM _nonexistent_table_12345")
        @test_throws CHServerException execute(client, "INVALID SQL SYNTAX HERE")

        @test_throws ArgumentError fetch_one(client, "SELECT 1 WHERE 1=0")
        @test fetch_optional(client, "SELECT 1 WHERE 1=0") === nothing

        close(client)
    end

end

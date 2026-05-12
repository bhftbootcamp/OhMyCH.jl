const CH_URL = get(ENV, "CLICKHOUSE_URL", "http://127.0.0.1:18123")
const CH_PASSWORD = get(ENV, "CLICKHOUSE_PASSWORD", "")

const _NS = "_ohmych_$(rand(UInt32))"

_tbl(name) = "$(_NS)_$name"

struct TypedRow
    x::Int32
    y::Float64
end

struct BinRow
    id::UInt32
    val::String
end

function _with_client(body::Function, tables::Vector{String} = String[]; kw...)
    client = connect(CH_URL; password = CH_PASSWORD, kw...)
    try
        body(client)
    finally
        for t in tables
            try
                execute(client, "DROP TABLE IF EXISTS $t")
            catch
            end
        end
        close(client)
    end
end

function _inserter_was_collected(client)
    w = let ins = Inserter{NamedTuple{(:x,), Tuple{Int32}}}(client, "_dummy"; period = 10.0)
        WeakRef(ins)
    end
    for _ in 1:5
        GC.gc(true)
    end
    return w.value === nothing
end

@testset "Integration tests" begin

    @testset "connect / ping / server_version / close" begin
        _with_client() do client
            @test isopen(client)
            @test ping(client)
            v = server_version(client)
            @test !isempty(v)
            @test occursin('.', v)
        end
    end

    @testset "connect do-block returns f's value" begin
        result = connect(CH_URL; password = CH_PASSWORD) do c
            @test isopen(c)
            ping(c)
        end
        @test result == true
    end

    @testset "connect positional CHConfig" begin
        cfg = CHConfig(CH_URL, "default", "default", CH_PASSWORD,
            :lz4, 10.0, 300.0, 0, 1.0, true)
        c = connect(cfg)
        try
            @test isopen(c)
            @test ping(c)
        finally
            close(c)
        end
    end

    @testset "execute / insert / query / fetch" begin
        tbl = _tbl("basic")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    id     UInt64,
                    name   String,
                    score  Float64,
                    active Bool
                ) ENGINE = MergeTree() ORDER BY id
            """)

            insert(client, tbl, [
                (id = UInt64(1), name = "Alice",   score = 95.5,  active = true),
                (id = UInt64(2), name = "Bob",     score = 87.3,  active = false),
                (id = UInt64(3), name = "Charlie", score = 91.0,  active = true),
            ])

            rows = fetch_all(client, "SELECT * FROM $tbl ORDER BY id")
            @test length(rows) == 3
            @test rows[1].name == "Alice"
            @test rows[2].name == "Bob"
            @test rows[3].name == "Charlie"
            @test rows[1].active == true
            @test rows[2].active == false

            top = fetch_one(client, "SELECT name, score FROM $tbl ORDER BY score DESC LIMIT 1")
            @test top.name == "Alice"
            @test top.score == 95.5

            @test_throws ArgumentError fetch_one(client, "SELECT * FROM $tbl WHERE name = 'Nobody'")
            @test_throws ArgumentError fetch_one(client, "SELECT * FROM $tbl")

            nobody = fetch_optional(client, "SELECT * FROM $tbl WHERE name = 'Nobody'")
            @test nobody === nothing

            alice = fetch_optional(client, "SELECT name FROM $tbl WHERE name = 'Alice'")
            @test alice.name == "Alice"
        end
    end

    @testset "Typed deserialization" begin
        tbl = _tbl("typed")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    x Int32,
                    y Float64
                ) ENGINE = MergeTree() ORDER BY x
            """)

            insert(client, tbl, [
                (x = Int32(10), y = 1.5),
                (x = Int32(20), y = 2.5),
            ])

            rows = fetch_all(client, "SELECT * FROM $tbl ORDER BY x", TypedRow)
            @test length(rows) == 2
            @test rows[1] == TypedRow(10, 1.5)
            @test rows[2] == TypedRow(20, 2.5)
        end
    end

    @testset "Parameterized queries" begin
        tbl = _tbl("params")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    id   UInt32,
                    name String
                ) ENGINE = MergeTree() ORDER BY id
            """)

            insert(client, tbl, [
                (id = UInt32(1), name = "one"),
                (id = UInt32(2), name = "two"),
                (id = UInt32(3), name = "three"),
            ])

            rows = fetch_all(client, "SELECT * FROM $tbl WHERE id >= {min_id:UInt32} ORDER BY id", (min_id = UInt32(2),))
            @test length(rows) == 2
            @test rows[1].name == "two"
            @test rows[2].name == "three"
        end
    end

    @testset "Reserved option keys are rejected" begin
        _with_client() do client
            @test_throws ArgumentError execute(client, "SELECT 1"; query = "evil")
            @test_throws ArgumentError execute(client, "SELECT 1"; param_x = "evil")
            @test_throws ArgumentError execute(client, "SELECT 1"; enable_http_compression = "0")
            @test fetch_one(client, "SELECT currentDatabase() AS d"; database = "default").d == "default"
        end
    end

    @testset "Insert into 'INSERT INTO ...' full statement still works" begin
        tbl = _tbl("inserts_log")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (x Int32) ENGINE = MergeTree() ORDER BY x")
            insert(client, tbl, [(x = Int32(1),), (x = Int32(2),)])
            insert(client, "INSERT INTO $tbl (x)", [(x = Int32(3),)])
            rows = fetch_all(client, "SELECT x FROM $tbl ORDER BY x")
            @test [r.x for r in rows] == Int32[1, 2, 3]
        end
    end

    @testset "All ClickHouse types" begin
        tbl = _tbl("types")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
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

            insert(client, tbl, RowType[(
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

            row = fetch_one(client, "SELECT * FROM $tbl")
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

            execute(client, "INSERT INTO $tbl VALUES (false, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, '', '2025-01-01', '2025-01-01 00:00:00', '00000000-0000-0000-0000-000000000000', '0.0.0.0', [], NULL, {}, (0, ''))")

            rows = fetch_all(client, "SELECT col_nullable FROM $tbl ORDER BY col_u64")
            @test rows[1].col_nullable == "present"
            @test rows[2].col_nullable === nothing
        end
    end

    @testset "Decimal round-trip at all widths" begin
        tbl = _tbl("decimals")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    id   UInt32,
                    d9   Decimal(9, 4),
                    d18  Decimal(18, 8),
                    d34  Decimal(34, 18)
                ) ENGINE = MergeTree() ORDER BY id
            """)

            rows = [
                (id = UInt32(1),
                 d9  = Decimal{9,4}("12345.6789"),
                 d18 = Decimal{18,8}("1234567890.12345678"),
                 d34 = Decimal{34,18}("1234567890123456.123456789012345678")),
                (id = UInt32(2),
                 d9  = Decimal{9,4}("-1.0000"),
                 d18 = Decimal{18,8}("0.00000001"),
                 d34 = Decimal{34,18}("-0.000000000000000001")),
            ]
            insert(client, tbl, rows)

            got = fetch_all(client, "SELECT * FROM $tbl ORDER BY id")
            @test length(got) == 2
            @test got[1].d9  == rows[1].d9
            @test got[1].d18 == rows[1].d18
            @test got[1].d34 == rows[1].d34
            @test got[2].d9  == rows[2].d9
            @test got[2].d18 == rows[2].d18
            @test got[2].d34 == rows[2].d34
        end
    end

    @testset "DateTime64 precisions 3 / 6 / 9" begin
        tbl = _tbl("dt64")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    id  UInt32,
                    t3  DateTime64(3),
                    t6  DateTime64(6),
                    t9  DateTime64(9)
                ) ENGINE = MergeTree() ORDER BY id
            """)

            insert(client, tbl, [(
                id = UInt32(1),
                t3 = NanoDate("2025-06-15T12:00:00.123"),
                t6 = NanoDate("2025-06-15T12:00:00.123456"),
                t9 = NanoDate("2025-06-15T12:00:00.123456789"),
            )])

            row = fetch_one(client, "SELECT * FROM $tbl")
            @test row.t3 == NanoDate("2025-06-15T12:00:00.123")
            @test row.t6 == NanoDate("2025-06-15T12:00:00.123456")
            @test row.t9 == NanoDate("2025-06-15T12:00:00.123456789")
        end
    end

    @testset "IPv6" begin
        tbl = _tbl("ipv6")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32, addr IPv6) ENGINE = MergeTree() ORDER BY id")
            insert(client, tbl, [
                (id = UInt32(1), addr = IPv6("::1")),
                (id = UInt32(2), addr = IPv6("2001:db8::1")),
                (id = UInt32(3), addr = IPv6("fe80::1")),
            ])
            rows = fetch_all(client, "SELECT * FROM $tbl ORDER BY id")
            @test rows[1].addr == IPv6("::1")
            @test rows[2].addr == IPv6("2001:db8::1")
            @test rows[3].addr == IPv6("fe80::1")
        end
    end

    @testset "FixedString round-trip" begin
        tbl = _tbl("fstr")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    id UInt32,
                    s5  FixedString(5),
                    s16 FixedString(16)
                ) ENGINE = MergeTree() ORDER BY id
            """)
            insert(client, tbl, [
                (id = UInt32(1), s5  = FixedString{5}("hi"),    s16 = FixedString{16}("short")),
                (id = UInt32(2), s5  = FixedString{5}("12345"), s16 = FixedString{16}("0123456789abcdef")),
            ])
            rows = fetch_all(client, "SELECT * FROM $tbl ORDER BY id")
            @test rows[1].s5  == FixedString{5}("hi")
            @test rows[1].s16 == FixedString{16}("short")
            @test rows[2].s5  == FixedString{5}("12345")
            @test rows[2].s16 == FixedString{16}("0123456789abcdef")
        end
    end

    @testset "Enum8 / Enum16" begin
        tbl = _tbl("enums")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    id UInt32,
                    side  Enum8('Bid' = 0, 'Ask' = 1),
                    region Enum16('US' = 100, 'EU' = 200, 'AS' = 300)
                ) ENGINE = MergeTree() ORDER BY id
            """)
            insert(client, tbl, [
                (id = UInt32(1), side = UInt8(0), region = UInt16(100)),
                (id = UInt32(2), side = UInt8(1), region = UInt16(200)),
                (id = UInt32(3), side = UInt8(0), region = UInt16(300)),
            ])
            rows = fetch_all(client, "SELECT id, side, region FROM $tbl ORDER BY id")
            @test rows[1].side == UInt8(0)
            @test rows[2].side == UInt8(1)
            @test rows[3].region == UInt16(300)
        end
    end

    @testset "Nullable(Array) and Map(LowCardinality(String), ...)" begin
        tbl = _tbl("nested")
        _with_client([tbl]) do client
            execute(client, """
                CREATE TABLE $tbl (
                    id UInt32,
                    tags  Array(Nullable(String)),
                    props Map(LowCardinality(String), Int32)
                ) ENGINE = MergeTree() ORDER BY id
            """)
            insert(client, tbl, [
                (id = UInt32(1),
                 tags = Union{Nothing,String}["a", nothing, "b"],
                 props = Dict{String,Int32}("k1" => Int32(1), "k2" => Int32(2))),
            ])
            row = fetch_one(client, "SELECT * FROM $tbl")
            @test row.tags == Union{Nothing,String}["a", nothing, "b"]
            @test row.props == Dict("k1" => Int32(1), "k2" => Int32(2))
        end
    end

    @testset "query_binary / insert_binary round-trip" begin
        src = _tbl("rb_src")
        dst = _tbl("rb_dst")
        _with_client([src, dst]) do client
            execute(client, "CREATE TABLE $src (id UInt32, val String) ENGINE = MergeTree() ORDER BY id")
            execute(client, "CREATE TABLE $dst (id UInt32, val String) ENGINE = MergeTree() ORDER BY id")

            insert(client, src, [
                (id = UInt32(1), val = "alpha"),
                (id = UInt32(2), val = "beta"),
            ])

            bin = query_binary(client, "SELECT * FROM $src ORDER BY id")
            @test bin isa RowBinary

            rows = collect(BinRow, bin)
            @test length(rows) == 2
            @test rows[1].val == "alpha"

            bin2 = query_binary(client, "SELECT * FROM $src ORDER BY id")
            insert_binary(client, "INSERT INTO $dst", bin2)

            dst_rows = fetch_all(client, "SELECT * FROM $dst ORDER BY id")
            @test length(dst_rows) == 2
            @test dst_rows[1].val == "alpha"
            @test dst_rows[2].val == "beta"
        end
    end

    @testset "Compression: LZ4 vs NoCompression" begin
        tbl = _tbl("compress")
        client_lz4 = connect(CH_URL; password = CH_PASSWORD, compression = :lz4)
        client_none = connect(CH_URL; password = CH_PASSWORD, compression = :none)
        try
            execute(client_lz4, "DROP TABLE IF EXISTS $tbl")
            execute(client_lz4, "CREATE TABLE $tbl (id UInt32, data String) ENGINE = MergeTree() ORDER BY id")

            data = [(id = UInt32(i), data = "row_$i") for i in 1:100]
            insert(client_lz4, tbl, data)

            rows_lz4 = fetch_all(client_lz4, "SELECT * FROM $tbl ORDER BY id")
            rows_none = fetch_all(client_none, "SELECT * FROM $tbl ORDER BY id")
            @test length(rows_lz4) == 100
            @test length(rows_none) == 100
            @test rows_lz4[1].data == "row_1"
            @test rows_none[50].data == "row_50"
        finally
            try
                execute(client_lz4, "DROP TABLE IF EXISTS $tbl")
            catch
            end
            close(client_lz4)
            close(client_none)
        end
    end

    @testset "Inserter: max_rows trigger" begin
        tbl = _tbl("ins_rows")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32, val String) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id, :val), Tuple{UInt32, String}}

            stats = inserter(client, tbl, T; max_rows = 50) do ins
                for i in 1:120
                    write(ins, (id = UInt32(i), val = "v$i"))
                    commit!(ins)
                end
            end

            @test stats.rows == 120
            @test stats.bytes > 0
            @test stats.transactions >= 2

            cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt.cnt == 120
        end
    end

    @testset "Inserter: InsertStats.bytes equals actual on-wire bytes" begin
        tbl = _tbl("ins_exact_bytes")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32, v String) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id, :v), Tuple{UInt32, String}}
            stats = inserter(client, tbl, T; max_rows = 200) do ins
                for i in 1:100
                    write(ins, (id = UInt32(i), v = "row_$i"))
                    commit!(ins)
                end
            end
            expected = sum(1:100) do i
                4 + 1 + ncodeunits("row_$i")
            end
            @test stats.rows == 100
            @test stats.bytes == expected
            @test stats.transactions == 1
        end
    end

    @testset "Inserter: max_bytes trigger" begin
        tbl = _tbl("ins_bytes")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32, payload String) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id, :payload), Tuple{UInt32, String}}

            stats = inserter(client, tbl, T; max_bytes = 1024) do ins
                for i in 1:50
                    write(ins, (id = UInt32(i), payload = repeat("x", 200)))
                    commit!(ins)
                end
            end

            @test stats.rows == 50
            @test stats.transactions >= 2

            cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt.cnt == 50
        end
    end

    @testset "Inserter with period does not leak when dropped without close" begin
        _with_client() do client
            @test _inserter_was_collected(client)
        end
    end

    @testset "Inserter warns on GC when buffer has unflushed rows" begin
        tbl = _tbl("ins_warn")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id,), Tuple{UInt32}}
            function _leak()
                ins = Inserter{T}(client, tbl)
                write(ins, (id = UInt32(1),))
                write(ins, (id = UInt32(2),))
                return nothing
            end

            @test_logs (:warn, r"garbage-collected with 2 unflushed") match_mode = :any begin
                _leak()
                for _ in 1:3
                    GC.gc(true)
                end
                sleep(0.2)
            end

            cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt.cnt == 0
        end
    end

    @testset "Inserter: buffer cleared on _chunked_insert! failure (no double-send)" begin
        tbl = _tbl("ins_failclear")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id,), Tuple{UInt32}}

            ins = Inserter{T}(client, tbl)
            write(ins, (id = UInt32(1),))
            write(ins, (id = UInt32(2),))

            close(client.curl_client)
            @test_throws OhMyCH.OhMyCHException flush!(ins)
            @test isempty(ins.buffer)

            close(ins)
            @test ins.closed
        end
    end

    @testset "Inserter: period trigger flushes idle stream" begin
        tbl = _tbl("ins_period")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id,), Tuple{UInt32}}

            ins = Inserter{T}(client, tbl; period = 0.3)
            try
                write(ins, (id = UInt32(1),))
                write(ins, (id = UInt32(2),))
                sleep(1.0)
                cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
                @test cnt.cnt == 2
            finally
                close(ins)
            end
            cnt2 = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt2.cnt == 2
        end
    end

    @testset "Inserter: explicit flush!" begin
        tbl = _tbl("ins_flush")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id,), Tuple{UInt32}}

            ins = Inserter{T}(client, tbl)
            try
                for i in 1:10
                    write(ins, (id = UInt32(i),))
                end
                s = flush!(ins)
                @test s.rows == 10
                @test s.transactions == 1

                s2 = flush!(ins)
                @test s2.rows == 0
                @test s2.transactions == 0
            finally
                close(ins)
            end

            cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt.cnt == 10
        end
    end

    @testset "Inserter: error in do-block discards buffer" begin
        tbl = _tbl("ins_err")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id,), Tuple{UInt32}}

            @test_throws ErrorException inserter(client, tbl, T) do ins
                write(ins, (id = UInt32(1),))
                write(ins, (id = UInt32(2),))
                error("boom — producer failed")
            end

            cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt.cnt == 0
        end
    end

    @testset "Inserter: double-close is idempotent" begin
        tbl = _tbl("ins_dc")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id,), Tuple{UInt32}}

            ins = Inserter{T}(client, tbl)
            write(ins, (id = UInt32(1),))
            s1 = close(ins)
            s2 = close(ins)
            @test s1.rows == 1
            @test s2.rows == 1

            @test_throws ArgumentError write(ins, (id = UInt32(2),))
            @test_throws ArgumentError flush!(ins)
            @test_throws ArgumentError commit!(ins)
        end
    end

    @testset "Inserter: chunk_size accepts any Integer subtype" begin
        tbl = _tbl("ins_chunk")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id,), Tuple{UInt32}}
            inserter(client, tbl, T; chunk_size = UInt32(4096)) do ins
                for i in 1:10
                    write(ins, (id = UInt32(i),))
                end
            end
            cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt.cnt == 10
        end
    end

    @testset "Inserter: convert(T, row) widens accepted types" begin
        tbl = _tbl("ins_conv")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt32, val String) ENGINE = MergeTree() ORDER BY id")
            T = NamedTuple{(:id, :val), Tuple{UInt32, String}}

            inserter(client, tbl, T) do ins
                write(ins, (id = 1, val = "a"))
                write(ins, (id = 2, val = "b"))
            end

            cnt = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test cnt.cnt == 2
        end
    end

    @testset "Tables.jl integration" begin
        tbl = _tbl("tables")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (a Int32, b String) ENGINE = MergeTree() ORDER BY a")

            insert(client, tbl, [
                (a = Int32(1), b = "x"),
                (a = Int32(2), b = "y"),
            ])

            result = query(client, "SELECT * FROM $tbl ORDER BY a")
            @test Tables.istable(typeof(result))

            sch = Tables.schema(result)
            @test sch.names == (:a, :b)
            @test sch.types == (Int32, String)

            rt = Tables.rowtable(result)
            @test length(rt) == 2
            @test rt[1] == (a = Int32(1), b = "x")
        end
    end

    @testset "Large insert with chunking" begin
        tbl = _tbl("large")
        _with_client([tbl]) do client
            execute(client, "CREATE TABLE $tbl (id UInt64, payload String) ENGINE = MergeTree() ORDER BY id")
            data = [(id = UInt64(i), payload = repeat("x", 1000)) for i in 1:5000]
            insert(client, tbl, data; chunk_size = 64 * 1024)

            row = fetch_one(client, "SELECT count() as cnt FROM $tbl")
            @test row.cnt == 5000
        end
    end

    @testset "Error handling" begin
        _with_client() do client
            @test_throws CHServerException execute(client, "SELECT * FROM _ohmych_nonexistent_table_12345")
            @test_throws CHServerException execute(client, "INVALID SQL SYNTAX HERE")

            @test_throws ArgumentError fetch_one(client, "SELECT 1 WHERE 1=0")
            @test fetch_optional(client, "SELECT 1 WHERE 1=0") === nothing
        end
    end

    @testset "Unknown server error codes still surface as CHServerException" begin
        ex = OhMyCH.CHServerException(999_999, "DB::Exception: synthetic")
        @test ex isa CHServerException
        @test ex.code == 999_999
    end

    @testset "CHConfig.show redacts the password" begin
        cfg_with_pw = CHConfig(CH_URL, "db", "user", "TOPSECRET",
            :lz4, 10.0, 300.0, 0, 1.0, true)
        s = sprint(show, cfg_with_pw)
        @test !occursin("TOPSECRET", s)
        @test occursin("***", s)

        cfg_no_pw = CHConfig(CH_URL, "db", "user", "",
            :none, 10.0, 300.0, 0, 1.0, true)
        s2 = sprint(show, cfg_no_pw)
        @test !occursin("***", s2)
    end

    @testset "CHClient is safe to share between concurrent tasks" begin
        _with_client() do client
            n = 30
            tasks = [Threads.@spawn fetch_one(client, "SELECT $i AS x").x for i in 1:n]
            results = fetch.(tasks)
            @test sort(Int.(results)) == collect(1:n)
        end
    end

    @testset "CHServerException.code compares to Integer and to ErrorCodes" begin
        ex_known = OhMyCH.CHServerException(60, "x")
        @test ex_known.code == 60
        @test 60 == ex_known.code
        @test ex_known.code === OhMyCH.UNKNOWN_TABLE
        @test ex_known.code == OhMyCH.UNKNOWN_TABLE
        _with_client() do client
            try
                execute(client, "SELECT * FROM _ohmych_does_not_exist_xyz")
                @test false
            catch e
                @test e isa CHServerException
                @test e.code == 60
            end
        end
    end

end

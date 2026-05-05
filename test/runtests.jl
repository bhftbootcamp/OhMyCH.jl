using Test
using OhMyCH
using Dates, NanoDates, UUIDs, Sockets
using Tables

import OhMyCH: Serializer, serialize, write_leb128, parse_column_type

include("decimals.jl")
include("fixed_strings.jl")
include("column_types.jl")
include("query_parameters.jl")
include("serialization.jl")

@testset "Compression codecs" begin
    @testset "LZ4 codec" begin
        codec = LZ4()
        @test codec isa Codec
        @test OhMyCH.content_encoding(codec) == "lz4"

        original = collect(UInt8, "Hello, ClickHouse!")
        compressed = OhMyCH.encode(codec, original)
        @test compressed != original
        decompressed = OhMyCH.decode(codec, compressed)
        @test decompressed == original
    end

    @testset "NoCompression codec" begin
        codec = NoCompression()
        @test codec isa Codec
        @test OhMyCH.content_encoding(codec) === nothing

        original = collect(UInt8, "Hello, ClickHouse!")
        @test OhMyCH.encode(codec, original) === original
        @test OhMyCH.decode(codec, original) === original
    end

    @testset "resolve_codec" begin
        @test OhMyCH.resolve_codec(:lz4) isa LZ4
        @test OhMyCH.resolve_codec(:none) isa NoCompression
        @test_throws ArgumentError OhMyCH.resolve_codec(:unknown)
    end
end

@testset "CHConfig and CHClient types" begin
    @testset "CHConfig construction" begin
        config = CHConfig(
            "http://localhost:8123", "default", "default", "",
            :lz4, 10.0, 300.0, 0, 1.0, true,
        )
        @test config.url == "http://localhost:8123"
        @test config.database == "default"
        @test config.user == "default"
        @test config.password == ""
        @test config.compression === :lz4
        @test config.connect_timeout == 10.0
        @test config.read_timeout == 300.0
        @test config.retry == 0
        @test config.retry_delay == 1.0
        @test config.verify_ssl == true
    end

    @testset "CHConfig with custom settings" begin
        config = CHConfig(
            "http://localhost:8123", "mydb", "admin", "secret",
            :none, 5.0, 600.0, 3, 2.0, false,
        )
        @test config.database == "mydb"
        @test config.compression === :none
        @test config.connect_timeout == 5.0
        @test config.read_timeout == 600.0
        @test config.retry == 3
        @test config.retry_delay == 2.0
        @test config.verify_ssl == false
    end

    @testset "CHConfig is serializable (all plain types)" begin
        config = CHConfig(
            "http://localhost:8123", "default", "default", "",
            :lz4, 10.0, 300.0, 0, 1.0, true,
        )
        for (name, T) in zip(fieldnames(CHConfig), fieldtypes(CHConfig))
            @test T <: Union{String, Symbol, Float64, Int, Bool}
        end
    end

    @testset "CHClientException with cause" begin
        cause = ErrorException("connection refused")
        ex = OhMyCH.CHClientException("failed to connect", cause)
        @test ex.message == "failed to connect"
        @test ex.cause === cause

        ex_no_cause = OhMyCH.CHClientException("timeout")
        @test ex_no_cause.cause === nothing
    end

    @testset "InsertStats" begin
        s1 = InsertStats(10, 100, 1)
        s2 = InsertStats(20, 200, 2)
        s3 = s1 + s2
        @test s3.rows == 30
        @test s3.bytes == 300
        @test s3.transactions == 3
    end
end

# Helper: build a RowBinaryWithNamesAndTypes buffer from column definitions and row data
function _build_rbwnat(col_names::Vector{String}, col_types::Vector{String}, rows)
    s = Serializer()
    julia_types = parse_column_type.(col_types)
    write_leb128(s, length(col_names))
    for name in col_names
        serialize(s, String, name)
    end
    for t in col_types
        serialize(s, String, t)
    end
    for row in rows
        for (val, T) in zip(row, julia_types)
            serialize(s, T, val)
        end
    end
    seekstart(s)
    return OhMyCH.RowBinaryWithNamesAndTypes(read(s.io))
end

@testset "RowBinaryWithNamesAndTypes" begin
    @testset "Direct iteration" begin
        result = _build_rbwnat(
            ["id", "name"],
            ["Int32", "String"],
            [(Int32(1), "Alice"), (Int32(2), "Bob"), (Int32(3), "Clara")],
        )

        rows = NamedTuple[]
        for row in result
            push!(rows, row)
        end

        @test length(rows) == 3
        @test rows[1] == (id = Int32(1), name = "Alice")
        @test rows[2] == (id = Int32(2), name = "Bob")
        @test rows[3] == (id = Int32(3), name = "Clara")
    end

    @testset "Direct iteration (empty result)" begin
        result = _build_rbwnat(["x"], ["Int32"], Tuple{Int32}[])

        rows = NamedTuple[]
        for row in result
            push!(rows, row)
        end
        @test isempty(rows)
    end

    @testset "eachrow" begin
        result = _build_rbwnat(
            ["val"],
            ["Float64"],
            [(1.5,), (2.5,)],
        )
        iter = eachrow(result)
        collected = collect(iter)
        @test length(collected) == 2
        @test collected[1] == (val = 1.5,)
        @test collected[2] == (val = 2.5,)
    end

    @testset "collect" begin
        result = _build_rbwnat(
            ["a", "b"],
            ["Int32", "Int32"],
            [(Int32(10), Int32(20)), (Int32(30), Int32(40))],
        )
        rows = collect(result)
        @test length(rows) == 2
        @test rows[1] == (a = Int32(10), b = Int32(20))
        @test rows[2] == (a = Int32(30), b = Int32(40))
    end

    @testset "collect with custom type" begin
        struct TestRow
            x::Int32
            y::Float64
        end

        result = _build_rbwnat(
            ["x", "y"],
            ["Int32", "Float64"],
            [(Int32(5), 3.14), (Int32(7), 2.71)],
        )
        rows = collect(TestRow, result)
        @test length(rows) == 2
        @test rows[1] == TestRow(Int32(5), 3.14)
        @test rows[2] == TestRow(Int32(7), 2.71)
    end
end

@testset "Tables.jl interface" begin
    @testset "RowBinaryWithNamesAndTypes is a Tables.jl source" begin
        result = _build_rbwnat(
            ["name", "age"],
            ["String", "Int32"],
            [("Alice", Int32(29)), ("Bob", Int32(35))],
        )

        @test Tables.istable(typeof(result))
        @test Tables.rowaccess(typeof(result))

        sch = Tables.schema(result)
        @test sch.names == (:name, :age)
        @test sch.types == (String, Int32)
    end

    @testset "Tables.rows produces iterable rows" begin
        result = _build_rbwnat(
            ["id", "value"],
            ["Int64", "Float64"],
            [(Int64(1), 10.0), (Int64(2), 20.0)],
        )

        tbl_rows = Tables.rows(result)
        collected = collect(tbl_rows)
        @test length(collected) == 2
        @test collected[1].id == Int64(1)
        @test collected[1].value == 10.0
        @test collected[2].id == Int64(2)
        @test collected[2].value == 20.0
    end

    @testset "BinaryToRowIter is a Tables.jl source" begin
        result = _build_rbwnat(
            ["x"],
            ["Int32"],
            [(Int32(42),)],
        )
        iter = eachrow(result)
        @test Tables.istable(typeof(iter))
        @test Tables.rowaccess(typeof(iter))

        sch = Tables.schema(iter)
        @test sch.names == (:x,)
        @test sch.types == (Int32,)
    end

    @testset "Tables.rowtable materialization" begin
        result = _build_rbwnat(
            ["a", "b"],
            ["String", "Float64"],
            [("hello", 1.0), ("world", 2.0)],
        )
        rt = Tables.rowtable(result)
        @test length(rt) == 2
        @test rt[1] == (a = "hello", b = 1.0)
        @test rt[2] == (a = "world", b = 2.0)
    end
end

@testset "RowBinary with typed eachrow" begin
    struct SimpleRecord
        id::Int64
        name::String
    end

    @testset "eachrow(T, RowBinary)" begin
        s = Serializer()
        serialize(s, Int64, Int64(100))
        serialize(s, String, "test")
        serialize(s, Int64, Int64(200))
        serialize(s, String, "hello")
        seekstart(s)
        rb = OhMyCH.RowBinary(read(s.io))

        rows = collect(SimpleRecord, rb)
        @test length(rows) == 2
        @test rows[1] == SimpleRecord(100, "test")
        @test rows[2] == SimpleRecord(200, "hello")
    end
end

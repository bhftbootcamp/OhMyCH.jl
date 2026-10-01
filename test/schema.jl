import OhMyCH: Column, CHType, parse_ch_type, coerce, column_positions, deserialize, serialize_row

struct SchemaRow
    b::Float64
    a::Int
end

function roundtrip(t::CHType, v)
    s = Serializer()
    serialize(s, t, v)
    seekstart(s)
    out = deserialize(s, t)
    @test eof(s)
    return out
end

@testset "Schema-driven (de)serialization" begin
    @testset "DateTime64 is scaled by its declared precision, not guessed" begin
        before_2001 = NanoDate("1999-01-01T12:34:56.789")
        for p in (0, 3, 6, 9)
            got = roundtrip(parse_ch_type("DateTime64($p)"), before_2001)
            # digits beyond the column's precision are cut on the way in
            want = p == 0 ? NanoDate("1999-01-01T12:34:56") : before_2001
            @test got == want
        end
        @test roundtrip(parse_ch_type("DateTime64(3, 'UTC')"), DateTime(1999, 1, 1, 12, 34, 56, 789)) ==
              NanoDate("1999-01-01T12:34:56.789")
        @test roundtrip(parse_ch_type("DateTime64(9)"), NanoDate("2023-11-25T23:59:59.333333335")) ==
              NanoDate("2023-11-25T23:59:59.333333335")
        @test roundtrip(parse_ch_type("DateTime64(3)"), NanoDate("1970-01-02T00:00:00")) ==
              NanoDate("1970-01-02T00:00:00")
    end

    @testset "every value is written as the column's type" begin
        @test roundtrip(parse_ch_type("Int32"), 42) === Int32(42)
        @test roundtrip(parse_ch_type("Float32"), 1) === Float32(1)
        @test roundtrip(parse_ch_type("Decimal(18, 8)"), 1.5) == Decimal{18,8}("1.5")
        @test roundtrip(parse_ch_type("FixedString(4)"), "ab") == FixedString{4}("ab")
        @test roundtrip(parse_ch_type("Nullable(String)"), missing) === nothing
        @test roundtrip(parse_ch_type("Nullable(String)"), nothing) === nothing
        @test roundtrip(parse_ch_type("Nullable(Int64)"), 7) === Int64(7)
        @test roundtrip(parse_ch_type("Array(UInt16)"), [1, 2, 3]) == UInt16[1, 2, 3]
        @test roundtrip(parse_ch_type("Map(String, Int32)"), Dict("a" => 1)) == Dict{String,Int32}("a" => 1)
        @test roundtrip(parse_ch_type("Tuple(Int32, String)"), (1, "x")) == (Int32(1), "x")
        @test roundtrip(parse_ch_type("LowCardinality(String)"), "lc") == "lc"
        @test roundtrip(parse_ch_type("DateTime"), DateTime(2024, 5, 6, 7, 8, 9)) == DateTime(2024, 5, 6, 7, 8, 9)
        @test roundtrip(parse_ch_type("Date"), Date(2024, 5, 6)) == Date(2024, 5, 6)
        @test_throws InexactError roundtrip(parse_ch_type("UInt8"), 300)
        @test_throws ArgumentError roundtrip(parse_ch_type("Tuple(Int32, String)"), (1,))
    end

    @testset "coerce: what a field accepts" begin
        @test coerce(Int, Int32(3)) === 3
        @test coerce(Float64, Decimal{9,4}("12.5")) === 12.5
        @test coerce(DateTime, NanoDate("2024-01-02T03:04:05.123456789")) == DateTime(2024, 1, 2, 3, 4, 5, 123)
        @test coerce(Date, NanoDate("2024-01-02T03:04:05")) == Date(2024, 1, 2)
        @test coerce(NanoDate, DateTime(2024, 1, 2)) == NanoDate("2024-01-02")
        @test coerce(String, FixedString{4}("ab")) === "ab"
        @test coerce(Union{Nothing,Int}, nothing) === nothing
        @test coerce(Union{Missing,Int}, nothing) === missing
        @test coerce(Union{Missing,Int}, Int32(1)) === 1
        @test coerce(Union{Nothing,Int}, missing) === nothing
        @test_throws ArgumentError coerce(Int, nothing)
        @test coerce(Vector{Int}, Int32[1, 2]) == [1, 2]
        @test coerce(Dict{String,Float64}, Dict("a" => Int32(1))) == Dict("a" => 1.0)
        @test coerce(Tuple{Int,String}, (Int32(1), "x")) === (1, "x")
        @test coerce(Decimal{9,4}, Decimal{9,4}("1.5")) == Decimal{9,4}("1.5")
    end

    @testset "column_positions: by name for structs and NamedTuples, by position for Tuples" begin
        columns = [Column("a", parse_ch_type("Int32")), Column("b", parse_ch_type("Float64")), Column("c", parse_ch_type("String"))]
        @test column_positions(SchemaRow, columns) == [2, 1]
        @test column_positions(NamedTuple{(:c, :a),Tuple{String,Int}}, columns) == [3, 1]
        @test column_positions(Tuple{Int,Float64,String}, columns) == [1, 2, 3]
        err = try
            column_positions(NamedTuple{(:a, :zzz, :yyy),Tuple{Int,Int,Int}}, columns; what = "table t")
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin("zzz, yyy", err.msg) && occursin("table t", err.msg) && occursin("a, b, c", err.msg)
        @test_throws ArgumentError column_positions(Tuple{Int,Int}, columns)
    end

    @testset "serialize_row by plan writes fields as their columns" begin
        s = Serializer()
        plan = [1 => parse_ch_type("Float64"), 2 => parse_ch_type("Int32")]
        @test serialize_row(s, SchemaRow(1.5, 7), plan) == 12
        seekstart(s)
        @test deserialize(s, Float64) == 1.5 && deserialize(s, Int32) === Int32(7)
    end
end

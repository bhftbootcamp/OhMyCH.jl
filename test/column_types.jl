import OhMyCH: parse_column_type, parse_ch_type, julia_type,
    CHType, CHPrimitive, CHDateTime, CHDateTime64, CHFixedString,
    CHDecimal, CHEnum8, CHEnum16, CHNullable, CHLowCardinality,
    CHArray, CHTuple, CHMap

@testset verbose = true "parse_ch_type(...)" begin
    @testset "Case №1: Primitives" begin
        t = parse_ch_type("Int32")
        @test t isa CHPrimitive
        @test t.name == :Int32
        @test string(t) == "Int32"
    end

    @testset "Case №2: DateTime" begin
        t = parse_ch_type("DateTime")
        @test t isa CHDateTime
        @test t.tz === nothing
        @test string(t) == "DateTime"

        t = parse_ch_type("DateTime('UTC')")
        @test t isa CHDateTime
        @test t.tz == "UTC"
        @test string(t) == "DateTime('UTC')"
    end

    @testset "Case №3: DateTime64" begin
        t = parse_ch_type("DateTime64(3)")
        @test t isa CHDateTime64
        @test t.precision == 3
        @test t.tz === nothing
        @test string(t) == "DateTime64(3)"

        t = parse_ch_type("DateTime64(6, 'Europe/Moscow')")
        @test t isa CHDateTime64
        @test t.precision == 6
        @test t.tz == "Europe/Moscow"
        @test string(t) == "DateTime64(6, 'Europe/Moscow')"
    end

    @testset "Case №4: FixedString" begin
        t = parse_ch_type("FixedString(16)")
        @test t isa CHFixedString
        @test t.n == 16
        @test string(t) == "FixedString(16)"
    end

    @testset "Case №5: Decimal" begin
        t = parse_ch_type("Decimal(9, 2)")
        @test t isa CHDecimal
        @test t.P == 9
        @test t.S == 2
        @test string(t) == "Decimal(9, 2)"
    end

    @testset "Case №6: Enums" begin
        t = parse_ch_type("Enum8('a' = 1, 'b' = 2)")
        @test t isa CHEnum8
        @test string(t) == "Enum8"

        t = parse_ch_type("Enum16('c' = 3)")
        @test t isa CHEnum16
        @test string(t) == "Enum16"
    end

    @testset "Case №7: Nullable" begin
        t = parse_ch_type("Nullable(String)")
        @test t isa CHNullable
        @test t.inner isa CHPrimitive
        @test t.inner.name == :String
        @test string(t) == "Nullable(String)"
    end

    @testset "Case №8: LowCardinality" begin
        t = parse_ch_type("LowCardinality(String)")
        @test t isa CHLowCardinality
        @test t.inner isa CHPrimitive
        @test string(t) == "LowCardinality(String)"
    end

    @testset "Case №9: Array" begin
        t = parse_ch_type("Array(UInt8)")
        @test t isa CHArray
        @test t.inner isa CHPrimitive
        @test string(t) == "Array(UInt8)"
    end

    @testset "Case №10: Tuple" begin
        t = parse_ch_type("Tuple(Int32, String, Float64)")
        @test t isa CHTuple
        @test length(t.inner) == 3
        @test string(t) == "Tuple(Int32, String, Float64)"
    end

    @testset "Case №11: Map" begin
        t = parse_ch_type("Map(String, Int64)")
        @test t isa CHMap
        @test t.key isa CHPrimitive
        @test t.val isa CHPrimitive
        @test string(t) == "Map(String, Int64)"
    end

    @testset "Case №12: Nested round-trip" begin
        types = [
            "Map(String, Array(Nullable(UInt8)))",
            "Tuple(Date, Map(UInt8, UUID))",
            "Array(Map(String, Int32))",
            "Nullable(Decimal(18, 4))",
            "LowCardinality(Nullable(String))",
        ]
        for s in types
            @test string(parse_ch_type(s)) == s
        end
    end

    @testset "Case №13: Errors" begin
        @test_throws ArgumentError parse_ch_type("")
        @test_throws ArgumentError parse_ch_type("UnknownType")
    end
end

@testset verbose = true "Column types" begin
    @testset "Case №1: Integers" begin
        @test parse_column_type("Bool")    == Bool
        @test parse_column_type("UInt8")   == UInt8
        @test parse_column_type("UInt16")  == UInt16
        @test parse_column_type("UInt32")  == UInt32
        @test parse_column_type("UInt64")  == UInt64
        @test parse_column_type("UInt128") == UInt128
        @test parse_column_type("Int8")    == Int8
        @test parse_column_type("Int16")   == Int16
        @test parse_column_type("Int32")   == Int32
        @test parse_column_type("Int64")   == Int64
        @test parse_column_type("Int128")  == Int128
    end

    @testset "Case №2: Floats" begin
        @test parse_column_type("Float32") == Float32
        @test parse_column_type("Float64") == Float64
    end

    @testset "Case №3: Decimals" begin
        @test parse_column_type("Decimal(9, 2)")  == Decimal{9,2}
        @test parse_column_type("Decimal(18, 10)") == Decimal{18,10}
        @test parse_column_type("Decimal(34, 24)") == Decimal{34,24}
    end

    @testset "Case №4: Enums" begin
        @test parse_column_type("Enum8('a' = 1, 'b' = 2)")  == UInt8
        @test parse_column_type("Enum16('c' = 3, 'd' = 4)") == UInt16
    end

    @testset "Case №5: Strings" begin
        @test parse_column_type("String")         == String
        @test parse_column_type("FixedString(5)") == FixedString{5}
    end

    @testset "Case №6: Dates" begin
        @test parse_column_type("Date")          == Date
        @test parse_column_type("DateTime")      == DateTime
        @test parse_column_type("DateTime64")    == NanoDate
        @test parse_column_type("DateTime64(3)") == NanoDate
    end

    @testset "Case №7: UUID & IPv4/IPv6" begin
        @test parse_column_type("UUID") == UUID
        @test parse_column_type("IPv4") == IPv4
        @test parse_column_type("IPv6") == IPv6
    end

    @testset "Case №8: Nullable" begin
        @test parse_column_type("Nullable(String)")         == Union{Nothing,String}
        @test parse_column_type("Nullable(Int8)")           == Union{Nothing,Int8}
        @test parse_column_type("Nullable(Int16)")          == Union{Nothing,Int16}
        @test parse_column_type("Nullable(Int32)")          == Union{Nothing,Int32}
        @test parse_column_type("Nullable(Int64)")          == Union{Nothing,Int64}
        @test parse_column_type("Nullable(UInt8)")          == Union{Nothing,UInt8}
        @test parse_column_type("Nullable(UInt16)")         == Union{Nothing,UInt16}
        @test parse_column_type("Nullable(UInt32)")         == Union{Nothing,UInt32}
        @test parse_column_type("Nullable(UInt64)")         == Union{Nothing,UInt64}
        @test parse_column_type("Nullable(Float32)")        == Union{Nothing,Float32}
        @test parse_column_type("Nullable(Float64)")        == Union{Nothing,Float64}
        @test parse_column_type("Nullable(Decimal(9, 2))")  == Union{Nothing,Decimal{9,2}}
        @test parse_column_type("Nullable(Decimal(18, 2))") == Union{Nothing,Decimal{18,2}}
        @test parse_column_type("Nullable(Decimal(34, 2))") == Union{Nothing,Decimal{34,2}}
        @test parse_column_type("Nullable(Date)")           == Union{Nothing,Date}
        @test parse_column_type("Nullable(DateTime)")       == Union{Nothing,DateTime}
        @test parse_column_type("Nullable(DateTime64)")     == Union{Nothing,NanoDate}
        @test parse_column_type("Nullable(FixedString(5))") == Union{Nothing,FixedString{5}}
        @test parse_column_type("Nullable(UUID)")           == Union{Nothing,Base.UUID}
    end

    @testset "Case №9: LowCardinality" begin
        @test parse_column_type("LowCardinality(String)") == String
        @test parse_column_type("LowCardinality(Int64)")  == Int64
    end

    @testset "Case №10: Vectors" begin
        @test parse_column_type("Array(UInt8)")       == Vector{UInt8}
        @test parse_column_type("Array(Int32)")       == Vector{Int32}
        @test parse_column_type("Array(Float64)")     == Vector{Float64}
        @test parse_column_type("Array(String)")      == Vector{String}
        @test parse_column_type("Array(Array(Date))") == Vector{Vector{Date}}
    end

    @testset "Case №11: Tuples" begin
        @test parse_column_type("Tuple(UInt8, Int32, Float64)")  == Tuple{UInt8,Int32,Float64}
        @test parse_column_type("Tuple(String, FixedString(5))") == Tuple{String,FixedString{5}}
        @test parse_column_type("Tuple(Date, DateTime)")         == Tuple{Date,DateTime}
    end

    @testset "Case №12: Dictionaries" begin
        @test parse_column_type("Map(String, UInt8)")            == Dict{String,UInt8}
        @test parse_column_type("Map(UInt8, String)")            == Dict{UInt8,String}
        @test parse_column_type("Map(String, Array(UInt8))")     == Dict{String,Vector{UInt8}}
        @test parse_column_type("Map(String, Nullable(UInt8))")  == Dict{String,Union{Nothing,UInt8}}
    end

    @testset "Case №13: Complex types" begin
        @test parse_column_type("Array(Map(String, Int32))")                                   == Vector{Dict{String,Int32}}
        @test parse_column_type("Tuple(Date, Map(UInt8, UUID))")                               == Tuple{Date,Dict{UInt8,UUID}}
        @test parse_column_type("Map(String, Array(Nullable(UInt8)))")                         == Dict{String,Vector{Union{Nothing,UInt8}}}
        @test parse_column_type("Map(String, Tuple(Nullable(String), LowCardinality(Int64)))") == Dict{String,Tuple{Union{Nothing,String},Int64}}
    end
end

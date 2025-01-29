#__ column_types

import OhMyCH: parse_column_type

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

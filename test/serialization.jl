#__ Serialization

import OhMyCH: Serializer, serialize, deserialize

@testset verbose = true "(De)Serilization" begin
    @testset "Case №1: Unsigned" begin
        s = Serializer()

        @test serialize(s, UInt8, UInt8(1)) == 1
        @test serialize(s, UInt16, UInt16(2)) == 2
        @test serialize(s, UInt32, UInt32(3)) == 4
        @test serialize(s, UInt64, UInt64(4)) == 8

        seekstart(s)

        @test deserialize(s, UInt8) == UInt8(1)
        @test deserialize(s, UInt16) == UInt16(2)
        @test deserialize(s, UInt32) == UInt32(3)
        @test deserialize(s, UInt64) == UInt64(4)

        @test eof(s)
    end

    @testset "Case №2: Integers" begin
        s = Serializer()

        @test serialize(s, Int8, Int8(1)) == 1
        @test serialize(s, Int16, Int16(2)) == 2
        @test serialize(s, Int32, Int32(3)) == 4
        @test serialize(s, Int64, Int64(4)) == 8

        seekstart(s)

        @test deserialize(s, Int8) == Int8(1)
        @test deserialize(s, Int16) == Int16(2)
        @test deserialize(s, Int32) == Int32(3)
        @test deserialize(s, Int64) == Int64(4)

        @test eof(s)
    end

    @testset "Case №3: Floats" begin
        s = Serializer()

        @test serialize(s, Float32, Float32(1)) == 4
        @test serialize(s, Float64, Float64(2)) == 8

        seekstart(s)

        @test deserialize(s, Float32) == Float32(1)
        @test deserialize(s, Float64) == Float64(2)

        @test eof(s)
    end

    @testset "Case №4: Bools" begin
        s = Serializer()

        @test serialize(s, Bool, true) == 1
        @test serialize(s, Bool, false) == 1

        seekstart(s)

        @test deserialize(s, Bool) == true
        @test deserialize(s, Bool) == false

        @test eof(s)
    end

    @testset "Case №5: Strings" begin
        s = Serializer()

        @test serialize(s, String, "1234567890abcdef") == 17
        @test serialize(s, String, "안녕하세요!") == 17
        @test serialize(s, String, "") == 1

        seekstart(s)

        @test deserialize(s, String) == "1234567890abcdef"
        @test deserialize(s, String) == "안녕하세요!"
        @test deserialize(s, String) == ""

        @test eof(s)
    end

    @testset "Case №6: Nullable" begin
        s = Serializer()

        @test serialize(s, Union{Nothing,String}, nothing) == 1
        @test serialize(s, Union{Nothing,String}, "nothing") == 9

        seekstart(s)

        @test deserialize(s, Union{Nothing,String}) === nothing
        @test deserialize(s, Union{Nothing,String}) == "nothing"

        @test eof(s)
    end

    @testset "Case №7: Dates" begin
        s = Serializer()

        @test serialize(s, Time, Time("12:3:45")) == 4
        @test serialize(s, Date, Date("2020-01-01")) == 2
        @test serialize(s, DateTime, DateTime("2020-01-01T12:00:00")) == 4
        @test serialize(s, NanoDate, NanoDate("2023-11-25T23:59:59.333333335")) == 8

        seekstart(s)

        @test deserialize(s, Time) == Time("12:03:45")
        @test deserialize(s, Date) == Date("2020-01-01")
        @test deserialize(s, DateTime) == DateTime("2020-01-01T12:00:00")
        @test deserialize(s, NanoDate) == NanoDate("2023-11-25T23:59:59.333333335")

        @test eof(s)
    end

    @testset "Case №8: UUIDs" begin
        s = Serializer()

        @test serialize(s, UUID, UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11")) == 16
        @test serialize(s, UUID, UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e")) == 16
        @test serialize(s, UUID, UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58")) == 16

        seekstart(s)

        @test deserialize(s, UUID) == UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11")
        @test deserialize(s, UUID) == UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e")
        @test deserialize(s, UUID) == UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58")

        @test eof(s)
    end

    @testset "Case №9: IPv4 & IPv6" begin
        s = Serializer()

        @test serialize(s, IPv4, IPv4("192.168.0.1")) == 4
        @test serialize(s, IPv6, IPv6("::ffff:192.168.0.1")) == 16

        seekstart(s)

        @test deserialize(s, IPv4) == IPv4("192.168.0.1")
        @test deserialize(s, IPv6) == IPv6("::ffff:192.168.0.1")

        @test eof(s)
    end

    @testset "Case №10: Vectors" begin
        s = Serializer()

        @test serialize(s, Vector{UInt8}, UInt8[1, 2, 3, 4]) == 5
        @test serialize(s, Vector{Int64}, Int64[1, 2, 3, 4]) == 33
        @test serialize(s, Vector{Float64}, Float64[1, 2, 3, 4]) == 33
        @test serialize(s, Vector{Bool}, Bool[true, false, true, false]) == 5
        @test serialize(s, Vector{String}, String["1234567890", "", "안녕하세요!", "abcdef"]) == 37
        @test serialize(s, Vector{Union{Nothing,Int64}}, Union{Nothing,Int64}[1, nothing, 3, nothing]) == 21
        @test serialize(s, Vector{Time}, Time[Time("1:1:1"), Time("2:2:2"), Time("3:3:3"), Time("4:4:4")]) == 17
        @test serialize(s, Vector{Date}, Date[Date("2021"), Date("2022"), Date("2023"), Date("2024")]) == 9
        @test serialize(
            s,
            Vector{DateTime},
            DateTime[
                DateTime("2021-01-01T1:1:1"),
                DateTime("2022-02-02T2:2:2"),
                DateTime("2023-03-03T3:3:3"),
                DateTime("2024-04-04T4:4:4"),
            ],
        ) == 17
        @test serialize(
            s,
            Vector{NanoDate},
            NanoDate[
                NanoDate("2021-01-01T01:01:01.111111111"),
                NanoDate("2022-02-02T02:02:02.222222222"),
                NanoDate("2023-03-03T03:03:03.333333333"),
                NanoDate("2024-04-04T04:04:04.333333333"),
            ],
        ) == 33
        @test serialize(
            s,
            Vector{UUID},
            UUID[
                UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
                UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e"),
                UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58"),
            ],
        ) == 49
        @test serialize(
            s,
            Vector{IPv4},
            IPv4[
                IPv4("192.168.0.1"),
                IPv4("192.168.0.2"),
                IPv4("192.168.0.3"),
            ],
        ) == 13
        @test serialize(
            s,
            Vector{IPv6},
            IPv6[
                IPv6("::ffff:192.168.0.1"),
                IPv6("::ffff:192.168.0.2"),
                IPv6("::ffff:192.168.0.3"),
            ],
        ) == 49

        seekstart(s)

        @test deserialize(s, Vector{UInt8}) == UInt8[1, 2, 3, 4]
        @test deserialize(s, Vector{Int64}) == Int64[1, 2, 3, 4]
        @test deserialize(s, Vector{Float64}) == Float64[1, 2, 3, 4]
        @test deserialize(s, Vector{Bool}) == Bool[true, false, true, false]
        @test deserialize(s, Vector{String}) == String["1234567890", "", "안녕하세요!", "abcdef"]
        @test deserialize(s, Vector{Union{Nothing,Int64}}) == Union{Nothing,Int64}[1, nothing, 3, nothing]
        @test deserialize(s, Vector{Time}) == Time[Time("1:1:1"), Time("2:2:2"), Time("3:3:3"), Time("4:4:4")]
        @test deserialize(s, Vector{Date}) == Date[Date("2021"), Date("2022"), Date("2023"), Date("2024")]
        @test deserialize(s, Vector{DateTime}) == DateTime[
            DateTime("2021-01-01T1:1:1"),
            DateTime("2022-02-02T2:2:2"),
            DateTime("2023-03-03T3:3:3"),
            DateTime("2024-04-04T4:4:4"),
        ]
        @test deserialize(s, Vector{NanoDate}) == NanoDate[
            NanoDate("2021-01-01T01:01:01.111111111"),
            NanoDate("2022-02-02T02:02:02.222222222"),
            NanoDate("2023-03-03T03:03:03.333333333"),
            NanoDate("2024-04-04T04:04:04.333333333"),
        ]
        @test deserialize(s, Vector{UUID}) == UUID[
            UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
            UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e"),
            UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58"),
        ]
        @test deserialize(s, Vector{IPv4}) == IPv4[
            IPv4("192.168.0.1"),
            IPv4("192.168.0.2"),
            IPv4("192.168.0.3"),
        ]
        @test deserialize(s, Vector{IPv6}) == IPv6[
            IPv6("::ffff:192.168.0.1"),
            IPv6("::ffff:192.168.0.2"),
            IPv6("::ffff:192.168.0.3"),
        ]

        @test eof(s)
    end

    @testset "Case №11: NTuples" begin
        s = Serializer()

        @test serialize(s, NTuple{4,UInt8}, NTuple{4,UInt8}([1, 2, 3, 4])) == 4
        @test serialize(s, NTuple{4,Int64}, NTuple{4,Int64}([1, 2, 3, 4])) == 32
        @test serialize(s, NTuple{4,Float64}, NTuple{4,Float64}([1, 2, 3, 4])) == 32
        @test serialize(s, NTuple{4,Bool}, NTuple{4,Bool}([true, false, true, false])) == 4
        @test serialize(s, NTuple{4,String}, NTuple{4,String}(["1234567890", "", "안녕하세요!", "abcdef"])) == 36
        @test serialize(s, NTuple{4,Union{Nothing,Int64}}, NTuple{4,Union{Nothing,Int64}}([1, nothing, 3, nothing])) == 20
        @test serialize(s, NTuple{4,Time}, NTuple{4,Time}([Time("1:1:1"), Time("2:2:2"), Time("3:3:3"), Time("4:4:4")])) == 16
        @test serialize(s, NTuple{4,Date}, NTuple{4,Date}([Date("2021"), Date("2022"), Date("2023"), Date("2024")])) == 8
        @test serialize(
            s,
            NTuple{4,DateTime},
            NTuple{4,DateTime}([
                DateTime("2021-01-01T1:1:1"),
                DateTime("2022-02-02T2:2:2"),
                DateTime("2023-03-03T3:3:3"),
                DateTime("2024-04-04T4:4:4"),
            ]),
        ) == 16
        @test serialize(
            s,
            NTuple{4,NanoDate},
            NTuple{4,NanoDate}([
                NanoDate("2021-01-01T01:01:01.111111111"),
                NanoDate("2022-02-02T02:02:02.222222222"),
                NanoDate("2023-03-03T03:03:03.333333333"),
                NanoDate("2024-04-04T04:04:04.333333333"),
            ]),
        ) == 32
        @test serialize(
            s,
            NTuple{3,UUID},
            NTuple{3,UUID}([
                UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
                UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e"),
                UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58"),
            ]),
        ) == 48
        @test serialize(
            s,
            NTuple{3,IPv4},
            NTuple{3,IPv4}([
                IPv4("192.168.0.1"),
                IPv4("192.168.0.2"),
                IPv4("192.168.0.3"),
            ]),
        ) == 12
        @test serialize(
            s,
            NTuple{3,IPv6},
            NTuple{3,IPv6}([
                IPv6("::ffff:192.168.0.1"),
                IPv6("::ffff:192.168.0.2"),
                IPv6("::ffff:192.168.0.3"),
            ]),
        ) == 48

        seekstart(s)

        @test deserialize(s, NTuple{4,UInt8}) == NTuple{4,UInt8}([1, 2, 3, 4])
        @test deserialize(s, NTuple{4,Int64}) == NTuple{4,Int64}([1, 2, 3, 4])
        @test deserialize(s, NTuple{4,Float64}) == NTuple{4,Float64}([1, 2, 3, 4])
        @test deserialize(s, NTuple{4,Bool}) == NTuple{4,Bool}([true, false, true, false])
        @test deserialize(s, NTuple{4,String}) == NTuple{4,String}(["1234567890", "", "안녕하세요!", "abcdef"])
        @test deserialize(s, NTuple{4,Union{Nothing,Int64}}) == NTuple{4,Union{Nothing,Int64}}([1, nothing, 3, nothing])
        @test deserialize(s, NTuple{4,Time}) == NTuple{4,Time}([Time("1:1:1"), Time("2:2:2"), Time("3:3:3"), Time("4:4:4")])
        @test deserialize(s, NTuple{4,Date}) == NTuple{4,Date}([Date("2021"), Date("2022"), Date("2023"), Date("2024")])
        @test deserialize(s, NTuple{4,DateTime}) == NTuple{4,DateTime}([
            DateTime("2021-01-01T1:1:1"),
            DateTime("2022-02-02T2:2:2"),
            DateTime("2023-03-03T3:3:3"),
            DateTime("2024-04-04T4:4:4"),
        ])
        @test deserialize(s, NTuple{4,NanoDate}) == NTuple{4,NanoDate}([
            NanoDate("2021-01-01T01:01:01.111111111"),
            NanoDate("2022-02-02T02:02:02.222222222"),
            NanoDate("2023-03-03T03:03:03.333333333"),
            NanoDate("2024-04-04T04:04:04.333333333"),
        ])
        @test deserialize(s, NTuple{3,UUID}) == NTuple{3,UUID}([
            UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
            UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e"),
            UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58"),
        ])
        @test deserialize(s, NTuple{3,IPv4}) == NTuple{3,IPv4}([
            IPv4("192.168.0.1"),
            IPv4("192.168.0.2"),
            IPv4("192.168.0.3"),
        ])
        @test deserialize(s, NTuple{3,IPv6}) == NTuple{3,IPv6}([
            IPv6("::ffff:192.168.0.1"),
            IPv6("::ffff:192.168.0.2"),
            IPv6("::ffff:192.168.0.3"),
        ])

        @test eof(s)
    end

    @testset "Case №12: Tuples" begin
        s = Serializer()

        @test serialize(s, Tuple{UInt8,Int64,Float64,Bool}, (UInt8(1), Int64(2), Float64(3), true)) == 18
        @test serialize(
            s,
            Tuple{String,Union{Nothing,String},String},
            ("1234567890", nothing, "안녕하세요!"),
        ) == 29
        @test serialize(
            s,
            Tuple{Time,Date,DateTime,NanoDate},
            (
                Time("1:1:1"),
                Date("2021"),
                DateTime("2021-01-01T1:1:1"),
                NanoDate("2021-01-01T01:01:01.111111111"),
            ),
        ) == 18
        @test serialize(
            s,
            Tuple{UUID,IPv4,IPv6},
            (
                UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
                IPv4("192.168.0.1"),
                IPv6("::ffff:192.168.0.1"),
            ),
        ) == 36

        seekstart(s)

        @test deserialize(s, Tuple{UInt8,Int64,Float64,Bool}) == (UInt8(1), Int64(2), Float64(3), true)
        @test deserialize(s, Tuple{String,Union{Nothing,String},String}) == ("1234567890", nothing, "안녕하세요!")
        @test deserialize(s, Tuple{Time,Date,DateTime,NanoDate}) == (
            Time("1:1:1"),
            Date("2021"),
            DateTime("2021-01-01T1:1:1"),
            NanoDate("2021-01-01T01:01:01.111111111"),
        )
        @test deserialize(s, Tuple{UUID,IPv4,IPv6}) == (
            UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
            IPv4("192.168.0.1"),
            IPv6("::ffff:192.168.0.1"),
        )

        @test eof(s)
    end

    @testset "Case №13: Dictionaries" begin
        s = Serializer()

        @test serialize(s, Dict{String,UInt8}, Dict{String,UInt8}(
            "key1" => UInt8(1),
            "key2" => UInt8(2),
            "key3" => UInt8(3),
        )) == 19
        @test serialize(s, Dict{String,Int64}, Dict{String,Int64}(
            "key1" => Int64(1),
            "key2" => Int64(2),
            "key3" => Int64(3),
        )) == 40
        @test serialize(s, Dict{String,Float64}, Dict{String,Float64}(
            "key1" => Float64(1),
            "key2" => Float64(2),
            "key3" => Float64(3),
        )) == 40
        @test serialize(s, Dict{String,Bool}, Dict{String,Bool}(
            "key1" => true,
            "key2" => false,
            "key3" => true,
        )) == 19
        @test serialize(s, Dict{String,String}, Dict{String,String}(
            "key1" => "1234567890",
            "key2" => "",
            "key3" => "안녕하세요!",
        )) == 45
        @test serialize(s, Dict{String,Union{Nothing,Int64}}, Dict{String,Union{Nothing,Int64}}(
            "key1" => 1,
            "key2" => nothing,
            "key3" => 3,
        )) == 35
        @test serialize(s, Dict{String,Time}, Dict{String,Time}(
            "key1" => Time("1:1:1"),
            "key2" => Time("2:2:2"),
            "key3" => Time("3:3:3"),
        )) == 28
        @test serialize(s, Dict{String,Date}, Dict{String,Date}(
            "key1" => Date("2021"),
            "key2" => Date("2022"),
            "key3" => Date("2023"),
        )) == 22
        @test serialize(s, Dict{String,DateTime}, Dict{String,DateTime}(
            "key1" => DateTime("2021-01-01T1:1:1"),
            "key2" => DateTime("2022-02-02T2:2:2"),
            "key3" => DateTime("2023-03-03T3:3:3"),
        )) == 28
        @test serialize(s, Dict{String,NanoDate}, Dict{String,NanoDate}(
            "key1" => NanoDate("2021-01-01T01:01:01.111111111"),
            "key2" => NanoDate("2022-02-02T02:02:02.222222222"),
            "key3" => NanoDate("2023-03-03T03:03:03.333333333"),
        )) == 40
        @test serialize(s, Dict{String,UUID}, Dict{String,UUID}(
            "key1" => UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
            "key2" => UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e"),
            "key3" => UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58"),
        )) == 64
        @test serialize(s, Dict{String,IPv4},  Dict{String,IPv4}(
            "key1" => IPv4("192.168.0.1"),
            "key2" => IPv4("192.168.0.2"),
            "key3" => IPv4("192.168.0.3"),
        )) == 28
        @test serialize(s, Dict{String,IPv6},  Dict{String,IPv6}(
            "key1" => IPv6("::ffff:192.168.0.1"),
            "key2" => IPv6("::ffff:192.168.0.2"),
            "key3" => IPv6("::ffff:192.168.0.3"),
        )) == 64

        seekstart(s)

        @test deserialize(s, Dict{String,UInt8}) == Dict{String,UInt8}(
            "key1" => UInt8(1),
            "key2" => UInt8(2),
            "key3" => UInt8(3),
        )
        @test deserialize(s, Dict{String,Int64}) == Dict{String,Int64}(
            "key1" => Int64(1),
            "key2" => Int64(2),
            "key3" => Int64(3),
        )
        @test deserialize(s, Dict{String,Float64}) == Dict{String,Float64}(
            "key1" => Float64(1),
            "key2" => Float64(2),
            "key3" => Float64(3),
        )
        @test deserialize(s, Dict{String,Bool}) == Dict{String,Bool}(
            "key1" => true,
            "key2" => false,
            "key3" => true,
        )
        @test deserialize(s, Dict{String,String}) == Dict{String,String}(
            "key1" => "1234567890",
            "key2" => "",
            "key3" => "안녕하세요!",
        )
        @test deserialize(s, Dict{String,Union{Nothing,Int64}}) == Dict{String,Union{Nothing,Int64}}(
            "key1" => 1,
            "key2" => nothing,
            "key3" => 3,
        )
        @test deserialize(s, Dict{String,Time}) == Dict{String,Time}(
            "key1" => Time("1:1:1"),
            "key2" => Time("2:2:2"),
            "key3" => Time("3:3:3"),
        )
        @test deserialize(s, Dict{String,Date}) == Dict{String,Date}(
            "key1" => Date("2021"),
            "key2" => Date("2022"),
            "key3" => Date("2023"),
        )
        @test deserialize(s, Dict{String,DateTime}) == Dict{String,DateTime}(
            "key1" => DateTime("2021-01-01T1:1:1"),
            "key2" => DateTime("2022-02-02T2:2:2"),
            "key3" => DateTime("2023-03-03T3:3:3"),
        )
        @test deserialize(s, Dict{String,NanoDate}) == Dict{String,NanoDate}(
            "key1" => NanoDate("2021-01-01T01:01:01.111111111"),
            "key2" => NanoDate("2022-02-02T02:02:02.222222222"),
            "key3" => NanoDate("2023-03-03T03:03:03.333333333"),
        )
        @test deserialize(s, Dict{String,UUID}) == Dict{String,UUID}(
            "key1" => UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
            "key2" => UUID("5b90644b-7aa0-17f0-5b66-46901ceaab4e"),
            "key3" => UUID("794f1703-2e75-797b-1dc7-bd1609e4cc58"),
        )
        @test deserialize(s, Dict{String,IPv4}) == Dict{String,IPv4}(
            "key1" => IPv4("192.168.0.1"),
            "key2" => IPv4("192.168.0.2"),
            "key3" => IPv4("192.168.0.3"),
        )
        @test deserialize(s, Dict{String,IPv6}) == Dict{String,IPv6}(
            "key1" => IPv6("::ffff:192.168.0.1"),
            "key2" => IPv6("::ffff:192.168.0.2"),
            "key3" => IPv6("::ffff:192.168.0.3"),
        )

        @test eof(s)
    end

    @testset "Case №14: Decimals" begin
        s = Serializer()

        @test serialize(s, Decimal{4,0}, Decimal{4,0}("1234.")) == 4
        @test serialize(s, Decimal{4,1}, Decimal{4,1}("123.4")) == 4
        @test serialize(s, Decimal{4,2}, Decimal{4,2}("12.34")) == 4
        @test serialize(s, Decimal{4,4}, Decimal{4,4}(".1234")) == 4

        @test serialize(s, Decimal{8,0}, Decimal{8,0}("12345678.")) == 4
        @test serialize(s, Decimal{8,1}, Decimal{8,1}("1234567.8")) == 4
        @test serialize(s, Decimal{8,4}, Decimal{8,4}("1234.5678")) == 4
        @test serialize(s, Decimal{8,8}, Decimal{8,8}(".12345678")) == 4

        @test serialize(s, Decimal{9,0}, Decimal{9,0}("123456789.")) == 4
        @test serialize(s, Decimal{9,1}, Decimal{9,1}("12345678.9")) == 4
        @test serialize(s, Decimal{9,4}, Decimal{9,4}("12345.6789")) == 4
        @test serialize(s, Decimal{9,9}, Decimal{9,9}(".123456789")) == 4

        @test serialize(s, Decimal{16,0}, Decimal{16,0}("1234567890123456.")) == 8
        @test serialize(s, Decimal{16,1}, Decimal{16,1}("123456789012345.6")) == 8
        @test serialize(s, Decimal{16,8}, Decimal{16,8}("12345678.90123456")) == 8
        @test serialize(s, Decimal{16,16}, Decimal{16,16}(".1234567890123456")) == 8

        @test serialize(s, Decimal{17,0}, Decimal{17,0}("12345678901234567.")) == 8
        @test serialize(s, Decimal{17,1}, Decimal{17,1}("1234567890123456.7")) == 8
        @test serialize(s, Decimal{17,8}, Decimal{17,8}("123456789.01234567")) == 8
        @test serialize(s, Decimal{17,17}, Decimal{17,17}(".12345678901234567")) == 8

        @test serialize(s, Decimal{20,0}, Decimal{20,0}("12345678901234567890.")) == 16
        @test serialize(s, Decimal{20,1}, Decimal{20,1}("1234567890123456789.0")) == 16
        @test serialize(s, Decimal{20,10}, Decimal{20,10}("1234567890.1234567890")) == 16
        @test serialize(s, Decimal{20,20}, Decimal{20,20}(".12345678901234567890")) == 16

        @test serialize(s, Decimal{34,0}, Decimal{34,0}("1234567890123456789012345678901234.")) == 16
        @test serialize(s, Decimal{34,1}, Decimal{34,1}("123456789012345678901234567890123.4")) == 16
        @test serialize(s, Decimal{34,17}, Decimal{34,17}("12345678901234567.89012345678901234")) == 16
        @test serialize(s, Decimal{34,34}, Decimal{34,34}(".1234567890123456789012345678901234")) == 16

        seekstart(s)

        @test deserialize(s, Decimal{4,0}) == Decimal{4,0}("1234.")
        @test deserialize(s, Decimal{4,1}) == Decimal{4,1}("123.4")
        @test deserialize(s, Decimal{4,2}) == Decimal{4,2}("12.34")
        @test deserialize(s, Decimal{4,4}) == Decimal{4,4}(".1234")

        @test deserialize(s, Decimal{8,0}) == Decimal{8,0}("12345678.")
        @test deserialize(s, Decimal{8,1}) == Decimal{8,1}("1234567.8")
        @test deserialize(s, Decimal{8,4}) == Decimal{8,4}("1234.5678")
        @test deserialize(s, Decimal{8,8}) == Decimal{8,8}(".12345678")

        @test deserialize(s, Decimal{9,0}) == Decimal{9,0}("123456789.")
        @test deserialize(s, Decimal{9,1}) == Decimal{9,1}("12345678.9")
        @test deserialize(s, Decimal{9,4}) == Decimal{9,4}("12345.6789")
        @test deserialize(s, Decimal{9,9}) == Decimal{9,9}(".123456789")

        @test deserialize(s, Decimal{16,0}) == Decimal{16,0}("1234567890123456.")
        @test deserialize(s, Decimal{16,1}) == Decimal{16,1}("123456789012345.6")
        @test deserialize(s, Decimal{16,8}) == Decimal{16,8}("12345678.90123456")
        @test deserialize(s, Decimal{16,16}) == Decimal{16,16}(".1234567890123456")

        @test deserialize(s, Decimal{17,0}) == Decimal{17,0}("12345678901234567.")
        @test deserialize(s, Decimal{17,1}) == Decimal{17,1}("1234567890123456.7")
        @test deserialize(s, Decimal{17,8}) == Decimal{17,8}("123456789.01234567")
        @test deserialize(s, Decimal{17,17}) == Decimal{17,17}(".12345678901234567")

        @test deserialize(s, Decimal{20,0}) == Decimal{20,0}("12345678901234567890.")
        @test deserialize(s, Decimal{20,1}) == Decimal{20,1}("1234567890123456789.0")
        @test deserialize(s, Decimal{20,10}) == Decimal{20,10}("1234567890.1234567890")
        @test deserialize(s, Decimal{20,20}) == Decimal{20,20}(".12345678901234567890")

        @test deserialize(s, Decimal{34,0}) == Decimal{34,0}("1234567890123456789012345678901234.")
        @test deserialize(s, Decimal{34,1}) == Decimal{34,1}("123456789012345678901234567890123.4")
        @test deserialize(s, Decimal{34,17}) == Decimal{34,17}("12345678901234567.89012345678901234")
        @test deserialize(s, Decimal{34,34}) == Decimal{34,34}(".1234567890123456789012345678901234")

        @test eof(s)
    end

    @testset "Case №15: FixedStrings" begin
        s = Serializer()

        @test serialize(s, FixedString{10}, FixedString{10}("1234567890")) == 10
        @test serialize(s, FixedString{5}, FixedString{5}("")) == 5
        @test serialize(s, FixedString{16}, FixedString{16}("안녕하세요!")) == 16
        @test serialize(s, FixedString{6}, FixedString{6}("abcdef")) == 6

        seekstart(s)

        @test deserialize(s, FixedString{10}) == FixedString{10}("1234567890")
        @test deserialize(s, FixedString{5}) == FixedString{5}("")
        @test deserialize(s, FixedString{16}) == FixedString{16}("안녕하세요!")
        @test deserialize(s, FixedString{6}) == FixedString{6}("abcdef")

        @test eof(s)
    end

    @testset "Case №16: Custom type" begin
        struct Foo
            uint8::UInt8
            uint16::UInt16
            uint32::UInt32
            uint64::UInt64
            int8::Int8
            int16::Int16
            int32::Int32
            int64::Int64
            float32::Float32
            float64::Float64
            boolean1::Bool
            boolean2::Bool
            str::String
            nullable_str1::Union{Nothing,String}
            nullable_str2::Union{Nothing,String}
            date::Date
            datetime::DateTime
            nanodate::NanoDate
            uuid::UUID
            ipv4::IPv4
            ipv6::IPv6
            vector_nullable_str::Vector{Union{Nothing,String}}
            vector_int64::Vector{Int64}
            tuple_str_str::Tuple{String,String}
            tuple_uint8_3::Tuple{UInt8,UInt8,UInt8}
            dict_nullable_str::Dict{String,Union{Nothing,String}}
            decimal1::Decimal{9,4}
            decimal2::Decimal{17,8}
            decimal3::Decimal{34,18}
            fixedstring5::FixedString{5}
        end

        s = Serializer()

        foo_1 = Foo(
            UInt8(1),
            UInt16(2),
            UInt32(3),
            UInt64(4),
            Int8(-1),
            Int16(-2),
            Int32(-3),
            Int64(-4),
            Float32(1.23),
            Float64(4.56),
            true,
            false,
            "example string",
            nothing,
            "nullable string",
            Date(2020, 1, 1),
            DateTime(2020, 1, 1, 12, 0, 0),
            NanoDate("2023-11-25T23:59:59.333333335"),
            UUID("61f0c404-5cb3-11e7-907b-a6006ad3db11"),
            IPv4("192.168.0.1"),
            IPv6("::ffff:192.168.0.1"),
            ["test", nothing, "value"],
            [1, 2, 3, 4],
            ("tuple1", "tuple2"),
            (UInt8(5), UInt8(10), UInt8(15)),
            Dict("key1" => "value1", "key2" => nothing),
            Decimal{9,4}("12345.6789"),
            Decimal{17,8}("123456789.01234567"),
            Decimal{34,18}("1234567890123456.789012345678901234"),
            FixedString{5}("hello"),
        )

        @test serialize(s, foo_1) == 245

        seekstart(s)

        foo_2 = Foo(map(t -> deserialize(s, t), fieldtypes(Foo))...)

        @test all(name -> getfield(foo_1, name) == getfield(foo_2, name), fieldnames(Foo))

        @test eof(s)
    end
end

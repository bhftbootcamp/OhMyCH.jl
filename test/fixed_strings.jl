#__ FixedStrings

@testset verbose = true "Simple FixedString" begin
    fstr = FixedString{16}("0123456789abcdef")

    @testset "Case №1: Base string interface" begin
        @test length(fstr) == 16
        @test String(fstr) == "0123456789abcdef"

        @test "-- $fstr --" == "-- 0123456789abcdef --"
        @test string("-- ", fstr, " --") == "-- 0123456789abcdef --"

        io = IOBuffer()
        print(io, fstr)
        @test String(take!(io)) == "0123456789abcdef"

        io = IOBuffer()
        show(io, fstr)
        @test String(take!(io)) == """FixedString{16}("0123456789abcdef")"""

        @test repr(fstr) == "\"0123456789abcdef\""
    end

    @testset "Case №2: Iterations & indexing" begin
        @test isvalid(fstr)
        @test ncodeunits(fstr) == 16

        @test codeunit(fstr, 1) == 0x30
        @test codeunit(fstr, 2) == 0x31
        @test codeunit(fstr, 3) == 0x32

        @test collect(UInt8, fstr) == UInt8[
            0x30,
            0x31,
            0x32,
            0x33,
            0x34,
            0x35,
            0x36,
            0x37,
            0x38,
            0x39,
            0x61,
            0x62,
            0x63,
            0x64,
            0x65,
            0x66,
        ]

        @test codeunits(fstr) == UInt8[
            0x30,
            0x31,
            0x32,
            0x33,
            0x34,
            0x35,
            0x36,
            0x37,
            0x38,
            0x39,
            0x61,
            0x62,
            0x63,
            0x64,
            0x65,
            0x66,
        ]

        map(identity, fstr) == "0123456789abcdef"

        fstr[begin] == '0'
        fstr[1] == '0'
        fstr[2] == '1'
        fstr[3] == '2'
        fstr[end] == 'f'
    end

    @testset "Case №3: IO interface" begin
        io = IOBuffer()

        @test write(io, FixedString{6}("123")) == 6
        @test write(io, fstr) == 16
        @test write(io, FixedString{3}("!?%")) == 3

        seekstart(io)

        @test read(io, FixedString{6}) == "123"
        @test read(io, typeof(fstr)) == "0123456789abcdef"
        @test read(io, FixedString{3}) == "!?%"
    end
end

@testset verbose = true "Short FixedString" begin
    fstr = FixedString{16}("0123456789")

    @testset "Case №1: Base string interface" begin
        @test length(fstr) == 10
        @test String(fstr) == "0123456789"

        @test "-- $fstr --" == "-- 0123456789 --"
        @test string("-- ", fstr, " --") == "-- 0123456789 --"

        io = IOBuffer()
        print(io, fstr)
        @test String(take!(io)) == "0123456789"

        io = IOBuffer()
        show(io, fstr)
        @test String(take!(io)) == """FixedString{16}("0123456789")"""

        @test repr(fstr) == "\"0123456789\""
    end

    @testset "Case №2: Iterations & indexing" begin
        @test isvalid(fstr)
        @test ncodeunits(fstr) == 10

        @test codeunit(fstr, 1) == 0x30
        @test codeunit(fstr, 2) == 0x31
        @test codeunit(fstr, 3) == 0x32

        @test collect(UInt8, fstr) == UInt8[
            0x30,
            0x31,
            0x32,
            0x33,
            0x34,
            0x35,
            0x36,
            0x37,
            0x38,
            0x39,
        ]

        @test codeunits(fstr) == UInt8[
            0x30,
            0x31,
            0x32,
            0x33,
            0x34,
            0x35,
            0x36,
            0x37,
            0x38,
            0x39,
        ]

        map(identity, fstr) == "0123456789"

        fstr[begin] == '0'
        fstr[1] == '0'
        fstr[2] == '1'
        fstr[3] == '2'
        fstr[end] == '9'
    end

    @testset "Case №3: IO interface" begin
        io = IOBuffer()

        @test write(io, FixedString{6}("123")) == 6
        @test write(io, fstr) == 16
        @test write(io, FixedString{3}("!?%")) == 3

        seekstart(io)

        @test read(io, FixedString{6}) == "123"
        @test read(io, typeof(fstr)) == "0123456789"
        @test read(io, FixedString{3}) == "!?%"
    end
end

@testset verbose = true "FixedString with special symbols" begin
    fstr = FixedString{16}("안녕하세요!")

    @testset "Case №1: Base string interface" begin
        @test length(fstr) == 6
        @test String(fstr) == "안녕하세요!"

        @test "-- $fstr --" == "-- 안녕하세요! --"
        @test string("-- ", fstr, " --") == "-- 안녕하세요! --"

        io = IOBuffer()
        print(io, fstr)
        @test String(take!(io)) == "안녕하세요!"

        io = IOBuffer()
        show(io, fstr)
        @test String(take!(io)) == """FixedString{16}("안녕하세요!")"""

        @test repr(fstr) == "\"안녕하세요!\""
    end

    @testset "Case №2: Iterations & indexing" begin
        @test isvalid(fstr)
        @test ncodeunits(fstr) == 16

        @test codeunit(fstr, 1) == 0xec
        @test codeunit(fstr, 2) == 0x95
        @test codeunit(fstr, 3) == 0x88

        @test collect(UInt16, fstr) == UInt16[
            0xc548,
            0xb155,
            0xd558,
            0xc138,
            0xc694,
            0x0021,
        ]

        @test codeunits(fstr) == UInt8[
            0xec,
            0x95,
            0x88,
            0xeb,
            0x85,
            0x95,
            0xed,
            0x95,
            0x98,
            0xec,
            0x84,
            0xb8,
            0xec,
            0x9a,
            0x94,
            0x21,
        ]

        map(identity, fstr) == "안녕하세요!"

        fstr[begin] == '안'
        fstr[4] == '녕'
        fstr[end] == '!'
    end

    @testset "Case №3: IO interface" begin
        io = IOBuffer()

        @test write(io, FixedString{6}("123")) == 6
        @test write(io, fstr) == 16
        @test write(io, FixedString{3}("!?%")) == 3

        seekstart(io)

        @test read(io, FixedString{6}) == "123"
        @test read(io, typeof(fstr)) == "안녕하세요!"
        @test read(io, FixedString{3}) == "!?%"
    end
end

@testset verbose = true "Empty FixedString" begin
    fstr = FixedString{10}("")

    @testset "Case №1: Base string interface" begin
        @test length(fstr) == 0
        @test String(fstr) == ""

        @test "-- $fstr --" == "--  --"
        @test string("-- ", fstr, " --") == "--  --"

        io = IOBuffer()
        print(io, fstr)
        @test String(take!(io)) == ""

        io = IOBuffer()
        show(io, fstr)
        @test String(take!(io)) == """FixedString{10}("")"""

        @test repr(fstr) == "\"\""
    end

    @testset "Case №2: Iterations & indexing" begin
        @test isvalid(fstr)
        @test ncodeunits(fstr) == 0

        @test_throws Exception codeunit(fstr, 1)
        @test_throws Exception codeunit(fstr, 2)
        @test_throws Exception codeunit(fstr, 3)

        @test collect(UInt16, fstr) == UInt16[]

        @test codeunits(fstr) == UInt8[]

        map(identity, fstr) == ""

        @test_throws Exception fstr[begin]
        @test_throws Exception fstr[end]
    end

    @testset "Case №3: IO interface" begin
        io = IOBuffer()

        @test write(io, FixedString{6}("123")) == 6
        @test write(io, fstr) == 10
        @test write(io, FixedString{3}("!?%")) == 3

        seekstart(io)

        @test read(io, FixedString{6}) == "123"
        @test read(io, typeof(fstr)) == ""
        @test read(io, FixedString{3}) == "!?%"
    end
end

@testset verbose = true "Operations with FixedString" begin
    fstr = FixedString{16}("123.abc")

    @testset "Case №1: String tools" begin
        @test split(fstr, ".") == ["123", "abc"]
        @test reverse(fstr) == "cba.321"
        @test replace(fstr, "abc" => "!!!", "123" => "???") == "???.!!!"

        @test occursin(r"123", fstr)
        @test !occursin(r"321", fstr)

        @test findfirst('a', fstr) == 5
        @test findlast('3', fstr) == 3

        @test rstrip(fstr, ['a', 'b', 'c']) == "123."
        @test rpad(fstr, 10) == "123.abc   "

        @test repeat(fstr, 3) == "123.abc123.abc123.abc"
    end

    @testset "Case №2: String comparison" begin
        x = FixedString{3}("000")
        y = FixedString{3}("111")

        @test x < y
        @test !(x > y)

        @test isless(x, y)
        @test !isless(y, x)

        @test x == x
        @test x != y

        @test isequal(x, x)
        @test !isequal(x, y)

        @test sort([
            FixedString{3}("333"),
            FixedString{3}("111"),
            FixedString{3}("222"),
        ]) == [
            FixedString{3}("111"),
            FixedString{3}("222"),
            FixedString{3}("333"),
        ]
    end
end

@testset verbose = true "Invalid FixedString" begin
    @test_throws ArgumentError("Input string is longer than 8 bytes (16).") FixedString{8}("0123456789abcdef")
    @test_throws ArgumentError("FixedString size N must be positive.") FixedString{-1}("123")
end

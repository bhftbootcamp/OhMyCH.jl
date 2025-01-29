#__ examples

using OhMyCH
using NanoDates

client = ohmych_connect(
    "http://127.0.0.1:8123/",
    "default",
    "default",
    "",
)

const CREATE_QUERY = """
    CREATE TABLE IF NOT EXISTS my_trades (
        timestamp DateTime64(9),
        trade_id  UInt64,
        symbol    LowCardinality(String),
        side      Enum8('Bid' = 0, 'Ask' = 1),
        price     Decimal(34, 18),
        qty       Float64
    ) ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY timestamp
"""

OhMyCH.execute(client, CREATE_QUERY)

# OhMyCH.execute(client, "ALTER TABLE my_trades RENAME COLUMN qty TO quantity")

OhMyCH.insert(
    client,
    "INSERT INTO my_trades (timestamp, trade_id, symbol, side, price, quantity)",
    [
        (NanoDate("2025-01-15T08:00:00.123456789"), 1, "AAPL", UInt8(1), Decimal{34,18}("145.321234567890123456"), 100.0),
        (NanoDate("2025-01-15T08:05:00.987654321"), 2, "GOOG", UInt8(0), Decimal{34,18}("2745.50000000000000000"), 50.0),
        (NanoDate("2025-01-15T08:10:00.111222333"), 3, "TSLA", UInt8(0), Decimal{34,18}("652.801234567890123456"), 200.0),
        (NanoDate("2025-01-15T08:15:00.444555666"), 4, "AMZN", UInt8(1), Decimal{34,18}("3301.65000000000000000"), 30.0)
    ],
    chunk_size = 1024 * 1024, # 1 Mbyte
)

OhMyCH.insert(
    client,
    "INSERT INTO my_trades (timestamp, trade_id, symbol, side, price, quantity)",
    [
        (timestamp = NanoDate("2025-01-15T08:00:00.123456789"), trade_id = 1, symbol = "AAPL", side = UInt8(1), price = Decimal{34,18}("145.321234567890123456"), quantity = 100.0),
        (timestamp = NanoDate("2025-01-15T08:05:00.987654321"), trade_id = 2, symbol = "GOOG", side = UInt8(0), price = Decimal{34,18}("2745.50000000000000000"), quantity = 50.0),
        (timestamp = NanoDate("2025-01-15T08:10:00.111222333"), trade_id = 3, symbol = "TSLA", side = UInt8(0), price = Decimal{34,18}("652.801234567890123456"), quantity = 200.0),
        (timestamp = NanoDate("2025-01-15T08:15:00.444555666"), trade_id = 4, symbol = "AMZN", side = UInt8(1), price = Decimal{34,18}("3301.65000000000000000"), quantity = 30.0)
    ],
    chunk_size = 1024 * 1024, # 1 Mbyte
    # options...,
)

struct MyTrade
    timestamp::NanoDate
    trade_id::UInt64
    symbol::String
    side::UInt8
    price::Decimal{34,18}
    quantity::Float64
end

OhMyCH.insert(
    client,
    "INSERT INTO my_trades (timestamp, trade_id, symbol, side, price, quantity)",
    MyTrade[
        MyTrade(NanoDate("2025-01-15T08:00:00.123456789"), 1, "AAPL", UInt8(1), Decimal{34,18}("145.321234567890123456"), 100.0),
        MyTrade(NanoDate("2025-01-15T08:05:00.987654321"), 2, "GOOG", UInt8(0), Decimal{34,18}("2745.50000000000000000"), 50.0),
        MyTrade(NanoDate("2025-01-15T08:10:00.111222333"), 3, "TSLA", UInt8(0), Decimal{34,18}("652.801234567890123456"), 200.0),
        MyTrade(NanoDate("2025-01-15T08:15:00.444555666"), 4, "AMZN", UInt8(1), Decimal{34,18}("3301.65000000000000000"), 30.0)
    ],
    chunk_size = 1024 * 1024, # 1 Mbyte
)

query_result = OhMyCH.query(
    client,
    "SELECT * FROM my_trades WHERE quantity >= {quantity:Float64} LIMIT 2",
    (quantity = 100, ),
    # options...,
)

collect(query_result)

query_result = OhMyCH.query(
    client,
    "SELECT * FROM my_trades WHERE quantity >= {quantity:Float64} LIMIT 2",
    (quantity = 100, ),
    # options...,
)

collect(MyTrade, query_result)

#__ query_binary

query_result = OhMyCH.query_binary(
    client,
    "SELECT * FROM my_trades WHERE quantity >= {quantity:Float64} LIMIT 2",
    (quantity = 100, ),
    # options...,
)

collect(MyTrade, query_result)

close(client)

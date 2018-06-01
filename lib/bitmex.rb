require "typhoeus"

module Bitmex
  BITMEX_BASE = ENV.fetch("BITMEX_URL")

  HttpError = Class.new(StandardError)

  # TODO: how to deal with LTC / BCH?
  def self.order_amount(risk, price, stop_loss_price, wallet_balance = Bitmex.wallet_balance)
    alt = price < 1 # only alts have a price less than one

    total_contracts = (alt ? wallet_balance / price : wallet_balance * price)
    risk_in_btc = risk * wallet_balance
    risk_in_contracts = risk * total_contracts
    entry_stop_difference = (price - stop_loss_price).abs
    position_size_contracts = (risk_in_contracts / entry_stop_difference) * price
    position_size_btc = position_size_contracts / price
    minimum_leverage = position_size_btc / wallet_balance
    recommended_leverage = position_size_btc / (wallet_balance / 3) # 1/3 of wallet balance
    position_size_contracts.floor
  end

  def self.current_price(symbol, side)
    response = get("quote", symbol: symbol, reverse: true, count: 1)
    data = JSON.parse(response.body)
    if side.downcase == "buy"
      data.first.fetch("askPrice")
    else
      data.first.fetch("bidPrice")
    end
  end

  # symbol - BTCUSD, XBTU18, XBT7D_U110, XBTM18, ADAM18, BCHM18, ETHM18, LTCM18, XRPM18
  # side # Buy, Sell
  # simpleOrderQty # in btc
  # orderQty # in contracts
  # price # for limit orders
  # stopPx # trigger stop price for stop orders
  # ordType # Market, Limit, Stop, StopLimit, MarketIfTouched, LimitIfTouched, MarketWithLeftOverAsLimit, Pegged
  # execInst # ParticipateDoNotInitiate, AllOrNone, MarkPrice, IndexPrice, LastPrice, Close, ReduceOnly, Fixed
  # text # whatever
  def self.create_orders(orders)
    post("order/bulk", orders: orders)
  end

  def self.update_orders(orders)
    put("order/bulk", orders: orders)
  end

  def self.wallet_balance
    response = get("user/walletSummary")
    json = JSON.parse(response.body)
    json.last.fetch("walletBalance") / 100_000_000.0 # or marginBalance?
  end

  %w[get post delete put].each do |verb|
    define_singleton_method(verb) do |path, params = {}|
      request(verb.upcase, path, params)
    end
  end

  def self.in_trade?(symbol)
    response = Bitmex.get("position", filter: { symbol: symbol }.to_json)
    positions = JSON.parse(response.body)
    !positions.empty?
  end

  def self.request(verb, path, params = {})
    path = "/api/v1/#{path}"
    expires = Time.now.to_i + 15
    body = params.empty? ? "" : params.to_json
    signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      ENV.fetch("BITMEX_API_SECRET"),
      verb + path + expires.to_s + body,
    )

    puts "[Bitmex] #{verb} #{path} #{params}"

    response = Typhoeus.send(
      verb.downcase,
      BITMEX_BASE + path,
      body: body,
      headers: {
        "api-expires" => expires.to_s,
        "api-key" => ENV.fetch("BITMEX_API_KEY"),
        "api-signature" => signature,
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      },
    )

    if response.code == 200
      response
    else
      raise HttpError, "[#{response.code}] #{response.body}"
    end
  end
end

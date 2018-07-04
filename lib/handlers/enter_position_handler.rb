class EnterPositionHandler < Handler
  REQUIRED_PARAMS = %w[position_id symbol side risk stop amount_percent price_at_entry published_at]

  def perform
    missing_params = REQUIRED_PARAMS.map do |param|
      param unless params.include?(param)
    end.compact

    unless missing_params.empty?
      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}. Got: #{params}"
    end

    skip_if_published_too_long_ago!(params.fetch("published_at"))

    risk_percent = risk_percent(params.fetch("risk"))
    symbol = params.fetch("symbol")
    stop = params.fetch("stop")
    amount_percent = params.fetch("amount_percent")
    side = params.fetch("side")

    skip_if_already_in_position_and_adjust_leverage!(symbol)

    current_price = Bitmex.current_price(symbol, side)

    skip_if_too_much_slippage!(side, params.fetch("price_at_entry"), current_price)

    order_data = { position_id: position_id, message_number: message_number }

    amount_in_contracts = Bitmex.order_amount(risk_percent, current_price, stop)

    if amount_in_contracts == 0
      puts "WARNING: Could not enter position #{position_id} since amount_in_contracts was 0"
      return
    end

    stop_order = {
      clOrdLinkID: position_id.to_s,
      symbol: symbol,
      side: inverse_side,
      ordType: "Stop",
      stopPx: stop,
      execInst: "LastPrice,Close",
      orderQty: amount_in_contracts,
      text: order_data.merge(type: "stop").to_json,
    }

    amount_to_enter = (amount_percent * amount_in_contracts).round

    entry_order = {
      clOrdLinkID: position_id.to_s,
      symbol: symbol,
      side: side,
      ordType: "Market",
      orderQty: amount_to_enter,
      text: order_data.merge(type: "entry", amount_percent: amount_percent, risk: risk_percent).to_json,
    }

    entry_orders = [
      stop_order,
      entry_order,
    ]

    target_orders = (params["targets"] || []).map do |target|
      target_id = target.fetch("id")
      amount_percent = target.fetch("amount_percent")
      price = target.fetch("price")

      amount = (amount_percent * amount_to_enter).ceil

      {
        clOrdLinkID: position_id.to_s,
        symbol: symbol,
        side: inverse_side,
        ordType: "Limit",
        price: price,
        orderQty: amount,
        execInst: "ReduceOnly",
        text: order_data.merge(type: "target", target_id: target_id, amount_percent: amount_percent).to_json,
      }
    end

    Bitmex.create_orders(entry_orders)
    Bitmex.create_orders(target_orders) unless target_orders.empty?
  end

  private

  def skip_if_published_too_long_ago!(published_at_string)
    published_at = Time.parse(published_at_string)
    seconds_since_published = published_at - Time.now

    if seconds_since_published < -(60 * 10)
      raise SkipMessageError, "Too long ago since entry was published: #{seconds_since_published}"
    end
  end

  def skip_if_already_in_position_and_adjust_leverage!(symbol)
    filter = { symbol: symbol }.to_json
    response = Bitmex.get("position", filter: filter, count: 1)

    if position = JSON.parse(response.body).first
      if position.fetch("isOpen") == true
        raise SkipMessageError, "Already in a #{symbol} position"
      end

      if position.fetch("crossMargin") == false
        Bitmex.post("position/leverage", symbol: symbol, leverage: 0)
      end
    end
  end

  def skip_if_too_much_slippage!(side, price_at_entry, current_price)
    side = side.downcase
    difference = price_at_entry - current_price

    return if side == "buy" && difference > 0
    return if side == "sell" && difference < 0

    average_price = (price_at_entry + current_price) / 2.0
    percent_difference = difference.abs / average_price

    if percent_difference > 0.0025
      raise SkipMessageError, "Too much slippage for #{side}, price_at_entry: #{price_at_entry}, current_price: #{current_price}, percent_difference: #{percent_difference}"
    end
  end

  def risk_percent(risk)
    case risk
      when "normal" then ENV.fetch("NORMAL_RISK_PERCENT", "0.01").to_f
      when "medium" then ENV.fetch("HIGH_RISK_PERCENT", "0.0075").to_f
      when "high" then ENV.fetch("HIGH_RISK_PERCENT", "0.005").to_f
      else raise ArgumentError, "Unknown risk: #{risk}"
    end
  end
end

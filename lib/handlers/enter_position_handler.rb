class EnterPositionHandler < Handler
  REQUIRED_PARAMS = %w[position_id symbol side risk stop amount_percent]

  def perform
    missing_params = REQUIRED_PARAMS.map do |param|
      param unless params.include?(param)
    end.compact

    unless missing_params.empty?
      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}. Got: #{params}"
    end

    risk_percent = risk_percent(params.fetch("risk"))
    symbol = params.fetch("symbol")
    stop = params.fetch("stop")
    amount_percent = params.fetch("amount_percent")
    side = params.fetch("side")
    current_price = Bitmex.current_price(symbol, side)

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

  def risk_percent(risk)
    case risk
      when "normal" then ENV.fetch("NORMAL_RISK_PERCENT", "0.01").to_f
      when "medium" then ENV.fetch("HIGH_RISK_PERCENT", "0.0075").to_f
      when "high" then ENV.fetch("HIGH_RISK_PERCENT", "0.005").to_f
      else raise ArgumentError, "Unknown risk: #{risk}"
    end
  end
end

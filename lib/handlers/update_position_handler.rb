class UpdatePositionHandler < Handler
  def perform
    require_active_position!

    current_amount = position.fetch("currentQty").abs
    updated_stop = params["stop"]
    updated_targets = params["targets"]

    order_data = { position_id: position_id, message_number: message_number }

    orders_to_update = []
    orders_to_create = []

    if updated_stop
      stop_data = parse_text(stop_order.fetch("text"))
      orders_to_update << {
        orderID: stop_order.fetch("orderID"),
        stopPx: updated_stop,
        text: order_data.merge(type: "stop").to_json,
      }
    end

    if updated_targets
      updated_targets.each do |target|
        target_id = target.fetch("id")
        amount_percent = target.fetch("amount_percent")
        price = target.fetch("price")
        amount = (amount_percent * current_amount).round

        if current_order = orders.find { |order| parse_text(order.fetch("text"))["target_id"] == target_id }
          next if current_order["ordStatus"].downcase == "filled"

          orders_to_update << {
            orderID: current_order["orderID"],
            price: price,
            orderQty: amount,
            text: order_data.merge(target_id: target_id, type: "target", amount_percent: amount_percent).to_json
          }
        else
          orders_to_create << {
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
      end
    end

    Bitmex.update_orders(orders_to_update) unless orders_to_update.empty?
    Bitmex.create_orders(orders_to_create) unless orders_to_create.empty?
  end
end

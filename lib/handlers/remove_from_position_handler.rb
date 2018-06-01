class RemoveFromPositionHandler < Handler
  # When positions are removed the remaining targets gets handled as if the position was new
  def perform
    require_active_position!

    # Detect idempotent state
    already_removed = false
    already_updated_targets = false

    orders.each do |order|
      order_data = parse_text(order.fetch("text"))

      if order_data.fetch("message_number") == message_number
        order_type = order_data.fetch("type")
        already_removed = true if order_type == "remove"
        already_updated_targets = true if order_type == "target"
      end
    end

    amount_percent = params.fetch("amount_percent")
    amount_in_contracts = stop_order.fetch("orderQty")

    if already_removed
      amount_before_remove = amount_after_remove = position.fetch("currentQty").abs
      amount_to_remove = 0
    else
      amount_before_remove = position.fetch("currentQty").abs
      amount_to_remove = (amount_percent * amount_in_contracts).ceil
      amount_after_remove = amount_before_remove - amount_to_remove
    end

    # don't go below 0
    if amount_after_remove < 0
      amount_to_remove = amount_before_remove
      amount_after_remove = 0
    end

    amount_percent_after_remove = amount_after_remove / amount_in_contracts.to_f

    order_data = { position_id: position_id, message_number: message_number }

    remove_order = {
      clOrdLinkID: position_id.to_s,
      symbol: symbol,
      side: inverse_side,
      ordType: "Market",
      execInst: "ReduceOnly",
      orderQty: amount_to_remove,
      text: order_data.merge(type: "remove", amount_percent: amount_percent).to_json,
    }

    updated_targets = target_orders.map do |target|
      # potentially messy if "partially filled" but shouldn't happen in practice
      next unless target.fetch("ordStatus") == "New"

      target_data = parse_text(target.fetch("text"))
      target_id = target_data.fetch("target_id")
      amount_percent = target_data.fetch("amount_percent")
      new_amount = (amount_percent * amount_after_remove).ceil

      {
        orderID: target.fetch("orderID"),
        orderQty: new_amount,
        text: order_data.merge(type: "target", target_id: target_id, amount_percent: amount_percent).to_json,
      }
    end.compact

    Bitmex.create_orders([remove_order]) unless already_removed
    Bitmex.update_orders(updated_targets) unless already_updated_targets || updated_targets.empty?
  end
end

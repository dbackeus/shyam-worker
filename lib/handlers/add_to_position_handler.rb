class AddToPositionHandler < Handler
  # When positions are added the remaining targets gets handled as if the position was new
  def perform
    require_active_position!

    # Detect idempotent state
    already_added = false
    already_updated_targets = false

    orders.each do |order|
      order_data = parse_text(order.fetch("text"))

      if order_data.fetch("message_number") == message_number
        order_type = order_data.fetch("type")
        already_added = true if order_type == "add"
        already_updated_targets = true if order_type == "target"
      end
    end

    amount_percent = params.fetch("amount_percent")
    amount_in_contracts = stop_order.fetch("orderQty")

    if already_added
      amount_before_add = amount_after_add = position.fetch("currentQty").abs
      amount_to_add = 0
    else
      amount_before_add = position.fetch("currentQty").abs
      amount_to_add = (amount_percent * amount_in_contracts).floor
      amount_after_add = amount_before_add + amount_to_add
    end

    # don't break max position size
    if amount_after_add > amount_in_contracts
      amount_to_add = amount_in_contracts - amount_before_add
      amount_after_add = amount_in_contracts
    end

    amount_percent_after_add = amount_after_add / amount_in_contracts.to_f

    order_data = { position_id: position_id, message_number: message_number }

    add_order = {
      clOrdLinkID: position_id.to_s,
      symbol: symbol,
      side: side,
      ordType: "Market",
      orderQty: amount_to_add,
      text: order_data.merge(type: "add", amount_percent: amount_percent).to_json,
    }

    updated_targets = target_orders.map do |target|
      # potentially messy if "partially filled" but shouldn't happen in practice
      next unless target.fetch("ordStatus") == "New"

      target_data = parse_text(target.fetch("text"))
      target_id = target_data.fetch("target_id")
      amount_percent = target_data.fetch("amount_percent")
      new_amount = (amount_percent * amount_after_add).ceil

      {
        orderID: target.fetch("orderID"),
        orderQty: new_amount,
        text: order_data.merge(type: "target", target_id: target_id, amount_percent: amount_percent).to_json,
      }
    end.compact

    Bitmex.create_orders([add_order]) unless already_added
    Bitmex.update_orders(updated_targets) unless already_updated_targets || updated_targets.empty?
  end
end

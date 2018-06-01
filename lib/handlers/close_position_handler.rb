class ClosePositionHandler < Handler
  REQUIRED_PARAMS = %w[position_id]

  def perform
    require_active_position!

    close_order = {
      symbol: orders.first.fetch("symbol"),
      clOrdLinkID: position_id.to_s,
      ordType: "Market",
      execInst: "Close",
      text: { type: "close", position_id: position_id }.to_json
    }

    # Implicitly cancels reduceOnly targets
    Bitmex.create_orders([close_order])
    # Cancel remaining stop loss
    Bitmex.delete("order/all", filter: { clOrdLinkID: position_id.to_s }.to_json)
  end
end

class Handler
  attr_reader :params, :position_id, :message_number

  SkipMessageError = Class.new(Exception)

  def initialize(message)
    @message_number = message.fetch("message_number")
    @params = message.fetch("params")
    @position_id = params.fetch("position_id")
  end

  def orders
    @orders ||= begin
      filter = { clOrdLinkID: position_id.to_s }.to_json
      response = Bitmex.get("order", filter: filter)
      JSON.parse(response.body)
    end
  end

  def require_active_position!
    if orders.empty?
      raise SkipMessageError, "non entered position: #{position_id}"
    end

    if %w[canceled filled].include? stop_order.fetch("ordStatus").downcase
      raise SkipMessageError, "stopped out position: #{position_id}"
    end
  end

  def position
    @position ||= begin
      filter = { symbol: stop_order.fetch("symbol") }.to_json
      response = Bitmex.get("position", filter: filter)
      JSON.parse(response.body).first
    end
  end

  def entry_order
    @entry_order ||= orders.find { |order| parse_text(order.fetch("text")).fetch("type") == "entry" }
  end

  def stop_order
    @stop_order ||= orders.find { |order| order.fetch("ordType") == "Stop" }
  end

  def target_orders
    @target_orders ||= orders.select { |order| parse_text(order.fetch("text")).fetch("type") == "target" }
  end

  def symbol
    @symbol ||= params["symbol"] || orders.first.fetch("symbol")
  end

  def side
    @side ||= params["side"] || entry_order.fetch("side")
  end

  def inverse_side
    @inverse_side ||= side == "Buy" ? "Sell" : "Buy"
  end

  # Bitmex adds its own annotation to order text attributes but saves our original text on a newline
  def parse_text(text)
    JSON.parse(text.split("\n").last)
  end
end

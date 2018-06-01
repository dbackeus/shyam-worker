require "spec_helper"

RSpec.describe ClosePositionHandler do
  describe "#perform" do
    let(:message) do
      {
        type: "CLOSE_POSITION",
        message_number: 2,
        params: {
          position_id: 9,
        },
      }.as_json
    end

    it "creates an add order and updates targets" do
      current_orders = [
        {
          orderID: "o1",
          symbol: "XBTUSD",
          stopPx: 800,
          ordType: "Stop",
          orderQty: 1000,
          ordStatus: "New",
          clOrdLinkID: "9",
          text: { message_number: 1, type: "stop" }.to_json
        },
        {
          orderID: "o2",
          symbol: "XBTUSD",
          ordType: "Market",
          side: "Buy",
          orderQty: 500,
          ordStatus: "Filled",
          clOrdLinkID: "9",
          avgPx: 1000.0,
          text: { message_number: 1, type: "entry" }.to_json
        },
        {
          orderID: "o3",
          symbol: "XBTUSD",
          ordType: "Limit",
          side: "Sell",
          price: 1200,
          orderQty: 150,
          ordStatus: "Filled",
          execInst: "ReduceOnly",
          clOrdLinkID: "9",
          text: { message_number: 1, amount_percent: 0.3, target_id: 1, type: "target" }.to_json
        },
        {
          orderID: "o4",
          symbol: "XBTUSD",
          ordType: "Limit",
          side: "Sell",
          price: 1300,
          orderQty: 200,
          ordStatus: "New",
          execInst: "ReduceOnly",
          clOrdLinkID: "9",
          text: { message_number: 1, amount_percent: 0.4, target_id: 2, type: "target" }.to_json
        }
      ]

      stub_request(:get, "https://testnet.bitmex.com/api/v1/order").
         with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"9\\\"}\"}").
         to_return(status: 200, body: current_orders.to_json)

      stub_request(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: "{}")

      stub_request(:delete, "https://testnet.bitmex.com/api/v1/order/all").
        with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"9\\\"}\"}").
        to_return(status: 200, body: "[]")

      handler = ClosePositionHandler.new(message)

      handler.perform

      # close at market
      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"symbol":"XBTUSD","clOrdLinkID":"9","ordType":"Market","execInst":"Close","text":"{\"type\":\"close\",\"position_id\":9}"}]}')

      # cancel remaining stop loss
      expect(WebMock).to have_requested(:delete, "https://testnet.bitmex.com/api/v1/order/all").
        with(body: '{"filter":"{\"clOrdLinkID\":\"9\"}"}')
    end
  end
end

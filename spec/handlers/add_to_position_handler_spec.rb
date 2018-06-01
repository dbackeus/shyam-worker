require "spec_helper"

RSpec.describe AddToPositionHandler do
  describe "#perform" do
    let(:message) do
      {
        type: "ADD_TO_POSITION",
        message_number: 2,
        params: {
          position_id: 62,
          amount_percent: 0.5,
        },
      }.as_json
    end

    it "creates an add order and updates targets" do
      current_position = {
        currentQty: 500,
      }

      current_orders = [
        {
          orderID: "o1",
          symbol: "XBTUSD",
          stopPx: 800,
          ordType: "Stop",
          orderQty: 1000,
          ordStatus: "New",
          clOrdLinkID: "62",
          text: { message_number: 1, type: "stop" }.to_json
        },
        {
          orderID: "o2",
          symbol: "XBTUSD",
          ordType: "Market",
          side: "Buy",
          orderQty: 500,
          ordStatus: "Filled",
          clOrdLinkID: "62",
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
          ordStatus: "New",
          execInst: "ReduceOnly",
          clOrdLinkID: "62",
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
          clOrdLinkID: "62",
          text: { message_number: 1, amount_percent: 0.4, target_id: 2, type: "target" }.to_json
        }
      ]

      stub_request(:get, "https://testnet.bitmex.com/api/v1/order").
         with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"62\\\"}\"}").
         to_return(status: 200, body: current_orders.to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
        with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"XBTUSD\\\"}\"}").
        to_return(status: 200, body: [current_position].to_json)

      stub_request(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: "{}")

      stub_request(:put, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: "{}")

      handler = AddToPositionHandler.new(message)

      handler.perform

      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"62","symbol":"XBTUSD","side":"Buy","ordType":"Market","orderQty":500,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"add\",\"amount_percent\":0.5}"}]}')

      expect(WebMock).to have_requested(:put, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"orderID":"o3","orderQty":300,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"target\",\"target_id\":1,\"amount_percent\":0.3}"},{"orderID":"o4","orderQty":400,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"target\",\"target_id\":2,\"amount_percent\":0.4}"}]}')
    end

    it "skips a non entered position" do
      stub_request(:get, "https://testnet.bitmex.com/api/v1/order").
         with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"62\\\"}\"}").
         to_return(status: 200, body: "[]")

      handler = AddToPositionHandler.new(message)

      expect { handler.perform }.to raise_error(Handler::SkipMessageError)
    end

    it "skips canceled position" do
      current_orders = [
        {
          orderID: "o1",
          stopPx: 200,
          ordType: "Stop",
          ordQty: 1000,
          ordStatus: "Canceled",
        },
      ]

      stub_request(:get, "https://testnet.bitmex.com/api/v1/order").
         with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"62\\\"}\"}").
         to_return(status: 200, body: current_orders.to_json)

      handler = AddToPositionHandler.new(message)

      expect { handler.perform }.to raise_error(Handler::SkipMessageError)
    end

    it "skips stopped out position" do
      current_orders = [
        {
          orderID: "o1",
          stopPx: 200,
          ordType: "Stop",
          ordQty: 1000,
          ordStatus: "Filled",
        },
      ]

      stub_request(:get, "https://testnet.bitmex.com/api/v1/order").
         with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"62\\\"}\"}").
         to_return(status: 200, body: current_orders.to_json)

      handler = AddToPositionHandler.new(message)

      expect { handler.perform }.to raise_error(Handler::SkipMessageError)
    end
  end
end

require "spec_helper"

RSpec.describe RemoveFromPositionHandler do
  describe "#perform" do
    it "creates an add order and updates targets" do
      message = {
        type: "REMOVE_FROM_POSITION",
        message_number: 2,
        params: {
          position_id: 62,
          amount_percent: 0.2,
        },
      }.as_json

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

      handler = RemoveFromPositionHandler.new(message)

      handler.perform

      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"62","symbol":"XBTUSD","side":"Sell","ordType":"Market","execInst":"ReduceOnly","orderQty":200,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"remove\",\"amount_percent\":0.2}"}]}')

      expect(WebMock).to have_requested(:put, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"orderID":"o3","orderQty":90,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"target\",\"target_id\":1,\"amount_percent\":0.3}"},{"orderID":"o4","orderQty":120,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"target\",\"target_id\":2,\"amount_percent\":0.4}"}]}')
    end

    it "works for sell side positions too" do
      message = {
        type: "REMOVE_FROM_POSITION",
        message_number: 2,
        params: {
          position_id: 62,
          amount_percent: 0.5,
        },
      }.as_json

      current_position = {
        currentQty: -690,
      }

      current_orders = [
        {
          orderID: "o1",
          symbol: "ADAM18",
          stopPx: 0.00003249,
          ordType: "Stop",
          orderQty: 690,
          ordStatus: "New",
          clOrdLinkID: "62",
          text: { message_number: 1, type: "stop" }.to_json
        },
        {
          orderID: "o2",
          symbol: "ADAM18",
          ordType: "Market",
          side: "Sell",
          orderQty: 690,
          ordStatus: "Filled",
          clOrdLinkID: "62",
          avgPx: 0.00003110,
          text: { message_number: 1, type: "entry" }.to_json
        },
        {
          orderID: "o3",
          symbol: "ADAM18",
          ordType: "Limit",
          side: "Sell",
          price: 0.00002949,
          orderQty: 207,
          ordStatus: "New",
          execInst: "ReduceOnly",
          clOrdLinkID: "62",
          text: { message_number: 1, amount_percent: 0.3, target_id: 1, type: "target" }.to_json
        },
      ]

      stub_request(:get, "https://testnet.bitmex.com/api/v1/order").
         with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"62\\\"}\"}").
         to_return(status: 200, body: current_orders.to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
        with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"ADAM18\\\"}\"}").
        to_return(status: 200, body: [current_position].to_json)

      stub_request(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: "{}")

      stub_request(:put, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: "{}")

      handler = RemoveFromPositionHandler.new(message)

      handler.perform

      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"62","symbol":"ADAM18","side":"Buy","ordType":"Market","execInst":"ReduceOnly","orderQty":345,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"remove\",\"amount_percent\":0.5}"}]}')

      expect(WebMock).to have_requested(:put, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"orderID":"o3","orderQty":104,"text":"{\"position_id\":62,\"message_number\":2,\"type\":\"target\",\"target_id\":1,\"amount_percent\":0.3}"}]}')
    end
  end
end

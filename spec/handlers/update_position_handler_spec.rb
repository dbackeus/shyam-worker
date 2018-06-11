require "spec_helper"

RSpec.describe EnterPositionHandler do
  describe "#perform" do
    let(:message) do
      {
        type: "UPDATE_POSITION",
        message_number: 2,
        params: {
          position_id: 7,
          stop: 8900,
          targets: [
            { id: 1, amount_percent: 0.4, price: 8550 },
            { id: 2, amount_percent: 0.2, price: 8440 },
            { id: 3, amount_percent: 0.3, price: 8240 },
          ],
        },
      }.as_json
    end

    it "updates stop / targets and creates new targets" do
      current_position = {
        currentQty: 500,
      }

      current_orders = [
        {
          orderID: "o1",
          symbol: "XBTUSD",
          stopPx: 8895,
          ordType: "Stop",
          orderQty: 291,
          ordStatus: "New",
          clOrdLinkID: "62",
          text: { message_number: 1, type: "stop" }.to_json
        },
        {
          orderID: "o2",
          symbol: "XBTUSD",
          ordType: "Market",
          side: "Sell",
          orderQty: 291,
          ordStatus: "Filled",
          clOrdLinkID: "62",
          avgPx: 8710.0,
          text: { message_number: 1, type: "entry" }.to_json
        },
        {
          orderID: "o3",
          symbol: "XBTUSD",
          ordType: "Limit",
          side: "Buy",
          price: 8546,
          orderQty: 88,
          ordStatus: "New",
          execInst: "ReduceOnly",
          clOrdLinkID: "62",
          text: { message_number: 1, amount_percent: 0.3, target_id: 1, type: "target" }.to_json
        },
        {
          orderID: "o4",
          symbol: "XBTUSD",
          ordType: "Limit",
          side: "Buy",
          price: 8476,
          orderQty: 88,
          ordStatus: "New",
          execInst: "ReduceOnly",
          clOrdLinkID: "62",
          text: { message_number: 1, amount_percent: 0.3, target_id: 2, type: "target" }.to_json
        }
      ]
      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
        with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"XBTUSD\\\",\\\"isOpen\\\":true}\"}").
        to_return(status: 200, body: [current_position].to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/order").
         with(body: "{\"filter\":\"{\\\"clOrdLinkID\\\":\\\"7\\\"}\"}").
         to_return(status: 200, body: current_orders.to_json)

      stub_request(:put, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: [{}].to_json)

      stub_request(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: [{}].to_json)

      handler = UpdatePositionHandler.new(message)

      handler.perform

      # current orders updates
      expect(WebMock).to have_requested(:put, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"orderID":"o1","stopPx":8900,"text":"{\"position_id\":7,\"message_number\":2,\"type\":\"stop\"}"},{"orderID":"o3","price":8550,"orderQty":200,"text":"{\"position_id\":7,\"message_number\":2,\"target_id\":1,\"type\":\"target\",\"amount_percent\":0.4}"},{"orderID":"o4","price":8440,"orderQty":100,"text":"{\"position_id\":7,\"message_number\":2,\"target_id\":2,\"type\":\"target\",\"amount_percent\":0.2}"}]}')

      # new target creation
      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"7","symbol":"XBTUSD","side":"Buy","ordType":"Limit","price":8240,"orderQty":150,"execInst":"ReduceOnly","text":"{\"position_id\":7,\"message_number\":2,\"type\":\"target\",\"target_id\":3,\"amount_percent\":0.3}"}]}')
    end
  end
end

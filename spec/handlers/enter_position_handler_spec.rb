require "spec_helper"

RSpec.describe EnterPositionHandler do
  describe "#perform" do
    it "cancels current orders, creates market entry, stop market and target orders" do
      message = {
        type: "ENTER_POSITION",
        message_number: 1,
        params: {
          position_id: 7,
          symbol: "XBTUSD",
          side: "Sell",
          risk: "normal",
          stop: 8895,
          price_at_entry: 8708,
          amount_percent: 1,
          published_at: Time.now,
          targets: [
            { id: 1, amount_percent: 0.3, price: 8546 },
            { id: 2, amount_percent: 0.3, price: 8476 },
          ],
        },
      }.as_json

      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
         with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"XBTUSD\\\"}\",\"count\":1}").
         to_return(status: 200, body: [].to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/OrderBook/L2").
        with(body: "{\"symbol\":\"XBTUSD\",\"depth\":1}").
        to_return(status: 200, body: [{ side: "Buy", price: 8710 }, { side: "Sell", price: 8710.5 }].to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/user/walletSummary").
        to_return(status: 200, body: [{walletBalance: 7100000}].to_json)

      stub_request(:delete, "https://testnet.bitmex.com/api/v1/order/all")

      stub_request(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: [{}].to_json)

      handler = EnterPositionHandler.new(message)

      handler.perform

      # cancel current orders
      expect(WebMock).to have_requested(:delete, "https://testnet.bitmex.com/api/v1/order/all").
        with(body: '{"filter":"{\"symbol\":\"XBTUSD\"}"}')

      # entry / stop
      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"7","symbol":"XBTUSD","side":"Buy","ordType":"Stop","stopPx":8895,"execInst":"LastPrice,Close","orderQty":291,"text":"{\"position_id\":7,\"message_number\":1,\"type\":\"stop\"}"},{"clOrdLinkID":"7","symbol":"XBTUSD","side":"Sell","ordType":"Market","orderQty":291,"text":"{\"position_id\":7,\"message_number\":1,\"type\":\"entry\",\"amount_percent\":1,\"risk\":0.01}"}]}')

      # targets
      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"7","symbol":"XBTUSD","side":"Buy","ordType":"Limit","price":8546,"orderQty":88,"execInst":"ReduceOnly","text":"{\"position_id\":7,\"message_number\":1,\"type\":\"target\",\"target_id\":1,\"amount_percent\":0.3}"},{"clOrdLinkID":"7","symbol":"XBTUSD","side":"Buy","ordType":"Limit","price":8476,"orderQty":88,"execInst":"ReduceOnly","text":"{\"position_id\":7,\"message_number\":1,\"type\":\"target\",\"target_id\":2,\"amount_percent\":0.3}"}]}')
    end

    it "calculates correct numbers for ADAM18" do
      message = {
        type: "ENTER_POSITION",
        message_number: 1,
        params: {
          position_id: 7,
          symbol: "ADAM18",
          side: "Buy",
          risk: "normal",
          stop: 0.00002823,
          price_at_entry: 0.00002923,
          amount_percent: 1,
          published_at: Time.now,
          targets: [
            { id: 1, amount_percent: 0.3, price: 0.00002993 },
            { id: 2, amount_percent: 0.3, price: 0.00003200 },
          ],
        },
      }.as_json

      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
         with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"ADAM18\\\"}\",\"count\":1}").
         to_return(status: 200, body: [].to_json)

       stub_request(:get, "https://testnet.bitmex.com/api/v1/OrderBook/L2").
         with(body: "{\"symbol\":\"ADAM18\",\"depth\":1}").
         to_return(status: 200, body: [{ side: "Buy", price: 0.00002923 }, { side: "Sell", price: 0.00002930 }].to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/user/walletSummary").
        to_return(status: 200, body: [{walletBalance: 7100000}].to_json)

      stub_request(:delete, "https://testnet.bitmex.com/api/v1/order/all")

      stub_request(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: [{}].to_json)

      handler = EnterPositionHandler.new(message)

      handler.perform

      # entry / stop
      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"7","symbol":"ADAM18","side":"Sell","ordType":"Stop","stopPx":2.823e-05,"execInst":"LastPrice,Close","orderQty":663,"text":"{\"position_id\":7,\"message_number\":1,\"type\":\"stop\"}"},{"clOrdLinkID":"7","symbol":"ADAM18","side":"Buy","ordType":"Market","orderQty":663,"text":"{\"position_id\":7,\"message_number\":1,\"type\":\"entry\",\"amount_percent\":1,\"risk\":0.01}"}]}')

      # targets
      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        with(body: '{"orders":[{"clOrdLinkID":"7","symbol":"ADAM18","side":"Sell","ordType":"Limit","price":2.993e-05,"orderQty":199,"execInst":"ReduceOnly","text":"{\"position_id\":7,\"message_number\":1,\"type\":\"target\",\"target_id\":1,\"amount_percent\":0.3}"},{"clOrdLinkID":"7","symbol":"ADAM18","side":"Sell","ordType":"Limit","price":3.2e-05,"orderQty":199,"execInst":"ReduceOnly","text":"{\"position_id\":7,\"message_number\":1,\"type\":\"target\",\"target_id\":2,\"amount_percent\":0.3}"}]}')
    end

    it "sets leverage to cross margin if necessary" do
      message = {
        type: "ENTER_POSITION",
        message_number: 1,
        params: {
          position_id: 7,
          symbol: "XBTUSD",
          side: "Sell",
          risk: "normal",
          stop: 8895,
          price_at_entry: 8708,
          amount_percent: 1,
          published_at: Time.now,
          targets: [
            { id: 1, amount_percent: 0.3, price: 8546 },
          ],
        },
      }.as_json

      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
         with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"XBTUSD\\\"}\",\"count\":1}").
         to_return(status: 200, body: [{leverage: 10, crossMargin: false, currentQty: 0, isOpen: false}].to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/OrderBook/L2").
        to_return(status: 200, body: [{ side: "Buy", price: 8710 }, { side: "Sell", price: 8710.5 }].to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/user/walletSummary").
        to_return(status: 200, body: [{walletBalance: 7100000}].to_json)

      stub_request(:delete, "https://testnet.bitmex.com/api/v1/order/all")

      stub_request(:post, "https://testnet.bitmex.com/api/v1/order/bulk").
        to_return(status: 200, body: [{}].to_json)

      stub_request(:post, "https://testnet.bitmex.com/api/v1/position/leverage")

      handler = EnterPositionHandler.new(message)

      handler.perform

      expect(WebMock).to have_requested(:post, "https://testnet.bitmex.com/api/v1/position/leverage").
        with(body: "{\"symbol\":\"XBTUSD\",\"leverage\":0}")
    end

    it "skips entering already entered positions" do
      message = {
        type: "ENTER_POSITION",
        message_number: 1,
        params: {
          position_id: 7,
          symbol: "XBTUSD",
          side: "Sell",
          risk: "normal",
          stop: 8895,
          price_at_entry: 8708,
          amount_percent: 1,
          published_at: Time.now,
          targets: [
            { id: 1, amount_percent: 0.3, price: 8546 },
          ],
        },
      }.as_json

      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
         with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"XBTUSD\\\"}\",\"count\":1}").
         to_return(status: 200, body: [{leverage: 100, crossMargin: true, currentQty: 500, isOpen: true}].to_json)

      handler = EnterPositionHandler.new(message)
      expect { handler.perform }.to raise_error Handler::SkipMessageError
    end

    it "skips entering if price slippage is to big" do
      message = {
        type: "ENTER_POSITION",
        message_number: 1,
        params: {
          position_id: 7,
          symbol: "XBTUSD",
          side: "Sell",
          risk: "normal",
          stop: 8895,
          price_at_entry: 8712,
          amount_percent: 1,
          published_at: Time.now,
        },
      }.as_json

      stub_request(:get, "https://testnet.bitmex.com/api/v1/OrderBook/L2").
        with(body: "{\"symbol\":\"XBTUSD\",\"depth\":1}").
        to_return(status: 200, body: [{ side: "Buy", price: 8690 }, { side: "Sell", price: 8690.5 }].to_json)

      stub_request(:get, "https://testnet.bitmex.com/api/v1/position").
         with(body: "{\"filter\":\"{\\\"symbol\\\":\\\"XBTUSD\\\"}\",\"count\":1}").
         to_return(status: 200, body: [].to_json)

      handler = EnterPositionHandler.new(message)

      expect { handler.perform }.to raise_error Handler::SkipMessageError
    end

    it "skips entering if too long time has passed since entry was published" do
      message = {
        type: "ENTER_POSITION",
        message_number: 1,
        params: {
          position_id: 7,
          symbol: "XBTUSD",
          side: "Sell",
          risk: "normal",
          stop: 8895,
          price_at_entry: 8712,
          amount_percent: 1,
          published_at: Time.now - (60 * 10),
        },
      }.as_json

      handler = EnterPositionHandler.new(message)

      expect { handler.perform }.to raise_error Handler::SkipMessageError
    end
  end
end

require "spec_helper"

RSpec.describe "RPC call with Hutch", :with_application_prefix, :with_hutch_worker do
  describe "when RPC call is performed" do
    subject(:call) { rpc_client.call(event) }

    let(:rpc_client) { Hermes::RpcClient }

    class DummyEventToTestRpcIntegration < Hermes::BaseEvent
      attribute :message, Types::Strict::String
    end

    class DummyEventToTestRpcIntegrationHandler
      def self.call(event)
        event.as_json
      end
    end

    let(:event) { DummyEventToTestRpcIntegration.new(message: message) }
    let(:message) { "bookingsync + rabbit = :hearts:" }
    let(:clock) do
      Class.new do
        def now
          Time.new(2018, 1, 1, 12, 0, 0, 0)
        end
      end.new
    end
    let(:configuration) { Hermes.configuration }
    let(:instrumenter) { configuration.instrumenter }
    let(:event_handler) do
      Hermes::EventHandler.new.tap do |handler|
        handler.handle_events do
          handle DummyEventToTestRpcIntegration, with: DummyEventToTestRpcIntegrationHandler,
            async: false, rpc: true
        end
      end
    end

    before do
      allow(instrumenter).to receive(:instrument).and_call_original

      hutch_publisher = Hermes::Publisher::HutchAdapter.new
      Hermes::Publisher.instance.current_adapter = hutch_publisher
    end

    around do |example|
      original_distributed_tracing_database_uri = configuration.distributed_tracing_database_uri
      original_event_handler = configuration.event_handler
      original_application_prefix = configuration.application_prefix
      original_clock = configuration.clock

      Hermes.configure do |config|
        config.distributed_tracing_database_uri = ENV["DISTRIBUTED_TRACING_DATABASE_URI"]
        config.event_handler = event_handler
        config.application_prefix = "bookingsync_hermes"
        config.clock = clock
      end

      example.run

      Hermes.configure do |config|
        config.distributed_tracing_database_uri = original_distributed_tracing_database_uri
        config.event_handler = original_event_handler
        config.application_prefix = original_application_prefix
        config.clock = original_clock
      end
    end


    context "when client receives a response from the server" do
      let(:trace_1) { Hermes::DistributedTrace.order(:id).first }
      let(:trace_2) { Hermes::DistributedTrace.order(:id).second }
      let(:trace_3) { Hermes::DistributedTrace.order(:id).third }

      it "returns a parsed response from server" do
        response = call

        expect(response).to eq("message" => "bookingsync + rabbit = :hearts:")
      end

      it "closes connection, channel and consumer" do
        expect_any_instance_of(Hutch::Adapters::BunnyAdapter).to receive(:close).and_call_original
        expect_any_instance_of(Bunny::Channel).to receive(:close).and_call_original
        expect_any_instance_of(Bunny::Consumer).to receive(:cancel).and_call_original

        call
      end

      it "is instrumented" do
        call

        expect(instrumenter).to have_received(:instrument).with("Hermes.RpcClient.broker_connect")
        expect(instrumenter).to have_received(:instrument).with("Hermes.RpcClient.call")
        expect(instrumenter).to have_received(:instrument).with("Hermes.RpcClient.close_connection")
      end

      it "creates traces: client - server - client" do
        expect {
          call
        }.to change { Hermes::DistributedTrace.count }.by(3)

        expect([trace_1.trace, trace_2.trace, trace_3.trace].uniq).to eq [trace_1.trace]
        expect(trace_1.span).to include "bookingsync_her"
        expect(trace_1.span).to include trace_1.trace[0..10]
        expect(trace_2.span).to include "bookingsync_her"
        expect(trace_2.span).to include trace_1.trace[0..10]
        expect(trace_3.span).to include "bookingsync_her"
        expect(trace_3.span).to include trace_1.trace[0..10]
        expect(trace_1.parent_span).to eq nil
        expect(trace_2.parent_span).to eq trace_1.span
        expect(trace_3.parent_span).to eq trace_2.span
        expect(trace_1.event_class).to eq "DummyEventToTestRpcIntegration"
        expect(trace_2.event_class).to eq "DummyEventToTestRpcIntegration"
        expect(trace_3.event_class).to eq "Hermes::RpcClient::ResponseEvent"
      end
    end

    context "when client does not receive a response from the server in a timely manner" do
      let(:rpc_client) { Hermes::RpcClient.new(rpc_call_timeout: 2) }

      before do
        allow(DummyEventToTestRpcIntegrationHandler).to receive(:call) { sleep 3.0 }
      end

      it { is_expected_block.to raise_error Hermes::RpcClient::RpcTimeoutError  }

      it "closes connection, channel and consumer" do
        expect_any_instance_of(Hutch::Adapters::BunnyAdapter).to receive(:close).and_call_original
        expect_any_instance_of(Bunny::Channel).to receive(:close).and_call_original
        expect_any_instance_of(Bunny::Consumer).to receive(:cancel).and_call_original

        begin
          call
        rescue Hermes::RpcClient::RpcTimeoutError
        end
      end
    end

    context "when an error is raised" do
      before do
        allow_any_instance_of(Bunny::Exchange).to receive(:publish) { raise "forced failure" }
      end

      it "re-raises that error" do
        expect {
          call
        }.to raise_error /forced failure/
      end

      it "closes connection and channel" do
        expect_any_instance_of(Hutch::Adapters::BunnyAdapter).to receive(:close).and_call_original
        expect_any_instance_of(Bunny::Channel).to receive(:close).and_call_original

        begin
          call
        rescue StandardError
        end
      end
    end
  end
end

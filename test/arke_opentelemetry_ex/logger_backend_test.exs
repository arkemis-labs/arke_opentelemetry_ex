defmodule ArkeOpentelemetryEx.LoggerBackendTest do
  use ExUnit.Case

  alias ArkeOpentelemetryEx.LoggerBackend

  describe "init/1 without endpoint" do
    test "initializes in degraded mode when no endpoint is configured" do
      # When no endpoint is available, the backend should still start
      # but with level :none and nil exporter so it silently drops logs
      {:ok, state} = LoggerBackend.init({LoggerBackend, []})

      assert state.level == :none
      assert state.exporter == nil
      assert state.buffer == []
      assert state.batch_size == 100
      assert state.flush_interval == 5000
    end
  end

  describe "handle_event/2 in degraded mode" do
    test "drops log events when exporter is nil" do
      state = %LoggerBackend{
        level: :none,
        exporter: nil,
        buffer: [],
        batch_size: 100,
        flush_interval: 5000,
        flush_ref: nil
      }

      timestamp = {{2024, 1, 1}, {0, 0, 0, 0}}
      event = {:info, self(), {Logger, "test message", timestamp, []}}

      assert {:ok, ^state} = LoggerBackend.handle_event(event, state)
    end

    test "handles :flush event with empty buffer" do
      state = %LoggerBackend{
        level: :info,
        exporter: nil,
        buffer: [],
        batch_size: 100,
        flush_interval: 5000,
        flush_ref: nil
      }

      assert {:ok, ^state} = LoggerBackend.handle_event(:flush, state)
    end

    test "handles unknown events gracefully" do
      state = %LoggerBackend{
        level: :info,
        exporter: nil,
        buffer: [],
        batch_size: 100,
        flush_interval: 5000,
        flush_ref: nil
      }

      assert {:ok, ^state} = LoggerBackend.handle_event(:unknown_event, state)
    end
  end

  describe "handle_info/2" do
    test "ignores messages with non-matching flush ref" do
      state = %LoggerBackend{
        level: :info,
        exporter: nil,
        buffer: [],
        batch_size: 100,
        flush_interval: 5000,
        flush_ref: make_ref()
      }

      assert {:ok, ^state} = LoggerBackend.handle_info({:flush, make_ref()}, state)
    end

    test "ignores unrelated messages" do
      state = %LoggerBackend{
        level: :info,
        exporter: nil,
        buffer: [],
        batch_size: 100,
        flush_interval: 5000,
        flush_ref: nil
      }

      assert {:ok, ^state} = LoggerBackend.handle_info(:something_else, state)
    end
  end

  describe "code_change/3" do
    test "returns state unchanged" do
      state = %LoggerBackend{
        level: :info,
        exporter: nil,
        buffer: [],
        batch_size: 100,
        flush_interval: 5000,
        flush_ref: nil
      }

      assert {:ok, ^state} = LoggerBackend.code_change("1.0.0", state, [])
    end
  end
end

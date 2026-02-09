defmodule ArkeOpentelemetryEx.LogRecordTest do
  use ExUnit.Case, async: true

  alias ArkeOpentelemetryEx.LogRecord

  describe "new/0" do
    test "creates a record with default severity :info" do
      record = LogRecord.new()

      assert record.severity_number == :SEVERITY_NUMBER_INFO
      assert record.severity_text == "INFO"
      assert is_integer(record.time_unix_nano)
      assert is_integer(record.observed_time_unix_nano)
      assert record.observed_time_unix_nano >= record.time_unix_nano
    end

    test "does not include body, attributes, trace_id, or span_id by default" do
      record = LogRecord.new()

      refute Map.has_key?(record, :body)
      refute Map.has_key?(record, :attributes)
      refute Map.has_key?(record, :trace_id)
      refute Map.has_key?(record, :span_id)
    end
  end

  describe "new/1 with :severity" do
    test "sets severity for known levels" do
      for {level, expected_num, expected_text} <- [
            {:debug, :SEVERITY_NUMBER_DEBUG, "DEBUG"},
            {:info, :SEVERITY_NUMBER_INFO, "INFO"},
            {:warning, :SEVERITY_NUMBER_WARN, "WARN"},
            {:warn, :SEVERITY_NUMBER_WARN, "WARN"},
            {:error, :SEVERITY_NUMBER_ERROR, "ERROR"},
            {:fatal, :SEVERITY_NUMBER_FATAL, "FATAL"}
          ] do
        record = LogRecord.new(severity: level)
        assert record.severity_number == expected_num, "expected #{expected_num} for #{level}"
        assert record.severity_text == expected_text, "expected #{expected_text} for #{level}"
      end
    end

    test "defaults to UNSPECIFIED for unknown severity" do
      record = LogRecord.new(severity: :banana)
      assert record.severity_number == :SEVERITY_NUMBER_UNSPECIFIED
      assert record.severity_text == "UNSPECIFIED"
    end
  end

  describe "new/1 with :time" do
    test "uses provided timestamp" do
      ts = 1_700_000_000_000_000_000
      record = LogRecord.new(time: ts)

      assert record.time_unix_nano == ts
      assert record.observed_time_unix_nano >= ts
    end
  end

  describe "new/1 with :body" do
    test "encodes a string body" do
      record = LogRecord.new(body: "hello world")
      assert Map.has_key?(record, :body)
    end

    test "does not include body key when nil" do
      record = LogRecord.new(body: nil)
      refute Map.has_key?(record, :body)
    end
  end

  describe "new/1 with :attributes" do
    test "encodes non-empty attributes" do
      record = LogRecord.new(attributes: [module: "MyApp", line: 42])
      assert Map.has_key?(record, :attributes)
    end

    test "does not include attributes key when empty list" do
      record = LogRecord.new(attributes: [])
      refute Map.has_key?(record, :attributes)
    end
  end

  describe "new/1 with :trace_id" do
    test "encodes a positive integer trace_id as 16-byte binary" do
      id = 123_456_789
      record = LogRecord.new(trace_id: id)

      assert record.trace_id == <<id::128>>
      assert byte_size(record.trace_id) == 16
    end

    test "passes through a 16-byte binary trace_id" do
      id = :crypto.strong_rand_bytes(16)
      record = LogRecord.new(trace_id: id)
      assert record.trace_id == id
    end

    test "ignores nil trace_id" do
      record = LogRecord.new(trace_id: nil)
      refute Map.has_key?(record, :trace_id)
    end

    test "ignores zero trace_id" do
      record = LogRecord.new(trace_id: 0)
      refute Map.has_key?(record, :trace_id)
    end

    test "ignores invalid trace_id values" do
      for invalid <- ["short", -1, 3.14, :atom] do
        record = LogRecord.new(trace_id: invalid)
        refute Map.has_key?(record, :trace_id), "expected trace_id to be ignored for #{inspect(invalid)}"
      end
    end
  end

  describe "new/1 with :span_id" do
    test "encodes a positive integer span_id as 8-byte binary" do
      id = 987_654
      record = LogRecord.new(span_id: id)

      assert record.span_id == <<id::64>>
      assert byte_size(record.span_id) == 8
    end

    test "passes through an 8-byte binary span_id" do
      id = :crypto.strong_rand_bytes(8)
      record = LogRecord.new(span_id: id)
      assert record.span_id == id
    end

    test "ignores nil span_id" do
      record = LogRecord.new(span_id: nil)
      refute Map.has_key?(record, :span_id)
    end

    test "ignores zero span_id" do
      record = LogRecord.new(span_id: 0)
      refute Map.has_key?(record, :span_id)
    end

    test "ignores invalid span_id values" do
      for invalid <- ["short", -1, 3.14, :atom] do
        record = LogRecord.new(span_id: invalid)
        refute Map.has_key?(record, :span_id), "expected span_id to be ignored for #{inspect(invalid)}"
      end
    end
  end

  describe "severity_number/1" do
    test "maps all standard levels" do
      assert LogRecord.severity_number(:trace) == :SEVERITY_NUMBER_TRACE
      assert LogRecord.severity_number(:debug) == :SEVERITY_NUMBER_DEBUG
      assert LogRecord.severity_number(:info) == :SEVERITY_NUMBER_INFO
      assert LogRecord.severity_number(:warn) == :SEVERITY_NUMBER_WARN
      assert LogRecord.severity_number(:warning) == :SEVERITY_NUMBER_WARN
      assert LogRecord.severity_number(:error) == :SEVERITY_NUMBER_ERROR
      assert LogRecord.severity_number(:fatal) == :SEVERITY_NUMBER_FATAL
    end

    test "returns UNSPECIFIED for unknown level" do
      assert LogRecord.severity_number(:unknown) == :SEVERITY_NUMBER_UNSPECIFIED
    end
  end

  describe "severity_text/1" do
    test "maps all standard levels" do
      assert LogRecord.severity_text(:trace) == "TRACE"
      assert LogRecord.severity_text(:debug) == "DEBUG"
      assert LogRecord.severity_text(:info) == "INFO"
      assert LogRecord.severity_text(:warn) == "WARN"
      assert LogRecord.severity_text(:warning) == "WARN"
      assert LogRecord.severity_text(:error) == "ERROR"
      assert LogRecord.severity_text(:fatal) == "FATAL"
    end

    test "returns UNSPECIFIED for unknown level" do
      assert LogRecord.severity_text(:unknown) == "UNSPECIFIED"
    end
  end
end

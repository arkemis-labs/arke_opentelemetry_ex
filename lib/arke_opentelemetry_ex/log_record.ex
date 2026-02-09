defmodule ArkeOpentelemetryEx.LogRecord do
  @severity_numbers %{
    trace: :SEVERITY_NUMBER_TRACE,
    trace2: :SEVERITY_NUMBER_TRACE2,
    trace3: :SEVERITY_NUMBER_TRACE3,
    trace4: :SEVERITY_NUMBER_TRACE4,
    debug: :SEVERITY_NUMBER_DEBUG,
    debug2: :SEVERITY_NUMBER_DEBUG2,
    debug3: :SEVERITY_NUMBER_DEBUG3,
    debug4: :SEVERITY_NUMBER_DEBUG4,
    info: :SEVERITY_NUMBER_INFO,
    info2: :SEVERITY_NUMBER_INFO2,
    info3: :SEVERITY_NUMBER_INFO3,
    info4: :SEVERITY_NUMBER_INFO4,
    warn: :SEVERITY_NUMBER_WARN,
    warning: :SEVERITY_NUMBER_WARN,
    warn2: :SEVERITY_NUMBER_WARN2,
    warn3: :SEVERITY_NUMBER_WARN3,
    warn4: :SEVERITY_NUMBER_WARN4,
    error: :SEVERITY_NUMBER_ERROR,
    error2: :SEVERITY_NUMBER_ERROR2,
    error3: :SEVERITY_NUMBER_ERROR3,
    error4: :SEVERITY_NUMBER_ERROR4,
    fatal: :SEVERITY_NUMBER_FATAL,
    fatal2: :SEVERITY_NUMBER_FATAL2,
    fatal3: :SEVERITY_NUMBER_FATAL3,
    fatal4: :SEVERITY_NUMBER_FATAL4
  }

  @severity_texts %{
    trace: "TRACE",
    trace2: "TRACE2",
    trace3: "TRACE3",
    trace4: "TRACE4",
    debug: "DEBUG",
    debug2: "DEBUG2",
    debug3: "DEBUG3",
    debug4: "DEBUG4",
    info: "INFO",
    info2: "INFO2",
    info3: "INFO3",
    info4: "INFO4",
    warn: "WARN",
    warning: "WARN",
    warn2: "WARN2",
    warn3: "WARN3",
    warn4: "WARN4",
    error: "ERROR",
    error2: "ERROR2",
    error3: "ERROR3",
    error4: "ERROR4",
    fatal: "FATAL",
    fatal2: "FATAL2",
    fatal3: "FATAL3",
    fatal4: "FATAL4"
  }

  def new(opts \\ []) do
    now = System.system_time(:nanosecond)
    time = Keyword.get(opts, :time, now)
    severity = Keyword.get(opts, :severity, :info)
    body = Keyword.get(opts, :body)
    attributes = Keyword.get(opts, :attributes, [])
    trace_id = Keyword.get(opts, :trace_id)
    span_id = Keyword.get(opts, :span_id)

    record = %{
      time_unix_nano: time,
      observed_time_unix_nano: now,
      severity_number: severity_number(severity),
      severity_text: severity_text(severity)
    }

    record =
      if body, do: Map.put(record, :body, :otel_otlp_common.to_any_value(body)), else: record

    record =
      if attributes != [] do
        Map.put(record, :attributes, :otel_otlp_common.to_attributes(attributes))
      else
        record
      end

    record =
      case trace_id do
        nil -> record
        0 -> record
        id when is_integer(id) and id > 0 -> Map.put(record, :trace_id, <<id::128>>)
        id when is_binary(id) and byte_size(id) == 16 -> Map.put(record, :trace_id, id)
        _invalid -> record
      end

    case span_id do
      nil -> record
      0 -> record
      id when is_integer(id) and id > 0 -> Map.put(record, :span_id, <<id::64>>)
      id when is_binary(id) and byte_size(id) == 8 -> Map.put(record, :span_id, id)
      _invalid -> record
    end
  end

  def severity_number(level) when is_atom(level) do
    Map.get(@severity_numbers, level, :SEVERITY_NUMBER_UNSPECIFIED)
  end

  def severity_text(level) when is_atom(level) do
    Map.get(@severity_texts, level, "UNSPECIFIED")
  end
end

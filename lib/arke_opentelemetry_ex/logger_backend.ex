defmodule ArkeOpentelemetryEx.LoggerBackend do
  @behaviour :gen_event

  alias ArkeOpentelemetryEx.Exporter
  alias ArkeOpentelemetryEx.LogRecord

  @default_batch_size 100
  @default_flush_interval 5000

  defstruct [
    :level,
    :exporter,
    :metadata,
    :batch_size,
    :flush_interval,
    :flush_ref,
    buffer: []
  ]

  @impl :gen_event
  def init(__MODULE__) do
    config = Application.get_env(:logger, __MODULE__, [])
    do_init(config)
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    do_init(opts)
  end

  defp do_init(config) do
    if ArkeOpentelemetryEx.enabled?() do
      case configure(config, %__MODULE__{}) do
        {:ok, state} ->
          {:ok, schedule_flush(state)}

        {:error, reason} ->
          IO.puts(
            :stderr,
            "ArkeOpentelemetryEx logger backend failed to initialize: #{inspect(reason)}"
          )

          {:ok, disabled_state()}
      end
    else
      {:ok, disabled_state()}
    end
  end

  defp disabled_state do
    %__MODULE__{
      level: :none,
      exporter: nil,
      buffer: [],
      batch_size: 100,
      flush_interval: 5000
    }
  end

  @impl :gen_event
  def handle_call({:configure, opts}, state) do
    case configure(opts, state) do
      {:ok, new_state} -> {:ok, :ok, new_state}
      {:error, reason} -> {:ok, {:error, reason}, state}
    end
  end

  @impl :gen_event
  def handle_event({_level, _gl, {Logger, _msg, _timestamp, _metadata}}, %{exporter: nil} = state) do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, timestamp, metadata}}, state) do
    if meet_level?(level, state.level) do
      log_record = build_log_record(level, msg, timestamp, metadata, state)
      new_buffer = [log_record | state.buffer]

      if length(new_buffer) >= state.batch_size do
        {:ok, flushed_state} = flush_buffer(%{state | buffer: new_buffer})
        {:ok, schedule_flush(flushed_state)}
      else
        {:ok, %{state | buffer: new_buffer}}
      end
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state) do
    flush_buffer(state)
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  @impl :gen_event
  def handle_info({:flush, ref}, %{flush_ref: ref} = state) do
    {:ok, new_state} = flush_buffer(state)
    {:ok, schedule_flush(new_state)}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl :gen_event
  def terminate(_reason, state) do
    flush_buffer(state)
    :ok
  end

  @impl :gen_event
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp configure(opts, state) do
    level = Keyword.get(opts, :level, :info)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    flush_interval = Keyword.get(opts, :flush_interval, @default_flush_interval)
    metadata_keys = Keyword.get(opts, :metadata, :all)

    endpoint = Keyword.get(opts, :endpoint) || System.get_env("OTLP_LOGS_ENDPOINT")

    exporter_opts = [
      endpoint: endpoint,
      headers: Keyword.get(opts, :headers, [])
    ]

    case Exporter.init(exporter_opts) do
      {:ok, exporter} ->
        {:ok,
         %__MODULE__{
           level: level,
           exporter: exporter,
           metadata: metadata_keys,
           batch_size: batch_size,
           flush_interval: flush_interval,
           buffer: state.buffer || [],
           flush_ref: state.flush_ref
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp flush_buffer(%{buffer: []} = state) do
    {:ok, state}
  end

  defp flush_buffer(%{exporter: nil} = state) do
    {:ok, state}
  end

  defp flush_buffer(%{buffer: buffer, exporter: exporter} = state) do
    records = Enum.reverse(buffer)

    spawn(fn ->
      Exporter.export(records, exporter)
    end)

    {:ok, %{state | buffer: []}}
  end

  defp build_log_record(level, msg, timestamp, metadata, state) do
    time = timestamp_to_nanoseconds(timestamp)
    body = format_message(msg)
    attrs = filter_metadata(metadata, state.metadata)

    opts = [severity: level, body: body, time: time, attributes: attrs]

    opts =
      case Keyword.get(metadata, :otel_trace_id) do
        nil -> opts
        id -> Keyword.put(opts, :trace_id, id)
      end

    opts =
      case Keyword.get(metadata, :otel_span_id) do
        nil -> opts
        id -> Keyword.put(opts, :span_id, id)
      end

    LogRecord.new(opts)
  end

  defp timestamp_to_nanoseconds({{year, month, day}, {hour, minute, second, micro}}) do
    datetime = %DateTime{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      microsecond: {micro, 6},
      zone_abbr: "UTC",
      utc_offset: 0,
      std_offset: 0,
      time_zone: "Etc/UTC"
    }

    DateTime.to_unix(datetime, :nanosecond)
  end

  defp format_message(msg) when is_binary(msg), do: msg
  defp format_message(msg) when is_list(msg), do: IO.iodata_to_binary(msg)
  defp format_message(msg), do: inspect(msg)

  defp filter_metadata(metadata, :all) do
    metadata
    |> Keyword.drop([:gl, :pid, :otel_trace_id, :otel_span_id])
    |> Enum.map(fn {k, v} -> {k, format_metadata_value(v)} end)
  end

  defp filter_metadata(metadata, keys) when is_list(keys) do
    metadata
    |> Keyword.take(keys)
    |> Enum.map(fn {k, v} -> {k, format_metadata_value(v)} end)
  end

  defp format_metadata_value(v) when is_binary(v), do: v
  defp format_metadata_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_metadata_value(v) when is_number(v), do: v
  defp format_metadata_value(v) when is_list(v), do: inspect(v)
  defp format_metadata_value(v) when is_map(v), do: inspect(v)
  defp format_metadata_value(v), do: inspect(v)

  defp schedule_flush(%{flush_interval: interval} = state) do
    ref = make_ref()
    Process.send_after(self(), {:flush, ref}, interval)
    %{state | flush_ref: ref}
  end

  defp meet_level?(lvl, min) do
    Logger.compare_levels(normalize_level(lvl), normalize_level(min)) != :lt
  end

  defp normalize_level(:warn), do: :warning
  defp normalize_level(level), do: level
end

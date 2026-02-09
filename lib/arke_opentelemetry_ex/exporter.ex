defmodule ArkeOpentelemetryEx.Exporter do
  defstruct [:resource, :otel_state]

  def init(opts \\ []) do
    with {:ok, endpoints} <- parse_endpoint(opts),
         {:ok, otel_state} <- init_otel_exporter(endpoints, opts) do
      {:ok, %__MODULE__{resource: get_otel_resource(), otel_state: otel_state}}
    end
  end

  def export([], _state), do: :ok

  def export(log_records, %__MODULE__{} = state) do
    request = build_request(log_records, state)
    export_http(request, state.otel_state)
  end

  defp parse_endpoint(opts) do
    case Keyword.get(opts, :endpoint) do
      nil -> {:error, :no_endpoint_configured}
      "" -> {:error, :no_endpoint_configured}
      endpoint when is_binary(endpoint) -> {:ok, [endpoint]}
      endpoints when is_list(endpoints) -> {:ok, endpoints}
    end
  end

  defp init_otel_exporter(endpoints, opts) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    otel_opts = %{
      endpoints: endpoints,
      protocol: :http_protobuf,
      headers: resolve_headers(opts)
    }

    try do
      case :otel_exporter_otlp.init(otel_opts) do
        {:ok, otel_state} -> {:ok, otel_state}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> {:error, Exception.message(e)}
    catch
      :exit, reason -> {:error, {:exit, reason}}
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp get_otel_resource do
    case Application.get_env(:opentelemetry, :resource) do
      nil -> %{}
      config -> config |> :otel_resource_app_env.parse() |> Map.new()
    end
  end

  defp resolve_headers(opts) do
    headers = Keyword.get(opts, :headers) || []

    case System.get_env("TENANT_ID") do
      nil ->
        headers

      tenant ->
        case List.keyfind(headers, "tenant", 0) do
          nil -> headers ++ [{"tenant", tenant}]
          _ -> headers
        end
    end
  end

  defp export_http(request, otel_state) do
    body =
      :opentelemetry_exporter_logs_service_pb.encode_msg(request, :export_logs_service_request)

    case otel_state.endpoints do
      [endpoint | _] -> send_to_endpoint(endpoint, body, otel_state)
      [] -> :error
    end
  end

  defp send_to_endpoint(endpoint, body, otel_state) do
    ssl_options = Map.get(endpoint, :ssl_options, [])

    uri_map = %{
      scheme: Map.get(endpoint, :scheme),
      host: Map.get(endpoint, :host),
      port: Map.get(endpoint, :port),
      path: Map.get(endpoint, :path, "")
    }

    case :uri_string.normalize(uri_map) do
      {:error, type, error} ->
        IO.puts(
          :stderr,
          "[ArkeOpentelemetryEx] Error normalizing URI: #{inspect(type)} #{inspect(error)}"
        )

        :error

      address ->
        :otel_exporter_otlp.export_http(
          address,
          otel_state.headers,
          body,
          otel_state.compression,
          ssl_options,
          otel_state.httpc_profile
        )
    end
  end

  defp build_request(log_records, state) do
    %{
      resource_logs: [
        %{
          resource: %{attributes: :otel_otlp_common.to_attributes(state.resource)},
          scope_logs: [
            %{
              scope: %{name: "arke_opentelemetry_ex", version: "0.1.0"},
              log_records: log_records
            }
          ]
        }
      ]
    }
  end
end

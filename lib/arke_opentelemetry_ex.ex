defmodule ArkeOpentelemetryEx do
  @moduledoc """
  All-in-one OpenTelemetry setup for Elixir applications.

  Bundles tracing instrumentation (Phoenix, Cowboy, Ecto) and OTLP log export
  into a single dependency.

  ## Quick Start

  1. Add to `mix.exs`:

      ```elixir
      {:arke_opentelemetry_ex, "~> 0.1.0"}
      ```

  2. Configure in `config/config.exs`:

      ```elixir
      config :opentelemetry,
        resource: %{service: %{name: "my_service"}}

      config :arke_opentelemetry_ex,
        ecto_repos: [[:my_app, :repo]]

      config :logger,
        backends: [:console, ArkeOpentelemetryEx.LoggerBackend]
      ```

  3. Set environment variables:

      ```
      OTLP_ENDPOINT=https://collector:4317
      OTLP_LOGS_ENDPOINT=https://collector:4318/v1/logs
      ```

     The exporter defaults to gRPC on `OTLP_ENDPOINT` and the logger
     backend defaults to HTTP on `OTLP_LOGS_ENDPOINT`. Override in
     `config/runtime.exs` if needed:

      ```elixir
      config :opentelemetry_exporter,
        otlp_endpoint: "https://custom:4317",
        otlp_protocol: :http_protobuf

      config :logger, ArkeOpentelemetryEx.LoggerBackend,
        endpoint: "https://custom:4318/v1/logs",
        level: :warning,
        batch_size: 200
      ```

  4. Call `setup/0` at the top of your `Application.start/2`:

      ```elixir
      def start(_type, _args) do
        ArkeOpentelemetryEx.setup()

        children = [...]
        Supervisor.start_link(children, strategy: :one_for_one)
      end
      ```
  """

  @doc """
  Starts the OpenTelemetry OTP apps in the right order and attaches
  telemetry handlers for Phoenix, Cowboy, and Ecto.

  Configuration is read directly from the standard OTP app envs
  (`:opentelemetry`, `:opentelemetry_exporter`, `:logger`).

  Must be called from `Application.start/2`.
  """
  def setup do
    if enabled?() do
      apply_exporter_defaults()

      {:ok, _} = Application.ensure_all_started(:opentelemetry_exporter)
      {:ok, _} = Application.ensure_all_started(:opentelemetry)

      attach_instrumentations()
    end

    :ok
  end

  @doc """
  Returns whether OpenTelemetry is enabled.

  Reads from `config :arke_opentelemetry_ex, enabled: true | false`.
  Defaults to `true`.
  """
  def enabled? do
    Application.get_env(:arke_opentelemetry_ex, :enabled, true)
  end

  @doc """
  Returns the OTP application configuration needed for releases.

      releases: [
        my_app: [
          applications:
            Map.merge(ArkeOpentelemetryEx.release_applications(), %{my_app: :permanent})
        ]
      ]
  """
  def release_applications do
    %{opentelemetry_exporter: :permanent, opentelemetry: :temporary}
  end

  defp apply_exporter_defaults do
    unless Application.get_env(:opentelemetry_exporter, :otlp_endpoint) do
      if endpoint = System.get_env("OTLP_ENDPOINT") do
        Application.put_env(:opentelemetry_exporter, :otlp_endpoint, endpoint, persistent: true)
      end
    end

    unless Application.get_env(:opentelemetry_exporter, :otlp_protocol) do
      Application.put_env(:opentelemetry_exporter, :otlp_protocol, :grpc, persistent: true)
    end

    existing = Application.get_env(:opentelemetry_exporter, :otlp_headers, [])
    headers = resolve_default_headers(existing)

    if headers != existing do
      Application.put_env(:opentelemetry_exporter, :otlp_headers, headers, persistent: true)
    end

    existing_resource = Application.get_env(:opentelemetry, :resource)
    resource = resolve_default_resource(existing_resource)

    if resource != (existing_resource || %{}) do
      Application.put_env(:opentelemetry, :resource, resource, persistent: true)
    end
  end

  @default_headers [
    {"tenant", "OTEL_TENANT_ID"},
    {"authorization", "OTEL_EXPORTER_OTLP_AUTH_HEADER"}
  ]

  @doc false
  def resolve_default_headers(headers) when is_list(headers) do
    Enum.reduce(@default_headers, headers, fn {header_name, env_var}, acc ->
      case System.get_env(env_var) do
        nil -> acc
        value ->
          case List.keyfind(acc, header_name, 0) do
            nil -> acc ++ [{header_name, value}]
            _ -> acc
          end
      end
    end)
  end

  @default_resource [
    {[:service, :name], "OTEL_SERVICE_NAME", "arke_backend"}
  ]

  @doc false
  def resolve_default_resource(resource) do
    resource = resource || %{}

    Enum.reduce(@default_resource, resource, fn {key_path, env_var, default}, acc ->
      if get_in(acc, key_path) do
        acc
      else
        value = System.get_env(env_var) || default
        put_in_path(acc, key_path, value)
      end
    end)
  end

  defp put_in_path(map, [key], value), do: Map.put(map, key, value)
  defp put_in_path(map, [key | rest], value) do
    child = Map.get(map, key, %{})
    Map.put(map, key, put_in_path(child, rest, value))
  end

  defp attach_instrumentations do
    config = Application.get_all_env(:arke_opentelemetry_ex)
    exclude = Keyword.get(config, :exclude, [])

    unless :cowboy in exclude do
      :opentelemetry_cowboy.setup()
    end

    unless :phoenix in exclude do
      adapter = Keyword.get(config, :phoenix_adapter, :cowboy2)
      OpentelemetryPhoenix.setup(adapter: adapter)
    end

    unless :ecto in exclude do
      for prefix <- Keyword.get(config, :ecto_repos, []) do
        OpentelemetryEcto.setup(prefix)
      end
    end
  end
end

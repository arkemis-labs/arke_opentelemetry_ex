# ArkeOpentelemetryEx

> **This package is under heavy development.** APIs may change without notice.

The go-to package for setting up OpenTelemetry in Arke applications. One dependency replaces seven — get traces (Phoenix, Cowboy, Ecto) and OTLP log export out of the box.

## Installation

Add the dependency to `mix.exs`:

```elixir
def deps do
  [
    {:arke_opentelemetry_ex, "~> 0.1.0"}
  ]
end
```

For releases, add the required OTP applications:

```elixir
def project do
  [
    releases: [
      my_app: [
        applications: [
          opentelemetry_exporter: :permanent,
          opentelemetry: :temporary
        ]
      ]
    ]
  ]
end
```

## Quick Start

1. Configure in `config/config.exs`:

```elixir
config :opentelemetry,
  resource: %{service: %{name: "my_service"}}

config :arke_opentelemetry_ex,
  ecto_repos: [[:my_app, :repo]]

config :logger,
  backends: [:console, ArkeOpentelemetryEx.LoggerBackend]
```

2. Set environment variables:

```
OTLP_ENDPOINT=https://collector:4317
OTLP_LOGS_ENDPOINT=https://collector:4318/v1/logs
```

3. Call `setup/0` in your `application.ex`:

```elixir
def start(_type, _args) do
  ArkeOpentelemetryEx.setup()

  children = [...]
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

That's it. The package reads `OTLP_ENDPOINT` (gRPC, for traces) and `OTLP_LOGS_ENDPOINT` (HTTP, for logs) automatically.

## Overriding Defaults

The smart defaults cover the common case. Override any of them in `config/runtime.exs`:

```elixir
# Override trace exporter settings
config :opentelemetry_exporter,
  otlp_endpoint: "https://custom-collector:4317",
  otlp_protocol: :http_protobuf,
  otlp_headers: [{"x-api-key", "secret"}],
  otlp_compression: :gzip

# Override logger backend settings
config :logger, ArkeOpentelemetryEx.LoggerBackend,
  endpoint: "https://custom-collector:4318/v1/logs",
  level: :warning,
  batch_size: 200,
  flush_interval: 10_000
```

Explicit config always takes precedence over environment variables.

## Default Headers

The package automatically resolves headers from environment variables and attaches them to both trace and log exports. Explicit config always takes precedence.

| Header | Env Var | Description |
|---|---|---|
| `tenant` | `OTEL_TENANT_ID` | Multi-tenancy identifier |
| `authorization` | `OTEL_EXPORTER_OTLP_AUTH_HEADER` | Authorization header (e.g. `Bearer <token>`) |

```
OTEL_TENANT_ID=my_tenant
OTEL_EXPORTER_OTLP_AUTH_HEADER=Bearer my_token
```

Headers are merged with any existing headers configured via `:otlp_headers` or `:headers` and won't override already-present keys.

## Default Resource

The package resolves resource attributes from environment variables, falling back to built-in defaults. Explicit `config :opentelemetry, :resource` takes precedence.

| Resource Attribute | Env Var | Default |
|---|---|---|
| `service.name` | `OTEL_SERVICE_NAME` | `"arke_backend"` |

```
OTEL_SERVICE_NAME=my_service
```

This means you don't need to set `config :opentelemetry, resource: %{service: %{name: "..."}}` manually — just set the env var or rely on the default.

## Disabling

Set `enabled: false` to turn off all tracing, instrumentation, and log export:

```elixir
config :arke_opentelemetry_ex,
  enabled: false
```

When disabled, `setup/0` is a no-op (OTP apps are not started, instrumentations are not attached) and the logger backend silently drops all log records. Defaults to `true`.

## Configuration Reference

### `:opentelemetry`

Standard opentelemetry SDK config. See [opentelemetry-erlang](https://github.com/open-telemetry/opentelemetry-erlang) docs.

| Key | Description |
|---|---|
| `:resource` | Resource attributes map (e.g. `%{service: %{name: "my_svc"}}`) |
| `:traces_exporter` | `:otlp` or `:none` |
| `:span_processor` | `:otel_batch_processor` or `:otel_simple_processor` |

### `:opentelemetry_exporter`

| Key | Description | Default |
|---|---|---|
| `:otlp_endpoint` | OTLP collector endpoint | `OTLP_ENDPOINT` env var |
| `:otlp_protocol` | `:grpc` or `:http_protobuf` | `:grpc` |
| `:otlp_headers` | Extra headers list | `[]` |
| `:otlp_compression` | `:gzip` or `nil` | `nil` |

### `ArkeOpentelemetryEx.LoggerBackend`

Configured via `config :logger, ArkeOpentelemetryEx.LoggerBackend`.

| Key | Description | Default |
|---|---|---|
| `:endpoint` | OTLP logs endpoint (HTTP) | `OTLP_LOGS_ENDPOINT` env var |
| `:level` | Minimum log level | `:info` |
| `:batch_size` | Records buffered before flush | `100` |
| `:flush_interval` | Milliseconds between flushes | `5000` |
| `:headers` | Extra headers list | `[]` |

### `:arke_opentelemetry_ex`

Package-specific options for telemetry instrumentation.

| Key | Description | Default |
|---|---|---|
| `:enabled` | Enable/disable all telemetry | `true` |
| `:ecto_repos` | List of Ecto telemetry prefixes | `[]` |
| `:exclude` | List of instrumentations to skip (`:cowboy`, `:phoenix`, `:ecto`) | `[]` |
| `:phoenix_adapter` | Phoenix adapter | `:cowboy2` |

## License

MIT

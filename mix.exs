defmodule ArkeOpentelemetryEx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/arkemis-labs/arke_opentelemetry_ex"

  def project do
    [
      app: :arke_opentelemetry_ex,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      included_applications: [:opentelemetry, :opentelemetry_exporter]
    ]
  end

  defp description do
    "All-in-one OpenTelemetry setup for Elixir applications. " <>
      "Bundles tracing (Phoenix, Cowboy, Ecto) and OTLP log export into a single dependency."
  end

  defp package do
    [
      maintainers: ["Arkemis Labs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "ArkeOpentelemetryEx",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp deps do
    [
      {:opentelemetry, "~> 1.7.0", runtime: false},
      {:opentelemetry_api, "~> 1.5.0"},
      {:opentelemetry_exporter, "~> 1.10.0", runtime: false},
      {:opentelemetry_phoenix, "~> 2.0.1"},
      {:opentelemetry_cowboy, "~> 1.0.0"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end

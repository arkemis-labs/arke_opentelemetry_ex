defmodule ArkeOpentelemetryEx.ExporterTest do
  use ExUnit.Case, async: true

  alias ArkeOpentelemetryEx.Exporter

  describe "init/0" do
    test "returns error when no endpoint is configured" do
      assert Exporter.init() == {:error, :no_endpoint_configured}
    end
  end

  describe "init/1" do
    test "returns error for nil endpoint" do
      assert Exporter.init(endpoint: nil) == {:error, :no_endpoint_configured}
    end

    test "returns error for empty string endpoint" do
      assert Exporter.init(endpoint: "") == {:error, :no_endpoint_configured}
    end
  end

  describe "export/2" do
    test "returns :ok for empty log records list" do
      assert Exporter.export([], %Exporter{}) == :ok
    end
  end
end

defmodule ArkeOpentelemetryExTest do
  use ExUnit.Case, async: false

  describe "release_applications/0" do
    test "returns expected OTP application config" do
      assert ArkeOpentelemetryEx.release_applications() == %{
               opentelemetry_exporter: :permanent,
               opentelemetry: :temporary
             }
    end
  end

  describe "enabled?/0" do
    test "defaults to true" do
      Application.delete_env(:arke_opentelemetry_ex, :enabled)

      assert ArkeOpentelemetryEx.enabled?() == true
    end

    test "returns false when explicitly disabled" do
      Application.put_env(:arke_opentelemetry_ex, :enabled, false)

      assert ArkeOpentelemetryEx.enabled?() == false
    after
      Application.delete_env(:arke_opentelemetry_ex, :enabled)
    end

    test "returns true when explicitly enabled" do
      Application.put_env(:arke_opentelemetry_ex, :enabled, true)

      assert ArkeOpentelemetryEx.enabled?() == true
    after
      Application.delete_env(:arke_opentelemetry_ex, :enabled)
    end
  end

  describe "setup/0 applies OTEL_TENANT_ID to exporter headers" do
    test "adds tenant header when OTEL_TENANT_ID is set" do
      System.put_env("OTEL_TENANT_ID", "my_tenant")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert {"tenant", "my_tenant"} in headers
    after
      System.delete_env("OTEL_TENANT_ID")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end

    test "merges tenant with existing headers" do
      System.put_env("OTEL_TENANT_ID", "my_tenant")
      Application.put_env(:opentelemetry_exporter, :otlp_headers, [{"x-api-key", "secret"}])

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert {"x-api-key", "secret"} in headers
      assert {"tenant", "my_tenant"} in headers
    after
      System.delete_env("OTEL_TENANT_ID")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end

    test "does not override explicit tenant header" do
      System.put_env("OTEL_TENANT_ID", "from_env")
      Application.put_env(:opentelemetry_exporter, :otlp_headers, [{"tenant", "explicit"}])

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert {"tenant", "explicit"} in headers
      refute {"tenant", "from_env"} in headers
    after
      System.delete_env("OTEL_TENANT_ID")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end

    test "does nothing when OTEL_TENANT_ID is not set" do
      System.delete_env("OTEL_TENANT_ID")
      Application.put_env(:opentelemetry_exporter, :otlp_headers, [{"x-key", "val"}])

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert headers == [{"x-key", "val"}]
    after
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end
  end

  describe "setup/0 applies OTEL_EXPORTER_OTLP_AUTH_HEADER to exporter headers" do
    test "adds authorization header when env var is set" do
      System.put_env("OTEL_EXPORTER_OTLP_AUTH_HEADER", "Bearer token123")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert {"authorization", "Bearer token123"} in headers
    after
      System.delete_env("OTEL_EXPORTER_OTLP_AUTH_HEADER")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end

    test "merges authorization with existing headers" do
      System.put_env("OTEL_EXPORTER_OTLP_AUTH_HEADER", "Bearer token123")
      Application.put_env(:opentelemetry_exporter, :otlp_headers, [{"x-api-key", "secret"}])

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert {"x-api-key", "secret"} in headers
      assert {"authorization", "Bearer token123"} in headers
    after
      System.delete_env("OTEL_EXPORTER_OTLP_AUTH_HEADER")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end

    test "does not override explicit authorization header" do
      System.put_env("OTEL_EXPORTER_OTLP_AUTH_HEADER", "Bearer from_env")
      Application.put_env(:opentelemetry_exporter, :otlp_headers, [{"authorization", "Bearer explicit"}])

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert {"authorization", "Bearer explicit"} in headers
      refute {"authorization", "Bearer from_env"} in headers
    after
      System.delete_env("OTEL_EXPORTER_OTLP_AUTH_HEADER")
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end

    test "does nothing when env var is not set" do
      System.delete_env("OTEL_EXPORTER_OTLP_AUTH_HEADER")
      Application.put_env(:opentelemetry_exporter, :otlp_headers, [{"x-key", "val"}])

      ArkeOpentelemetryEx.setup()

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      refute Enum.any?(headers, fn {k, _} -> k == "authorization" end)
    after
      Application.delete_env(:opentelemetry_exporter, :otlp_headers)
    end
  end

  describe "setup/0 applies OTEL_SERVICE_NAME to resource" do
    test "sets service.name when no resource configured" do
      System.put_env("OTEL_SERVICE_NAME", "my_service")
      Application.delete_env(:opentelemetry, :resource)

      ArkeOpentelemetryEx.setup()

      resource = Application.get_env(:opentelemetry, :resource)
      assert %{service: %{name: "my_service"}} = resource
    after
      System.delete_env("OTEL_SERVICE_NAME")
      Application.delete_env(:opentelemetry, :resource)
    end

    test "merges with existing resource config" do
      System.put_env("OTEL_SERVICE_NAME", "my_service")
      Application.put_env(:opentelemetry, :resource, %{deployment: %{environment: "prod"}})

      ArkeOpentelemetryEx.setup()

      resource = Application.get_env(:opentelemetry, :resource)
      assert %{service: %{name: "my_service"}, deployment: %{environment: "prod"}} = resource
    after
      System.delete_env("OTEL_SERVICE_NAME")
      Application.delete_env(:opentelemetry, :resource)
    end

    test "does not override explicit service.name" do
      System.put_env("OTEL_SERVICE_NAME", "from_env")
      Application.put_env(:opentelemetry, :resource, %{service: %{name: "explicit"}})

      ArkeOpentelemetryEx.setup()

      resource = Application.get_env(:opentelemetry, :resource)
      assert resource.service.name == "explicit"
    after
      System.delete_env("OTEL_SERVICE_NAME")
      Application.delete_env(:opentelemetry, :resource)
    end

    test "falls back to default when env var is not set" do
      System.delete_env("OTEL_SERVICE_NAME")
      Application.delete_env(:opentelemetry, :resource)

      ArkeOpentelemetryEx.setup()

      resource = Application.get_env(:opentelemetry, :resource)
      assert %{service: %{name: "arke_backend"}} = resource
    after
      Application.delete_env(:opentelemetry, :resource)
    end

    test "does not override explicit service.name when env var is not set" do
      System.delete_env("OTEL_SERVICE_NAME")
      Application.put_env(:opentelemetry, :resource, %{service: %{name: "existing"}})

      ArkeOpentelemetryEx.setup()

      resource = Application.get_env(:opentelemetry, :resource)
      assert resource.service.name == "existing"
    after
      Application.delete_env(:opentelemetry, :resource)
    end
  end

  describe "setup/0 when disabled" do
    test "returns :ok without starting otel apps" do
      Application.put_env(:arke_opentelemetry_ex, :enabled, false)

      # Stop otel apps if running so we can verify they don't start
      Application.stop(:opentelemetry)
      Application.stop(:opentelemetry_exporter)

      assert ArkeOpentelemetryEx.setup() == :ok

      # Otel apps should not have been started
      started_apps = Application.started_applications() |> Enum.map(&elem(&1, 0))
      refute :opentelemetry in started_apps
    after
      Application.delete_env(:arke_opentelemetry_ex, :enabled)
    end
  end
end

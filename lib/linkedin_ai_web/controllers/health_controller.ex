defmodule LinkedinAiWeb.HealthController do
  @moduledoc """
  Health check controller for monitoring and load balancer health checks.
  """

  use LinkedinAiWeb, :controller

  def check(conn, _params) do
    # Basic health checks
    health_status = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: Application.spec(:linkedin_ai, :vsn) |> to_string(),
      checks: %{
        database: check_database(),
        oban: check_oban()
      }
    }

    case all_checks_passing?(health_status.checks) do
      true ->
        conn
        |> put_status(:ok)
        |> json(health_status)

      false ->
        conn
        |> put_status(:service_unavailable)
        |> json(health_status)
    end
  end

  defp check_database do
    try do
      LinkedinAi.Repo.query!("SELECT 1")
      "ok"
    rescue
      _ -> "error"
    end
  end

  defp check_oban do
    try do
      case Oban.check_queue(LinkedinAi.Oban, queue: :default) do
        :ok -> "ok"
        _ -> "error"
      end
    rescue
      _ -> "error"
    end
  end

  defp all_checks_passing?(checks) do
    checks
    |> Map.values()
    |> Enum.all?(&(&1 == "ok"))
  end
end

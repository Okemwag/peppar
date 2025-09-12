defmodule LinkedinAi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LinkedinAiWeb.Telemetry,
      LinkedinAi.Repo,
      {DNSCluster, query: Application.get_env(:linkedin_ai, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LinkedinAi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LinkedinAi.Finch},
      # Start Oban for background job processing
      {Oban, Application.fetch_env!(:linkedin_ai, Oban)},
      # Start Quantum scheduler for cron jobs
      LinkedinAi.Scheduler,
      # Start to serve requests, typically the last entry
      LinkedinAiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LinkedinAi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LinkedinAiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

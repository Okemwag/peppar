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
      # Start caching system
      cache_supervisor(),
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

  defp cache_supervisor do
    if Application.get_env(:linkedin_ai, :enable_cache, true) do
      {Supervisor, 
       [
         # In-memory caches
         {Cachex, name: :user_cache, limit: 10_000},
         {Cachex, name: :content_cache, limit: 50_000},
         {Cachex, name: :analytics_cache, limit: 5_000},
         {Cachex, name: :api_response_cache, limit: 20_000}
       ] ++ redis_children(),
       [strategy: :one_for_one, name: LinkedinAi.CacheSupervisor]
      }
    else
      # Return a no-op supervisor if caching is disabled
      {Supervisor, [], [strategy: :one_for_one, name: LinkedinAi.CacheSupervisor]}
    end
  end

  defp redis_children do
    if redis_enabled?() do
      [
        {Redix, {redis_url(), [name: :redix_pool, pool_size: redis_pool_size()]}}
      ]
    else
      []
    end
  end

  defp redis_enabled? do
    Application.get_env(:linkedin_ai, :enable_redis, false) or
    System.get_env("REDIS_URL") != nil
  end

  defp redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379/0"
  end

  defp redis_pool_size do
    case System.get_env("REDIS_POOL_SIZE") do
      nil -> 10
      size -> String.to_integer(size)
    end
  end
end

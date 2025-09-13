defmodule LinkedinAi.Cache do
  @moduledoc """
  Caching utilities for the LinkedIn AI platform.
  Provides both in-memory (Cachex) and Redis-based caching.
  """

  require Logger

  @default_ttl :timer.hours(1)
  @redis_pool_name :redix_pool

  # Cache names
  @user_cache :user_cache
  @content_cache :content_cache
  @analytics_cache :analytics_cache
  @api_response_cache :api_response_cache

  @doc """
  Starts the cache supervision tree.
  """
  def start_link do
    children = [
      # In-memory caches
      {Cachex, name: @user_cache, limit: 10_000},
      {Cachex, name: @content_cache, limit: 50_000},
      {Cachex, name: @analytics_cache, limit: 5_000},
      {Cachex, name: @api_response_cache, limit: 20_000},
      
      # Redis connection pool
      {Redix,
       {redis_url(), [name: @redis_pool_name, pool_size: redis_pool_size()]}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  @doc """
  Gets a value from cache with fallback function.
  """
  def get_or_compute(cache_name, key, compute_fn, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    use_redis = Keyword.get(opts, :redis, false)

    if use_redis do
      get_or_compute_redis(key, compute_fn, ttl)
    else
      get_or_compute_memory(cache_name, key, compute_fn, ttl)
    end
  end

  @doc """
  Gets a value from memory cache.
  """
  def get(cache_name, key) do
    case Cachex.get(cache_name, key) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, value}
      {:error, _} = error -> error
    end
  end

  @doc """
  Puts a value in memory cache.
  """
  def put(cache_name, key, value, ttl \\ @default_ttl) do
    Cachex.put(cache_name, key, value, ttl: ttl)
  end

  @doc """
  Deletes a value from memory cache.
  """
  def delete(cache_name, key) do
    Cachex.del(cache_name, key)
  end

  @doc """
  Gets a value from Redis cache.
  """
  def get_redis(key) do
    case Redix.command(@redis_pool_name, ["GET", key]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, Jason.decode!(value)}
      {:error, _} = error -> error
    end
  rescue
    Jason.DecodeError -> {:error, :decode_error}
  end

  @doc """
  Puts a value in Redis cache.
  """
  def put_redis(key, value, ttl_seconds \\ 3600) do
    encoded_value = Jason.encode!(value)
    
    case Redix.command(@redis_pool_name, ["SETEX", key, ttl_seconds, encoded_value]) do
      {:ok, "OK"} -> :ok
      {:error, _} = error -> error
    end
  rescue
    Jason.EncodeError -> {:error, :encode_error}
  end

  @doc """
  Deletes a value from Redis cache.
  """
  def delete_redis(key) do
    case Redix.command(@redis_pool_name, ["DEL", key]) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Invalidates cache entries by pattern.
  """
  def invalidate_pattern(cache_name, pattern) do
    # For memory cache, we need to scan all keys
    case Cachex.keys(cache_name) do
      {:ok, keys} ->
        matching_keys = Enum.filter(keys, &String.match?(to_string(&1), ~r/#{pattern}/))
        Enum.each(matching_keys, &Cachex.del(cache_name, &1))
        {:ok, length(matching_keys)}
      
      error ->
        error
    end
  end

  @doc """
  Invalidates Redis cache entries by pattern.
  """
  def invalidate_redis_pattern(pattern) do
    case Redix.command(@redis_pool_name, ["KEYS", pattern]) do
      {:ok, keys} when length(keys) > 0 ->
        case Redix.command(@redis_pool_name, ["DEL" | keys]) do
          {:ok, count} -> {:ok, count}
          error -> error
        end
      
      {:ok, []} ->
        {:ok, 0}
      
      error ->
        error
    end
  end

  @doc """
  Warms up cache with commonly accessed data.
  """
  def warm_up do
    Logger.info("Starting cache warm-up")
    
    # Warm up user cache with active users
    warm_up_users()
    
    # Warm up content templates
    warm_up_content_templates()
    
    # Warm up analytics data
    warm_up_analytics()
    
    Logger.info("Cache warm-up completed")
  end

  @doc """
  Gets cache statistics.
  """
  def stats do
    %{
      user_cache: get_cache_stats(@user_cache),
      content_cache: get_cache_stats(@content_cache),
      analytics_cache: get_cache_stats(@analytics_cache),
      api_response_cache: get_cache_stats(@api_response_cache),
      redis_info: get_redis_info()
    }
  end

  @doc """
  Clears all caches.
  """
  def clear_all do
    Cachex.clear(@user_cache)
    Cachex.clear(@content_cache)
    Cachex.clear(@analytics_cache)
    Cachex.clear(@api_response_cache)
    
    # Clear Redis cache
    case Redix.command(@redis_pool_name, ["FLUSHDB"]) do
      {:ok, "OK"} -> :ok
      error -> error
    end
  end

  # Cache-specific functions

  @doc """
  Caches user data.
  """
  def cache_user(user) do
    put(@user_cache, "user:#{user.id}", user, :timer.hours(2))
    
    # Also cache by email for login lookups
    put(@user_cache, "user:email:#{user.email}", user, :timer.hours(2))
  end

  @doc """
  Gets cached user data.
  """
  def get_user(user_id) do
    get(@user_cache, "user:#{user_id}")
  end

  @doc """
  Gets cached user by email.
  """
  def get_user_by_email(email) do
    get(@user_cache, "user:email:#{email}")
  end

  @doc """
  Caches API response.
  """
  def cache_api_response(endpoint, params, response, ttl \\ :timer.minutes(15)) do
    key = "api:#{endpoint}:#{:crypto.hash(:md5, Jason.encode!(params)) |> Base.encode16()}"
    put(@api_response_cache, key, response, ttl)
  end

  @doc """
  Gets cached API response.
  """
  def get_api_response(endpoint, params) do
    key = "api:#{endpoint}:#{:crypto.hash(:md5, Jason.encode!(params)) |> Base.encode16()}"
    get(@api_response_cache, key)
  end

  @doc """
  Caches analytics data.
  """
  def cache_analytics(key, data, ttl \\ :timer.hours(6)) do
    put(@analytics_cache, "analytics:#{key}", data, ttl)
  end

  @doc """
  Gets cached analytics data.
  """
  def get_analytics(key) do
    get(@analytics_cache, "analytics:#{key}")
  end

  # Private functions

  defp get_or_compute_memory(cache_name, key, compute_fn, ttl) do
    case get(cache_name, key) do
      {:ok, value} ->
        {:ok, value}
      
      {:error, :not_found} ->
        case compute_fn.() do
          {:ok, value} ->
            put(cache_name, key, value, ttl)
            {:ok, value}
          
          error ->
            error
        end
      
      error ->
        error
    end
  end

  defp get_or_compute_redis(key, compute_fn, ttl_seconds) do
    case get_redis(key) do
      {:ok, value} ->
        {:ok, value}
      
      {:error, :not_found} ->
        case compute_fn.() do
          {:ok, value} ->
            put_redis(key, value, ttl_seconds)
            {:ok, value}
          
          error ->
            error
        end
      
      error ->
        error
    end
  end

  defp warm_up_users do
    # This would typically load recently active users
    # For now, just log the action
    Logger.debug("Warming up user cache")
  end

  defp warm_up_content_templates do
    # Load system content templates
    Logger.debug("Warming up content templates cache")
  end

  defp warm_up_analytics do
    # Load commonly requested analytics
    Logger.debug("Warming up analytics cache")
  end

  defp get_cache_stats(cache_name) do
    case Cachex.stats(cache_name) do
      {:ok, stats} -> stats
      _ -> %{error: "Unable to get stats"}
    end
  end

  defp get_redis_info do
    case Redix.command(@redis_pool_name, ["INFO", "memory"]) do
      {:ok, info} -> parse_redis_info(info)
      _ -> %{error: "Unable to get Redis info"}
    end
  end

  defp parse_redis_info(info) do
    info
    |> String.split("\r\n")
    |> Enum.filter(&String.contains?(&1, ":"))
    |> Enum.map(&String.split(&1, ":", parts: 2))
    |> Enum.into(%{}, fn [key, value] -> {key, value} end)
  end

  defp redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379/0"
  end

  defp redis_pool_size do
    System.get_env("REDIS_POOL_SIZE") |> parse_integer(10)
  end

  defp parse_integer(nil, default), do: default
  defp parse_integer(str, default) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> default
    end
  end
end
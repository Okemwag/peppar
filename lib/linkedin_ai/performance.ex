defmodule LinkedinAi.Performance do
  @moduledoc """
  Performance monitoring and optimization utilities for the LinkedIn AI platform.
  """

  require Logger
  alias LinkedinAi.Repo

  @doc """
  Monitors query performance and logs slow queries.
  """
  def monitor_query(query_name, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      result = fun.()
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      if duration > slow_query_threshold() do
        Logger.warning("Slow query detected", %{
          query_name: query_name,
          duration_ms: duration,
          threshold_ms: slow_query_threshold()
        })
      end
      
      # Store performance metrics
      record_query_performance(query_name, duration)
      
      result
    rescue
      error ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        Logger.error("Query failed", %{
          query_name: query_name,
          duration_ms: duration,
          error: inspect(error)
        })
        
        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Analyzes database performance and provides optimization suggestions.
  """
  def analyze_performance do
    %{
      connection_pool: analyze_connection_pool(),
      slow_queries: get_slow_queries(),
      index_usage: analyze_index_usage(),
      table_sizes: get_table_sizes(),
      suggestions: generate_optimization_suggestions()
    }
  end

  @doc """
  Gets database statistics for monitoring.
  """
  def get_database_stats do
    %{
      active_connections: get_active_connections(),
      total_connections: get_total_connections(),
      cache_hit_ratio: get_cache_hit_ratio(),
      index_hit_ratio: get_index_hit_ratio(),
      deadlocks: get_deadlock_count(),
      temp_files: get_temp_file_usage()
    }
  end

  @doc """
  Optimizes a query by adding appropriate preloads and select fields.
  """
  def optimize_query(queryable, opts \\ []) do
    queryable
    |> maybe_add_preloads(opts[:preload])
    |> maybe_add_select(opts[:select])
    |> maybe_add_limit(opts[:limit])
  end

  @doc """
  Executes a query with performance monitoring.
  """
  def execute_monitored(query, query_name) do
    monitor_query(query_name, fn ->
      Repo.all(query)
    end)
  end

  @doc """
  Batches operations to reduce database load.
  """
  def batch_insert(entries, schema, batch_size \\ 1000) do
    entries
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce({0, []}, fn batch, {total_inserted, errors} ->
      case Repo.insert_all(schema, batch, returning: true) do
        {count, _} ->
          {total_inserted + count, errors}
        
        error ->
          Logger.error("Batch insert failed", %{
            schema: schema,
            batch_size: length(batch),
            error: inspect(error)
          })
          {total_inserted, [error | errors]}
      end
    end)
  end

  # Private functions

  defp slow_query_threshold do
    Application.get_env(:linkedin_ai, :slow_query_threshold_ms, 1000)
  end

  defp record_query_performance(query_name, duration) do
    # Store in ETS table for performance metrics
    table_name = :query_performance_metrics
    
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :public, :bag])
      _ ->
        :ok
    end
    
    timestamp = System.system_time(:second)
    :ets.insert(table_name, {query_name, duration, timestamp})
    
    # Keep only last hour of data
    cutoff = timestamp - 3600
    :ets.select_delete(table_name, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
  end

  defp analyze_connection_pool do
    # Get connection pool information from DBConnection
    try do
      pool_size = Application.get_env(:linkedin_ai, LinkedinAi.Repo)[:pool_size] || 10
      
      %{
        configured_pool_size: pool_size,
        status: "active"
      }
    rescue
      _ ->
        %{error: "Unable to analyze connection pool"}
    end
  end

  defp get_slow_queries do
    case :ets.whereis(:query_performance_metrics) do
      :undefined ->
        []
      
      table ->
        threshold = slow_query_threshold()
        
        :ets.select(table, [
          {{:"$1", :"$2", :"$3"}, [{:>, :"$2", threshold}], [%{query: :"$1", duration: :"$2", timestamp: :"$3"}]}
        ])
        |> Enum.sort_by(& &1.duration, :desc)
        |> Enum.take(10)
    end
  end

  defp analyze_index_usage do
    # This would require PostgreSQL-specific queries
    # For now, return a placeholder
    %{
      unused_indexes: [],
      missing_indexes: [],
      index_scan_ratio: 0.95
    }
  end

  defp get_table_sizes do
    query = """
    SELECT 
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
      pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
    FROM pg_tables 
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 10
    """
    
    case Repo.query(query) do
      {:ok, result} ->
        Enum.map(result.rows, fn [schema, table, size, size_bytes] ->
          %{schema: schema, table: table, size: size, size_bytes: size_bytes}
        end)
      
      {:error, _} ->
        []
    end
  rescue
    _ ->
      []
  end

  defp generate_optimization_suggestions do
    [
      "Consider adding indexes for frequently queried columns",
      "Monitor connection pool usage during peak hours",
      "Review slow queries and optimize with proper indexes",
      "Consider partitioning large tables if they grow significantly",
      "Use EXPLAIN ANALYZE to understand query execution plans"
    ]
  end

  defp get_active_connections do
    query = "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'"
    
    case Repo.query(query) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp get_total_connections do
    query = "SELECT count(*) FROM pg_stat_activity"
    
    case Repo.query(query) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp get_cache_hit_ratio do
    query = """
    SELECT 
      round(
        (sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read))) * 100, 
        2
      ) as cache_hit_ratio
    FROM pg_statio_user_tables
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [[ratio]]}} when is_number(ratio) -> ratio
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp get_index_hit_ratio do
    query = """
    SELECT 
      round(
        (sum(idx_blks_hit) / (sum(idx_blks_hit) + sum(idx_blks_read))) * 100, 
        2
      ) as index_hit_ratio
    FROM pg_statio_user_indexes
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [[ratio]]}} when is_number(ratio) -> ratio
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp get_deadlock_count do
    query = "SELECT deadlocks FROM pg_stat_database WHERE datname = current_database()"
    
    case Repo.query(query) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp get_temp_file_usage do
    query = """
    SELECT 
      temp_files,
      pg_size_pretty(temp_bytes) as temp_bytes_pretty,
      temp_bytes
    FROM pg_stat_database 
    WHERE datname = current_database()
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [[files, pretty, bytes]]}} ->
        %{temp_files: files, temp_bytes_pretty: pretty, temp_bytes: bytes}
      _ ->
        %{temp_files: 0, temp_bytes_pretty: "0 bytes", temp_bytes: 0}
    end
  rescue
    _ ->
      %{temp_files: 0, temp_bytes_pretty: "0 bytes", temp_bytes: 0}
  end

  defp maybe_add_preloads(query, nil), do: query
  defp maybe_add_preloads(query, preloads) when is_list(preloads) do
    import Ecto.Query
    preload(query, ^preloads)
  end
  defp maybe_add_preloads(query, preload_spec) do
    import Ecto.Query
    preload(query, ^preload_spec)
  end

  defp maybe_add_select(query, nil), do: query
  defp maybe_add_select(query, fields) do
    import Ecto.Query
    select(query, ^fields)
  end

  defp maybe_add_limit(query, nil), do: query
  defp maybe_add_limit(query, limit_val) do
    import Ecto.Query
    limit(query, ^limit_val)
  end
end
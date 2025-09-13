defmodule LinkedinAiWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug for API endpoints and sensitive operations.
  Uses ETS tables for in-memory rate limiting with configurable limits.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Plug

  @default_limit 100
  # 1 hour
  @default_window_seconds 3600
  # 5 minutes
  @cleanup_interval 300_000

  def init(opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    window_seconds = Keyword.get(opts, :window_seconds, @default_window_seconds)
    key_generator = Keyword.get(opts, :key_generator, &default_key_generator/1)

    table_name = Keyword.get(opts, :table_name, :rate_limiter)

    # Create ETS table if it doesn't exist
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :public, :set])
        schedule_cleanup(table_name, window_seconds)

      _ ->
        :ok
    end

    %{
      limit: limit,
      window_seconds: window_seconds,
      key_generator: key_generator,
      table_name: table_name
    }
  end

  def call(conn, opts) do
    key = opts.key_generator.(conn)
    current_time = System.system_time(:second)
    window_start = current_time - opts.window_seconds

    # Clean old entries for this key
    clean_old_entries(opts.table_name, key, window_start)

    # Get current count
    current_count = get_request_count(opts.table_name, key, window_start)

    if current_count >= opts.limit do
      # Rate limit exceeded
      LinkedinAi.Security.log_security_event(
        "rate_limit_exceeded",
        %{
          key: key,
          limit: opts.limit,
          current_count: current_count,
          endpoint: "#{conn.method} #{conn.request_path}"
        }
      )

      conn
      |> put_status(:too_many_requests)
      |> json(%{
        error: "Rate limit exceeded",
        limit: opts.limit,
        window_seconds: opts.window_seconds,
        retry_after: opts.window_seconds
      })
      |> halt()
    else
      # Record this request
      :ets.insert(opts.table_name, {{key, current_time}, 1})

      # Add rate limit headers
      conn
      |> put_resp_header("x-ratelimit-limit", to_string(opts.limit))
      |> put_resp_header("x-ratelimit-remaining", to_string(opts.limit - current_count - 1))
      |> put_resp_header("x-ratelimit-reset", to_string(current_time + opts.window_seconds))
    end
  end

  # Default key generator uses IP address
  defp default_key_generator(conn) do
    case get_client_ip(conn) do
      nil -> "unknown"
      ip -> to_string(:inet.ntoa(ip))
    end
  end

  # Key generator for authenticated users
  def user_key_generator(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> "user:#{user_id}"
      _ -> default_key_generator(conn)
    end
  end

  # Key generator for API endpoints
  def api_key_generator(conn) do
    api_key = get_req_header(conn, "x-api-key") |> List.first()

    case api_key do
      nil -> default_key_generator(conn)
      # Use first 8 chars for privacy
      key -> "api:#{String.slice(key, 0, 8)}"
    end
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()
        |> parse_ip()

      [] ->
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          _ -> nil
        end
    end
  end

  defp parse_ip(ip_string) do
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, ip} -> ip
      {:error, _} -> nil
    end
  end

  defp get_request_count(table_name, key, window_start) do
    match_pattern = {{key, :"$1"}, :"$2"}
    guard = [{:>=, :"$1", window_start}]
    select = [:"$2"]

    :ets.select(table_name, [{match_pattern, guard, select}])
    |> Enum.sum()
  end

  defp clean_old_entries(table_name, key, window_start) do
    match_pattern = {{key, :"$1"}, :_}
    guard = [{:<, :"$1", window_start}]

    :ets.select_delete(table_name, [{match_pattern, guard, [true]}])
  end

  defp schedule_cleanup(table_name, window_seconds) do
    Process.send_after(
      self(),
      {:cleanup_rate_limiter, table_name, window_seconds},
      @cleanup_interval
    )
  end

  # Handle cleanup messages
  def handle_info({:cleanup_rate_limiter, table_name, window_seconds}, state) do
    current_time = System.system_time(:second)
    window_start = current_time - window_seconds

    # Clean all old entries
    match_pattern = {{:_, :"$1"}, :_}
    guard = [{:<, :"$1", window_start}]
    :ets.select_delete(table_name, [{match_pattern, guard, [true]}])

    # Schedule next cleanup
    schedule_cleanup(table_name, window_seconds)

    {:noreply, state}
  end
end

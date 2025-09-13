defmodule LinkedinAiWeb.Plugs.RateLimiterTest do
  use LinkedinAiWeb.ConnCase, async: false

  alias LinkedinAiWeb.Plugs.RateLimiter

  setup do
    # Clean up any existing ETS tables
    case :ets.whereis(:test_rate_limiter) do
      :undefined -> :ok
      _ -> :ets.delete(:test_rate_limiter)
    end

    :ok
  end

  describe "rate limiting" do
    test "allows requests under the limit" do
      opts = RateLimiter.init(limit: 5, window_seconds: 60, table_name: :test_rate_limiter)

      conn = build_conn(:get, "/test")

      # First request should pass
      conn = RateLimiter.call(conn, opts)
      refute conn.halted
      assert get_resp_header(conn, "x-ratelimit-limit") == ["5"]
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["4"]
    end

    test "blocks requests over the limit" do
      opts = RateLimiter.init(limit: 2, window_seconds: 60, table_name: :test_rate_limiter)

      conn = build_conn(:get, "/test")

      # First two requests should pass
      conn1 = RateLimiter.call(conn, opts)
      refute conn1.halted

      conn2 = RateLimiter.call(conn, opts)
      refute conn2.halted

      # Third request should be blocked
      conn3 = RateLimiter.call(conn, opts)
      assert conn3.halted
      assert conn3.status == 429
    end

    test "uses custom key generator" do
      key_gen = fn _conn -> "custom_key" end

      opts =
        RateLimiter.init(
          limit: 1,
          window_seconds: 60,
          key_generator: key_gen,
          table_name: :test_rate_limiter
        )

      conn1 = build_conn(:get, "/test") |> put_req_header("x-forwarded-for", "1.1.1.1")
      conn2 = build_conn(:get, "/test") |> put_req_header("x-forwarded-for", "2.2.2.2")

      # First request should pass
      conn1 = RateLimiter.call(conn1, opts)
      refute conn1.halted

      # Second request from different IP should be blocked (same custom key)
      conn2 = RateLimiter.call(conn2, opts)
      assert conn2.halted
    end
  end

  describe "user_key_generator/1" do
    test "uses user ID when available" do
      user = %{id: 123}
      conn = build_conn(:get, "/test") |> assign(:current_user, user)

      key = RateLimiter.user_key_generator(conn)
      assert key == "user:123"
    end

    test "falls back to IP when no user" do
      conn = build_conn(:get, "/test")

      key = RateLimiter.user_key_generator(conn)
      assert key != "user:"
    end
  end

  describe "api_key_generator/1" do
    test "uses API key when provided" do
      conn = build_conn(:get, "/test") |> put_req_header("x-api-key", "sk-1234567890")

      key = RateLimiter.api_key_generator(conn)
      assert key == "api:sk-12345"
    end

    test "falls back to IP when no API key" do
      conn = build_conn(:get, "/test")

      key = RateLimiter.api_key_generator(conn)
      assert key != "api:"
    end
  end
end

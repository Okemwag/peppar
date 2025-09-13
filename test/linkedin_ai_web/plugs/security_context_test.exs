defmodule LinkedinAiWeb.Plugs.SecurityContextTest do
  use LinkedinAiWeb.ConnCase, async: true

  alias LinkedinAiWeb.Plugs.SecurityContext

  describe "security context capture" do
    test "captures client IP from remote_ip" do
      conn = build_conn(:get, "/")
      conn = %{conn | remote_ip: {192, 168, 1, 1}}
      
      conn = SecurityContext.call(conn, SecurityContext.init([]))
      
      assert conn.assigns.client_ip == "192.168.1.1"
      assert Process.get(:client_ip) == "192.168.1.1"
    end

    test "captures client IP from x-forwarded-for header" do
      conn = build_conn(:get, "/")
      conn = put_req_header(conn, "x-forwarded-for", "203.0.113.1, 192.168.1.1")
      
      conn = SecurityContext.call(conn, SecurityContext.init([]))
      
      assert conn.assigns.client_ip == "203.0.113.1"
    end

    test "captures client IP from x-real-ip header" do
      conn = build_conn(:get, "/")
      conn = put_req_header(conn, "x-real-ip", "203.0.113.2")
      
      conn = SecurityContext.call(conn, SecurityContext.init([]))
      
      assert conn.assigns.client_ip == "203.0.113.2"
    end

    test "captures user agent" do
      conn = build_conn(:get, "/")
      conn = put_req_header(conn, "user-agent", "Mozilla/5.0 Test Browser")
      
      conn = SecurityContext.call(conn, SecurityContext.init([]))
      
      assert conn.assigns.user_agent == "Mozilla/5.0 Test Browser"
      assert Process.get(:user_agent) == "Mozilla/5.0 Test Browser"
    end

    test "handles missing user agent" do
      conn = build_conn(:get, "/")
      
      conn = SecurityContext.call(conn, SecurityContext.init([]))
      
      assert conn.assigns.user_agent == "unknown"
    end

    test "handles IPv6 addresses" do
      conn = build_conn(:get, "/")
      conn = %{conn | remote_ip: {8193, 3512, 34211, 0, 0, 35374, 880, 29492}}
      
      conn = SecurityContext.call(conn, SecurityContext.init([]))
      
      # IPv6 should be formatted properly
      assert is_binary(conn.assigns.client_ip)
      assert String.contains?(conn.assigns.client_ip, ":")
    end
  end
end
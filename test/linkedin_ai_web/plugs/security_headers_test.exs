defmodule LinkedinAiWeb.Plugs.SecurityHeadersTest do
  use LinkedinAiWeb.ConnCase, async: true

  alias LinkedinAiWeb.Plugs.SecurityHeaders

  describe "security headers" do
    test "adds security headers to response" do
      conn = build_conn(:get, "/")
      conn = SecurityHeaders.call(conn, SecurityHeaders.init([]))

      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-xss-protection") == ["1; mode=block"]
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]

      assert get_resp_header(conn, "permissions-policy") == [
               "geolocation=(), microphone=(), camera=()"
             ]
    end

    test "adds content security policy" do
      conn = build_conn(:get, "/")
      conn = SecurityHeaders.call(conn, SecurityHeaders.init([]))

      csp_headers = get_resp_header(conn, "content-security-policy")
      assert length(csp_headers) == 1

      csp = hd(csp_headers)
      assert String.contains?(csp, "default-src 'self'")
      assert String.contains?(csp, "script-src 'self'")
      assert String.contains?(csp, "object-src 'none'")
    end

    test "adds HSTS header for HTTPS connections" do
      conn = build_conn(:get, "/")
      conn = %{conn | scheme: :https}
      conn = SecurityHeaders.call(conn, SecurityHeaders.init([]))

      hsts_headers = get_resp_header(conn, "strict-transport-security")
      assert hsts_headers == ["max-age=31536000; includeSubDomains"]
    end

    test "does not add HSTS header for HTTP connections" do
      conn = build_conn(:get, "/")
      conn = %{conn | scheme: :http}
      conn = SecurityHeaders.call(conn, SecurityHeaders.init([]))

      hsts_headers = get_resp_header(conn, "strict-transport-security")
      assert hsts_headers == []
    end
  end
end

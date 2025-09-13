defmodule LinkedinAiWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Adds security headers to HTTP responses for enhanced security.
  """

  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_content_security_policy()
    |> put_strict_transport_security()
  end

  defp put_content_security_policy(conn) do
    csp =
      [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com https://checkout.stripe.com",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
        "font-src 'self' https://fonts.gstatic.com",
        "img-src 'self' data: https: blob:",
        "connect-src 'self' https://api.openai.com https://api.stripe.com https://api.linkedin.com wss:",
        "frame-src https://js.stripe.com https://hooks.stripe.com",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ]
      |> Enum.join("; ")

    put_resp_header(conn, "content-security-policy", csp)
  end

  defp put_strict_transport_security(conn) do
    if conn.scheme == :https do
      put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains")
    else
      conn
    end
  end
end

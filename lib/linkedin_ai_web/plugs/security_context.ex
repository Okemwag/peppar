defmodule LinkedinAiWeb.Plugs.SecurityContext do
  @moduledoc """
  Captures security context information for logging and audit purposes.
  """

  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    # Extract client IP
    client_ip = get_client_ip(conn)

    # Extract user agent
    user_agent = get_req_header(conn, "user-agent") |> List.first() || "unknown"

    # Store in process dictionary for security logging
    Process.put(:client_ip, client_ip)
    Process.put(:user_agent, user_agent)

    # Also store in conn assigns for easy access
    conn
    |> assign(:client_ip, client_ip)
    |> assign(:user_agent, user_agent)
  end

  defp get_client_ip(conn) do
    # Check for forwarded headers first (for load balancers/proxies)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Check other common forwarded headers
        case get_req_header(conn, "x-real-ip") do
          [real_ip | _] ->
            real_ip

          [] ->
            # Fall back to remote_ip
            case conn.remote_ip do
              {a, b, c, d} ->
                "#{a}.#{b}.#{c}.#{d}"

              {a, b, c, d, e, f, g, h} ->
                # IPv6 address
                [a, b, c, d, e, f, g, h]
                |> Enum.map(&Integer.to_string(&1, 16))
                |> Enum.join(":")

              _ ->
                "unknown"
            end
        end
    end
  end
end

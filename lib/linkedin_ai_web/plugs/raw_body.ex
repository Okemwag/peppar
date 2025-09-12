defmodule LinkedinAiWeb.Plugs.RawBody do
  @moduledoc """
  Plug to capture the raw request body for webhook signature verification.
  """
  
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    {:ok, body, conn} = read_body(conn)
    assign(conn, :raw_body, body)
  end
end
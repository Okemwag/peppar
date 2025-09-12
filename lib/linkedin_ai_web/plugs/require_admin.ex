defmodule LinkedinAiWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug to ensure the current user has admin role.
  Redirects non-admin users to the dashboard with an error message.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias LinkedinAi.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %User{role: "admin", account_status: "active"} ->
        conn

      %User{role: "admin"} ->
        conn
        |> put_flash(:error, "Account suspended. Please contact support.")
        |> redirect(to: "/dashboard")
        |> halt()

      %User{} ->
        conn
        |> put_flash(:error, "Access denied. Admin privileges required.")
        |> redirect(to: "/dashboard")
        |> halt()

      nil ->
        conn
        |> put_flash(:error, "Please log in to access this area.")
        |> redirect(to: "/users/log_in")
        |> halt()
    end
  end
end
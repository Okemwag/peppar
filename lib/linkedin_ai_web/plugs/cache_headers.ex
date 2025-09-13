defmodule LinkedinAiWeb.Plugs.CacheHeaders do
  @moduledoc """
  Adds appropriate cache headers to HTTP responses.
  """

  import Plug.Conn
  alias LinkedinAi.CDN

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    cache_type = determine_cache_type(conn, opts)
    add_cache_headers(conn, cache_type)
  end

  defp determine_cache_type(conn, opts) do
    cond do
      # Override from options
      opts[:cache_type] ->
        opts[:cache_type]
      
      # Static assets
      static_asset?(conn.request_path) ->
        if immutable_asset?(conn.request_path) do
          :immutable
        else
          :long_term
        end
      
      # API endpoints
      api_endpoint?(conn.request_path) ->
        :short_term
      
      # Dynamic pages
      authenticated_user?(conn) ->
        :no_cache
      
      # Public pages
      true ->
        :default
    end
  end

  defp add_cache_headers(conn, cache_type) do
    headers = CDN.cache_headers(cache_type)
    
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      put_resp_header(acc, key, value)
    end)
  end

  defp static_asset?(path) do
    String.starts_with?(path, "/assets/") or
    String.starts_with?(path, "/images/") or
    String.starts_with?(path, "/fonts/") or
    String.match?(path, ~r/\.(css|js|png|jpg|jpeg|gif|svg|woff|woff2|ttf|ico)$/)
  end

  defp immutable_asset?(path) do
    # Assets with hashes in filename are immutable
    String.match?(path, ~r/-[a-f0-9]{8,}\.(css|js)$/) or
    String.contains?(path, "/assets/") and String.contains?(path, "-")
  end

  defp api_endpoint?(path) do
    String.starts_with?(path, "/api/")
  end

  defp authenticated_user?(conn) do
    case conn.assigns[:current_user] do
      nil -> false
      _ -> true
    end
  end
end
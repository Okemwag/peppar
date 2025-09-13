defmodule LinkedinAi.CORS do
  @moduledoc """
  CORS configuration for production environment.
  
  This module handles Cross-Origin Resource Sharing (CORS) configuration
  for the LinkedIn AI Platform, allowing controlled access from web browsers.
  """

  @doc """
  Determines if an origin is allowed for CORS requests.
  
  In production, this checks against a whitelist of allowed origins
  from environment variables.
  """
  def origin_allowed?(origin) do
    allowed_origins = get_allowed_origins()
    
    cond do
      # Always allow same-origin requests
      is_nil(origin) -> true
      
      # Check against whitelist
      origin in allowed_origins -> true
      
      # Allow localhost in development/test
      Mix.env() != :prod and localhost_origin?(origin) -> true
      
      # Deny all others
      true -> false
    end
  end

  defp get_allowed_origins do
    System.get_env("CORS_ORIGINS", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp localhost_origin?(origin) do
    String.contains?(origin, "localhost") or 
    String.contains?(origin, "127.0.0.1") or
    String.contains?(origin, "0.0.0.0")
  end
end
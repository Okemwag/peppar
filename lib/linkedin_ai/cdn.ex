defmodule LinkedinAi.CDN do
  @moduledoc """
  CDN configuration and asset management for the LinkedIn AI platform.
  """

  @doc """
  Gets the CDN URL for static assets.
  """
  def asset_url(path) do
    case cdn_host() do
      nil -> path
      host -> "#{host}#{path}"
    end
  end

  @doc """
  Gets the CDN URL for uploaded files.
  """
  def file_url(path) do
    case file_cdn_host() do
      nil -> path
      host -> "#{host}#{path}"
    end
  end

  @doc """
  Generates cache-busted URLs for assets.
  """
  def versioned_asset_url(path) do
    version = asset_version()
    base_url = asset_url(path)
    
    if String.contains?(base_url, "?") do
      "#{base_url}&v=#{version}"
    else
      "#{base_url}?v=#{version}"
    end
  end

  @doc """
  Gets cache headers for static assets.
  """
  def cache_headers(asset_type \\ :default) do
    case asset_type do
      :immutable ->
        [
          {"cache-control", "public, max-age=31536000, immutable"},
          {"expires", expires_header(365)}
        ]
      
      :long_term ->
        [
          {"cache-control", "public, max-age=2592000"},
          {"expires", expires_header(30)}
        ]
      
      :short_term ->
        [
          {"cache-control", "public, max-age=3600"},
          {"expires", expires_header(1)}
        ]
      
      :no_cache ->
        [
          {"cache-control", "no-cache, no-store, must-revalidate"},
          {"pragma", "no-cache"},
          {"expires", "0"}
        ]
      
      :default ->
        [
          {"cache-control", "public, max-age=86400"},
          {"expires", expires_header(1)}
        ]
    end
  end

  @doc """
  Purges CDN cache for specific paths.
  """
  def purge_cache(paths) when is_list(paths) do
    if cdn_purge_enabled?() do
      # This would integrate with your CDN provider's API
      # For now, just log the action
      require Logger
      Logger.info("Purging CDN cache for paths: #{inspect(paths)}")
      
      # Example for CloudFlare API
      # purge_cloudflare_cache(paths)
      
      :ok
    else
      :disabled
    end
  end

  def purge_cache(path) when is_binary(path) do
    purge_cache([path])
  end

  @doc """
  Preloads critical assets.
  """
  def preload_headers do
    critical_assets = [
      "/assets/app.css",
      "/assets/app.js"
    ]
    
    Enum.map(critical_assets, fn asset ->
      {"link", "<#{asset_url(asset)}>; rel=preload; as=#{asset_type(asset)}"}
    end)
  end

  @doc """
  Gets optimized image URL with transformations.
  """
  def optimized_image_url(path, opts \\ []) do
    width = Keyword.get(opts, :width)
    height = Keyword.get(opts, :height)
    quality = Keyword.get(opts, :quality, 85)
    format = Keyword.get(opts, :format, "webp")
    
    base_url = file_url(path)
    
    # Build transformation parameters
    params = []
    params = if width, do: ["w_#{width}" | params], else: params
    params = if height, do: ["h_#{height}" | params], else: params
    params = ["q_#{quality}", "f_#{format}" | params]
    
    if length(params) > 0 do
      transform_string = Enum.join(params, ",")
      # This would work with image transformation services like Cloudinary
      String.replace(base_url, "/upload/", "/upload/#{transform_string}/")
    else
      base_url
    end
  end

  # Private functions

  defp cdn_host do
    Application.get_env(:linkedin_ai, :cdn_host)
  end

  defp file_cdn_host do
    Application.get_env(:linkedin_ai, :file_cdn_host) || cdn_host()
  end

  defp asset_version do
    Application.get_env(:linkedin_ai, :asset_version) || 
      System.get_env("ASSET_VERSION") || 
      "1.0.0"
  end

  defp cdn_purge_enabled? do
    Application.get_env(:linkedin_ai, :cdn_purge_enabled, false)
  end

  defp expires_header(days) do
    DateTime.utc_now()
    |> DateTime.add(days * 24 * 60 * 60, :second)
    |> DateTime.to_string()
  end

  defp asset_type(path) do
    cond do
      String.ends_with?(path, ".css") -> "style"
      String.ends_with?(path, ".js") -> "script"
      String.ends_with?(path, [".woff", ".woff2", ".ttf"]) -> "font"
      String.ends_with?(path, [".jpg", ".jpeg", ".png", ".webp", ".svg"]) -> "image"
      true -> "fetch"
    end
  end

  # Example CloudFlare integration (commented out)
  # defp purge_cloudflare_cache(paths) do
  #   zone_id = System.get_env("CLOUDFLARE_ZONE_ID")
  #   api_token = System.get_env("CLOUDFLARE_API_TOKEN")
  #   
  #   if zone_id && api_token do
  #     url = "https://api.cloudflare.com/client/v4/zones/#{zone_id}/purge_cache"
  #     headers = [
  #       {"Authorization", "Bearer #{api_token}"},
  #       {"Content-Type", "application/json"}
  #     ]
  #     body = Jason.encode!(%{files: paths})
  #     
  #     case HTTPoison.post(url, body, headers) do
  #       {:ok, %{status_code: 200}} -> :ok
  #       {:ok, response} -> {:error, response}
  #       {:error, reason} -> {:error, reason}
  #     end
  #   else
  #     {:error, :missing_credentials}
  #   end
  # end
end
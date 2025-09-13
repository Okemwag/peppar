defmodule LinkedinAiWeb.Plugs.CacheHeadersTest do
  use LinkedinAiWeb.ConnCase, async: true

  alias LinkedinAiWeb.Plugs.CacheHeaders

  describe "cache headers for static assets" do
    test "adds long-term cache headers for CSS files" do
      conn = build_conn(:get, "/assets/app.css")
      conn = CacheHeaders.call(conn, CacheHeaders.init([]))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["public, max-age=2592000"]
      
      expires = get_resp_header(conn, "expires")
      assert length(expires) == 1
    end

    test "adds long-term cache headers for JS files" do
      conn = build_conn(:get, "/assets/app.js")
      conn = CacheHeaders.call(conn, CacheHeaders.init([]))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["public, max-age=2592000"]
    end

    test "adds immutable cache headers for versioned assets" do
      conn = build_conn(:get, "/assets/app-abc12345.css")
      conn = CacheHeaders.call(conn, CacheHeaders.init([]))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["public, max-age=31536000, immutable"]
    end

    test "adds long-term cache headers for images" do
      conn = build_conn(:get, "/images/logo.png")
      conn = CacheHeaders.call(conn, CacheHeaders.init([]))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["public, max-age=2592000"]
    end
  end

  describe "cache headers for API endpoints" do
    test "adds short-term cache headers for API endpoints" do
      conn = build_conn(:get, "/api/health")
      conn = CacheHeaders.call(conn, CacheHeaders.init([]))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["public, max-age=3600"]
    end
  end

  describe "cache headers for authenticated users" do
    test "adds no-cache headers for authenticated users" do
      user = %{id: 1, email: "test@example.com"}
      conn = build_conn(:get, "/dashboard")
      conn = assign(conn, :current_user, user)
      conn = CacheHeaders.call(conn, CacheHeaders.init([]))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["no-cache, no-store, must-revalidate"]
      
      pragma = get_resp_header(conn, "pragma")
      assert pragma == ["no-cache"]
      
      expires = get_resp_header(conn, "expires")
      assert expires == ["0"]
    end
  end

  describe "cache headers for public pages" do
    test "adds default cache headers for public pages" do
      conn = build_conn(:get, "/")
      conn = CacheHeaders.call(conn, CacheHeaders.init([]))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["public, max-age=86400"]
    end
  end

  describe "cache type override" do
    test "respects cache_type option" do
      conn = build_conn(:get, "/some-page")
      conn = CacheHeaders.call(conn, CacheHeaders.init(cache_type: :no_cache))

      cache_control = get_resp_header(conn, "cache-control")
      assert cache_control == ["no-cache, no-store, must-revalidate"]
    end
  end
end
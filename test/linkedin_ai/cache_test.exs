defmodule LinkedinAi.CacheTest do
  use LinkedinAi.DataCase, async: false

  alias LinkedinAi.Cache
  alias LinkedinAi.AccountsFixtures

  setup do
    # Start cache processes for testing
    start_supervised!({Cachex, name: :test_cache, limit: 1000})
    :ok
  end

  describe "get_or_compute/4" do
    test "computes and caches value on first call" do
      compute_fn = fn -> {:ok, "computed_value"} end
      
      {:ok, value} = Cache.get_or_compute(:test_cache, "test_key", compute_fn)
      assert value == "computed_value"
      
      # Verify it's cached
      {:ok, cached_value} = Cache.get(:test_cache, "test_key")
      assert cached_value == "computed_value"
    end

    test "returns cached value on subsequent calls" do
      compute_fn = fn -> {:ok, "computed_value"} end
      
      # First call
      {:ok, _} = Cache.get_or_compute(:test_cache, "test_key", compute_fn)
      
      # Second call should return cached value without calling compute_fn
      compute_fn_2 = fn -> {:ok, "different_value"} end
      {:ok, value} = Cache.get_or_compute(:test_cache, "test_key", compute_fn_2)
      
      assert value == "computed_value"
    end

    test "handles compute function errors" do
      compute_fn = fn -> {:error, :computation_failed} end
      
      result = Cache.get_or_compute(:test_cache, "error_key", compute_fn)
      assert result == {:error, :computation_failed}
      
      # Verify error is not cached
      assert {:error, :not_found} = Cache.get(:test_cache, "error_key")
    end
  end

  describe "put/4 and get/2" do
    test "stores and retrieves values" do
      :ok = Cache.put(:test_cache, "key1", "value1")
      
      {:ok, value} = Cache.get(:test_cache, "key1")
      assert value == "value1"
    end

    test "returns error for non-existent keys" do
      assert {:error, :not_found} = Cache.get(:test_cache, "non_existent")
    end
  end

  describe "delete/2" do
    test "removes values from cache" do
      Cache.put(:test_cache, "key_to_delete", "value")
      {:ok, _} = Cache.get(:test_cache, "key_to_delete")
      
      Cache.delete(:test_cache, "key_to_delete")
      assert {:error, :not_found} = Cache.get(:test_cache, "key_to_delete")
    end
  end

  describe "invalidate_pattern/2" do
    test "invalidates keys matching pattern" do
      Cache.put(:test_cache, "user:1:profile", "profile1")
      Cache.put(:test_cache, "user:1:settings", "settings1")
      Cache.put(:test_cache, "user:2:profile", "profile2")
      Cache.put(:test_cache, "other:key", "other")
      
      {:ok, count} = Cache.invalidate_pattern(:test_cache, "user:1")
      assert count == 2
      
      # Verify correct keys were deleted
      assert {:error, :not_found} = Cache.get(:test_cache, "user:1:profile")
      assert {:error, :not_found} = Cache.get(:test_cache, "user:1:settings")
      assert {:ok, "profile2"} = Cache.get(:test_cache, "user:2:profile")
      assert {:ok, "other"} = Cache.get(:test_cache, "other:key")
    end
  end

  describe "cache_user/1 and get_user/1" do
    test "caches and retrieves user data" do
      user = AccountsFixtures.user_fixture()
      
      Cache.cache_user(user)
      
      {:ok, cached_user} = Cache.get_user(user.id)
      assert cached_user.id == user.id
      assert cached_user.email == user.email
    end

    test "caches user by email" do
      user = AccountsFixtures.user_fixture()
      
      Cache.cache_user(user)
      
      {:ok, cached_user} = Cache.get_user_by_email(user.email)
      assert cached_user.id == user.id
    end
  end

  describe "cache_api_response/4 and get_api_response/2" do
    test "caches and retrieves API responses" do
      endpoint = "openai/completions"
      params = %{model: "gpt-3.5-turbo", prompt: "test"}
      response = %{choices: [%{text: "response"}]}
      
      Cache.cache_api_response(endpoint, params, response)
      
      {:ok, cached_response} = Cache.get_api_response(endpoint, params)
      assert cached_response == response
    end

    test "different parameters create different cache keys" do
      endpoint = "openai/completions"
      params1 = %{model: "gpt-3.5-turbo", prompt: "test1"}
      params2 = %{model: "gpt-3.5-turbo", prompt: "test2"}
      response1 = %{choices: [%{text: "response1"}]}
      response2 = %{choices: [%{text: "response2"}]}
      
      Cache.cache_api_response(endpoint, params1, response1)
      Cache.cache_api_response(endpoint, params2, response2)
      
      {:ok, cached1} = Cache.get_api_response(endpoint, params1)
      {:ok, cached2} = Cache.get_api_response(endpoint, params2)
      
      assert cached1 == response1
      assert cached2 == response2
    end
  end

  describe "cache_analytics/3 and get_analytics/1" do
    test "caches and retrieves analytics data" do
      key = "daily_stats_2023_12_01"
      data = %{users: 100, posts: 500, engagement: 0.85}
      
      Cache.cache_analytics(key, data)
      
      {:ok, cached_data} = Cache.get_analytics(key)
      assert cached_data == data
    end
  end

  describe "stats/0" do
    test "returns cache statistics" do
      stats = Cache.stats()
      
      assert Map.has_key?(stats, :user_cache)
      assert Map.has_key?(stats, :content_cache)
      assert Map.has_key?(stats, :analytics_cache)
      assert Map.has_key?(stats, :api_response_cache)
    end
  end
end
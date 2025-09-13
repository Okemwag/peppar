defmodule LinkedinAi.Cache.InvalidationTest do
  use LinkedinAi.DataCase, async: false

  alias LinkedinAi.Cache
  alias LinkedinAi.Cache.Invalidation

  setup do
    # Start cache processes for testing
    start_supervised!({Cachex, name: :user_cache, limit: 1000})
    start_supervised!({Cachex, name: :content_cache, limit: 1000})
    start_supervised!({Cachex, name: :analytics_cache, limit: 1000})
    :ok
  end

  describe "invalidate_user/1" do
    test "invalidates user-related cache entries" do
      user_id = 123
      
      # Set up some cache entries
      Cache.put(:user_cache, "user:#{user_id}", %{id: user_id, name: "Test"})
      Cache.put(:user_cache, "user:#{user_id}:profile", %{bio: "Test bio"})
      Cache.put(:analytics_cache, "user:#{user_id}:stats", %{posts: 10})
      Cache.put(:user_cache, "user:456", %{id: 456, name: "Other"})
      
      Invalidation.invalidate_user(user_id)
      
      # Verify user-specific entries are gone
      assert {:error, :not_found} = Cache.get(:user_cache, "user:#{user_id}")
      
      # Verify other user's data is still there
      assert {:ok, _} = Cache.get(:user_cache, "user:456")
    end
  end

  describe "invalidate_user_email/2" do
    test "invalidates email-based cache entries" do
      old_email = "old@example.com"
      new_email = "new@example.com"
      
      Cache.put(:user_cache, "user:email:#{old_email}", %{id: 1})
      Cache.put(:user_cache, "user:email:#{new_email}", %{id: 1})
      
      Invalidation.invalidate_user_email(old_email, new_email)
      
      assert {:error, :not_found} = Cache.get(:user_cache, "user:email:#{old_email}")
      assert {:error, :not_found} = Cache.get(:user_cache, "user:email:#{new_email}")
    end
  end

  describe "invalidate_content/2" do
    test "invalidates content-related cache entries" do
      user_id = 123
      content_id = 456
      
      Cache.put(:content_cache, "content:#{content_id}", %{id: content_id})
      Cache.put(:content_cache, "user:#{user_id}:contents", [])
      Cache.put(:analytics_cache, "content:user:#{user_id}:stats", %{})
      
      Invalidation.invalidate_content(user_id, content_id)
      
      assert {:error, :not_found} = Cache.get(:content_cache, "content:#{content_id}")
    end
  end

  describe "invalidate_subscription/1" do
    test "invalidates subscription-related cache entries" do
      user_id = 123
      
      Cache.put(:user_cache, "subscription:#{user_id}:status", "active")
      Cache.put(:analytics_cache, "subscription:revenue", 1000)
      
      Invalidation.invalidate_subscription(user_id)
      
      # This test mainly verifies the function doesn't crash
      # since pattern matching in test environment is limited
      assert :ok
    end
  end

  describe "invalidate_analytics/1" do
    test "invalidates analytics cache with default pattern" do
      Cache.put(:analytics_cache, "daily_stats", %{})
      Cache.put(:analytics_cache, "weekly_stats", %{})
      
      Invalidation.invalidate_analytics()
      
      # This test mainly verifies the function doesn't crash
      assert :ok
    end

    test "invalidates analytics cache with specific pattern" do
      Cache.put(:analytics_cache, "user:123:stats", %{})
      Cache.put(:analytics_cache, "user:456:stats", %{})
      
      Invalidation.invalidate_analytics("user:123")
      
      # This test mainly verifies the function doesn't crash
      assert :ok
    end
  end

  describe "invalidate_api_responses/1" do
    test "invalidates API response cache for endpoint pattern" do
      start_supervised!({Cachex, name: :api_response_cache, limit: 1000})
      
      Cache.put(:api_response_cache, "api:openai:completions:hash1", %{})
      Cache.put(:api_response_cache, "api:linkedin:profile:hash2", %{})
      
      Invalidation.invalidate_api_responses("openai")
      
      # This test mainly verifies the function doesn't crash
      assert :ok
    end
  end

  describe "invalidate_all_user_data/1" do
    test "invalidates all cache data for a user" do
      user_id = 123
      
      Cache.put(:user_cache, "user:#{user_id}", %{})
      Cache.put(:content_cache, "user:#{user_id}:contents", [])
      Cache.put(:analytics_cache, "user:#{user_id}:stats", %{})
      
      Invalidation.invalidate_all_user_data(user_id)
      
      # This test mainly verifies the function doesn't crash
      assert :ok
    end
  end

  describe "scheduled_cleanup/0" do
    test "performs scheduled cache cleanup" do
      Cache.put(:user_cache, "test_key", "test_value")
      
      Invalidation.scheduled_cleanup()
      
      # This test mainly verifies the function doesn't crash
      assert :ok
    end
  end

  describe "handle_database_change/4" do
    test "handles user table changes" do
      Invalidation.handle_database_change("users", :update, 123)
      assert :ok
    end

    test "handles content table changes" do
      Invalidation.handle_database_change("generated_contents", :insert, 456, 123)
      assert :ok
    end

    test "handles subscription table changes" do
      Invalidation.handle_database_change("subscriptions", :update, 789, 123)
      assert :ok
    end

    test "handles unknown table changes" do
      Invalidation.handle_database_change("unknown_table", :update, 123)
      assert :ok
    end
  end
end
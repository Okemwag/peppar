defmodule LinkedinAi.Cache.Invalidation do
  @moduledoc """
  Handles cache invalidation strategies for the LinkedIn AI platform.
  """

  alias LinkedinAi.Cache
  require Logger

  @doc """
  Invalidates user-related cache entries when user data changes.
  """
  def invalidate_user(user_id) do
    Cache.delete(:user_cache, "user:#{user_id}")
    Cache.invalidate_pattern(:user_cache, "user:#{user_id}:*")
    Cache.invalidate_pattern(:analytics_cache, "user:#{user_id}:*")
    
    Logger.debug("Invalidated cache for user #{user_id}")
  end

  @doc """
  Invalidates user cache when email changes.
  """
  def invalidate_user_email(old_email, new_email) do
    Cache.delete(:user_cache, "user:email:#{old_email}")
    Cache.delete(:user_cache, "user:email:#{new_email}")
  end

  @doc """
  Invalidates content-related cache entries.
  """
  def invalidate_content(user_id, content_id \\ nil) do
    if content_id do
      Cache.delete(:content_cache, "content:#{content_id}")
    end
    
    Cache.invalidate_pattern(:content_cache, "user:#{user_id}:*")
    Cache.invalidate_pattern(:analytics_cache, "content:user:#{user_id}:*")
    
    Logger.debug("Invalidated content cache for user #{user_id}")
  end

  @doc """
  Invalidates subscription-related cache entries.
  """
  def invalidate_subscription(user_id) do
    Cache.invalidate_pattern(:user_cache, "subscription:#{user_id}:*")
    Cache.invalidate_pattern(:analytics_cache, "subscription:*")
    
    Logger.debug("Invalidated subscription cache for user #{user_id}")
  end

  @doc """
  Invalidates analytics cache entries.
  """
  def invalidate_analytics(pattern \\ "*") do
    Cache.invalidate_pattern(:analytics_cache, pattern)
    Cache.invalidate_redis_pattern("analytics:#{pattern}")
    
    Logger.debug("Invalidated analytics cache with pattern: #{pattern}")
  end

  @doc """
  Invalidates API response cache for specific endpoints.
  """
  def invalidate_api_responses(endpoint_pattern) do
    Cache.invalidate_pattern(:api_response_cache, "api:#{endpoint_pattern}:*")
    
    Logger.debug("Invalidated API response cache for: #{endpoint_pattern}")
  end

  @doc """
  Invalidates all cache entries for a user (used when user is deleted).
  """
  def invalidate_all_user_data(user_id) do
    invalidate_user(user_id)
    invalidate_content(user_id)
    invalidate_subscription(user_id)
    
    # Also invalidate any Redis entries
    Cache.invalidate_redis_pattern("user:#{user_id}:*")
    
    Logger.info("Invalidated all cache data for user #{user_id}")
  end

  @doc """
  Scheduled cache cleanup - removes expired entries and optimizes cache.
  """
  def scheduled_cleanup do
    Logger.info("Starting scheduled cache cleanup")
    
    # Cachex handles TTL automatically, but we can trigger cleanup
    Cachex.purge(:user_cache)
    Cachex.purge(:content_cache)
    Cachex.purge(:analytics_cache)
    Cachex.purge(:api_response_cache)
    
    Logger.info("Completed scheduled cache cleanup")
  end

  @doc """
  Invalidates cache based on database changes.
  """
  def handle_database_change(table, action, record_id, user_id \\ nil) do
    case {table, action} do
      {"users", _} ->
        invalidate_user(record_id)
      
      {"generated_contents", _} ->
        invalidate_content(user_id || record_id)
      
      {"subscriptions", _} ->
        invalidate_subscription(user_id || record_id)
      
      {"profile_analyses", _} ->
        invalidate_user(user_id || record_id)
        invalidate_analytics("profile:*")
      
      {_, _} ->
        Logger.debug("No cache invalidation rule for table: #{table}")
    end
  end
end
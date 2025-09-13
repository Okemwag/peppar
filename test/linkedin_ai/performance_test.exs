defmodule LinkedinAi.PerformanceTest do
  use LinkedinAi.DataCase, async: false

  alias LinkedinAi.Performance
  alias LinkedinAi.AccountsFixtures

  describe "monitor_query/2" do
    test "monitors query execution time" do
      result = Performance.monitor_query("test_query", fn ->
        Process.sleep(10)
        :ok
      end)

      assert result == :ok
    end

    test "logs slow queries" do
      # Mock a slow query threshold
      Application.put_env(:linkedin_ai, :slow_query_threshold_ms, 5)

      log_output = capture_log(fn ->
        Performance.monitor_query("slow_test_query", fn ->
          Process.sleep(10)
          :ok
        end)
      end)

      assert log_output =~ "Slow query detected"
      assert log_output =~ "slow_test_query"

      # Reset threshold
      Application.put_env(:linkedin_ai, :slow_query_threshold_ms, 1000)
    end

    test "handles query errors" do
      assert_raise RuntimeError, "test error", fn ->
        Performance.monitor_query("error_query", fn ->
          raise "test error"
        end)
      end
    end
  end

  describe "analyze_performance/0" do
    test "returns performance analysis" do
      analysis = Performance.analyze_performance()

      assert Map.has_key?(analysis, :connection_pool)
      assert Map.has_key?(analysis, :slow_queries)
      assert Map.has_key?(analysis, :index_usage)
      assert Map.has_key?(analysis, :table_sizes)
      assert Map.has_key?(analysis, :suggestions)
      assert is_list(analysis.suggestions)
    end
  end

  describe "get_database_stats/0" do
    test "returns database statistics" do
      stats = Performance.get_database_stats()

      assert Map.has_key?(stats, :active_connections)
      assert Map.has_key?(stats, :total_connections)
      assert Map.has_key?(stats, :cache_hit_ratio)
      assert Map.has_key?(stats, :index_hit_ratio)
      assert is_number(stats.active_connections)
      assert is_number(stats.total_connections)
    end
  end

  describe "optimize_query/2" do
    test "adds preloads to query" do
      import Ecto.Query
      
      base_query = from(u in LinkedinAi.Accounts.User)
      optimized = Performance.optimize_query(base_query, preload: [:subscription])

      # Check that preload was added (this is a bit tricky to test directly)
      assert optimized != base_query
    end

    test "adds limit to query" do
      import Ecto.Query
      
      base_query = from(u in LinkedinAi.Accounts.User)
      optimized = Performance.optimize_query(base_query, limit: 10)

      assert optimized != base_query
    end
  end

  describe "execute_monitored/2" do
    test "executes query with monitoring" do
      import Ecto.Query
      
      user = AccountsFixtures.user_fixture()
      query = from(u in LinkedinAi.Accounts.User, where: u.id == ^user.id)

      result = Performance.execute_monitored(query, "test_user_query")

      assert length(result) == 1
      assert hd(result).id == user.id
    end
  end

  describe "batch_insert/3" do
    test "inserts records in batches" do
      entries = [
        %{event_type: "test1", inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()},
        %{event_type: "test2", inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()},
        %{event_type: "test3", inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      ]

      {inserted_count, errors} = Performance.batch_insert(entries, LinkedinAi.Security.AuditLog, 2)

      assert inserted_count == 3
      assert errors == []
    end

    test "handles batch insert errors gracefully" do
      # Invalid entries (missing required fields)
      entries = [
        %{invalid_field: "test"},
        %{another_invalid: "test"}
      ]

      {inserted_count, errors} = Performance.batch_insert(entries, LinkedinAi.Security.AuditLog, 1)

      assert inserted_count == 0
      assert length(errors) > 0
    end
  end

  defp capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end
end
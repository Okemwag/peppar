defmodule LinkedinAi.Security.AuditLogTest do
  use LinkedinAi.DataCase, async: true

  alias LinkedinAi.Security.AuditLog
  alias LinkedinAi.AccountsFixtures

  describe "create_entry/1" do
    test "creates audit log entry with valid attributes" do
      user = AccountsFixtures.user_fixture()

      attrs = %{
        event_type: "login_attempt",
        details: %{success: true},
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        severity: :medium,
        user_id: user.id
      }

      assert {:ok, audit_log} = AuditLog.create_entry(attrs)
      assert audit_log.event_type == "login_attempt"
      assert audit_log.details == %{success: true}
      assert audit_log.ip_address == "192.168.1.1"
      assert audit_log.severity == :medium
      assert audit_log.user_id == user.id
    end

    test "creates entry without optional fields" do
      attrs = %{event_type: "system_event"}

      assert {:ok, audit_log} = AuditLog.create_entry(attrs)
      assert audit_log.event_type == "system_event"
      assert audit_log.severity == :medium
    end

    test "requires event_type" do
      attrs = %{details: %{test: "data"}}

      assert {:error, changeset} = AuditLog.create_entry(attrs)
      assert "can't be blank" in errors_on(changeset).event_type
    end
  end

  describe "list_entries/1" do
    setup do
      user = AccountsFixtures.user_fixture()

      {:ok, _} =
        AuditLog.create_entry(%{
          event_type: "login",
          user_id: user.id,
          severity: :low
        })

      {:ok, _} =
        AuditLog.create_entry(%{
          event_type: "logout",
          user_id: user.id,
          severity: :medium
        })

      {:ok, _} =
        AuditLog.create_entry(%{
          event_type: "security_alert",
          severity: :high
        })

      %{user: user}
    end

    test "lists all entries by default", %{user: user} do
      entries = AuditLog.list_entries()
      assert length(entries) == 3
    end

    test "filters by user_id", %{user: user} do
      entries = AuditLog.list_entries(user_id: user.id)
      assert length(entries) == 2
      assert Enum.all?(entries, &(&1.user_id == user.id))
    end

    test "filters by event_type" do
      entries = AuditLog.list_entries(event_type: "login")
      assert length(entries) == 1
      assert hd(entries).event_type == "login"
    end

    test "filters by severity" do
      entries = AuditLog.list_entries(severity: :high)
      assert length(entries) == 1
      assert hd(entries).severity == :high
    end

    test "limits results" do
      entries = AuditLog.list_entries(limit: 2)
      assert length(entries) == 2
    end
  end

  describe "get_user_entries/2" do
    test "gets entries for specific user" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()

      {:ok, _} = AuditLog.create_entry(%{event_type: "login", user_id: user.id})
      {:ok, _} = AuditLog.create_entry(%{event_type: "logout", user_id: other_user.id})

      entries = AuditLog.get_user_entries(user.id)
      assert length(entries) == 1
      assert hd(entries).user_id == user.id
    end
  end

  describe "get_recent_security_alerts/1" do
    test "gets recent high severity events" do
      {:ok, _} =
        AuditLog.create_entry(%{
          event_type: "security_breach",
          severity: :critical
        })

      {:ok, _} =
        AuditLog.create_entry(%{
          event_type: "failed_login",
          severity: :high
        })

      {:ok, _} =
        AuditLog.create_entry(%{
          event_type: "normal_login",
          severity: :low
        })

      alerts = AuditLog.get_recent_security_alerts()
      assert length(alerts) == 2
      assert Enum.all?(alerts, &(&1.severity in [:high, :critical]))
    end
  end

  describe "cleanup_old_entries/1" do
    test "removes old entries" do
      # Create an old entry by manually setting the timestamp
      old_date = DateTime.utc_now() |> DateTime.add(-100, :day)

      {:ok, old_entry} = AuditLog.create_entry(%{event_type: "old_event"})

      # Update the timestamp to be old
      from(a in AuditLog, where: a.id == ^old_entry.id)
      |> Repo.update_all(set: [inserted_at: old_date])

      {:ok, _} = AuditLog.create_entry(%{event_type: "recent_event"})

      assert length(AuditLog.list_entries()) == 2

      {deleted_count, _} = AuditLog.cleanup_old_entries(90)
      assert deleted_count == 1

      remaining = AuditLog.list_entries()
      assert length(remaining) == 1
      assert hd(remaining).event_type == "recent_event"
    end
  end
end

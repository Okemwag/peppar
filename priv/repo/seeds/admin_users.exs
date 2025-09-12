# Admin Users Seed Script
#
# This script creates admin users for the LinkedIn AI platform.
# Run with: mix run priv/repo/seeds/admin_users.exs

alias LinkedinAi.Accounts
alias LinkedinAi.Repo

# Admin user data
admin_users = [
  %{
    email: "admin@linkedinai.com",
    password: "AdminPassword123!",
    first_name: "Admin",
    last_name: "User",
    role: "admin",
    account_status: "active",
    confirmed_at: NaiveDateTime.utc_now()
  }
]

# Create admin users
Enum.each(admin_users, fn user_attrs ->
  case Accounts.get_user_by_email(user_attrs.email) do
    nil ->
      case Accounts.register_user(user_attrs) do
        {:ok, user} ->
          # Promote to admin and confirm account
          {:ok, _admin_user} = Accounts.promote_to_admin(user)
          IO.puts("✓ Created admin user: #{user_attrs.email}")

        {:error, changeset} ->
          IO.puts("✗ Failed to create admin user #{user_attrs.email}:")
          IO.inspect(changeset.errors)
      end

    existing_user ->
      # Update existing user to admin if not already
      if existing_user.role != "admin" do
        case Accounts.promote_to_admin(existing_user) do
          {:ok, _admin_user} ->
            IO.puts("✓ Promoted existing user to admin: #{user_attrs.email}")

          {:error, changeset} ->
            IO.puts("✗ Failed to promote user #{user_attrs.email}:")
            IO.inspect(changeset.errors)
        end
      else
        IO.puts("→ Admin user already exists: #{user_attrs.email}")
      end
  end
end)

IO.puts("\n🎉 Admin user seeding completed!")
IO.puts("You can now log in with admin credentials to access the admin panel at /admin")
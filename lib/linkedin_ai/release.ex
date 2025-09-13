defmodule LinkedinAi.Release do
  @moduledoc """
  Release tasks for production deployment.
  
  These tasks are used for database migrations, seeding, and other
  deployment-related operations in production.
  """

  @app :linkedin_ai

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()
    
    for repo <- repos() do
      # Run the seed script
      seed_script = priv_path_for(repo, "seeds.exs")
      
      if File.exists?(seed_script) do
        IO.puts("Running seed script for #{repo}...")
        Code.eval_file(seed_script)
      end
    end
  end

  def create_admin_user do
    load_app()
    
    email = System.get_env("ADMIN_EMAIL") || "admin@linkedin-ai-platform.com"
    password = System.get_env("ADMIN_PASSWORD") || generate_password()
    
    case LinkedinAi.Accounts.get_user_by_email(email) do
      nil ->
        attrs = %{
          email: email,
          password: password,
          role: :admin
        }
        
        case LinkedinAi.Accounts.register_user(attrs) do
          {:ok, user} ->
            # Confirm the user automatically
            LinkedinAi.Accounts.confirm_user(user)
            IO.puts("Admin user created successfully!")
            IO.puts("Email: #{email}")
            IO.puts("Password: #{password}")
            IO.puts("Please change the password after first login.")
            
          {:error, changeset} ->
            IO.puts("Failed to create admin user:")
            IO.inspect(changeset.errors)
        end
        
      user ->
        IO.puts("Admin user already exists: #{user.email}")
    end
  end

  def start_workers do
    load_app()
    
    # Start Oban workers for background job processing
    children = [
      {Oban, Application.fetch_env!(@app, Oban)}
    ]
    
    opts = [strategy: :one_for_one, name: LinkedinAi.WorkerSupervisor]
    Supervisor.start_link(children, opts)
  end

  def create_indexes do
    load_app()
    
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
        # Create performance indexes
        IO.puts("Creating performance indexes...")
        
        # Users table indexes
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email_confirmed ON users (email) WHERE confirmed_at IS NOT NULL;")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_role ON users (role);")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_linkedin_connected ON users (linkedin_profile_url) WHERE linkedin_profile_url IS NOT NULL;")
        
        # Subscriptions table indexes
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_subscriptions_user_id_status ON subscriptions (user_id, status);")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_subscriptions_stripe_customer_id ON subscriptions (stripe_customer_id);")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_subscriptions_current_period ON subscriptions (current_period_start, current_period_end);")
        
        # Generated content indexes
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_generated_contents_user_id_created ON generated_contents (user_id, inserted_at DESC);")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_generated_contents_content_type ON generated_contents (content_type);")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_generated_contents_favorites ON generated_contents (user_id, is_favorite) WHERE is_favorite = true;")
        
        # Profile analyses indexes
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_profile_analyses_user_id_date ON profile_analyses (user_id, analysis_date DESC);")
        
        # Usage records indexes
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_usage_records_subscription_date ON usage_records (subscription_id, usage_date DESC);")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_usage_records_feature_type ON usage_records (feature_type, usage_date);")
        
        # Oban jobs indexes (if not already created by Oban)
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oban_jobs_state_queue ON oban_jobs (state, queue);")
        repo.query!("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oban_jobs_scheduled_at ON oban_jobs (scheduled_at) WHERE state = 'scheduled';")
        
        IO.puts("Performance indexes created successfully!")
      end)
    end
  end

  def cleanup_old_data do
    load_app()
    
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
        IO.puts("Cleaning up old data...")
        
        # Clean up old Oban jobs (older than 30 days)
        repo.query!("DELETE FROM oban_jobs WHERE inserted_at < NOW() - INTERVAL '30 days' AND state IN ('completed', 'discarded');")
        
        # Clean up old usage records (older than 2 years)
        repo.query!("DELETE FROM usage_records WHERE inserted_at < NOW() - INTERVAL '2 years';")
        
        # Clean up old profile analyses (keep only latest 10 per user)
        repo.query!("""
          DELETE FROM profile_analyses 
          WHERE id NOT IN (
            SELECT id FROM (
              SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY analysis_date DESC) as rn
              FROM profile_analyses
            ) t WHERE t.rn <= 10
          );
        """)
        
        IO.puts("Old data cleanup completed!")
      end)
    end
  end

  def check_external_apis do
    load_app()
    
    IO.puts("Checking external API connectivity...")
    
    # Check OpenAI API
    case LinkedinAi.AI.OpenAIClient.test_connection() do
      {:ok, _} -> IO.puts("✓ OpenAI API: Connected")
      {:error, reason} -> IO.puts("✗ OpenAI API: #{inspect(reason)}")
    end
    
    # Check Stripe API
    case Stripe.Account.retrieve() do
      {:ok, _} -> IO.puts("✓ Stripe API: Connected")
      {:error, reason} -> IO.puts("✗ Stripe API: #{inspect(reason)}")
    end
    
    # Check Redis connection
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} -> IO.puts("✓ Redis: Connected")
      {:error, reason} -> IO.puts("✗ Redis: #{inspect(reason)}")
    end
    
    IO.puts("External API check completed!")
  end

  def validate_config do
    load_app()
    
    IO.puts("Validating configuration...")
    
    required_env_vars = [
      "DATABASE_URL",
      "SECRET_KEY_BASE",
      "OPENAI_API_KEY",
      "STRIPE_SECRET_KEY",
      "LINKEDIN_CLIENT_ID",
      "LINKEDIN_CLIENT_SECRET"
    ]
    
    missing_vars = Enum.filter(required_env_vars, fn var ->
      is_nil(System.get_env(var)) or System.get_env(var) == ""
    end)
    
    if Enum.empty?(missing_vars) do
      IO.puts("✓ All required environment variables are set")
    else
      IO.puts("✗ Missing required environment variables:")
      Enum.each(missing_vars, fn var -> IO.puts("  - #{var}") end)
      System.halt(1)
    end
    
    # Validate SECRET_KEY_BASE length
    secret_key = System.get_env("SECRET_KEY_BASE")
    if String.length(secret_key) < 64 do
      IO.puts("✗ SECRET_KEY_BASE must be at least 64 characters long")
      System.halt(1)
    end
    
    IO.puts("✓ Configuration validation passed!")
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config(), :otp_app)
    repo_underscore = repo |> Module.split() |> List.last() |> Macro.underscore()
    priv_dir = "#{:code.priv_dir(app)}"
    Path.join([priv_dir, "repo", filename])
  end

  defp generate_password do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> String.slice(0, 16)
  end
end
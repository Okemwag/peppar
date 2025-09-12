# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :linkedin_ai,
  ecto_repos: [LinkedinAi.Repo],
  generators: [timestamp_type: :utc_datetime]

config :linkedin_ai, LinkedinAi.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "sandbox.smtp.mailtrap.io",
  username: "4c425215352652",
  password: "51e0a703114f99",
  port: 587,
  ssl: false,
  tls: :always,
  auth: :always


# Configures the endpoint
config :linkedin_ai, LinkedinAiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LinkedinAiWeb.ErrorHTML, json: LinkedinAiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LinkedinAi.PubSub,
  live_view: [signing_salt: "8eyxItYS"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :linkedin_ai, LinkedinAi.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  linkedin_ai: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  linkedin_ai: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Oban for background job processing
config :linkedin_ai, Oban,
  repo: LinkedinAi.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    ai_content: 5,
    analytics: 3,
    notifications: 2
  ]

# Configure Quantum for scheduled tasks
config :linkedin_ai, LinkedinAi.Scheduler,
  jobs: [
    # Daily analytics processing at 2 AM
    {"0 2 * * *", {LinkedinAi.Analytics, :process_daily_metrics, []}},
    # Weekly report generation on Sundays at 6 AM
    {"0 6 * * 0", {LinkedinAi.Reports, :generate_weekly_reports, []}}
  ]

# Configure CORS
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:4000"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

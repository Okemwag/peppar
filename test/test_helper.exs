ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(LinkedinAi.Repo, :manual)

# Set up Mox
Mox.defmock(LinkedinAi.AI.Mock, for: LinkedinAi.AI.Behaviour)

# Configure the application to use mocks in test
Application.put_env(:linkedin_ai, :ai_module, LinkedinAi.AI.Mock)

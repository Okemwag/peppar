# Use the official Elixir image as a base
FROM elixir

# Install inotify-tools and Node.js and npm
RUN apt-get update && apt-get install -y inotify-tools nodejs npm

# Install Hex package manager and rebar
RUN mix local.hex --force
RUN mix local.rebar --force

# Create app directory
RUN mkdir /app
WORKDIR /app

# Copy the mix.exs and mix.lock files
COPY mix.exs mix.lock ./

# Install Elixir dependencies
RUN mix deps.get

# Copy the rest of the application code
COPY . .

# Install npm packages
RUN npm install --prefix ./assets

# Compile assets
RUN npm run deploy --prefix ./assets
RUN mix phx.digest

# Expose port 4000 to the outside world
EXPOSE 4000

# Command to run the Phoenix server
CMD ["mix", "phx.server"]
FROM elixir:1.18-alpine

#Install Dependencies
RUN apk add --no-cache build-base git npm postgresql-client inotify-tools icu-data-full

#Install work Directory
WORKDIR /app

#Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# COPY project
COPY mix.exs mix.lock ./

# Install Dependencies and compile
RUN mix deps.get
COPY . .
RUN mix compile

# Run Server
CMD ["mix", "phx.server"]
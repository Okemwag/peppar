# Use the official Elixir image
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Set build ENV
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set work directory
WORKDIR /app

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy priv directory
COPY priv priv

# Copy assets
COPY assets assets

# Install npm dependencies and build assets
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error
RUN mix assets.deploy

# Compile the release
COPY lib lib
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Assemble the release
RUN mix release

# Start a new build stage for the runtime image
FROM alpine:3.18 AS app

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++

# Set environment
ENV USER="elixir"

# Create a non-root user
RUN addgroup -g 1000 -S "${USER}" && \
    adduser -u 1000 -S "${USER}" -G "${USER}"

# Set work directory and user
WORKDIR "/home/${USER}/app"
USER "${USER}"

# Copy the release from the build stage
COPY --from=build --chown="${USER}":"${USER}" /app/_build/prod/rel/linkedin_ai ./

# Expose port
EXPOSE 4000

# Set default command
CMD ["bin/linkedin_ai", "start"]
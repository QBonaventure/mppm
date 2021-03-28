################################################################################
################################## APP BUILD ###################################
################################################################################

FROM elixir:1.10-slim as app-build

RUN apt-get update && apt-get install -y \
  nodejs \
  npm \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app
WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix archive.install --force hex phx_new

WORKDIR /app
COPY mix.exs mix.lock README.md LICENSE.md ./
COPY assets ./assets

COPY lib ./lib
COPY priv ./priv
COPY config ./config

WORKDIR /app/config
RUN for file in *.dist; do cp "$file" "${file%.*}"; done

WORKDIR /app
RUN mix do deps.get, deps.compile
RUN MIX_ENV=prod mix compile

RUN npm run deploy --prefix ./assets
RUN mix phx.digest


################################################################################
################################# FINAL LAYER ##################################
################################################################################

from elixir:1.10-slim

RUN apt-get update && apt-get install -y curl procps && \
  rm -rf /var/lib/apt/lists/* && \
  mix local.hex --force

COPY --from=app-build /app/_build /app/_build
COPY --from=app-build /app/priv /app/priv
COPY --from=app-build /app/config /app/config
COPY --from=app-build /app/lib /app/lib
COPY --from=app-build /app/deps /app/deps
COPY --from=app-build /app/mix.* /app/
COPY --from=app-build /app/mix.* /app/

WORKDIR /app

COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]

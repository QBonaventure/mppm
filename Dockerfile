FROM elixir:1.10


RUN apt-get update && apt-get install -y \
  curl \
  nodejs \
  npm \
  inotify-tools \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app
WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix archive.install --force hex phx_new

COPY mix.exs /app/

COPY deps ./deps
RUN ["mix", "deps.get"]
RUN ["mix", "deps.compile"]

COPY assets ./assets
WORKDIR /app/assets
RUN ["npm", "install"]

WORKDIR /app

COPY config/config.exs.dist ./config/config.exs
COPY config/prod.exs.dist ./config/prod.exs
COPY config/dev.exs.dist ./config/dev.exs
COPY config/secret.exs.dist ./config/secret.exs

COPY README.md ./
COPY LICENSE.md ./
COPY .gitignore ./

COPY priv ./priv
COPY lib ./lib

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

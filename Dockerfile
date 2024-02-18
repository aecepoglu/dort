ARG v_elixir=1.14.0
FROM elixir:${v_elixir}

ENV PORT=4000 MIX_ENV=prod
ENV APP_NAME=dort APP_VERSION="0.1.0"

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mkdir /app

WORKDIR /app

COPY mix.exs mix.lock ./
COPY config ./config
COPY lib ./lib
EXPOSE 4000

RUN mix deps.get
RUN mix deps.compile


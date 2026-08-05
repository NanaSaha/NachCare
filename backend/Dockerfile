# Development image, used via ops/docker-compose.yml. See docs/adr/0001.
# (Rails' generated production multi-stage Dockerfile was intentionally
# replaced — this build needs the development/test gem groups and a bind
# mount for live iteration, not a slim production artifact.)
FROM ruby:3.3-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev \
    git \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]

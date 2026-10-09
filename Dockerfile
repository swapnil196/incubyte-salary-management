# syntax=docker/dockerfile:1
#
# Two stages: everything needed to compile gems and build the frontend stays in
# the builder, so the image that actually runs carries neither a C toolchain nor
# node_modules.

ARG RUBY_VERSION=3.4.9
ARG NODE_VERSION=22.18.0

# ---------- build ----------
FROM ruby:$RUBY_VERSION-slim AS build

ARG NODE_VERSION
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git pkg-config curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Node is needed to build the frontend bundle, and only for that.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install --no-install-recommends -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Gems first: this layer is cached unless the Gemfile changes.
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# Builds the Vite bundle into public/vite. SECRET_KEY_BASE_DUMMY lets the app
# boot for the asset build without the real secret being present at build time.
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec vite build

# ---------- runtime ----------
FROM ruby:$RUBY_VERSION-slim

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development \
    RAILS_LOG_TO_STDOUT=1 \
    DATABASE_PATH=/data/production.sqlite3

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libsqlite3-0 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Runs unprivileged. /data is the mount point for the persisted database.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /data /rails/tmp /rails/log && \
    chown -R rails:rails /data /rails/tmp /rails/log /rails/db
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

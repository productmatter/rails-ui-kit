# syntax=docker/dockerfile:1
# check=error=true

# The docs site's production image (examples/DEPLOY.md). The build context is the REPO ROOT: the
# docs app boots from the gem's Gemfile and renders the gem's own app/ and config/.
#
#   docker build -f examples/Dockerfile -t rails-ui-kit-docs .
#
# Gemfile.lock is gitignored (this is a gem), so the image resolves its gems fresh from the Gemfile
# on every build, exactly as CI does. .dockerignore keeps a local lockfile out so a local build
# matches a deploy.

ARG RUBY_VERSION=4.0.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# jemalloc: less memory fragmentation, which matters on a 512MB machine.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test assets" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# The runtime gems (default and :docs groups), compiled once and copied into the final image.
FROM base AS gems

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile rails_ui_kit.gemspec ./
COPY lib/rails_ui_kit/version.rb lib/rails_ui_kit/version.rb
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Adds :assets (tailwindcss-rails) and compiles the CSS and the Propshaft manifest. Only the
# output leaves this stage; the Tailwind binary doesn't.
FROM gems AS build

ENV BUNDLE_WITHOUT="development test"
RUN bundle install

COPY . .

WORKDIR /rails/examples
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_GROUPS=assets ./bin/rails assets:precompile && \
    rm -rf tmp/cache

FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY --from=gems "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

WORKDIR /rails/examples
RUN mkdir -p tmp/pids log && chown -R rails:rails tmp log
USER 1000:1000

# Thruster listens on 8080 (fly.toml's internal_port; an unprivileged port, since this runs as a
# non-root user) and proxies to Puma on 3000, adding compression and caching for the assets.
ENV HTTP_PORT="8080" \
    TARGET_PORT="3000"
EXPOSE 8080
CMD ["bundle", "exec", "thrust", "./bin/rails", "server"]

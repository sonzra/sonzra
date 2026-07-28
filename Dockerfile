# syntax=docker/dockerfile:1
ARG RUBY_VERSION=4.0.6
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
ENV RAILS_ENV="production" BUNDLE_DEPLOYMENT="1" BUNDLE_PATH="/usr/local/bundle" BUNDLE_WITHOUT="development:test"
RUN apt-get update -qq && apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && rm -rf /var/lib/apt/lists/*
FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=dummy ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=dummy ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=dummy bin/rails assets:precompile
FROM base
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN useradd rails --create-home --shell /bin/bash && chown -R rails:rails db log storage tmp
USER rails
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD curl --fail http://localhost:3000/up || exit 1
CMD ["./bin/rails", "server"]

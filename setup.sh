#!/usr/bin/env bash
set -e

cd /home/nicol/projetos/code/mvp/chat

echo "=== 1. Bundle install ==="
bundle config set --local path vendor/bundle
bundle install

echo "=== 2. Tailwind build ==="
bundle exec rails tailwindcss:build || true

echo "=== 3. Create database ==="
bundle exec rails db:create

echo "=== 4. Run migrations ==="
bundle exec rails db:migrate

echo "=== 5. Seed database ==="
bundle exec rails db:seed

echo ""
echo "✅ Setup completo!"
echo "   Inicie o servidor com: bundle exec rails server"
echo "   Ou use Foreman: foreman start -f Procfile.dev"

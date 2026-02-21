---
name: Deployment Tutorial
overview: Create TUTORIAL_DEPLOY.md — a simple, step-by-step deployment guide targeting Railway.app (free tier) as the recommended platform, covering all services required by the app (Rails web, PostgreSQL, Redis, Sidekiq worker, Cloudflare R2 storage).
todos:
  - id: deploy-tutorial
    content: Create TUTORIAL_DEPLOY.md with full Railway deployment guide
    status: pending
  - id: readme-link
    content: Add link to TUTORIAL_DEPLOY.md in README.md Quick Start section
    status: pending
isProject: false
---

# Deployment Tutorial Plan

## Why Railway

The app requires 4 running services:

- Rails/Puma (web)
- PostgreSQL
- Redis
- Sidekiq (worker process)

Railway is the only platform that includes all 4 in a free tier ($5/month credit, no credit card required). Render is a close second but its free Redis requires a paid add-on.

## File to create

`**TUTORIAL_DEPLOY.md**` — standalone file, linked from `README.md`.

## Tutorial sections

1. **Prerequisites** — accounts to create before starting
  - Railway account (railway.app)
  - GitHub account (for connect-to-deploy)
  - Cloudflare account (for R2 storage — already configured in `config/storage.yml`)
2. **Push the code to GitHub**
  - `git init`, `git add .`, `git commit`, `git remote add`, `git push`
3. **Create a Railway project**
  - New project → Deploy from GitHub repo
  - Railway auto-detects Rails (Nixpacks buildpack)
4. **Add PostgreSQL service**
  - Railway dashboard → + New → Database → PostgreSQL
  - `DATABASE_URL` is auto-injected
5. **Add Redis service**
  - Railway dashboard → + New → Database → Redis
  - `REDIS_URL` is auto-injected
6. **Set environment variables** (Railway Variables tab)

```
   RAILS_ENV=production
   SECRET_KEY_BASE=<rails secret output>
   DEVISE_JWT_SECRET_KEY=<openssl rand -hex 64>
   ACTIVE_STORAGE_SERVICE=cloudflare_r2
   R2_ACCESS_KEY_ID=...
   R2_SECRET_ACCESS_KEY=...
   R2_BUCKET=...
   R2_ACCOUNT_ID=...
   RAILS_SERVE_STATIC_FILES=true
   RAILS_LOG_TO_STDOUT=true
   

```

1. **Add a Procfile** (if not present) to declare web + worker processes

```
   web: bundle exec puma -C config/puma.rb
   worker: bundle exec sidekiq -C config/sidekiq.yml
   

```

   Railway runs each line as a separate service.

1. **Run migrations** — one-time via Railway CLI or the Railway "Run Command" panel

```bash
   railway run rails db:migrate db:seed
   

```

1. **Generate a public domain** — Railway Settings → Networking → Generate Domain
2. **Verify** — checklist (web loads, WebSocket chat works, file upload goes to R2, background jobs run)
3. **Cloudflare R2 setup** — step-by-step screenshots of creating a bucket and generating API tokens
4. **Common errors & fixes** — missing `SECRET_KEY_BASE`, `ActiveRecord::NoDatabaseError`, asset precompile failures, WebSocket wss:// mismatch
5. **Keeping costs at $0** — tips on staying within the free $5 credit (scale down idle services, use Upstash as a Redis alternative if needed)

## README.md change

Add one line to the Quick Start links pointing to the new file.
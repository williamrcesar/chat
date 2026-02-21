# Getting Started — Step-by-Step Tutorial

This tutorial walks you through setting up the Chat app on **Windows 11 with Ubuntu (WSL2)** from scratch.

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Install WSL2 + Ubuntu](#2-install-wsl2--ubuntu)
3. [Install Ruby](#3-install-ruby)
4. [Install Rails](#4-install-rails)
5. [Install PostgreSQL](#5-install-postgresql)
6. [Install Redis](#6-install-redis)
7. [Install Docker (optional but recommended)](#7-install-docker-optional-but-recommended)
8. [Clone / Open the Project](#8-clone--open-the-project)
9. [Install Project Dependencies](#9-install-project-dependencies)
10. [Configure Environment Variables](#10-configure-environment-variables)
11. [Set Up the Database](#11-set-up-the-database)
12. [Run the App](#12-run-the-app)
13. [Using the App](#13-using-the-app)
14. [Common Errors and Fixes](#14-common-errors-and-fixes)
15. [Setting Up Cloudflare R2 (Production Storage)](#15-setting-up-cloudflare-r2-production-storage)
16. [Running the API with a REST Client](#16-running-the-api-with-a-rest-client)
17. [Development Workflow](#17-development-workflow)

---

## 1. System Requirements

Before starting, make sure you have:

- **Windows 11** (or Windows 10 version 2004+)
- **WSL2** with Ubuntu installed
- At least **4 GB RAM** free
- At least **5 GB disk space**

---

## 2. Install WSL2 + Ubuntu

If you don't have WSL2 yet, open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

This installs WSL2 with Ubuntu by default. Restart your computer when prompted.

After restart, open **Ubuntu** from the Start menu and create your username and password.

**Verify WSL2 is active:**
```powershell
wsl --list --verbose
# Should show VERSION 2 next to Ubuntu
```

---

## 3. Install Ruby

Open **Ubuntu** (search for it in the Start menu or use Windows Terminal → Ubuntu).

### Option A — rbenv (recommended)

```bash
# Install dependencies
sudo apt update && sudo apt install -y curl git build-essential libssl-dev libreadline-dev zlib1g-dev

# Install rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Add rbenv to PATH
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.2.3
rbenv install 3.2.3
rbenv global 3.2.3

# Verify
ruby --version
# ruby 3.2.3 (2024-01-18 revision 52bb2ac0a6) [x86_64-linux]
```

### Option B — System Ruby (already installed)

If Ruby is already installed (check with `ruby --version`), you can skip this step.

---

## 4. Install Rails

```bash
gem install rails -v "~> 7.2"

# Verify
rails --version
# Rails 7.2.x
```

> If you get a permission error, add `gem: --user-install` to `~/.gemrc` and add the gem bin path to your PATH.

---

## 5. Install PostgreSQL

```bash
# Install PostgreSQL
sudo apt update
sudo apt install -y postgresql postgresql-contrib libpq-dev

# Start PostgreSQL
sudo service postgresql start

# Create a superuser for your Linux username (so Rails can create databases)
sudo -u postgres createuser --superuser $USER

# Verify it works
psql -c "\conninfo"
```

> **Important:** You need to run `sudo service postgresql start` every time you restart WSL. 
> To start it automatically, add it to `~/.bashrc`:
> ```bash
> echo "sudo service postgresql start > /dev/null 2>&1" >> ~/.bashrc
> ```

---

## 6. Install Redis

```bash
# Install Redis
sudo apt install -y redis-server

# Start Redis
sudo service redis-server start

# Verify
redis-cli ping
# PONG
```

> Same as PostgreSQL, add to `~/.bashrc` to auto-start:
> ```bash
> echo "sudo service redis-server start > /dev/null 2>&1" >> ~/.bashrc
> ```

---

## 7. Install Docker (optional but recommended)

Using Docker is the easiest way to run PostgreSQL and Redis without installing them manually.

### Install Docker Desktop for Windows

1. Download from [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
2. Install and enable **"Use WSL 2 based engine"** during setup
3. In Docker Desktop → Settings → Resources → WSL Integration → Enable for Ubuntu
4. Restart Docker Desktop

### Verify Docker works in Ubuntu:

```bash
docker --version
docker compose version
```

If Docker is set up, you can skip steps 5 and 6 — Docker will handle PostgreSQL and Redis.

---

## 8. Clone / Open the Project

The project is already created at `/home/nicol/projetos/code/mvp/chat`.

Open it in Ubuntu:

```bash
cd /home/nicol/projetos/code/mvp/chat
ls
# You should see: Gemfile, README.md, app/, config/, db/, etc.
```

---

## 9. Install Project Dependencies

```bash
cd /home/nicol/projetos/code/mvp/chat

# Configure Bundler to install gems locally (avoids permission issues)
bundle config set --local path vendor/bundle

# Install all gems
bundle install
```

> This can take **3–10 minutes** on the first run. You'll see a lot of output — that's normal.

**Expected output at the end:**
```
Bundle complete! 20 Gemfile dependencies, 120 gems now installed.
Bundled gems are installed into `./vendor/bundle`
```

---

## 10. Configure Environment Variables

```bash
cd /home/nicol/projetos/code/mvp/chat

# Copy the example file
cp .env.example .env

# Open it to edit
nano .env
```

**Minimum required values for development:**

```env
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=           # leave blank if you created a superuser with your Linux username
DB_PASSWORD=           # leave blank if no password was set
DB_NAME=chat_development

REDIS_URL=redis://localhost:6379/0
```

> If using Docker instead of native PostgreSQL/Redis, use these values:
> ```env
> DB_HOST=localhost
> DB_USERNAME=postgres
> DB_PASSWORD=postgres
> REDIS_URL=redis://localhost:6379/0
> ```

Save with `Ctrl+X` → `Y` → `Enter`.

---

## 11. Set Up the Database

### If using Docker (start services first):

```bash
cd /home/nicol/projetos/code/mvp/chat
docker compose up -d
```

Wait a few seconds for PostgreSQL and Redis to be ready, then:

### Create and migrate the database:

```bash
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed
```

**What each command does:**
- `db:create` — creates the `chat_development` and `chat_test` databases
- `db:migrate` — runs all migrations (creates tables)
- `db:seed` — creates test users and sample conversations

**Expected seed output:**
```
Seeding database...
✅ Seeds concluídos!
   alice@example.com / password123
   bob@example.com   / password123
   carol@example.com / password123
```

---

## 12. Run the App

### Option A — Simple (just the web server)

```bash
bundle exec rails server
```

Open your browser at **http://localhost:3000**

### Option B — Full development mode (with Tailwind auto-compile)

```bash
# Install foreman if you don't have it
gem install foreman

# Start all processes
foreman start -f Procfile.dev
```

This starts:
- Rails web server (port 3000)
- Tailwind CSS watcher (auto-recompiles CSS on changes)
- Sidekiq (background job worker)

---

## 13. Using the App

### Sign in

1. Go to http://localhost:3000
2. You'll be redirected to the login page
3. Sign in with: `alice@example.com` / `password123`

### Start a conversation

1. Click the **+** button in the top-right of the sidebar
2. Click on a contact to start a direct conversation
3. Or fill in a group name and click "Criar Grupo"

### Send a message

1. Click on a conversation in the sidebar
2. Type your message in the input bar at the bottom
3. Press **Enter** to send (Shift+Enter for new line)

### Send a file

1. Click the **paperclip icon** (📎) next to the input
2. Select an image, audio, video, or document
3. A preview will appear — press the send button

### Use a message template

1. Click **Templates** (the list icon in the top bar)
2. Click **New Template** to create one
3. Use `{{variable}}` syntax in the content
4. In a conversation, use the template picker (coming in next release)

### Edit your profile

1. Click your avatar in the top-left of the sidebar
2. Click **Edit Profile**
3. Update your name, phone, bio, or photo

---

## 14. Common Errors and Fixes

### ❌ `could not connect to server: Connection refused`

PostgreSQL is not running.

```bash
# Native install:
sudo service postgresql start

# Or with Docker:
docker compose up -d
```

---

### ❌ `FATAL: role "nicol" does not exist`

Your Linux user doesn't have a PostgreSQL role.

```bash
sudo -u postgres createuser --superuser $USER
```

---

### ❌ `Redis::CannotConnectError`

Redis is not running.

```bash
# Native install:
sudo service redis-server start

# Or with Docker:
docker compose up -d
```

---

### ❌ `bundle: command not found`

Bundler is not in your PATH.

```bash
# Add gem bin dir to PATH
export PATH="$PATH:$(ruby -e 'puts Gem.user_dir')/bin"
echo 'export PATH="$PATH:'"$(ruby -e 'puts Gem.user_dir')"'/bin"' >> ~/.bashrc
source ~/.bashrc

gem install bundler
```

---

### ❌ `Devise.secret_key was not set` or JWT errors

Missing secret key. Run:

```bash
bundle exec rails secret
```

Copy the output and add it to `.env`:

```env
SECRET_KEY_BASE=<paste here>
DEVISE_JWT_SECRET_KEY=<paste the output of: openssl rand -hex 64>
```

---

### ❌ `PG::UndefinedTable: ERROR: relation "users" does not exist`

Migrations haven't been run.

```bash
bundle exec rails db:migrate
```

---

### ❌ CSS not loading / page looks broken

Tailwind CSS hasn't been compiled.

```bash
bundle exec rails tailwindcss:build
```

---

### ❌ `Errno::EADDRINUSE: Address already in use - bind(2)`

Port 3000 is already in use. Kill the old process:

```bash
kill -9 $(lsof -ti:3000)
# Then start again
bundle exec rails server
```

---

## 15. Setting Up Cloudflare R2 (Production Storage)

For production, files are stored in Cloudflare R2 (S3-compatible, generous free tier).

### Create a Cloudflare R2 bucket

1. Go to [https://dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **R2 Object Storage** in the left menu
3. Click **Create bucket** → name it (e.g., `chat-app-production`)
4. Go to **Manage R2 API Tokens** → **Create API Token**
5. Give it **Object Read & Write** permissions for your bucket
6. Copy the **Access Key ID** and **Secret Access Key**
7. Your **Account ID** is in the top-right of the Cloudflare dashboard

### Update your `.env` (production):

```env
ACTIVE_STORAGE_SERVICE=cloudflare_r2
R2_ACCESS_KEY_ID=your_access_key_id
R2_SECRET_ACCESS_KEY=your_secret_access_key
R2_BUCKET=chat-app-production
R2_ACCOUNT_ID=your_cloudflare_account_id
```

### Development

In development, files are stored locally in `storage/` (no R2 needed).

```env
ACTIVE_STORAGE_SERVICE=local
```

---

## 16. Running the API with a REST Client

You can test the API using **Postman**, **Insomnia**, or **curl**.

### Step 1 — Register a user

```bash
curl -X POST http://localhost:3000/api/v1/auth/sign_up \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "test@example.com", "password": "password123", "display_name": "Test User"}}'
```

### Step 2 — Sign in and get JWT token

```bash
curl -X POST http://localhost:3000/api/v1/auth/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "alice@example.com", "password": "password123"}}'
```

Response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": { "id": 1, "display_name": "Alice Silva", "email": "alice@example.com" }
}
```

### Step 3 — Use the token in subsequent requests

```bash
TOKEN="eyJhbGciOiJIUzI1NiJ9..."

# List conversations
curl http://localhost:3000/api/v1/conversations \
  -H "Authorization: Bearer $TOKEN"

# Send a message
curl -X POST http://localhost:3000/api/v1/conversations/1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": {"content": "Hello from the API!"}}'
```

---

## 17. Development Workflow

### Day-to-day commands

```bash
# Navigate to the project
cd /home/nicol/projetos/code/mvp/chat

# Start services (if not using Docker autostart)
sudo service postgresql start
sudo service redis-server start

# Start the app
bundle exec rails server

# OR start everything at once with Foreman
foreman start -f Procfile.dev
```

### Useful Rails commands

```bash
# Open Rails console (interactive Ruby shell with app loaded)
bundle exec rails console

# Check all routes
bundle exec rails routes

# Reset the database (WARNING: deletes all data)
bundle exec rails db:reset

# Run a specific migration
bundle exec rails db:migrate VERSION=20260221000001

# Check migration status
bundle exec rails db:migrate:status

# Generate a new migration
bundle exec rails generate migration AddFieldToTable field:type
```

### Adding a new feature

1. Create a migration: `bundle exec rails generate migration AddNewField`
2. Edit the migration file in `db/migrate/`
3. Run it: `bundle exec rails db:migrate`
4. Update the model in `app/models/`
5. Update controller(s) in `app/controllers/`
6. Update views in `app/views/`
7. If API-related, update the blueprint in `app/blueprints/`

### File upload size limits

To allow larger files, edit `config/environments/production.rb`:

```ruby
# Increase to 100MB
config.active_storage.service_urls_expire_in = 1.hour
```

And in your web server config (Nginx or Puma):
```
client_max_body_size 100M;
```

---

## What's Next?

Once the app is running, here are some things you can explore:

| Feature               | Status  | Notes                                          |
|-----------------------|---------|------------------------------------------------|
| Web chat              | ✅ Done | Login, conversations, messages, attachments    |
| REST API              | ✅ Done | JWT auth, full CRUD for conversations/messages |
| Message templates     | ✅ Done | `{{variable}}` support                         |
| Cloudflare R2         | ✅ Done | Configure `.env` vars for production           |
| Mobile app (iOS/Android)| 🔜 TODO | React Native + Expo using existing API        |
| End-to-end encryption | 🔜 TODO | Signal Protocol / libsodium                    |
| Push notifications    | 🔜 TODO | FCM (Android) + APNs (iOS)                    |
| Voice/video calls     | 🔜 TODO | WebRTC                                         |

---

## Getting Help

If you run into any issues:

1. **Check this document** — most common errors are covered in section 14
2. **Read the error message carefully** — Rails errors are usually descriptive
3. **Check the Rails logs** in `log/development.log`
4. **Open an issue** or ask in the project chat

Happy coding! 🚀

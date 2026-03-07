# Chat — Rails WhatsApp Web Boilerplate

A full-featured WhatsApp-like messaging web app built with Ruby on Rails 7.2. Real-time messaging via ActionCable + Turbo Streams, email/password authentication, Cloudflare R2 file storage, and a REST API v1 ready for future mobile apps.

---

## Tech Stack

| Layer          | Technology                                   |
|----------------|----------------------------------------------|
| Framework      | Ruby on Rails 7.2 (full-stack)               |
| Database       | PostgreSQL                                   |
| Real-time      | ActionCable + Redis + Turbo Streams          |
| Frontend       | Hotwire (Turbo + Stimulus) + Tailwind CSS    |
| Web Auth       | Devise (email + password)                    |
| API Auth       | devise-jwt (JWT Bearer Token)                |
| File Storage   | Cloudflare R2 via Active Storage (S3-compat) |
| Background Jobs| Sidekiq + Redis                              |
| Authorization  | Pundit                                       |

---

## Features

- ✅ Sign up / sign in (email + password)
- ✅ Direct conversations (1:1) and group chats
- ✅ Real-time text messages (Turbo Streams + ActionCable)
- ✅ Image, audio, video, and document attachments
- ✅ Message templates with dynamic variables (`{{name}}`)
- ✅ Typing indicator ("is typing...")
- ✅ Online / last seen status
- ✅ Message status ticks ✓ ✓✓ (sent / delivered / read)
- ✅ Unread message count badges
- ✅ User profile with avatar
- ✅ REST API v1 with JWT (ready for mobile apps)
- ✅ WhatsApp Web dark-mode UI
- ✅ Message reactions (👍 ❤️ 😂 😮 😢 🙏) with real-time updates
- ✅ Delete for everyone (soft delete with broadcast)
- ✅ Forward messages to any conversation
- ✅ Full-text message search (pg_search)
- ✅ Archive and pin conversations
- ✅ Nickname-based identity (`@nickname`) + Contact Request system (Accept / Block strangers)
- ✅ Marketing Template Builder (header image/text, body, footer, buttons, list menus)
- ✅ Bulk Campaign sender — up to 1000 recipients/day (by @nickname or phone)
- ✅ Real-time Kanban board — tracks delivery: Queued → Sent → Delivered → Read → Clicked
- ✅ Interactive Message Lock — recipients must click a button/list before sending text (24h window)
- ✅ Company Multi-Agent Inbox — company @nickname, multiple attendants, departments, real-time routing
- ✅ Company Department Menu — interactive list message routes customers to the right attendant
- ✅ Live Company Dashboard — Kanban inbox (Pending / Queued / Active / Resolved) with real-time updates
- ✅ Attendant Management — custom roles (Finance, Support, AI, Tech), tags, status (available/busy/offline)
- ✅ Supervisor Dashboard — transfer conversations, resolve tickets, monitor attendant status live

---

## Quick Start

> **Full step-by-step setup tutorial:** see [TUTORIAL.md](TUTORIAL.md)
> **Company Multi-Agent Inbox tutorial:** see [TUTORIAL_COMPANY.md](TUTORIAL_COMPANY.md)

```bash
# 1. Start PostgreSQL + Redis
docker compose up -d

# 2. Install gems
bundle config set --local path vendor/bundle
bundle install

# 3. Set up environment variables
cp .env.example .env

# 4. Set up the database
bundle exec rails db:create db:migrate db:seed

# 5. Start the app
bundle exec rails server
```

Open **http://localhost:3000**

Test accounts (created by seeds):
| Email                  | Password      |
|------------------------|---------------|
| alice@example.com      | password123   |
| bob@example.com        | password123   |
| carol@example.com      | password123   |

---

## Project Structure

```
app/
├── channels/
│   ├── application_cable/connection.rb   # WebSocket auth
│   ├── chat_channel.rb                   # Messages, typing, presence
│   ├── kanban_channel.rb                 # Marketing campaign Kanban
│   ├── contact_requests_channel.rb       # Real-time contact request alerts
│   └── company_channel.rb               # Company live inbox
├── controllers/
│   ├── conversations_controller.rb
│   ├── messages_controller.rb
│   ├── contact_requests_controller.rb   # Friend-request system
│   ├── companies_controller.rb          # Company registration + profile
│   ├── company/                         # Company namespace
│   │   ├── base_controller.rb
│   │   ├── dashboard_controller.rb      # Live inbox Kanban
│   │   ├── attendants_controller.rb     # CRUD attendants
│   │   ├── settings_controller.rb       # Menu config editor
│   │   ├── assignments_controller.rb    # Transfer / resolve tickets
│   │   └── menu_clicks_controller.rb   # Customer dept selection
│   ├── marketing/                       # Marketing namespace
│   │   ├── templates_controller.rb
│   │   ├── campaigns_controller.rb
│   │   └── deliveries_controller.rb
│   ├── users/                           # Custom Devise controllers
│   └── api/v1/                          # REST API (JWT)
├── models/
│   ├── user.rb
│   ├── conversation.rb
│   ├── participant.rb
│   ├── message.rb
│   ├── contact_request.rb              # Nickname-based friend requests
│   ├── marketing_template.rb           # Rich marketing templates
│   ├── marketing_campaign.rb           # Bulk campaign sender
│   ├── campaign_delivery.rb            # Per-recipient delivery tracking
│   ├── company.rb                      # Company accounts
│   ├── company_attendant.rb            # Attendant roles + tags
│   └── conversation_assignment.rb      # Ticket assignment to attendant
├── services/
│   └── company_router_service.rb       # Routes customers to attendants
├── jobs/
│   ├── send_campaign_job.rb
│   ├── unlock_interactive_participants_job.rb
│   └── route_company_conversation_job.rb
├── javascript/controllers/              # Stimulus
│   ├── chat_controller.js
│   ├── template_builder_controller.js  # Marketing template builder
│   ├── kanban_controller.js            # Campaign Kanban real-time
│   ├── interactive_message_controller.js
│   ├── contact_requests_controller.js
│   ├── company_menu_controller.js      # Department menu editor
│   └── company_inbox_controller.js     # Live company dashboard
└── views/
    ├── conversations/
    ├── messages/
    ├── contact_requests/
    ├── companies/                       # Company registration + profile
    ├── company/                         # Company namespace views
    │   ├── dashboard/
    │   ├── attendants/
    │   ├── settings/
    │   └── assignments/
    └── marketing/
        ├── templates/
        └── campaigns/
```

---

## Database Schema

### users
| Column              | Type      | Notes                        |
|---------------------|-----------|------------------------------|
| email               | string    | unique, Devise                |
| encrypted_password  | string    | Devise                        |
| display_name        | string    |                               |
| nickname            | string    | unique @handle                |
| phone               | string    | optional                      |
| bio                 | text      | optional                      |
| online              | boolean   | presence status               |
| last_seen_at        | datetime  |                               |
| jti                 | string    | JWT revocation                |
| avatar              | (Active Storage attachment)        |

### conversations
| Column                  | Type    | Notes                          |
|-------------------------|---------|--------------------------------|
| name                    | string  | groups only                    |
| conversation_type       | integer | 0=direct, 1=group              |
| description             | text    |                                |
| company_id              | bigint  | FK → companies (optional)      |
| is_company_conversation | boolean | true for company inbox chats   |

### participants
| Column                   | Type     | Notes                       |
|--------------------------|----------|-----------------------------|
| user_id                  | integer  | FK → users                  |
| conversation_id          | integer  | FK → conversations          |
| role                     | integer  | 0=member, 1=admin           |
| last_read_at             | datetime |                             |
| muted                    | boolean  |                             |
| interactive_locked_until | datetime | unlock timestamp (marketing)|
| interactive_message_id   | bigint   | locked by this message      |

### messages
| Column             | Type     | Notes                                                    |
|--------------------|----------|----------------------------------------------------------|
| conversation_id    | integer  | FK → conversations                                       |
| sender_id          | integer  | FK → users                                               |
| content            | text     | nullable if attachment present                           |
| message_type       | integer  | text/image/audio/video/document/template/marketing/company_menu |
| status             | integer  | sent/delivered/read                                      |
| reply_to_id        | integer  | self-reference (optional)                                |
| metadata           | jsonb    | company menu config stored here                          |
| campaign_delivery_id | bigint | FK → campaign_deliveries (optional)                     |
| attachment         | (Active Storage attachment)                              |

### companies
| Column      | Type    | Notes                                        |
|-------------|---------|----------------------------------------------|
| owner_id    | integer | FK → users                                   |
| name        | string  |                                              |
| nickname    | string  | unique @handle (searched like users)         |
| description | string  |                                              |
| status      | integer | 0=active, 1=suspended                        |
| menu_config | jsonb   | greeting + departments array                 |
| logo        | (Active Storage attachment)                  |

### company_attendants
| Column         | Type    | Notes                                  |
|----------------|---------|----------------------------------------|
| company_id     | integer | FK → companies                         |
| user_id        | integer | FK → users                             |
| role_name      | string  | "Financeiro", "Suporte", "TI", etc.    |
| attendant_type | integer | 0=human, 1=ai                          |
| tags           | jsonb   | ["vip", "técnico", …]                  |
| status         | integer | 0=available, 1=busy, 2=offline         |
| is_supervisor  | boolean |                                        |

### conversation_assignments
| Column               | Type     | Notes                              |
|----------------------|----------|------------------------------------|
| conversation_id      | integer  | FK → conversations                 |
| company_id           | integer  | FK → companies                     |
| company_attendant_id | integer  | FK → company_attendants (optional) |
| status               | integer  | pending/active/resolved/transferred/queued |
| selected_department  | string   | what the customer chose            |
| assigned_at          | datetime |                                    |
| resolved_at          | datetime |                                    |

### templates
| Column       | Type   | Notes                     |
|--------------|--------|---------------------------|
| name         | string | unique                    |
| category     | string | general/marketing/support |
| content      | text   | supports {{variables}}    |
| variables    | jsonb  | array of variable names   |
| created_by_id| integer| FK → users                |

### read_receipts
| Column     | Type     |
|------------|----------|
| message_id | integer  |
| user_id    | integer  |
| read_at    | datetime |

---

## REST API v1

**Base URL:** `/api/v1`
**Authentication:** `Authorization: Bearer <JWT_TOKEN>`

### Auth

| Method | Route          | Description         |
|--------|----------------|---------------------|
| POST   | /auth/sign_up  | Register            |
| POST   | /auth/sign_in  | Login → returns JWT |
| DELETE | /auth/sign_out | Logout              |

**Sign in request:**
```http
POST /api/v1/auth/sign_in
Content-Type: application/json

{
  "user": {
    "email": "alice@example.com",
    "password": "password123"
  }
}
```

**Sign in response:**
```json
{
  "message": "Login realizado com sucesso.",
  "user": { "id": 1, "display_name": "Alice", "email": "alice@example.com" },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Conversations

| Method | Route                             | Description              |
|--------|-----------------------------------|--------------------------|
| GET    | /conversations                    | List conversations        |
| POST   | /conversations                    | Create group              |
| POST   | /conversations?user_id=X          | Start direct conversation |
| GET    | /conversations/:id                | Details + participants    |
| GET    | /conversations/:id/participants   | Participant list          |

### Messages

| Method | Route                              | Description       |
|--------|------------------------------------|-------------------|
| GET    | /conversations/:id/messages        | Message history   |
| POST   | /conversations/:id/messages        | Send message      |
| DELETE | /conversations/:id/messages/:msg_id| Delete message    |

**Send message with attachment (multipart):**
```http
POST /api/v1/conversations/1/messages
Authorization: Bearer <token>
Content-Type: multipart/form-data

message[content]=Hello!
message[attachment]=@photo.jpg
```

### Templates

| Method | Route           | Description      |
|--------|-----------------|------------------|
| GET    | /templates      | List templates   |
| POST   | /templates      | Create template  |
| PUT    | /templates/:id  | Update           |
| DELETE | /templates/:id  | Delete           |

**Using template variables:**
```json
{
  "name": "Welcome",
  "category": "general",
  "content": "Hello {{name}}, welcome to our service! Your code is {{code}}.",
  "variables": ["name", "code"]
}
```

### Profile

| Method | Route    | Description        |
|--------|----------|--------------------|
| GET    | /profile | Get current user   |
| PATCH  | /profile | Update profile     |

---

## WebSocket (ActionCable)

Subscribe to a conversation channel:

```javascript
import { createConsumer } from "@rails/actioncable"

const cable = createConsumer()
const channel = cable.subscriptions.create(
  { channel: "ChatChannel", conversation_id: 1 },
  {
    received(data) {
      if (data.type === "new_message") { /* new message HTML */ }
      if (data.type === "typing")      { /* user is typing */   }
      if (data.type === "presence")    { /* online/offline */   }
      if (data.type === "read")        { /* message read */     }
    }
  }
)

// Broadcast typing event:
channel.perform("typing", { typing: true })

// Mark conversation as read:
channel.perform("mark_read", {})
```

---

## Cloudflare R2 Storage

In production `.env`:

```env
ACTIVE_STORAGE_SERVICE=cloudflare_r2
R2_ACCESS_KEY_ID=your-key
R2_SECRET_ACCESS_KEY=your-secret
R2_BUCKET=your-bucket-name
R2_ACCOUNT_ID=your-cloudflare-account-id
```

`config/storage.yml` is already configured to point to the R2 endpoint.

---

## Message Templates

Templates support dynamic variables with `{{variable_name}}` syntax:

```
Hello {{name}}! Your order #{{order}} has been confirmed and will arrive in {{time}}.
```

Render a template via API:
```http
POST /api/v1/conversations/1/messages
Content-Type: application/json
Authorization: Bearer <token>

{
  "template_id": 1,
  "variables": {
    "name": "John",
    "order": "12345",
    "time": "3 business days"
  }
}
```

---

## Environment Variables

| Variable                | Required  | Description                          |
|-------------------------|-----------|--------------------------------------|
| `DATABASE_URL`          | Production| Full PostgreSQL connection URL        |
| `DB_HOST`               | Dev       | Database host (default: localhost)    |
| `DB_USERNAME`           | Dev       | Database user                         |
| `DB_PASSWORD`           | Dev       | Database password                     |
| `REDIS_URL`             | Yes       | Redis URL (default: localhost:6379)   |
| `SECRET_KEY_BASE`       | Production| Rails secret key                      |
| `DEVISE_JWT_SECRET_KEY` | Yes       | JWT signing key                       |
| `R2_ACCESS_KEY_ID`      | Production| Cloudflare R2 key                     |
| `R2_SECRET_ACCESS_KEY`  | Production| Cloudflare R2 secret                  |
| `R2_BUCKET`             | Production| R2 bucket name                        |
| `R2_ACCOUNT_ID`         | Production| Cloudflare account ID                 |
| `ACTIVE_STORAGE_SERVICE`| Yes       | `local` (dev) or `cloudflare_r2` (prod)|
| `CORS_ORIGINS`          | API       | Allowed CORS origins (default: *)     |

---

## Deployment

### Required production environment variables

```bash
rails secret          # → SECRET_KEY_BASE
openssl rand -hex 64  # → DEVISE_JWT_SECRET_KEY
```

### Recommended platforms

| Platform  | Notes                                          |
|-----------|------------------------------------------------|
| **Render**   | Simple, supports Sidekiq as a background worker|
| **Railway**  | PostgreSQL + Redis included                    |
| **Fly.io**   | Great performance, Docker-based                |
| **Heroku**   | Classic choice, requires paid add-ons          |

---

## Web Push Notifications (PWA)

Notificações no browser quando chega uma nova mensagem. Cada **dispositivo/navegador** precisa ativar notificações uma vez (botão "Enable notifications" / "Notifications ON").

### Setup

1. **Chaves VAPID** (uma vez por projeto):
   ```bash
   bundle exec rake webpush:generate_vapid_keys
   ```
   Copie as duas linhas para o `.env` (`VAPID_PUBLIC_KEY` e `VAPID_PRIVATE_KEY`).

2. **Sidekiq a correr** — o envio de push é feito em job em background. Com `bin/dev`, Sidekiq já sobe.

3. **Cada utilizador** deve clicar em "Enable notifications" (ícone de sino) **em cada dispositivo** onde quer receber notificações (Windows, telemóvel, etc.).

### Por que não recebo notificações?

| Situação | O que fazer |
|----------|-------------|
| **Windows / Chrome** | Confirmar que o site tem permissão em Definições → Privacidade → Notificações. Abrir a consola (F12) e verificar erros ao clicar em "Enable notifications". |
| **Telemóvel (iOS Safari)** | Web Push no iPhone **só funciona em PWA**: abrir o site no Safari → Partilhar → "Adicionar ao Ecrã Início". Depois abrir a app pelo ícone no ecrã inicial e aí ativar notificações. Requer **iOS 16.4+**. |
| **Telemóvel (Chrome Android)** | Ativar notificações no site (botão no chat). Se usar apenas em browser, permitir notificações quando o Chrome pedir. |
| **Nada acontece ao enviar mensagem** | Ver os logs do servidor (onde corre `bin/dev` ou Sidekiq). Deve aparecer `[WebPush] Sent to N subscription(s)` ou `[WebPush] User X has no subscriptions`. Se aparecer "no subscriptions", o destinatário não ativou notificações naquele dispositivo. |
| **Acesso por IP (ex.: 192.168.x.x)** | Push exige **contexto seguro**: `https://` ou `localhost`. Com `http://192.168.x.x` o browser pode bloquear. Use um túnel HTTPS (ex.: ngrok) ou localhost para testar. |

### Verificar no servidor

Ao enviar uma mensagem, nos logs deve aparecer algo como:
- `[WebPush] Sent to 1 subscription(s) for user_id=3` — push enviado.
- `[WebPush] User 3 has no subscriptions` — destinatário não ativou notificações nesse dispositivo.
- `[WebPush] Skipped: VAPID keys not set` — faltam chaves no `.env`.

---

## TODO — Upcoming Features

- [ ] **End-to-end encryption** (Signal Protocol / libsodium)
- [ ] **React Native + Expo mobile app** (uses existing API v1)
- [ ] **Flutter mobile app** (alternative)
- [x] **Web push notifications** (PWA — Service Worker) ✅
- [ ] **Mobile push notifications** (FCM + APNs)
- [x] **Message reactions** (emoji) ✅
- [x] **Delete for everyone** (soft delete) ✅
- [x] **Forward messages** ✅
- [x] **Full-text message search** (pg_search) ✅
- [x] **Archived / pinned conversations** ✅
- [x] **Infinite scroll for messages** ✅
- [x] **Admin dashboard** ✅
- [x] **Voice and video calls** (WebRTC) ✅
- [x] **Nickname-based identity + Contact Request system** ✅
- [x] **Marketing Template Builder** (buttons, lists, images) ✅
- [x] **Bulk Campaign sender** (up to 1,000/day by @nickname or phone) ✅
- [x] **Real-time Kanban board** for campaign delivery tracking ✅
- [x] **Interactive Message Lock** (24h block until button/list clicked) ✅
- [x] **Company Multi-Agent Inbox** (departments, routing, supervisor dashboard) ✅
- [ ] **Disappearing messages**
- [ ] **Stories / Status**#
- [ ] **Block users**
- [ ] **Rate limiting** (rack-attack)
- [ ] **Webhooks for external events**
- [ ] **Two-factor authentication** (TOTP)
- [ ] **Light/dark mode toggle**
- [ ] **@mentions in group chats**
- [ ] **AI attendant integration** (connect `attendant_type: :ai` to an LLM API)
- [ ] **SLA timers** (alert supervisor when ticket is unanswered too long)
- [ ] **Company analytics** (response time, CSAT score)

---

## Company Multi-Agent Inbox

A full **customer support inbox** built into the same chat app. Any user can register a **Company** with its own `@nickname`. Customers search for the company nickname exactly like a person and are greeted with an interactive department menu.

### Key concepts

| Concept | Description |
|---|---|
| **Company @nickname** | Unique handle that customers search for — e.g. `@acmesuporte` |
| **Department menu** | Interactive list message auto-sent on first contact |
| **Attendant** | A user linked to the company with a role (Finance, Support, AI, etc.) |
| **Supervisor** | Attendant with extra permissions — can see the dashboard, transfer and resolve tickets |
| **Assignment** | A ticket linking a customer conversation to a company and attendant |
| **CompanyChannel** | ActionCable channel for real-time dashboard updates |

### Quick setup

```
1. Click the 🏢 icon in the sidebar → Create Company
2. Go to Settings → edit your department menu
3. Go to Attendants → add team members by @nickname or email
4. Share your @nickname with customers
5. Watch conversations arrive on the live Dashboard
```

> Full tutorial: [TUTORIAL_COMPANY.md](TUTORIAL_COMPANY.md)

---

## License

MIT — free to use for personal and commercial projects.

# Company Multi-Agent Inbox — Tutorial

This tutorial covers everything you need to know to set up and use the **Company** feature: creating a company account, adding attendants with custom roles, configuring the department menu, and managing the live inbox as a supervisor.

---

## Table of Contents

1. [What is a Company Account?](#1-what-is-a-company-account)
2. [Creating Your Company](#2-creating-your-company)
3. [Configuring the Department Menu](#3-configuring-the-department-menu)
4. [Adding Attendants](#4-adding-attendants)
5. [How Customers Reach You](#5-how-customers-reach-you)
6. [The Live Dashboard](#6-the-live-dashboard)
7. [Managing Assignments (Tickets)](#7-managing-assignments-tickets)
8. [Attendant Status (Available / Busy / Offline)](#8-attendant-status)
9. [Transferring and Resolving Conversations](#9-transferring-and-resolving-conversations)
10. [Role Reference](#10-role-reference)

---

## 1. What is a Company Account?

A **Company** is a shared account that sits on top of normal user accounts. It has:

- Its own **@nickname** (e.g. `@acmesuporte`) — customers search for this to reach you
- A public **profile page** at `/companies/:id`
- A configurable **department menu** — an interactive list message customers receive when they first contact the company
- A **live supervisor dashboard** at `/company/dashboard` with real-time Kanban columns

Each attendant is a normal user account linked to the company through a **role** (e.g. "Financeiro", "Suporte", "TI").

```
Customer types @acmesuporte
        ↓
Interactive menu appears ("Pick a department")
        ↓
Customer selects "Suporte Técnico"
        ↓
System finds an available attendant with role_name = "TI"
        ↓
Attendant's chat opens with the customer conversation
        ↓
Supervisor watches it all on the live Kanban dashboard
```

---

## 2. Creating Your Company

### Step 1 — Click the building icon in the sidebar

In the chat sidebar header you will see a **building icon** (🏢). If you do not yet belong to any company, clicking it takes you to **Create Company**.

### Step 2 — Fill in the registration form

| Field | Example | Notes |
|---|---|---|
| Company name | Acme Support | Displayed everywhere |
| @Nickname | `acmesuporte` | Unique; customers search this |
| Description | "24/7 customer support" | Optional, shown on profile page |
| Logo | _upload image_ | Optional |

Click **Create Company**.

> The system automatically adds you as the first attendant with role **Admin** and marks you as **supervisor**.

### Step 3 — You are taken to the dashboard

After creation you land on `/company/dashboard`. From here you manage everything.

---

## 3. Configuring the Department Menu

When a customer contacts your company @nickname for the first time they receive an interactive list message. You control exactly what options appear.

### Editing the menu

1. Click **Configurações** in the company nav bar (or go to `/company/settings/edit`)
2. Edit the **Greeting message** — this is the text shown above the list
3. In the **Departments** section, each row has two fields:
   - **Label** — what the customer sees (e.g. "Suporte Técnico")
   - **role_name** — must match exactly the `role_name` of the attendants who handle this department (e.g. "TI")
4. Click **+ Adicionar** to add new departments
5. Click the ✕ button to remove a department
6. Watch the **live preview** on the right update as you type
7. Click **Salvar Configurações**

### Example menu config (stored as JSON internally)

```json
{
  "greeting": "Hello! How can we help you today?",
  "departments": [
    { "id": "support",  "label": "General Support",    "role_name": "Suporte" },
    { "id": "finance",  "label": "Billing / Finance",  "role_name": "Financeiro" },
    { "id": "ti",       "label": "Technical Support",  "role_name": "TI" },
    { "id": "ai",       "label": "AI Assistant",       "role_name": "IA" }
  ]
}
```

> **Important:** The `role_name` field in the menu **must match exactly** the `role_name` you assign to attendants. Capitalisation matters. If the menu says `"TI"` then attendants must have `role_name = "TI"`.

---

## 4. Adding Attendants

An attendant is any existing user you invite to your company team.

### Step 1 — Go to the Attendants page

Click **Atendentes** in the company nav, or go to `/company/attendants`.

### Step 2 — Click "Adicionar Atendente"

Fill in the form:

| Field | Notes |
|---|---|
| **@Nickname or email** | The user must already have an account |
| **Department / role_name** | e.g. `TI`, `Financeiro`, `Suporte`, `IA` — must match menu config |
| **Type** | `Human` (default) or `AI` (for bot integrations) |
| **Tags** | Comma-separated — e.g. `vip, técnico, nível2` |
| **Is supervisor** | Check to allow this attendant to see the dashboard, transfer and resolve tickets |

Click **Adicionar Atendente**.

### Editing an attendant

On the attendants list, click **Editar** next to any attendant to change their role, tags, type, or supervisor status.

### Removing an attendant

Click **Remover**. This does not delete their user account — it only removes them from your company team.

---

## 5. How Customers Reach You

Customers interact with the company just like they would search for any user by @nickname.

### Flow

1. Customer opens the chat app and clicks **+ Nova conversa** (new conversation button)
2. They type `@acmesuporte` (your company @nickname) in the search box
3. Instead of a direct chat, the system detects it is a company and:
   - Creates a **company conversation**
   - Sends the **interactive department menu** automatically
4. The customer sees the greeting message and a list of department buttons
5. They click a department (e.g. "Suporte Técnico")
6. The system calls `RouteCompanyConversationJob` which:
   - Finds the first **available** attendant with the matching `role_name`
   - Adds the attendant to the conversation
   - Sends a greeting message from the attendant
   - Updates the assignment status to **active**
7. If no attendant is available, the customer is placed in the **queue** and notified

### What the customer sees

```
┌─────────────────────────────────────────┐
│  Acme Support                           │
│                                         │
│  Hello! How can we help you today?      │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Choose a department            │   │
│  ├─────────────────────────────────┤   │
│  │  > General Support              │   │
│  │  > Billing / Finance            │   │
│  │  > Technical Support            │   │
│  │  > AI Assistant                 │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

After clicking a department, the buttons become disabled and the customer waits for an attendant.

---

## 6. The Live Dashboard

Go to `/company/dashboard` (click the building icon if you are already in a company, or click **Dashboard** in the company nav).

### Attendant status board (top)

Shows every attendant as a card with:
- **Green dot** = Available
- **Yellow dot** = Busy
- **Grey dot** = Offline

If you are viewing your own card, you will see a **dropdown** to change your own status in real time.

### Kanban columns

| Column | Meaning |
|---|---|
| **Aguardando** (Pending) | Customer contacted the company, menu was sent, waiting for them to choose a department |
| **Na Fila** (Queued) | Customer chose a department but no attendant is available yet |
| **Em Atendimento** (Active) | Assigned to an attendant and conversation is in progress |
| **Transferido** (Transferred) | Conversation was transferred to a different attendant |
| **Resolvido** (Resolved) | Ticket closed |

Cards **move between columns in real time** via ActionCable — no page refresh needed.

Clicking a card takes you to the full conversation view for that assignment.

---

## 7. Managing Assignments (Tickets)

Go to `/company/assignments` for the full list.

### Filtering

Use the status buttons at the top right to filter:
- **All** — everything
- **Aguardando** — pending menu selection
- **Ativo** — in progress
- **Resolvido** — closed

### Assignment detail page

Click **Ver** on any assignment row to open the detail view. You will see:

- The full message thread between the customer and attendant
- Assignment metadata (department, attendant, timestamps)
- **Transfer** — reassign to another available attendant
- **Marcar como Resolvido** — close the ticket (only supervisors)

---

## 8. Attendant Status

Each attendant controls their own availability from within the dashboard.

### Changing your status

On the **Dashboard** page, find your own attendant card in the **Attendant Status Board** section. Use the dropdown to select:

- **Disponível** (Available) — you will receive new conversations
- **Ocupado** (Busy) — you will not receive new conversations (customers go to queue)
- **Offline** — same as Busy; use when you are not at your computer

The status change broadcasts immediately to all supervisors via the `CompanyChannel`.

### Automatic routing

When a customer picks a department, the router picks a **random available attendant** with the matching `role_name`. If multiple attendants are available, one is chosen at random to distribute load.

---

## 9. Transferring and Resolving Conversations

### Transfer

1. Open the assignment detail (`/company/assignments/:id`)
2. In the **Transfer** panel (right sidebar), select the new attendant from the dropdown
3. Only **available** attendants appear in the list
4. Click **Transferir**

The old attendant is freed and the new attendant is added to the conversation.

### Resolve

1. Open the assignment detail
2. Click **Marcar como Resolvido** (green button, bottom of sidebar)
3. Confirm the dialog
4. The assignment moves to **Resolvido** column on the Kanban
5. The attendant's status is automatically reset to **Disponível** (if they have no other active assignments)

---

## 10. Role Reference

### Attendant types

| Type | Use case |
|---|---|
| `Human` | Regular team member — answers manually |
| `AI` | Reserved for bot integrations — you connect an AI service via webhook/API |

### Attendant status

| Status | Routing behaviour |
|---|---|
| `Available` | Will receive new conversations |
| `Busy` | Skipped during routing — customer goes to queue |
| `Offline` | Same as Busy |

### Assignment status flow

```
pending → (customer picks dept) → active
                                → queued  (no attendant free)
active  → (resolved)            → resolved
active  → (transferred)         → transferred → active (new attendant)
```

### Supervisor permissions

Supervisors can:
- See the full dashboard
- Transfer conversations between attendants
- Resolve tickets
- Add and remove attendants
- Edit company settings and menu config

Regular attendants can:
- Chat with their assigned customers
- Update their own status (available/busy/offline)
- See their own conversation list

---

## Quick Reference — URLs

| URL | Purpose |
|---|---|
| `/companies/new` | Create a new company |
| `/companies/:id` | Public company profile |
| `/company/dashboard` | Live Kanban inbox |
| `/company/attendants` | Manage team |
| `/company/attendants/new` | Add attendant |
| `/company/settings` | View company settings |
| `/company/settings/edit` | Edit menu + profile |
| `/company/assignments` | All tickets list |
| `/company/assignments/:id` | Ticket detail (transfer/resolve) |

---

## Tips

- Keep your department `role_name` values **consistent** between the menu config and attendant records. A mismatch means customers get routed to the queue even when attendants are available.
- Mark yourself **Offline** when you leave for the day so customers are not routed to you.
- Use **Tags** on attendants to filter them later (filtering by tag is planned for a future update).
- The **AI** attendant type is a placeholder — to power it, connect a webhook that listens to conversation messages and replies via the API.

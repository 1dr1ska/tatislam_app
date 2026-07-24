# TatIslam — Supabase Backend Architecture

This document is the single source of truth for the backend. It describes the
database schema, security model, storage layout, and the exact steps to
provision a new Supabase project. Read this before touching any Flutter data
layer code (Phase 2+).

---

## 1. Design principles

- **CMS, not a fixed content type.** A publication is metadata only
  (`publications`). Its body is an ordered, unbounded list of typed blocks
  (`content_blocks`): `text`, `image`, `video`, `audio` today, in any
  quantity and any order (e.g. text → image → text → video → image → audio →
  text).
- **A publication always has a cover image.** `cover_image_path` is
  `not null` — it is impossible at the database level to save a publication
  without one.
- **Block payload is JSONB, not a wide column set.** `content_blocks.data`
  holds the block-specific payload as JSON rather than a permanently growing
  list of nullable columns. This is the key extensibility decision: adding a
  brand new block type later (pdf, quote, timeline, map, poll, ...) only
  requires extending one CHECK constraint value and adding a Dart model +
  renderer — **no schema redesign, no new columns, no backfill.**
- **Sections are free-form taxonomy**, fully admin-managed (create, rename,
  hide, delete, reorder) with zero SQL required after deployment — the admin
  panel is a complete CRUD UI over the `sections` table.
- **Storage paths, not URLs, are stored in the DB.** `cover_image_path` and
  any `path` inside a block's `data` hold Storage object paths. The app
  resolves these to public URLs at read time, so bucket/CDN changes never
  require a data migration.
- **Video is always external.** `{ "url", "provider" }` — provider is
  auto-detected by the app from the URL (YouTube, RuTube, VK Video, or a
  generic direct link). Nothing is ever uploaded to Storage for video.
- **Audio supports both uploads and external URLs**, through the exact same
  `audio` block type — distinguished by a `source` discriminator
  (`"upload"` vs `"external"`) inside the JSON payload.
- **Security lives in the database.** Every table has RLS enabled. Public
  (anon + authenticated) can only read. Only rows in `profiles` with
  `role = 'admin'` can write — enforced by the `is_admin()` SQL function, not
  by client-side checks. This holds for every current and future client.

---

## 2. Entity-relationship overview

```
profiles            sections
  id (=auth.users)     id
  email                name
  role                 slug
                        is_visible
                        sort_order

publications  1 ── * content_blocks
  id                    id
  title                 publication_id (FK)
  description           type (text|image|video|audio|...)
  cover_image_path       order_index
  published_at           data (jsonb — shape depends on type)

publications  * ── * sections
        (via publication_sections)
```

---

## 3. Tables

### `profiles`
Mirrors `auth.users`; the single source of truth for the admin role.

| column     | type      | notes                                   |
|------------|-----------|------------------------------------------|
| id         | uuid PK   | = `auth.users.id`                        |
| email      | text      |                                          |
| role       | text      | `'user'` \| `'admin'`, default `'user'`  |
| created_at | timestamptz |                                        |
| updated_at | timestamptz |                                        |

A trigger (`handle_new_user`) auto-creates a `profiles` row on signup. Role
must be promoted manually (see §6).

### `sections`
Admin-managed taxonomy. Fully manageable from the admin panel — no SQL
required after deployment.

| column      | type    | notes                        |
|-------------|---------|-------------------------------|
| id          | uuid PK |                               |
| name        | text    | display name                 |
| slug        | text    | unique, url-safe              |
| is_visible  | bool    | "hide" toggle, default true   |
| sort_order  | int     | drag-and-drop order            |

### `publications`
Metadata only — no body content here.

| column            | type      | notes                              |
|-------------------|-----------|--------------------------------------|
| id                | uuid PK   |                                       |
| title             | text      |                                       |
| description       | text      | short summary shown in cards          |
| cover_image_path  | text      | Storage path, **`NOT NULL`** — a publication cannot exist without a cover |
| published_at      | timestamptz | drives ordering everywhere          |

### `content_blocks`
The ordered body of a publication. One polymorphic table; `data` carries the
type-specific payload.

| column         | type    | notes                                     |
|----------------|---------|---------------------------------------------|
| id             | uuid PK |                                              |
| publication_id | uuid FK |                                              |
| type           | text    | `text`\|`image`\|`video`\|`audio` (extend via migration for new types) |
| order_index    | int     | position within the publication              |
| data           | jsonb   | shape depends on `type`, see below           |

**`data` shapes (built-in types):**

```jsonc
// text
{ "text": "..." }

// image
{ "path": "blocks/<pubId>/images/<blockId>.jpg", "caption": "optional" }

// video — always an external URL, never uploaded
{ "url": "https://youtu.be/...", "provider": "youtube", "caption": "optional" }
// provider ∈ youtube | rutube | vk | direct — auto-detected by the app

// audio — EITHER uploaded OR external, same block type
{ "source": "upload",   "path": "blocks/<pubId>/audio/<blockId>.mp3", "caption": "optional" }
{ "source": "external", "url": "https://...",                          "caption": "optional" }
```

A CHECK constraint (`content_blocks_data_shape`) validates these shapes for
the four built-in types. Future/custom types intentionally skip this
constraint (`else true`) — they are validated at the application layer, so
adding them is a pure app-layer change plus a one-line CHECK extension.

### `publication_sections`
Many-to-many join table, composite PK `(publication_id, section_id)`. A
publication may belong to any number of sections simultaneously.

---

## 4. Security model (RLS)

| table                 | SELECT                     | INSERT/UPDATE/DELETE |
|-----------------------|-----------------------------|------------------------|
| profiles              | own row, or admin           | own row (update only) |
| sections              | visible rows, or admin       | admin only             |
| publications          | everyone                    | admin only             |
| content_blocks        | everyone                    | admin only             |
| publication_sections  | everyone                    | admin only             |
| storage.objects (media)| everyone                   | admin only             |

`is_admin(uid uuid default auth.uid())` is a `security definer` SQL function
that checks `profiles.role = 'admin'`. All admin-write policies call it, so
there is exactly one place that defines "who is an admin."

---

## 5. Storage layout

Single public bucket: **`media`**.

```
media/
  covers/<publication_id>.<ext>                    cover images
  blocks/<publication_id>/images/<block_id>.<ext>   inline images
  blocks/<publication_id>/audio/<block_id>.<ext>    uploaded audio
```

- Video is **never** uploaded — only an external `url` (inside the block's
  `data`) is stored.
- Audio may be uploaded here (`source: "upload"`) **or** reference an
  external URL (`source: "external"`) — both go through the same block type.
- Grouping by `publication_id` keeps related files together and makes
  cleanup simple if a publication is deleted (Storage objects are not
  cascade-deleted automatically by Postgres; the admin data source is
  responsible for removing associated files when a publication/block is
  deleted).
- The DB only ever stores the Storage **path**, never the public URL — the
  app resolves paths to public URLs on demand via Supabase Storage.

---

## 6. Provisioning a new Supabase project

1. Create a project at https://supabase.com/dashboard.
2. Open **SQL Editor** and run every file in `supabase/migrations/` **in
   filename order** (`0001_...` → `0009_...`). Each file is idempotent
   (`create table if not exists`, `drop policy if exists`, etc.), so it is
   safe to re-run.
3. (Optional) Run `supabase/seed.sql` to create three starter sections.
4. **Authentication → Providers**: ensure Email is enabled.
5. **Authentication → URL Configuration**: set Site URL / Redirect URLs for
   your deep link scheme.
6. Create the first admin:
   - Sign up once through the app (or Authentication → Users → Add user).
   - In the SQL Editor:
     ```sql
     update profiles set role = 'admin' where email = 'admin@example.com';
     ```
7. Copy **Project URL** and **anon public key** from Settings → API into the
   Flutter app's Supabase initialization.

If you use the Supabase CLI instead of the dashboard:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

This applies every file under `supabase/migrations/` in order.

---

## 7. Extensibility

- **New block type** (pdf, quote, timeline, map, poll, ...): add the value
  to the `content_blocks.type` CHECK, define its `data` JSON shape in the
  app, add a renderer widget. No new columns, no backfill, no redesign.
- **Draft/scheduled publishing**: add `status` or `scheduled_at` to
  `publications`; existing queries (`select * ... order by published_at`)
  are unaffected.
- **View counts, tags, comments**: new columns or new joined tables; nothing
  in the current schema needs to change.
- **Multiple admin permission levels**: extend `profiles.role` and update
  `is_admin()` / policies — a single-function change.
- **Home layout preference (Feed vs Grid)** is a per-device UI setting, not
  backend state — it is persisted locally on the device (no DB column),
  since it has no meaning server-side.

---

## 8. Directory reference

```
supabase/
  migrations/
    0001_extensions.sql
    0002_helpers.sql
    0003_profiles.sql
    0004_sections.sql
    0005_publications.sql
    0006_content_blocks.sql
    0007_publication_sections.sql
    0008_rls_policies.sql
    0009_storage.sql
  seed.sql
```

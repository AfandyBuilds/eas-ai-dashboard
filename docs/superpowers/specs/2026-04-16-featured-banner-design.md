# Featured Banner & Likes System — Design Spec

**Date:** 2026-04-16
**Status:** Approved
**Skills applied:** UI/UX Pro Max, Superpowers

---

## Overview

A full-width auto-rotating carousel banner at the top of the dashboard that spotlights the best-liked and highest-performing tasks, accomplishments, prompts, and use cases. Includes a global permanent like/unlike system visible across all content sections, with hybrid selection (admin pins + user votes + metric fallback). Refreshes daily at midnight (client-side calendar-day reset).

---

## Database Schema

### `likes` table

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID FK → users.id | Who liked |
| item_type | TEXT | 'task', 'accomplishment', 'prompt', 'use_case' |
| item_id | UUID | FK to respective table |
| created_at | TIMESTAMPTZ | Default now() |

- Unique constraint: `(user_id, item_type, item_id)`
- RLS: authenticated read all; insert/delete own only; no update

### `featured_banner_config` table

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| item_type | TEXT UNIQUE | 'task', 'accomplishment', 'prompt', 'use_case', 'global' |
| slots | INTEGER | Default varies, total = 10 |
| is_active | BOOLEAN | Default true |
| updated_by | UUID FK → users.id | |
| updated_at | TIMESTAMPTZ | |

- RLS: authenticated read; admin insert/update/delete

### `featured_banner_pins` table

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| item_type | TEXT | |
| item_id | UUID | |
| pin_label | TEXT | e.g. "Admin Pick" |
| pinned_by | UUID FK → users.id | |
| pinned_at | TIMESTAMPTZ | Default now() |
| expires_at | DATE | NULL = never |

- RLS: authenticated read; admin CRUD any; SPOC CRUD own practice only

### `v_banner_candidates` SQL view

Unions tasks, accomplishments, prompt_library, use_cases with:
- Like counts (LEFT JOIN + COUNT)
- Metric values (efficiency/time_saved for tasks, effort_saved for accomplishments)
- Pin status from featured_banner_pins
- Contributor name, practice, department
- Filtered to current quarter + approved only
- Ordered by: pinned first → like_count DESC → metric_value DESC

---

## Banner UI

- **Position:** Full-width above KPI cards, below header
- **Height:** 180px desktop / 220px mobile
- **Auto-rotate:** 5 seconds per slide
- **Controls:** Left/right arrows (44x44px), clickable dot indicators (8px+ spacing), pause on hover + keyboard focus
- **Transitions:** CSS transform translateX() 300ms ease-out (enter), ease-in (exit), direction-aware
- **Accessibility:** role="region" aria-roledescription="carousel", aria-live="polite", keyboard arrow nav, focus rings 2-4px, prefers-reduced-motion support
- **Per-slide content:** Badge label, title/description, metric chips, contributor + practice + department, date, like count + like button
- **Content-type gradients:** Blue (tasks), green (accomplishments), purple (prompts), cyan (use cases) — subtle 8% opacity
- **Empty/loading states:** Skeleton shimmer on load; friendly empty state message with CTA

---

## Like Button (Global)

- SVG heart icon, 32x32px visual / 44x44px hit area
- Outline = not liked, filled red = liked, 200ms scale bounce on toggle
- Appears on: task table rows, accomplishment cards, prompt library entries, use case cards, banner slides
- Optimistic UI: instant toggle + async Supabase write, revert on error
- One like per user per item (permanent, global)

---

## Selection Algorithm (client-side)

1. Fetch `featured_banner_config` → slots per type
2. Fetch `featured_banner_pins` (non-expired)
3. Query `v_banner_candidates` for current quarter
4. Per type: pins first → top-liked → top-metric fallback
5. Cache in localStorage with date key; recalculate on new day or quarter change

---

## Admin Configuration

- Lives in admin.html as "Banner Settings" section
- Config table: slots per content type + active toggle
- Pin management: searchable item picker, label input, optional expiry date
- SPOC: can pin own-practice items only
- Admin: full access

---

## Security

- All tables behind RLS
- View only exposes approved items
- Like auth: any authenticated user
- Pin auth: admin (any practice), SPOC (own practice)
- Client hides like button for unauthenticated users

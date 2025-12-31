# Permit Absinthe Phoenix Demo

Minimal Phoenix + Absinthe app that exercises every configurable option
introduced on the `permit/1` macro. It ships with GraphiQL so you can try the
options live against a tiny Postgres-backed dataset (users own notes).

## Prereqs
- Elixir >= 1.15
- PostgreSQL running locally (defaults: `postgres` / `postgres` on `localhost`)

## Run it
```bash
cd permit_absinthe/examples/phoenix_demo
mix deps.get
mix ecto.setup   # creates DB, runs migrations, seeds demo data
mix phx.server   # visit http://localhost:4001/graphiql
```

Headers to act as different users:
- Admin: `X-User-Id: 1`
- User: `X-User-Id: 2`
- Custom subject demo: `X-Custom-User-Id: 2`

## Fields mapped to each option
All definitions live in `lib/permit_absinthe_demo_web/schema.ex`.

- `:fetch_subject` – `noteWithCustomSubject`
- `:base_query` – `noteWithCustomBaseQuery`
- `:finalize_query` – `notesWithFinalizeQuery`
- `:handle_unauthorized` – `noteWithCustomUnauthorized`, `createNoteWithCustomOptions`
- `:handle_not_found` – `noteWithCustomNotFound`
- `:unauthorized_message` – `noteWithUnauthorizedMessage`
- `:loader` – `noteWithCustomLoader`, `noteWithNilLoader`, `noteWithRaisingLoader`
- `:wrap_authorized` – `noteWithWrappedAuthorized`, `noteWithErrorWrap`, `noteWithRaisingWrapAuthorized`, `noteWithInvalidWrapReturn`, `noteWithInvalidWrapReturnTuple`
- Combined options – `noteWithCombinedOptions`
- Standard flows – `note`, `notes`, `updateNote` (middleware)

## Targeted queries (8 features, before/after)
Each pair shows a “plain” field vs the same feature enabled. Use headers:
Admin `X-User-Id: 1`, User `X-User-Id: 2`, Custom subject `X-Custom-User-Id: 2`
(you can set both a user and custom subject header to see the `fetch_subject` branch).

1) Base query (owner filter)
```graphql
# Without base_query
query { note(id: "1") { id ownerId } }
# With base_query restricting ownerId
query { noteWithCustomBaseQuery(id: "1", ownerId: "999") { id ownerId } }
# Header: try as Admin (1) to see not-found due to owner filter
# Expect: plain `note` returns note 1 for admin; `noteWithCustomBaseQuery` → null + "Not found".
```
What it shows: how to scope the initial query (e.g., tenant/owner scoping).
Use in real products: enforce tenant isolation, parent-child ownership, or per-request filters before auth runs (mirrors `base_query` in permit_phoenix controllers/LiveViews).

2) Finalize query (pagination)
```graphql
# Without finalize_query
query { notes { id body } }
# With finalize_query applying limit/offset
query { notesWithFinalizeQuery(limit: 1, offset: 1) { id body } }
# Header: Admin (1) to see all notes; User (2) limits to own notes
# Expect: plain `notes` returns all visible notes; `notesWithFinalizeQuery` returns one note (second page).
```
What it shows: adding post-processing to queries (pagination, ordering) after auth filters.
Use in real products: pagination, sorting, windowing, or feature-flagged query tweaks without changing resolvers (same idea as `finalize_query` in permit_phoenix).

3) Fetch subject (custom current user)
```graphql
# Without fetch_subject (uses current_user)
query { note(id: "1") { id body } }
# With fetch_subject using X-Custom-User-Id
query { noteWithCustomSubject(id: "1") { id body } }
# Header: set X-Custom-User-Id: 2 (and optionally X-User-Id) to see access granted
# Expect: without custom subject, user 2 is unauthorized for note 1; with custom subject header, access succeeds.
```
What it shows: deriving the subject from custom context (headers, tokens, session).
Use in real products: API key auth, impersonation, device tokens, multi-actor contexts—same pattern as `fetch_subject` callbacks in permit_phoenix controller/live_view hooks.

4) Unauthorized handling
```graphql
# Default message
query { note(id: "3") { id } }
# Custom unauthorized handler
query { noteWithCustomUnauthorized(id: "3") { id } }
# Header: as User (2) to trigger unauthorized on someone else's note
# Expect: default → "Unauthorized"; custom → "Custom unauthorized for read on PermitAbsintheDemo.Note".
```
What it shows: customizing unauthorized errors (structure/message).
Use in real products: return domain-specific error codes, localized messages, or audit metadata (parallels `handle_unauthorized` in permit_phoenix).

5) Not found handling
```graphql
# Default not found
query { note(id: "999") { id } }
# Custom not found handler
query { noteWithCustomNotFound(id: "999") { id } }
# Header: any user; id 999 does not exist
# Expect: default → "Not found"; custom → "Custom not found".
```
What it shows: customizing not-found responses when records are absent after scoping/auth.
Use in real products: hide existence of resources (security through concealment) or attach support info (akin to `handle_not_found` in permit_phoenix).

6) Unauthorized message (string)
```graphql
# Default unauthorized message
query { note(id: "3") { id } }
# Custom unauthorized_message
query { noteWithUnauthorizedMessage(id: "3") { id } }
# Header: as User (2) to see the custom message
# Expect: default → "Unauthorized"; custom → "You don't have permission to view this item".
```
What it shows: simple string override without a full handler function.
Use in real products: quick UX-friendly denial messages without custom structs (like `unauthorized_message` in permit_phoenix).

7) Loader (non-Ecto) and nil/raise cases
```graphql
# Normal load
query { note(id: "1") { id body } }
# Custom loader
query { noteWithCustomLoader(id: "1") { id body } }
# Loader returns nil
query { noteWithNilLoader(id: "1") { id } }
# Header: Admin (1); loader examples ignore DB load but still check auth
# Expect: normal shows real note; custom loader shows body "custom_loaded"; nil loader → null + "Not found".
```
What it shows: supplying your own loader instead of Ecto; handling nil/raise gracefully.
Use in real products: load from external APIs, caches, search indices, or preloaded data structures—same pattern as `loader` in permit_phoenix when not using Ecto.

8) Wrap authorized (success/error)
```graphql
# Normal success
query { note(id: "1") { id body } }
# Wrapped success / error
query { noteWithWrappedAuthorized(id: "1") { id body } }
query { noteWithErrorWrap(id: "1") { id } }
# Header: Admin (1) to see success and custom error variants
# Expect: wrapped success matches normal (body prefixed); error wrap returns null + "Custom error from wrap".
```
What it shows: transforming the success result after authorization, or returning custom errors.
Use in real products: shape responses, attach metadata, or short-circuit with domain errors after auth passes; think of it as the Absinthe analogue of customizing controller/live_view success handling in permit_phoenix.

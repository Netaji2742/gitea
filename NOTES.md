# Task 1: Gitea Local Setup & Understanding
 
## What I understood about the Gitea project
 
Gitea is a self-hosted Git service — a lightweight, open-source alternative to
GitHub/GitLab. It's written in Go with a JS/CSS frontend, supports SQLite,
MySQL, PostgreSQL, MSSQL and TiDB as database backends, and ships as a single
compiled binary. It provides repository hosting, issues, pull requests, an
API, and more — everything needed to run your own internal Git platform.
 
## What I understood from the repository structure
 
- `cmd/` — CLI entrypoints (`gitea web`, `gitea admin`, `gitea doctor`, etc.)
- `models/` — database schema and ORM layer (xorm)
- `modules/` — reusable internal packages (git operations, auth, settings)
- `services/` — business logic between routers and models
- `routers/` — HTTP handlers, split into `web/` (browser-facing) and `api/`
- `templates/` — server-rendered HTML templates
- `web_src/` — frontend source (JS/CSS), built via pnpm/vite
- `options/locale/` — i18n translation files
- `Makefile` — drives the whole build (`make build`, `make backend`,
  `make frontend`, etc.)
- `docs/build-source.md` — official build/run documentation
## Steps I followed to run it locally (without Docker)
 
1. Forked `go-gitea/gitea` to my own GitHub account.
2. Fixed my git remotes — renamed the original `origin` (pointing at
   upstream) to `upstream`, and added my fork as the new `origin`.
3. Pushed my working branch (`netaji`) to my fork.
4. Installed prerequisites:
   - Go 1.27 (installed manually from go.dev — `apt`'s packaged version was
     too old for this project's `go.mod` requirement)
   - Node.js 22 and pnpm via `nvm` (same reason — `apt`'s Node was too old)
   - `make` (already available)
5. Built the project: `TAGS="bindata" make build`, which compiles both the
   Go backend and the frontend assets (JS/CSS via pnpm) into a single binary.
6. Ran the server: `./gitea web`
7. Completed the first-run web installer at `localhost:3000`, choosing
   SQLite3 as the database and creating an admin account.
8. Verified the app was fully working by creating a test repository (`demo`)
   through the UI.
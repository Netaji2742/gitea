# Task 2: Automate Local Project Setup

## Objective

Replace the manual sequence of commands from Task 1 (checking tool versions,
running `make build`, running `./gitea web`, etc.) with a single shell
script, `setup-gitea.sh`, that builds and runs Gitea locally end-to-end.

## What the script does

`setup-gitea.sh` automates the full local setup in one run:

1. **Verifies the correct project directory** — checks that `go.mod` and
   `Makefile` exist and that `go.mod`'s module name matches Gitea, before
   doing anything else. Prevents the script from running (and failing
   confusingly) in the wrong folder.
2. **Checks required tools are installed** — `go`, `node`, `pnpm`, `make`,
   `git`. Exits immediately with a clear list of what's missing rather than
   failing partway through the build.
3. **Displays each tool's version** — and warns (without hard failing) if
   Go or Node are below the versions this project expects.
4. **Builds Gitea from source** — runs `TAGS="bindata" make build`, which
   compiles the frontend (via pnpm/vite) and backend (Go) together into a
   single binary.
5. **Verifies the binary was created** — confirms the `gitea` executable
   exists and is executable before trying to run it.
6. **Checks whether port 3000 is already in use** — using `lsof` or `ss`
   (whichever is available) so the script fails with a clear message
   instead of a confusing bind error from Gitea itself.
7. **Starts the Gitea web server** and **prints the local URL**
   (`http://localhost:3000`) so there's no guessing where to go.

## Design decisions

- **No hard-coded paths.** The script resolves its own directory at runtime
  with `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, so it
  works regardless of username or where the repo is cloned — it doesn't
  assume `/home/akash/...` or any specific machine.
- **Error handling over `set -e`.** Instead of relying on `set -e` to
  silently kill the script on any failure, each step checks its own result
  and prints a clear `[ERROR]` message explaining what went wrong and how
  to fix it, then exits with a non-zero status.
- **Status messages throughout** — colour-coded `[INFO]` / `[OK]` /
  `[WARN]` / `[ERROR]` prefixes make it easy to see progress and spot
  problems at a glance, especially useful when demonstrating in the Loom
  video.
- **No Docker** — the script only uses the native Go/Node/pnpm/make
  toolchain, consistent with Task 1's local (non-container) setup.

## How to run it

```bash
chmod +x setup-gitea.sh
./setup-gitea.sh
```

Stop the server anytime with `Ctrl+C` — this sends `SIGINT`, which Gitea
handles gracefully (closes the HTTP listener cleanly rather than crashing),
confirmed in the log output:

```
[W] PID <pid>. Received SIGINT. Shutting down...
[I] HTTP Listener: 0.0.0.0:3000 Closed
[I] PID: <pid> Gitea Web Finished
```

## Verification performed

- Ran the script from a clean terminal in the project root.
- Confirmed it detected all installed tools and versions correctly.
- Confirmed it rebuilt successfully and located the resulting binary.
- Confirmed it correctly reported port 3000 as free.
- Confirmed the server started and `http://localhost:3000` loaded the
  existing Gitea dashboard (not the installer again), proving that
  previously persisted data (`app.ini`, SQLite DB, the `demo` repo from
  Task 1) was picked up correctly.
- Confirmed `Ctrl+C` stopped the server gracefully.

## What I learned

- How to turn a manual setup runbook into an idempotent, portable script.
- Why explicit checks (tool presence, directory, port availability) matter
  more than just chaining commands together — they turn silent/confusing
  failures into actionable error messages.
- How to avoid hard-coded paths by resolving a script's own location at
  runtime, making it portable across machines and users.
- How Unix signals (SIGINT) enable graceful shutdown in long-running
  server processes.
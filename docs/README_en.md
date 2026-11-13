# Claude Dev Container

[![CI](https://github.com/ManuelFlorez/claude-dev-container/actions/workflows/ci.yml/badge.svg)](https://github.com/ManuelFlorez/claude-dev-container/actions/workflows/ci.yml)

[English](README_en.md) | [Español](README_es.md) | [Home](../README.md)

Docker image that prepares a ready-to-use development environment with
[Claude Code](https://docs.anthropic.com/en/docs/claude-code) and the [GitHub CLI](https://cli.github.com/),
designed for working with AI agents and managing GitHub repositories from an
isolated, reproducible container.

## Requirements

- [Docker](https://docs.docker.com/get-docker/) installed and running.

## Image contents

- **Node.js** `26.13.0` (base `node:26.13.0-bookworm`).
- **GitHub CLI** (`gh`), installed from the official repository.
- **Claude Code** (`claude`), installed via the official install script.
- **jq**, **ripgrep**, **fzf**, **tmux** and **vim** for everyday development.
- Working directory: `/app`.
- Default shell: `bash`.

## Configuration

The project includes a `.env.example` file with the required variables. Copy it
to `.env` and fill in your real credentials:

```bash
cp .env.example .env
```

```env
ANTHROPIC_API_KEY="your_anthropic_api_key_here"
GH_TOKEN="your_github_token_here"
```

- `ANTHROPIC_API_KEY`: Anthropic API key used by Claude Code.
- `GH_TOKEN`: GitHub personal token used by the `gh` CLI.

## Usage

You can build the image locally or use the version published to the GitHub
Container Registry (GHCR):

```bash
docker pull ghcr.io/manuelflorez/claude-dev-container:latest
```

### 1. Build the image

```bash
docker build -t claude-dev .
```

Or, using the Makefile:

```bash
make build
```

### 2. Run the container

```bash
docker run -it --rm --env-file .env \
  -v "${PWD}:/app" \
  -v claude-config:/root/.claude \
  -e CLAUDE_CONFIG_DIR=/root/.claude \
  claude-dev
```

Or:

```bash
make run
```

This opens a `bash` shell inside the container with:

- the variables from `.env` loaded,
- the current directory mounted at `/app`,
- a persistent Docker volume (`claude-config` by default) mounted at `/root/.claude` with `CLAUDE_CONFIG_DIR=/root/.claude`, so Claude Code credentials and session data (including `~/.claude.json`) are preserved across runs.

These paths assume the container runs as `root` (default in this image). To remove saved credentials, stop the container and run `docker volume rm claude-config`. If you authenticate with a Claude Team subscription via interactive login, avoid mixing it with `ANTHROPIC_API_KEY` unless you need to.

### 3. Authenticate GitHub (optional)

If you don't use `GH_TOKEN`, you can sign in interactively:

```bash
gh auth login
```

Check the authentication status with:

```bash
gh auth status
```

### 4. Start Claude Code

```bash
claude
```

## Makefile

Run `make help` to list the available targets:

| Target | Description |
| --- | --- |
| `make build` | Build the Docker image. |
| `make run` | Run the container with `.env`, `/app` mounted, and persistent Claude auth. |
| `make check` | Validate required files and that `.env` is not tracked by git. |
| `make clean` | Remove the Docker image. |

## SSH keys (optional)

To let `git` and `gh` use your SSH keys inside the container, mount `~/.ssh`
read-only:

```bash
docker run -it --rm --env-file .env \
  -v "${PWD}:/app" \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  claude-dev
```

If your keys are passphrase-protected, forward your SSH agent instead:

```bash
docker run -it --rm --env-file .env \
  -v "${PWD}:/app" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK=/ssh-agent \
  claude-dev
```

Make sure the mounted keys have restrictive permissions (`chmod 600`).

## Windows PowerShell (optional)

On Windows 11 you can add PowerShell profile functions so that typing `claude`
in any folder runs Claude Code inside the published image, with that folder
mounted at `/app`. The full script is also available as a
[gist](https://gist.github.com/ManuelFlorez/5d01a04f89e9d54aa0455f87abe680d1).

### 1. Allow your profile to run

PowerShell blocks `.ps1` scripts by default, including your profile. Allow
local scripts for your user (no admin needed):

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

If `Get-ExecutionPolicy -List` shows a value other than `Undefined` for
`MachinePolicy` or `UserPolicy`, the policy is enforced by Group Policy and
must be changed by your IT team.

### 2. Add the functions to your profile

```powershell
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
notepad $PROFILE
```

Paste the following, save, and reload with `. $PROFILE`:

```powershell
$ClaudeImage   = "ghcr.io/manuelflorez/claude-dev-container:1.0.0"
$ClaudeEnvFile = "$HOME\.claude-dev\.env"
$ClaudeVolume  = "claude-config"

function Invoke-ClaudeContainer {
    $dockerArgs = @(
        "run", "-it", "--rm",
        "-v", "$((Get-Location).Path):/app",
        "-v", "${ClaudeVolume}:/root/.claude",
        "-e", "CLAUDE_CONFIG_DIR=/root/.claude",
        "-w", "/app"
    )
    if (Test-Path $ClaudeEnvFile) { $dockerArgs += @("--env-file", $ClaudeEnvFile) }

    docker @dockerArgs $ClaudeImage @args
}

function claude       { Invoke-ClaudeContainer claude @args }
function claude-shell { Invoke-ClaudeContainer bash }
```

### 3. Create the env file (optional)

The functions load `$HOME\.claude-dev\.env` if it exists, kept outside your
projects so it is never committed by accident:

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude-dev" | Out-Null
New-Item -ItemType File -Force "$HOME\.claude-dev\.env" | Out-Null
notepad "$HOME\.claude-dev\.env"
```

Add your token **without quotes** (`docker --env-file` keeps quotes as part of
the value):

```
GH_TOKEN=ghp_your_token_here
```

Avoid `echo ... >` or `Out-File` in Windows PowerShell 5.1: they write UTF-16
or a BOM, which breaks the first variable. Notepad on Windows 11 saves UTF-8
without BOM.

### 4. Use it

```powershell
cd C:\path\to\your\project
claude               # Claude Code in the current folder
claude --version     # arguments are passed through to claude
claude-shell         # bash inside the container
```

Notes:

- Docker Desktop must be running (WSL2 backend).
- If the GHCR package is private, run `docker login ghcr.io` first with a token
  that has the `read:packages` scope.
- These functions take precedence over a native `claude` install on Windows;
  rename them (e.g. `claude-docker`) if you have both.

## Security notes

- **Do not commit** the `.env` file with real keys to a public repository. It is
  already listed in `.gitignore`; share `.env.example` with example values instead.
- CI runs **gitleaks** to detect secrets in the repository history.
- Rotate any token you may have exposed by mistake.
- Use GitHub tokens with the minimum required permissions.

## Documentation

- [English documentation](README_en.md)
- [Documentación en español](README_es.md)
- [Project README](../README.md)

## License

Released under the [MIT License](../LICENSE).

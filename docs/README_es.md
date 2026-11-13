# Claude Dev Container

[![CI](https://github.com/ManuelFlorez/claude-dev-container/actions/workflows/ci.yml/badge.svg)](https://github.com/ManuelFlorez/claude-dev-container/actions/workflows/ci.yml)

[English](README_en.md) | Español | [Inicio](../README.md)

Imagen Docker que prepara un entorno de desarrollo listo para usar con
[Claude Code](https://docs.anthropic.com/en/docs/claude-code) y el [GitHub CLI](https://cli.github.com/),
pensada para trabajar con agentes de IA y gestionar repositorios de GitHub desde
un contenedor aislado y reproducible.

## Requisitos

- [Docker](https://docs.docker.com/get-docker/) instalado y funcionando.

## Contenido de la imagen

- **Node.js** `26.13.0` (base `node:26.13.0-bookworm`).
- **GitHub CLI** (`gh`), instalado desde el repositorio oficial.
- **Claude Code** (`claude`), instalado mediante el script de instalación oficial.
- **jq**, **ripgrep**, **fzf**, **tmux** y **vim** para el trabajo diario.
- Directorio de trabajo: `/app`.
- Shell por defecto: `bash`.

## Configuración

El proyecto incluye un archivo `.env.example` con las variables necesarias.
Cópialo a `.env` y rellena tus credenciales reales:

```bash
cp .env.example .env
```

```env
ANTHROPIC_API_KEY="tu_clave_de_anthropic_aqui"
GH_TOKEN="tu_token_de_github_aqui"
```

- `ANTHROPIC_API_KEY`: clave de API de Anthropic usada por Claude Code.
- `GH_TOKEN`: token personal de GitHub usado por el CLI `gh`.

## Uso

Puedes construir la imagen localmente o usar la versión publicada en el
GitHub Container Registry (GHCR):

```bash
docker pull ghcr.io/manuelflorez/claude-dev-container:latest
```

### 1. Construir la imagen

```bash
docker build -t claude-dev .
```

O, usando el Makefile:

```bash
make build
```

### 2. Ejecutar el contenedor

```bash
docker run -it --rm --env-file .env \
  -v "${PWD}:/app" \
  -v claude-config:/root/.claude \
  -e CLAUDE_CONFIG_DIR=/root/.claude \
  claude-dev
```

O:

```bash
make run
```

Esto abre una shell `bash` dentro del contenedor, con:

- las variables del `.env` cargadas,
- el directorio actual montado en `/app`,
- un volumen Docker persistente (`claude-config` por defecto) montado en `/root/.claude` con `CLAUDE_CONFIG_DIR=/root/.claude`, para conservar las credenciales y datos de sesión de Claude Code (incluido `~/.claude.json`) entre ejecuciones.

Estas rutas asumen que el contenedor se ejecuta como `root` (valor por defecto en esta imagen). Para eliminar las credenciales guardadas, detén el contenedor y ejecuta `docker volume rm claude-config`. Si te autenticas con una suscripción Claude Team mediante login interactivo, evita mezclarlo con `ANTHROPIC_API_KEY` salvo que lo necesites.

### 3. Autenticar GitHub (opcional)

Si no usas `GH_TOKEN`, puedes iniciar sesión de forma interactiva:

```bash
gh auth login
```

Comprueba el estado de la autenticación con:

```bash
gh auth status
```

### 4. Iniciar Claude Code

```bash
claude
```

## Makefile

Ejecuta `make help` para listar los objetivos disponibles:

| Objetivo | Descripción |
| --- | --- |
| `make build` | Construye la imagen Docker. |
| `make run` | Ejecuta el contenedor con `.env`, `/app` montado y autenticación de Claude persistente. |
| `make check` | Valida los archivos necesarios y que `.env` no esté versionado. |
| `make clean` | Elimina la imagen Docker. |

## Llaves SSH (opcional)

Para que `git` y `gh` usen tus llaves SSH dentro del contenedor, monta `~/.ssh`
en modo solo lectura:

```bash
docker run -it --rm --env-file .env \
  -v "${PWD}:/app" \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  claude-dev
```

Si tus llaves tienen passphrase, reenvía tu agente SSH en su lugar:

```bash
docker run -it --rm --env-file .env \
  -v "${PWD}:/app" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK=/ssh-agent \
  claude-dev
```

Asegúrate de que las llaves montadas tengan permisos restrictivos (`chmod 600`).

## Windows PowerShell (opcional)

En Windows 11 puedes añadir funciones a tu perfil de PowerShell para que, al
escribir `claude` en cualquier carpeta, se ejecute Claude Code dentro de la
imagen publicada, con esa carpeta montada en `/app`. El script completo también
está disponible como [gist](https://gist.github.com/ManuelFlorez/5d01a04f89e9d54aa0455f87abe680d1).

### 1. Permitir que se ejecute el perfil

PowerShell bloquea por defecto los scripts `.ps1`, incluido tu perfil. Permite
los scripts locales para tu usuario (no requiere administrador):

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Si `Get-ExecutionPolicy -List` muestra un valor distinto de `Undefined` en
`MachinePolicy` o `UserPolicy`, la política la impone una directiva de grupo y
debe cambiarla tu equipo de TI.

### 2. Añadir las funciones al perfil

```powershell
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
notepad $PROFILE
```

Pega lo siguiente, guarda y recarga con `. $PROFILE`:

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

### 3. Crear el archivo de entorno (opcional)

Las funciones cargan `$HOME\.claude-dev\.env` si existe; queda fuera de tus
proyectos para no versionarlo por error:

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude-dev" | Out-Null
New-Item -ItemType File -Force "$HOME\.claude-dev\.env" | Out-Null
notepad "$HOME\.claude-dev\.env"
```

Escribe tu token **sin comillas** (`docker --env-file` conserva las comillas
como parte del valor):

```
GH_TOKEN=ghp_tu_token_aqui
```

Evita `echo ... >` u `Out-File` en Windows PowerShell 5.1: escriben en UTF-16
o con BOM y Docker no lee bien la primera variable. El Bloc de notas de
Windows 11 guarda en UTF-8 sin BOM.

### 4. Uso

```powershell
cd C:\ruta\a\tu\proyecto
claude               # Claude Code en la carpeta actual
claude --version     # los argumentos se pasan tal cual a claude
claude-shell         # bash dentro del contenedor
```

Notas:

- Docker Desktop debe estar en ejecución (backend WSL2).
- Si el paquete en GHCR es privado, ejecuta antes `docker login ghcr.io` con un
  token con el permiso `read:packages`.
- Estas funciones tienen prioridad sobre una instalación nativa de `claude` en
  Windows; renómbralas (por ejemplo `claude-docker`) si tienes ambas.

## Notas de seguridad

- **No subas** el archivo `.env` con claves reales a un repositorio público.
  Ya está incluido en `.gitignore`; comparte un `.env.example` con valores de
  ejemplo en su lugar.
- El CI ejecuta **gitleaks** para detectar secretos en el historial del repositorio.
- Rota cualquier token que hayas expuesto por error.
- Usa tokens de GitHub con el mínimo de permisos necesarios.

## Documentación

- [Documentación en inglés](README_en.md)
- [README del proyecto (inglés)](../README.md)

## Licencia

Distribuido bajo la [Licencia MIT](../LICENSE).

# 🦙 ollameter
> A terminal benchmark tool for locally-hosted [Ollama](https://ollama.com) models.  
> Test generation speed across multiple servers and prompt types — with live streaming output and persistent result history.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-lightgrey.svg)]()

---

## Features

- 🖥️ **Multi-server support** — configure up to 4 Ollama server profiles (A–D), switch on the fly
- 📝 **7 built-in benchmark prompts** — Python, PHP, Bash, SQL, Logic puzzle, Philosophy, Baseline
- ⚡ **Live streaming output** — tokens appear in real time with a spinner and t/s progress bar
- 📊 **Result history** — last speed and token count stored per model × prompt × server
- 🔢 **Hard token cap** — configurable `MAX_TOKENS` via Ollama's `num_predict`; truncation is detected and shown
- 🌐 **Remote model listing** — models fetched via Ollama REST API (works for remote servers, no SSH needed)
- 📦 **No dependencies** — requires only `bash`, `python3` (stdlib only) and `curl`

---

## Requirements

| Tool | Version |
|------|---------|
| `bash` | 4.0+ |
| `python3` | 3.6+ (standard library only) |
| `curl` | any recent |
| Ollama | running on at least one server |

---

## Installation

```bash
git clone https://github.com/MrRolid/ollapulse.git
cd ollapulse
chmod +x ollapulse.sh
./ollapulse.sh
```

---

## Configuration

Edit the **USER CONFIGURATION** block at the top of `ollapulse.sh`:

```bash
# Maximum tokens generated per run  (hard cap via num_predict)
MAX_TOKENS=800

# ── Server Profiles  (A – D) ─────────────────────────────────
# Leave URL empty ("") to disable a slot.

SERVER_NAME_A="Local"
SERVER_URL_A="http://localhost:11434"

SERVER_NAME_B="Primary"
SERVER_URL_B="http://192.168.1.100:11434"

SERVER_NAME_C="Secondary"
SERVER_URL_C=""

SERVER_NAME_D="Remote"
SERVER_URL_D=""

# Default active server and prompt on startup
ACTIVE_SERVER="A"
ACTIVE_PROMPT=1
```

Results are saved automatically to `~/.config/ollama_bench_results.dat`.

---

## Usage

```
  Choose (number / A-D / P1-P7 / Z / X):
```

| Input | Action |
|-------|--------|
| `0`, `1`, `2`, … | Run benchmark on that model |
| `A` / `B` / `C` / `D` | Switch active server |
| `P1` … `P7` | Switch active prompt |
| `Z` | Test **all** models with the active prompt |
| `X` | Quit |

---

## Benchmark Prompts

| Tag | Name | Expected output |
|-----|------|----------------|
| `[PY]` | Python – fibonacci + @timer decorator | ~300 tokens |
| `[PHP]` | PHP – REST API class skeleton | ~400 tokens |
| `[SH]` | Bash – compress old files (function) | ~250 tokens |
| `[SQL]` | SQL – TOP 10 query + index hint | ~200 tokens |
| `[LOG]` | Logic – reasoning puzzle (Czech) | ~150 tokens |
| `[PHI]` | Philosophy – Plato & AI (~150 words, Czech) | ~200 tokens |
| `[BSL]` | Baseline – count 1–20 + greeting | ~60 tokens |

The `MAX_TOKENS` cap applies to all prompts. A warning appears at 90 % usage and a `⚠ truncated` note is shown in statistics if the model hits the limit.

---

## Result History

Each completed run stores one line in `~/.config/ollama_bench_results.dat`:

```
model_name | prompt_id | server_key | speed (t/s) | tokens | duration | timestamp
```

Switching between prompts or servers in the main menu instantly refreshes the history column in the model table.

---

## Adding Custom Prompts

1. Increment `PROMPT_COUNT` at the top of the script
2. Add a `case` entry in each of the four functions:  
   `prompt_name()` · `prompt_expected()` · `prompt_tag()` · `get_prompt_text()`

---

## License

MIT License — see [LICENSE](LICENSE)

Copyright © 2026 [Martin Vorel](https://github.com/MrRolid)

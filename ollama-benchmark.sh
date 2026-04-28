#!/bin/bash
# ================================================================
#  Ollama Benchmark
#  ──────────────────────────────────────────────────────────────
#  Author  : Martin Vorel
#  GitHub  : https://github.com/MrRolid
#  License : MIT  (https://opensource.org/licenses/MIT)
#  Version : 1.0.0
# ================================================================
#
#  A terminal benchmark tool for locally-hosted Ollama models.
#
#  Features:
#   • Switch between up to 4 Ollama server profiles  (A – D)
#   • 7 built-in benchmark prompts: Python, PHP, Bash, SQL,
#     Logic puzzle, Philosophy, Baseline counting
#   • Live streaming output with spinner + real-time t/s counter
#   • Per-model / per-prompt / per-server result history
#   • Hard token cap via num_predict  (configurable MAX_TOKENS)
#   • Truncation detection with visual warning
#   • Remote model listing via Ollama REST API
#
# ================================================================

# ╔══════════════════════════════════════════════════════════════╗
# ║                    USER CONFIGURATION                        ║
# ╚══════════════════════════════════════════════════════════════╝

# Maximum tokens generated per run  (hard cap via num_predict)
MAX_TOKENS=800

# Results history file
RESULTS_FILE="$HOME/.config/ollama_bench_results.dat"

# ── Server Profiles  (A – D) ─────────────────────────────────
# Edit names and URLs to match your setup.
# Leave URL empty ("") to disable a slot.

SERVER_NAME_A="Local"
SERVER_URL_A="http://localhost:11434"

SERVER_NAME_B="Primary"
SERVER_URL_B="http://192.168.102.101:11434"

SERVER_NAME_C="Secondary"
SERVER_URL_C=""

SERVER_NAME_D="Remote"
SERVER_URL_D=""

# Default active server  (A / B / C / D)
ACTIVE_SERVER="B"

# Default active prompt  (1 – 7)
ACTIVE_PROMPT=1

# ════════════════════════════════════════════════════════════════
#  Internal setup — do not edit below unless you know what you're doing
# ════════════════════════════════════════════════════════════════

mkdir -p "$(dirname "$RESULTS_FILE")"

ESC=$'\e'
R="${ESC}[0m";   B="${ESC}[1m";   DIM="${ESC}[2m"
CY="${ESC}[96m"; GR="${ESC}[92m"; YL="${ESC}[93m"
RD="${ESC}[91m"; MG="${ESC}[95m"; BL="${ESC}[94m"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SEP2="──────────────────────────────────────────────────────────────────────────"

PROMPT_COUNT=7

# ── Server helpers ───────────────────────────────────────────
server_name() {
    case $1 in
        A) echo "$SERVER_NAME_A";; B) echo "$SERVER_NAME_B";;
        C) echo "$SERVER_NAME_C";; D) echo "$SERVER_NAME_D";;
    esac
}

server_url() {
    case $1 in
        A) echo "$SERVER_URL_A";; B) echo "$SERVER_URL_B";;
        C) echo "$SERVER_URL_C";; D) echo "$SERVER_URL_D";;
    esac
}

server_enabled() {
    local url; url=$(server_url "$1")
    [ -n "$url" ]
}

# Returns true (0) if server responds within 3 s
server_online() {
    local url; url=$(server_url "$1")
    [ -z "$url" ] && return 1
    curl -s --max-time 3 "$url/api/tags" -o /dev/null 2>&1
}

# ── Prompt definitions ───────────────────────────────────────
prompt_name() {
    case $1 in
        1) echo "Python   – fibonacci + @timer decorator";;
        2) echo "PHP      – REST API class (skeleton)";;
        3) echo "Bash     – compress old files (function)";;
        4) echo "SQL      – TOP 10 query + index hint";;
        5) echo "Logic    – reasoning puzzle (Czech)";;
        6) echo "Philosophy – Plato & AI  (~150 words, Czech)";;
        7) echo "Baseline – count 1–20 + greeting";;
    esac
}

prompt_expected() {
    case $1 in
        1) echo "~300tok";; 2) echo "~400tok";; 3) echo "~250tok";;
        4) echo "~200tok";; 5) echo "~150tok";; 6) echo "~200tok";; 7) echo "~60tok";;
    esac
}

prompt_tag() {
    case $1 in
        1) echo "[PY]";; 2) echo "[PHP]";; 3) echo "[SH]";;
        4) echo "[SQL]";; 5) echo "[LOG]";; 6) echo "[PHI]";; 7) echo "[BSL]";;
    esac
}

get_prompt_text() {
    case $1 in
        1) cat << 'PROMPT'
Write Python code only (no prose, only code + brief inline comments):
1. A fibonacci(n) function using functools.lru_cache for memoization.
2. A @timer decorator that prints execution time in milliseconds.
3. Apply @timer to fibonacci and print results for n=10 and n=35.
Keep total output under 35 lines.
PROMPT
        ;;
        2) cat << 'PROMPT'
Write a PHP class ProductAPI (raw PHP, no frameworks). Show only:
- Constructor accepting a PDO instance.
- handleRequest() routing GET / POST / PUT / DELETE.
- One example method: getAll() returning JSON with HTTP 200.
Use proper HTTP status codes and json_encode responses.
Code only, no explanations. Max 50 lines.
PROMPT
        ;;
        3) cat << 'PROMPT'
Write a single bash function: compress_old_files(dir, days)
It should: find files in $dir older than $days days, gzip each one,
print a summary line "Compressed N files".
Add a basic existence check for $dir. Max 25 lines.
PROMPT
        ;;
        4) cat << 'PROMPT'
Tables: users(id,name,email), orders(id,user_id,total,status,created_at),
        order_items(id,order_id,quantity,price).
Write one PostgreSQL query: top 10 users by total spending in the last 90 days,
completed orders only. Return: name, email, order_count, total_spent.
Then write one CREATE INDEX that best speeds up this query.
SQL only — no prose explanation.
PROMPT
        ;;
        5) cat << 'PROMPT'
Tři přátelé – Adam, Bořek, Cyril – mají povolání: programátor, doktor, kuchař.
Víme: Adam není programátor. Bořek není doktor. Cyril není kuchař.
Kdo je co? Uveď postup krok za krokem, česky. Buď stručný.
PROMPT
        ;;
        6) cat << 'PROMPT'
Vysvětli Platónovo podobenství o jeskyni (max 150 slov, česky).
Přidej jeden konkrétní příklad z dnešního světa (sociální sítě, AI nebo reklama).
PROMPT
        ;;
        7) echo "Count from 1 to 20, then say hello in Czech. Nothing else.";;
    esac
}

# ── Results storage ──────────────────────────────────────────
# Format: model|prompt_id|server|speed|tokens|duration|timestamp
save_result() {
    local model="$1" pid="$2" srv="$3" speed="$4" tokens="$5" dur="$6"
    local ts; ts=$(date '+%Y-%m-%d %H:%M')
    touch "$RESULTS_FILE"
    grep -vF "${model}|${pid}|${srv}|" "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" 2>/dev/null \
        && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
    printf '%s|%s|%s|%s|%s|%s|%s\n' \
        "$model" "$pid" "$srv" "$speed" "$tokens" "$dur" "$ts" >> "$RESULTS_FILE"
}

get_result() {
    local model="$1" pid="$2" srv="$3"
    [ -f "$RESULTS_FILE" ] || return
    grep -F "${model}|${pid}|${srv}|" "$RESULTS_FILE" | tail -1
}

# ── Load model list from Ollama API ─────────────────────────
load_models() {
    local url="$1"
    python3 - "$url" << 'PYEOF'
import sys, json, urllib.request, urllib.error
url = sys.argv[1]
try:
    with urllib.request.urlopen(f"{url}/api/tags", timeout=5) as r:
        data = json.load(r)
    for m in sorted(data.get("models", []), key=lambda x: x["name"]):
        name = m["name"]
        size = m.get("size", 0) / 1_000_000_000
        print(f"{name}\t{size:.1f} GB")
except Exception as e:
    print(f"ERROR\t{e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# ── Benchmark run ────────────────────────────────────────────
run_benchmark() {
    local model="$1"
    local pid="$2"
    local srv="$3"
    local url; url=$(server_url "$srv")

    clear
    printf '\n'
    printf '  %s%s%s\n' "$B$CY" "$SEP" "$R"
    printf '  %s▶  Model  : %s%s\n'       "$B$CY"  "$R$B"     "$model"
    printf '  %s   Server : %s[%s] %s  %s%s\n' \
        "$DIM$CY" "$R$YL$B" "$srv" "$(server_name "$srv")" "$DIM$url" "$R"
    printf '  %s   Prompt : %s %s%s\n'    "$DIM$CY" "$(prompt_tag "$pid")" "$(prompt_name "$pid")" "$R"
    printf '  %s   Max tok: %s%d%s   %s(expected %s)%s\n' \
        "$DIM$CY" "$R$YL$B" "$MAX_TOKENS" "$R" "$DIM" "$(prompt_expected "$pid")" "$R"
    printf '  %s%s%s\n\n' "$B$CY" "$SEP" "$R"

    local STATS_FILE
    STATS_FILE=$(mktemp /tmp/bench_stats_XXXXXX)

    printf '  %s📝 Response:%s\n' "$B" "$R"
    printf '  %s%s%s\n\n' "$DIM" "$SEP2" "$R"

    export _BENCH_URL="$url"
    export _BENCH_MODEL="$model"
    export _BENCH_STATS="$STATS_FILE"
    export _BENCH_MAX="$MAX_TOKENS"
    export _BENCH_PROMPT
    _BENCH_PROMPT="$(get_prompt_text "$pid")"

    python3 << 'PYEOF'
import sys, os, json, time, threading, urllib.request, urllib.error

url        = os.environ["_BENCH_URL"]
model      = os.environ["_BENCH_MODEL"]
stats_file = os.environ["_BENCH_STATS"]
max_tokens = int(os.environ["_BENCH_MAX"])
prompt     = os.environ["_BENCH_PROMPT"].strip()

ESC = "\033"
GR=f"{ESC}[92m"; YL=f"{ESC}[93m"; DIM=f"{ESC}[2m"
B=f"{ESC}[1m";   R=f"{ESC}[0m";   CY=f"{ESC}[96m"; RD=f"{ESC}[91m"

# Spinner thread
stop_spinner = threading.Event()

def spinner_thread():
    frames = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    idx = 0
    while not stop_spinner.is_set():
        sys.stdout.write(f"\r  {YL}{frames[idx % len(frames)]}{R}  {DIM}Waiting for first token...{R}  ")
        sys.stdout.flush()
        idx += 1
        stop_spinner.wait(0.1)
    sys.stdout.write(f"\r{' ' * 55}\r")
    sys.stdout.flush()

t = threading.Thread(target=spinner_thread, daemon=True)
t.start()

payload = json.dumps({
    "model":   model,
    "prompt":  prompt,
    "stream":  True,
    "options": {"num_predict": max_tokens}
}).encode()

req = urllib.request.Request(
    f"{url}/api/generate", data=payload,
    headers={"Content-Type": "application/json"}
)

eval_count=0; eval_dur=1.0; load_dur=0.0; prompt_toks=0
token_count=0; start_time=None; is_first=True; truncated=False

try:
    with urllib.request.urlopen(req, timeout=300) as resp:
        for raw in resp:
            raw = raw.strip()
            if not raw:
                continue
            try:
                d = json.loads(raw)
            except Exception:
                continue

            if not d.get("done", False):
                token = d.get("response", "")
                if not token:
                    continue

                if is_first:
                    stop_spinner.set()
                    t.join(timeout=0.3)
                    start_time = time.time()
                    sys.stdout.write(f"  {DIM}")
                    sys.stdout.flush()
                    is_first = False

                token_count += 1

                # Soft warning at 90% of limit
                if token_count == int(max_tokens * 0.9):
                    sys.stdout.write(
                        f"\n  {YL}⚠  Approaching token limit ({max_tokens})...{R}\n  {DIM}"
                    )
                    sys.stdout.flush()

                for ch in token:
                    sys.stdout.write("\n  " if ch == "\n" else ch)
                sys.stdout.flush()

                # Live t/s bar every 20 tokens
                if token_count % 20 == 0 and start_time:
                    elapsed = time.time() - start_time
                    spd = token_count / elapsed if elapsed > 0 else 0
                    filled = int((token_count / max_tokens) * 20)
                    bar = "█" * filled + "░" * (20 - filled)
                    sys.stdout.write(
                        f"\033[s\033[3;0H\033[2K"
                        f"  {CY}⚡ {B}{spd:.1f} t/s{R}  {DIM}[{bar}] {token_count}/{max_tokens}{R}"
                        f"\033[u"
                    )
                    sys.stdout.flush()

            else:
                eval_count  = d.get("eval_count", 0)
                eval_dur    = max(d.get("eval_duration", 1), 1) / 1e9
                load_dur    = d.get("load_duration", 0) / 1e9
                prompt_toks = d.get("prompt_eval_count", 0)
                if d.get("done_reason") == "length":
                    truncated = True

except urllib.error.URLError as e:
    stop_spinner.set()
    sys.stdout.write(f"\n\n  {RD}✗  Connection error: {e}{R}\n")
    open(stats_file, "w").write("ERR|0|0|0|0|0")
    sys.exit(1)
except Exception as e:
    stop_spinner.set()
    sys.stdout.write(f"\n\n  {RD}✗  Error: {e}{R}\n")
    open(stats_file, "w").write("ERR|0|0|0|0|0")
    sys.exit(1)
finally:
    stop_spinner.set()

speed = eval_count / eval_dur if eval_dur > 0 else 0
sys.stdout.write(f"{R}\n"); sys.stdout.flush()
open(stats_file, "w").write(
    f"{speed:.1f}|{eval_count}|{eval_dur:.1f}|{load_dur:.1f}|{prompt_toks}|{'1' if truncated else '0'}"
)
PYEOF

    local exit_code=$?
    local stats=""
    [ -f "$STATS_FILE" ] && stats=$(cat "$STATS_FILE")
    rm -f "$STATS_FILE"
    unset _BENCH_URL _BENCH_MODEL _BENCH_STATS _BENCH_MAX _BENCH_PROMPT

    if [[ "$stats" == ERR* ]] || [ $exit_code -ne 0 ] || [ -z "$stats" ]; then
        printf '\n  %s✗  Benchmark failed.%s\n' "$B$RD" "$R"
        read -rp "  Press Enter to return..."
        return
    fi

    local speed tokens dur load ptoks trunc
    IFS='|' read -r speed tokens dur load ptoks trunc <<< "$stats"

    printf '\n  %s%s%s\n' "$DIM$CY" "$SEP2" "$R"
    printf '  %s📊 Statistics:%s\n' "$B" "$R"
    printf '  %-22s %s%s t/s%s\n'       "  Speed:"           "$GR$B" "$speed"  "$R"
    printf '  %-22s %s tokens in %ss\n' "  Output:"          "$tokens" "$dur"
    printf '  %-22s %ss\n'              "  GPU load time:"   "$load"
    printf '  %-22s %s\n'               "  Prompt tokens:"   "$ptoks"
    [ "$trunc" = "1" ] && \
        printf '  %-22s %s⚠ truncated at %d tokens%s\n' "  Limit hit:" "$YL$B" "$MAX_TOKENS" "$R"
    printf '  %s%s%s\n' "$DIM$CY" "$SEP2" "$R"

    save_result "$model" "$pid" "$srv" "$speed" "$tokens" "$dur"

    printf '\n'
    read -rp "  Press Enter to continue..."
}

# ════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ════════════════════════════════════════════════════════════════
while true; do
    clear

    # Load model list from current server
    local_url=$(server_url "$ACTIVE_SERVER")
    mapfile -t MODEL_LINES < <(load_models "$local_url" 2>/dev/null)
    MODEL_COUNT=${#MODEL_LINES[@]}
    SERVER_OK=true
    if [ "$MODEL_COUNT" -eq 0 ]; then
        SERVER_OK=false
    fi

    printf '\n'
    printf '  %s╔══════════════════════════════════════════════════════════╗%s\n' "$B$CY" "$R"
    printf '  %s║           O L L A M A   B E N C H M A R K              ║%s\n' "$B$CY" "$R"
    printf '  %s║           github.com/MrRolid  •  MIT License            ║%s\n' "$DIM$CY" "$R"
    printf '  %s╚══════════════════════════════════════════════════════════╝%s\n' "$B$CY" "$R"
    printf '\n'

    # ── Server selector ──────────────────────────────────────
    printf '  %sServers%s  %s(switch: A B C D)%s\n' "$B" "$R" "$DIM" "$R"
    for S in A B C D; do
        server_enabled "$S" || continue
        sname=$(server_name "$S")
        surl=$(server_url "$S")
        if [ "$S" = "$ACTIVE_SERVER" ]; then
            if $SERVER_OK; then
                status="${GR}● online${R}"
            else
                status="${RD}✗ unreachable${R}"
            fi
            printf '    %s[%s]%s %-12s  %s%s%s  %s%s◀%s\n' \
                "$GR$B" "$S" "$R" "$sname" "$DIM" "$surl" "$R" "$GR" "" "$R"
        else
            printf '    %s[%s]%s %-12s  %s%s%s\n' \
                "$DIM" "$S" "$R" "$sname" "$DIM" "$surl" "$R"
        fi
    done
    printf '\n'

    # ── Prompt selector ───────────────────────────────────────
    printf '  %sPrompts%s  %s(switch: P1–P%d)%s\n' "$B" "$R" "$DIM" "$PROMPT_COUNT" "$R"
    for i in $(seq 1 $PROMPT_COUNT); do
        exp=$(prompt_expected "$i")
        if [ "$i" -eq "$ACTIVE_PROMPT" ]; then
            printf '    %s[P%d]%s %s %-40s %s%-8s  ◀%s\n' \
                "$YL$B" "$i" "$R" "$(prompt_tag "$i")" "$(prompt_name "$i")" "$DIM" "$exp" "$R"
        else
            printf '    %s[P%d]%s %s %-40s %s%s%s\n' \
                "$DIM" "$i" "$R" "$(prompt_tag "$i")" "$(prompt_name "$i")" "$DIM" "$exp" "$R"
        fi
    done
    printf '\n'

    # ── Model table ───────────────────────────────────────────
    printf '  %s%s%s\n' "$DIM" "$SEP2" "$R"
    printf '  %s%-4s  %-42s %-9s  %-10s  %-8s  %s%s\n' \
        "$B" "No." "Model" "Size" "Speed" "Tokens" "Last run [$(prompt_tag "$ACTIVE_PROMPT") / $ACTIVE_SERVER]" "$R"
    printf '  %s%s%s\n' "$DIM" "$SEP2" "$R"

    if ! $SERVER_OK; then
        printf '  %s  ✗  Cannot reach server [%s] — check the URL in configuration.%s\n' \
            "$RD$B" "$ACTIVE_SERVER" "$R"
    else
        for i in "${!MODEL_LINES[@]}"; do
            NAME=$(cut -f1 <<< "${MODEL_LINES[$i]}")
            SIZE=$(cut -f2 <<< "${MODEL_LINES[$i]}")
            row=$(get_result "$NAME" "$ACTIVE_PROMPT" "$ACTIVE_SERVER")
            if [ -n "$row" ]; then
                spd=$(cut -d'|' -f4 <<< "$row")
                tok=$(cut -d'|' -f5 <<< "$row")
                ts=$(cut -d'|'  -f7 <<< "$row")
                printf '  %s[%2d]%s  %-42s %-9s  %s%-8s t/s%s  %s%-6s tok%s  %s%s%s\n' \
                    "$YL" "$i" "$R" "$NAME" "$SIZE" \
                    "$GR$B" "$spd" "$R" "$DIM" "$tok" "$R" "$DIM" "$ts" "$R"
            else
                printf '  %s[%2d]%s  %-42s %-9s  %s─%s\n' \
                    "$YL" "$i" "$R" "$NAME" "$SIZE" "$DIM" "$R"
            fi
        done
    fi

    printf '  %s%s%s\n' "$DIM" "$SEP2" "$R"
    printf '  %s[Z]%s  Test ALL models with active prompt\n' "$MG$B" "$R"
    printf '  %s[X]%s  Quit\n' "$RD$B" "$R"
    printf '\n'
    read -rp "  Choose (number / A-D / P1-P${PROMPT_COUNT} / Z / X): " CHOICE

    CHOICE_UP=$(echo "$CHOICE" | tr '[:lower:]' '[:upper:]')

    case "$CHOICE_UP" in
        X)
            printf '\n  %sGoodbye!%s\n\n' "$GR$B" "$R"
            break
            ;;
        Z)
            if ! $SERVER_OK; then
                printf '  %sServer unreachable!%s\n' "$RD" "$R"; sleep 2; continue
            fi
            for i in "${!MODEL_LINES[@]}"; do
                MDL=$(cut -f1 <<< "${MODEL_LINES[$i]}")
                run_benchmark "$MDL" "$ACTIVE_PROMPT" "$ACTIVE_SERVER"
            done
            read -rp "  Press Enter to return to menu..."
            ;;
        A|B|C|D)
            if server_enabled "$CHOICE_UP"; then
                ACTIVE_SERVER="$CHOICE_UP"
            else
                printf '  %sServer [%s] is not configured (URL is empty).%s\n' \
                    "$RD" "$CHOICE_UP" "$R"; sleep 2
            fi
            ;;
        P[1-9]|P[1-9][0-9])
            pid="${CHOICE_UP:1}"
            if [ "$pid" -ge 1 ] && [ "$pid" -le "$PROMPT_COUNT" ]; then
                ACTIVE_PROMPT=$pid
            else
                printf '  %sInvalid prompt number!%s\n' "$RD" "$R"; sleep 1
            fi
            ;;
        ''|*[!0-9]*)
            printf '  %sInvalid choice!%s\n' "$RD" "$R"; sleep 1
            ;;
        *)
            if ! $SERVER_OK; then
                printf '  %sServer unreachable!%s\n' "$RD" "$R"; sleep 2
            elif [ "$CHOICE_UP" -lt "$MODEL_COUNT" ] 2>/dev/null; then
                MDL=$(cut -f1 <<< "${MODEL_LINES[$CHOICE_UP]}")
                run_benchmark "$MDL" "$ACTIVE_PROMPT" "$ACTIVE_SERVER"
            else
                printf '  %sIndex out of range!%s\n' "$RD" "$R"; sleep 1
            fi
            ;;
    esac
done

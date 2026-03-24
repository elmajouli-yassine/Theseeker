#!/usr/bin/env bash
# ============================================================
#  TheSeeker — Advanced OSINT Reconnaissance Tool
#  Version: 1.0.0
#  Author:  Yassine / TheSeeker Project
# ============================================================

set -euo pipefail

# ─── Colors & Styling ───────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Defaults ───────────────────────────────────────────────
TARGET=""
WORDLIST="/usr/share/wordlists/dirb/common.txt"
THREADS=10
OUTPUT_DIR="./theseeker_output"
DEPTH=2
FOLLOW_REDIRECTS=true
USE_CEWL=true
USE_LLM=true
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (TheSeeker/1.0 OSINT)"
EXTENSIONS="php,html,js,txt,bak,json,xml"
API_KEY="${ANTHROPIC_API_KEY:-}"
LOG_FILE=""
MODE="full"   # full | dirs | subs | llm

# ─── Banner ─────────────────────────────────────────────────
banner() {
cat << 'EOF'
   _______ _           _____           _
  |__   __| |         / ____|         | |
     | |  | |__   ___| (___   ___  ___| | _____ _ __
     | |  | '_ \ / _ \\___ \ / _ \/ _ \ |/ / _ \ '__|
     | |  | | | |  __/____) |  __/  __/   <  __/ |
     |_|  |_| |_|\___|_____/ \___|\___|_|\_\___|_|

        [ Advanced OSINT Reconnaissance Framework ]
              Powered by CewL + Claude AI
EOF
echo -e "${DIM}  ─────────────────────────────────────────────────${NC}"
}

# ─── Logging ────────────────────────────────────────────────
log()     { echo -e "${DIM}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
info()    { echo -e "${CYAN}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[FOUND]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERR]${NC}   $*" | tee -a "$LOG_FILE"; }
section() { echo -e "\n${BOLD}${BLUE}══ $* ══${NC}" | tee -a "$LOG_FILE"; }

# ─── Usage ──────────────────────────────────────────────────
usage() {
  echo -e "${WHITE}Usage:${NC} $0 [options]"
  echo ""
  echo -e "${BOLD}Required:${NC}"
  echo "  -u, --url <url>          Target URL (e.g. https://example.com)"
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -w, --wordlist <file>    Base wordlist (default: dirb common.txt)"
  echo "  -t, --threads <n>        Concurrent threads (default: 10)"
  echo "  -d, --depth <n>          Recursion depth (default: 2)"
  echo "  -e, --ext <list>         Extensions to test (default: php,html,js,...)"
  echo "  -o, --output <dir>       Output directory (default: ./theseeker_output)"
  echo "  -m, --mode <mode>        Mode: full|dirs|subs|llm (default: full)"
  echo "  --no-cewl                Skip CewL keyword scraping"
  echo "  --no-llm                 Skip LLM subdomain prediction"
  echo "  --no-redirects           Don't follow HTTP redirects"
  echo "  --timeout <sec>          Request timeout in seconds (default: 10)"
  echo "  --api-key <key>          Anthropic API key (or set ANTHROPIC_API_KEY)"
  echo "  -h, --help               Show this help"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  $0 -u https://target.com"
  echo "  $0 -u https://target.com -m subs --no-cewl"
  echo "  $0 -u https://target.com -d 3 -t 20 -e php,asp,aspx"
  exit 0
}

# ─── Dependency check ───────────────────────────────────────
check_deps() {
  local missing=()
  for dep in curl jq grep sed awk; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
  done
  if $USE_CEWL; then
    command -v cewl &>/dev/null || missing+=("cewl")
  fi
  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing dependencies: ${missing[*]}"
    error "Install with: sudo apt install ${missing[*]}"
    exit 1
  fi
}

# ─── Parse arguments ────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--url)       TARGET="$2"; shift 2 ;;
      -w|--wordlist)  WORDLIST="$2"; shift 2 ;;
      -t|--threads)   THREADS="$2"; shift 2 ;;
      -d|--depth)     DEPTH="$2"; shift 2 ;;
      -e|--ext)       EXTENSIONS="$2"; shift 2 ;;
      -o|--output)    OUTPUT_DIR="$2"; shift 2 ;;
      -m|--mode)      MODE="$2"; shift 2 ;;
      --no-cewl)      USE_CEWL=false; shift ;;
      --no-llm)       USE_LLM=false; shift ;;
      --no-redirects) FOLLOW_REDIRECTS=false; shift ;;
      --timeout)      TIMEOUT="$2"; shift 2 ;;
      --api-key)      API_KEY="$2"; shift 2 ;;
      -h|--help)      usage ;;
      *)              error "Unknown option: $1"; usage ;;
    esac
  done

  [[ -z "$TARGET" ]] && { error "Target URL is required. Use -u <url>"; usage; }
  TARGET="${TARGET%/}"  # strip trailing slash
}

# ─── Setup output directory ─────────────────────────────────
setup_output() {
  mkdir -p "$OUTPUT_DIR"
  LOG_FILE="$OUTPUT_DIR/theseeker_$(date '+%Y%m%d_%H%M%S').log"
  touch "$LOG_FILE"
  info "Output dir: $OUTPUT_DIR"
  info "Log file:   $LOG_FILE"
}

# ─── HTTP request helper ────────────────────────────────────
http_get() {
  local url="$1"
  local follow_flag=""
  $FOLLOW_REDIRECTS && follow_flag="-L"
  curl -s $follow_flag \
       --max-time "$TIMEOUT" \
       -A "$USER_AGENT" \
       -o /dev/null \
       -w "%{http_code} %{url_effective} %{redirect_url}" \
       "$url" 2>/dev/null
}

http_get_body() {
  local url="$1"
  curl -s -L --max-time "$TIMEOUT" -A "$USER_AGENT" "$url" 2>/dev/null
}

# ─── Step 1: Target fingerprinting ─────────────────────────
fingerprint_target() {
  section "Target Fingerprinting"
  info "Target: $TARGET"

  local headers
  headers=$(curl -sI --max-time "$TIMEOUT" -A "$USER_AGENT" "$TARGET" 2>/dev/null)

  local server powered_by x_frame ctype
  server=$(echo "$headers" | grep -i "^Server:" | head -1 | awk '{print $2}' || true)
  powered_by=$(echo "$headers" | grep -i "^X-Powered-By:" | head -1 | awk '{print $2}' || true)
  x_frame=$(echo "$headers" | grep -i "^X-Frame-Options:" | head -1 || true)
  ctype=$(echo "$headers" | grep -i "^Content-Type:" | head -1 || true)

  echo "$headers" > "$OUTPUT_DIR/headers.txt"

  [[ -n "$server" ]]     && info "Server:        $server"
  [[ -n "$powered_by" ]] && info "X-Powered-By:  $powered_by"
  [[ -n "$ctype" ]]      && info "Content-Type:  $ctype"
  [[ -z "$x_frame" ]]    && warn "X-Frame-Options not set (possible clickjacking)"

  # Check robots.txt
  local robots
  robots=$(http_get_body "$TARGET/robots.txt")
  if echo "$robots" | grep -qi "disallow\|allow"; then
    success "robots.txt found!"
    echo "$robots" > "$OUTPUT_DIR/robots.txt"
    local disallowed
    disallowed=$(echo "$robots" | grep -i "Disallow:" | awk '{print $2}' | grep -v "^$" || true)
    if [[ -n "$disallowed" ]]; then
      info "Disallowed paths in robots.txt:"
      echo "$disallowed" | while read -r path; do
        success "  robots.txt leak → $TARGET$path"
      done
      echo "$disallowed" > "$OUTPUT_DIR/robots_paths.txt"
    fi
  fi

  # Check sitemap
  local sitemap
  sitemap=$(http_get_body "$TARGET/sitemap.xml")
  if echo "$sitemap" | grep -qi "<urlset\|<sitemapindex"; then
    success "sitemap.xml found!"
    echo "$sitemap" > "$OUTPUT_DIR/sitemap.xml"
    grep -oP '(?<=<loc>)[^<]+' "$OUTPUT_DIR/sitemap.xml" > "$OUTPUT_DIR/sitemap_urls.txt" 2>/dev/null || true
    local count
    count=$(wc -l < "$OUTPUT_DIR/sitemap_urls.txt" 2>/dev/null || echo 0)
    info "Extracted $count URLs from sitemap"
  fi
}

# ─── Step 2: CewL keyword scraping ──────────────────────────
run_cewl() {
  section "CewL Keyword Scraping"

  if ! $USE_CEWL; then
    warn "CewL disabled, skipping."
    return
  fi

  if ! command -v cewl &>/dev/null; then
    warn "CewL not installed. Skipping keyword scraping."
    warn "Install: sudo apt install cewl"
    USE_CEWL=false
    return
  fi

  info "Running CewL on $TARGET (depth: $DEPTH)..."
  local cewl_output="$OUTPUT_DIR/cewl_keywords.txt"

  cewl -d "$DEPTH" \
    -m 4 \
    --with-numbers \
    -w "$cewl_output" \
    --ua "$USER_AGENT" \
    "$TARGET" 2>/dev/null && true

  if [[ -s "$cewl_output" ]]; then
    local count
    count=$(wc -l < "$cewl_output")
    success "CewL scraped $count keywords → $cewl_output"

    # Build extended wordlist by combining base + cewl
    local combined="$OUTPUT_DIR/combined_wordlist.txt"
    # Filter for only alphanumeric-style paths and remove binary junk
    grep -ahE '^[a-zA-Z0-9_\.\/-]+$' "$WORDLIST" "$cewl_output" 2>/dev/null | \
    sort -u > "$combined"
    count=$(wc -l < "$combined")
    info "Combined wordlist: $count unique entries → $combined"
    WORDLIST="$combined"
  else
    warn "CewL returned no keywords. Using base wordlist."
  fi
}

# ─── Step 3: Directory enumeration ──────────────────────────
enumerate_dirs() {
  section "Directory Enumeration"

  local found_file="$OUTPUT_DIR/found_dirs.txt"
  local redirect_file="$OUTPUT_DIR/redirects.txt"
  > "$found_file"
  > "$redirect_file"

  if [[ ! -f "$WORDLIST" ]]; then
    error "Wordlist not found: $WORDLIST"
    return
  fi

  local total
  total=$(wc -l < "$WORDLIST")
  info "Testing $total paths against $TARGET"
  info "Extensions: $EXTENSIONS"
  info "Threads: $THREADS"

  local count=0
  local found=0

  # Build extension array
  IFS=',' read -ra EXT_ARR <<< "$EXTENSIONS"

  # Process wordlist in parallel using background jobs
  local job_count=0

  while IFS= read -r word; do
    [[ -z "$word" || "$word" == \#* ]] && continue

    # Test base path + each extension
    local paths=("$word")
    for ext in "${EXT_ARR[@]}"; do
      paths+=("$word.$ext")
    done

    for path in "${paths[@]}"; do
      (
        local url="$TARGET/$path"
        read -r code effective_url redirect_url <<< "$(http_get "$url")"

        case "$code" in
          200|201|202|204)
            echo "$code $url" >> "$found_file"
            success "[${GREEN}$code${NC}] $url"
            ;;
          301|302|307|308)
            echo "$code $url → $effective_url" >> "$redirect_file"
            warn "[${YELLOW}$code${NC}] $url → $effective_url"
            # Add redirect destination to found
            echo "$code $effective_url" >> "$found_file"
            ;;
          401|403)
            echo "$code $url" >> "$found_file"
            info "[${MAGENTA}$code${NC}] $url (restricted)"
            ;;
        esac
      ) &

      job_count=$((job_count + 1))
      if [[ $job_count -ge $THREADS ]]; then
        wait
        job_count=0
      fi
    done

    count=$((count + 1))
    # Progress every 100 entries
    if (( count % 100 == 0 )); then
      local pct=$(( count * 100 / total ))
      printf "\r${DIM}[%3d%%] Tested %d/%d paths...${NC}" "$pct" "$count" "$total"
    fi
  done < "$WORDLIST"
  wait

  echo ""  # newline after progress

  found=$(wc -l < "$found_file" 2>/dev/null || echo 0)
  success "Enumeration complete: $found paths discovered"
}

# ─── Step 4: HTML link extraction ───────────────────────────
extract_links() {
  section "HTML Content Analysis"

  local body
  body=$(http_get_body "$TARGET")
  echo "$body" > "$OUTPUT_DIR/index.html"

  # Extract href links
  local links_file="$OUTPUT_DIR/extracted_links.txt"
  grep -oP '(?<=href=")[^"]+' "$OUTPUT_DIR/index.html" 2>/dev/null | \
    grep -v "^#\|^javascript\|^mailto" | \
    sort -u > "$links_file" || true

  # Extract src links
  grep -oP '(?<=src=")[^"]+' "$OUTPUT_DIR/index.html" 2>/dev/null | \
    sort -u >> "$links_file" || true

  # Extract data-* attributes that may contain paths
  grep -oP '(?<=data-url=")[^"]+' "$OUTPUT_DIR/index.html" 2>/dev/null >> "$links_file" || true

  sort -u -o "$links_file" "$links_file"

  local count
  count=$(wc -l < "$links_file" 2>/dev/null || echo 0)
  info "Extracted $count unique links from homepage"

  # Extract internal paths only
  local internal_file="$OUTPUT_DIR/internal_paths.txt"
  grep -E "^/" "$links_file" > "$internal_file" 2>/dev/null || true
  grep -E "^$TARGET" "$links_file" >> "$internal_file" 2>/dev/null || true
  sort -u -o "$internal_file" "$internal_file"

  local icount
  icount=$(wc -l < "$internal_file" 2>/dev/null || echo 0)
  [[ $icount -gt 0 ]] && success "Found $icount internal paths via HTML analysis"

  # Look for JS files that might expose API endpoints
  local js_files
  js_files=$(grep -oP '(?<=src=")[^"]*\.js[^"]*' "$OUTPUT_DIR/index.html" 2>/dev/null | head -10 || true)
  if [[ -n "$js_files" ]]; then
    info "Analyzing JavaScript files for hidden endpoints..."
    while IFS= read -r jsurl; do
      [[ -z "$jsurl" ]] && continue
      [[ "$jsurl" != http* ]] && jsurl="$TARGET/$jsurl"
      local jsbody
      jsbody=$(http_get_body "$jsurl" 2>/dev/null)
      # Extract API-like paths from JS
      echo "$jsbody" | grep -oP '["'"'"'](/[a-zA-Z0-9/_-]+)['"'"'"]' 2>/dev/null | \
        tr -d '"'"'" >> "$OUTPUT_DIR/js_paths.txt" || true
    done <<< "$js_files"

    if [[ -s "$OUTPUT_DIR/js_paths.txt" ]]; then
      sort -u -o "$OUTPUT_DIR/js_paths.txt" "$OUTPUT_DIR/js_paths.txt"
      count=$(wc -l < "$OUTPUT_DIR/js_paths.txt")
      success "Extracted $count potential paths from JS files"
    fi
  fi
}
#------------------------ml_prediction()-------------------------------------------
run_ml_prediction() {
  section "ML Path Prediction"
  
  local cewl_file="$OUTPUT_DIR/cewl_keywords.txt"
  local ml_out="$OUTPUT_DIR/ml_predicted_paths.txt"
  
  if [[ ! -s "$OUTPUT_DIR/cewl_keywords.txt" ]]; then
    warn "No keywords found. Running CewL automatically..."
    run_cewl
  fi
  if [[ ! -f "path_predictor.pkl" ]]; then
    warn "path_predictor.pkl not found. Run training script first."
    return
  fi

  info "Analyzing keywords with Random Forest model..."
  python3 predict.py "$cewl_file" | jq -r '.[]' > "$ml_out"

  if [[ -s "$ml_out" ]]; then
    local count=$(wc -l < "$ml_out")
    success "Model predicted $count relevant paths based on site content."
    
    # Merge these into the wordlist for the 'enumerate_dirs' step
    cat "$ml_out" >> "$WORDLIST"
    sort -u "$WORDLIST" -o "$WORDLIST"
  fi
}
# ─── Step 6: Generate HTML Report ───────────────────────────
generate_report() {
  section "Generating Report"

  local report_file="$OUTPUT_DIR/report.html"
  local domain
  domain=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  local found_count=0 sub_count=0 link_count=0
  [[ -f "$OUTPUT_DIR/found_dirs.txt" ]] && found_count=$(wc -l < "$OUTPUT_DIR/found_dirs.txt")
  [[ -f "$OUTPUT_DIR/llm_predicted_subdomains.txt" ]] && sub_count=$(wc -l < "$OUTPUT_DIR/llm_predicted_subdomains.txt")
  [[ -f "$OUTPUT_DIR/extracted_links.txt" ]] && link_count=$(wc -l < "$OUTPUT_DIR/extracted_links.txt")

  cat > "$report_file" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>TheSeeker Report — $domain</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Exo+2:wght@300;600&display=swap');
  :root { --green:#00ff88;--cyan:#00e5ff;--red:#ff3366;--bg:#080c10;--card:#0d1117; }
  body { background:var(--bg);color:#c9d1d9;font-family:'Exo 2',sans-serif;margin:0;padding:2rem; }
  h1 { font-family:'Share Tech Mono',monospace;color:var(--green);font-size:2rem;margin-bottom:0; }
  .meta { color:#555;font-size:.85rem;margin-bottom:2rem; }
  .stats { display:grid;grid-template-columns:repeat(3,1fr);gap:1rem;margin-bottom:2rem; }
  .stat { background:var(--card);border:1px solid #1e2a3a;border-radius:8px;padding:1rem;text-align:center; }
  .stat .n { font-size:2.5rem;font-weight:600;color:var(--cyan);font-family:'Share Tech Mono',monospace; }
  .stat .l { font-size:.8rem;color:#666;text-transform:uppercase; }
  table { width:100%;border-collapse:collapse;background:var(--card);border-radius:8px;overflow:hidden;margin-bottom:2rem; }
  th { background:#0d2137;color:var(--cyan);padding:.6rem 1rem;text-align:left;font-size:.8rem;text-transform:uppercase; }
  td { padding:.5rem 1rem;border-bottom:1px solid #1a1f2e;font-family:'Share Tech Mono',monospace;font-size:.85rem; }
  tr:hover td { background:#0d1a2a; }
  .c200{color:var(--green)} .c301{color:var(--cyan)} .c403{color:#ff9900} .c404{color:#555}
  h2 { color:var(--cyan);font-size:1.1rem;border-bottom:1px solid #1e2a3a;padding-bottom:.4rem; }
  .tag{display:inline-block;background:#0d2137;color:var(--cyan);padding:.2rem .6rem;border-radius:4px;margin:.2rem;font-size:.8rem;font-family:'Share Tech Mono',monospace;}
</style>
</head>
<body>
<h1>⟨ TheSeeker ⟩</h1>
<div class="meta">Target: $TARGET &nbsp;|&nbsp; Scan: $timestamp &nbsp;|&nbsp; Domain: $domain</div>

<div class="stats">
  <div class="stat"><div class="n">$found_count</div><div class="l">Paths Found</div></div>
  <div class="stat"><div class="n">$sub_count</div><div class="l">Predicted Subdomains</div></div>
  <div class="stat"><div class="n">$link_count</div><div class="l">Links Extracted</div></div>
</div>

HTMLEOF

  # Add found dirs table
  if [[ -f "$OUTPUT_DIR/found_dirs.txt" && -s "$OUTPUT_DIR/found_dirs.txt" ]]; then
    echo "<h2>Discovered Paths</h2><table><tr><th>Status</th><th>URL</th></tr>" >> "$report_file"
    while IFS= read -r line; do
      local code url
      code=$(echo "$line" | awk '{print $1}')
      url=$(echo "$line" | awk '{print $2}')
      echo "<tr><td class='c$code'>$code</td><td>$url</td></tr>" >> "$report_file"
    done < "$OUTPUT_DIR/found_dirs.txt"
    echo "</table>" >> "$report_file"
  fi

  # Add LLM results
  if [[ -f "$OUTPUT_DIR/llm_raw.json" ]]; then
    local cat_val
    cat_val=$(jq -r '.site_category' "$OUTPUT_DIR/llm_raw.json" 2>/dev/null || echo "")
    local subs_html=""
    if [[ -f "$OUTPUT_DIR/llm_predicted_subdomains.txt" ]]; then
      while IFS= read -r sub; do
        subs_html+="<span class='tag'>$sub</span>"
      done < "$OUTPUT_DIR/llm_predicted_subdomains.txt"
    fi
    cat >> "$report_file" << HTMLEOF2
<h2>LLM Subdomain Prediction</h2>
<p>Site Category: <strong style="color:var(--green)">$cat_val</strong></p>
<div>$subs_html</div><br>
HTMLEOF2
  fi

  echo "</body></html>" >> "$report_file"
  success "HTML Report → $report_file"
}

# ─── Summary ────────────────────────────────────────────────
print_summary() {
  section "Scan Summary"
  echo -e "${BOLD}Output files:${NC}"
  ls -lh "$OUTPUT_DIR/" | tail -n +2 | while IFS= read -r line; do
    echo -e "  ${DIM}$line${NC}"
  done
  echo ""
  echo -e "${GREEN}${BOLD}TheSeeker scan complete.${NC} Results in: ${CYAN}$OUTPUT_DIR/${NC}"
}

# ─── Main ────────────────────────────────────────────────────
main() {
  banner
  parse_args "$@"
  setup_output
  check_deps

  log "=== TheSeeker Scan Started ==="
  log "Target: $TARGET | Mode: $MODE | Depth: $DEPTH | Threads: $THREADS"

  case "$MODE" in
    full)
      fingerprint_target
      extract_links
      run_cewl
      run_ml_prediction
      enumerate_dirs
      ;;
    dirs)
      fingerprint_target
      extract_links
      run_cewl
      enumerate_dirs
      ;;
    ml)
      run_ml_prediction
      enumerate_dirs
      ;;
    *)
      error "Unknown mode: $MODE"
      usage
      ;;
  esac

  generate_report
  print_summary
  log "=== TheSeeker Scan Complete ==="
}

main "$@"

# TheSeeker — Advanced OSINT Reconnaissance Tool

```
   _______ _           _____           _
  |__   __| |         / ____|         | |
     | |  | |__   ___| (___   ___  ___| | _____ _ __
     | |  | '_ \ / _ \\___ \ / _ \/ _ \ |/ / _ \ '__|
     | |  | | | |  __/____) |  __/  __/   <  __/ |
     |_|  |_| |_|\___|_____/ \___|\___|_|\_\___|_|
```

> Advanced Bash-based OSINT reconnaissance framework with CewL integration and Claude AI-powered subdomain prediction.

---

## Features

| Feature | Description |
|---|---|
| 🔎 **Directory Enumeration** | Multi-threaded path bruteforcing with extension support |
| 📄 **HTML Analysis** | Link extraction, JS endpoint discovery, meta-tag harvesting |
| 🔀 **Redirect Tracking** | Follows and logs all HTTP redirections |
| 🤖 **CewL Integration** | Scrapes page keywords → generates custom wordlists |
| 🧠 **LLM Prediction** | Claude AI analyzes site category + keywords → predicts subdomains |
| 📊 **HTML Report** | Full scan report with status codes, tables, and LLM results |
| ⚡ **Concurrent** | Configurable thread count for speed |

---

## Requirements

- Bash 4+
- `curl`, `jq`, `grep`, `sed`, `awk`
- `cewl` (for keyword scraping)
- Anthropic API key (for LLM subdomain prediction)

---

## Installation

```bash
git clone https://github.com/you/theseeker
cd theseeker
chmod +x install.sh theseeker.sh
sudo ./install.sh
```

---

## Usage

```bash
# Full scan (all modules)
theseeker -u https://target.com

# Directory enumeration only
theseeker -u https://target.com -m dirs

# Subdomain prediction only (LLM)
theseeker -u https://target.com -m subs

# LLM module only (no enumeration)
theseeker -u https://target.com -m llm

# Custom options
theseeker -u https://target.com \
  -w /usr/share/wordlists/SecLists/Discovery/Web-Content/big.txt \
  -t 20 \
  -d 3 \
  -e php,asp,aspx,html,js \
  --api-key sk-ant-YOUR_KEY
```

---

## Modes

| Mode | What it does |
|---|---|
| `full` | Everything: fingerprint → extract → cewl → enumerate → LLM |
| `dirs` | Directory enumeration with CewL wordlist generation |
| `subs` | CewL scraping + LLM subdomain prediction only |
| `llm` | LLM prediction using previously collected data |

---

## LLM Subdomain Prediction

TheSeeker feeds the following context to Claude:

1. **Domain name** and TLD patterns
2. **Page title + meta description** (site category inference)
3. **CewL keywords** (top 50 scraped from target)
4. **Already-discovered paths** (from enumeration)

Claude responds with:
- Site category classification
- Predicted subdomain list (e.g. `api.`, `admin.`, `staging.`)
- Predicted directory paths specific to the site type
- Confidence level and reasoning

Predicted subdomains are then **actively probed** over HTTP/HTTPS.

---

## Output Files

```
theseeker_output/
├── theseeker_YYYYMMDD_HHMMSS.log   # Full scan log
├── headers.txt                      # HTTP response headers
├── robots.txt                       # robots.txt if found
├── robots_paths.txt                 # Disallowed paths from robots.txt
├── sitemap.xml                      # sitemap.xml if found
├── sitemap_urls.txt                 # Extracted sitemap URLs
├── index.html                       # Target homepage HTML
├── extracted_links.txt              # All hrefs/srcs found
├── internal_paths.txt               # Internal paths only
├── js_paths.txt                     # Paths found in JS files
├── cewl_keywords.txt                # CewL scraped keywords
├── combined_wordlist.txt            # Base + CewL wordlist
├── found_dirs.txt                   # Discovered paths (200/301/403)
├── redirects.txt                    # Redirect chains
├── llm_raw.json                     # Raw LLM JSON response
├── llm_predicted_subdomains.txt     # Predicted subdomain FQDNs
├── llm_predicted_dirs.txt           # LLM-suggested directories
├── verified_subdomains.txt          # Live subdomains confirmed
└── report.html                      # Full HTML report
```

---

## Environment Variables

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

---

## ⚠️ Legal Disclaimer

TheSeeker is designed for **authorized penetration testing and CTF challenges only**.  
Only use against systems you have explicit permission to test.  
Unauthorized use may violate laws including CFAA, Computer Misuse Act, and local equivalents.

---

## Author

Yassine — ENSAM Casablanca  
Built for offensive security practice and CTF reconnaissance workflows.

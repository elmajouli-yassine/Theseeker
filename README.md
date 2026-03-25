# TheSeeker — Advanced OSINT Reconnaissance Tool

```
   _______ _           _____           _
  |__   __| |         / ____|         | |
     | |  | |__   ___| (___   ___  ___| | _____ _ __
     | |  | '_ \ / _ \\___ \ / _ \/ _ \ |/ / _ \ '__|
     | |  | | | |  __/____) |  __/  __/   <  __/ |
     |_|  |_| |_|\___|_____/ \___|\___|_|\_\___|_|
```

> Advanced Bash-based OSINT reconnaissance framework with CewL integration and ML prediction.

---

## Features

| Feature | Description |
|---|---|
| 🔎 **Directory Enumeration** | Multi-threaded path bruteforcing with extension support. |
| 📄 **HTML Analysis** | Link extraction, JS endpoint discovery, and meta-tag harvesting. |
| 🔀 **Redirect Tracking** | Follows and logs all HTTP redirections. |
| 🤖 **CewL Integration** | Scrapes page keywords to generate custom, cleaned wordlists. |
| 🧠 **Local ML Prediction** | A local Random Forest model analyzes keywords to predict intelligent paths. |
| 📊 **HTML Report** | Generates a full scan report with status codes, tables, and ML results. |
| ⚡ **Concurrent** | High-speed discovery with a configurable thread count. |

---

## Requirements

- **System**: Bash 4+
- **Core Tools**: `curl`, `jq`, `grep`, `sed`, `awk`
- **Keyword Scraping**: `cewl`
- **Machine Learning**: Python 3, `scikit-learn`, `pandas`

---

## Installation

```bash
git clone https://github.com/elmajouli-yassine/Theseeker.git
cd theseeker
chmod +x install.sh theseeker.sh
sudo ./install.sh

# Train the local ML model before first use
python3 train_model.py
```

---

## Usage

```bash
# Full scan (Recon + ML + Enumeration)
./theseeker.sh -u https://target.com -m full

# Directory enumeration only
./theseeker.sh -u https://target.com -m dirs

# ML Intelligence mode (Keyword scraping + Prediction only)
./theseeker.sh -u https://target.com -m ml

# Custom options
./theseeker.sh -u https://target.com \
  -m full \
  -t 25 \
  -o custom_results \
  -e php,html,txt \
  --no-cewl \
  --no-redirects
```

---

## Modes

| Mode | What it does |
|---|---|
| `full` | The complete automated pipeline: System fingerprinting, link extraction, CewL keyword scraping, ML path prediction, and final multi-threaded directory enumeration. |
| `dirs` | Focuses on speed. It performs the initial reconnaissance and then jumps straight into directory enumeration using your base wordlists and CewL-generated keywords. |
| `ml` | The "Intelligence Only" mode. It scrapes the target for keywords and runs the local Random Forest model to predict likely paths, saving them to ml_predicted_paths.txt without performing an active scan.|

---

## ML Prediction

The model acts as a "context-aware" predictor that bridges the gap between raw scraping and active brute-forcing:

- Feature Extraction: It takes the top 50 keywords discovered by CewL and processes them as input features.

- Pattern Recognition: The Random Forest algorithm—an ensemble of decision trees—analyzes these keywords to classify the "type" of website (e.g., Medical, Corporate, Government, or Development).

- Path Intelligence: Based on the identified category, the model predicts hidden directories that are statistically likely to exist on that specific type of site (e.g., predicting /wp-json/ for a blog or /api/v1/ for a modern web app).

- Offline Efficiency: Because it uses a pre-trained .pkl file, the prediction happens in milliseconds and works entirely offline once the keywords are gathered.

### **Why Random Forest?**
A Random Forest is often better than a deep learning model because it is lightweight, less prone to "hallucinating" non-existent patterns, and can be easily re-trained on new CTF or real-world datasets using your train_model.py script.

---

## Output Files

```
theseeker_output/
├── theseeker_YYYYMMDD_HHMMSS.log   # Full scan log
├── headers.txt                      # HTTP response headers
├── index.html                       # Target homepage HTML
├── extracted_links.txt              # All hrefs/srcs found
├── js_paths.txt                     # Paths found in JS files
├── cewl_keywords.txt                # CewL scraped keywords (Cleaned)
├── combined_wordlist.txt            # Base + CewL + ML wordlist
├── ml_predicted_paths.txt           # Paths suggested by Random Forest
├── found_dirs.txt                   # Discovered paths (200/301/403)
├── redirects.txt                    # Redirect chains
└── report.html                      # Full HTML report
```
---

## ⚠️ Legal Disclaimer

TheSeeker is designed for **authorized penetration testing and CTF challenges only**.  
Only use against systems you have explicit permission to test.  
Unauthorized use may violate laws including CFAA, Computer Misuse Act, and local equivalents.

---

## Author

El majouli Yassine
Built for offensive security practice and CTF reconnaissance workflows.

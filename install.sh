#!/usr/bin/env bash
# ─────────────────────────────────────────────
#  TheSeeker — Installer
# ─────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

info()    { echo -e "${CYAN}[+]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }

echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  TheSeeker — Installer
  ─────────────────────
EOF
echo -e "${NC}"

# Check root
[[ $EUID -ne 0 ]] && warn "Not running as root. Some installs may fail."

# Detect package manager
if command -v apt-get &>/dev/null; then
  PM="apt-get"
elif command -v apt &>/dev/null; then
  PM="apt"
elif command -v yum &>/dev/null; then
  PM="yum"
elif command -v pacman &>/dev/null; then
  PM="pacman"
else
  error "Unsupported package manager. Install deps manually."
fi

info "Package manager: $PM"

# Core dependencies
DEPS=(curl jq grep sed awk ruby python3 python3-pip)
info "Installing core dependencies..."
if [[ "$PM" == "pacman" ]]; then
  $PM -S --noconfirm "${DEPS[@]}" 2>/dev/null || warn "Some packages may have failed"
else
  $PM install -y "${DEPS[@]}" 2>/dev/null || warn "Some packages may have failed"
fi

info "Installing ML dependencies via APT..."
$PM install -y python3-pandas python3-sklearn 2>/dev/null || \
  warn "APT failed. Trying pip with bypass..."

# CewL
if ! command -v cewl &>/dev/null; then
  info "Installing CewL..."
  if [[ "$PM" == "apt-get" || "$PM" == "apt" ]]; then
    $PM install -y cewl 2>/dev/null || {
      warn "CewL not in repos, installing via gem..."
      gem install cewl 2>/dev/null || warn "CewL gem install failed. Install manually."
    }
  else
    gem install cewl 2>/dev/null || warn "CewL install failed."
  fi
fi

# Wordlists
if [[ ! -f /usr/share/wordlists/dirb/common.txt ]]; then
  info "Installing wordlists (dirb)..."
  $PM install -y dirb 2>/dev/null || warn "dirb not available. Provide your own wordlist with -w"
fi

# Make TheSeeker executable and install globally
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR/theseeker.sh"

if [[ -d /usr/local/bin ]]; then
  ln -sf "$SCRIPT_DIR/theseeker.sh" /usr/local/bin/theseeker 2>/dev/null || \
    warn "Could not symlink to /usr/local/bin (try sudo)"
  success "Symlinked: theseeker → /usr/local/bin/theseeker"
fi

# Verify
echo ""
info "Checking installed tools:"
for tool in curl jq cewl ruby python3 pip3; do
  if command -v "$tool" &>/dev/null; then
    success "$tool → $(command -v $tool)"
  else
    warn "$tool NOT found"
  fi
done

echo ""
success "TheSeeker installed!"
echo -e "${BOLD}Usage:${NC}"
echo "  theseeker -u https://target.com"
echo "  theseeker -u https://target.com -m full"
echo ""


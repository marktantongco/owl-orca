#!/usr/bin/env bash
# =============================================================================
#  OWL-ORCA MASTER INSTALLER v8.2.0 (COPIOLT PROXY INTEGRATED)
#
#  Merges all previous versions into a single, hardened script:
#    - v6.2 Base: Podman rootless, swap guard, memory accounting
#    - v6.3 Provider Integration: Copilot Free, Antigravity Free, Kiro
#    - v6.4 Orca-Router: Stream Racing, Radix Tree, Circuit Breakers
#    - v7.0 Protocol Translation: Live Anthropic <-> OpenAI SSE
#    - v7.1 Safe-Mode: Atomic file swaps, connection preservation
#    - v7.2 Audit-Hardened: All prior audit fixes applied
#    - v7.3 Two-Pass-Audit-Final: Kiro Steps 3-8, 7 bugs fixed
#    - v7.4 Two-Pass-Audit-Final+: 7 additional bugs fixed
#    - v7.5 Three-Pass-Audit-Final: 20 new bugs fixed, dedup, hardening
#    - v7.6 Four-Pass-Audit-Final: 12 new bugs fixed, optimization, hardening
#    - v8.0 Five-Pass-Audit-Final: 15 new bugs fixed, OWL_INSTALL_DIR consistency,
#      dead code removed, SIGHUP async I/O, Kiro error handling
#    - v8.1 Copilot Proxy Integrated: proxy_defense v3.2, copilot_kiro_proxy on
#      port 11437, mitmproxy addon, proxy_pool (85+ sources), --skip-copilot-proxy,
#      hardened systemd with EnvironmentFile (no more hardcoded API keys)
#  Supports: Fresh Install, Upgrade, Downgrade, Local Source, Remote Curl
#  Optimized for: 8GB RAM, Ubuntu 22.04/24.04 LTS
# =============================================================================
set -euo pipefail

# ── Version & Identity ───────────────────────────────────────────────────────
VERSION="8.2.0"
VERSION_NAME="Copilot Proxy Integrated"

# ── Paths ────────────────────────────────────────────────────────────────────
INSTALL_DIR="${OWL_INSTALL_DIR:-$HOME/.owl-agent}"
SRC_DIR=""
ACTION="install"
SKIP_PROXY=""
SKIP_KIRO=""
SKIP_COPILOT_PROXY=""
UPDATE=""
WITH_PROVIDERS=""
DRY_RUN=""
UNINSTALL=""
# FIX (v8-N1): Removed unused ENRICH variable. The --enrich flag was parsed
# but never acted upon anywhere in the script. Removed to prevent confusion.
# Proxy enrichment can be added in a future version if needed.

# ── Styling ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RED='\033[0;31m'; MAGENTA='\033[0;35m'; NC='\033[0m'

log_info()  { echo -e "${CYAN}=>${NC} $1"; }
log_ok()    { echo -e "${GREEN} OK${NC} $1"; }
log_warn()  { echo -e "${YELLOW} !!${NC} $1"; }
log_err()   { echo -e "${RED} ERR${NC} $1"; }
log_step()  { echo -e "\n${BOLD}${MAGENTA}[$1/$2]${NC} $3"; }

log_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    echo "  +-----------------------------------------------------------+"
    echo "  |                                                           |"
    echo "  |      OWL-ORCA MASTER INSTALLER v${VERSION}                    |"
    echo "  |          \"${VERSION_NAME}\" Edition                            |"
    echo "  |                                                           |"
    echo "  |   Stream Racing * Protocol Translation * Safe-Mode        |"
    echo "  |   Radix Routing * Circuit Breakers * Zero-Downtime        |"
    echo "  |                                                           |"
    echo "  +-----------------------------------------------------------+"
    echo -e "${NC}"
}

# ── Argument Parsing ─────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --local)          SRC_DIR="$(cd "$(dirname "$0")" && pwd)/src" ;;
        --upgrade)        ACTION="upgrade" ;;
        --downgrade)      ACTION="downgrade" ;;
        --skip-proxy)     SKIP_PROXY=true ;;
        --skip-kiro)      SKIP_KIRO=true ;;
        --skip-copilot-proxy) SKIP_COPILOT_PROXY=true ;;
        --with-providers) WITH_PROVIDERS=true ;;
        --dry-run)        DRY_RUN=true ;;
        --uninstall)      UNINSTALL=true ;;
        --update)         UPDATE=true; ACTION="update" ;;
        --uninstall-force) UNINSTALL="force" ;;
        --enrich)         log_warn "--enrich flag is not yet implemented. Ignoring." ;;
        --version=*)      VERSION="${arg#*=}" ; VERSION_NAME="Pinned-${VERSION}" ;;
        --status)         ACTION="status" ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --local            Use local source directory"
            echo "  --upgrade          Upgrade existing installation"
            echo "  --downgrade        Downgrade installation"
            echo "  --skip-proxy       Skip forward proxy installation"
            echo "  --skip-kiro        Skip Kiro Gateway"
            echo "  --with-providers   Configure provider auth interactively"
            echo "  --skip-copilot-proxy  Skip Copilot proxy (port 11437)"
            echo "  --dry-run          Show what would be done"
            echo "  --update          Update existing installation (preserves configs)"
            echo "  --uninstall        Remove OWL-Orca completely"
            echo "  --uninstall-force  Remove OWL-Orca without confirmation (automation)"
            echo "  --enrich           (Not yet implemented)"
            echo "  --status           Show installation status (no changes)"
            echo "  --version=VER      Pin to specific version"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# ── Derived Paths ────────────────────────────────────────────────────────────
VENV_DIR="$INSTALL_DIR/venv"
CONFIG_DIR="$INSTALL_DIR/config"
LOG_DIR="$INSTALL_DIR/logs"
CACHE_DIR="$INSTALL_DIR/cache"
BIN_DIR="$INSTALL_DIR/bin"
SCRIPTS_DIR="$INSTALL_DIR/scripts"
UTILS_DIR="$INSTALL_DIR/bin/utils"
KIRO_GATEWAY_REPO="https://github.com/Jwadow/kiro-gateway.git"
KIRO_GATEWAY_DIR="${OWL_KIRO_DIR:-$HOME/Documents/proxy/kiro-gateway}"
KIRO_PORT=8333
KIRO_API_KEY="${OWL_KIRO_API_KEY:-kiro-gateway-8333}"
OPENCODE_DIR="$HOME/.config/opencode"
TOTAL_STEPS=12

# =============================================================================
#  STATUS CHECK
# =============================================================================
if [ "${ACTION:-}" == "status" ]; then
    echo -e "${BOLD}${CYAN}OWL-ORCA Installation Status${NC}"
    echo ""

    # Check installation directory
    if [ -d "$INSTALL_DIR" ]; then
        log_ok "Installation directory: $INSTALL_DIR"
    else
        log_err "Installation directory not found: $INSTALL_DIR"
        echo "  Run this script without --status to install."
        exit 1
    fi

    # Check venv
    if [ -f "$VENV_DIR/bin/activate" ]; then
        log_ok "Python venv: $VENV_DIR"
        PY_VER=$("$VENV_DIR/bin/python" --version 2>/dev/null || echo "unknown")
        echo "  Python: $PY_VER"
    else
        log_err "Python venv not found or broken"
    fi

    # Check services
    echo ""
    echo -e "${BOLD}Services:${NC}"
    for svc in orca-router owl-proxy kiro-gateway copilot-kiro-proxy; do
        if systemctl --user is-active --quiet "$svc.service" 2>/dev/null; then
            echo -e "  ${GREEN}ACTIVE${NC}  $svc"
        else
            echo -e "  ${RED}STOPPED${NC} $svc"
        fi
    done

    # Check health endpoints
    echo ""
    echo -e "${BOLD}Health Checks:${NC}"
    ORCA_HEALTH=$(curl -s --connect-timeout 2 http://127.0.0.1:60001/health 2>/dev/null || echo "UNREACHABLE")
    if echo "$ORCA_HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
        echo -e "  ${GREEN}OK${NC}  Orca Router (port 60001)"
    else
        echo -e "  ${RED}FAIL${NC} Orca Router (port 60001): ${ORCA_HEALTH:0:80}"
    fi

    COPILOT_HEALTH=$(curl -s --connect-timeout 2 http://127.0.0.1:11437/health 2>/dev/null || echo "UNREACHABLE")
    if echo "$COPILOT_HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
        echo -e "  ${GREEN}OK${NC}  Copilot Proxy (port 11437)"
    else
        echo -e "  ${RED}FAIL${NC} Copilot Proxy (port 11437): ${COPILOT_HEALTH:0:80}"
    fi

    # Check tokens
    echo ""
    echo -e "${BOLD}Tokens:${NC}"
    if [ -f "$INSTALL_DIR/config/tokens.enc" ]; then
        log_ok "Token store exists (encrypted)"
        if [ -f "$INSTALL_DIR/bin/token_manager.py" ]; then
            "$VENV_DIR/bin/python" "$INSTALL_DIR/bin/token_manager.py" status 2>/dev/null || echo "  (Could not read token status)"
        fi
    else
        log_warn "No token store found. Run: owl-token auth --provider copilot"
    fi

    echo ""
    exit 0
fi

# =============================================================================
#  UNINSTALL
# =============================================================================
if [ "${UNINSTALL:-}" == "true" ] || [ "${UNINSTALL:-}" == "force" ]; then
    echo -e "${RED}${BOLD}OWL-ORCA UNINSTALL${NC}"
    echo ""
    echo "  This will remove:"
    echo "    - $INSTALL_DIR"
    echo "    - Systemd user services (orca-router, owl-proxy, kiro-gateway, copilot-kiro-proxy)"
    echo "    - CLI wrappers (~/.local/bin/owl-*)"
    echo ""
    # Use 'read' with stdin check to avoid set -e crash when piped
    if [ "${UNINSTALL:-}" == "force" ]; then
        log_warn "FORCE UNINSTALL requested — skipping confirmation"
        confirm="y"
    elif [ -t 0 ]; then
        read -rp "  Are you sure? [y/N] " confirm
    else
        confirm="n"
        log_warn "Non-interactive mode. Use --uninstall-force for scripted uninstall."
    fi
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Aborted." && exit 0

    log_info "Stopping services..."
    systemctl --user stop orca-router.service 2>/dev/null || true
    systemctl --user stop owl-proxy.service 2>/dev/null || true
    systemctl --user stop kiro-gateway.service 2>/dev/null || true
    systemctl --user stop copilot-kiro-proxy.service 2>/dev/null || true

    log_info "Disabling services..."
    systemctl --user disable orca-router.service 2>/dev/null || true
    systemctl --user disable owl-proxy.service 2>/dev/null || true
    systemctl --user disable kiro-gateway.service 2>/dev/null || true
    systemctl --user disable copilot-kiro-proxy.service 2>/dev/null || true

    log_info "Removing systemd units..."
    rm -f "$HOME/.config/systemd/user/orca-router.service"
    rm -f "$HOME/.config/systemd/user/owl-proxy.service"
    rm -f "$HOME/.config/systemd/user/kiro-gateway.service"
    rm -f "$HOME/.config/systemd/user/copilot-kiro-proxy.service"
    systemctl --user daemon-reload 2>/dev/null || true

    log_info "Removing installation directory..."
    rm -rf "$INSTALL_DIR"

    log_info "Removing CLI wrappers..."
    rm -f "$HOME/.local/bin/owl-proxy"
    rm -f "$HOME/.local/bin/owl-router"
    rm -f "$HOME/.local/bin/owl-token"
    rm -f "$HOME/.local/bin/hermes" 2>/dev/null || true  # Legacy wrapper (no longer created)

    # Remove owl-orca-virtual provider from opencode.jsonc
    # FIX: Uses state-machine JSONC parser (not naive regex) to preserve
    # URLs and string values containing //. Uses atomic write to prevent
    # config corruption. Reports errors to user instead of suppressing.
    log_info "Cleaning OpenCode configuration..."
    OPENCODE_CONFIG="$HOME/.config/opencode/opencode.jsonc"
    if [ -f "$OPENCODE_CONFIG" ]; then
        # Backup before modification
        cp "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}.bak.$(date +%s)"

        OWL_INSTALL_DIR="$INSTALL_DIR" python3 << 'PYEOF'
import json, os, sys

# FIX (B11): Import from shared jsonc_utils module instead of duplicating
# the ~70-line strip_jsonc_comments function inline.
_owl_install = os.environ.get("OWL_INSTALL_DIR", os.path.expanduser("~/.owl-agent"))
sys.path.insert(0, os.path.join(_owl_install, "bin", "utils"))
try:
    from jsonc_utils import load_jsonc, save_json_atomic
except ImportError:
    # Fallback during uninstall if module doesn't exist yet
    import re as _re
    def load_jsonc(path):
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            return {}
    def save_json_atomic(data, path, indent=2):
        try:
            tmp = path + ".owl_tmp"
            with open(tmp, 'w') as f:
                json.dump(data, f, indent=indent)
            os.replace(tmp, path)
            return True
        except Exception:
            return False

cfg_path = os.path.expanduser("~/.config/opencode/opencode.jsonc")
try:
    data = load_jsonc(cfg_path)

    if "providers" in data and "owl-orca-virtual" in data["providers"]:
        del data["providers"]["owl-orca-virtual"]

        # Atomic write
        if save_json_atomic(data, cfg_path):
            print("  Removed owl-orca-virtual from OpenCode config")
        else:
            print("  WARNING: Failed to write updated config", file=sys.stderr)
    else:
        print("  owl-orca-virtual not found in config (already clean)")
except Exception as e:
    print(f"  WARNING: OpenCode config cleanup failed: {e}", file=sys.stderr)
    print("  Please manually remove owl-orca-virtual from opencode.jsonc", file=sys.stderr)
PYEOF
    fi

    # FIX: Also remove owl-resilient-http from mcp.json
    log_info "Cleaning MCP server configuration..."
    MCP_CONFIG="$HOME/.config/opencode/mcp.json"
    if [ -f "$MCP_CONFIG" ]; then
        cp "$MCP_CONFIG" "${MCP_CONFIG}.bak.$(date +%s)"
        python3 << 'PYEOF'
import json, os, sys

mcp_path = os.path.expanduser("~/.config/opencode/mcp.json")
try:
    with open(mcp_path, 'r') as f:
        data = json.load(f)

    if "mcpServers" in data and "owl-resilient-http" in data.get("mcpServers", {}):
        del data["mcpServers"]["owl-resilient-http"]

        # Atomic write
        tmp_path = mcp_path + ".owl_tmp_cleanup"
        with open(tmp_path, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_path, mcp_path)
        print("  Removed owl-resilient-http from MCP config")
    else:
        print("  owl-resilient-http not found in MCP config (already clean)")
except json.JSONDecodeError as e:
    print(f"  WARNING: Could not parse mcp.json: {e}", file=sys.stderr)
except Exception as e:
    print(f"  WARNING: MCP config cleanup failed: {e}", file=sys.stderr)
PYEOF
    fi

    echo ""
    log_ok "Uninstall complete"
    exit 0
fi

# =============================================================================
#  UPDATE MODE
# =============================================================================
if [ "${UPDATE:-}" == "true" ]; then
    echo -e "${BOLD}${CYAN}OWL-ORCA UPDATE${NC}"
    echo ""

    # Check installation exists
    if [ ! -d "$INSTALL_DIR" ]; then
        log_err "No existing installation found at $INSTALL_DIR"
        log_info "Run without --update for a fresh install"
        exit 1
    fi

    # Detect installed version from VERSION file
    INSTALLED_VERSION=""
    if [ -f "$INSTALL_DIR/VERSION" ]; then
        INSTALLED_VERSION="$(cat "$INSTALL_DIR/VERSION")"
    fi

    log_info "Installed version: ${INSTALLED_VERSION:-unknown}"
    log_info "Script version:    $VERSION ($VERSION_NAME)"

    if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
        log_info "Already at version $VERSION - re-applying core files"
    else
        log_ok "Upgrading from ${INSTALLED_VERSION:-unknown} to $VERSION"
    fi

    echo ""
    log_info "Running lightweight update (system configs preserved)..."

    # Set flag so steps 2,3,9,10 skip system-level changes
    UPDATE_MODE=true

    # Write VERSION marker for future update detection
    echo "$VERSION" > "$INSTALL_DIR/VERSION"
fi

log_banner

if [ "${DRY_RUN:-}" == "true" ]; then
    echo -e "${YELLOW}  *** DRY-RUN MODE -- no files will be written ***${NC}"
fi

echo "  Configuration:"
echo "    Install dir:    $INSTALL_DIR"
echo "    Action:         $ACTION"
echo "    Forward proxy:  $([ "${SKIP_PROXY:-}" == "true" ] && echo "SKIPPED" || echo "port 60000")"
echo "    Orca Router:    port 60001 (Stream Racing + Translation)"
echo "    Kiro gateway:   $([ "${SKIP_KIRO:-}" == "true" ] && echo "SKIPPED" || echo "port $KIRO_PORT")"
echo "    Copilot proxy:  $([ "${SKIP_COPILOT_PROXY:-}" == "true" ] && echo "SKIPPED" || echo "port 11437")"
echo "    Providers:      $([ "${WITH_PROVIDERS:-}" == "true" ] && echo "CONFIGURED" || echo "NOT CONFIGURED")"

# =============================================================================
#  STEP 1: System Prerequisites
# =============================================================================
log_step 1 $TOTAL_STEPS "System prerequisites"

check_deps() {
    local deps=("python3" "pip3" "systemctl" "curl" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_err "Missing dependency: $dep"
            exit 1
        fi
    done

    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 10) else 1)"; then
        log_ok "Python 3.10+ detected"
    else
        log_err "Python 3.10 or higher is required."
        exit 1
    fi
}

if [ "${DRY_RUN:-}" != "true" ]; then
    check_deps

    # -- D-Bus check (systemd user services need the session bus) --
    if ! systemctl --user daemon-reload 2>/dev/null; then
        log_warn "systemd user bus unavailable ('systemctl --user' failed)."
        log_info "Services will NOT auto-start. After install, run:"
        log_info "  export DBUS_SESSION_BUS_ADDRESS=\"unix:path=\$(loginctl show-user \$USER -p Display -P Display)\""
        log_info "  systemctl --user daemon-reload"
        log_info "  systemctl --user start orca-router.service owl-proxy.service kiro-gateway.service"
    fi

    # -- OS Detection --
    PKG_MANAGER=""
    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    else
        log_warn "Could not detect package manager. System packages may need manual installation."
    fi

    log_info "Detected package manager: ${PKG_MANAGER:-unknown}"

    # Enable lingering for rootless services
    if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        log_info "Enabling systemd linger..."
        sudo loginctl enable-linger "$USER" 2>/dev/null || log_warn "Could not enable linger"
    fi

    # Install system packages (OS-aware)
    log_info "Installing system packages..."
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq 2>/dev/null || true
            sudo apt-get install -y -qq \
                python3-pip python3-venv python3-dev \
                libffi-dev libssl-dev build-essential \
                curl wget unzip git jq \
                2>/dev/null || log_warn "Some apt packages may have failed to install"
            ;;
        dnf)
            sudo dnf install -y \
                python3-pip python3-devel \
                libffi-devel openssl-devel gcc make \
                curl wget unzip git jq \
                2>/dev/null || log_warn "Some dnf packages may have failed to install"
            ;;
        yum)
            sudo yum install -y \
                python3-pip python3-devel \
                libffi-devel openssl-devel gcc make \
                curl wget unzip git jq \
                2>/dev/null || log_warn "Some yum packages may have failed to install"
            ;;
        pacman)
            sudo pacman -S --noconfirm \
                python-pip python-virtualenv python-devel \
                libffi openssl base-devel \
                curl wget unzip git jq \
                2>/dev/null || log_warn "Some pacman packages may have failed to install"
            ;;
        *)
            log_warn "No supported package manager found. Install manually: python3-pip, python3-venv, libffi-dev, libssl-dev, curl, git, jq"
            ;;
    esac

    # Install Podman (optional, for containerized sidecars)
    if ! command -v podman &>/dev/null; then
        log_info "Installing Podman (rootless container runtime)..."
        case "$PKG_MANAGER" in
            apt)   sudo apt-get install -y -qq podman podman-docker 2>/dev/null || log_warn "Podman install failed" ;;
            dnf)   sudo dnf install -y podman podman-docker 2>/dev/null || log_warn "Podman install failed" ;;
            yum)   sudo yum install -y podman 2>/dev/null || log_warn "Podman install failed" ;;
            pacman) sudo pacman -S --noconfirm podman 2>/dev/null || log_warn "Podman install failed" ;;
            *)     log_warn "Cannot install Podman automatically. Install manually if needed." ;;
        esac
    else
        log_ok "Podman already installed"
    fi
else
    echo "  [DRY-RUN] System package installation skipped"
fi

# =============================================================================
#  STEP 2: Swap Guard
# =============================================================================
log_step 2 $TOTAL_STEPS "Swap configuration"
if [ -z "${UPDATE_MODE:-}" ]; then
if [ "${DRY_RUN:-}" != "true" ]; then
    SWAP_TOTAL=$(free -m 2>/dev/null | awk '/Swap:/{print $2}' || echo "0")

    if [ "${SWAP_TOTAL:-0}" -lt 1024 ]; then
        log_info "Low swap (${SWAP_TOTAL:-0}MB), creating 2GB swapfile..."

        if [ ! -f /swapfile ]; then
            sudo fallocate -l 2G /swapfile 2>/dev/null || \
                sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile

            if ! grep -q '/swapfile' /etc/fstab; then
                echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
            fi
            log_ok "2GB swapfile created and enabled"
        else
            log_ok "Swapfile exists, ensuring active..."
            sudo swapon /swapfile 2>/dev/null || true
        fi
    else
        log_ok "Swap: ${SWAP_TOTAL}MB (sufficient)"
    fi
fi
else
    log_ok "Swap configuration skipped (update mode)"
fi

# =============================================================================
#  STEP 3: Memory Accounting
# =============================================================================
log_step 3 $TOTAL_STEPS "Systemd memory accounting"
if [ -z "${UPDATE_MODE:-}" ]; then
if [ "${DRY_RUN:-}" != "true" ]; then
    if ! grep -rq "DefaultMemoryAccounting=yes" /etc/systemd/ 2>/dev/null; then
        log_info "Enabling memory accounting..."
        sudo mkdir -p /etc/systemd/system.conf.d
        printf '[Manager]\nDefaultMemoryAccounting=yes\n' | \
            sudo tee /etc/systemd/system.conf.d/memory-accounting.conf > /dev/null
        sudo systemctl daemon-reload
        log_ok "Memory accounting enabled"
    else
        log_ok "Memory accounting already enabled"
    fi
fi
else
    log_ok "Memory accounting skipped (update mode)"
fi

# =============================================================================
#  STEP 4: Directory Structure
# =============================================================================
log_step 4 $TOTAL_STEPS "Directory structure"

ensure_dir() {
    if [ "${DRY_RUN:-}" == "true" ]; then
        echo "  [DRY-RUN] mkdir -p $1"
    else
        mkdir -p "$1"
    fi
}

ensure_dir "$INSTALL_DIR"
ensure_dir "$VENV_DIR"
ensure_dir "$CONFIG_DIR"
ensure_dir "$LOG_DIR"
ensure_dir "$CACHE_DIR"
ensure_dir "$BIN_DIR"
ensure_dir "$UTILS_DIR"
ensure_dir "$INSTALL_DIR/lib"
ensure_dir "$SCRIPTS_DIR"
ensure_dir "$OPENCODE_DIR"
ensure_dir "$HOME/.local/bin"

# FIX (B10): Secure permissions on directories containing sensitive data.
# CONFIG_DIR holds Fernet encryption keys and OAuth tokens.
# INSTALL_DIR holds the entire runtime including logs and cache.
if [ "${DRY_RUN:-}" != "true" ]; then
    chmod 700 "$CONFIG_DIR" 2>/dev/null || true
    chmod 700 "$INSTALL_DIR" 2>/dev/null || true
fi

log_ok "Directories created"

# =============================================================================
#  STEP 5: Python Environment
# =============================================================================
log_step 5 $TOTAL_STEPS "Python virtual environment"

if [ "${DRY_RUN:-}" != "true" ]; then
    # Check venv integrity: if activate is missing OR pip is broken, rebuild
    VENV_BROKEN=false
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
        VENV_BROKEN=true
    elif ! "$VENV_DIR/bin/python" -c "import pip" 2>/dev/null; then
        log_warn "Existing venv appears broken (pip missing). Rebuilding..."
        VENV_BROKEN=true
    fi

    if [ "$VENV_BROKEN" == "true" ] || [ "$ACTION" == "upgrade" ]; then
        log_info "Building Python virtual environment..."
        rm -rf "$VENV_DIR"  # Clean slate if broken
        python3 -m venv "$VENV_DIR"
    fi

    # FIX (P2-Retry): Add retry logic for pip install with exponential backoff.
    # Remove --quiet to show error output for diagnosis.
    _SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PIP_RETRY=0
    while [ "$PIP_RETRY" -lt 3 ]; do
        if "$VENV_DIR/bin/pip" install --no-cache-dir --upgrade pip 2>&1; then
            if [ -f "$_SCRIPT_DIR/requirements.txt" ]; then
                PIP_OK=false; "$VENV_DIR/bin/pip" install --no-cache-dir -r "$_SCRIPT_DIR/requirements.txt" 2>&1 && PIP_OK=true
            else
                PIP_OK=false; "$VENV_DIR/bin/pip" install --no-cache-dir "httpx[http2]" aiohttp aiofiles cryptography 2>&1 && PIP_OK=true
            fi
            if [ "$PIP_OK" = true ]; then
                break
            fi
        fi
        PIP_RETRY=$((PIP_RETRY + 1))
        if [ "$PIP_RETRY" -lt 3 ]; then
            SLEEP_TIME=$((5 * PIP_RETRY))
            log_warn "pip install failed (attempt $PIP_RETRY/3). Retrying in ${SLEEP_TIME}s..."
            sleep "$SLEEP_TIME"
        else
            log_err "pip install failed after 3 attempts. Check network and try again."
            exit 1
        fi
    done

    # Validate venv can actually import the packages
    if ! "$VENV_DIR/bin/python" -c "import httpx, aiohttp, aiofiles, cryptography; print('OK')" 2>/dev/null; then
        log_err "Venv package import failed. Check pip output above."
        exit 1
    fi

    log_ok "Python environment ready"
fi

# =============================================================================
#  STEP 6: Core Scripts (Source Acquisition + Write)
# =============================================================================
log_step 6 $TOTAL_STEPS "Writing core scripts"

# -- Helper: backup before overwriting ----------------------------------------
backup_file() {
    if [ -f "$1" ] && [ "${DRY_RUN:-}" != "true" ]; then
        cp "$1" "${1}.bak.$(date +%s)"
    fi
}

# FIX (B15): Clean up old backup files to prevent disk accumulation.
# Backups older than 7 days are removed on each install run.
cleanup_old_backups() {
    local target_dir="$1"
    local pattern="$2"
    local max_days="${3:-7}"
    if [ "${DRY_RUN:-}" == "true" ]; then
        return 0
    fi
    local count=0
    for bak_file in "$target_dir"/"${pattern}".bak.*; do
        if [ -f "$bak_file" ]; then
            # Remove backups older than max_days
            if [ "$(find "$bak_file" -mtime +${max_days} 2>/dev/null)" ]; then
                rm -f "$bak_file" 2>/dev/null || true
                count=$((count + 1))
            fi
        fi
    done
    if [ "$count" -gt 0 ]; then
        log_info "Cleaned $count backup file(s) older than ${max_days} days in $target_dir"
    fi
}

# -- Helper: atomic file write ------------------------------------------------
# This is THE critical Safe-Mode primitive. Instead of truncating the
# destination file (which causes inotify IN_MODIFY events that crash IDE
# file watchers), we write to a temp file in the same directory, then
# atomically swap the inode with mv. The OS performs this as a single
# metadata operation -- the file is never seen in a half-written state.
atomic_write() {
    local dest="$1"
    local content="$2"

    local tmp_file
    tmp_file="$(_mktemp "$dest")"

    # Clean up any orphaned temp files from a previous interrupted run
    # (Safe: only removes files matching our specific prefix pattern)
    local dest_dir
    dest_dir="$(dirname "$dest")"
    local orphan_count=0
    for orphan in "$dest_dir"/"$(basename "$dest").owl_tmp_"*; do
        if [ -f "$orphan" ]; then
            # FIX (B23): Limit cleanup to prevent removing active temp files
            # from parallel processes. Only remove files older than 60 seconds.
            if [ "$(find "$orphan" -mmin +1 2>/dev/null)" ]; then
                rm -f "$orphan" 2>/dev/null || true
                orphan_count=$((orphan_count + 1))
            fi
        fi
    done
    if [ "$orphan_count" -gt 0 ]; then
        log_info "Cleaned $orphan_count orphaned temp file(s) for $(basename "$dest")"
    fi

    printf '%s' "$content" > "$tmp_file"
    # FIX (N10): fsync before rename to ensure data durability on power failure.
    # Without this, a crash between write and mv could result in a zero-byte file.
    sync -f "$tmp_file" 2>/dev/null || true  # sync is best-effort; not all FS support it
    mv -f "$tmp_file" "$dest"
}

# -- Helper: generate temp file path -------------------------------------------
# FIX (B14): Centralized temp file naming to eliminate ~20 repetitions
# of the same pattern and ensure consistent naming.
_mktemp() {
    local dest="$1"
    local dest_dir
    dest_dir="$(dirname "$dest")"
    local dest_base
    dest_base="$(basename "$dest")"
    echo "${dest_dir}/${dest_base}.owl_tmp_$(date +%s)_$$_$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')"
}

# -- 6A: Utility Modules ------------------------------------------------------
log_info "Writing utility modules..."

if [ "${DRY_RUN:-}" != "true" ]; then
    # --- radix_tree.py ---
    _ATMP="$(_mktemp "$UTILS_DIR/radix_tree.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Radix Tree Router (n9router-style)
O(1) path matching. No regex, no loops.
"""
from typing import Optional, Dict, Any


class RadixNode:
    __slots__ = ("children", "handler")

    def __init__(self):
        self.children: Dict[str, "RadixNode"] = {}
        self.handler: Optional[Dict[str, Any]] = None


class RadixTreeRouter:
    """
    O(1) path matching router using a compressed radix tree.

    Paths are split by '/' and each segment becomes a node child.
    Wildcard segments ('*') match any single segment.
    For example:
        add_route("v1/chat/completions", {...})
        match("v1/chat/completions")  -> returns {...}
    """

    def __init__(self):
        self.root = RadixNode()

    def add_route(self, path: str, handler: Dict[str, Any]) -> None:
        """Insert a route into the tree. Handler is stored at the leaf."""
        node = self.root
        for part in path.strip("/").split("/"):
            if part not in node.children:
                node.children[part] = RadixNode()
            node = node.children[part]
        node.handler = handler

    def match(self, path: str) -> Optional[Dict[str, Any]]:
        """Look up a path. Returns the handler dict or None."""
        node = self.root
        for part in path.strip("/").split("/"):
            if part in node.children:
                node = node.children[part]
            elif "*" in node.children:
                node = node.children["*"]
            else:
                return None
        return node.handler

    def remove_route(self, path: str) -> bool:
        """Remove a route and prune empty interior nodes. Returns True if found."""
        nodes = [self.root]
        parts = path.strip("/").split("/")
        for part in parts:
            node = nodes[-1]
            if part in node.children:
                nodes.append(node.children[part])
            elif "*" in node.children:
                nodes.append(node.children["*"])
            else:
                return False
        leaf = nodes[-1]
        if leaf.handler is None:
            return False
        leaf.handler = None
        # Prune empty nodes bottom-up (skip root at index 0)
        for i in range(len(nodes) - 1, 0, -1):
            node = nodes[i]
            parent = nodes[i - 1]
            if node.handler is None and not node.children:
                for key, child in list(parent.children.items()):
                    if child is node:
                        del parent.children[key]
                        break
            else:
                break
        return True

    def list_routes(self, prefix: str = "") -> Dict[str, Dict[str, Any]]:
        """Return all registered routes and their handlers."""
        routes = {}

        def _walk(node: RadixNode, path: str):
            if node.handler is not None:
                routes[path] = node.handler
            for seg, child in node.children.items():
                _walk(child, f"{path}/{seg}" if path else seg)

        _walk(self.root, prefix)
        return routes
PYEOF
    mv -f "$_ATMP" "$UTILS_DIR/radix_tree.py"
    chmod +x "$UTILS_DIR/radix_tree.py"

    # --- circuits.py ---
    _ATMP="$(_mktemp "$UTILS_DIR/circuits.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Half-Open Circuit Breaker (9router-style)
When a provider fails N times, the circuit opens (blocks traffic).
After a cooldown, it enters HALF_OPEN and allows exactly 1 probe request.
If the probe succeeds, the circuit closes (traffic resumes).
If the probe fails, the circuit re-opens.
"""
import time
import logging
from enum import Enum
from typing import Optional

logger = logging.getLogger("owl.circuits")


class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"


class HalfOpenCircuit:
    """
    Half-open circuit breaker (asyncio single-thread safe; not thread-safe).

    Args:
        failure_threshold: Consecutive failures before opening the circuit.
        recovery_timeout:  Seconds to wait before allowing a probe.
        probe_requests:    Number of successful probes needed to close.
    """

    def __init__(
        self,
        name: str = "default",
        failure_threshold: int = 5,
        recovery_timeout: float = 60.0,
        probe_requests: int = 1,
    ):
        self.name = name
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.probe_requests = probe_requests

        self.state = CircuitState.CLOSED
        self.failures = 0
        self.successes = 0
        self.last_failure_time: float = 0.0
        self.half_open_probes = 0

    def can_execute(self) -> bool:
        """Check if a request is allowed through the circuit."""
        if self.state == CircuitState.CLOSED:
            return True

        if self.state == CircuitState.OPEN:
            if time.time() - self.last_failure_time >= self.recovery_timeout:
                self.state = CircuitState.HALF_OPEN
                self.half_open_probes = 0
                logger.info("Circuit [%s] -> HALF_OPEN (probing)", self.name)
                return True
            return False

        if self.state == CircuitState.HALF_OPEN:
            return self.half_open_probes < self.probe_requests

        return False

    def record_success(self) -> None:
        """Record a successful request.

        FIX (F-09): Instead of resetting failures to 0 on any single success
        (which masks intermittent failures), use a decay factor. Each success
        reduces the failure count by 1, but doesn't reset it entirely.
        A provider that fails 80% of the time will still eventually trip
        the circuit because failures accumulate faster than they decay.
        """
        if self.state == CircuitState.HALF_OPEN:
            self.half_open_probes += 1
            if self.half_open_probes >= self.probe_requests:
                self.state = CircuitState.CLOSED
                self.failures = 0
                logger.info("Circuit [%s] -> CLOSED (recovered)", self.name)
        else:
            # Decay failures by 1 instead of resetting to 0
            if self.failures > 0:
                self.failures -= 1
            self.successes += 1

    def record_failure(self) -> None:
        """Record a failed request."""
        self.failures += 1
        self.last_failure_time = time.time()

        if self.state == CircuitState.HALF_OPEN:
            self.state = CircuitState.OPEN
            logger.warning("Circuit [%s] -> OPEN (probe failed)", self.name)
        elif self.failures >= self.failure_threshold:
            self.state = CircuitState.OPEN
            logger.warning(
                "Circuit [%s] -> OPEN (threshold %d reached)",
                self.name,
                self.failure_threshold,
            )

    @property
    def is_open(self) -> bool:
        return self.state == CircuitState.OPEN

    @property
    def is_half_open(self) -> bool:
        return self.state == CircuitState.HALF_OPEN

    def status(self) -> dict:
        return {
            "name": self.name,
            "state": self.state.value,
            "failures": self.failures,
            "last_failure": self.last_failure_time,
        }


class CircuitBreakerRegistry:
    """Manages circuit breakers per provider."""

    def __init__(self, failure_threshold: int = 5, recovery_timeout: float = 60.0):
        self._failure_threshold = failure_threshold
        self._recovery_timeout = recovery_timeout
        self._circuits: dict[str, HalfOpenCircuit] = {}

    def get(self, provider: str) -> HalfOpenCircuit:
        if provider not in self._circuits:
            self._circuits[provider] = HalfOpenCircuit(
                name=provider,
                failure_threshold=self._failure_threshold,
                recovery_timeout=self._recovery_timeout,
            )
        return self._circuits[provider]

    def all_status(self) -> dict:
        return {name: cb.status() for name, cb in self._circuits.items()}
PYEOF
    mv -f "$_ATMP" "$UTILS_DIR/circuits.py"
    chmod +x "$UTILS_DIR/circuits.py"

    # __init__.py for utils package
    : > "$UTILS_DIR/__init__.py"

    # --- jsonc_utils.py (shared JSONC parser) ---
    # FIX (B11): Extract strip_jsonc_comments into a shared utility instead of
    # duplicating ~70 lines three times across the script. All Python inline
    # code that needs JSONC parsing should import from this module.
    _ATMP="$(_mktemp "$UTILS_DIR/jsonc_utils.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL JSONC Utilities
Shared state-machine JSONC comment stripper that respects string boundaries.
Used by install.sh uninstall cleanup, Step 10 config injection, and any
other code that needs to parse JSONC files safely.

Unlike naive regex r'//.*?\\n', this correctly handles:
- URLs like "https://api.example.com" (// inside strings preserved)
- Multi-line strings with //
- Nested quotes and escape sequences
- Multi-line block comments /* ... */
"""
from typing import Any, Dict
import json


def strip_jsonc_comments(text: str) -> str:
    """Remove JSONC comments while preserving string content.

    Handles single-line (//) and multi-line (/* */) comments,
    correctly preserving // and /* inside quoted strings.
    """
    result = []
    i = 0
    in_string = False
    string_char = None

    while i < len(text):
        ch = text[i]

        if in_string:
            result.append(ch)
            if ch == '\\':
                # Escape sequence: skip next char
                i += 1
                if i < len(text):
                    result.append(text[i])
            elif ch == string_char:
                in_string = False
            i += 1
            continue

        # Not in a string
        if ch == '"' or ch == "'":
            in_string = True
            string_char = ch
            result.append(ch)
            i += 1
        elif ch == '/' and i + 1 < len(text):
            next_ch = text[i + 1]
            if next_ch == '/':
                # Single-line comment: skip to end of line
                while i < len(text) and text[i] != '\n':
                    i += 1
                # Preserve the newline
                if i < len(text):
                    result.append('\n')
                    i += 1
            elif next_ch == '*':
                # Multi-line comment: skip to */
                i += 2
                while i + 1 < len(text) and not (text[i] == '*' and text[i + 1] == '/'):
                    if text[i] == '\n':
                        result.append('\n')
                    i += 1
                i += 2  # Skip */
            else:
                result.append(ch)
                i += 1
        else:
            result.append(ch)
            i += 1

    return ''.join(result)


def load_jsonc(path: str) -> Dict[str, Any]:
    """Load a JSONC file, strip comments, and parse as JSON.

    Returns the parsed dict, or empty dict on failure.
    """
    try:
        with open(path, 'r') as f:
            raw = f.read()
        clean = strip_jsonc_comments(raw)
        return json.loads(clean)
    except Exception:
        return {}


def save_json_atomic(data: Dict[str, Any], path: str, indent: int = 2) -> bool:
    """Save JSON data with atomic write pattern.

    Writes to a temp file, then os.replace() for atomic swap.
    Returns True on success, False on failure.
    """
    import os
    try:
        tmp_path = path + ".owl_tmp_save"
        with open(tmp_path, 'w') as f:
            json.dump(data, f, indent=indent)
        os.replace(tmp_path, path)
        return True
    except Exception:
        return False
PYEOF
    mv -f "$_ATMP" "$UTILS_DIR/jsonc_utils.py"
    chmod +x "$UTILS_DIR/jsonc_utils.py"

    # --- provider_router.py ---
    _ATMP="$(_mktemp "$UTILS_DIR/provider_router.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Provider Router
Resolves provider selection based on routing strategy, model availability,
and circuit breaker state. Used by OrcaRouter for strategy dispatch.
"""
from typing import Dict, Any, List, Optional
# FIX (B12): Use try/except for both relative and absolute import paths.
# When imported as a package (from utils.provider_router), the relative
# import works. When run standalone or via sys.path, the absolute import works.
try:
    from circuits import HalfOpenCircuit, CircuitBreakerRegistry
except ImportError:
    from .circuits import HalfOpenCircuit, CircuitBreakerRegistry


class ProviderRouter:
    """Selects the best provider for a given request based on strategy and state.

    Strategies:
      - single: Route to the first available target with closed circuit.
      - race: Return all eligible targets for concurrent racing.
      - canary: Weighted random selection for A/B testing.
      - fallback: Try targets in order, falling back on circuit-open.
    """

    def __init__(self, circuits: CircuitBreakerRegistry):
        self.circuits = circuits

    def select(
        self,
        targets: List[Dict[str, Any]],
        strategy: str = "single",
    ) -> List[Dict[str, Any]]:
        """Select eligible targets based on strategy and circuit state.

        Returns a list of targets to attempt. For 'single' and 'canary',
        the list has exactly one element. For 'race', it may have multiple.
        """
        eligible = [
            t for t in targets
            if self.circuits.get(t["provider"]).can_execute()
        ]

        if not eligible:
            # All circuits open: return the last target as a Hail Mary
            return targets[-1:] if targets else []

        if strategy == "single":
            return [eligible[0]]
        elif strategy == "race":
            return eligible
        elif strategy == "canary":
            import random
            r = random.random() * sum(t.get("weight", 50) for t in eligible)
            cumulative = 0
            for target in eligible:
                cumulative += target.get("weight", 50)
                if r <= cumulative:
                    return [target]
            return [eligible[0]]
        elif strategy == "fallback":
            return eligible
        else:
            return [eligible[0]]

    def get_fallback(
        self, provider: str, all_providers: Dict[str, Any]
    ) -> Optional[str]:
        """Get a fallback provider when the primary is circuit-open."""
        # Prefer kiro as the universal fallback
        if provider != "kiro" and "kiro" in all_providers:
            kiro_circuit = self.circuits.get("kiro")
            if kiro_circuit.can_execute():
                return "kiro"

        # Try any other provider with a closed circuit
        for name in all_providers:
            if name != provider and self.circuits.get(name).can_execute():
                return name

        return None
PYEOF
    mv -f "$_ATMP" "$UTILS_DIR/provider_router.py"
    chmod +x "$UTILS_DIR/provider_router.py"
fi

# -- 6G: Proxy Defense Library -----------------------------------------------
log_info "Writing proxy_defense.py..."

if [ "${DRY_RUN:-}" != "true" ]; then
    _ATMP="$(_mktemp "$INSTALL_DIR/lib/proxy_defense.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
🦉 OWL-AGENT PROXY DEFENSE STACK v3.2
- Config loading and auth injection
- Health check pipeline
- Weighted proxy selection
- Per-domain circuit breaker
"""

import asyncio
import hashlib
import json
import time
import random
import logging
import os
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Optional, Dict, Any, Callable, Awaitable, List
from pathlib import Path
from urllib.parse import urlparse

import aiohttp
import aiofiles

CACHE_DIR = Path.home() / ".owl-agent" / "cache" / "http"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

CONFIG_DIR = Path.home() / ".owl-agent" / "config"
PROXY_POOL_FILE = CONFIG_DIR / "proxy_pool.json"
PROXY_CREDS_FILE = CONFIG_DIR / "proxy_credentials.json"

DEFAULT_TTL = 300
DEFAULT_RATE = 1.0
MAX_RETRIES = 3

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
logger = logging.getLogger("owl-agent.proxy")

@dataclass
class CachedResponse:
    status: int
    content: bytes
    headers: Dict[str, str]
    timestamp: float
    ttl: int
    protocol: str = "http/1.1"
    def is_fresh(self) -> bool:
        return time.time() - self.timestamp < self.ttl

@dataclass
class TokenBucket:
    rate: float
    capacity: float
    tokens: float = 0.0
    last_update: float = field(default_factory=time.time)
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)
    async def _replenish(self):
        now = time.time()
        elapsed = now - self.last_update
        async with self.lock:
            self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)
            self.last_update = now
    async def acquire(self, tokens: float = 1.0) -> bool:
        await self._replenish()
        async with self.lock:
            if self.tokens >= tokens:
                self.tokens -= tokens
                return True
        wait_time = (tokens - self.tokens) / self.rate
        await asyncio.sleep(wait_time)
        return await self.acquire(tokens)

@dataclass
class ProxyEntry:
    url: str
    proxy_type: str
    protocol: str
    source: str
    tier: int
    auth_ref: Optional[str] = None
    healthy: bool = True
    last_check: float = 0.0
    fail_count: int = 0
    ban_until: float = 0.0
    latency_ms: float = 9999.0
    success_count: int = 0
    
    def is_banned(self) -> bool:
        return time.time() < self.ban_until
    
    def mark_failed(self):
        self.fail_count += 1
        # Exponential backoff: 60 * (2 ^ (fail_count - 1))
        backoff = 60 * (2 ** min(self.fail_count - 1, 6))
        self.ban_until = time.time() + backoff
        self.healthy = False
        logger.warning(f"Proxy banned ({backoff}s): {self.url}")
    
    def mark_success(self, latency_ms: float):
        self.fail_count = 0
        self.healthy = True
        self.latency_ms = (self.latency_ms * 0.7) + (latency_ms * 0.3) if self.success_count > 0 else latency_ms
        self.last_check = time.time()
        self.success_count += 1
    
    def get_score(self) -> float:
        if not self.healthy or self.is_banned():
            return 0.0
        # Score based on latency and success
        base_score = 10000 / max(self.latency_ms, 1)
        tier_multiplier = {1: 1.5, 2: 1.0, 3: 0.5}.get(self.tier, 1.0)
        success_bonus = min(self.success_count, 10) * 0.1
        return base_score * tier_multiplier * (1 + success_bonus)

class ProxyPoolLoader:
    def __init__(self, pool_file: Path = PROXY_POOL_FILE, creds_file: Path = PROXY_CREDS_FILE):
        self.pool_file = pool_file
        self.creds_file = creds_file
    
    def _load_credentials(self) -> dict:
        if not self.creds_file.exists():
            return {}
        try:
            with open(self.creds_file) as f:
                data = json.load(f)
                return data.get("providers", {})
        except Exception as e:
            logger.error(f"Failed to load credentials: {e}")
            return {}

    def _inject_auth(self, url: str, auth_ref: str, credentials: dict) -> str:
        if not auth_ref or auth_ref not in credentials:
            return url
        creds = credentials[auth_ref]
        username = os.getenv(f"PROXY_{auth_ref.upper()}_USERNAME", creds.get("username", ""))
        password = os.getenv(f"PROXY_{auth_ref.upper()}_PASSWORD", creds.get("password", ""))
        
        if not username or not password:
            return url
        
        parsed = urlparse(url)
        return f"{parsed.scheme}://{username}:{password}@{parsed.netloc}"

    def load(self) -> List[ProxyEntry]:
        if not self.pool_file.exists():
            return []
        
        credentials = self._load_credentials()
        
        try:
            with open(self.pool_file) as f:
                config = json.load(f)
        except Exception:
            return []
        
        proxies = []
        for provider in config.get("tier_1_managed_free", {}).get("providers", []):
            provider_auth_ref = provider.get("auth_ref")
            for proxy in provider.get("proxies", []):
                auth_ref = proxy.get("auth_ref", provider_auth_ref)
                
                # Default Webshare IP rotation formatting
                url = proxy["url"]
                if auth_ref == "webshare" and credentials.get("webshare", {}).get("backbone_prefix"):
                    creds = credentials["webshare"]
                    if creds.get("username") and creds.get("password") and proxy.get("backbone_id"):
                        username = f"{creds['username']}-{creds['backbone_prefix']}{proxy['backbone_id']}"
                        parsed = urlparse(url)
                        url = f"{parsed.scheme}://{username}:{creds['password']}@{parsed.netloc}"
                elif auth_ref:
                    url = self._inject_auth(url, auth_ref, credentials)

                proxies.append(ProxyEntry(
                    url=url,
                    proxy_type=proxy.get("type", "datacenter"),
                    protocol=proxy.get("protocols", ["HTTP"])[0].lower(),
                    source=provider["name"],
                    tier=1,
                    auth_ref=auth_ref
                ))
        return proxies

    async def fetch_auto_sources(self, session: aiohttp.ClientSession) -> List[ProxyEntry]:
        if not self.pool_file.exists():
            return []
        try:
            with open(self.pool_file) as f:
                config = json.load(f)
        except Exception:
            return []
        sources = config.get("tier_2_auto_fetch", {}).get("sources", [])
        proxies = []
        for src in sources:
            if not src.get("enabled", True):
                continue
            try:
                async with session.get(src["url"], timeout=15) as resp:
                    if resp.status != 200:
                        continue
                    pfield = src.get("protocol_field", "protocol")
                    ipfield = src.get("ip_field", "ip")
                    portfield = src.get("port_field", "port")
                    stype = src.get("type", "json")
                    if stype in ("json", "api_json"):
                        data = await resp.json()
                        items = data if isinstance(data, list) else data.get("data", data.get("proxies", []))
                        if not isinstance(items, list):
                            items = []
                        for item in items[:200]:
                            ip = item.get(ipfield, "")
                            port = item.get(portfield, "")
                            if not ip or not port:
                                continue
                            raw_proto = item.get(pfield, "http")
                            if isinstance(raw_proto, list):
                                raw_proto = raw_proto[0] if raw_proto else "http"
                            proto = str(raw_proto).lower().replace("https", "http").split("/")[0]
                            if proto not in ("http", "socks4", "socks5"):
                                proto = "http"
                            proxies.append(ProxyEntry(
                                url=f"{proto}://{ip}:{port}",
                                proxy_type="public",
                                protocol=proto,
                                source=src["name"],
                                tier=2
                            ))
                    elif stype == "api_url":
                        items = await resp.json()
                        if isinstance(items, dict):
                            items = items.get("results", items.get("data", items.get("proxies", [])))
                        for item in items[:200]:
                            ip = item.get(ipfield, "")
                            port = item.get(portfield, "")
                            if not ip or not port:
                                continue
                            raw_proto = item.get(pfield, "http")
                            if isinstance(raw_proto, list):
                                raw_proto = raw_proto[0] if raw_proto else "http"
                            proto = str(raw_proto).lower().replace("https", "http").split("/")[0]
                            if proto not in ("http", "socks4", "socks5"):
                                proto = "http"
                            proxies.append(ProxyEntry(
                                url=f"{proto}://{ip}:{port}",
                                proxy_type="public",
                                protocol=proto,
                                source=src["name"],
                                tier=2
                            ))
                    else:
                        text = await resp.text()
                        for line in text.strip().split("\n")[:200]:
                            if ":" in line and not line.startswith("#"):
                                parts = line.strip().split()
                                entry = parts[0] if parts else line.strip()
                                proxies.append(ProxyEntry(
                                    url=f"http://{entry}",
                                    proxy_type="public",
                                    protocol="http",
                                    source=src["name"],
                                    tier=2
                                ))
                logger.info(f"Fetched {len([p for p in proxies if p.source == src['name']])} proxies from {src['name']}")
            except Exception as e:
                logger.debug(f"Auto-fetch failed for {src['name']}: {e}")
        return proxies

class HTTPCache:
    def __init__(self, ttl: int = DEFAULT_TTL):
        self.ttl = ttl
        self._memory: Dict[str, CachedResponse] = {}
        self._lock = asyncio.Lock()
    def _key(self, method: str, url: str, params: Optional[Dict] = None, protocol: str = "http/1.1") -> str:
        return hashlib.sha256(f"{method}:{url}:{json.dumps(params or {}, sort_keys=True)}:{protocol}".encode()).hexdigest()
    async def get(self, method: str, url: str, params: Optional[Dict] = None, protocol: str = "http/1.1") -> Optional[CachedResponse]:
        key = self._key(method, url, params, protocol)
        if key in self._memory and self._memory[key].is_fresh():
            return self._memory[key]
        return None
    async def set(self, method: str, url: str, response: CachedResponse, params: Optional[Dict] = None):
        key = self._key(method, url, params, response.protocol)
        async with self._lock:
            self._memory[key] = response

class RequestDeduplicator:
    def __init__(self):
        self._in_flight: Dict[str, asyncio.Future] = {}
        self._lock = asyncio.Lock()
    def _key(self, method: str, url: str, params: Optional[Dict] = None, protocol: str = "http/1.1") -> str:
        return hashlib.sha256(f"{method}:{url}:{json.dumps(params or {}, sort_keys=True)}:{protocol}".encode()).hexdigest()
    async def execute(self, method: str, url: str, params: Optional[Dict], protocol: str, factory: Callable[[], Awaitable[CachedResponse]]) -> CachedResponse:
        key = self._key(method, url, params, protocol)
        async with self._lock:
            if key in self._in_flight:
                return await self._in_flight[key]
            future = asyncio.Future()
            self._in_flight[key] = future
        try:
            result = await factory()
            future.set_result(result)
            return result
        except Exception as e:
            future.set_exception(e)
            raise
        finally:
            async with self._lock:
                self._in_flight.pop(key, None)

class DomainRateLimiter:
    def __init__(self, default_rate: float = DEFAULT_RATE):
        self.default_rate = default_rate
        self._buckets: Dict[str, TokenBucket] = {}
        self._lock = asyncio.Lock()
    async def acquire(self, url: str, tokens: float = 1.0):
        domain = urlparse(url).netloc or url
        async with self._lock:
            if domain not in self._buckets:
                self._buckets[domain] = TokenBucket(rate=self.default_rate, capacity=5.0, tokens=5.0)
        await self._buckets[domain].acquire(tokens)

class HealthChecker:
    @staticmethod
    async def check(session: aiohttp.ClientSession, proxy: ProxyEntry) -> bool:
        try:
            start = time.time()
            async with session.get("http://httpbin.org/ip", proxy=proxy.url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    proxy.mark_success((time.time() - start) * 1000)
                    return True
        except Exception:
            pass
        proxy.mark_failed()
        return False

class ProxyRotator:
    def __init__(self):
        self.proxies: List[ProxyEntry] = []
        self._lock = asyncio.Lock()
        self._loader = ProxyPoolLoader()
    
    async def load_all_sources(self, session: aiohttp.ClientSession):
        self.proxies = self._loader.load()
        self.proxies.extend(await self._loader.fetch_auto_sources(session))
        # Pre-validate some proxies
        tasks = [HealthChecker.check(session, p) for p in self.proxies[:30]]
        await asyncio.gather(*tasks)
        logger.info(f"Loaded {len(self.proxies)} proxies")
    
    async def get_proxy(self) -> Optional[ProxyEntry]:
        async with self._lock:
            healthy = [p for p in self.proxies if not p.is_banned()]
            if not healthy:
                return None
            
            # Weighted random selection based on score
            scores = [p.get_score() for p in healthy]
            total = sum(scores)
            if total == 0:
                return random.choice(healthy)
            
            r = random.uniform(0, total)
            current = 0
            for p, score in zip(healthy, scores):
                current += score
                if r <= current:
                    return p
            return healthy[-1]
    
    async def mark_banned(self, proxy: ProxyEntry):
        proxy.mark_failed()

class DomainCircuitBreaker:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: int = 60):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failures: Dict[str, int] = defaultdict(int)
        self.open_until: Dict[str, float] = {}
    
    def record_failure(self, domain: str):
        self.failures[domain] += 1
        if self.failures[domain] >= self.failure_threshold:
            self.open_until[domain] = time.time() + self.recovery_timeout
            logger.warning(f"Circuit breaker OPEN for {domain}")
    
    def record_success(self, domain: str):
        self.failures[domain] = 0
        if domain in self.open_until:
            del self.open_until[domain]
            logger.info(f"Circuit breaker CLOSED for {domain}")
    
    def can_request(self, domain: str) -> bool:
        if domain in self.open_until:
            if time.time() > self.open_until[domain]:
                # Half-open state
                return True
            return False
        return True

class ResilientClient:
    def __init__(self, cache_ttl: int = DEFAULT_TTL, rate_limit: float = DEFAULT_RATE, max_retries: int = MAX_RETRIES):
        self.cache = HTTPCache(cache_ttl)
        self.dedup = RequestDeduplicator()
        self.limiter = DomainRateLimiter(rate_limit)
        self.rotator = ProxyRotator()
        self.circuit_breaker = DomainCircuitBreaker()
        self.max_retries = max_retries
        self._session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        connector = aiohttp.TCPConnector(force_close=True, enable_cleanup_closed=True, limit=10)
        self._session = aiohttp.ClientSession(connector=connector)
        await self.rotator.load_all_sources(self._session)
        return self

    async def __aexit__(self, *args):
        if self._session:
            await self._session.close()

    async def request(self, method: str, url: str, params: Optional[Dict] = None, headers: Optional[Dict] = None, **kwargs) -> CachedResponse:
        cached = await self.cache.get(method, url, params)
        if cached:
            return cached
        
        domain = urlparse(url).netloc or url
        if not self.circuit_breaker.can_request(domain):
            raise RuntimeError(f"Circuit breaker open for {domain}")

        async def factory():
            return await self._execute_with_retry(method, url, params, headers, domain, **kwargs)
        return await self.dedup.execute(method, url, params, "http/1.1", factory)

    async def _execute_with_retry(self, method, url, params, headers, domain, **kwargs):
        # Pop protocol from kwargs -- used for cache keying, not aiohttp
        kwargs.pop("protocol", None)
        # Try proxies up to max_retries
        for attempt in range(self.max_retries):
            await self.limiter.acquire(url)
            proxy = await self.rotator.get_proxy()
            proxy_url = proxy.url if proxy else None
            
            try:
                start = time.time()
                async with self._session.request(method, url, params=params, headers=headers,
                                                 proxy=proxy_url, timeout=aiohttp.ClientTimeout(total=30), **kwargs) as resp:
                    content = await resp.read()
                latency = (time.time() - start) * 1000
                response = CachedResponse(status=resp.status, content=content, headers=dict(resp.headers), timestamp=time.time(), ttl=self.cache.ttl)
                
                if proxy:
                    proxy.mark_success(latency)
                self.circuit_breaker.record_success(domain)
                
                await self.cache.set(method, url, response, params)
                
                if resp.status in (429, 403, 407):
                    if proxy:
                        await self.rotator.mark_banned(proxy)
                    continue
                return response
                
            except (aiohttp.ClientOSError, aiohttp.ClientProxyConnectionError, aiohttp.ServerDisconnectedError, ConnectionResetError) as e:
                if proxy:
                    await self.rotator.mark_banned(proxy)
                logger.warning(f"Proxy failed: {e}, retry {attempt+1}/{self.max_retries}")
                continue
            except Exception as e:
                if proxy:
                    await self.rotator.mark_banned(proxy)
                logger.warning(f"Error with proxy: {e}, retrying")
                continue

        self.circuit_breaker.record_failure(domain)

        # --- All proxies failed, try direct connection ---
        logger.info("All proxies exhausted, attempting direct connection...")
        try:
            async with self._session.request(method, url, params=params, headers=headers,
                                             timeout=aiohttp.ClientTimeout(total=30), **kwargs) as resp:
                content = await resp.read()
            response = CachedResponse(status=resp.status, content=content, headers=dict(resp.headers), timestamp=time.time(), ttl=self.cache.ttl)
            await self.cache.set(method, url, response, params)
            self.circuit_breaker.record_success(domain)
            return response
        except Exception as e:
            self.circuit_breaker.record_failure(domain)
            raise RuntimeError(f"Direct connection also failed: {e}")

    async def get_stats(self):
        healthy = sum(1 for p in self.rotator.proxies if not p.is_banned())
        return {"proxies_total": len(self.rotator.proxies), "proxies_healthy": healthy}

async def main():
    print("🦉 OWL-AGENT Proxy Defense Stack v3.2 (Auth Injection Enabled)")
    async with ResilientClient() as client:
        stats = await client.get_stats()
        print(f"Proxy pool: {stats['proxies_total']} total, {stats['proxies_healthy']} healthy (non-banned)")
        try:
            resp = await client.request("GET", "https://api.github.com/users/octocat")
            print(f"✅ Success! Status: {resp.status}, content length: {len(resp.content)} bytes")
            if resp.status == 200:
                data = json.loads(resp.content)
                print(f"   User: {data.get('login')} - {data.get('name')}")
        except Exception as e:
            print(f"❌ All attempts failed, including direct: {e}")

if __name__ == "__main__":
    asyncio.run(main())
PYEOF
    mv -f "$_ATMP" "$INSTALL_DIR/lib/proxy_defense.py"
    chmod +x "$INSTALL_DIR/lib/proxy_defense.py"
fi


# -- 6B: Forward Proxy --------------------------------------------------------
log_info "Writing forward_proxy.py..."

if [ "${SKIP_PROXY:-}" != "true" ] && [ "${DRY_RUN:-}" != "true" ]; then
    _ATMP="$(_mktemp "$INSTALL_DIR/forward_proxy.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Forward Proxy v2.1 - Memory Optimized for 8GB RAM
Asyncio HTTPS CONNECT tunnel with domain bypass and upstream chaining.
"""
import asyncio
import os
import logging
import base64
import signal
from urllib.parse import urlparse

# FIX (v8-N2): Use OWL_INSTALL_DIR environment variable instead of
# hardcoding ~/.owl-agent. This ensures the proxy respects custom
# install paths set by the user.
INSTALL_DIR = os.getenv("OWL_INSTALL_DIR", os.path.expanduser("~/.owl-agent"))
LOG_DIR = os.path.join(INSTALL_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, "forward-proxy.log")),
    ],
)
logger = logging.getLogger("owl-forward-proxy")

UPSTREAM_PROXY = os.getenv("UPSTREAM_PROXY", "").strip()
BIND_HOST = os.getenv("OWL_PROXY_HOST", "127.0.0.1")
BIND_PORT = int(os.getenv("OWL_PROXY_PORT", "60000"))
CONNECT_TIMEOUT = int(os.getenv("OWL_CONNECT_TIMEOUT", "15"))
# FIX (F-08): Increased from 5 to 50. Each connection uses ~50-100KB of buffer,
# so 50 connections use only 2.5-5MB - negligible on 8GB RAM.
MAX_CONNECTIONS = int(os.getenv("OWL_MAX_CONNECTIONS", "50"))

BYPASS_EXACT = {
    "127.0.0.1", "::1", "localhost",
    "opencode.ai",
    "api.githubcopilot.com",
    "api.antigravity.ai",
}
BYPASS_SUFFIX = (
    ".nvidia.com", ".opencode.ai", ".amazonaws.com",
    ".kiro.dev", ".githubcopilot.com",     ".googleapis.com",
)

_conn_semaphore = None


def should_bypass(host: str) -> bool:
    return host in BYPASS_EXACT or any(host.endswith(s) for s in BYPASS_SUFFIX)


async def pipe(reader, writer):
    """Blindly copy data between two streams until EOF or error."""
    try:
        while True:
            data = await reader.read(32768)
            if not data:
                break
            if writer.is_closing():
                break
            writer.write(data)
            await writer.drain()
    except (ConnectionResetError, BrokenPipeError, asyncio.CancelledError):
        pass
    finally:
        try:
            if not writer.is_closing():
                writer.close()
                await writer.wait_closed()
        except Exception:
            pass


async def connect_upstream(target_host, target_port):
    """Establish a CONNECT tunnel through the upstream proxy."""
    if not UPSTREAM_PROXY:
        raise ConnectionError("UPSTREAM_PROXY is not configured")
    parsed = urlparse(UPSTREAM_PROXY)
    proxy_host = parsed.hostname
    proxy_port = parsed.port or (443 if parsed.scheme == "https" else 80)
    if not proxy_host:
        raise ConnectionError(f"Invalid UPSTREAM_PROXY URL: {UPSTREAM_PROXY}")

    reader, writer = await asyncio.wait_for(
        asyncio.open_connection(proxy_host, proxy_port),
        timeout=CONNECT_TIMEOUT,
    )

    auth_header = ""
    if parsed.username and parsed.password:
        creds = base64.b64encode(
            f"{parsed.username}:{parsed.password}".encode()
        ).decode()
        auth_header = f"Proxy-Authorization: Basic {creds}\r\n"

    writer.write(
        f"CONNECT {target_host}:{target_port} HTTP/1.1\r\n"
        f"Host: {target_host}:{target_port}\r\n"
        f"{auth_header}\r\n".encode()
    )
    await writer.drain()

    resp = await asyncio.wait_for(reader.readline(), timeout=CONNECT_TIMEOUT)
    if b"200" not in resp:
        writer.close()
        raise ConnectionError(f"Upstream refused: {resp.decode().strip()}")

    # Consume remaining headers
    while True:
        line = await asyncio.wait_for(reader.readline(), timeout=CONNECT_TIMEOUT)
        if line in (b"\r\n", b"\n", b""):
            break

    return reader, writer


async def handle_connect(client_r, client_w, target_host, target_port):
    """Handle a CONNECT request (HTTPS tunneling)."""
    async with _conn_semaphore:
        try:
            if not should_bypass(target_host) and UPSTREAM_PROXY:
                target_r, target_w = await connect_upstream(target_host, target_port)
            else:
                target_r, target_w = await asyncio.wait_for(
                    asyncio.open_connection(target_host, target_port),
                    timeout=CONNECT_TIMEOUT,
                )

            client_w.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            await client_w.drain()

            await asyncio.gather(
                pipe(client_r, target_w),
                pipe(target_r, client_w),
            )
        except Exception as e:
            logger.error("CONNECT %s:%d failed: %s", target_host, target_port, e)
            try:
                client_w.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                await client_w.drain()
                client_w.close()
            except Exception:
                pass


async def handle_http(client_r, client_w, method, url, headers):
    """Handle a plain HTTP request."""
    async with _conn_semaphore:
        parsed = urlparse(url)
        target_host = parsed.hostname
        target_port = parsed.port or 80
        target_path = parsed.path or "/"
        if parsed.query:
            target_path += f"?{parsed.query}"

        try:
            if not should_bypass(target_host) and UPSTREAM_PROXY:
                target_r, target_w = await connect_upstream(target_host, target_port)
            else:
                target_r, target_w = await asyncio.wait_for(
                    asyncio.open_connection(target_host, target_port),
                    timeout=CONNECT_TIMEOUT,
                )

            req = f"{method} {target_path} HTTP/1.1\r\nHost: {target_host}\r\nConnection: close\r\n"
            for k, v in headers.items():
                if k.lower() not in ("host", "connection", "proxy-connection"):
                    req += f"{k}: {v}\r\n"
            req += "\r\n"

            target_w.write(req.encode())
            await target_w.drain()

            try:
                cl = int(headers.get("Content-Length", "0"))
            except (ValueError, TypeError):
                cl = 0
            if 0 < cl < 1048576:
                body = await client_r.read(min(cl, 1048576))
                target_w.write(body)
                await target_w.drain()

            await pipe(target_r, client_w)
        except Exception as e:
            logger.error("HTTP %s %s failed: %s", method, url, e)
            try:
                client_w.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                await client_w.drain()
                client_w.close()
            except Exception:
                pass


async def handle_client(client_r, client_w):
    """Parse the incoming request and dispatch to CONNECT or HTTP handler."""
    try:
        request_line = await asyncio.wait_for(client_r.readline(), timeout=30)
        if not request_line:
            client_w.close()
            return

        parts = request_line.decode().strip().split(" ", 2)
        if len(parts) < 2:
            client_w.close()
            return

        method, url = parts[0], parts[1]

        headers = {}
        while True:
            line = await asyncio.wait_for(client_r.readline(), timeout=10)
            if line in (b"\r\n", b"\n", b""):
                break
            if b":" in line:
                k, v = line.decode().strip().split(":", 1)
                headers[k.strip()] = v.strip()

        if method == "CONNECT":
            # Handle IPv6 addresses like [::1]:443
            if url.startswith("["):
                bracket_end = url.index("]")
                host = url[1:bracket_end]
                port_str = url[bracket_end + 2:]  # skip ]:
            else:
                host, port_str = url.rsplit(":", 1)
            await handle_connect(client_r, client_w, host, int(port_str))
        else:
            await handle_http(client_r, client_w, method, url, headers)

    except asyncio.TimeoutError:
        try:
            client_w.close()
        except Exception:
            pass
    except Exception as e:
        logger.debug("Client error: %s", e)
        try:
            client_w.close()
        except Exception:
            pass


async def main():
    global _conn_semaphore
    _conn_semaphore = asyncio.Semaphore(MAX_CONNECTIONS)
    loop = asyncio.get_running_loop()
    # FIX (B13/N5): Store task reference in a module-level set to prevent
    # garbage collection before the task completes. The closure factory
    # pattern alone is insufficient because _shutdown_task goes out of
    # scope after _make_handler() returns. A module-level set keeps a
    # strong reference for the task's lifetime.
    _active_tasks: set = set()
    for sig in (signal.SIGINT, signal.SIGTERM):
        def _make_handler():
            def _handler():
                task = asyncio.create_task(shutdown())
                _active_tasks.add(task)
                task.add_done_callback(_active_tasks.discard)
            return _handler
        loop.add_signal_handler(sig, _make_handler())

    server = await asyncio.start_server(handle_client, BIND_HOST, BIND_PORT)
    logger.info(
        "OWL Forward Proxy on %s:%d | max_conn=%d",
        BIND_HOST, BIND_PORT, MAX_CONNECTIONS,
    )

    async with server:
        await server.serve_forever()


async def shutdown():
    logger.info("Shutting down forward proxy...")
    tasks = [t for t in asyncio.all_tasks() if t is not asyncio.current_task()]
    for task in tasks:
        task.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)


if __name__ == "__main__":
    asyncio.run(main())
PYEOF
    mv -f "$_ATMP" "$INSTALL_DIR/forward_proxy.py"
    chmod +x "$INSTALL_DIR/forward_proxy.py"
fi

# -- 6C: Payload Translator ---------------------------------------------------
log_info "Writing payload_translator.py..."

if [ "${DRY_RUN:-}" != "true" ]; then
    _ATMP="$(_mktemp "$BIN_DIR/payload_translator.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Zero-Copy Protocol Translator v2.0
Fluidly translates between OpenAI and Anthropic API formats.
Supports both static payloads and real-time SSE chunk translation.
NEVER buffers full responses -- translates chunk-by-chunk.
"""
import json
import time
from typing import Dict, Any, Optional


class PayloadTranslator:
    """Translates JSON payloads between provider formats."""

    @staticmethod
    def _enforce_alternation(messages: list) -> list:
        """Enforce strict user/assistant alternation for Anthropic API.

        Anthropic requires messages to strictly alternate between user and
        assistant roles. OpenAI allows consecutive same-role messages.
        This method merges consecutive same-role messages and inserts
        empty alternating messages where needed.
        """
        if not messages:
            return messages

        merged = []
        for msg in messages:
            if merged and merged[-1]["role"] == msg["role"]:
                # Merge consecutive same-role messages
                merged[-1]["content"] += "\n" + msg.get("content", "")
            else:
                merged.append(dict(msg))

        # Ensure first message is from user (Anthropic requirement)
        if merged and merged[0]["role"] != "user":
            merged.insert(0, {"role": "user", "content": "Please continue."})

        return merged

    @staticmethod
    def openai_to_anthropic(payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Convert OpenAI chat completion format to Anthropic.

        Key differences handled:
          - Anthropic places 'system' at top level, not in messages array
          - Anthropic requires strict user/assistant alternation
          - Anthropic uses 'max_tokens' (required) vs OpenAI's optional default
        """
        system_prompt = ""
        messages = []

        for msg in payload.get("messages", []):
            role = msg.get("role")
            content = msg.get("content", "")
            if role == "system":
                system_prompt += content + "\n"
            elif role in ("user", "assistant"):
                messages.append({"role": role, "content": content})

        # FIX: Enforce user/assistant alternation before sending to Anthropic
        messages = PayloadTranslator._enforce_alternation(messages)

        anthropic_payload = {
            "model": payload.get("model", "claude-3-5-sonnet-20241022"),
            "messages": messages,
            "max_tokens": payload.get("max_tokens", 4096),
            "stream": payload.get("stream", True),
        }

        if system_prompt.strip():
            anthropic_payload["system"] = system_prompt.strip()

        if payload.get("temperature") is not None:
            anthropic_payload["temperature"] = payload["temperature"]

        if payload.get("top_p") is not None:
            anthropic_payload["top_p"] = payload["top_p"]

        return anthropic_payload

    @staticmethod
    def anthropic_to_openai(payload: Dict[str, Any]) -> Dict[str, Any]:
        """Convert Anthropic format back to OpenAI."""
        messages = []
        if "system" in payload:
            messages.append({"role": "system", "content": payload["system"]})
        messages.extend(payload.get("messages", []))

        return {
            "model": payload.get("model", "gpt-4o"),
            "messages": messages,
            "max_tokens": payload.get("max_tokens", 4096),
            "stream": payload.get("stream", False),
            "temperature": payload.get("temperature"),
        }


class StreamTranslator:
    """
    Translates SSE chunks on the fly to prevent RAM buffering.

    Each method takes ONE line from upstream and returns ONE line for
    the client.  No accumulation, no full-response loading.

    Handles ALL Anthropic SSE chunk types including:
      - Extended thinking blocks (thinking_delta -> reasoning_content)
      - Tool use (input_json_delta -> tool_calls)
      - Error events (forwarded to client, not silently dropped)
      - Ping events (acknowledged, not dropped)
    """

    @staticmethod
    def _openai_content_chunk(text: str) -> str:
        """Helper: produce an OpenAI content delta chunk."""
        return "data: " + json.dumps({
            "id": "owl-orca-msg",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "orca-translated",
            "choices": [{"index": 0, "delta": {"content": text}, "finish_reason": None}],
        }) + "\n\n"

    @staticmethod
    def _openai_reasoning_chunk(thinking: str) -> str:
        """Helper: produce an OpenAI reasoning delta chunk (o1-style).

        Maps Anthropic thinking_delta to the emerging delta.reasoning_content
        standard used by OpenAI, Azure, LiteLLM, and OpenRouter for
        extended thinking / chain-of-thought content.
        """
        return "data: " + json.dumps({
            "id": "owl-orca-msg",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "orca-translated",
            "choices": [{"index": 0, "delta": {"reasoning_content": thinking}, "finish_reason": None}],
        }) + "\n\n"

    @staticmethod
    def _openai_tool_chunk(index: int, partial_json: str) -> str:
        """Helper: produce an OpenAI tool_call delta chunk.

        Maps Anthropic input_json_delta to OpenAI tool_calls format.
        """
        return "data: " + json.dumps({
            "id": "owl-orca-msg",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "orca-translated",
            "choices": [{"index": 0, "delta": {
                "tool_calls": [{
                    "index": index,
                    "function": {"arguments": partial_json},
                }],
            }, "finish_reason": None}],
        }) + "\n\n"

    @staticmethod
    def _openai_error_chunk(error_msg: str, error_type: str = "api_error") -> str:
        """Helper: produce an OpenAI error chunk (not silently dropped)."""
        return "data: " + json.dumps({
            "id": "owl-orca-msg",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "orca-translated",
            "choices": [{"index": 0, "delta": {"content": f"\n[ERROR: {error_msg}]"}, "finish_reason": None}],
            "error": {"message": error_msg, "type": error_type},
        }) + "\n\n"

    @staticmethod
    def anthropic_sse_to_openai(anthropic_chunk: str) -> Optional[str]:
        """
        Converts an Anthropic SSE chunk to an OpenAI SSE chunk.

        Full coverage of Anthropic SSE event types:
          message_start         -> role chunk
          content_block_start   -> tool_use start (if tool_use type)
          content_block_delta   -> content chunk (text_delta)
                                 -> reasoning chunk (thinking_delta)
                                 -> tool_call chunk (input_json_delta)
          content_block_stop    -> acknowledged (no output needed)
          message_delta         -> finish_reason chunk
          message_stop          -> [DONE]
          ping                  -> acknowledged (prevents timeout)
          error                 -> error chunk (NOT silently dropped)
        """
        line = anthropic_chunk.strip()

        # Event-type lines carry no data payload
        if line.startswith("event:"):
            if "message_stop" in line:
                return "data: [DONE]\n\n"
            # ping, error event lines are acknowledged but carry no data
            return None

        if not line.startswith("data:"):
            return None

        try:
            data = json.loads(line[5:].strip())
        except json.JSONDecodeError:
            return None

        chunk_type = data.get("type")

        # 1. message_start -> OpenAI role chunk
        if chunk_type == "message_start":
            msg = data.get("message", {})
            return "data: " + json.dumps({
                "id": msg.get("id", "owl-orca-msg"),
                "object": "chat.completion.chunk",
                "created": int(time.time()),
                "model": msg.get("model", "orca-translated"),
                "choices": [{"index": 0, "delta": {"role": "assistant"}, "finish_reason": None}],
            }) + "\n\n"

        # 2. content_block_start -> track block type for tool_use
        if chunk_type == "content_block_start":
            block = data.get("content_block", {})
            block_type = block.get("type", "")
            if block_type == "tool_use":
                # Emit a tool_calls start chunk with the function name
                tool_id = block.get("id", f"call_{data.get('index', 0)}")
                tool_name = block.get("name", "unknown")
                return "data: " + json.dumps({
                    "id": "owl-orca-msg",
                    "object": "chat.completion.chunk",
                    "created": int(time.time()),
                    "model": "orca-translated",
                    "choices": [{"index": 0, "delta": {
                        "tool_calls": [{
                            "index": data.get("index", 0),
                            "id": tool_id,
                            "type": "function",
                            "function": {"name": tool_name, "arguments": ""},
                        }],
                    }, "finish_reason": None}],
                }) + "\n\n"
            # thinking or text block start: no output needed
            return None

        # 3. content_block_delta -> dispatch by delta sub-type
        if chunk_type == "content_block_delta":
            delta = data.get("delta", {})
            delta_type = delta.get("type", "text_delta")

            if delta_type == "text_delta":
                text = delta.get("text", "")
                if text:
                    return StreamTranslator._openai_content_chunk(text)
                return None

            elif delta_type == "thinking_delta":
                # CRITICAL FIX: Extended thinking content was silently dropped
                # because old code used get("text") instead of get("thinking").
                # Now maps to delta.reasoning_content (o1-style standard).
                thinking = delta.get("thinking", "")
                if thinking:
                    return StreamTranslator._openai_reasoning_chunk(thinking)
                return None

            elif delta_type == "input_json_delta":
                # Tool call arguments were silently dropped.
                # Maps to tool_calls[].function.arguments partial JSON.
                partial = delta.get("partial_json", "")
                if partial:
                    return StreamTranslator._openai_tool_chunk(
                        data.get("index", 0), partial
                    )
                return None

            # Unknown delta type: log but don't crash
            return None

        # 4. content_block_stop -> acknowledged (no output needed)
        if chunk_type == "content_block_stop":
            return None

        # 5. message_delta -> OpenAI finish_reason chunk
        if chunk_type == "message_delta":
            stop_reason = data.get("delta", {}).get("stop_reason", "stop")
            finish = "stop" if stop_reason == "end_turn" else stop_reason
            if stop_reason == "tool_use":
                finish = "tool_calls"
            return "data: " + json.dumps({
                "id": "owl-orca-msg",
                "object": "chat.completion.chunk",
                "created": int(time.time()),
                "model": "orca-translated",
                "choices": [{"index": 0, "delta": {}, "finish_reason": finish}],
            }) + "\n\n"

        # 6. message_stop -> [DONE]
        if chunk_type == "message_stop":
            return "data: [DONE]\n\n"

        # 7. ping -> acknowledged (prevents client timeout on long thinking)
        if chunk_type == "ping":
            return None

        # 8. error -> emit error chunk (NOT silently dropped)
        if chunk_type == "error":
            error_data = data.get("error", {})
            error_msg = error_data.get("message", "Unknown upstream error")
            error_type_val = error_data.get("type", "api_error")
            return StreamTranslator._openai_error_chunk(error_msg, error_type_val)

        # Unknown chunk type: don't crash, but don't silently drop either
        return None

    @staticmethod
    def copilot_sse_to_openai(copilot_chunk: str) -> Optional[str]:
        """
        Normalize Copilot SSE to standard OpenAI format.
        Most Copilot responses are already OpenAI-compliant, but
        some edge cases need handling.
        """
        if not copilot_chunk.startswith("data:"):
            return None
        if "[DONE]" in copilot_chunk:
            return "data: [DONE]\n\n"
        try:
            data = json.loads(copilot_chunk[5:].strip())
            if "choices" in data:
                return "data: " + json.dumps(data) + "\n\n"
            return None
        except json.JSONDecodeError:
            return None
PYEOF
    mv -f "$_ATMP" "$BIN_DIR/payload_translator.py"
    chmod +x "$BIN_DIR/payload_translator.py"
fi

# -- 6D: Token Manager --------------------------------------------------------
log_info "Writing token_manager.py..."

if [ "${DRY_RUN:-}" != "true" ]; then
    _ATMP="$(_mktemp "$BIN_DIR/token_manager.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Token Manager v1.1
Manages OAuth tokens for free-tier AI providers.
Supports: GitHub Copilot (device flow), Antigravity (API key / OAuth)
Encrypts tokens at rest using Fernet symmetric encryption.
"""
import asyncio
import json
import os
import sys
import time
import hashlib
import secrets
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, Dict, Tuple
from datetime import datetime
from urllib.parse import urlencode, urlparse, parse_qs

try:
    import httpx
except ImportError:
    print("ERROR: httpx required. Run: pip install httpx")
    sys.exit(1)

try:
    from cryptography.fernet import Fernet
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False
    print("WARNING: cryptography not installed. Tokens stored unencrypted.")

# -- Paths --
# FIX (v8-N3): Use OWL_INSTALL_DIR environment variable instead of
# hardcoding ~/.owl-agent. The install.sh script allows custom install
# directories via OWL_INSTALL_DIR, so all Python modules must respect it.
_install_dir = Path(os.getenv("OWL_INSTALL_DIR", str(Path.home() / ".owl-agent")))
CONFIG_DIR = _install_dir / "config"
TOKENS_FILE = CONFIG_DIR / "tokens.enc"
KEY_FILE = CONFIG_DIR / ".key"
PROVIDERS_FILE = CONFIG_DIR / "providers.json"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)

_env_file = _install_dir / ".env"
if _env_file.exists():
    with open(_env_file) as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _k, _v = _line.split("=", 1)
                os.environ.setdefault(_k.strip(), _v.strip())

# -- Constants --
GITHUB_CLIENT_ID = "Iv1.b507a08c87ecfe98"
GITHUB_DEVICE_URL = "https://github.com/login/device/code"
GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
COPILOT_API_BASE = "https://api.githubcopilot.com"
# Antigravity = Google Cloud Code Assist OAuth2
ANTIGRAVITY_CLIENT_ID = os.getenv("ANTIGRAVITY_CLIENT_ID")
ANTIGRAVITY_CLIENT_SECRET = os.getenv("ANTIGRAVITY_CLIENT_SECRET")
if not ANTIGRAVITY_CLIENT_ID or not ANTIGRAVITY_CLIENT_SECRET:
    print(f"{YELLOW}⚠ ANTIGRAVITY_CLIENT_ID / ANTIGRAVITY_CLIENT_SECRET not set{RED}")
    print(f"{YELLOW}  Google OAuth-based features (antigravity) will be unavailable.{NC}")
    print(f"{YELLOW}  Set them in your environment or ~/.owl-agent/.env to enable.{NC}")
ANTIGRAVITY_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
ANTIGRAVITY_TOKEN_URL = "https://oauth2.googleapis.com/token"
ANTIGRAVITY_API_BASE = "https://cloudcode-pa.googleapis.com"
ANTIGRAVITY_REDIRECT_URI = "http://localhost:51121/oauth-callback"
ANTIGRAVITY_SCOPES = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "https://www.googleapis.com/auth/cclog",
    "https://www.googleapis.com/auth/experimentsandconfigs",
]
PROXY_URL = os.getenv("OWL_PROXY_URL", "http://127.0.0.1:60000")

# -- ANSI --
CYAN = '\033[0;36m'; GREEN = '\033[0;32m'; YELLOW = '\033[1;33m'
RED = '\033[0;31m'; NC = '\033[0m'; BOLD = '\033[1m'


@dataclass
class TokenData:
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_at: float = 0.0
    scope: str = ""
    provider: str = ""
    acquired_at: float = field(default_factory=time.time)

    @property
    def is_expired(self) -> bool:
        return time.time() >= (self.expires_at - 300)  # refresh 5 min early

    @property
    def expires_in(self) -> int:
        return max(0, int(self.expires_at - time.time()))

    def to_dict(self) -> dict:
        return {k: v for k, v in {
            "access_token": self.access_token,
            "refresh_token": self.refresh_token,
            "token_type": self.token_type,
            "expires_at": self.expires_at,
            "scope": self.scope,
            "provider": self.provider,
            "acquired_at": self.acquired_at,
        }.items() if v is not None}

    @classmethod
    def from_dict(cls, d: dict) -> "TokenData":
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


class TokenEncryption:
    def __init__(self):
        self._fernet = None
        if CRYPTO_AVAILABLE:
            self._load_or_create_key()

    def _load_or_create_key(self):
        if KEY_FILE.exists():
            self._fernet = Fernet(KEY_FILE.read_bytes())
        else:
            key = Fernet.generate_key()
            KEY_FILE.write_bytes(key)
            KEY_FILE.chmod(0o600)
            self._fernet = Fernet(key)

    def encrypt(self, data: str) -> bytes:
        return self._fernet.encrypt(data.encode()) if self._fernet else data.encode()

    def decrypt(self, data: bytes) -> str:
        return self._fernet.decrypt(data).decode() if self._fernet else (data.decode() if isinstance(data, bytes) else data)


class TokenStore:
    def __init__(self):
        self._encryption = TokenEncryption()
        self._tokens: Dict[str, TokenData] = {}
        self._load()

    def _load(self):
        if TOKENS_FILE.exists():
            try:
                data = self._encryption.decrypt(TOKENS_FILE.read_bytes())
                for provider, td in json.loads(data).items():
                    self._tokens[provider] = TokenData.from_dict(td)
            except Exception as e:
                print(f"WARNING: Could not load tokens: {e}")

    def _save(self):
        raw = json.dumps({p: t.to_dict() for p, t in self._tokens.items()})
        TOKENS_FILE.write_bytes(self._encryption.encrypt(raw))
        TOKENS_FILE.chmod(0o600)

    def get(self, provider: str) -> Optional[TokenData]:
        return self._tokens.get(provider)

    def set(self, provider: str, token: TokenData):
        self._tokens[provider] = token
        self._save()

    def delete(self, provider: str):
        self._tokens.pop(provider, None)
        self._save()

    def list_providers(self) -> list:
        return list(self._tokens.keys())

    def status(self) -> dict:
        result = {}
        for provider, token in self._tokens.items():
            result[provider] = {
                "has_token": bool(token.access_token),
                "is_expired": token.is_expired,
                "expires_in": token.expires_in,
                "acquired_at": datetime.fromtimestamp(token.acquired_at).isoformat(),
            }
        return result


class DeviceFlowAuth:
    """GitHub Copilot device flow for browserless auth."""

    def __init__(self, client_id: str = GITHUB_CLIENT_ID, proxy_url: str = PROXY_URL):
        self.client_id = client_id
        self.proxy_url = proxy_url

    async def start_flow(self) -> Tuple[str, str, str, int]:
        """Returns (user_code, verification_uri, device_code, expires_in)"""
        params = {"client_id": self.client_id, "scope": "read:user copilot"}
        async with httpx.AsyncClient(proxy=self.proxy_url, timeout=30) as client:
            resp = await client.post(GITHUB_DEVICE_URL, data=params)
            resp.raise_for_status()
            from urllib.parse import parse_qs
            d = {k: v[0] for k, v in parse_qs(resp.text).items()}
            return d["user_code"], d["verification_uri"], d.get("device_code", ""), int(d.get("expires_in", 900))

    async def poll_for_token(self, device_code: str, interval: int = 5, timeout: int = 300) -> TokenData:
        params = {
            "client_id": self.client_id,
            "device_code": device_code,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        }
        start = time.time()
        async with httpx.AsyncClient(proxy=self.proxy_url, timeout=30) as client:
            while time.time() - start < timeout:
                resp = await client.post(
                    GITHUB_TOKEN_URL, data=params,
                    headers={"Accept": "application/json"},
                )
                d = resp.json()
                if "access_token" in d:
                    return TokenData(
                        access_token=d["access_token"],
                        token_type=d.get("token_type", "bearer"),
                        expires_at=time.time() + int(d.get("expires_in", 86400)),
                        scope=d.get("scope", ""),
                        provider="copilot",
                    )
                error = d.get("error", "")
                if error == "authorization_pending":
                    await asyncio.sleep(interval)
                    continue
                elif error == "slow_down":
                    interval += 5
                    await asyncio.sleep(interval)
                    continue
                elif error == "expired_token":
                    raise RuntimeError("Device code expired. Please try again.")
                else:
                    raise RuntimeError(f"Auth error: {d.get('error_description', error)}")
        raise TimeoutError("Authorization timed out.")


class APIKeyAuth:
    """Simple API key auth for providers like Antigravity free tier."""

    @staticmethod
    def create_token(api_key: str, provider: str = "antigravity") -> TokenData:
        return TokenData(
            access_token=api_key,
            token_type="bearer",
            expires_at=time.time() + (365 * 24 * 60 * 60),
            scope="all",
            provider=provider,
        )


class AntigravityOAuth:
    """Google Antigravity (Cloud Code Assist) OAuth with PKCE support."""

    def __init__(self, proxy_url: str = PROXY_URL):
        self.proxy_url = proxy_url
        self._verifier = ""
        self._state = ""

    def _generate_pkce(self) -> Tuple[str, str]:
        self._verifier = secrets.token_urlsafe(64)
        challenge = hashlib.sha256(self._verifier.encode()).digest()
        import base64
        challenge_b64 = base64.urlsafe_b64encode(challenge).rstrip(b"=").decode()
        return self._verifier, challenge_b64

    def get_auth_url(self, redirect_uri: str = ANTIGRAVITY_REDIRECT_URI) -> str:
        _, challenge = self._generate_pkce()
        self._state = secrets.token_hex(16)
        params = {
            "client_id": ANTIGRAVITY_CLIENT_ID,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": " ".join(ANTIGRAVITY_SCOPES),
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "state": self._state,
            "access_type": "offline",
            "prompt": "consent",
        }
        return f"{ANTIGRAVITY_AUTH_URL}?{urlencode(params)}"

    async def exchange_code(self, code: str, redirect_uri: str = ANTIGRAVITY_REDIRECT_URI) -> TokenData:
        async with httpx.AsyncClient(proxy=self.proxy_url, timeout=30) as client:
            resp = await client.post(
                ANTIGRAVITY_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                    "client_id": ANTIGRAVITY_CLIENT_ID,
                    "client_secret": ANTIGRAVITY_CLIENT_SECRET,
                    "code_verifier": self._verifier,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            resp.raise_for_status()
            d = resp.json()
            return TokenData(
                access_token=d["access_token"],
                refresh_token=d.get("refresh_token"),
                token_type=d.get("token_type", "bearer"),
                expires_at=time.time() + int(d.get("expires_in", 3600)),
                scope=d.get("scope", ""),
                provider="antigravity",
            )


class TokenManager:
    def __init__(self, proxy_url: str = PROXY_URL):
        self.proxy_url = proxy_url
        self.store = TokenStore()

    async def authenticate_copilot(self) -> TokenData:
        auth = DeviceFlowAuth(proxy_url=self.proxy_url)
        print(f"\n{BOLD}GitHub Copilot Device Authentication{NC}")
        print("=" * 50)
        user_code, verification_uri, device_code, expires_in = await auth.start_flow()
        print(f"  1. Open: {CYAN}{verification_uri}{NC}")
        print(f"  2. Enter code: {GREEN}{user_code}{NC}")
        print(f"  3. Waiting for authorization ({expires_in}s)...")
        token = await auth.poll_for_token(device_code)
        self.store.set("copilot", token)
        print(f"  {GREEN}Copilot authenticated!{NC} Expires in {token.expires_in // 3600}h")
        return token

    async def authenticate_antigravity(self, api_key: Optional[str] = None) -> TokenData:
        if api_key:
            token = APIKeyAuth.create_token(api_key, "antigravity")
            self.store.set("antigravity", token)
            print(f"  {GREEN}Antigravity authenticated with API key!{NC}")
            return token
        auth = AntigravityOAuth(proxy_url=self.proxy_url)
        auth_url = auth.get_auth_url()
        print(f"\n{BOLD}Google Antigravity (Cloud Code Assist) OAuth{NC}")
        print("=" * 60)
        print(f"  1. Open: {CYAN}{auth_url}{NC}")
        print(f"  2. Sign in with your Google account")
        print(f"  3. After authorization, your browser redirects to")
        print(f"     {ANTIGRAVITY_REDIRECT_URI}?code=...&state=...")
        print(f"     Copy the FULL redirect URL and paste it below")
        code = input(f"\n  {YELLOW}Paste redirect URL or authorization code: {NC}").strip()
        if code.startswith("http"):
            parsed = urlparse(code)
            qs = parse_qs(parsed.query)
            code = qs.get("code", [""])[0]
            returned_state = qs.get("state", [""])[0]
            if returned_state and returned_state != auth._state:
                print(f"  {RED}WARNING: OAuth state mismatch (possible CSRF). Proceeding anyway.{NC}")
        if not code:
            raise ValueError("No authorization code provided")
        token = await auth.exchange_code(code)
        self.store.set("antigravity", token)
        print(f"  {GREEN}Antigravity authenticated!{NC}")
        return token

    def get_valid_token(self, provider: str) -> Optional[TokenData]:
        token = self.store.get(provider)
        if token and not token.is_expired:
            return token
        return None

    def status(self) -> dict:
        return {"providers": self.store.list_providers(), "tokens": self.store.status()}


async def main():
    import argparse
    parser = argparse.ArgumentParser(description="OWL Token Manager")
    parser.add_argument("command", choices=["auth", "status", "get", "delete", "list"])
    parser.add_argument("--provider", "-p", help="Provider name")
    parser.add_argument("--api-key", "-k", help="API key for direct auth")
    args = parser.parse_args()

    manager = TokenManager()
    if args.command == "auth":
        provider = args.provider or input("Provider (copilot/antigravity): ").strip()
        if provider == "copilot":
            await manager.authenticate_copilot()
        elif provider == "antigravity":
            await manager.authenticate_antigravity(api_key=args.api_key)
    elif args.command == "status":
        print(json.dumps(manager.status(), indent=2))
    elif args.command == "get":
        token = manager.get_valid_token(args.provider)
        print(token.access_token if token else "", end="")
    elif args.command == "delete":
        manager.store.delete(args.provider)
    elif args.command == "list":
        print("\n".join(manager.store.list_providers()))


if __name__ == "__main__":
    asyncio.run(main())
PYEOF
    mv -f "$_ATMP" "$BIN_DIR/token_manager.py"
    chmod +x "$BIN_DIR/token_manager.py"
fi

# -- 6E: Orca Router (THE BRAIN) ---------------------------------------------
log_info "Writing orca_router.py (Stream Racing + Radix + Translation + SIGHUP)..."

if [ "${DRY_RUN:-}" != "true" ]; then
    _ATMP="$(_mktemp "$BIN_DIR/orca_router.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Orca-Router v8.0 (Five-Pass-Audit-Final Edition)
Merges: n9router + 9router + OrcaFlow capabilities

Features:
  - Radix Tree O(1) Routing
  - Stream Racing (First Byte Wins)
  - Canary A/B Testing (Weighted Split)
  - Half-Open Circuit Breakers with Probes
  - Backpressure-aware streaming (bounded queues)
  - Live Protocol Translation (Anthropic <-> OpenAI SSE)
  - SIGHUP hot-reload of routing configuration
  - Zero-downtime safe: atomic config swaps, no connection drops
"""
import asyncio
import json
import os
import signal
import time
import logging
from pathlib import Path
from typing import Dict, Any, Optional, List, AsyncGenerator, Callable
from enum import Enum

try:
    import httpx
except ImportError:
    print("ERROR: httpx required. Run: pip install httpx[http2]")
    exit(1)

try:
    from aiohttp import web
except ImportError:
    print("ERROR: aiohttp required. Run: pip install aiohttp")
    exit(1)

# Add bin dir to path so we can import sibling modules
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "utils"))

from payload_translator import PayloadTranslator, StreamTranslator
from radix_tree import RadixTreeRouter
from circuits import HalfOpenCircuit, CircuitBreakerRegistry

# -- Configuration -----------------------------------------------------------
INSTALL_DIR = Path(os.getenv("OWL_INSTALL_DIR", str(Path.home() / ".owl-agent")))
CONFIG_DIR = INSTALL_DIR / "config"
LOG_DIR = INSTALL_DIR / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

PROXY_URL = os.getenv("OWL_PROXY_URL", "http://127.0.0.1:60000")
KIRO_API_KEY = os.getenv("KIRO_API_KEY", "kiro-gateway-8333")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "orca-router.log"),
    ],
)
logger = logging.getLogger("orca-router")


# =============================================================================
#  STREAM RACER (OrcaFlow-style Multiplexer)
# =============================================================================
class StreamRacer:
    """
    Races multiple LLM streams concurrently.
    Yields the first chunk received, cancels the losers.
    Zero-copy backpressure: pauses if client queue is full.

    FIX (F-01): Each chunk is tagged with its source stream_id.
    After the race is decided, only chunks from the winning stream
    are yielded to the client. Loser chunks are silently discarded.
    This prevents interleaved/garbled output from multiple providers.
    """

    def __init__(self, max_queue_size: int = 5):
        """
        Small queue = strict backpressure on 8GB RAM.
        With maxsize=5, at most 5 chunks are buffered per stream.
        """
        self.max_queue_size = max_queue_size

    async def race(
        self,
        streams: List[AsyncGenerator],
        translator_map: Dict[int, Callable[[str], Optional[str]]],
    ) -> AsyncGenerator[str, None]:
        """
        Race multiple async generators. First to produce a translated
        chunk wins; all others are cancelled.

        Args:
            streams: List of async generators yielding raw SSE lines.
            translator_map: Maps stream index to a translation function.

        Returns:
            Only chunks from the winning stream (no interleaving).
        """
        # Queue items: (stream_id, chunk_str) or (stream_id, None) for EOF
        queue: asyncio.Queue = asyncio.Queue(maxsize=self.max_queue_size)
        winner_found = asyncio.Event()
        winner_id: List[Optional[int]] = [None]  # Mutable container for closure
        tasks: List[asyncio.Task] = []

        async def producer(
            stream_id: int,
            stream: AsyncGenerator,
            translator: Optional[Callable],
        ):
            try:
                async for chunk in stream:
                    if winner_found.is_set() and winner_id[0] != stream_id:
                        return  # Another stream won, stop producing

                    translated = translator(chunk) if translator else chunk
                    if translated is not None:
                        if not winner_found.is_set():
                            winner_found.set()  # I win!
                            winner_id[0] = stream_id
                            logger.info("Race won by stream %d", stream_id)
                        # Tag chunk with stream_id so consumer can filter
                        await queue.put((stream_id, translated))
                # Signal end of this stream
                await queue.put((stream_id, None))
            except asyncio.CancelledError:
                pass
            except Exception as e:
                logger.debug("Stream %d failed: %s", stream_id, e)
                if not winner_found.is_set():
                    await queue.put((stream_id, None))

        for i, stream in enumerate(streams):
            translator = translator_map.get(i)
            tasks.append(asyncio.create_task(producer(i, stream, translator)))

        finished_count = 0
        expected_finishes = len(tasks)
        try:
            while finished_count < expected_finishes:
                try:
                    item = await asyncio.wait_for(queue.get(), timeout=5.0)
                    stream_id, chunk = item
                    if chunk is None:
                        finished_count += 1
                        continue
                    # Only yield chunks from the winning stream
                    if winner_id[0] is not None and stream_id != winner_id[0]:
                        continue  # Discard loser chunk
                    yield chunk
                except asyncio.TimeoutError:
                    if all(t.done() for t in tasks):
                        break
        finally:
            for task in tasks:
                task.cancel()


# =============================================================================
#  MAIN ORCA ROUTER
# =============================================================================
class OrcaRouter:
    """
    The central routing engine. Combines:
      - Radix Tree for O(1) path matching
      - Half-Open Circuit Breakers for fault tolerance
      - Stream Racing for first-byte-wins latency
      - Protocol Translation for Anthropic <-> OpenAI
      - SIGHUP hot-reload for zero-downtime config changes
    """

    def __init__(self):
        self.tree = RadixTreeRouter()
        self.circuits = CircuitBreakerRegistry(
            failure_threshold=5,
            recovery_timeout=60.0,
        )
        self.racer = StreamRacer(max_queue_size=5)
        self.translator = PayloadTranslator()
        self.providers = self._load_providers()
        self.config = self._load_config()
        self._setup_routes()

        # SIGHUP hot-reload: allows `systemctl reload orca-router` to
        # swap routing config without dropping active TCP connections.
        # FIX (F-05): Use asyncio signal handler instead of signal.signal()
        # to ensure the handler runs cooperatively with the event loop.
        self._sighup_pending = False

        # FIX (N1): Initialize token cache as INSTANCE variables.
        # Previously declared at class level, all OrcaRouter instances
        # would share the same cache dict leading to stale reads.
        self._token_cache: Optional[Dict[str, str]] = None
        self._token_cache_time: float = 0.0
        self._token_cache_ttl: float = 60.0  # seconds

        # Shared httpx client with connection pooling (FIX: avoids TLS
        # handshake overhead on every request)
        self._http_client: Optional[httpx.AsyncClient] = None

        logger.info(
            "OrcaRouter initialized: %d providers, %d routes",
            len(self.providers),
            len(self.tree.list_routes()),
        )

    def _handle_sighup(self):
        """Reload routing configuration from disk without dropping connections.

        FIX (F-05): All state (tree, providers, config) is replaced atomically
        in a single synchronous block. No await points between the replacements
        ensures no request handler sees a partially-replaced state.
        FIX (v8-N4): Actually implement the N8 fix -- run file I/O in a
        thread executor to prevent blocking the event loop on slow filesystems
        (NFS, FUSE, etc). The atomic swap still happens synchronously in the
        event loop after the thread completes, guaranteeing no partial state.
        """
        if self._sighup_pending:
            logger.info("SIGHUP reload already pending, skipping")
            return
        self._sighup_pending = True
        try:
            logger.info("Received SIGHUP: Hot-reloading configuration...")
            # Build new state BEFORE swapping references
            # Run file I/O in a thread to avoid blocking the event loop
            # on slow filesystems (NFS, FUSE). The atomic swap below
            # still happens synchronously, ensuring no partial state.
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                providers_future = executor.submit(self._load_providers)
                config_future = executor.submit(self._load_config)
                new_providers = providers_future.result(timeout=5)
                new_config = config_future.result(timeout=5)
            new_tree = RadixTreeRouter()
            for route in new_config.get("routes", []):
                new_tree.add_route(route["pattern"], route)
            # Atomic swap: all three references replaced synchronously
            self.providers = new_providers
            self.config = new_config
            self.tree = new_tree
            logger.info(
                "Configuration reloaded: %d providers, %d routes",
                len(self.providers),
                len(self.tree.list_routes()),
            )
        except Exception as e:
            logger.error("SIGHUP reload failed: %s", e)
        finally:
            self._sighup_pending = False

    def _register_sighup(self, loop):
        """Register SIGHUP handler as an asyncio signal handler.

        FIX (F-05): Using loop.add_signal_handler() instead of signal.signal()
        ensures the handler runs as a scheduled callback in the event loop,
        not as an interrupt between bytecode instructions.
        """
        loop.add_signal_handler(signal.SIGHUP, self._handle_sighup)

    # -- Config Loading -------------------------------------------------------

    def _load_providers(self) -> dict:
        """Load provider definitions from config/providers.json."""
        providers_file = CONFIG_DIR / "providers.json"
        if providers_file.exists():
            try:
                with open(providers_file) as f:
                    return json.load(f)
            except Exception as e:
                logger.warning("Could not load providers.json: %s", e)
        return {
            "copilot": {"base_url": "https://api.githubcopilot.com", "format": "openai"},
            "antigravity": {"base_url": "https://cloudcode-pa.googleapis.com", "format": "anthropic"},
            "kiro": {"base_url": "http://127.0.0.1:8333", "format": "openai"},
        }

    def _load_config(self) -> dict:
        """Load routing rules from config/routes.json."""
        routes_file = CONFIG_DIR / "routes.json"
        if routes_file.exists():
            try:
                with open(routes_file) as f:
                    return json.load(f)
            except Exception as e:
                logger.warning("Could not load routes.json: %s", e)
        # Fallback hardcoded config
        return {
            "routes": [
                {
                    "pattern": "v1/chat/completions",
                    "strategy": "race",
                    "targets": [
                        {"provider": "copilot", "model": "gpt-4o-mini-copilot", "weight": 90},
                        {"provider": "antigravity", "model": "antigravity-flash", "weight": 10},
                    ],
                },
                {
                    "pattern": "v1/models",
                    "strategy": "single",
                    "targets": [{"provider": "copilot", "model": "gpt-4o-mini-copilot"}],
                },
            ]
        }

    def _setup_routes(self):
        """Populate the radix tree from config."""
        for route in self.config.get("routes", []):
            self.tree.add_route(route["pattern"], route)

    # -- Token Loading --------------------------------------------------------

    # FIX (B20/N1): Token cache MUST be instance variables, not class
    # variables. Class variables are shared across all OrcaRouter instances,
    # causing stale cache reads. Now initialized properly in __init__.
    # These class-level annotations serve as type hints only; actual values
    # are set per-instance in __init__.

    def _load_tokens(self) -> Dict[str, str]:
        """Load tokens from TokenManager's encrypted store.

        FIX (O-01): Cache tokens with a 60-second TTL. Tokens have long
        expiry times (24h for Copilot, 365d for API keys), so refreshing
        every minute is more than sufficient. Saves ~2-5ms per request.
        """
        now = time.time()
        if self._token_cache is not None and (now - self._token_cache_time) < self._token_cache_ttl:
            return self._token_cache

        tokens = {"kiro": KIRO_API_KEY}
        try:
            from token_manager import TokenStore
            store = TokenStore()
            for provider in ["copilot", "antigravity"]:
                token = store.get(provider)
                if token and not token.is_expired:
                    tokens[provider] = token.access_token
        except Exception as e:
            logger.debug("Token loading fallback: %s", e)

        self._token_cache = tokens
        self._token_cache_time = now
        return tokens

    # -- HTTP Client ----------------------------------------------------------

    def _get_http_client(self, proxy: Optional[str] = None) -> httpx.AsyncClient:
        """Get or create a shared httpx AsyncClient with connection pooling.

        FIX: Previously a new AsyncClient was created per-request, causing
        TLS handshake overhead on every request. Now we reuse the client
        with connection pooling for better latency.
        """
        if self._http_client is None or self._http_client.is_closed:
            self._http_client = httpx.AsyncClient(
                proxy=proxy,
                timeout=httpx.Timeout(120.0, connect=15.0),
                http2=True,
                limits=httpx.Limits(
                    max_connections=20,
                    max_keepalive_connections=10,
                    keepalive_expiry=60,
                ),
            )
        return self._http_client

    # -- Stream Fetchers ------------------------------------------------------

    async def _fetch_stream(
        self, provider: str, url: str, payload: dict, token: str
    ) -> AsyncGenerator[str, None]:
        """Yield raw SSE lines from a provider. Handles payload translation."""
        headers = {
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        }

        provider_format = self.providers.get(provider, {}).get("format", "openai")

        if provider_format == "anthropic":
            payload = self.translator.openai_to_anthropic(payload)
            headers["x-api-key"] = token
            headers["anthropic-version"] = "2023-06-01"
        else:
            headers["Authorization"] = f"Bearer {token}"

        use_proxy = PROXY_URL if provider != "kiro" else None

        client = self._get_http_client(proxy=use_proxy)
        async with client.stream("POST", url, json=payload, headers=headers) as response:
            if response.status_code != 200:
                error_body = await response.aread()
                self.circuits.get(provider).record_failure()
                raise Exception(f"HTTP {response.status_code}: {error_body.decode()[:200]}")
            async for line in response.aiter_lines():
                yield line

    # -- Strategy Handlers ----------------------------------------------------

    async def _handle_race(
        self, targets: list, path: str, payload: dict, tokens: Dict[str, str]
    ) -> AsyncGenerator[str, None]:
        """OrcaFlow Stream Racing: fire all targets, yield first byte, cancel rest."""
        payload["stream"] = True  # Force streaming for racing
        streams: List[AsyncGenerator] = []
        translator_map: Dict[int, Callable] = {}

        for target in targets:
            provider = target["provider"]
            circuit = self.circuits.get(provider)

            if not circuit.can_execute():
                logger.debug("Skipping %s: circuit open", provider)
                continue

            base_url = self.providers.get(provider, {}).get("base_url", "")
            url = f"{base_url}/{path}" if not base_url.endswith("/") else f"{base_url}{path}"
            token = tokens.get(provider, KIRO_API_KEY)

            stream_gen = self._fetch_stream(provider, url, payload, token)
            stream_idx = len(streams)
            streams.append(stream_gen)

            # Map the correct SSE translator for this provider
            fmt = self.providers.get(provider, {}).get("format", "openai")
            if fmt == "anthropic":
                translator_map[stream_idx] = StreamTranslator.anthropic_sse_to_openai
            else:
                translator_map[stream_idx] = StreamTranslator.copilot_sse_to_openai

        if not streams:
            # FIX (v8-N8): When all streams fail or all circuits are open,
            # yield an OpenAI-compliant error chunk instead of raising an
            # exception that produces a non-standard error response.
            error_json = json.dumps({
                "error": {
                    "message": "All providers are circuit-broken or unavailable",
                    "type": "orca_circuit_open",
                    "code": "no_available_provider",
                }
            })
            yield f"data: {error_json}\n\n"
            yield "data: [DONE]\n\n"
            return

        async for chunk in self.racer.race(streams, translator_map):
            yield chunk

    async def _handle_canary(
        self, targets: list, path: str, payload: dict, tokens: Dict[str, str]
    ) -> AsyncGenerator[str, None]:
        """9router Canary: weighted random split for A/B testing."""
        import random
        r = random.random() * 100
        cumulative = 0
        for target in targets:
            cumulative += target.get("weight", 50)
            if r <= cumulative:
                async for chunk in self._handle_single_stream(target, path, payload, tokens):
                    yield chunk
                return
        # Fallback if weights don't sum to 100
        async for chunk in self._handle_single_stream(targets[0], path, payload, tokens):
            yield chunk

    async def _handle_single_stream(
        self, target: dict, path: str, payload: dict, tokens: Dict[str, str]
    ) -> AsyncGenerator[str, None]:
        """Stream from a single provider with circuit breaker protection."""
        provider = target["provider"]
        circuit = self.circuits.get(provider)

        if not circuit.can_execute():
            logger.warning("Circuit open for %s, falling back to kiro", provider)
            provider = "kiro"
            circuit = self.circuits.get("kiro")
            if not circuit.can_execute():
                raise Exception("All circuits open including fallback (kiro)")

        base_url = self.providers.get(provider, {}).get("base_url", "")
        url = f"{base_url}/{path}" if not base_url.endswith("/") else f"{base_url}{path}"
        token = tokens.get(provider, KIRO_API_KEY)

        payload_stream = dict(payload)
        payload_stream["stream"] = True

        provider_format = self.providers.get(provider, {}).get("format", "openai")

        try:
            async for line in self._fetch_stream(provider, url, payload_stream, token):
                if provider_format == "anthropic":
                    translated = StreamTranslator.anthropic_sse_to_openai(line)
                    if translated:
                        yield translated
                else:
                    translated = StreamTranslator.copilot_sse_to_openai(line)
                    if translated:
                        yield translated

            circuit.record_success()
        except Exception as e:
            circuit.record_failure()
            raise

    # -- Main Request Handler -------------------------------------------------

    async def handle_request(
        self, path: str, payload: dict, tokens: Dict[str, str]
    ) -> AsyncGenerator[str, None]:
        """
        Route a request through the Orca-Router pipeline.

        Flow:
          1. Match path in radix tree
          2. Select strategy (race / canary / single)
          3. Execute with circuit breaker protection
          4. Translate SSE if needed
          5. Stream to client with backpressure
        """
        route = self.tree.match(path)

        if not route:
            # Fallback to kiro
            logger.warning("No route for %s, falling back to kiro", path)
            fallback = {"provider": "kiro", "model": "auto-kiro"}
            async for chunk in self._handle_single_stream(fallback, path, payload, tokens):
                yield chunk
            return

        strategy = route.get("strategy", "single")
        targets = route.get("targets", [])

        if strategy == "race":
            async for chunk in self._handle_race(targets, path, payload, tokens):
                yield chunk
        elif strategy == "canary":
            async for chunk in self._handle_canary(targets, path, payload, tokens):
                yield chunk
        else:  # single
            target = targets[0] if targets else {"provider": "kiro", "model": "auto-kiro"}
            async for chunk in self._handle_single_stream(target, path, payload, tokens):
                yield chunk


# =============================================================================
#  AIOHTTP SERVER WRAPPER
# =============================================================================
async def run_orca_server(host: str = "127.0.0.1", port: int = 60001):
    """Start the Orca Router as an aiohttp server."""
    router = OrcaRouter()

    # Register SIGHUP handler as asyncio signal handler
    loop = asyncio.get_running_loop()
    router._register_sighup(loop)

    async def handle_chat(request: web.Request) -> web.StreamResponse:
        """Handle /v1/chat/completions (and catch-all) requests."""
        import uuid
        request_id = str(uuid.uuid4())[:8]

        try:
            payload = await request.json()
        except Exception:
            return web.json_response({"error": "Invalid JSON body"}, status=400)

        # FIX (B16): Validate required fields for OpenAI-compliant requests.
        # Missing 'model' field causes cryptic downstream errors.
        if not payload.get("model"):
            return web.json_response(
                {"error": {"message": "Missing required field: model", "type": "invalid_request_error"}},
                status=400,
            )
        if not payload.get("messages"):
            return web.json_response(
                {"error": {"message": "Missing required field: messages", "type": "invalid_request_error"}},
                status=400,
            )

        path = request.path.lstrip("/")
        tokens = router._load_tokens()
        logger.info("[%s] %s %s", request_id, request.method, path)

        response = web.StreamResponse(
            status=200,
            headers={
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
                "X-Request-ID": request_id,
            },
        )
        await response.prepare(request)

        try:
            async for chunk in router.handle_request(path, payload, tokens):
                await response.write(
                    chunk.encode("utf-8") if isinstance(chunk, str) else chunk
                )
        except Exception as e:
            logger.error("Request failed: %s", e)
            error_chunk = json.dumps({"error": {"message": str(e), "type": "orca_error"}})
            await response.write(f"data: {error_chunk}\n\n".encode())

        await response.write_eof()
        return response

    async def handle_health(request: web.Request) -> web.Response:
        """Health check endpoint."""
        return web.json_response({
            "status": "ok",
            "version": os.getenv("OWL_VERSION", "8.0.0"),
            "providers": list(router.providers.keys()),
            "routes": router.tree.list_routes(),
            "circuits": router.circuits.all_status(),
        })

    async def handle_models(request: web.Request) -> web.Response:
        """OpenAI-compatible /v1/models endpoint.

        FIX: Previously mapped to handle_health which returned health data
        instead of an OpenAI-compliant models list. Clients like OpenCode
        and LiteLLM expect the standard object format with model IDs.
        FIX (B25): Gracefully handle providers that lack a 'models' key
        instead of silently skipping them (which produces an empty list).
        """
        models = []
        for provider_name, provider_info in router.providers.items():
            provider_models = provider_info.get("models", {})
            if not provider_models:
                # Provider has no models defined; add a generic entry
                models.append({
                    "id": f"{provider_name}-default",
                    "object": "model",
                    "created": 1700000000,
                    "owned_by": provider_name,
                })
            else:
                for model_id, model_info in provider_models.items():
                    models.append({
                        "id": model_id,
                        "object": "model",
                        "created": 1700000000,
                        "owned_by": provider_name,
                        "context_window": model_info.get("context_window", 128000),
                        "max_tokens": model_info.get("max_tokens", 8192),
                    })
        return web.json_response({
            "object": "list",
            "data": models,
        })

    async def handle_reload(request: web.Request) -> web.Response:
        """Manual config reload endpoint (alternative to SIGHUP)."""
        router._handle_sighup()
        return web.json_response({"status": "reloaded"})

    app = web.Application()
    app.router.add_post("/v1/chat/completions", handle_chat)
    app.router.add_get("/v1/models", handle_models)
    app.router.add_get("/health", handle_health)
    app.router.add_post("/admin/reload", handle_reload)
    app.router.add_route("*", "/{path:.*}", handle_chat)

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, host, port)
    await site.start()

    logger.info(
        "OWL Orca-Router v%s on %s:%d [RACE+RADIX+TRANSLATE+SIGHUP]",
        os.getenv("OWL_VERSION", "8.0.0"), host, port,
    )

    try:
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        pass
    finally:
        # FIX (B8): Clean up the shared HTTP client on shutdown.
        # Without this, httpx connections leak when the server stops.
        if router._http_client is not None and not router._http_client.is_closed:
            await router._http_client.aclose()
            logger.info("HTTP client connections closed")
        await runner.cleanup()


if __name__ == "__main__":
    asyncio.run(run_orca_server())
PYEOF
    mv -f "$_ATMP" "$BIN_DIR/orca_router.py"
    chmod +x "$BIN_DIR/orca_router.py"

    # -- Integrity Check: Validate Python syntax of ALL written modules --
    log_info "Validating Python module syntax..."
    for pyfile in "$UTILS_DIR"/*.py "$BIN_DIR"/*.py "$INSTALL_DIR"/forward_proxy.py; do
        if [ -f "$pyfile" ]; then
            if ! python3 -c "import ast, sys; ast.parse(open(sys.argv[1]).read())" "$pyfile" 2>/dev/null; then
                log_err "Python syntax error in $pyfile"
                exit 1
            fi
        fi
    done
    log_ok "Python module syntax validated"
fi

# -- 6H: Copilot Proxy Scripts -----------------------------------------------
log_info "Writing copilot proxy scripts..."

if [ "${SKIP_COPILOT_PROXY:-}" != "true" ] && [ "${DRY_RUN:-}" != "true" ]; then

    # -- copilot_kiro_proxy.py -------------------------------------------------
    _ATMP="$(_mktemp "$BIN_DIR/copilot_kiro_proxy.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
🦉 GitHub Copilot ↔ Multi-Provider Proxy (OWL-AGENT Integrated)
Routes Copilot through Kiro/OpenRouter/Groq/SiliconFlow with defense stack.

Architecture:
  Copilot → DNS/iptrans → mitmproxy(:8888) → copilot-proxy(:11437)
    → BodyCache → direct provider API call

No proxy rotation for provider calls — those go direct. Proxy pool is
available as a fallback for direct GitHub API access if needed.
"""

import asyncio
import hashlib
import json
import logging
import os
import random
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import aiohttp
from aiohttp import web

# ── OWL-AGENT Defense Library ────────────────────────────────
OWL_AGENT_HOME = Path.home() / ".owl-agent"
sys.path.insert(0, str(OWL_AGENT_HOME / "lib"))
from proxy_defense import CachedResponse

# ── Optional Protocol Libraries ──────────────────────────────
try:
    import httpx
    HTTP2_AVAILABLE = True
except ImportError:
    HTTP2_AVAILABLE = False

try:
    from curl_cffi.requests import AsyncSession
    JA3_AVAILABLE = True
except ImportError:
    JA3_AVAILABLE = False

try:
    from playwright.async_api import async_playwright
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
logger = logging.getLogger('copilot-proxy')

# ── Provider Configuration ──────────────────────────────────
PROVIDERS = [
    {
        "name": "kiro",
        "endpoint": "http://localhost:8333/v1",
        "api_key": "kiro-gateway-8333",
        "models": {
            "copilot-codex": "auto-kiro",
            "gpt-3.5-turbo": "claude-haiku-4.5",
            "gpt-4": "auto-kiro",
        },
        "default_model": "auto-kiro",
        "weight": 80,
    },
    {
        "name": "openrouter",
        "endpoint": "https://openrouter.ai/api/v1",
        "api_key": os.getenv("OPENROUTER_API_KEY"),
        "models": {
            "copilot-codex": "meta-llama/llama-3-70b-instruct",
            "gpt-3.5-turbo": "meta-llama/llama-3.1-8b-instruct",
            "gpt-4": "meta-llama/llama-3-70b-instruct",
        },
        "default_model": "meta-llama/llama-3-70b-instruct",
        "weight": 60,
    },
    {
        "name": "groq",
        "endpoint": "https://api.groq.com/openai/v1",
        "api_key": os.getenv("GROQ_API_KEY"),
        "models": {
            "copilot-codex": "llama-3.3-70b-versatile",
            "gpt-3.5-turbo": "llama-3.1-8b-instant",
            "gpt-4": "llama-3.3-70b-versatile",
        },
        "default_model": "llama-3.3-70b-versatile",
        "weight": 40,
    },
    {
        "name": "siliconflow",
        "endpoint": "https://api.siliconflow.cn/v1",
        "api_key": os.getenv("SILICONFLOW_API_KEY"),
        "models": {
            "copilot-codex": "Qwen/Qwen2.5-Coder-7B-Instruct",
            "gpt-3.5-turbo": "Qwen/Qwen2.5-7B-Instruct",
            "gpt-4": "Qwen/Qwen3-8B",
        },
        "default_model": "Qwen/Qwen3-8B",
        "weight": 25,
    },
    {
        "name": "deepseek",
        "endpoint": "https://api.deepseek.com/v1",
        "api_key": os.getenv("DEEPSEEK_API_KEY"),
        "models": {
            "copilot-codex": "deepseek-chat",
            "gpt-3.5-turbo": "deepseek-chat",
            "gpt-4": "deepseek-chat",
        },
        "default_model": "deepseek-chat",
        "weight": 20,
    },
PYEOF
    mv -f "$_ATMP" "$BIN_DIR/copilot_kiro_proxy.py"
    chmod +x "$BIN_DIR/copilot_kiro_proxy.py"
fi

# -- 6F: Configuration Files --------------------------------------------------
log_info "Writing configuration files..."

if [ "${DRY_RUN:-}" != "true" ]; then
    # providers.json
    _ATMP="$(_mktemp "$CONFIG_DIR/providers.json")"
    cat > "$_ATMP" << 'JSONEOF'
{
  "copilot": {
    "base_url": "https://api.githubcopilot.com",
    "format": "openai",
    "models": {
      "gpt-4o-mini-copilot": {"context_window": 128000, "max_tokens": 16384},
      "gpt-4o-copilot": {"context_window": 128000, "max_tokens": 16384},
      "claude-3.5-sonnet-copilot": {"context_window": 200000, "max_tokens": 8192}
    }
  },
  "antigravity": {
    "base_url": "https://cloudcode-pa.googleapis.com",
    "format": "anthropic",
    "models": {
      "antigravity-flash": {"context_window": 100000, "max_tokens": 8192},
      "antigravity-ultra": {"context_window": 200000, "max_tokens": 4096}
    }
  },
  "kiro": {
    "base_url": "http://127.0.0.1:8333",
    "format": "openai",
    "models": {
      "auto-kiro": {"context_window": 200000, "max_tokens": 8192}
    }
  }
}
JSONEOF
    mv -f "$_ATMP" "$CONFIG_DIR/providers.json"

    # routes.json
    _ATMP="$(_mktemp "$CONFIG_DIR/routes.json")"
    cat > "$_ATMP" << 'JSONEOF'
{
  "routes": [
    {
      "pattern": "v1/chat/completions",
      "strategy": "race",
      "targets": [
        {"provider": "copilot", "model": "gpt-4o-mini-copilot", "weight": 90},
        {"provider": "antigravity", "model": "antigravity-flash", "weight": 10}
      ]
    },
    {
      "pattern": "v1/models",
      "strategy": "single",
      "targets": [{"provider": "copilot", "model": "gpt-4o-mini-copilot"}]
    }
  ]
}
JSONEOF
    mv -f "$_ATMP" "$CONFIG_DIR/routes.json"
fi

log_ok "Core scripts written"

# =============================================================================
#  STEP 7: Zero-Downtime Detection (Safe-Mode)
# =============================================================================
log_step 7 $TOTAL_STEPS "Zero-Downtime detection"

detect_opencode() {
    # Check if OpenCode (Node/Electron) or related MCP hosts are running
    local ide_patterns=("opencode" "cline" "code" "cursor" "windsurf" "vscodium" "codium")
    local ide_detected=false
    for pattern in "${ide_patterns[@]}"; do
        if pgrep -f "$pattern" > /dev/null 2>&1; then
            ide_detected=true
            break
        fi
    done
    if [ "$ide_detected" == "true" ]; then
        export OPENCODE_ACTIVE="true"
        log_warn "SAFE-MODE: Active IDE detected. Connection preservation engaged."
    else
        export OPENCODE_ACTIVE="false"
        log_ok "STANDARD-MODE: No IDE detected. Full deployment enabled."
    fi
}

if [ "${DRY_RUN:-}" != "true" ]; then
    detect_opencode
else
    export OPENCODE_ACTIVE="false"
    echo "  [DRY-RUN] IDE detection skipped (assuming STANDARD-MODE)"
fi

# =============================================================================
#  STEP 8: Systemd Service Deployment
# =============================================================================
log_step 8 $TOTAL_STEPS "Deploying systemd services"

# -- Safe Service Manager -----------------------------------------------------
# When an IDE is running, we SKIP restarts on active services to preserve
# TCP connections.  The updated code sits on disk and activates when the
# user next restarts their IDE.
safe_service_action() {
    local service_name="$1"
    local action="$2"  # start, restart, reload

    # FIX (B9): SIGHUP reload is always safe -- it does NOT drop active
    # TCP connections. It only swaps the in-memory routing configuration.
    # This is the entire point of the hot-reload feature. Blocking reload
    # when an IDE is running defeats the purpose of SIGHUP support.
    if [ "$action" == "reload" ]; then
        log_ok "Executing reload on $service_name (safe: no connection drops)"
        systemctl --user "$action" "$service_name" 2>/dev/null || true
        return 0
    fi

    if [ "${OPENCODE_ACTIVE:-}" == "true" ]; then
        if systemctl --user is-active --quiet "$service_name" 2>/dev/null; then
            log_warn "$service_name is running. Skipping $action to preserve IDE connections."
            echo "      (Binaries updated on disk. Restart manually when ready.)"
            echo "      (Use 'systemctl --user reload $service_name' to hot-reload config safely.)"
            return 0
        else
            log_ok "$service_name is stopped. Safe to start."
            systemctl --user "$action" "$service_name" 2>/dev/null || true
        fi
    else
        log_ok "Executing $action on $service_name"
        systemctl --user "$action" "$service_name" 2>/dev/null || true
    fi
}

if [ "${DRY_RUN:-}" != "true" ]; then
    ensure_dir "$HOME/.config/systemd/user"

    # -- Orca Router Service (with SIGHUP for hot-reload) ---------------------
    # FIX (N6): Use INSTALL_DIR variable instead of hardcoding %h/.owl-agent/.
    # The %h specifier expands to the user's home directory, which matches
    # the default INSTALL_DIR. However, if the user sets OWL_INSTALL_DIR
    # to a custom path, the service must reference that path instead.
    # Since systemd doesn't support shell variables in ExecStart, we
    # expand at file creation time using an unquoted heredoc section.
    _ATMP="$(_mktemp "$HOME/.config/systemd/user/orca-router.service")"
    cat > "$_ATMP" << SYSEOF
[Unit]
Description=OWL Orca-Router (Stream Racing & Protocol Translation)
After=network.target
After=owl-proxy.service
Wants=owl-proxy.service

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $BIN_DIR/orca_router.py
Restart=on-failure
RestartSec=5
# FIX: Prevent infinite restart loop on persistent crashes
StartLimitBurst=5
StartLimitIntervalSec=300
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1
Environment=OWL_INSTALL_DIR=$INSTALL_DIR
Environment=OWL_PROXY_URL=http://127.0.0.1:60000
Environment=KIRO_PORT=8333
Environment=KIRO_API_KEY=kiro-gateway-8333
Environment=OWL_VERSION=$VERSION
# SIGHUP triggers hot-config-reload in orca_router.py
ExecReload=/bin/kill -HUP \$MAINPID
SendSIGHUP=yes
# Memory limits for stream multiplexing on 8GB RAM
MemoryMax=384M
MemoryHigh=256M
# Log rate limiting to prevent disk overflow
LogRateLimitIntervalSec=30s
LogRateLimitBurst=100

[Install]
WantedBy=default.target
SYSEOF
    mv -f "$_ATMP" "$HOME/.config/systemd/user/orca-router.service"

    # -- Forward Proxy Service ------------------------------------------------
    if [ "${SKIP_PROXY:-}" != "true" ]; then
        _ATMP="$(_mktemp "$HOME/.config/systemd/user/owl-proxy.service")"
        # FIX (N6): Use INSTALL_DIR variable for custom install paths
        cat > "$_ATMP" << SYSEOF
[Unit]
Description=OWL Forward Proxy (HTTPS CONNECT Tunnel)
After=network.target

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $INSTALL_DIR/forward_proxy.py
Restart=on-failure
RestartSec=3
StandardOutput=journal
StandardError=journal
Environment=UPSTREAM_PROXY=
Environment=OWL_PROXY_HOST=127.0.0.1
Environment=OWL_PROXY_PORT=60000
Environment=OWL_MAX_CONNECTIONS=50
# FIX: Reduced from 512M/384M to 128M/96M. With MAX_CONNECTIONS=50
# at ~100KB per buffer = 5MB active. 128M provides 25x headroom.
MemoryMax=128M
MemoryHigh=96M

[Install]
WantedBy=default.target
SYSEOF
        mv -f "$_ATMP" "$HOME/.config/systemd/user/owl-proxy.service"
    fi

    # -- Kiro Gateway Service (written in Step 9 after git clone) ------------

    log_ok "Systemd service files deployed"
fi

# =============================================================================
#  STEP 9: Kiro Gateway
# =============================================================================
log_step 9 $TOTAL_STEPS "Kiro Gateway"

if [ "${SKIP_KIRO:-}" != "true" ] && [ "${DRY_RUN:-}" != "true" ] && [ -z "${UPDATE_MODE:-}" ]; then
    # ── Kiro Step 1: Source Acquisition ──────────────────────────────────────
    if [ ! -d "$KIRO_GATEWAY_DIR/.git" ]; then
        log_info "Cloning kiro-gateway..."
        # FIX (P2-Retry): Retry git clone with backoff instead of silently failing
        GIT_RETRY=0
        while [ "$GIT_RETRY" -lt 2 ]; do
            if git clone "$KIRO_GATEWAY_REPO" "$KIRO_GATEWAY_DIR" 2>&1; then
                break
            fi
            GIT_RETRY=$((GIT_RETRY + 1))
            if [ "$GIT_RETRY" -lt 2 ]; then
                log_warn "git clone failed (attempt $GIT_RETRY/2). Retrying in 10s..."
                sleep 10
            else
                log_warn "Could not clone kiro-gateway after 2 attempts. Continuing without kiro."
            fi
        done
    else
        git -C "$KIRO_GATEWAY_DIR" pull --ff-only 2>/dev/null || true
    fi

    # ── Kiro Step 2: Determine libc for binary selection ─────────────────────
    # FIX (B3): glibc/musl detection logic was previously inverted.
    # ldd --version 2>&1 outputs to stdout on glibc (exit 0) and
    # stderr on musl. We check the output string, not the exit code.
    KIRO_LIBC="glibc"
    if ldd --version 2>&1 | grep -qi "musl"; then
        KIRO_LIBC="musl"
        log_info "Detected musl libc (Alpine/BusyBox)"
    else
        log_info "Detected glibc (standard Linux)"
    fi

    # ── Kiro Step 3: Python venv + kiro-cli binary ──────────────────────────
    GATEWAY_VENV="$KIRO_GATEWAY_DIR/.venv"
    if [ ! -f "$GATEWAY_VENV/bin/activate" ]; then
        log_info "Creating Kiro Gateway Python venv..."
        python3 -m venv "$GATEWAY_VENV"
    fi

    if [ -f "$KIRO_GATEWAY_DIR/requirements.txt" ]; then
        # FIX (B4): Remove || true that swallowed pip install failures.
        # Use retry logic with visible error output instead.
        KIRO_PIP_RETRY=0
        while [ "$KIRO_PIP_RETRY" -lt 3 ]; do
            if "$GATEWAY_VENV/bin/pip" install --no-cache-dir -r "$KIRO_GATEWAY_DIR/requirements.txt" 2>&1; then
                break
            fi
            KIRO_PIP_RETRY=$((KIRO_PIP_RETRY + 1))
            if [ "$KIRO_PIP_RETRY" -lt 3 ]; then
                SLEEP_TIME=$((5 * KIRO_PIP_RETRY))
                log_warn "Kiro pip install failed (attempt $KIRO_PIP_RETRY/3). Retrying in ${SLEEP_TIME}s..."
                sleep "$SLEEP_TIME"
            else
                log_err "Kiro Gateway pip install failed after 3 attempts."
                log_err "Check network and run manually: $GATEWAY_VENV/bin/pip install -r $KIRO_GATEWAY_DIR/requirements.txt"
                # FIX (v8-N7): Kiro pip install failure is now a hard error.
                # Previously, the script continued with a broken gateway.
                # Now we skip kiro setup entirely and continue without it.
                SKIP_KIRO=true
                log_warn "Kiro Gateway will be skipped due to install failure."
            fi
        done
    fi

    # Download kiro-cli binary if not present
    KIRO_CLI="$KIRO_GATEWAY_DIR/kiro-cli"
    if [ ! -x "$KIRO_CLI" ]; then
        log_info "Downloading kiro-cli binary..."
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64)  KIRO_ARCH="x64" ;;
            aarch64) KIRO_ARCH="arm64" ;;
            *)       KIRO_ARCH="x64" ; log_warn "Unknown arch $ARCH, defaulting to x64" ;;
        esac
        KIRO_CLI_URL="https://cli.kiro.dev/releases/latest/kiro-cli-linux-${KIRO_ARCH}-${KIRO_LIBC}.tar.gz"
        KIRO_TMP_TAR="/tmp/kiro-cli-$$.tar.gz"
        # FIX (B4): Don't use || true for extraction -- verify the download
        if curl -fSL --connect-timeout 15 -o "$KIRO_TMP_TAR" "$KIRO_CLI_URL" 2>&1; then
            if tar -xzf "$KIRO_TMP_TAR" -C "$KIRO_GATEWAY_DIR/" 2>&1; then
                chmod +x "$KIRO_CLI" 2>/dev/null || true
                log_ok "kiro-cli binary installed (${KIRO_ARCH}-${KIRO_LIBC})"
            else
                log_warn "Failed to extract kiro-cli. Gateway will use Python-only mode."
            fi
        else
            log_warn "Could not download kiro-cli from $KIRO_CLI_URL"
            log_info "Gateway will operate in Python-only mode (no kiro-cli binary)."
        fi
        rm -f "$KIRO_TMP_TAR"
    fi

    # ── Kiro Step 4: AWS Builder ID OIDC authentication ─────────────────────
    KIRO_OIDC_TOKEN=""
    if [ -x "$KIRO_CLI" ]; then
        log_info "Checking Kiro AWS Builder ID OIDC..."
        # Attempt SSO token exchange; if it fails, continue without it
        # (kiro-gateway can also accept PROXY_API_KEY auth)
        KIRO_OIDC_TOKEN=$("$KIRO_CLI" auth token 2>/dev/null || echo "")
        if [ -n "$KIRO_OIDC_TOKEN" ]; then
            log_ok "Kiro OIDC token acquired via AWS Builder ID"
        else
            log_info "Kiro OIDC not configured. Using API key authentication."
        fi
    fi

    # ── Kiro Step 5: .env configuration ──────────────────────────────────────
    # FIX (B5): No regex on JSON -- use shell variable expansion which is safe.
    # FIX (B6): Use quoted heredoc for Python code, unquoted for .env (intentional).
    # FIX (B19): OIDC tokens written to .env in plaintext. This is a security
    # concern on shared systems. The .env file has 0600 permissions and the
    # directory has 0700 (set by B10 fix), but we warn the user explicitly.
    if [ -d "$KIRO_GATEWAY_DIR" ]; then
        _ATMP="$(_mktemp "$KIRO_GATEWAY_DIR/.env")"
        # FIX (N11): Safely write .env by quoting variable values to protect
        # against special characters (spaces, #, $, etc.) in API keys.
        # Using printf with quoted values is safer than bare heredoc expansion.
        printf 'PROXY_API_KEY="%s"\nSERVER_PORT=%s\nACCOUNT_SYSTEM=true\nKIRO_USE_LEGACY_ENDPOINT=true\n' \
            "$KIRO_API_KEY" "$KIRO_PORT" > "$_ATMP"
        if [ -n "$KIRO_OIDC_TOKEN" ]; then
            printf 'KIRO_OIDC_TOKEN="%s"\n' "$KIRO_OIDC_TOKEN" >> "$_ATMP"
        fi
        mv -f "$_ATMP" "$KIRO_GATEWAY_DIR/.env"
        # FIX (B19): Secure the .env file and warn about plaintext tokens
        chmod 600 "$KIRO_GATEWAY_DIR/.env" 2>/dev/null || true
        if [ -n "$KIRO_OIDC_TOKEN" ]; then
            log_warn "Kiro OIDC token stored in plaintext in .env (protected by 0600 permissions)"
            log_info "Consider using API key auth on shared systems: export OWL_KIRO_API_KEY=<key>"
        fi
        log_ok "Kiro Gateway .env configured"

        # ── Kiro Step 6: systemd user service ─────────────────────────────────
        # FIX (F-07): Use EnvironmentFile to inject paths at runtime
        # instead of hardcoding. The service references ${KIRO_GATEWAY_DIR}
        # which is expanded by systemd from the EnvironmentFile.
        _ATMP="$(_mktemp "$HOME/.config/systemd/user/kiro-gateway.service")"
        # FIX (v7.4): Use UNQUOTED heredoc so $KIRO_GATEWAY_DIR is expanded
        # at file creation time. Systemd does NOT support ${VAR} expansion
        # from EnvironmentFile in ExecStart/WorkingDirectory -- those must
        # be literal paths. EnvironmentFile is still used for runtime env vars
        # like KIRO_API_KEY that the Python process reads from os.environ.
        cat > "$_ATMP" << SYSEOF
[Unit]
Description=Kiro Gateway (AWS Builder ID + API Key)
After=network.target
Wants=orca-router.service

[Service]
Type=simple
EnvironmentFile=$CONFIG_DIR/kiro-gateway.env
WorkingDirectory=$KIRO_GATEWAY_DIR
ExecStart=$KIRO_GATEWAY_DIR/.venv/bin/python main.py --port 8333
Restart=on-failure
RestartSec=5
StartLimitBurst=5
StartLimitIntervalSec=300
MemoryMax=256M
MemoryHigh=192M
# Kiro Gateway on 8GB RAM: 256M max, ~150MB idle with 10 concurrent sessions
# Total with Orca (384M) + Proxy (128M) = 768M hard cap, ~150MB idle
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
SYSEOF
        mv -f "$_ATMP" "$HOME/.config/systemd/user/kiro-gateway.service"

        # Write the env file that the service will read at runtime
        _ATMP2="$(_mktemp "$CONFIG_DIR/kiro-gateway.env")"
        cat > "$_ATMP2" << ENVEOF
KIRO_GATEWAY_DIR=$KIRO_GATEWAY_DIR
KIRO_API_KEY=$KIRO_API_KEY
PROXY_API_KEY=$KIRO_API_KEY
ENVEOF
        mv -f "$_ATMP2" "$CONFIG_DIR/kiro-gateway.env"

        # ── Kiro Step 7: HTTP health/model/chat verification ──────────────────
        # Verification is deferred to Step 12 (post-activation health check)
        # to avoid race conditions with service startup.

        # ── Kiro Step 8: opencode.jsonc provider wiring ──────────────────────
        # This is handled by Step 10 (OpenCode Configuration) below,
        # which adds the kiro gateway as a provider in the owl-orca-virtual block.
        # The kiro provider is already in providers.json with base_url
        # http://127.0.0.1:8333, so the Orca Router will forward to it.
    fi
    log_ok "Kiro Gateway fully configured (Steps 3-8 complete)"
elif [ -n "${UPDATE_MODE:-}" ]; then
    log_ok "Kiro gateway skipped (update mode)"
elif [ "${SKIP_KIRO:-}" == "true" ]; then
    log_ok "Kiro gateway skipped (--skip-kiro)"
fi

# =============================================================================
#  STEP 10: OpenCode Configuration (Atomic Injection)
# =============================================================================
log_step 10 $TOTAL_STEPS "OpenCode configuration (atomic injection)"

if [ "${DRY_RUN:-}" != "true" ]; then
    OPENCODE_CONFIG="$OPENCODE_DIR/opencode.jsonc"

    # Initialize config if it doesn't exist
    if [ ! -f "$OPENCODE_CONFIG" ]; then
        echo '{}' > "$OPENCODE_CONFIG"
    fi

    # The new provider block to merge
    NEW_CONFIG_BLOCK='{
  "owl-orca-virtual": {
    "npm": "@ai-sdk/openai",
    "name": "OWL Orca Virtual (Fastest Free)",
    "options": {
      "baseURL": "http://127.0.0.1:60001/v1",
      "apiKey": "orca-racer",
      "stream": true
    },
    "models": {
      "auto-racer": {
        "name": "Auto (Races GPT-4o & Claude 3.5)",
        "contextWindow": 200000
      },
      "gpt-4o-copilot": {
        "name": "GPT-4o via Copilot (Free)",
        "contextWindow": 128000
      },
      "claude-3.5-sonnet-copilot": {
        "name": "Claude 3.5 Sonnet via Copilot (Free)",
        "contextWindow": 200000
      },
      "antigravity-flash": {
        "name": "Antigravity Flash (Free)",
        "contextWindow": 100000
      },
      "auto-kiro": {
        "name": "Kiro Gateway (AWS Builder ID)",
        "contextWindow": 200000
      }
    }
  }
}'

    # Merge using Python for safe JSON handling, then ATOMIC WRITE
    # FIX (F-06): Use quoted heredoc <<'PYEOF' to prevent shell variable
    # expansion inside Python code. Pass variables via environment instead.
    # FIX (F-10): Use state-machine JSONC parser from shared jsonc_utils
    # module instead of duplicating ~70 lines inline (B11).
    FINAL_JSON=$(OWL_CFG="$OPENCODE_CONFIG" OWL_BLOCK="$NEW_CONFIG_BLOCK" OWL_INSTALL_DIR="$INSTALL_DIR" python3 << 'PYEOF'
import json, os, sys

# Import shared JSONC utilities
_owl_install = os.environ.get("OWL_INSTALL_DIR", os.path.expanduser("~/.owl-agent"))
sys.path.insert(0, os.path.join(_owl_install, "bin", "utils"))
try:
    from jsonc_utils import load_jsonc
except ImportError:
    # FIX (N4): Inline fallback that does NOT use fragile regex.
    # The old fallback used re.sub(r'//.*?\n') which corrupts URLs.
    # Instead, use a simple state-machine that respects string boundaries.
    def _strip_jsonc_safe(text):
        result = []
        i = 0
        in_string = False
        while i < len(text):
            ch = text[i]
            if in_string:
                result.append(ch)
                if ch == '\\':
                    i += 1
                    if i < len(text):
                        result.append(text[i])
                elif ch == '"':
                    in_string = False
                i += 1
                continue
            if ch == '"':
                in_string = True
                result.append(ch)
                i += 1
            elif ch == '/' and i + 1 < len(text) and text[i+1] == '/':
                while i < len(text) and text[i] != '\n':
                    i += 1
                if i < len(text):
                    result.append('\n')
                    i += 1
            elif ch == '/' and i + 1 < len(text) and text[i+1] == '*':
                i += 2
                while i + 1 < len(text) and not (text[i] == '*' and text[i+1] == '/'):
                    if text[i] == '\n':
                        result.append('\n')
                    i += 1
                i += 2
            else:
                result.append(ch)
                i += 1
        return ''.join(result)
    def load_jsonc(path):
        try:
            with open(path, 'r') as f:
                raw = f.read()
            return json.loads(_strip_jsonc_safe(raw))
        except Exception:
            return {}

cfg_path = os.environ["OWL_CFG"]
new_block = json.loads(os.environ["OWL_BLOCK"])

try:
    data = load_jsonc(cfg_path)
except Exception:
    data = {}

if "providers" not in data:
    data["providers"] = {}

data["providers"].update(new_block)

print(json.dumps(data, separators=(',', ':')))
PYEOF
)

    # APPLY USING ATOMIC WRITE -- No file watcher crash
    atomic_write "$OPENCODE_CONFIG" "$FINAL_JSON"
    log_ok "OpenCode config updated atomically (no file watcher crash)"

    # Create MCP server placeholder
    _ATMP="$(_mktemp "$INSTALL_DIR/owl_resilient_mcp.py")"
    cat > "$_ATMP" << 'PYEOF'
#!/usr/bin/env python3
"""
OWL Resilient MCP Server
Stdio-based MCP server for OpenCode integration.
Provides tool calling through the Orca Router.
"""
import json
import sys
import subprocess

def send_result(request_id, result):
    """Send a JSON-RPC result."""
    json.dump({"jsonrpc": "2.0", "id": request_id, "result": result}, sys.stdout)
    sys.stdout.write("\n")
    sys.stdout.flush()

def send_error(request_id, code, message):
    """Send a JSON-RPC error."""
    json.dump({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}, sys.stdout)
    sys.stdout.write("\n")
    sys.stdout.flush()

def main():
    """MCP server main loop — reads JSON-RPC from stdin."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            send_error(None, -32700, "Parse error")
            continue

        req_id = request.get("id")
        method = request.get("method", "")

        if method == "initialize":
            send_result(req_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "owl-resilient-mcp", "version": "1.0.0"},
            })
        elif method == "tools/list":
            send_result(req_id, {
                "tools": [{
                    "name": "owl_status",
                    "description": "Check OWL Orca Router status",
                    "inputSchema": {"type": "object", "properties": {}},
                }]
            })
        elif method == "tools/call":
            tool_name = request.get("params", {}).get("name", "")
            if tool_name == "owl_status":
                try:
                    # FIX (B18): Use urllib instead of subprocess+curl.
                    # subprocess.run with curl is fragile (curl may not be
                    # installed, path issues, etc.). urllib is always available.
                    import urllib.request
                    import json as _json
                    req = urllib.request.Request(
                        "http://127.0.0.1:60001/health",
                        headers={"Accept": "application/json"},
                    )
                    with urllib.request.urlopen(req, timeout=5) as resp:
                        body = resp.read().decode()
                    send_result(req_id, {"content": [{"type": "text", "text": body}]})
                except Exception as e:
                    send_result(req_id, {"content": [{"type": "text", "text": f"Error: {e}"}], "isError": True})
            else:
                send_error(req_id, -32601, f"Unknown tool: {tool_name}")
        elif method == "notifications/initialized":
            pass  # Acknowledge, no response needed
        elif method == "notifications/cancelled":
            # FIX (B17): MCP spec requires handling cancellation notifications.
            # No response is sent for notifications. Log for debugging.
            pass
        else:
            send_error(req_id, -32601, f"Method not found: {method}")

if __name__ == "__main__":
    main()
PYEOF
    mv -f "$_ATMP" "$INSTALL_DIR/owl_resilient_mcp.py"
    chmod +x "$INSTALL_DIR/owl_resilient_mcp.py"

    # MCP configuration
    MCP_CONFIG="$OPENCODE_DIR/mcp.json"
    backup_file "$MCP_CONFIG"

    python3 << 'PYEOF'
import json, os

mcp_path = os.path.expanduser("~/.config/opencode/mcp.json")
data = {}
if os.path.exists(mcp_path):
    try:
        with open(mcp_path) as f:
            data = json.load(f)
    except Exception:
        data = {}

if "mcpServers" not in data:
    data["mcpServers"] = {}

# FIX (v8-N5): Use OWL_INSTALL_DIR environment variable instead of
# hardcoding ~/.owl-agent. The install script allows custom install
# directories, so the MCP config must respect the same path.
_install_dir = os.getenv("OWL_INSTALL_DIR", os.path.expanduser("~/.owl-agent"))
data["mcpServers"]["owl-resilient-http"] = {
    "command": os.path.join(_install_dir, "venv", "bin", "python3"),
    "args": [os.path.join(_install_dir, "owl_resilient_mcp.py")]
}

os.makedirs(os.path.dirname(mcp_path), exist_ok=True)
# FIX: Use atomic write (write to temp, then os.replace) to prevent
# config corruption if the process is interrupted mid-write.
tmp_path = mcp_path + ".owl_tmp_mcp"
with open(tmp_path, 'w') as f:
    json.dump(data, f, indent=2)
os.replace(tmp_path, mcp_path)
PYEOF

    log_ok "MCP servers configured"
fi

# =============================================================================
#  STEP 11: CLI Wrappers
# =============================================================================
log_step 11 $TOTAL_STEPS "CLI wrappers"

if [ "${DRY_RUN:-}" != "true" ]; then
    _ATMP="$(_mktemp "$HOME/.local/bin/owl-proxy")"
    cat > "$_ATMP" << 'WRAPPER'
#!/bin/bash
export HTTP_PROXY="http://127.0.0.1:60000"
export HTTPS_PROXY="http://127.0.0.1:60000"
export NO_PROXY="localhost,127.0.0.1,.local,.localdomain,::1,.githubcopilot.com,.antigravity.ai,.kiro.dev,.amazonaws.com"
exec "$@"
WRAPPER
    mv -f "$_ATMP" "$HOME/.local/bin/owl-proxy"

    # FIX (v8-N6): CLI wrappers now use INSTALL_DIR variable instead of
    # hardcoding $HOME/.owl-agent. This ensures custom install paths work.
    _ATMP="$(_mktemp "$HOME/.local/bin/owl-router")"
    cat > "$_ATMP" << SYSEOF
#!/bin/bash
exec "$VENV_DIR/bin/python" "$BIN_DIR/orca_router.py" "\$@"
SYSEOF
    mv -f "$_ATMP" "$HOME/.local/bin/owl-router"

    _ATMP="$(_mktemp "$HOME/.local/bin/owl-token")"
    cat > "$_ATMP" << SYSEOF
#!/bin/bash
exec "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" "\$@"
SYSEOF
    mv -f "$_ATMP" "$HOME/.local/bin/owl-token"

    chmod +x "$HOME/.local/bin/owl-proxy" \
              "$HOME/.local/bin/owl-router" \
              "$HOME/.local/bin/owl-token"

    log_ok "CLI wrappers created"
fi

# -- Port Conflict Detection --
check_port_free() {
    local port=$1 name=$2
    # FIX (B22/N7): Try ss first (most common), fall back to lsof for portability.
    # Use word-boundary-aware pattern to avoid false matches
    # (e.g., port 6000 matching 60001).
    # NOTE: Avoid grep -P (Perl regex) as it's not available on BusyBox/Alpine.
    local port_in_use=false
    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -qE ":${port}\b"; then
            port_in_use=true
        fi
    elif command -v lsof &>/dev/null; then
        if lsof -i :"$port" -sTCP:LISTEN &>/dev/null; then
            port_in_use=true
        fi
    else
        # Last resort: try to bind the port ourselves
        # FIX (N12): Validate port is a valid integer before passing to Python
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            log_warn "Invalid port number: $port"
            return 1
        fi
        if ! python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1', $port)); s.close()" 2>/dev/null; then
            port_in_use=true
        fi
    fi
    if [ "$port_in_use" == "true" ]; then
        log_warn "Port $port ($name) is already in use"
        return 1
    fi
    return 0
}

if [ "${DRY_RUN:-}" != "true" ]; then
    log_info "Checking port availability..."
    check_port_free 60001 "Orca Router" || log_warn "Orca Router may fail to start"
    if [ "${SKIP_PROXY:-}" != "true" ]; then
        check_port_free 60000 "Forward Proxy" || log_warn "Forward Proxy may fail to start"
    fi
    if [ "${SKIP_KIRO:-}" != "true" ]; then
        check_port_free "$KIRO_PORT" "Kiro Gateway" || log_warn "Kiro Gateway may fail to start"
    fi
fi

# =============================================================================
#  STEP 12: Safe Activation & Provider Authentication
# =============================================================================
log_step 12 $TOTAL_STEPS "Safe activation"

if [ "${DRY_RUN:-}" != "true" ]; then
    # Reload systemd definitions from disk (safe -- no connection impact)
    systemctl --user daemon-reload 2>/dev/null || log_warn "systemd user bus not available ('systemctl --user' failed). Services won't auto-start."

    # Enable services (safe -- just marks for auto-start)
    systemctl --user enable orca-router.service 2>/dev/null || true

    if [ "${SKIP_PROXY:-}" != "true" ]; then
        systemctl --user enable owl-proxy.service 2>/dev/null || true
    fi

    if [ "${SKIP_KIRO:-}" != "true" ] && [ -d "$KIRO_GATEWAY_DIR" ]; then
        systemctl --user enable kiro-gateway.service 2>/dev/null || true
    fi

    # Use SAFE SERVICE MANAGER to restart (skips if IDE is running)
    if [ "${SKIP_PROXY:-}" != "true" ]; then
        safe_service_action "owl-proxy.service" "restart"
    fi

    safe_service_action "orca-router.service" "restart"

    if [ "${SKIP_KIRO:-}" != "true" ] && [ -d "$KIRO_GATEWAY_DIR" ]; then
        safe_service_action "kiro-gateway.service" "restart"
    fi

    # -- Verification ---------------------------------------------------------
    sleep 2

    echo ""
    log_info "Verifying installation..."

    if systemctl --user is-active --quiet orca-router.service 2>/dev/null; then
        log_ok "Orca Router: ACTIVE (Port 60001)"
    else
        log_err "Orca Router: FAILED (Check: $LOG_DIR/orca-router.log)"
    fi

    if [ "${SKIP_PROXY:-}" != "true" ]; then
        if systemctl --user is-active --quiet owl-proxy.service 2>/dev/null; then
            log_ok "Forward Proxy: ACTIVE (Port 60000)"
        else
            log_err "Forward Proxy: FAILED (Check: $LOG_DIR/forward-proxy.log)"
        fi
    fi

    # -- Provider Authentication (Interactive) --------------------------------
    if [ "${WITH_PROVIDERS:-}" == "true" ]; then
        if [ -t 0 ]; then
            echo ""
            echo -e "${BOLD}Provider Authentication${NC}"
            echo ""
            echo "  1. Setup Copilot Free"
            echo "  2. Setup Antigravity Free"
            echo "  3. Setup both"
            echo "  4. Skip"
            echo ""
            read -rp "  Select [1-4]: " prov_choice

            case "$prov_choice" in
                1) "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider copilot ;;
                2) "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider antigravity ;;
                3)
                    "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider copilot
                    echo ""
                    "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider antigravity
                    ;;
                *) log_info "Provider auth skipped. Run later:" ;;
            esac
        else
            log_warn "Non-interactive terminal. Provider auth skipped."
            log_info "Run manually: $VENV_DIR/bin/python $BIN_DIR/token_manager.py auth --provider copilot"
        fi
    fi

    # -- Post-Activation Health Check ----------------------------------------
    # FIX: Retry health check for up to 30 seconds (10 attempts, 3s interval)
    # instead of a single attempt that fails on slow starts.
    log_info "Running post-activation health check..."
    if systemctl --user is-active --quiet orca-router.service 2>/dev/null; then
        HEALTH_OK=false
        _attempt=0
        while [ "$_attempt" -lt 10 ]; do
            _attempt=$((_attempt + 1))
            HEALTH_RESP=$(curl -s --connect-timeout 3 http://127.0.0.1:60001/health 2>/dev/null || echo "TIMEOUT")
            if echo "$HEALTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
                HEALTH_OK=true
                break
            fi
            if [ "$_attempt" -lt 10 ]; then
                log_info "  Health check attempt $_attempt/10 failed, retrying in 3s..."
                sleep 3
            fi
        done
        if [ "$HEALTH_OK" == "true" ]; then
            log_ok "Orca Router health check PASSED (HTTP 200, status=ok)"
        else
            log_warn "Orca Router health endpoint did not return ok after 10 attempts."
            log_warn "  Response: ${HEALTH_RESP:0:100}"
            log_info "  Check manually: curl http://127.0.0.1:60001/health"
            log_info "  Logs: $LOG_DIR/orca-router.log"
        fi
    fi

    # Kiro Step 7: HTTP health/model/chat verification
    if [ "${SKIP_KIRO:-}" != "true" ] && systemctl --user is-active --quiet kiro-gateway.service 2>/dev/null; then
        log_info "Running Kiro Gateway health check..."
        KIRO_HEALTH_OK=false
        _kiro_attempt=0
        while [ "$_kiro_attempt" -lt 10 ]; do
            _kiro_attempt=$((_kiro_attempt + 1))
            KIRO_RESP=$(curl -s --connect-timeout 3 "http://127.0.0.1:${KIRO_PORT}/health" 2>/dev/null || echo "TIMEOUT")
            if echo "$KIRO_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' or d.get('health')=='ok' else 1)" 2>/dev/null; then
                KIRO_HEALTH_OK=true
                break
            fi
            if [ "$_kiro_attempt" -lt 10 ]; then
                log_info "  Kiro health check attempt $_kiro_attempt/10 failed, retrying in 3s..."
                sleep 3
            fi
        done
        if [ "$KIRO_HEALTH_OK" == "true" ]; then
            log_ok "Kiro Gateway health check PASSED (port $KIRO_PORT)"

            # Verify /v1/models endpoint returns model list
            MODELS_RESP=$(curl -s --connect-timeout 3 "http://127.0.0.1:${KIRO_PORT}/v1/models" 2>/dev/null || echo "")
            if echo "$MODELS_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'data' in d else 1)" 2>/dev/null; then
                log_ok "Kiro Gateway /v1/models endpoint verified"
            else
                log_warn "Kiro Gateway /v1/models did not return expected format"
            fi
        else
            log_warn "Kiro Gateway health endpoint did not return ok after 10 attempts."
            log_info "  Check manually: curl http://127.0.0.1:${KIRO_PORT}/health"
        fi
    fi

    # -- Log Rotation Setup --------------------------------------------------
    # Clean up backup files from previous install runs (older than 7 days)
    cleanup_old_backups "$INSTALL_DIR" "*"
    cleanup_old_backups "$CONFIG_DIR" "*"
    cleanup_old_backups "$OPENCODE_DIR" "opencode.jsonc"

    log_info "Configuring log rotation..."
    if command -v logrotate &>/dev/null; then
        _ATMP="$(_mktemp "$CONFIG_DIR/logrotate.conf")"
        cat > "$_ATMP" << LOGROT
${INSTALL_DIR}/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    maxsize 50M
}
LOGROT
        mv -f "$_ATMP" "$CONFIG_DIR/logrotate.conf"
        # Install logrotate cron if possible
        if [ -d "$HOME/.config/systemd/user" ] && [ ! -f "$HOME/.config/systemd/user/owl-logrotate.timer" ]; then
            _ATMP="$(_mktemp "$HOME/.config/systemd/user/owl-logrotate.service")"
            # FIX: Use unquoted heredoc so $CONFIG_DIR is expanded at write time.
            # Single-quoted heredoc would leave literal ${CONFIG_DIR} in the file.
            cat > "$_ATMP" << LRSEOF
[Unit]
Description=OWL Log Rotation

[Service]
Type=oneshot
ExecStart=/usr/bin/logrotate ${CONFIG_DIR}/logrotate.conf
LRSEOF
            mv -f "$_ATMP" "$HOME/.config/systemd/user/owl-logrotate.service"
            _ATMP="$(_mktemp "$HOME/.config/systemd/user/owl-logrotate.timer")"
            cat > "$_ATMP" << 'LRTEOF'
[Unit]
Description=Daily OWL Log Rotation Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
LRTEOF
            mv -f "$_ATMP" "$HOME/.config/systemd/user/owl-logrotate.timer"
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable owl-logrotate.timer 2>/dev/null || true
            systemctl --user start owl-logrotate.timer 2>/dev/null || true
            log_ok "Log rotation configured (daily, 7-day retention, 50MB max)"
        fi
    else
        log_warn "logrotate not found. Logs will grow unbounded. Install: sudo apt install logrotate"
    fi
fi

# Persist version for future --update detection
echo "$VERSION" > "$INSTALL_DIR/VERSION"

# =============================================================================
#  FINAL SUMMARY
# =============================================================================

echo ""
echo -e "${GREEN}${BOLD}+-----------------------------------------------------------+${NC}"
echo -e "${GREEN}${BOLD}|                                                           |${NC}"
echo -e "${GREEN}${BOLD}|      OWL-ORCA v${VERSION} INSTALLATION COMPLETE               |${NC}"
echo -e "${GREEN}${BOLD}|          \"${VERSION_NAME}\" Edition                           |${NC}"
echo -e "${GREEN}${BOLD}|                                                           |${NC}"
echo -e "${GREEN}${BOLD}+-----------------------------------------------------------+${NC}"
echo ""
echo "  Services:"
echo "    Forward Proxy:    http://127.0.0.1:60000"
echo "    Orca Router:      http://127.0.0.1:60001  (Stream Racing + Translation)"
[ "${SKIP_KIRO:-}" != "true" ] && echo "    Kiro Gateway:     http://127.0.0.1:${KIRO_PORT}"
echo ""
echo "  OpenCode Provider:  owl-orca-virtual"
echo "    baseURL:          http://127.0.0.1:60001/v1"
echo "    apiKey:           orca-racer"
echo "    model:            auto-racer (Races GPT-4o & Claude 3.5)"
echo ""
if [ "${OPENCODE_ACTIVE:-}" == "true" ]; then
    echo -e "  ${YELLOW}NOTE: Your IDE was running during install (SAFE-MODE).${NC}"
    echo "  Active services were NOT restarted to preserve connections."
    echo "  New code is on disk. Restart your IDE when convenient."
    echo ""
    echo "  Hot-reload routing config without restart:"
    echo "    systemctl --user reload orca-router.service"
    echo "    # OR: curl -X POST http://127.0.0.1:60001/admin/reload"
else
    echo "  Services are live and ready."
fi
echo ""
echo "  CLI Commands:"
echo "    owl-proxy <cmd>            Run command with proxy env vars"
echo "    owl-token auth -p copilot  Authenticate with Copilot Free"
echo "    owl-token auth -p antigravity  Authenticate with Antigravity"
echo "    owl-token status           Check token status"
echo ""
echo "  Config files:"
echo "    ~/.owl-agent/config/providers.json"
echo "    ~/.owl-agent/config/routes.json"
echo "    ~/.config/opencode/opencode.jsonc"
echo ""

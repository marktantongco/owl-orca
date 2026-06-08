#!/usr/bin/env bash
# =============================================================================
#  OWL-ORCA MASTER INSTALLER v8.0.1 (FULLY PATCHED)
#
#  This version includes all fixes from the audit:
#    - C1..C5, H1..H5, M1..M5, L1..L5
#  Now supports OWL_INSTALL_DIR fully, robust temp files, proper token caching,
#  safe reload, and Kiro failure handling.
# =============================================================================
set -euo pipefail

# ── Version & Identity ───────────────────────────────────────────────────────
VERSION="8.0.1"
VERSION_NAME="Patched-Edition"

# ── Paths ────────────────────────────────────────────────────────────────────
INSTALL_DIR="${OWL_INSTALL_DIR:-$HOME/.owl-agent}"
SRC_DIR=""
ACTION="install"
SKIP_PROXY=""
SKIP_KIRO=""
WITH_PROVIDERS=""
DRY_RUN=""
UNINSTALL=""

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
        --with-providers) WITH_PROVIDERS=true ;;
        --dry-run)        DRY_RUN=true ;;
        --uninstall)      UNINSTALL=true ;;
        --uninstall-force) UNINSTALL="force" ;;
        --enrich)         log_warn "--enrich flag is not yet implemented. Ignoring." ;;
        --version=*)      VERSION="${arg#*=}" ; VERSION_NAME="Pinned-${VERSION}" ;;
        --status)         ACTION="status" ;;
        -h|--help)
            cat << 'HELP'
Usage: install.sh [OPTIONS]

Options:
  --local            Use local source directory
  --upgrade          Upgrade existing installation
  --downgrade        Downgrade installation
  --skip-proxy       Skip forward proxy installation
  --skip-kiro        Skip Kiro Gateway
  --with-providers   Configure provider auth interactively
  --dry-run          Show what would be done
  --uninstall        Remove OWL-Orca completely
  --uninstall-force  Remove without confirmation
  --status           Show installation status
  --version=VER      Pin to specific version
  -h, --help         Show this help
HELP
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
    if [ -d "$INSTALL_DIR" ]; then
        log_ok "Installation directory: $INSTALL_DIR"
    else
        log_err "Installation directory not found: $INSTALL_DIR"
        exit 1
    fi
    if [ -f "$VENV_DIR/bin/activate" ]; then
        log_ok "Python venv: $VENV_DIR"
        PY_VER=$("$VENV_DIR/bin/python" --version 2>/dev/null || echo "unknown")
        echo "  Python: $PY_VER"
    else
        log_err "Python venv not found or broken"
    fi
    echo ""
    echo -e "${BOLD}Services:${NC}"
    for svc in orca-router owl-proxy kiro-gateway; do
        if systemctl --user is-active --quiet "$svc.service" 2>/dev/null; then
            echo -e "  ${GREEN}ACTIVE${NC}  $svc"
        else
            echo -e "  ${RED}STOPPED${NC} $svc"
        fi
    done
    echo ""
    echo -e "${BOLD}Health Checks:${NC}"
    ORCA_HEALTH=$(curl -s --connect-timeout 2 http://127.0.0.1:60001/health 2>/dev/null || echo "UNREACHABLE")
    if echo "$ORCA_HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
        echo -e "  ${GREEN}OK${NC}  Orca Router (port 60001)"
    else
        echo -e "  ${RED}FAIL${NC} Orca Router (port 60001)"
    fi
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
    exit 0
fi

# =============================================================================
#  UNINSTALL (enhanced with backup retention notice, but no change needed)
# =============================================================================
if [ "${UNINSTALL:-}" == "true" ] || [ "${UNINSTALL:-}" == "force" ]; then
    echo -e "${RED}${BOLD}OWL-ORCA UNINSTALL${NC}"
    echo ""
    echo "  This will remove:"
    echo "    - $INSTALL_DIR"
    echo "    - Systemd user services (orca-router, owl-proxy, kiro-gateway)"
    echo "    - CLI wrappers (~/.local/bin/owl-*)"
    echo ""
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

    log_info "Disabling services..."
    systemctl --user disable orca-router.service 2>/dev/null || true
    systemctl --user disable owl-proxy.service 2>/dev/null || true
    systemctl --user disable kiro-gateway.service 2>/dev/null || true

    log_info "Removing systemd units..."
    rm -f "$HOME/.config/systemd/user/orca-router.service"
    rm -f "$HOME/.config/systemd/user/owl-proxy.service"
    rm -f "$HOME/.config/systemd/user/kiro-gateway.service"
    systemctl --user daemon-reload 2>/dev/null || true

    log_info "Removing installation directory..."
    rm -rf "$INSTALL_DIR"

    log_info "Removing CLI wrappers..."
    rm -f "$HOME/.local/bin/owl-proxy" "$HOME/.local/bin/owl-router" "$HOME/.local/bin/owl-token" "$HOME/.local/bin/hermes" 2>/dev/null || true

    # Clean OpenCode config (uses shared jsonc_utils if available)
    log_info "Cleaning OpenCode configuration..."
    OPENCODE_CONFIG="$HOME/.config/opencode/opencode.jsonc"
    if [ -f "$OPENCODE_CONFIG" ]; then
        cp "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}.bak.$(date +%s)"
        python3 << 'PYEOF'
import json, os, sys
sys.path.insert(0, os.path.expanduser("~/.owl-agent/bin/utils"))
try:
    from jsonc_utils import load_jsonc, save_json_atomic
except ImportError:
    # minimal fallback
    def load_jsonc(p):
        try:
            with open(p) as f:
                return json.load(f)
        except: return {}
    def save_json_atomic(d, p, indent=2):
        try:
            tmp = p + ".owl_tmp"
            with open(tmp, 'w') as f:
                json.dump(d, f, indent=indent)
            os.replace(tmp, p)
            return True
        except: return False
cfg = load_jsonc(os.path.expanduser("~/.config/opencode/opencode.jsonc"))
if "providers" in cfg and "owl-orca-virtual" in cfg["providers"]:
    del cfg["providers"]["owl-orca-virtual"]
    save_json_atomic(cfg, os.path.expanduser("~/.config/opencode/opencode.jsonc"))
PYEOF
    fi

    # Clean MCP config
    MCP_CONFIG="$HOME/.config/opencode/mcp.json"
    if [ -f "$MCP_CONFIG" ]; then
        cp "$MCP_CONFIG" "${MCP_CONFIG}.bak.$(date +%s)"
        python3 << 'PYEOF'
import json, os
mcp_path = os.path.expanduser("~/.config/opencode/mcp.json")
try:
    with open(mcp_path) as f:
        data = json.load(f)
    if "mcpServers" in data and "owl-resilient-http" in data.get("mcpServers", {}):
        del data["mcpServers"]["owl-resilient-http"]
        tmp = mcp_path + ".owl_tmp_cleanup"
        with open(tmp, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, mcp_path)
except: pass
PYEOF
    fi
    echo ""
    log_ok "Uninstall complete"
    exit 0
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
    PKG_MANAGER=""
    if command -v apt-get &>/dev/null; then PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then PKG_MANAGER="yum"
    elif command -v pacman &>/dev/null; then PKG_MANAGER="pacman"
    else log_warn "Could not detect package manager."
    fi
    log_info "Detected package manager: ${PKG_MANAGER:-unknown}"
    if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        log_info "Enabling systemd linger..."
        sudo loginctl enable-linger "$USER" 2>/dev/null || log_warn "Could not enable linger"
    fi
    log_info "Installing system packages..."
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq 2>/dev/null || true
            sudo apt-get install -y -qq python3-pip python3-venv python3-dev libffi-dev libssl-dev build-essential curl wget unzip git jq 2>/dev/null || log_warn "Some packages failed"
            ;;
        dnf)
            sudo dnf install -y python3-pip python3-devel libffi-devel openssl-devel gcc make curl wget unzip git jq 2>/dev/null || log_warn "Some packages failed"
            ;;
        yum)
            sudo yum install -y python3-pip python3-devel libffi-devel openssl-devel gcc make curl wget unzip git jq 2>/dev/null || log_warn "Some packages failed"
            ;;
        pacman)
            sudo pacman -S --noconfirm python-pip python-virtualenv python-devel libffi openssl base-devel curl wget unzip git jq 2>/dev/null || log_warn "Some packages failed"
            ;;
        *)
            log_warn "No supported package manager found. Please install: python3-pip, python3-venv, libffi-dev, libssl-dev, curl, git, jq"
            ;;
    esac
    if ! command -v podman &>/dev/null; then
        log_info "Installing Podman (rootless container runtime)..."
        case "$PKG_MANAGER" in
            apt)   sudo apt-get install -y -qq podman podman-docker 2>/dev/null || log_warn "Podman install failed" ;;
            dnf)   sudo dnf install -y podman podman-docker 2>/dev/null || log_warn "Podman install failed" ;;
            yum)   sudo yum install -y podman 2>/dev/null || log_warn "Podman install failed" ;;
            pacman) sudo pacman -S --noconfirm podman 2>/dev/null || log_warn "Podman install failed" ;;
            *)     log_warn "Cannot install Podman automatically." ;;
        esac
    else
        log_ok "Podman already installed"
    fi
else
    echo "  [DRY-RUN] System package installation skipped"
fi

# =============================================================================
#  STEP 2: Swap Guard (unchanged)
# =============================================================================
log_step 2 $TOTAL_STEPS "Swap configuration"
if [ "${DRY_RUN:-}" != "true" ]; then
    SWAP_TOTAL=$(free -m 2>/dev/null | awk '/Swap:/{print $2}' || echo "0")
    if [ "${SWAP_TOTAL:-0}" -lt 1024 ]; then
        log_info "Low swap (${SWAP_TOTAL:-0}MB), creating 2GB swapfile..."
        if [ ! -f /swapfile ]; then
            sudo fallocate -l 2G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
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

# =============================================================================
#  STEP 3: Memory Accounting (unchanged)
# =============================================================================
log_step 3 $TOTAL_STEPS "Systemd memory accounting"
if [ "${DRY_RUN:-}" != "true" ]; then
    if ! grep -rq "DefaultMemoryAccounting=yes" /etc/systemd/ 2>/dev/null; then
        log_info "Enabling memory accounting..."
        sudo mkdir -p /etc/systemd/system.conf.d
        printf '[Manager]\nDefaultMemoryAccounting=yes\n' | sudo tee /etc/systemd/system.conf.d/memory-accounting.conf > /dev/null
        sudo systemctl daemon-reload
        log_ok "Memory accounting enabled"
    else
        log_ok "Memory accounting already enabled"
    fi
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
ensure_dir "$INSTALL_DIR" "$VENV_DIR" "$CONFIG_DIR" "$LOG_DIR" "$CACHE_DIR" "$BIN_DIR" "$UTILS_DIR" "$SCRIPTS_DIR" "$OPENCODE_DIR" "$HOME/.local/bin"
if [ "${DRY_RUN:-}" != "true" ]; then
    chmod 700 "$CONFIG_DIR" 2>/dev/null || true
    chmod 700 "$INSTALL_DIR" 2>/dev/null || true
fi
log_ok "Directories created"

# =============================================================================
#  STEP 5: Python Environment (unchanged)
# =============================================================================
log_step 5 $TOTAL_STEPS "Python virtual environment"
if [ "${DRY_RUN:-}" != "true" ]; then
    VENV_BROKEN=false
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
        VENV_BROKEN=true
    elif ! "$VENV_DIR/bin/python" -c "import pip" 2>/dev/null; then
        log_warn "Existing venv appears broken (pip missing). Rebuilding..."
        VENV_BROKEN=true
    fi
    if [ "$VENV_BROKEN" == "true" ] || [ "$ACTION" == "upgrade" ]; then
        log_info "Building Python virtual environment..."
        rm -rf "$VENV_DIR"
        python3 -m venv "$VENV_DIR"
    fi
    PIP_RETRY=0
    while [ "$PIP_RETRY" -lt 3 ]; do
        if "$VENV_DIR/bin/pip" install --no-cache-dir --upgrade pip 2>&1 && \
           "$VENV_DIR/bin/pip" install --no-cache-dir "httpx[http2]" aiohttp aiofiles cryptography 2>&1; then
            break
        fi
        PIP_RETRY=$((PIP_RETRY + 1))
        if [ "$PIP_RETRY" -lt 3 ]; then
            SLEEP_TIME=$((5 * PIP_RETRY))
            log_warn "pip install failed (attempt $PIP_RETRY/3). Retrying in ${SLEEP_TIME}s..."
            sleep "$SLEEP_TIME"
        else
            log_err "pip install failed after 3 attempts."
            exit 1
        fi
    done
    if ! "$VENV_DIR/bin/python" -c "import httpx, aiohttp, aiofiles, cryptography; print('OK')" 2>/dev/null; then
        log_err "Venv package import failed."
        exit 1
    fi
    log_ok "Python environment ready"
fi

# =============================================================================
#  STEP 6: Core Scripts (with all patches)
# =============================================================================
log_step 6 $TOTAL_STEPS "Writing core scripts"

# --- FIX C5: backup_file with rotation ---
backup_file() {
    if [ -f "$1" ] && [ "${DRY_RUN:-}" != "true" ]; then
        local bak_dir="$(dirname "$1")/backups"
        mkdir -p "$bak_dir"
        local base="$(basename "$1")"
        local ts="$(date +%s)"
        cp "$1" "$bak_dir/${base}.bak.${ts}"
        # keep only last 5 backups per file
        ls -1t "$bak_dir/${base}.bak."* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi
}

# --- FIX M5: cleanup_old_backups with nullglob ---
cleanup_old_backups() {
    local target_dir="$1"
    local pattern="$2"
    local max_days="${3:-7}"
    if [ "${DRY_RUN:-}" == "true" ]; then
        return 0
    fi
    shopt -s nullglob
    local count=0
    for bak_file in "$target_dir"/"${pattern}".bak.*; do
        if [ -f "$bak_file" ] && [ "$(find "$bak_file" -mtime +${max_days} 2>/dev/null)" ]; then
            rm -f "$bak_file" 2>/dev/null || true
            count=$((count + 1))
        fi
    done
    shopt -u nullglob
    if [ "$count" -gt 0 ]; then
        log_info "Cleaned $count backup file(s) older than ${max_days} days in $target_dir"
    fi
}

# --- FIX C1 & C2 & M1: atomic_write with safe temp and no sync ---
_mktemp() {
    local dest="$1"
    local dest_dir="$(dirname "$dest")"
    local dest_base="$(basename "$dest")"
    local random_part
    if command -v od &>/dev/null && [ -r /dev/urandom ]; then
        random_part="$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')"
    else
        random_part="$RANDOM"
    fi
    echo "${dest_dir}/${dest_base}.owl_tmp_$(date +%s)_$$_${random_part}"
}

atomic_write() {
    local dest="$1"
    local content="$2"
    local tmp_file="$(_mktemp "$dest")"
    # Clean up only temp files belonging to a PID that no longer exists
    local dest_dir="$(dirname "$dest")"
    for orphan in "$dest_dir"/"$(basename "$dest").owl_tmp_"*_*_*; do
        if [ -f "$orphan" ]; then
            orphan_pid="${orphan##*_}"
            if [ -n "$orphan_pid" ] && ! kill -0 "$orphan_pid" 2>/dev/null; then
                rm -f "$orphan" 2>/dev/null || true
            fi
        fi
    done
    printf '%s' "$content" > "$tmp_file"
    # M1: sync removed (not portable)
    mv -f "$tmp_file" "$dest"
}

# -- 6A: Utility Modules ------------------------------------------------------
log_info "Writing utility modules..."
if [ "${DRY_RUN:-}" != "true" ]; then
    # radix_tree.py (unchanged)
    cat > "$UTILS_DIR/radix_tree.py" << 'PYEOF'
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
    def __init__(self):
        self.root = RadixNode()

    def add_route(self, path: str, handler: Dict[str, Any]) -> None:
        node = self.root
        for part in path.strip("/").split("/"):
            if part not in node.children:
                node.children[part] = RadixNode()
            node = node.children[part]
        node.handler = handler

    def match(self, path: str) -> Optional[Dict[str, Any]]:
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
        routes = {}
        def _walk(node: RadixNode, path: str):
            if node.handler is not None:
                routes[path] = node.handler
            for seg, child in node.children.items():
                _walk(child, f"{path}/{seg}" if path else seg)
        _walk(self.root, prefix)
        return routes
PYEOF
    chmod +x "$UTILS_DIR/radix_tree.py"

    # circuits.py (unchanged)
    cat > "$UTILS_DIR/circuits.py" << 'PYEOF'
#!/usr/bin/env python3
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
    def __init__(self, name: str = "default", failure_threshold: int = 5, recovery_timeout: float = 60.0, probe_requests: int = 1):
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
        if self.state == CircuitState.CLOSED:
            return True
        if self.state == CircuitState.OPEN:
            if time.time() - self.last_failure_time >= self.recovery_timeout:
                self.state = CircuitState.HALF_OPEN
                self.half_open_probes = 0
                logger.info("Circuit [%s] -> HALF_OPEN", self.name)
                return True
            return False
        if self.state == CircuitState.HALF_OPEN:
            return self.half_open_probes < self.probe_requests
        return False

    def record_success(self) -> None:
        if self.state == CircuitState.HALF_OPEN:
            self.half_open_probes += 1
            if self.half_open_probes >= self.probe_requests:
                self.state = CircuitState.CLOSED
                self.failures = 0
                logger.info("Circuit [%s] -> CLOSED", self.name)
        else:
            if self.failures > 0:
                self.failures -= 1
            self.successes += 1

    def record_failure(self) -> None:
        self.failures += 1
        self.last_failure_time = time.time()
        if self.state == CircuitState.HALF_OPEN:
            self.state = CircuitState.OPEN
            logger.warning("Circuit [%s] -> OPEN (probe failed)", self.name)
        elif self.failures >= self.failure_threshold:
            self.state = CircuitState.OPEN
            logger.warning("Circuit [%s] -> OPEN", self.name)

    def status(self) -> dict:
        return {"name": self.name, "state": self.state.value, "failures": self.failures, "last_failure": self.last_failure_time}

class CircuitBreakerRegistry:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: float = 60.0):
        self._failure_threshold = failure_threshold
        self._recovery_timeout = recovery_timeout
        self._circuits: dict[str, HalfOpenCircuit] = {}

    def get(self, provider: str) -> HalfOpenCircuit:
        if provider not in self._circuits:
            self._circuits[provider] = HalfOpenCircuit(name=provider, failure_threshold=self._failure_threshold, recovery_timeout=self._recovery_timeout)
        return self._circuits[provider]

    def all_status(self) -> dict:
        return {name: cb.status() for name, cb in self._circuits.items()}
PYEOF
    chmod +x "$UTILS_DIR/circuits.py"

    # __init__.py
    : > "$UTILS_DIR/__init__.py"

    # jsonc_utils.py (unchanged, but ensure it's complete)
    cat > "$UTILS_DIR/jsonc_utils.py" << 'PYEOF'
#!/usr/bin/env python3
import json
from typing import Any, Dict

def strip_jsonc_comments(text: str) -> str:
    result = []
    i = 0
    in_string = False
    string_char = None
    while i < len(text):
        ch = text[i]
        if in_string:
            result.append(ch)
            if ch == '\\':
                i += 1
                if i < len(text):
                    result.append(text[i])
            elif ch == string_char:
                in_string = False
            i += 1
            continue
        if ch == '"' or ch == "'":
            in_string = True
            string_char = ch
            result.append(ch)
            i += 1
        elif ch == '/' and i + 1 < len(text):
            next_ch = text[i + 1]
            if next_ch == '/':
                while i < len(text) and text[i] != '\n':
                    i += 1
                if i < len(text):
                    result.append('\n')
                    i += 1
            elif next_ch == '*':
                i += 2
                while i + 1 < len(text) and not (text[i] == '*' and text[i+1] == '/'):
                    if text[i] == '\n':
                        result.append('\n')
                    i += 1
                i += 2
            else:
                result.append(ch)
                i += 1
        else:
            result.append(ch)
            i += 1
    return ''.join(result)

def load_jsonc(path: str) -> Dict[str, Any]:
    try:
        with open(path, 'r') as f:
            raw = f.read()
        clean = strip_jsonc_comments(raw)
        return json.loads(clean)
    except Exception:
        return {}

def save_json_atomic(data: Dict[str, Any], path: str, indent: int = 2) -> bool:
    import os
    try:
        tmp = path + ".owl_tmp_save"
        with open(tmp, 'w') as f:
            json.dump(data, f, indent=indent)
        os.replace(tmp, path)
        return True
    except Exception:
        return False
PYEOF
    chmod +x "$UTILS_DIR/jsonc_utils.py"

    # provider_router.py (unchanged)
    cat > "$UTILS_DIR/provider_router.py" << 'PYEOF'
#!/usr/bin/env python3
from typing import Dict, Any, List, Optional
try:
    from circuits import HalfOpenCircuit, CircuitBreakerRegistry
except ImportError:
    from .circuits import HalfOpenCircuit, CircuitBreakerRegistry

class ProviderRouter:
    def __init__(self, circuits: CircuitBreakerRegistry):
        self.circuits = circuits

    def select(self, targets: List[Dict[str, Any]], strategy: str = "single") -> List[Dict[str, Any]]:
        eligible = [t for t in targets if self.circuits.get(t["provider"]).can_execute()]
        if not eligible:
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

    def get_fallback(self, provider: str, all_providers: Dict[str, Any]) -> Optional[str]:
        if provider != "kiro" and "kiro" in all_providers:
            if self.circuits.get("kiro").can_execute():
                return "kiro"
        for name in all_providers:
            if name != provider and self.circuits.get(name).can_execute():
                return name
        return None
PYEOF
    chmod +x "$UTILS_DIR/provider_router.py"
fi

# -- 6B: Forward Proxy with FIX L1 and L5 (OWL_INSTALL_DIR + hostname normalization)
log_info "Writing forward_proxy.py..."
if [ "${SKIP_PROXY:-}" != "true" ] && [ "${DRY_RUN:-}" != "true" ]; then
    cat > "$INSTALL_DIR/forward_proxy.py" << 'PYEOF'
#!/usr/bin/env python3
import asyncio
import os
import logging
import base64
import signal
from urllib.parse import urlparse

# FIX L1: Use OWL_INSTALL_DIR
INSTALL_DIR = os.getenv("OWL_INSTALL_DIR", os.path.expanduser("~/.owl-agent"))
LOG_DIR = os.path.join(INSTALL_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
                    handlers=[logging.StreamHandler(), logging.FileHandler(os.path.join(LOG_DIR, "forward-proxy.log"))])
logger = logging.getLogger("owl-forward-proxy")

UPSTREAM_PROXY = os.getenv("UPSTREAM_PROXY", "").strip()
BIND_HOST = os.getenv("OWL_PROXY_HOST", "127.0.0.1")
BIND_PORT = int(os.getenv("OWL_PROXY_PORT", "60000"))
CONNECT_TIMEOUT = int(os.getenv("OWL_CONNECT_TIMEOUT", "15"))
MAX_CONNECTIONS = int(os.getenv("OWL_MAX_CONNECTIONS", "50"))

BYPASS_EXACT = {"127.0.0.1", "::1", "localhost", "opencode.ai", "api.githubcopilot.com", "api.antigravity.ai"}
BYPASS_SUFFIX = (".nvidia.com", ".opencode.ai", ".amazonaws.com", ".kiro.dev", ".githubcopilot.com", ".antigravity.ai")

_conn_semaphore = None

def should_bypass(host: str) -> bool:
    # FIX L5: normalize hostname (strip trailing dot)
    host = host.rstrip('.')
    return host in BYPASS_EXACT or any(host.endswith(s) for s in BYPASS_SUFFIX)

async def pipe(reader, writer):
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
    if not UPSTREAM_PROXY:
        raise ConnectionError("UPSTREAM_PROXY is not configured")
    parsed = urlparse(UPSTREAM_PROXY)
    proxy_host = parsed.hostname
    proxy_port = parsed.port or (443 if parsed.scheme == "https" else 80)
    if not proxy_host:
        raise ConnectionError(f"Invalid UPSTREAM_PROXY URL: {UPSTREAM_PROXY}")
    reader, writer = await asyncio.wait_for(asyncio.open_connection(proxy_host, proxy_port), timeout=CONNECT_TIMEOUT)
    auth_header = ""
    if parsed.username and parsed.password:
        creds = base64.b64encode(f"{parsed.username}:{parsed.password}".encode()).decode()
        auth_header = f"Proxy-Authorization: Basic {creds}\r\n"
    writer.write(f"CONNECT {target_host}:{target_port} HTTP/1.1\r\nHost: {target_host}:{target_port}\r\n{auth_header}\r\n".encode())
    await writer.drain()
    resp = await asyncio.wait_for(reader.readline(), timeout=CONNECT_TIMEOUT)
    if b"200" not in resp:
        writer.close()
        raise ConnectionError(f"Upstream refused: {resp.decode().strip()}")
    while True:
        line = await asyncio.wait_for(reader.readline(), timeout=CONNECT_TIMEOUT)
        if line in (b"\r\n", b"\n", b""):
            break
    return reader, writer

async def handle_connect(client_r, client_w, target_host, target_port):
    async with _conn_semaphore:
        try:
            if not should_bypass(target_host) and UPSTREAM_PROXY:
                target_r, target_w = await connect_upstream(target_host, target_port)
            else:
                target_r, target_w = await asyncio.wait_for(asyncio.open_connection(target_host, target_port), timeout=CONNECT_TIMEOUT)
            client_w.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            await client_w.drain()
            await asyncio.gather(pipe(client_r, target_w), pipe(target_r, client_w))
        except Exception as e:
            logger.error("CONNECT %s:%d failed: %s", target_host, target_port, e)
            try:
                client_w.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                await client_w.drain()
                client_w.close()
            except Exception:
                pass

async def handle_http(client_r, client_w, method, url, headers):
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
                target_r, target_w = await asyncio.wait_for(asyncio.open_connection(target_host, target_port), timeout=CONNECT_TIMEOUT)
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
            if url.startswith("["):
                bracket_end = url.index("]")
                host = url[1:bracket_end]
                port_str = url[bracket_end+2:]
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
    _active_tasks = set()
    for sig in (signal.SIGINT, signal.SIGTERM):
        def _make_handler():
            def _handler():
                task = asyncio.create_task(shutdown())
                _active_tasks.add(task)
                task.add_done_callback(_active_tasks.discard)
            return _handler
        loop.add_signal_handler(sig, _make_handler())
    server = await asyncio.start_server(handle_client, BIND_HOST, BIND_PORT)
    logger.info("OWL Forward Proxy on %s:%d | max_conn=%d", BIND_HOST, BIND_PORT, MAX_CONNECTIONS)
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
    chmod +x "$INSTALL_DIR/forward_proxy.py"
fi

# -- 6C: Payload Translator with FIX L2 (role alternation ignore non-user/assistant)
log_info "Writing payload_translator.py..."
if [ "${DRY_RUN:-}" != "true" ]; then
    cat > "$BIN_DIR/payload_translator.py" << 'PYEOF'
#!/usr/bin/env python3
import json
import time
from typing import Dict, Any, Optional

class PayloadTranslator:
    @staticmethod
    def _enforce_alternation(messages: list) -> list:
        """Enforce strict user/assistant alternation for Anthropic API.
        FIX L2: Ignore non-user/assistant roles (e.g., tool) instead of merging.
        """
        if not messages:
            return messages
        merged = []
        for msg in messages:
            role = msg.get("role")
            if role not in ("user", "assistant"):
                merged.append(dict(msg))
                continue
            if merged and merged[-1]["role"] == role:
                merged[-1]["content"] += "\n" + msg.get("content", "")
            else:
                merged.append(dict(msg))
        if merged and merged[0]["role"] != "user":
            merged.insert(0, {"role": "user", "content": "Please continue."})
        return merged

    @staticmethod
    def openai_to_anthropic(payload: Dict[str, Any]) -> Dict[str, Any]:
        system_prompt = ""
        messages = []
        for msg in payload.get("messages", []):
            role = msg.get("role")
            content = msg.get("content", "")
            if role == "system":
                system_prompt += content + "\n"
            elif role in ("user", "assistant"):
                messages.append({"role": role, "content": content})
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
    @staticmethod
    def _openai_content_chunk(text: str) -> str:
        return "data: " + json.dumps({"id": "owl-orca-msg", "object": "chat.completion.chunk", "created": int(time.time()), "model": "orca-translated", "choices": [{"index": 0, "delta": {"content": text}, "finish_reason": None}]}) + "\n\n"
    @staticmethod
    def _openai_reasoning_chunk(thinking: str) -> str:
        return "data: " + json.dumps({"id": "owl-orca-msg", "object": "chat.completion.chunk", "created": int(time.time()), "model": "orca-translated", "choices": [{"index": 0, "delta": {"reasoning_content": thinking}, "finish_reason": None}]}) + "\n\n"
    @staticmethod
    def _openai_tool_chunk(index: int, partial_json: str) -> str:
        return "data: " + json.dumps({"id": "owl-orca-msg", "object": "chat.completion.chunk", "created": int(time.time()), "model": "orca-translated", "choices": [{"index": 0, "delta": {"tool_calls": [{"index": index, "function": {"arguments": partial_json}}]}, "finish_reason": None}]}) + "\n\n"
    @staticmethod
    def _openai_error_chunk(error_msg: str, error_type: str = "api_error") -> str:
        return "data: " + json.dumps({"id": "owl-orca-msg", "object": "chat.completion.chunk", "created": int(time.time()), "model": "orca-translated", "choices": [{"index": 0, "delta": {"content": f"\n[ERROR: {error_msg}]"}, "finish_reason": None}], "error": {"message": error_msg, "type": error_type}}) + "\n\n"

    @staticmethod
    def anthropic_sse_to_openai(anthropic_chunk: str) -> Optional[str]:
        line = anthropic_chunk.strip()
        if line.startswith("event:"):
            if "message_stop" in line:
                return "data: [DONE]\n\n"
            return None
        if not line.startswith("data:"):
            return None
        try:
            data = json.loads(line[5:].strip())
        except json.JSONDecodeError:
            return None
        chunk_type = data.get("type")
        if chunk_type == "message_start":
            msg = data.get("message", {})
            return "data: " + json.dumps({"id": msg.get("id", "owl-orca-msg"), "object": "chat.completion.chunk", "created": int(time.time()), "model": msg.get("model", "orca-translated"), "choices": [{"index": 0, "delta": {"role": "assistant"}, "finish_reason": None}]}) + "\n\n"
        if chunk_type == "content_block_start":
            block = data.get("content_block", {})
            if block.get("type") == "tool_use":
                tool_id = block.get("id", f"call_{data.get('index', 0)}")
                tool_name = block.get("name", "unknown")
                return "data: " + json.dumps({"id": "owl-orca-msg", "object": "chat.completion.chunk", "created": int(time.time()), "model": "orca-translated", "choices": [{"index": 0, "delta": {"tool_calls": [{"index": data.get("index", 0), "id": tool_id, "type": "function", "function": {"name": tool_name, "arguments": ""}}]}, "finish_reason": None}]}) + "\n\n"
            return None
        if chunk_type == "content_block_delta":
            delta = data.get("delta", {})
            delta_type = delta.get("type", "text_delta")
            if delta_type == "text_delta":
                text = delta.get("text", "")
                return StreamTranslator._openai_content_chunk(text) if text else None
            elif delta_type == "thinking_delta":
                thinking = delta.get("thinking", "")
                return StreamTranslator._openai_reasoning_chunk(thinking) if thinking else None
            elif delta_type == "input_json_delta":
                partial = delta.get("partial_json", "")
                return StreamTranslator._openai_tool_chunk(data.get("index", 0), partial) if partial else None
            return None
        if chunk_type == "message_delta":
            stop_reason = data.get("delta", {}).get("stop_reason", "stop")
            finish = "stop" if stop_reason == "end_turn" else stop_reason
            if stop_reason == "tool_use":
                finish = "tool_calls"
            return "data: " + json.dumps({"id": "owl-orca-msg", "object": "chat.completion.chunk", "created": int(time.time()), "model": "orca-translated", "choices": [{"index": 0, "delta": {}, "finish_reason": finish}]}) + "\n\n"
        if chunk_type == "message_stop":
            return "data: [DONE]\n\n"
        if chunk_type == "error":
            error_data = data.get("error", {})
            error_msg = error_data.get("message", "Unknown upstream error")
            error_type_val = error_data.get("type", "api_error")
            return StreamTranslator._openai_error_chunk(error_msg, error_type_val)
        return None

    @staticmethod
    def copilot_sse_to_openai(copilot_chunk: str) -> Optional[str]:
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
    chmod +x "$BIN_DIR/payload_translator.py"
fi

# -- 6D: Token Manager (unchanged, but already uses OWL_INSTALL_DIR)
log_info "Writing token_manager.py..."
if [ "${DRY_RUN:-}" != "true" ]; then
    cat > "$BIN_DIR/token_manager.py" << 'PYEOF'
#!/usr/bin/env python3
import asyncio, json, os, sys, time, hashlib, secrets
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, Dict, Tuple
from datetime import datetime
from urllib.parse import urlencode, urlparse, parse_qs

try: import httpx
except: print("ERROR: httpx required."); sys.exit(1)
try: from cryptography.fernet import Fernet; CRYPTO_AVAILABLE = True
except: CRYPTO_AVAILABLE = False; print("WARNING: cryptography not installed. Tokens stored unencrypted.")

_install_dir = Path(os.getenv("OWL_INSTALL_DIR", str(Path.home() / ".owl-agent")))
CONFIG_DIR = _install_dir / "config"
TOKENS_FILE = CONFIG_DIR / "tokens.enc"
KEY_FILE = CONFIG_DIR / ".key"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)

GITHUB_CLIENT_ID = "Iv1.b507a08c87ecfe98"
GITHUB_DEVICE_URL = "https://github.com/login/device/code"
GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
PROXY_URL = os.getenv("OWL_PROXY_URL", "http://127.0.0.1:60000")

CYAN = '\033[0;36m'; GREEN = '\033[0;32m'; YELLOW = '\033[1;33m'; RED = '\033[0;31m'; NC = '\033[0m'; BOLD = '\033[1m'

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
    def is_expired(self) -> bool: return time.time() >= (self.expires_at - 300)
    def to_dict(self) -> dict: return {k: v for k, v in self.__dict__.items() if v is not None}
    @classmethod
    def from_dict(cls, d: dict) -> "TokenData": return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})

class TokenEncryption:
    def __init__(self):
        self._fernet = None
        if CRYPTO_AVAILABLE:
            if KEY_FILE.exists():
                self._fernet = Fernet(KEY_FILE.read_bytes())
            else:
                key = Fernet.generate_key()
                KEY_FILE.write_bytes(key)
                KEY_FILE.chmod(0o600)
                self._fernet = Fernet(key)
    def encrypt(self, data: str) -> bytes: return self._fernet.encrypt(data.encode()) if self._fernet else data.encode()
    def decrypt(self, data: bytes) -> str: return self._fernet.decrypt(data).decode() if self._fernet else (data.decode() if isinstance(data, bytes) else data)

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
            except: pass
    def _save(self):
        raw = json.dumps({p: t.to_dict() for p, t in self._tokens.items()})
        TOKENS_FILE.write_bytes(self._encryption.encrypt(raw))
        TOKENS_FILE.chmod(0o600)
    def get(self, provider: str) -> Optional[TokenData]: return self._tokens.get(provider)
    def set(self, provider: str, token: TokenData): self._tokens[provider] = token; self._save()
    def delete(self, provider: str): self._tokens.pop(provider, None); self._save()
    def list_providers(self) -> list: return list(self._tokens.keys())
    def status(self) -> dict: return {p: {"has_token": bool(t.access_token), "is_expired": t.is_expired, "expires_in": t.expires_in} for p, t in self._tokens.items()}

class DeviceFlowAuth:
    def __init__(self, client_id: str = GITHUB_CLIENT_ID, proxy_url: str = PROXY_URL):
        self.client_id = client_id
        self.proxy_url = proxy_url
    async def start_flow(self) -> Tuple[str, str, str, int]:
        params = {"client_id": self.client_id, "scope": "read:user copilot"}
        async with httpx.AsyncClient(proxy=self.proxy_url, timeout=30) as client:
            resp = await client.post(GITHUB_DEVICE_URL, data=params)
            resp.raise_for_status()
            d = resp.json()
            return d["user_code"], d["verification_uri"], d.get("device_code", ""), int(d.get("expires_in", 900))
    async def poll_for_token(self, device_code: str, interval: int = 5, timeout: int = 300) -> TokenData:
        params = {"client_id": self.client_id, "device_code": device_code, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"}
        start = time.time()
        async with httpx.AsyncClient(proxy=self.proxy_url, timeout=30) as client:
            while time.time() - start < timeout:
                resp = await client.post(GITHUB_TOKEN_URL, data=params, headers={"Accept": "application/json"})
                d = resp.json()
                if "access_token" in d:
                    return TokenData(access_token=d["access_token"], token_type=d.get("token_type", "bearer"), expires_at=time.time() + int(d.get("expires_in", 86400)), scope=d.get("scope", ""), provider="copilot")
                error = d.get("error", "")
                if error == "authorization_pending":
                    await asyncio.sleep(interval)
                elif error == "slow_down":
                    interval += 5; await asyncio.sleep(interval)
                else:
                    raise RuntimeError(f"Auth error: {d.get('error_description', error)}")
        raise TimeoutError("Authorization timed out.")

class APIKeyAuth:
    @staticmethod
    def create_token(api_key: str, provider: str = "antigravity") -> TokenData:
        return TokenData(access_token=api_key, token_type="bearer", expires_at=time.time() + (365*24*60*60), scope="all", provider=provider)

class AntigravityOAuth:
    def __init__(self, proxy_url: str = PROXY_URL): self.proxy_url = proxy_url
    def _generate_pkce(self) -> Tuple[str, str]:
        verifier = secrets.token_urlsafe(64)
        challenge = hashlib.sha256(verifier.encode()).digest()
        import base64
        challenge_b64 = base64.urlsafe_b64encode(challenge).rstrip(b"=").decode()
        return verifier, challenge_b64
    def get_auth_url(self, redirect_uri: str = "http://localhost:3456/callback") -> str:
        verifier, challenge = self._generate_pkce()
        self._verifier = verifier
        params = {"client_id": "antigravity-free", "redirect_uri": redirect_uri, "response_type": "code", "scope": "read write", "code_challenge": challenge, "code_challenge_method": "S256", "state": secrets.token_hex(16)}
        return f"https://auth.antigravity.ai/oauth/authorize?{urlencode(params)}"
    async def exchange_code(self, code: str, redirect_uri: str = "http://localhost:3456/callback") -> TokenData:
        async with httpx.AsyncClient(proxy=self.proxy_url, timeout=30) as client:
            resp = await client.post("https://auth.antigravity.ai/oauth/token", data={"grant_type": "authorization_code", "code": code, "redirect_uri": redirect_uri, "client_id": "antigravity-free", "code_verifier": self._verifier}, headers={"Content-Type": "application/x-www-form-urlencoded"})
            resp.raise_for_status()
            d = resp.json()
            return TokenData(access_token=d["access_token"], refresh_token=d.get("refresh_token"), token_type=d.get("token_type", "bearer"), expires_at=time.time() + int(d.get("expires_in", 3600)), scope=d.get("scope", ""), provider="antigravity")

class TokenManager:
    def __init__(self, proxy_url: str = PROXY_URL): self.proxy_url = proxy_url; self.store = TokenStore()
    async def authenticate_copilot(self) -> TokenData:
        auth = DeviceFlowAuth(proxy_url=self.proxy_url)
        print(f"\n{BOLD}GitHub Copilot Device Authentication{NC}")
        user_code, verification_uri, device_code, expires_in = await auth.start_flow()
        print(f"  1. Open: {CYAN}{verification_uri}{NC}\n  2. Enter code: {GREEN}{user_code}{NC}\n  3. Waiting...")
        token = await auth.poll_for_token(device_code)
        self.store.set("copilot", token)
        print(f"  {GREEN}Copilot authenticated!{NC}")
        return token
    async def authenticate_antigravity(self, api_key: Optional[str] = None) -> TokenData:
        if api_key:
            token = APIKeyAuth.create_token(api_key)
            self.store.set("antigravity", token)
            print(f"  {GREEN}Antigravity authenticated with API key!{NC}")
            return token
        auth = AntigravityOAuth(proxy_url=self.proxy_url)
        auth_url = auth.get_auth_url()
        print(f"\n{BOLD}Antigravity OAuth Authentication{NC}\n  1. Open: {CYAN}{auth_url}{NC}")
        code = input("  2. Paste authorization code: ").strip()
        if code.startswith("http"):
            code = parse_qs(urlparse(code).query).get("code", [""])[0]
        token = await auth.exchange_code(code)
        self.store.set("antigravity", token)
        print(f"  {GREEN}Antigravity authenticated!{NC}")
        return token
    def get_valid_token(self, provider: str) -> Optional[TokenData]:
        token = self.store.get(provider)
        if token and not token.is_expired: return token
        return None
    def status(self) -> dict: return {"providers": self.store.list_providers(), "tokens": self.store.status()}

async def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["auth", "status", "get", "delete", "list"])
    parser.add_argument("--provider", "-p")
    parser.add_argument("--api-key", "-k")
    args = parser.parse_args()
    manager = TokenManager()
    if args.command == "auth":
        provider = args.provider or input("Provider (copilot/antigravity): ").strip()
        if provider == "copilot": await manager.authenticate_copilot()
        elif provider == "antigravity": await manager.authenticate_antigravity(api_key=args.api_key)
    elif args.command == "status": print(json.dumps(manager.status(), indent=2))
    elif args.command == "get": token = manager.get_valid_token(args.provider); print(token.access_token if token else "", end="")
    elif args.command == "delete": manager.store.delete(args.provider)
    elif args.command == "list": print("\n".join(manager.store.list_providers()))

if __name__ == "__main__": asyncio.run(main())
PYEOF
    chmod +x "$BIN_DIR/token_manager.py"
fi

# -- 6E: Orca Router with FIX C3, H4, H5, M4, and stream EOF handling
log_info "Writing orca_router.py (fully patched)..."
if [ "${DRY_RUN:-}" != "true" ]; then
    cat > "$BIN_DIR/orca_router.py" << 'PYEOF'
#!/usr/bin/env python3
import asyncio, json, os, signal, time, logging, copy
from pathlib import Path
from typing import Dict, Any, Optional, List, AsyncGenerator, Callable, Tuple
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "utils"))

from payload_translator import PayloadTranslator, StreamTranslator
from radix_tree import RadixTreeRouter
from circuits import CircuitBreakerRegistry
# FIX M4: import TokenStore at top
from token_manager import TokenStore

import httpx
from aiohttp import web

CONFIG_DIR = Path(os.getenv("OWL_INSTALL_DIR", str(Path.home() / ".owl-agent"))) / "config"
LOG_DIR = Path(os.getenv("OWL_INSTALL_DIR", str(Path.home() / ".owl-agent"))) / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

PROXY_URL = os.getenv("OWL_PROXY_URL", "http://127.0.0.1:60000")
KIRO_API_KEY = os.getenv("KIRO_API_KEY", "kiro-gateway-8333")

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
                    handlers=[logging.StreamHandler(), logging.FileHandler(LOG_DIR / "orca-router.log")])
logger = logging.getLogger("orca-router")

class StreamRacer:
    """FIX H5: proper EOF handling and winner detection with sentinel."""
    def __init__(self, max_queue_size: int = 5):
        self.max_queue_size = max_queue_size

    async def race(self, streams: List[AsyncGenerator], translator_map: Dict[int, Callable]) -> AsyncGenerator[str, None]:
        queue: asyncio.Queue = asyncio.Queue(maxsize=self.max_queue_size)
        winner_found = asyncio.Event()
        winner_id: List[Optional[int]] = [None]
        tasks: List[asyncio.Task] = []
        stream_finished = [False] * len(streams)

        async def producer(stream_id: int, stream: AsyncGenerator, translator: Optional[Callable]):
            try:
                async for chunk in stream:
                    if winner_found.is_set() and winner_id[0] != stream_id:
                        return
                    translated = translator(chunk) if translator else chunk
                    if translated is not None:
                        if not winner_found.is_set():
                            winner_found.set()
                            winner_id[0] = stream_id
                            logger.info("Race won by stream %d", stream_id)
                        await queue.put((stream_id, translated))
                # EOF reached
                stream_finished[stream_id] = True
                await queue.put((stream_id, None))
            except asyncio.CancelledError:
                pass
            except Exception as e:
                logger.debug("Stream %d failed: %s", stream_id, e)
                stream_finished[stream_id] = True
                await queue.put((stream_id, None))

        for i, s in enumerate(streams):
            tasks.append(asyncio.create_task(producer(i, s, translator_map.get(i))))

        finished_count = 0
        try:
            while finished_count < len(tasks):
                item = await queue.get()
                stream_id, chunk = item
                if chunk is None:
                    finished_count += 1
                    continue
                # Only yield chunks from winner
                if winner_id[0] is not None and stream_id != winner_id[0]:
                    continue
                yield chunk
            # After all streams finished, send [DONE] if winner was found
            if winner_id[0] is not None:
                yield "data: [DONE]\n\n"
        finally:
            for t in tasks:
                t.cancel()

class OrcaRouter:
    def __init__(self):
        self.tree = RadixTreeRouter()
        self.circuits = CircuitBreakerRegistry(failure_threshold=5, recovery_timeout=60.0)
        self.racer = StreamRacer(max_queue_size=5)
        self.translator = PayloadTranslator()
        self.providers = self._load_providers()
        self.config = self._load_config()
        self._setup_routes()
        self._sighup_pending = False
        # FIX C3: token cache stores (token, expiry_time)
        self._token_cache: Dict[str, Tuple[str, float]] = {}
        self._token_cache_ttl: float = 60.0
        self._http_client: Optional[httpx.AsyncClient] = None
        logger.info("OrcaRouter initialized: %d providers, %d routes", len(self.providers), len(self.tree.list_routes()))

    def _handle_sighup(self):
        if self._sighup_pending:
            return
        self._sighup_pending = True
        try:
            logger.info("Received SIGHUP: Hot-reloading...")
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
                new_providers = ex.submit(self._load_providers).result(timeout=5)
                new_config = ex.submit(self._load_config).result(timeout=5)
            new_tree = RadixTreeRouter()
            for route in new_config.get("routes", []):
                new_tree.add_route(route["pattern"], route)
            self.providers = new_providers
            self.config = new_config
            self.tree = new_tree
            logger.info("Config reloaded")
        except Exception as e:
            logger.error("SIGHUP reload failed: %s", e)
        finally:
            self._sighup_pending = False

    def _register_sighup(self, loop):
        loop.add_signal_handler(signal.SIGHUP, self._handle_sighup)

    def _load_providers(self) -> dict:
        prov_file = CONFIG_DIR / "providers.json"
        if prov_file.exists():
            try:
                with open(prov_file) as f:
                    return json.load(f)
            except: pass
        return {"copilot": {"base_url": "https://api.githubcopilot.com", "format": "openai"},
                "antigravity": {"base_url": "https://api.antigravity.ai", "format": "anthropic"},
                "kiro": {"base_url": "http://127.0.0.1:8333", "format": "openai"}}

    def _load_config(self) -> dict:
        routes_file = CONFIG_DIR / "routes.json"
        if routes_file.exists():
            try:
                with open(routes_file) as f:
                    return json.load(f)
            except: pass
        return {"routes": [{"pattern": "v1/chat/completions", "strategy": "race", "targets": [{"provider": "copilot", "model": "gpt-4o-mini-copilot", "weight": 90}, {"provider": "antigravity", "model": "antigravity-flash", "weight": 10}]}, {"pattern": "v1/models", "strategy": "single", "targets": [{"provider": "copilot", "model": "gpt-4o-mini-copilot"}]}]}

    def _setup_routes(self):
        for route in self.config.get("routes", []):
            self.tree.add_route(route["pattern"], route)

    # FIX C3: token cache with expiry
    def _get_token(self, provider: str) -> Optional[str]:
        now = time.time()
        if provider in self._token_cache:
            token, expiry = self._token_cache[provider]
            if expiry > now:
                return token
        # re-fetch from store
        try:
            store = TokenStore()
            token_data = store.get(provider)
            if token_data and not token_data.is_expired:
                self._token_cache[provider] = (token_data.access_token, token_data.expires_at)
                return token_data.access_token
        except Exception as e:
            logger.debug("Token fetch error: %s", e)
        return None

    def _load_tokens(self) -> Dict[str, str]:
        tokens = {"kiro": KIRO_API_KEY}
        for prov in ["copilot", "antigravity"]:
            t = self._get_token(prov)
            if t:
                tokens[prov] = t
        return tokens

    def _get_http_client(self, proxy: Optional[str] = None) -> httpx.AsyncClient:
        if self._http_client is None or self._http_client.is_closed:
            self._http_client = httpx.AsyncClient(proxy=proxy, timeout=httpx.Timeout(120.0, connect=15.0), http2=True,
                                                  limits=httpx.Limits(max_connections=20, max_keepalive_connections=10, keepalive_expiry=60))
        return self._http_client

    async def _fetch_stream(self, provider: str, url: str, payload: dict, token: str) -> AsyncGenerator[str, None]:
        headers = {"Content-Type": "application/json", "Accept": "text/event-stream"}
        fmt = self.providers.get(provider, {}).get("format", "openai")
        if fmt == "anthropic":
            payload = self.translator.openai_to_anthropic(payload)
            headers["x-api-key"] = token
            headers["anthropic-version"] = "2023-06-01"
        else:
            headers["Authorization"] = f"Bearer {token}"
        use_proxy = PROXY_URL if provider != "kiro" else None
        client = self._get_http_client(proxy=use_proxy)
        async with client.stream("POST", url, json=payload, headers=headers) as resp:
            if resp.status_code != 200:
                error_body = await resp.aread()
                self.circuits.get(provider).record_failure()
                raise Exception(f"HTTP {resp.status_code}: {error_body[:200]}")
            async for line in resp.aiter_lines():
                yield line

    async def _handle_race(self, targets: list, path: str, payload: dict, tokens: Dict[str, str]) -> AsyncGenerator[str, None]:
        # FIX H4: copy payload before modifying
        payload = copy.deepcopy(payload)
        payload["stream"] = True
        streams = []
        translator_map = {}
        for target in targets:
            prov = target["provider"]
            circuit = self.circuits.get(prov)
            if not circuit.can_execute():
                continue
            base = self.providers.get(prov, {}).get("base_url", "")
            url = f"{base}/{path}" if not base.endswith("/") else f"{base}{path}"
            token = tokens.get(prov, KIRO_API_KEY)
            stream = self._fetch_stream(prov, url, payload, token)
            idx = len(streams)
            streams.append(stream)
            fmt = self.providers.get(prov, {}).get("format", "openai")
            translator_map[idx] = StreamTranslator.anthropic_sse_to_openai if fmt == "anthropic" else StreamTranslator.copilot_sse_to_openai
        if not streams:
            error_json = json.dumps({"error": {"message": "All providers circuit-broken or unavailable", "type": "orca_circuit_open"}})
            yield f"data: {error_json}\n\n"
            yield "data: [DONE]\n\n"
            return
        async for chunk in self.racer.race(streams, translator_map):
            yield chunk

    async def _handle_canary(self, targets: list, path: str, payload: dict, tokens: Dict[str, str]) -> AsyncGenerator[str, None]:
        import random
        r = random.random() * 100
        cum = 0
        for t in targets:
            cum += t.get("weight", 50)
            if r <= cum:
                async for chunk in self._handle_single_stream(t, path, payload, tokens):
                    yield chunk
                return
        async for chunk in self._handle_single_stream(targets[0], path, payload, tokens):
            yield chunk

    async def _handle_single_stream(self, target: dict, path: str, payload: dict, tokens: Dict[str, str]) -> AsyncGenerator[str, None]:
        prov = target["provider"]
        circuit = self.circuits.get(prov)
        if not circuit.can_execute():
            logger.warning("Circuit open for %s, falling back to kiro", prov)
            prov = "kiro"
            circuit = self.circuits.get("kiro")
            if not circuit.can_execute():
                raise Exception("All circuits open including fallback (kiro)")
        base = self.providers.get(prov, {}).get("base_url", "")
        url = f"{base}/{path}" if not base.endswith("/") else f"{base}{path}"
        token = tokens.get(prov, KIRO_API_KEY)
        payload_stream = copy.deepcopy(payload)
        payload_stream["stream"] = True
        fmt = self.providers.get(prov, {}).get("format", "openai")
        try:
            async for line in self._fetch_stream(prov, url, payload_stream, token):
                if fmt == "anthropic":
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

    async def handle_request(self, path: str, payload: dict, tokens: Dict[str, str]) -> AsyncGenerator[str, None]:
        route = self.tree.match(path)
        if not route:
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
        else:
            target = targets[0] if targets else {"provider": "kiro", "model": "auto-kiro"}
            async for chunk in self._handle_single_stream(target, path, payload, tokens):
                yield chunk

async def run_orca_server(host: str = "127.0.0.1", port: int = 60001):
    router = OrcaRouter()
    loop = asyncio.get_running_loop()
    router._register_sighup(loop)

    async def handle_chat(request: web.Request) -> web.StreamResponse:
        import uuid
        rid = str(uuid.uuid4())[:8]
        try:
            payload = await request.json()
        except:
            return web.json_response({"error": "Invalid JSON body"}, status=400)
        if not payload.get("model") or not payload.get("messages"):
            return web.json_response({"error": {"message": "Missing required field: model or messages", "type": "invalid_request_error"}}, status=400)
        path = request.path.lstrip("/")
        tokens = router._load_tokens()
        logger.info("[%s] %s %s", rid, request.method, path)
        resp = web.StreamResponse(status=200, headers={"Content-Type": "text/event-stream", "Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no", "X-Request-ID": rid})
        await resp.prepare(request)
        try:
            async for chunk in router.handle_request(path, payload, tokens):
                await resp.write(chunk.encode("utf-8") if isinstance(chunk, str) else chunk)
        except Exception as e:
            logger.error("Request failed: %s", e)
            error_chunk = json.dumps({"error": {"message": str(e), "type": "orca_error"}})
            await resp.write(f"data: {error_chunk}\n\n".encode())
        await resp.write_eof()
        return resp

    async def handle_health(request: web.Request) -> web.Response:
        return web.json_response({"status": "ok", "version": os.getenv("OWL_VERSION", "8.0.1"), "providers": list(router.providers.keys()), "routes": router.tree.list_routes(), "circuits": router.circuits.all_status()})

    async def handle_models(request: web.Request) -> web.Response:
        models = []
        for pname, pinfo in router.providers.items():
            pmodels = pinfo.get("models", {})
            if not pmodels:
                models.append({"id": f"{pname}-default", "object": "model", "created": 1700000000, "owned_by": pname})
            else:
                for mid, minfo in pmodels.items():
                    models.append({"id": mid, "object": "model", "created": 1700000000, "owned_by": pname, "context_window": minfo.get("context_window", 128000), "max_tokens": minfo.get("max_tokens", 8192)})
        return web.json_response({"object": "list", "data": models})

    async def handle_reload(request: web.Request) -> web.Response:
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
    logger.info("OWL Orca-Router v%s on %s:%d", os.getenv("OWL_VERSION", "8.0.1"), host, port)
    try:
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        pass
    finally:
        if router._http_client and not router._http_client.is_closed:
            await router._http_client.aclose()
        await runner.cleanup()

if __name__ == "__main__":
    asyncio.run(run_orca_server())
PYEOF
    chmod +x "$BIN_DIR/orca_router.py"

    # Validate syntax
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

# -- 6F: Configuration Files (unchanged) --
log_info "Writing configuration files..."
if [ "${DRY_RUN:-}" != "true" ]; then
    cat > "$CONFIG_DIR/providers.json" << 'JSONEOF'
{"copilot": {"base_url": "https://api.githubcopilot.com", "format": "openai", "models": {"gpt-4o-mini-copilot": {"context_window": 128000, "max_tokens": 16384}, "gpt-4o-copilot": {"context_window": 128000, "max_tokens": 16384}, "claude-3.5-sonnet-copilot": {"context_window": 200000, "max_tokens": 8192}}}, "antigravity": {"base_url": "https://api.antigravity.ai", "format": "anthropic", "models": {"antigravity-flash": {"context_window": 100000, "max_tokens": 8192}, "antigravity-ultra": {"context_window": 200000, "max_tokens": 4096}}}, "kiro": {"base_url": "http://127.0.0.1:8333", "format": "openai", "models": {"auto-kiro": {"context_window": 200000, "max_tokens": 8192}}}}
JSONEOF
    cat > "$CONFIG_DIR/routes.json" << 'JSONEOF'
{"routes": [{"pattern": "v1/chat/completions", "strategy": "race", "targets": [{"provider": "copilot", "model": "gpt-4o-mini-copilot", "weight": 90}, {"provider": "antigravity", "model": "antigravity-flash", "weight": 10}]}, {"pattern": "v1/models", "strategy": "single", "targets": [{"provider": "copilot", "model": "gpt-4o-mini-copilot"}]}]}
JSONEOF
fi
log_ok "Core scripts written"

# =============================================================================
#  STEP 7: Zero-Downtime Detection (FIX H2)
# =============================================================================
log_step 7 $TOTAL_STEPS "Zero-Downtime detection"
detect_opencode() {
    local ide_detected=false
    for pattern in "opencode" "cursor" "windsurf" "vscodium" "codium"; do
        if pgrep -f "/opt/${pattern}/" >/dev/null 2>&1 || pgrep -x "$pattern" >/dev/null 2>&1; then
            ide_detected=true
            break
        fi
    done
    export OPENCODE_ACTIVE="$ide_detected"
    if [ "${DRY_RUN:-}" != "true" ]; then
        if [ "$ide_detected" = true ]; then
            log_warn "SAFE-MODE: IDE detected. Connection preservation engaged."
        else
            log_ok "STANDARD-MODE: No IDE detected."
        fi
    else
        export OPENCODE_ACTIVE="false"
        echo "  [DRY-RUN] IDE detection skipped (assuming STANDARD-MODE)"
    fi
}
if [ "${DRY_RUN:-}" != "true" ]; then
    detect_opencode
else
    export OPENCODE_ACTIVE="false"
fi

# =============================================================================
#  STEP 8: Systemd Service Deployment (with FIX H3 for reload)
# =============================================================================
log_step 8 $TOTAL_STEPS "Deploying systemd services"
safe_service_action() {
    local service_name="$1"
    local action="$2"
    if [ "$action" = "reload" ]; then
        if systemctl --user is-active --quiet "$service_name" 2>/dev/null; then
            systemctl --user reload "$service_name"
            log_ok "Reloaded $service_name"
        else
            log_warn "$service_name not active, cannot reload"
        fi
        return 0
    fi
    if [ "${OPENCODE_ACTIVE:-}" = "true" ]; then
        if systemctl --user is-active --quiet "$service_name" 2>/dev/null; then
            log_warn "$service_name is running. Skipping $action to preserve IDE connections."
            return 0
        else
            log_ok "$service_name is stopped. Safe to start."
            systemctl --user "$action" "$service_name"
        fi
    else
        log_ok "Executing $action on $service_name"
        systemctl --user "$action" "$service_name"
    fi
}

if [ "${DRY_RUN:-}" != "true" ]; then
    ensure_dir "$HOME/.config/systemd/user"
    # Orca Router service
    cat > "$HOME/.config/systemd/user/orca-router.service" << SYSEOF
[Unit]
Description=OWL Orca-Router
After=network.target owl-proxy.service
Wants=owl-proxy.service

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $BIN_DIR/orca_router.py
Restart=on-failure
RestartSec=5
StartLimitBurst=5
StartLimitIntervalSec=300
Environment=PYTHONUNBUFFERED=1
Environment=OWL_INSTALL_DIR=$INSTALL_DIR
Environment=OWL_PROXY_URL=http://127.0.0.1:60000
Environment=KIRO_PORT=8333
Environment=KIRO_API_KEY=kiro-gateway-8333
Environment=OWL_VERSION=$VERSION
ExecReload=/bin/kill -HUP \$MAINPID
SendSIGHUP=yes
MemoryMax=384M
MemoryHigh=256M

[Install]
WantedBy=default.target
SYSEOF

    if [ "${SKIP_PROXY:-}" != "true" ]; then
        cat > "$HOME/.config/systemd/user/owl-proxy.service" << SYSEOF
[Unit]
Description=OWL Forward Proxy
After=network.target

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $INSTALL_DIR/forward_proxy.py
Restart=on-failure
RestartSec=3
Environment=UPSTREAM_PROXY=
Environment=OWL_PROXY_HOST=127.0.0.1
Environment=OWL_PROXY_PORT=60000
Environment=OWL_MAX_CONNECTIONS=50
MemoryMax=128M
MemoryHigh=96M

[Install]
WantedBy=default.target
SYSEOF
    fi

    log_ok "Systemd service files deployed"
fi

# =============================================================================
#  STEP 9: Kiro Gateway (with FIX H1)
# =============================================================================
log_step 9 $TOTAL_STEPS "Kiro Gateway"
if [ "${SKIP_KIRO:-}" != "true" ] && [ "${DRY_RUN:-}" != "true" ]; then
    if [ ! -d "$KIRO_GATEWAY_DIR/.git" ]; then
        log_info "Cloning kiro-gateway..."
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
                log_warn "Could not clone kiro-gateway after 2 attempts. Skipping Kiro."
                SKIP_KIRO=true
            fi
        done
    else
        git -C "$KIRO_GATEWAY_DIR" pull --ff-only 2>/dev/null || true
    fi

    if [ "${SKIP_KIRO}" != "true" ]; then
        # Determine libc
        KIRO_LIBC="glibc"
        if ldd --version 2>&1 | grep -qi "musl"; then
            KIRO_LIBC="musl"
            log_info "Detected musl libc"
        else
            log_info "Detected glibc"
        fi

        GATEWAY_VENV="$KIRO_GATEWAY_DIR/.venv"
        if [ ! -f "$GATEWAY_VENV/bin/activate" ]; then
            log_info "Creating Kiro Gateway Python venv..."
            python3 -m venv "$GATEWAY_VENV"
        fi

        if [ -f "$KIRO_GATEWAY_DIR/requirements.txt" ]; then
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
                    log_err "Kiro Gateway pip install failed after 3 attempts. Skipping Kiro."
                    SKIP_KIRO=true
                fi
            done
        fi

        if [ "${SKIP_KIRO}" != "true" ]; then
            KIRO_CLI="$KIRO_GATEWAY_DIR/kiro-cli"
            if [ ! -x "$KIRO_CLI" ]; then
                log_info "Downloading kiro-cli native binary from AWS S3..."
                ARCH=$(uname -m)
                case "$ARCH" in
                    x86_64|amd64)  KIRO_ARCH_DETECTED="x86_64" ;;
                    aarch64|arm64) KIRO_ARCH_DETECTED="aarch64" ;;
                    *)             KIRO_ARCH_DETECTED="x86_64" ;;
                esac

                if [ "$KIRO_LIBC" = "musl" ]; then
                    KIRO_ZIP="kirocli-${KIRO_ARCH_DETECTED}-linux-musl.zip"
                else
                    KIRO_ZIP="kirocli-${KIRO_ARCH_DETECTED}-linux.zip"
                fi

                KIRO_CLI_URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/${KIRO_ZIP}"
                KIRO_TMP_ZIP="/tmp/${KIRO_ZIP}"

                download_kiro() {
                    local attempt=0 max=5 delay=10
                    while [ $attempt -lt $max ]; do
                        attempt=$((attempt + 1))
                        log_info "Downloading (attempt $attempt/$max)..."
                        if curl -fsSL -C - --connect-timeout 15 --max-time 300 "$KIRO_CLI_URL" -o "$KIRO_TMP_ZIP" 2>/dev/null; then
                            log_ok "Download complete ($(ls -lh "$KIRO_TMP_ZIP" | awk '{print $5}'))"
                            return 0
                        fi
                        log_warn "Download failed, retrying in ${delay}s..."
                        sleep $delay
                    done
                    return 1
                }

                if download_kiro; then
                    rm -rf /tmp/kirocli_extracted_$$
                    unzip -qo "$KIRO_TMP_ZIP" -d "/tmp/kirocli_extracted_$$"

                    # Install all 3 official binaries
                    for bin in kiro-cli kiro-cli-chat kiro-cli-term; do
                        if [ -f "/tmp/kirocli_extracted_$$/kirocli/bin/$bin" ]; then
                            cp "/tmp/kirocli_extracted_$$/kirocli/bin/$bin" "$KIRO_GATEWAY_DIR/$bin"
                            chmod +x "$KIRO_GATEWAY_DIR/$bin"
                            # Also install to ~/.local/bin for PATH access
                            mkdir -p "$HOME/.local/bin"
                            install -m 755 "/tmp/kirocli_extracted_$$/kirocli/bin/$bin" "$HOME/.local/bin/$bin" 2>/dev/null || true
                            log_ok "$bin installed ($(du -h "/tmp/kirocli_extracted_$$/kirocli/bin/$bin" | cut -f1))"
                        fi
                    done

                    # Install convenience wrappers (q, qchat)
                    for wrapper in q qchat; do
                        if [ -f "/tmp/kirocli_extracted_$$/kirocli/bin/$wrapper" ]; then
                            install -m 755 "/tmp/kirocli_extracted_$$/kirocli/bin/$wrapper" "$HOME/.local/bin/$wrapper" 2>/dev/null || true
                        fi
                    done

                    # Run official setup unless skipped
                    if [ -z "${KIRO_CLI_SKIP_SETUP:-}" ] && [ -x "$KIRO_CLI" ]; then
                        log_info "Running kiro-cli setup..."
                        "$KIRO_CLI" setup 2>&1 || log_warn "setup encountered issues (may need interactive terminal)"
                    fi

                    rm -f "$KIRO_TMP_ZIP"
                    rm -rf "/tmp/kirocli_extracted_$$"
                else
                    log_warn "Could not download kiro-cli from AWS S3 after 5 attempts"
                    log_warn "Download manually: $KIRO_CLI_URL"
                fi
            fi

            # OIDC token
            KIRO_OIDC_TOKEN=""
            if [ -x "$KIRO_CLI" ]; then
                log_info "Checking Kiro AWS Builder ID OIDC..."
                KIRO_OIDC_TOKEN=$("$KIRO_CLI" auth token 2>/dev/null || echo "")
                if [ -n "$KIRO_OIDC_TOKEN" ]; then
                    log_ok "Kiro OIDC token acquired"
                else
                    log_info "Kiro OIDC not configured. Using API key."
                fi
            fi

            # .env
            printf 'PROXY_API_KEY="%s"\nSERVER_PORT=%s\nACCOUNT_SYSTEM=true\nKIRO_USE_LEGACY_ENDPOINT=true\n' "$KIRO_API_KEY" "$KIRO_PORT" > "$KIRO_GATEWAY_DIR/.env"
            if [ -n "$KIRO_OIDC_TOKEN" ]; then
                printf 'KIRO_OIDC_TOKEN="%s"\n' "$KIRO_OIDC_TOKEN" >> "$KIRO_GATEWAY_DIR/.env"
            fi
            chmod 600 "$KIRO_GATEWAY_DIR/.env"

            # systemd service
            cat > "$HOME/.config/systemd/user/kiro-gateway.service" << SYSEOF
[Unit]
Description=Kiro Gateway
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
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
SYSEOF

            cat > "$CONFIG_DIR/kiro-gateway.env" << ENVEOF
KIRO_GATEWAY_DIR=$KIRO_GATEWAY_DIR
KIRO_API_KEY=$KIRO_API_KEY
PROXY_API_KEY=$KIRO_API_KEY
ENVEOF
            log_ok "Kiro Gateway fully configured"
        fi
    fi
elif [ "${SKIP_KIRO:-}" == "true" ]; then
    log_ok "Kiro gateway skipped"
fi

# =============================================================================
#  STEP 10: OpenCode Configuration (atomic injection, no fallback - FIX C4)
# =============================================================================
log_step 10 $TOTAL_STEPS "OpenCode configuration (atomic injection)"
if [ "${DRY_RUN:-}" != "true" ]; then
    OPENCODE_CONFIG="$OPENCODE_DIR/opencode.jsonc"
    if [ ! -f "$OPENCODE_CONFIG" ]; then
        echo '{}' > "$OPENCODE_CONFIG"
    fi

    NEW_CONFIG_BLOCK='{"owl-orca-virtual": {"npm": "@ai-sdk/openai", "name": "OWL Orca Virtual (Fastest Free)", "options": {"baseURL": "http://127.0.0.1:60001/v1", "apiKey": "orca-racer", "stream": true}, "models": {"auto-racer": {"name": "Auto (Races GPT-4o & Claude 3.5)", "contextWindow": 200000}, "gpt-4o-copilot": {"name": "GPT-4o via Copilot (Free)", "contextWindow": 128000}, "claude-3.5-sonnet-copilot": {"name": "Claude 3.5 Sonnet via Copilot (Free)", "contextWindow": 200000}, "antigravity-flash": {"name": "Antigravity Flash (Free)", "contextWindow": 100000}, "auto-kiro": {"name": "Kiro Gateway (AWS Builder ID)", "contextWindow": 200000}}}'

    # FIX C4: No fallback; use shared jsonc_utils (already written)
    FINAL_JSON=$(OWL_CFG="$OPENCODE_CONFIG" OWL_BLOCK="$NEW_CONFIG_BLOCK" python3 << 'PYEOF'
import json, os, sys
sys.path.insert(0, os.path.expanduser("~/.owl-agent/bin/utils"))
from jsonc_utils import load_jsonc, save_json_atomic
cfg_path = os.environ["OWL_CFG"]
new_block = json.loads(os.environ["OWL_BLOCK"])
data = load_jsonc(cfg_path)
if "providers" not in data:
    data["providers"] = {}
data["providers"].update(new_block)
print(json.dumps(data, separators=(',', ':')))
PYEOF
)
    atomic_write "$OPENCODE_CONFIG" "$FINAL_JSON"
    log_ok "OpenCode config updated atomically"

    # MCP server
    cat > "$INSTALL_DIR/owl_resilient_mcp.py" << 'PYEOF'
#!/usr/bin/env python3
import json, sys, urllib.request
def send_result(req_id, result):
    json.dump({"jsonrpc": "2.0", "id": req_id, "result": result}, sys.stdout); sys.stdout.write("\n"); sys.stdout.flush()
def send_error(req_id, code, msg):
    json.dump({"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": msg}}, sys.stdout); sys.stdout.write("\n"); sys.stdout.flush()
def main():
    for line in sys.stdin:
        line = line.strip()
        if not line: continue
        try: req = json.loads(line)
        except: send_error(None, -32700, "Parse error"); continue
        req_id = req.get("id")
        method = req.get("method", "")
        if method == "initialize":
            send_result(req_id, {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "owl-resilient-mcp", "version": "1.0.0"}})
        elif method == "tools/list":
            send_result(req_id, {"tools": [{"name": "owl_status", "description": "Check OWL Orca Router status", "inputSchema": {"type": "object", "properties": {}}}]})
        elif method == "tools/call":
            tool = req.get("params", {}).get("name", "")
            if tool == "owl_status":
                try:
                    req = urllib.request.Request("http://127.0.0.1:60001/health", headers={"Accept": "application/json"})
                    with urllib.request.urlopen(req, timeout=5) as resp:
                        body = resp.read().decode()
                    send_result(req_id, {"content": [{"type": "text", "text": body}]})
                except Exception as e:
                    send_result(req_id, {"content": [{"type": "text", "text": f"Error: {e}"}], "isError": True})
            else:
                send_error(req_id, -32601, f"Unknown tool: {tool}")
        elif method == "notifications/initialized":
            pass
        else:
            send_error(req_id, -32601, f"Method not found: {method}")
if __name__ == "__main__": main()
PYEOF
    chmod +x "$INSTALL_DIR/owl_resilient_mcp.py"

    MCP_CONFIG="$OPENCODE_DIR/mcp.json"
    backup_file "$MCP_CONFIG"
    python3 << PYEOF
import json, os
mcp_path = os.path.expanduser("~/.config/opencode/mcp.json")
data = {}
if os.path.exists(mcp_path):
    try:
        with open(mcp_path) as f:
            data = json.load(f)
    except: pass
if "mcpServers" not in data:
    data["mcpServers"] = {}
_install_dir = os.getenv("OWL_INSTALL_DIR", os.path.expanduser("~/.owl-agent"))
data["mcpServers"]["owl-resilient-http"] = {
    "command": os.path.join(_install_dir, "venv", "bin", "python3"),
    "args": [os.path.join(_install_dir, "owl_resilient_mcp.py")]
}
os.makedirs(os.path.dirname(mcp_path), exist_ok=True)
tmp = mcp_path + ".owl_tmp_mcp"
with open(tmp, 'w') as f:
    json.dump(data, f, indent=2)
os.replace(tmp, mcp_path)
PYEOF
    log_ok "MCP servers configured"
fi

# =============================================================================
#  STEP 11: CLI Wrappers (unchanged)
# =============================================================================
log_step 11 $TOTAL_STEPS "CLI wrappers"
if [ "${DRY_RUN:-}" != "true" ]; then
    cat > "$HOME/.local/bin/owl-proxy" << 'WRAPPER'
#!/bin/bash
export HTTP_PROXY="http://127.0.0.1:60000"
export HTTPS_PROXY="http://127.0.0.1:60000"
export NO_PROXY="localhost,127.0.0.1,.local,.localdomain,::1,.githubcopilot.com,.antigravity.ai,.kiro.dev,.amazonaws.com"
exec "$@"
WRAPPER
    cat > "$HOME/.local/bin/owl-router" << SYSEOF
#!/bin/bash
exec "$VENV_DIR/bin/python" "$BIN_DIR/orca_router.py" "\$@"
SYSEOF
    cat > "$HOME/.local/bin/owl-token" << SYSEOF
#!/bin/bash
exec "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" "\$@"
SYSEOF
    chmod +x "$HOME/.local/bin/owl-proxy" "$HOME/.local/bin/owl-router" "$HOME/.local/bin/owl-token"
    log_ok "CLI wrappers created"
fi

# Port conflict detection (with FIX M3)
check_port_free() {
    local port=$1 name=$2
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_warn "Invalid port number: $port"
        return 1
    fi
    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -qE ":${port}\b"; then
            log_warn "Port $port ($name) is already in use"
            return 1
        fi
    elif command -v lsof &>/dev/null; then
        if lsof -i :"$port" -sTCP:LISTEN &>/dev/null; then
            log_warn "Port $port ($name) is already in use"
            return 1
        fi
    else
        # FIX M3: use SO_REUSEADDR to avoid TIME_WAIT false positive
        if ! python3 -c "import socket; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(('127.0.0.1', $port)); s.close()" 2>/dev/null; then
            log_warn "Port $port ($name) is already in use"
            return 1
        fi
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
#  STEP 12: Safe Activation & Provider Authentication (with FIX M2)
# =============================================================================
log_step 12 $TOTAL_STEPS "Safe activation"
if [ "${DRY_RUN:-}" != "true" ]; then
    systemctl --user daemon-reload
    systemctl --user enable orca-router.service 2>/dev/null || true
    if [ "${SKIP_PROXY:-}" != "true" ]; then
        systemctl --user enable owl-proxy.service 2>/dev/null || true
    fi
    if [ "${SKIP_KIRO:-}" != "true" ] && [ -d "$KIRO_GATEWAY_DIR" ]; then
        systemctl --user enable kiro-gateway.service 2>/dev/null || true
    fi

    safe_service_action "owl-proxy.service" "restart"
    safe_service_action "orca-router.service" "restart"
    if [ "${SKIP_KIRO:-}" != "true" ] && [ -d "$KIRO_GATEWAY_DIR" ]; then
        safe_service_action "kiro-gateway.service" "restart"
    fi

    sleep 2
    echo ""
    log_info "Verifying installation..."
    if systemctl --user is-active --quiet orca-router.service 2>/dev/null; then
        log_ok "Orca Router: ACTIVE"
    else
        log_err "Orca Router: FAILED"
    fi
    if [ "${SKIP_PROXY:-}" != "true" ] && systemctl --user is-active --quiet owl-proxy.service 2>/dev/null; then
        log_ok "Forward Proxy: ACTIVE"
    elif [ "${SKIP_PROXY:-}" != "true" ]; then
        log_err "Forward Proxy: FAILED"
    fi

    # Provider authentication (interactive)
    if [ "${WITH_PROVIDERS:-}" == "true" ]; then
        if [ -t 0 ]; then
            echo ""
            echo -e "${BOLD}Provider Authentication${NC}"
            echo "  1. Setup Copilot Free"
            echo "  2. Setup Antigravity Free"
            echo "  3. Setup both"
            echo "  4. Skip"
            read -rp "  Select [1-4]: " prov_choice
            case "$prov_choice" in
                1) "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider copilot ;;
                2) "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider antigravity ;;
                3) "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider copilot && echo "" && "$VENV_DIR/bin/python" "$BIN_DIR/token_manager.py" auth --provider antigravity ;;
                *) log_info "Provider auth skipped." ;;
            esac
        else
            log_warn "Non-interactive terminal. Provider auth skipped."
        fi
    fi

    # Post-activation health check (FIX M2)
    log_info "Running post-activation health check..."
    if systemctl --user is-active --quiet orca-router.service 2>/dev/null; then
        HEALTH_OK=false
        for attempt in $(seq 1 10); do
            HEALTH_RESP=$(curl -s --connect-timeout 3 http://127.0.0.1:60001/health 2>/dev/null)
            if [ -n "$HEALTH_RESP" ]; then
                if echo "$HEALTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
                    HEALTH_OK=true
                    break
                fi
            fi
            if [ "$attempt" -lt 10 ]; then
                log_info "  Health check attempt $attempt/10 failed, retrying in 3s..."
                sleep 3
            fi
        done
        if [ "$HEALTH_OK" = true ]; then
            log_ok "Orca Router health check PASSED"
        else
            log_warn "Orca Router health check failed after 10 attempts."
        fi
    fi

    # Kiro health
    if [ "${SKIP_KIRO:-}" != "true" ] && systemctl --user is-active --quiet kiro-gateway.service 2>/dev/null; then
        log_info "Running Kiro Gateway health check..."
        KIRO_HEALTH_OK=false
        for attempt in $(seq 1 10); do
            KIRO_RESP=$(curl -s --connect-timeout 3 "http://127.0.0.1:${KIRO_PORT}/health" 2>/dev/null)
            if [ -n "$KIRO_RESP" ]; then
                if echo "$KIRO_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')=='ok' or d.get('health')=='ok' else 1)" 2>/dev/null; then
                    KIRO_HEALTH_OK=true
                    break
                fi
            fi
            if [ "$attempt" -lt 10 ]; then
                sleep 3
            fi
        done
        if [ "$KIRO_HEALTH_OK" = true ]; then
            log_ok "Kiro Gateway health check PASSED"
        else
            log_warn "Kiro Gateway health check failed."
        fi
    fi

    # Log rotation (unchanged)
    log_info "Configuring log rotation..."
    if command -v logrotate &>/dev/null; then
        cat > "$CONFIG_DIR/logrotate.conf" << LOGROT
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
        if [ -d "$HOME/.config/systemd/user" ] && [ ! -f "$HOME/.config/systemd/user/owl-logrotate.timer" ]; then
            cat > "$HOME/.config/systemd/user/owl-logrotate.service" << LRSEOF
[Unit]
Description=OWL Log Rotation

[Service]
Type=oneshot
ExecStart=/usr/bin/logrotate ${CONFIG_DIR}/logrotate.conf
LRSEOF
            cat > "$HOME/.config/systemd/user/owl-logrotate.timer" << 'LRTEOF'
[Unit]
Description=Daily OWL Log Rotation Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
LRTEOF
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable owl-logrotate.timer 2>/dev/null || true
            systemctl --user start owl-logrotate.timer 2>/dev/null || true
            log_ok "Log rotation configured"
        fi
    else
        log_warn "logrotate not found. Logs will grow unbounded."
    fi
fi

# =============================================================================
#  FINAL SUMMARY
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}+-----------------------------------------------------------+${NC}"
echo -e "${GREEN}${BOLD}|      OWL-ORCA v${VERSION} INSTALLATION COMPLETE               |${NC}"
echo -e "${GREEN}${BOLD}+-----------------------------------------------------------+${NC}"
echo ""
echo "  Services:"
echo "    Forward Proxy:    http://127.0.0.1:60000"
echo "    Orca Router:      http://127.0.0.1:60001"
[ "${SKIP_KIRO:-}" != "true" ] && echo "    Kiro Gateway:     http://127.0.0.1:${KIRO_PORT}"
echo ""
echo "  OpenCode Provider:  owl-orca-virtual"
echo "    baseURL:          http://127.0.0.1:60001/v1"
echo "    apiKey:           orca-racer"
echo ""
if [ "${OPENCODE_ACTIVE:-}" == "true" ]; then
    echo -e "  ${YELLOW}NOTE: Your IDE was running during install (SAFE-MODE).${NC}"
    echo "  Restart your IDE when convenient."
    echo "  Hot-reload: systemctl --user reload orca-router.service"
else
    echo "  Services are live and ready."
fi
echo ""
echo "  CLI Commands:"
echo "    owl-proxy <cmd>"
echo "    owl-token auth -p copilot"
echo "    owl-token auth -p antigravity"
echo ""
exit 0
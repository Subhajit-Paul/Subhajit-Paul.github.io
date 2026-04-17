#!/usr/bin/env bash
# cleanup.sh - Cross-distro system cache and junk cleaner
# Usage: curl -fsSL https://subhajit-paul.github.io/cleanup.sh | bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${BLUE}[·]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}━━━  $*  ━━━${NC}"; }
skip()    { echo -e "${DIM}[–]${NC} $* — skipping"; }

FREED_BYTES=0

# ── Helpers ────────────────────────────────────────────────────────────────────

confirm() {
  local msg="$1"
  if [ ! -e /dev/tty ]; then return 1; fi
  printf "${YELLOW}[?]${NC} %s [y/N] " "$msg"
  local ans
  read -r ans < /dev/tty
  [[ "${ans,,}" == "y" ]]
}

du_bytes() {
  du -sb "$@" 2>/dev/null | awk '{s+=$1} END {print s+0}'
}

human() {
  local b=$1
  if   [ "$b" -ge $((1024*1024*1024)) ]; then printf "%.1f GiB" "$(echo "$b 1073741824" | awk '{printf "%.1f", $1/$2}')";
  elif [ "$b" -ge $((1024*1024))      ]; then printf "%.1f MiB" "$(echo "$b 1048576"    | awk '{printf "%.1f", $1/$2}')";
  elif [ "$b" -ge 1024                ]; then printf "%.1f KiB" "$(echo "$b 1024"        | awk '{printf "%.1f", $1/$2}')";
  else printf "%d B" "$b"; fi
}

clean_dir() {
  local label="$1"; shift
  local total=0
  for p in "$@"; do
    [ -e "$p" ] && total=$((total + $(du_bytes "$p")))
  done
  if [ "$total" -eq 0 ]; then skip "$label (nothing to clean)"; return; fi
  info "$label — $(human $total) to free"
  for p in "$@"; do
    [ -e "$p" ] && rm -rf "$p"
  done
  FREED_BYTES=$((FREED_BYTES + total))
  success "$label cleaned (freed $(human $total))"
}

run_cmd() {
  local label="$1"; shift
  info "$label..."
  "$@" >/dev/null 2>&1 && success "$label done" || warn "$label failed (non-fatal)"
}

# ── System snapshot ────────────────────────────────────────────────────────────

header "Disk Usage Before"
df -h --output=target,size,used,avail,pcent 2>/dev/null \
  | grep -v "^tmpfs\|^udev\|^/dev/loop" \
  | head -10 \
  || df -h | head -10

# ── Package manager caches ─────────────────────────────────────────────────────

header "Package Manager Caches"

if command -v apt-get >/dev/null 2>&1; then
  APT_CACHE_SIZE=$(du_bytes /var/cache/apt/archives/ 2>/dev/null || echo 0)
  if [ "$APT_CACHE_SIZE" -gt 0 ]; then
    info "apt cache — $(human $APT_CACHE_SIZE)"
    sudo apt-get clean -qq
    sudo apt-get autoremove -y -qq >/dev/null 2>&1 || true
    FREED_BYTES=$((FREED_BYTES + APT_CACHE_SIZE))
    success "apt cache cleared (freed $(human $APT_CACHE_SIZE))"
  else
    skip "apt cache (already empty)"
  fi
fi

if command -v pacman >/dev/null 2>&1; then
  PKG_CACHE=$(du_bytes /var/cache/pacman/pkg/ 2>/dev/null || echo 0)
  if [ "$PKG_CACHE" -gt 0 ]; then
    info "pacman cache — $(human $PKG_CACHE)"
    sudo pacman -Sc --noconfirm >/dev/null 2>&1
    FREED_BYTES=$((FREED_BYTES + PKG_CACHE))
    success "pacman cache cleared"
  else
    skip "pacman cache (already empty)"
  fi
fi

if command -v dnf >/dev/null 2>&1; then
  info "dnf cache..."
  sudo dnf clean all -q >/dev/null 2>&1 && success "dnf cache cleared" || skip "dnf clean (non-fatal)"
fi

# ── Language / toolchain caches ────────────────────────────────────────────────

header "Language Tool Caches"

# pip
clean_dir "pip cache" "$HOME/.cache/pip"

# uv
clean_dir "uv cache" "$HOME/.cache/uv"

# cargo registry (not the compiled artifacts, just downloaded crate sources)
if [ -d "$HOME/.cargo/registry/cache" ]; then
  clean_dir "cargo registry cache" "$HOME/.cargo/registry/cache"
fi

# npm
if [ -d "$HOME/.npm/_cacache" ]; then
  clean_dir "npm cache" "$HOME/.npm/_cacache"
fi

# yarn v1
if [ -d "$HOME/.cache/yarn" ]; then
  clean_dir "yarn cache" "$HOME/.cache/yarn"
fi

# pnpm
if [ -d "$HOME/.cache/pnpm" ] || [ -d "$HOME/.local/share/pnpm/store" ]; then
  clean_dir "pnpm cache" "$HOME/.cache/pnpm" "$HOME/.local/share/pnpm/store"
fi

# gradle
if [ -d "$HOME/.gradle/caches" ]; then
  clean_dir "gradle cache" "$HOME/.gradle/caches"
fi

# maven
if [ -d "$HOME/.m2/repository" ]; then
  MAVEN_SIZE=$(du_bytes "$HOME/.m2/repository")
  if [ "$MAVEN_SIZE" -gt 0 ] && confirm "Clean Maven repository (~$(human $MAVEN_SIZE))?"; then
    clean_dir "maven repository" "$HOME/.m2/repository"
  else
    skip "maven repository"
  fi
fi

# ── Browser / app caches ───────────────────────────────────────────────────────

header "Application Caches"

CACHE_DIRS=()
for d in \
  "$HOME/.cache/google-chrome/Default/Cache" \
  "$HOME/.cache/chromium/Default/Cache" \
  "$HOME/.cache/BraveSoftware/Brave-Browser/Default/Cache" \
  "$HOME/.cache/mozilla/firefox" \
  "$HOME/.cache/thumbnails" \
  "$HOME/.cache/fontconfig" \
  "$HOME/.cache/mesa_shader_cache" \
  "$HOME/.cache/spotify" \
  "$HOME/.cache/slack"
do
  [ -d "$d" ] && CACHE_DIRS+=("$d")
done

if [ "${#CACHE_DIRS[@]}" -gt 0 ]; then
  CACHE_TOTAL=$(du_bytes "${CACHE_DIRS[@]}")
  if [ "$CACHE_TOTAL" -gt 0 ] && confirm "Clean app caches ($(human $CACHE_TOTAL))?"; then
    for d in "${CACHE_DIRS[@]}"; do
      clean_dir "$(basename "$(dirname "$d")")/$(basename "$d")" "$d"
    done
  else
    skip "app caches"
  fi
fi

# ── /tmp old files ─────────────────────────────────────────────────────────────

header "Temporary Files"

TMP_SIZE=$(find /tmp -maxdepth 1 -atime +3 -not -name '.' 2>/dev/null | wc -l)
if [ "$TMP_SIZE" -gt 0 ]; then
  info "Found ${TMP_SIZE} items in /tmp older than 3 days"
  if confirm "Remove them?"; then
    BEFORE=$(du_bytes /tmp 2>/dev/null || echo 0)
    find /tmp -maxdepth 1 -atime +3 -not -name '.' -exec rm -rf {} + 2>/dev/null || true
    AFTER=$(du_bytes /tmp 2>/dev/null || echo 0)
    DIFF=$((BEFORE - AFTER))
    [ "$DIFF" -gt 0 ] && FREED_BYTES=$((FREED_BYTES + DIFF))
    success "/tmp old files removed"
  else
    skip "/tmp cleanup"
  fi
else
  skip "/tmp (nothing older than 3 days)"
fi

# ── Journal logs ───────────────────────────────────────────────────────────────

if command -v journalctl >/dev/null 2>&1; then
  header "System Journal"
  JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+(\.\d+)? [KMGT]?iB' | head -1 || echo "unknown")
  info "Journal disk usage: ${JOURNAL_SIZE}"
  if confirm "Vacuum journal to keep only last 7 days?"; then
    sudo journalctl --vacuum-time=7d -q >/dev/null 2>&1 && success "Journal vacuumed" || warn "journalctl vacuum failed"
  else
    skip "journal vacuum"
  fi
fi

# ── Docker ─────────────────────────────────────────────────────────────────────

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  header "Docker"
  DOCKER_SIZE=$(docker system df 2>/dev/null | tail -n +2 | awk '{gsub(/[BKMGT]B/,"",$4); sum+=$4} END {print sum+0}')
  info "Reclaimable space reported by Docker"
  docker system df 2>/dev/null | grep -v "^$" || true
  if confirm "Run 'docker system prune' (removes stopped containers, dangling images, unused networks)?"; then
    docker system prune -f >/dev/null 2>&1 && success "Docker pruned" || warn "Docker prune failed"
  else
    skip "Docker prune"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────────

header "Done"
echo ""
echo -e "${BOLD}${GREEN}  Total freed: $(human $FREED_BYTES)${NC}"
echo ""
echo -e "  ${CYAN}Disk Usage After${NC}"
df -h --output=target,size,used,avail,pcent 2>/dev/null \
  | grep -v "^tmpfs\|^udev\|^/dev/loop" \
  | head -10 \
  || df -h | head -10
echo ""

#!/usr/bin/env bash
# Front door for PTMS. Downloads the arch-matched binary from ptms-dist,
# installs it under /usr/local/bin, drops a systemd unit and a starter config.
#
#   curl -fsSL https://raw.githubusercontent.com/Aitorrio/ptms-dist/main/contrib/install/install-ptms.sh | sudo bash
#
#   PTMS_BRANCH=beta   install latest-beta (default: stable / latest-stable)
set -euo pipefail

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
  die "hay que ser root. Ejemplo: curl -fsSL https://raw.githubusercontent.com/Aitorrio/ptms-dist/main/contrib/install/install-ptms.sh | sudo bash"
fi

BRANCH="${PTMS_BRANCH:-main}"
case "$BRANCH" in
  main) TAG="latest-stable"; CANAL="estable"; OTA="stable" ;;
  beta) TAG="latest-beta"; CANAL="beta"; OTA="beta" ;;
  *) die "PTMS_BRANCH debe ser main o beta" ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64) ASSET="ptms-aarch64" ;;
  x86_64|amd64)  ASSET="ptms-x86_64" ;;
  i686|i386|x86) ASSET="ptms-i686" ;;
  *) die "arquitectura no soportada: $ARCH (soportadas: aarch64, x86_64, i686)" ;;
esac

cat << 'EOF'

  ____ _____ __  __ ____
 |  _ \_   _|  \/  / ___|
 | |_) || | | |\/| \___ \
 |  __/ | | | |  | |___) |
 |_|    |_| |_|  |_|____/

  Personal Tetra Management System

EOF

export DEBIAN_FRONTEND=noninteractive
log "Preparando el sistema (${ARCH} → ${ASSET}, canal ${CANAL})…"
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl >/tmp/ptms-apt.err 2>&1 \
    || { cat /tmp/ptms-apt.err >&2; die "no se pudo instalar curl"; }
elif ! command -v curl >/dev/null 2>&1; then
  die "hace falta curl"
fi

BASE="https://github.com/Aitorrio/ptms-dist/releases/download/${TAG}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

CURL=(curl -fL --retry 3 --retry-delay 2)
log "Descargando ${ASSET}…"
if [[ -t 1 ]]; then
  "${CURL[@]}" -# -o "$WORKDIR/${ASSET}" "${BASE}/${ASSET}" \
    || die "no se pudo bajar el binario"
else
  "${CURL[@]}" -sS -o "$WORKDIR/${ASSET}" "${BASE}/${ASSET}" \
    || die "no se pudo bajar el binario"
fi
"${CURL[@]}" -fsSL -o "$WORKDIR/ptms.sha256" "${BASE}/ptms.sha256" \
  || die "no se pudo bajar la suma"

log "Comprobando la suma…"
(
  cd "$WORKDIR"
  grep " ${ASSET}\$" ptms.sha256 | sha256sum -c -
) || die "la suma no coincide — no se ha instalado nada"

log "Instalando…"
install -d /usr/local/bin /etc/ptms /etc/systemd/system
install -m 755 "$WORKDIR/${ASSET}" /usr/local/bin/ptms

UNIT_SRC=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/ptms.service" ]]; then
  UNIT_SRC="$SCRIPT_DIR/ptms.service"
fi
if [[ -z "$UNIT_SRC" ]]; then
  "${CURL[@]}" -fsSL -o "$WORKDIR/ptms.service" \
    "https://raw.githubusercontent.com/Aitorrio/ptms-dist/${BRANCH}/contrib/install/ptms.service" \
    || die "no se pudo bajar ptms.service"
  UNIT_SRC="$WORKDIR/ptms.service"
fi
install -m 644 "$UNIT_SRC" /etc/systemd/system/ptms.service

CFG="/etc/ptms/nucleus.toml"
if [[ ! -f "$CFG" ]]; then
  log "Creando configuración inicial…"
  if "${CURL[@]}" -fsSL -o "$CFG" \
    "https://raw.githubusercontent.com/Aitorrio/ptms-dist/${BRANCH}/example_config/nucleus.toml"; then
    # Panel abierto en el VPS: escucha en todas las interfaces.
    sed -i 's/^listen = "127.0.0.1:7480"/listen = "0.0.0.0:7480"/' "$CFG" || true
  else
    cat > "$CFG" << EOF
# Escrito por install-ptms.sh.

[nucleus]
mcc = 901
mnc = 9999
listen = "0.0.0.0:7400"

[dashboard]
listen = "0.0.0.0:7480"
user = "admin"
password = "1234"
ota_channel = "${OTA}"

[security]
issi_whitelist = []
EOF
  fi
fi

# Alinea el canal OTA del fichero con el canal de instalación.
if grep -q '^ota_channel' "$CFG" 2>/dev/null; then
  sed -i "s/^ota_channel *=.*/ota_channel = \"${OTA}\"/" "$CFG"
elif grep -q '^\[dashboard\]' "$CFG"; then
  sed -i "/^\[dashboard\]/a ota_channel = \"${OTA}\"" "$CFG"
else
  printf '\n[dashboard]\nota_channel = "%s"\n' "$OTA" >> "$CFG"
fi

log "Arrancando…"
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable ptms.service >/dev/null 2>&1 || true
if ! systemctl restart ptms.service; then
  journalctl -u ptms.service -n 30 --no-pager >&2 || true
  die "el servicio no ha arrancado; el panel no está a la escucha"
fi
sleep 2
if ! systemctl is-active --quiet ptms.service; then
  journalctl -u ptms.service -n 30 --no-pager >&2 || true
  die "el servicio no se ha quedado en marcha"
fi

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
IP="${IP:-<ip-del-servidor>}"

export LC_ALL=C.UTF-8
pad() {
  local text="$1" width="$2" n pad
  n=${#text}
  pad=$((width - n))
  if (( pad < 0 )); then
    printf '%s' "$text"
  else
    printf '%s%*s' "$text" "$pad" ''
  fi
}
rule() {
  local left right
  left=$(printf '%*s' 16 '' | tr ' ' '-')
  right=$(printf '%*s' 44 '' | tr ' ' '-')
  printf '  %s%s%s%s%s\n' "$1" "$left" "$2" "$right" "$3"
}
row() {
  printf '  | %s | %s |\n' "$(pad "$1" 14)" "$(pad "$2" 42)"
}

printf '\n'
rule '+' '+' '+'
row "Panel" "http://${IP}:7480/"
row "Usuario" "admin"
row "Contraseña" "1234"
row "Config" "/etc/ptms/nucleus.toml"
row "Servicio" "ptms.service"
row "Binario" "/usr/local/bin/ptms (${ASSET})"
row "Canal" "${CANAL}"
rule '+' '+' '+'
printf '\n  Cambia la contraseña del panel antes de dejarlo abierto a Internet.\n'
printf '  Las actualizaciones se hacen desde el panel (Actualizar) o reejecutando este script.\n\n'

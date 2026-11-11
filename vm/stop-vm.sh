#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_DIR="$ROOT_DIR/.vm"

stop_from_pidfile() {
    local pidfile="$1"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid="$(cat "$pidfile")"
        kill "$pid" 2>/dev/null || true
        rm -f "$pidfile"
    fi
}

stop_from_pidfile "$VM_DIR/novnc.pid"
stop_from_pidfile "$VM_DIR/qemu.pid"

if [[ "${1:-}" == "--purge" ]]; then
    rm -rf "$VM_DIR"
    echo "VM, disco e seed removidos."
else
    echo "VM parada. O disco foi preservado em $VM_DIR."
fi
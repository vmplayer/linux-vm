#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_DIR="$ROOT_DIR/.vm"
IMAGE="$VM_DIR/ubuntu-cloud.img"
SEED="$VM_DIR/seed.iso"
PIDFILE="$VM_DIR/qemu.pid"
LOGFILE="$VM_DIR/qemu.log"
BASE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"

RAM="${VM_RAM:-6G}"
CPUS="${VM_CPUS:-$(nproc)}"
SSH_PORT="${VM_SSH_PORT:-10022}"
NOVNC_PROXY="$(command -v novnc_proxy || true)"
NOVNC_PROXY="${NOVNC_PROXY:-/usr/share/novnc/utils/novnc_proxy}"

for command_name in qemu-system-x86_64 qemu-img cloud-localds curl; do
    command -v "$command_name" >/dev/null || {
        echo "Comando ausente: $command_name" >&2
        echo "Instale as dependências com: sudo apt-get install qemu-system-x86 qemu-utils cloud-image-utils novnc curl" >&2
        exit 1
    }
done
[[ -x "$NOVNC_PROXY" ]] || {
    echo "Executável noVNC ausente: $NOVNC_PROXY" >&2
    exit 1
}

if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    echo "Sem acesso a /dev/kvm. Adicione o usuário ao grupo kvm e abra uma nova sessão." >&2
    exit 1
fi

mkdir -p "$VM_DIR"
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "VM já está em execução (PID $(cat "$PIDFILE")). Acesse http://localhost:6080/vm.html?cache=2"
    exit 0
fi

if [[ ! -f "$VM_DIR/base.img" ]]; then
    echo "Baixando imagem Ubuntu cloud..."
    curl -fL --retry 3 -o "$VM_DIR/base.img" "$BASE_URL"
fi

if [[ ! -f "$IMAGE" ]]; then
    qemu-img create -f qcow2 -F qcow2 -b "$VM_DIR/base.img" "$IMAGE" 40G
fi

if [[ ! -f "$SEED" ]]; then
    work_dir="$VM_DIR/seed"
    mkdir -p "$work_dir"
    cat > "$work_dir/user-data" <<'EOF'
#cloud-config
hostname: linux-vm
manage_etc_hosts: true
ssh_pwauth: true
users:
  - name: vmuser
    gecos: VM User
    groups: [adm, sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: vmuser
    ssh_authorized_keys: []
chpasswd:
    expire: false
    list:
        - vmuser:vmuser
package_update: true
packages:
    - xserver-xorg
    - dbus-x11
    - xfce4
    - xfce4-goodies
    - lightdm
    - firefox
    - openssh-server
write_files:
    - path: /etc/lightdm/lightdm.conf.d/10-autologin.conf
        permissions: '0644'
        content: |
            [Seat:*]
            autologin-user=vmuser
            autologin-user-timeout=0
            user-session=xfce
runcmd:
  - systemctl enable lightdm
  - systemctl set-default graphical.target
  - systemctl restart lightdm
EOF
    cp "$ROOT_DIR/vm/user-data.yaml" "$work_dir/user-data"
    cat > "$work_dir/meta-data" <<EOF
instance-id: linux-vm
local-hostname: linux-vm
EOF
    cloud-localds "$SEED" "$work_dir/user-data" "$work_dir/meta-data"
fi

WEB_DIR="$VM_DIR/web"
mkdir -p "$WEB_DIR"
cp -a /usr/share/novnc/. "$WEB_DIR/"
sed 's#app/ui.js"#app/ui.js?v=linux-vm-2"#' /usr/share/novnc/vnc.html > "$WEB_DIR/vm.html"
cat > "$WEB_DIR/index.html" <<'EOF'
<!doctype html>
<meta http-equiv="refresh" content="0; url=/vm.html?cache=3&autoconnect=1&resize=scale">
<a href="/vm.html?cache=3&autoconnect=1&resize=scale">Abrir noVNC</a>
EOF

qemu-system-x86_64 \
    -enable-kvm \
    -machine type=q35,accel=kvm \
    -cpu host \
    -smp "$CPUS",sockets=1,cores="$CPUS",threads=1 \
    -m "$RAM" \
    -object iothread,id=vm_iothread \
    -drive "if=none,id=vm_disk,format=qcow2,file=$IMAGE,cache=writeback,aio=threads,discard=unmap" \
    -device virtio-blk-pci,drive=vm_disk,iothread=vm_iothread \
    -drive "if=virtio,format=raw,readonly=on,file=$SEED" \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
    -device virtio-net-pci,netdev=net0 \
    -display vnc=127.0.0.1:1 \
    -daemonize \
    -pidfile "$PIDFILE" \
    -D "$LOGFILE"

"$NOVNC_PROXY" --vnc localhost:5901 --listen 6080 --heartbeat 30 --web "$WEB_DIR" > "$VM_DIR/novnc.log" 2>&1 &
echo $! > "$VM_DIR/novnc.pid"

echo "VM iniciada com $CPUS vCPU(s) e $RAM de RAM."
echo "Acesse: http://localhost:6080/vm.html?cache=3&autoconnect=1&resize=scale"
# shellcheck shell=bash
# VMM helpers run on the NAS as root. Source after lib.sh.

VIRSH="sudo /usr/local/bin/virsh -c qemu:///system"

# Print the VMM guest_id for VM_HOSTNAME.
vm_guest_id() {
  nas_ssh "sudo /usr/syno/bin/synowebapi --exec api=SYNO.Virtualization.API.Guest method=list version=1" 2>/dev/null \
    | sed -n '/^{/,/^}/p' \
    | jq -r --arg n "$VM_HOSTNAME" '.data.guests[] | select(.guest_name == $n) | .guest_id'
}

# Print the host block device backing the guest's first virtual disk.
vm_disk_device() {
  nas_ssh "$VIRSH domblklist $1 --details" | awk '$2 == "disk" {print $4; exit}'
}

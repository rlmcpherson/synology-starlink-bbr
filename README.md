# synology-starlink-bbr

Stop Plex buffering for remote viewers on Starlink when Plex runs on a Synology NAS. Remote connections are served from a small VM on the NAS that uses BBR congestion control.

## The problem

Starlink loses packets often enough that a sender using CUBIC, the Linux default, keeps cutting its sending rate. A single long TCP stream, like a Plex stream, collapses below the video bitrate, while multi-stream speed tests, YouTube and Netflix look fine. Switching the sender to BBR fixes it ([r/PleX thread](https://www.reddit.com/r/PleX/comments/1vzbyng/plex_buffering_over_starlink_despite_plenty_of/)).

Congestion control is chosen by the sender, so it has to change on the server side. Most Synology models run DSM on Linux 4.4, which predates BBR (added in 4.9), and Docker containers share that kernel. This project runs a small Debian VM in Virtual Machine Manager, which has its own kernel with BBR. Remote clients connect to the VM, and HAProxy passes the traffic through to the NAS.

```
Starlink client ──(BBR over the lossy link)──> router ──> VM (HAProxy) ──(LAN)──> NAS :32400
```

HAProxy runs in TCP mode, so TLS passes through untouched and Plex's `plex.direct` certificates keep working.

## Does this apply to you?

1. Remote clients on Starlink, or another lossy, high-latency link, buffer even though speed tests look fine.
2. Check your NAS kernel first:
   ```sh
   cat /proc/sys/net/ipv4/tcp_available_congestion_control
   ```
   If `bbr` is listed, you don't need a VM. Run `sudo sysctl -w net.ipv4.tcp_congestion_control=bbr` on the NAS, and make it persistent with a DSM Task Scheduler boot task.
3. Your NAS supports Virtual Machine Manager, which generally means an x86 "Plus" model, with about 1.3 GB of RAM and 6 GB of storage free. See [Overhead](#overhead).

## Results

Tested on a DS220+ (DSM 7.4.1, kernel 4.4.302+, VMM 2.8) with a client on Starlink. Single TCP stream, 30s per run.

| Sender | Avg | Worst 1s |
|---|---|---|
| NAS, CUBIC, 1 stream | 6 to 26 Mbps | |
| NAS, CUBIC, 8 parallel streams | 108 Mbps total | |
| VM, CUBIC (3 runs) | 32.5 Mbps | 5.2 Mbps |
| VM, BBR (3 runs) | 157.4 Mbps | 52.2 Mbps |

After cutover, two simultaneous 4K streams played to two Starlink devices without buffering. Raw iperf3 output, with hosts and addresses scrubbed, is in `bench/results/`.

## Overhead

Measured with `bench/vm-overhead.sh` on the DS220+ (Celeron J4025, 2 cores) while the VM forwarded two 4K streams at 34 to 39 Mbps:

| Resource | Cost |
|---|---|
| NAS CPU (QEMU process) | 9 to 10% of one core, about 5% of the NAS. Roughly 2.5% of a core per 10 Mbps forwarded. |
| CPU inside the VM (HAProxy) | about 3% of its vCPU |
| NAS memory | 1.3 GB resident for a 1 GB VM. The guest uses about 280 MB, so 512 MB would likely work but is untested. |
| NAS storage | 2.8 GB in VMM storage (thin VM disk about 1.8 GB, imported image about 1.0 GB). You can delete the 3 GB source image in `NAS_IMAGE_DIR` after import. |
| LAN traffic | None added. The NAS-to-VM hop stays inside the NAS's virtual switch. |

Idle cost was not measured separately. A VM forwarding no traffic uses little CPU, but its memory stays reserved.

## Layout

| Path | Purpose |
|---|---|
| `config.env.example` | All settings. Copy to `config.env`. |
| `lib.sh` | `nas_ssh` and `vm_ssh` helpers |
| `vm/` | Image download, cloud-init seed, VM status and recovery |
| `proxy/` | HAProxy config rendering, BBR sysctl, deploy, Plex LAN Networks |
| `bench/` | Throughput tests, live connection stats, VM overhead, saved results |
| `test/` | bats unit tests |

## Requirements

On the machine you run the scripts from:

- bash 5 or later (macOS: `brew install bash`)
- `ssh`, `jq`, `bc`
- `hdiutil` (macOS) or `xorriso`/`genisoimage` (Linux)
- `iperf3`, for the A/B test

On the NAS:

- SSH enabled, and an administrator account.
- Passwordless sudo for `vm/console.sh`, `vm/reboot.sh` and `vm/write-disk.sh`. Everything else works without it.
- If you run the scripts away from home (`VM_VIA_NAS=1`), install SynoCommunity's `synocli-net` package for `nc`.

## Setup

### 1. Configure

```sh
cp config.env.example config.env
```

Set the NAS address and user, `VM_IP`, `LAN_CIDR`, and the folder for the VM images.

`VM_IP` must be a free address: either outside your router's DHCP pool, or one you will reserve for the VM.

`VM_USER` must not be a Debian system account. For example, `proxy` fails: cloud-init reuses the existing account, which has a `nologin` shell.

### 2. Install Virtual Machine Manager

Install it from Package Center and put its storage on a volume. Installing it moves the NAS network port onto Open vSwitch, which causes a short network drop.

VMM shows a `provision_warning` once the volume is over about 90% full. The VM is small, so that's safe to ignore if you have a few GB free.

### 3. Prepare the images

```sh
vm/fetch-image.sh     # Debian generic cloud image onto the NAS, SHA512 verified, saved as .img
vm/upload-seed.sh     # cloud-init seed ISO with your SSH key (~/.ssh/id_ed25519.pub by default)
```

Both files go to `NAS_IMAGE_DIR`. The VM gets your public key, HAProxy, iperf3, the QEMU guest agent and automatic security updates.

### 4. Create the VM

1. **Image > Disk Image > Create > From NAS**: pick the `.img`. The **ISO File** tab only lists `.iso` files.
2. **Image > ISO File > Create > From NAS**: pick `<VM_HOSTNAME>-seed.iso`.
3. **Virtual Machine > Import > Import from disk image**. Don't use **Create**: it attaches a new blank disk, and the VM shows "No bootable device".
   - Name: `VM_HOSTNAME`
   - 1 vCPU, 1 GB RAM, the default VM network
   - Autostart: Yes
4. Before powering on, open **Action > Edit > Others** and set **ISO file for bootup** to the seed ISO. The import wizard has no option for it. cloud-init only reads the seed on first boot.
5. Power on.

### 5. Give the VM a fixed IP

Reserve `VM_IP` for the VM's MAC address on your router. Most routers only list a device once it has a DHCP lease, so do this after first boot, then run `vm/reboot.sh`.

On UniFi: **Client Devices > the VM > Settings > Fixed IP Address**.

### 6. Verify and deploy

```sh
vm/status.sh          # waits for SSH and cloud-init, prints kernel, congestion control, packages
proxy/deploy.sh       # renders haproxy.cfg from SERVICES, installs BBR sysctl, reloads HAProxy
```

### 7. A/B test (recommended)

This confirms BBR helps on your link before you switch. Temporarily forward TCP 5201 on your router to `VM_IP`. Then, from a machine on the Starlink side:

```sh
bench/ab-test.sh 3 30   # 3 rounds of 30s, alternating CUBIC and BBR on the VM
```

The script restores BBR and stops iperf3 when it exits. Remove the 5201 forward afterwards. To share results, run `bench/scrub-results.sh` on the JSON files first.

### 8. Cutover

1. **Router:** point the TCP 32400 port forward at `VM_IP` instead of the NAS.
2. **Plex:** run `proxy/plex-lan-networks.sh` and paste its output into **Settings > Network > Show Advanced > LAN Networks**. Add any other local subnets you have.

   Don't skip this. Proxied clients reach Plex from `VM_IP`, which is on your LAN. Without the setting, Plex treats every remote viewer as local and doesn't apply its remote-streaming rules. The list covers your LAN except `VM_IP`.
3. **Verify:** start a stream from the Starlink side.
   - The Plex Dashboard shows it as Remote, not Relay.
   - `bench/streams.sh` lists the connection with `bbr`.
   - `bench/stream-rate.sh` measures its throughput.

**Rollback:** point the 32400 forward back at the NAS and clear LAN Networks.

## Other services

`SERVICES` takes a list such as `plex:32400 other:8443`. Each entry becomes a HAProxy `listen` block, and you point that port's router forward at the VM. Each port needs a matching forward.

This mainly helps services that send large files or video. Before proxying DSM services such as Synology Photos, note:

- DSM sees every proxied client as `VM_IP`. With **Auto Block** on, a few failed logins through the proxy block `VM_IP`, which cuts off every proxied client.
- DSM's **Trusted Proxies** setting accepts the real client IP from a proxy, but only in HTTP headers. That needs TLS termination on the VM, which this project doesn't do.
- Traffic over QuickConnect relay doesn't use your port forwards, so the proxy has no effect on it.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| VM console: "Boot failed: not a bootable disk" | Created with **Create** instead of **Import**. Run `vm/write-disk.sh`, which writes the image onto the blank disk (refusing if it isn't blank), verifies it and resets the VM. |
| Disk image missing from the VMM picker | Use the **Disk Image** tab. The file must be `.img`, `.vmdk`, `.vdi`, `.vhd`, `.vhdx` or `.qcow2`. |
| SSH: "This account is currently not available" | `VM_USER` is a Debian system account. Pick another name, then run `vm/upload-seed.sh` and `vm/reboot.sh`. Each seed has a new instance ID, so cloud-init runs again. |
| `vm/status.sh` times out | The VM may still be on its DHCP address. Try `VM_IP=<address> vm/status.sh`, or run `vm/console.sh` for a screenshot of the VM console. |
| Downloaded image is a few hundred bytes | It's the mirror redirect page. `vm/fetch-image.sh` follows redirects and checks the SHA512. |
| No HAProxy logs | `journalctl -u haproxy` on the VM. Logs go to stdout because `/dev/log` is unreachable from HAProxy's chroot. |
| Stream slower than the A/B test | Run `bench/stream-rate.sh`. Starlink capacity varies over the day, and players stop reading once their buffer is full. |

## Development

```sh
shellcheck -x lib.sh vm/*.sh proxy/*.sh bench/*.sh
bats test
```

## License

MIT. See [LICENSE](LICENSE).

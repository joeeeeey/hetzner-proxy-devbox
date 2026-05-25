# Hetzner Proxy Devbox

Ansible workspace for creating a single-user Hetzner Cloud VM and routing normal
outbound traffic through a user-provided SOCKS5 or HTTP proxy.

The default target is a small personal development box:

- Hetzner Cloud Debian 12 VM
- default server type: `cx22` (2 vCPU, 4 GB RAM)
- root SSH login with the user's public key
- one sudo-capable Linux user with the same public key
- SSH-only public ingress with UFW and fail2ban
- optional developer tooling preinstall
- transparent outbound proxy with sing-box TUN

## Network Model

There are two different public IPs:

```text
[laptop] -> ssh -> [Hetzner VM IPv4]
                    |
                    +-> outbound traffic -> [proxy provider] -> [proxy egress IP]
```

- `Hetzner VM IPv4`: created automatically by Hetzner and used for SSH/bootstrap.
- `proxy_expected_egress_ip`: fixed outbound IP from the proxy provider.

This project does not buy proxy IPs. First version expects you to provide a
working SOCKS5 or HTTP proxy endpoint.

## Quick Start

Install dependencies:

```bash
cd /path/to/hetzner-proxy-devbox
make install
```

Create host vars:

```bash
cp inventory/host_vars/example-devbox.yml.example inventory/host_vars/example-devbox.yml
```

Edit `inventory/host_vars/example-devbox.yml`:

```yaml
hcloud_server_name: my-proxy-devbox
hcloud_location: ash
hcloud_server_type: cx22

devbox_username: alice
devbox_ssh_public_key: "ssh-ed25519 AAAA... alice@example"

proxy_expected_egress_ip: "203.0.113.10"
proxy_url: "socks5://USER:PASS@proxy.example.com:1080"
```

For a proxy URL like:

```text
socks5://USER:PASS@PROXY_HOST:1080
```

you can use it directly:

```yaml
proxy_url: "socks5://USER:PASS@PROXY_HOST:1080"
proxy_expected_egress_ip: "<provider fixed egress IP>"
```

Advanced split-field equivalent:

```yaml
proxy_mode: socks5
proxy_host: PROXY_HOST
proxy_port: 1080
proxy_username: USER
proxy_password: PASS
proxy_expected_egress_ip: "<provider fixed egress IP>"
```

Run:

```bash
export HETZNER_TOKEN="<your Hetzner API token>"
make syntax
make apply HOST=example-devbox
```

## Proxy Safety Gate

Before transparent routing is enabled, Ansible runs:

```bash
test-transparent-proxy-endpoint /etc/sing-box/transparent-proxy.env --expected-ip <proxy_expected_egress_ip>
```

That command uses the proxy endpoint directly and checks:

```text
observed egress IP == proxy_expected_egress_ip
```

If the proxy endpoint is wrong, credentials fail, or the egress IP does not
match, sing-box transparent routing is not enabled.

## Installed Commands

On a configured VM:

```bash
verify-global-proxy
verify-transparent-proxy
check-dns-proxy
sudo update-transparent-proxy-endpoint \
  --mode socks5 \
  --host <proxy-host> \
  --port <proxy-port> \
  --expected-ip <proxy-egress-ip> \
  --username <proxy-user> \
  --password <proxy-password>
sudo rollback-transparent-proxy
```

SSH management traffic on TCP/22 bypasses the TUN/proxy path so a broken proxy
does not normally cut off SSH access.

## Post-Bootstrap Verification

Run this after bootstrap:

```bash
verify-global-proxy
```

`verify-global-proxy` is kept as the compatibility command from the original
runbook. It points to the same verifier as:

```bash
verify-transparent-proxy
```

It checks:

- `sing-box.service` is active
- observed IPv4 egress equals `proxy_expected_egress_ip`
- Cloudflare trace IP equals `proxy_expected_egress_ip`
- DNS resolves through the configured sing-box DNS path
- policy route table `2022` sends default traffic to `singtun0`
- sing-box nftables redirect and DNS hijack rules exist
- SSH TCP/22 ingress and reply traffic bypass the TUN/proxy path
- UDP proxying when `proxy_allow_udp=true`

For DNS-specific validation:

```bash
check-dns-proxy
check-dns-proxy /etc/sing-box/transparent-proxy.env example.com
```

For scheduled health checks:

```bash
systemctl status verify-transparent-proxy.timer
journalctl -u verify-transparent-proxy.service --no-pager -n 100
```

## Defaults

Key defaults live in `inventory/group_vars/devboxes.yml`:

- `hcloud_location: ash`
- `hcloud_server_type: cx22`
- `hcloud_image: debian-12`
- `transparent_proxy_enabled: true`
- `proxy_mode: socks5`
- DoT DNS upstream: `1.1.1.1:853` with SNI `cloudflare-dns.com`
- IPv6 egress disabled by default to reduce leak paths

## Notes

- Proxy credentials are stored in the host vars and rendered to
  `/etc/sing-box/transparent-proxy.env` on the VM. Do not commit real
  credentials to a public repo.
- The Hetzner VM's own IPv4 is not intended to be the fixed proxy egress IP.
- The project currently does not manage proxy-provider APIs or buy IPs.

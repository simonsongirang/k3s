# k3s mainframe

Ansible installs a single-server k3s cluster on hardware #3 in [hardware.md](hardware.md): the x86_64 Ubuntu 24 host at `mainframe.local` (`10.88.111.24`). The duplicate hardware #4 entry is not treated as a second node. The playbook runs locally, so SSH to the mainframe and run the deployment script there.

## Prerequisites on the mainframe

Install Ansible, UFW, and the Infisical CLI:

```bash
sudo apt update
sudo apt install -y ansible ufw
ansible-galaxy collection install -r ansible/requirements.yml
curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | sudo -E bash
sudo apt-get update
sudo apt-get install -y infisical
```

Authenticate the CLI before deploying. For an interactive login over SSH, use:

```bash
infisical login -i
```

If using a machine identity instead, configure its authentication through your normal secure process; do not put credentials in this repository or on the command line.

In the Infisical project, create a strong `K3S_TOKEN` secret in the environment and path you intend to use. The playbook requires this secret and does not print it. Keep the token stable: it is used when initializing the server and is also needed by future agents joining this cluster.

Before deploying, configure and enable UFW with the inbound rules needed by the mainframe's existing services and SSH access. The playbook requires UFW to be active and allows TCP port 6443 from the LAN (`10.88.111.0/24`) and Tailscale's IPv4 (`100.64.0.0/10`) and IPv6 (`fd7a:115c:a1e0::/48`) ranges. It denies the API port from other IPv4 and IPv6 sources and does not change UFW's default inbound policy. The VPN Pi's default Tailscale subnet-router SNAT makes routed traffic appear from its LAN address, which is already allowed.

## Deploy

From the repository root on the mainframe:

```bash
bash ./scripts/deploy-k3s.sh
```

Enter the Infisical project ID, environment slug, and secret path when prompted, then enter the sudo password when Ansible asks. The Infisical CLI provides secrets to Ansible for that run; no secret values are written into the repository. The account running the script must have sudo access.

The playbook installs the pinned k3s release in `ansible/site.yml`, enables the `k3s` systemd service, and waits for the Kubernetes API to list the node. Re-running it is safe; it installs or upgrades k3s only when the pinned version differs. Change the version pin deliberately to upgrade.

This is a single-node cluster, not a highly available control plane. The k3s API listens on TCP port 6443 and is reachable from the `10.88.111.0/24` LAN and the Tailscale network under the UFW rules managed by the playbook. Default k3s components, including Traefik and ServiceLB, are left enabled.

# k3s mainframe worker

Ansible joins hardware #3 in [hardware.md](hardware.md), the Ubuntu 24 host at `mainframe.local` (`10.88.111.24`), to the existing k3s cluster as a worker. The existing cluster keeps its control plane; this playbook does not initialize a new cluster. It runs locally, so SSH to the mainframe and run the deployment script there.

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

In Infisical, provide these values in the selected environment and secret path:

- `K3S_URL`: the existing cluster's HTTPS API endpoint, normally `https://<server>:6443`. It must be reachable from the mainframe, and its hostname or IP must be included in the API server's TLS certificate.
- `K3S_TOKEN`: the existing cluster's token for joining agent nodes. If the cluster has a separate `K3S_AGENT_TOKEN`, use that value here.
- `K3S_VERSION`: the exact k3s release installed on the existing servers, such as `v1.x.y+k3s1`.

There are no local `infisical_env` or `infisical_path` files. When you run the deployment script, enter the environment slug and secret path exactly as they appear in Infisical. Make sure all three keys above exist under that same project, environment, and path.

To check that Infisical loads all three values without displaying them, run this from the mainframe with the same project ID, environment slug, and path:

```bash
infisical secrets-manager run \
  --projectId="<project-id>" \
  --env="<environment-slug>" \
  --path="<secret-path>" \
  -- bash -c 'test -n "$K3S_URL" && test -n "$K3S_TOKEN" && test -n "$K3S_VERSION" && echo "All required values are set"'
```

The token is written to `/etc/rancher/k3s/config.yaml`, owned by root with mode `0600`, because the agent needs it after installation. It is not written to the repository or printed by Ansible.

## UFW and cluster networking

The playbook requires UFW to be active with default-deny incoming and allow-outgoing policies. Before enabling UFW, preserve the inbound rules needed by SSH and the mainframe's existing services. Check the current firewall and listeners:

```bash
sudo ufw status numbered
sudo ss -tulpn
sudo ufw app list
```

For a new UFW setup, add the required service rules before enabling it. This example uses standard SSH; add rules for services actually hosted on the mainframe:

```bash
sudo ufw allow OpenSSH
# Add any other required service ports before enabling UFW.
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

Enable IPv6 filtering in `/etc/default/ufw` (`IPV6=yes`) so the Tailscale IPv6 rule is active. If UFW is already active, reload it after changing this setting.

The playbook allows the default k3s pod and service CIDRs (`10.42.0.0/16` and `10.43.0.0/16`), Flannel VXLAN (`UDP 8472`) and metrics-server traffic (`TCP 10250`) from the LAN and Tailscale networks, and ingress on `TCP 80/443` from those networks. The existing cluster must use these default pod and service CIDRs and Flannel VXLAN; update the corresponding variables and firewall port tasks in `ansible/site.yml` if its networking differs. The control-plane endpoint must accept the mainframe's connection on `TCP 6443`.

The API remains on the existing control-plane endpoint; this worker does not expose an API server on port 6443. Configure the control-plane firewall separately to allow TCP 6443 from LAN and Tailscale clients and block other sources; this worker playbook cannot change the control-plane firewall. The 80/443 rules let LAN and Tailscale clients reach ingress traffic when the cluster's ServiceLB schedules it on this node.

## Deploy

From the repository root on the mainframe:

```bash
bash ./scripts/deploy-k3s.sh
```

Enter the Infisical project ID, environment slug, and secret path when prompted, then enter the sudo password when Ansible asks. The mainframe must have hostname `mainframe` and address `10.88.111.24`. The playbook refuses to proceed if it finds a standalone `k3s.service`; it will not delete that cluster's state or convert it automatically.

Ansible installs or upgrades the `k3s-agent` service to the exact version specified by `K3S_VERSION`, starts it, and waits for systemd to report it active. Confirm node registration with `kubectl get nodes -o wide` from an existing cluster admin context.

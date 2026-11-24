# Kali VPS Provisioning — Cross-VPS Recon Deployment

## SSH Key Migration (Lazy Password → Key Auth)

**Context:** Kali reachable via Tailscale/SSH but only with password. Need key-based auth before automating.

### Step 1: Password-authenticate and add public key
```bash
# First time only:
sshpass -p '<PASSWORD>' ssh -o StrictHostKeyChecking=no user@kali "mkdir -p ~/.ssh && \
  echo 'ssh-ed25519 AAAA... your-key-comment' >> ~/.ssh/authorized_keys && \
  chmod 600 ~/.ssh/authorized_keys"
```

### Step 2: Verify key auth works
```bash
ssh -i /path/to/private_key user@kali "echo OK"
# Should return: OK
```

### Step 3: Add NOPASSWD sudo (required for tool install)
```bash
# Login Kali manually (console/Tailscale):
echo "user ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
```

### Step 4: Install recon toolchain
```bash
sudo apt-get install -y httpx dnsx gau naabu gowitness assetfinder subjack
```

**Why ntpd/etc needs NOPASSWD:** Automated install scripts pipe to sudo which blocks on TTY. Either NOPASSWD sudo or manual install.

## Kali Spec Reference
- **User:** ramsy
- **Password:** ricky321
- **Host:** kali.taile76fd9.ts.net (100.64.217.73)
- **OS:** Kali Rolling x86_64 (7.1.5)
- **CPU:** AMD Ryzen 5 PRO 3500U (8 cores @ 3.70GHz)
- **RAM:** 21.41 GiB
- **Disk:** 220.63 GB (91% used — monitor)

## Automation Pattern
```bash
# Install sshpass if needed:
sudo apt-get install -y sshpass

# Full provisioning:
sshpass -p 'ricky321' ssh -o StrictHostKeyChecking=no ramsy@kali \
  "echo ricky321 | sudo -S apt-get update && \
   echo ricky321 | sudo -S apt-get install -y httpx dnsx gau naabu gowitness assetfinder subjack subfinder nuclei"
```

# CAUTION: piping sudo -S password is blocked by security policy. Use NOPASSWD sudo instead.

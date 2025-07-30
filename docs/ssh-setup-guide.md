# SSH Setup Guide for Mac Studio

This guide covers the manual steps required to enable SSH access on your Mac Studio before running the automated setup.

## Prerequisites

- Physical access to Mac Studio (one-time setup)
- Both machines on the same network
- Admin privileges on both machines

## Step 1: Enable Remote Login on Mac Studio

### Option A: Using System Settings (GUI)
1. On Mac Studio, open **System Settings**
2. Navigate to **General** → **Sharing**
3. Toggle **Remote Login** to ON
4. Note the SSH command shown (e.g., `ssh username@YourMac-Studio.local`)

### Option B: Using Command Line
```bash
# On Mac Studio (requires physical access)
sudo systemsetup -setremotelogin on
```

## Step 2: Find Your Mac Studio's Address

On Mac Studio, determine your hostname and IP:

```bash
# Get hostname
hostname
# Example output: Johns-Mac-Studio.local

# Get IP address
ipconfig getifaddr en0
# Example output: 192.168.1.50
```

## Step 3: Test Connection from MacBook Pro

```bash
# Try hostname first
ssh username@mac-studio.local

# If hostname doesn't work, use IP
ssh username@192.168.1.50
```

Replace `username` with your Mac Studio username.

## Step 4: Set Up SSH Key Authentication

For passwordless access (recommended):

```bash
# On MacBook Pro
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "llm-setup@macbook"

# Copy key to Mac Studio
ssh-copy-id username@mac-studio.local

# Test passwordless login
ssh username@mac-studio.local
```

## Troubleshooting

### "Connection refused" error
- Verify Remote Login is enabled on Mac Studio
- Check firewall settings: `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`

### "Host not found" error
- Use IP address instead of hostname
- Ensure both machines are on same network
- Check network settings: `ifconfig | grep inet`

### "Permission denied" error
- Verify username is correct
- Check password is correct
- Ensure user has SSH access privileges

### Firewall blocking connection
```bash
# On Mac Studio
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/sbin/sshd
```

## Security Best Practices

1. **Use SSH keys** instead of passwords
2. **Limit SSH to local network** (done automatically by our setup)
3. **Disable root login**: Edit `/etc/ssh/sshd_config` and set `PermitRootLogin no`
4. **Use strong passwords** if not using SSH keys

## Next Steps

Once SSH is working, return to the main README and continue with:
```bash
swissarmyhammer --debug flow run implement
```

This will automate the rest of the setup process.
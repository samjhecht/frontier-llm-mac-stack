# SSH Port Forwarding Setup Guide for Mac LLM Access

## Overview
This guide walks you through setting up SSH with port forwarding to remotely access an LLM running on your Mac Studio from your MacBook Pro.

## Prerequisites
- Mac Studio (host machine) running your LLM
- MacBook Pro (client machine) for remote access
- Both machines on the same network (initially)
- Admin access on both machines

## Part 1: Mac Studio Setup (Host Machine)

### Step 1: Enable Remote Login
1. Open **System Settings** on your Mac Studio
2. Navigate to **General** → **Sharing**
3. Toggle on **Remote Login**
4. Choose **Allow full disk access for remote users** (recommended for development)
5. Under "Allow access for:", select either:
   - **All users** (easier setup)
   - **Only these users** (more secure - add your username)

### Step 2: Find Your Mac Studio's IP Address
1. In **System Settings**, go to **Wi-Fi**
2. Click **Details** next to your network name
3. Note the **IP Address** (e.g., `192.168.1.100`)
4. Write this down - you'll need it for connections

### Step 3: Configure Your LLM Service
Depending on your LLM setup:

**For Ollama:**
```bash
# Start Ollama with host binding (if not already running)
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

**For custom Python servers:**
```bash
# Ensure your server binds to all interfaces
# Example: app.run(host='0.0.0.0', port=8080)
```

**For LM Studio:**
- Go to **Settings** → **Server**
- Set **Host** to `0.0.0.0`
- Note the port number (usually 1234)

### Step 4: Test Local Access
Open a web browser on your Mac Studio and verify your LLM is accessible at:
- Ollama: `http://localhost:11434`
- LM Studio: `http://localhost:1234`
- Custom setup: `http://localhost:[your-port]`

## Part 2: MacBook Pro Setup (Client Machine)

### Step 5: Test SSH Connection
1. Open **Terminal** on your MacBook Pro
2. Test basic SSH connection:
```bash
ssh [your-username]@[mac-studio-ip]
```
Example: `ssh john@192.168.1.100`

3. Enter your Mac Studio password when prompted
4. If successful, you'll see the Mac Studio terminal
5. Type `exit` to return to your MacBook Pro

### Step 6: Setup SSH Key Authentication (Optional but Recommended)
This eliminates the need to enter passwords repeatedly:

1. On your MacBook Pro, generate SSH keys (if you don't have them):
```bash
ssh-keygen -t rsa -b 4096
```
Press Enter for all prompts to use defaults

2. Copy your public key to the Mac Studio:
```bash
ssh-copy-id [your-username]@[mac-studio-ip]
```

3. Test passwordless connection:
```bash
ssh [your-username]@[mac-studio-ip]
```

## Part 3: Port Forwarding Setup

### Step 7: Basic Port Forwarding
Connect with port forwarding to access your LLM:

**For Ollama (port 11434):**
```bash
ssh -L 11434:localhost:11434 [your-username]@[mac-studio-ip]
```

**For LM Studio (port 1234):**
```bash
ssh -L 1234:localhost:1234 [your-username]@[mac-studio-ip]
```

**For custom port (e.g., 8080):**
```bash
ssh -L 8080:localhost:8080 [your-username]@[mac-studio-ip]
```

### Step 8: Test Remote Access
1. Keep the SSH connection open
2. On your MacBook Pro, open a web browser
3. Navigate to `http://localhost:[port]` (same port as your LLM)
4. You should see your LLM interface served from the Mac Studio

### Step 9: Background Connection (Optional)
To run the SSH connection in the background:

```bash
ssh -f -N -L [local-port]:localhost:[remote-port] [username]@[mac-studio-ip]
```

Example:
```bash
ssh -f -N -L 11434:localhost:11434 john@192.168.1.100
```

To kill background connections:
```bash
# List SSH processes
ps aux | grep ssh

# Kill specific process
kill [process-id]
```

## Part 4: Advanced Configuration

### Step 10: Create SSH Config (Convenience)
Create `~/.ssh/config` on your MacBook Pro for easier connections:

```
Host mac-studio-llm
    HostName [mac-studio-ip]
    User [your-username]
    LocalForward 11434 localhost:11434
    LocalForward 1234 localhost:1234
```

Now you can simply run:
```bash
ssh mac-studio-llm
```

### Step 11: Firewall Considerations
If you have issues connecting:

1. On Mac Studio, check **System Settings** → **Network** → **Firewall**
2. Ensure firewall allows SSH connections
3. Consider temporarily disabling firewall for testing

## Part 5: Usage Patterns

### Development Workflow
1. Start SSH connection with port forwarding
2. Access LLM through `localhost:[port]` on MacBook Pro
3. Develop as if LLM were running locally
4. Keep SSH session open during development

### API Integration
If using the LLM via API calls in your code, point requests to:
```
http://localhost:[forwarded-port]/api/[endpoint]
```

### Multiple Port Forwarding
Forward multiple services simultaneously:
```bash
ssh -L 11434:localhost:11434 -L 8080:localhost:8080 [user]@[host]
```

## Troubleshooting

### Common Issues
- **Connection refused**: Check if Remote Login is enabled
- **Port already in use**: Another service might be using the port locally
- **Timeout**: Verify IP address and network connectivity
- **Permission denied**: Check username and password/SSH keys

### Testing Commands
```bash
# Test network connectivity
ping [mac-studio-ip]

# Check if SSH port is open
nc -zv [mac-studio-ip] 22

# List active SSH connections
ss -tulpn | grep :22
```

### Security Notes
- Only enable Remote Login when needed
- Use SSH keys instead of passwords
- Consider changing the default SSH port (22) for external access
- Regularly update both machines

## External Access (Bonus)

### Router Configuration
To access from outside your home network:
1. Configure port forwarding on your router (port 22 → Mac Studio)
2. Use your external IP address instead of local IP
3. Consider using a dynamic DNS service
4. **Important**: Use SSH keys and strong authentication for external access

### VPN Alternative
Consider setting up a VPN server for more secure external access instead of exposing SSH directly to the internet.

---

## Quick Reference Commands

**Basic connection:**
```bash
ssh [username]@[ip-address]
```

**With port forwarding:**
```bash
ssh -L [local-port]:localhost:[remote-port] [username]@[ip-address]
```

**Background connection:**
```bash
ssh -f -N -L [local-port]:localhost:[remote-port] [username]@[ip-address]
```

**Kill background SSH:**
```bash
pkill -f "ssh.*-L"
```
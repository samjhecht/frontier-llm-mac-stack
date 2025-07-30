# Step 2: SSH Setup Verification and Configuration

## Overview
Verify SSH connectivity between MacBook Pro and Mac Studio is properly configured. This is essential for remote deployment and management of the LLM stack.

## Tasks
1. Create SSH verification script
2. Test SSH key-based authentication
3. Verify network connectivity and hostname resolution
4. Create SSH config optimization for persistent connections

## Implementation Details

### Create script: `scripts/validation/verify-ssh.sh`
```bash
#!/bin/bash
# Tasks:
# 1. Check if SSH key exists (~/.ssh/id_*)
# 2. Test SSH connection to Mac Studio
# 3. Verify passwordless authentication
# 4. Test file transfer capabilities
# 5. Check network latency
```

### SSH Config Optimization
Create or update `~/.ssh/config`:
```
Host mac-studio mac-studio.local
    HostName mac-studio.local
    User username
    ControlMaster auto
    ControlPath ~/.ssh/master-%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

## Dependencies
- Step 1 must be completed (prerequisites validated)

## Success Criteria
- SSH connection works without password prompt
- File transfer via SCP works
- Connection persists for multiple commands
- Network latency is acceptable (<10ms for LAN)

## Testing
- Test with both hostname and IP address
- Verify SSH key permissions (600)
- Test with large file transfer
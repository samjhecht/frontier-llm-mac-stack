# Step 1: Validate Prerequisites and System Requirements

## Overview
Implement automated validation of system prerequisites before beginning the LLM stack setup. This ensures the Mac Studio meets minimum requirements and has necessary dependencies.

## Tasks
1. Create a validation script that checks:
   - macOS version (should be recent)
   - Available RAM (minimum 32GB, recommend 64GB+)
   - Available disk space (minimum 100GB, recommend 500GB+)
   - Docker Desktop installation and running status
   - Homebrew installation
   - Network connectivity

2. Create script: `scripts/validation/check-prerequisites.sh`

## Implementation Details
```bash
#!/bin/bash
# Check system requirements:
# - macOS version using sw_vers
# - Memory using sysctl hw.memsize
# - Disk space using df
# - Docker status using docker info
# - Homebrew using brew --version
```

## Success Criteria
- Script exits with 0 if all prerequisites met
- Clear error messages for any missing requirements
- Warnings for suboptimal but acceptable conditions
- Should complete in under 10 seconds

## Testing
- Run on Mac Studio with various conditions
- Test with Docker stopped
- Test with low disk space
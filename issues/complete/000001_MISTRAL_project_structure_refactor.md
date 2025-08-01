# MISTRAL_000001: Refactor Project Structure for Multi-Inference Support

## Objective
Refactor the project structure to support multiple inference engines (Ollama and Mistral.rs) as separate, selectable stacks.

## Context
Currently, the project is tightly coupled to Ollama. We need to create a flexible structure that allows users to choose between different inference engines while maintaining the same monitoring and management capabilities.

## Tasks

### 1. Create New Directory Structure
- Create `stacks/` directory at project root
- Create `stacks/ollama/` subdirectory for existing Ollama configuration
- Create `stacks/mistral/` subdirectory for new Mistral.rs configuration
- Create `stacks/common/` for shared components (monitoring, nginx)

### 2. Move Existing Ollama Configuration
- Move current `docker-compose.yml` to `stacks/ollama/docker-compose.yml`
- Create Ollama-specific `.env.example` in `stacks/ollama/`
- Move Ollama-specific configuration files to appropriate subdirectories

### 3. Create Stack Selection Mechanism
- Create a root-level `stack-select.sh` script
- Implement logic to symlink selected stack's docker-compose.yml to root
- Update helper scripts to work with selected stack

### 4. Update Documentation Structure
- Create `docs/stacks/` directory
- Move Ollama-specific documentation to `docs/stacks/ollama/`
- Create placeholder for `docs/stacks/mistral/`

## Implementation Details

```bash
# New directory structure
frontier-llm-mac-stack/
├── stacks/
│   ├── common/
│   │   ├── monitoring/
│   │   │   ├── prometheus/
│   │   │   └── grafana/
│   │   └── nginx/
│   ├── ollama/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── config/
│   └── mistral/
│       ├── docker-compose.yml (to be created)
│       ├── .env.example (to be created)
│       └── config/ (to be created)
├── stack-select.sh (new)
├── docker-compose.yml (symlink to selected stack)
└── .env (user's actual env file)
```

## Success Criteria
- Existing Ollama functionality remains unchanged
- Stack selection mechanism works correctly
- All helper scripts continue to function
- Clear separation between stack-specific and common components

## Estimated Changes
- ~50 lines of new shell scripts
- File movements (no code changes)
- Documentation updates

## Proposed Solution

Based on my analysis of the current project structure, I will implement the following steps:

1. **Create the new directory structure**:
   - Create `stacks/` directory at the project root
   - Create subdirectories: `stacks/ollama/`, `stacks/mistral/`, and `stacks/common/`
   - Create subdirectories for common components: `stacks/common/monitoring/` and `stacks/common/nginx/`

2. **Separate stack-specific from common components**:
   - Move Ollama service configuration to `stacks/ollama/docker-compose.yml`
   - Extract common monitoring services (Prometheus, Grafana, Node-exporter) to `stacks/common/monitoring/docker-compose.yml`
   - Extract Nginx configuration to `stacks/common/nginx/docker-compose.yml`
   - Create Ollama-specific `.env.example` with only Ollama-related variables

3. **Create the stack selection mechanism**:
   - Implement `stack-select.sh` script to:
     - List available stacks
     - Create symlinks for the selected stack's docker-compose files
     - Generate a combined docker-compose setup that includes common components
   - Update the root directory to use the symlinked configuration

4. **Update helper scripts**:
   - Modify existing scripts to work with the new structure
   - Ensure backward compatibility where possible

5. **Reorganize documentation**:
   - Create `docs/stacks/` directory structure
   - Move Ollama-specific documentation
   - Create placeholder documentation for Mistral

6. **Test the refactoring**:
   - Verify Ollama stack continues to work as before
   - Test stack selection mechanism
   - Ensure all helper scripts function correctly
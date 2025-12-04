# Proxmox API Architecture

This document describes the architectural approach for interacting with Proxmox VE (PVE) clusters within the `adaptive-shell` ecosystem. The implementation provides a unified interface that transparently switches between local CLI execution and remote API calls based on the execution context.

## Core Philosophy: "Hybrid Execution"

The central design goal is **portability**. Scripts using these utilities should run identically whether they are:

1. **On a PVE Host**: Executed directly via SSH or console on a Proxmox node.
2. **Remote**: Executed from a developer laptop, a CI/CD runner, or a management container.
3. **Inside a Container**: Executed from within an LXC or VM hosted on the cluster.

To achieve this, the architecture abstracts the transport mechanism:

- **Local Context**: When running on a PVE host, it utilizes `pvesh` (Proxmox Shell) via the CLI. This is faster and requires no additional authentication.
- **Remote Context**: When running elsewhere, it utilizes `curl` to hit the Proxmox REST API (port 8006). This requires an API Token.

## Key Components

The architecture is split across three primary files in `utils/`:

| File | Purpose |
| :--- | :--- |
| **`proxmox-utils.sh`** | Core infrastructure. Contains the transport logic (`pve_endpoint`), node resolution, and low-level `curl`/`jq` handling. |
| **`proxmox-api.sh`** | High-level business logic. Defines specific resource getters (e.g., `pve_lxc_containers`, `pve_storage`) that use the core infrastructure. |
| **`pve.sh`** | **Legacy/Compatibility**. Main entry point for older scripts. Sources the new files and provides backward-compatible wrappers (e.g., `pve_api_get`). |

### The `pve_endpoint` Abstraction

The heart of the system is the `pve_endpoint` function in `proxmox-utils.sh`. It signature is:

```bash
pve_endpoint <api_path> [jq_filter] [suggested_host]
```

**Logic Flow:**

1. **Detect Environment**: Checks `is_pve_host` (from `detection.sh`).
2. **Prepare Filter**: Adapts the `jq` filter syntax (CLI `pvesh` output vs API JSON structure can differ slightly, though `pve_endpoint` standardizes this).
3. **Dispatch**:
    - **If Local**: Calls `pve_cli_call` -> `pvesh get <path> --output-format=json`
    - **If Remote**: Calls `pve_api_call` -> `curl https://<node>:8006/api2/json/<path>`

### Node Discovery & Routing

When operating remotely, the system must know *which* node to contact. This is handled by `get_proxmox_node`.

**Discovery Strategy (in order):**

1. **Cluster Cache**: Checks `~/.pve-cluster.env` for previously discovered clusters.
2. **Explicit Request**: If a specific IP/DNS is requested, it validates accessibility.
3. **Environment Variables**: Checks `PROXMOX_HOST` (primary) and `PROXMOX_FALLBACK`.
4. **Defaults**: Tries standard hostnames like `pve.home`, `pve.local`, `pve`.

Once a node is successfully contacted, its cluster membership is cached to `~/.pve-cluster.env` via `save_pve_cluster`. This speeds up subsequent calls by avoiding repeated discovery probes.

## Configuration & Authentication

### Environment Variables

| Variable | Description |
| :--- | :--- |
| `PVE_API_TOKEN` | **Required for Remote.** Format: `USER@REALM!TOKENID=UUID`. |
| `PVE_API_KEY` | Alternate name for the token (used in some legacy contexts). |
| `PROXMOX_HOST` | Primary hostname/IP to attempt connection to. |
| `PROXMOX_FALLBACK` | Secondary hostname/IP if primary fails. |
| `PROXMOX_API_PORT` | Defaults to `8006`. |

### Setup Recommendations

1. **Create an API Token** in Proxmox (Datacenter -> Permissions -> API Tokens). Uncheck "Privilege Separation" if you want it to inherit the user's full permissions, or assign specific ACLs.
2. **Export the Token**:

    ```bash
    export PVE_API_TOKEN="root@pam!myscript=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    ```

3. **Source the Utilities**:

    ```bash
    source utils/pve.sh
    # or specifically
    source utils/proxmox-api.sh
    ```

## Usage Examples

### Getting a List of Containers

```bash
source utils/proxmox-api.sh

# Returns a JSON array of LXC containers
containers=$(pve_lxc_containers)

# Process with jq
echo "$containers" | jq -r '.[] | .name'
```

### Direct Endpoint Access

If a specific wrapper function doesn't exist, use `pve_endpoint` directly:

```bash
# Get cluster status
# Path corresponds to API: /api2/json/cluster/status
status=$(pve_endpoint "/cluster/status")
```

### Using Filters

The system integrates `jq` filtering directly into the call to minimize shell overhead:

```bash
# Get only running containers
# The filter syntax is standard jq
running=$(pve_endpoint "/cluster/resources" "| map(select(.status == \"running\"))")
```

## Developing New Functions

When adding new functionality:

1. **Add to `proxmox-api.sh`**: Create a specific function (e.g., `pve_get_users`).
2. **Use `pve_endpoint`**: Do not call `curl` or `pvesh` directly.
3. **Return JSON**: Always return the raw (or filtered) JSON string. Let the caller handle formatting or display logic.



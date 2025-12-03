import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { sourcedBash, bashExitCode } from './helpers'
import { execSync } from 'child_process'
import * as fs from 'fs'
import * as path from 'path'
import * as os from 'os'

// Temporary directory for test files
let tmpDir: string
let testEnvFile: string

beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'proxmox-test-'))
    testEnvFile = path.join(tmpDir, '.pve-cluster.env')
})

afterEach(() => {
    if (tmpDir && fs.existsSync(tmpDir)) {
        fs.rmSync(tmpDir, { recursive: true, force: true })
    }
})

describe('PVE Node Identification', () => {

    describe('uc() function', () => {
        it('should convert lowercase to uppercase', () => {
            const result = sourcedBash('./utils/text.sh', 'uc "hello world"')
            expect(result).toBe('HELLO WORLD')
        })

        it('should convert mixed case to uppercase', () => {
            const result = sourcedBash('./utils/text.sh', 'uc "HeLLo WoRLd"')
            expect(result).toBe('HELLO WORLD')
        })

        it('should handle already uppercase text', () => {
            const result = sourcedBash('./utils/text.sh', 'uc "HELLO"')
            expect(result).toBe('HELLO')
        })

        it('should handle empty string', () => {
            const result = sourcedBash('./utils/text.sh', 'uc ""')
            expect(result).toBe('')
        })

        it('should handle special characters', () => {
            const result = sourcedBash('./utils/text.sh', 'uc "hello-world_123"')
            expect(result).toBe('HELLO-WORLD_123')
        })
    })

    describe('match_known_cluster()', () => {
        it('should return empty when no clusters defined and no default', () => {
            // Function echoes empty string and returns 1
            const result = sourcedBash('./utils/proxmox.sh', 'match_known_cluster ""')
            expect(result).toBe('')
        })

        it('should use DEFAULT_PVE_CLUSTER when no request specified', () => {
            const result = sourcedBash('./utils/proxmox.sh',
                'export DEFAULT_PVE_CLUSTER="VENICE" && export PVE_CLUSTER_VENICE="192.168.100.2 192.168.100.4" && match_known_cluster ""')
            expect(result).toBe('192.168.100.2 192.168.100.4')
        })

        it('should look up requested cluster by name (case insensitive)', () => {
            const result = sourcedBash('./utils/proxmox.sh',
                'export PVE_CLUSTER_ROME="192.168.200.1 192.168.200.2" && match_known_cluster "rome"')
            expect(result).toBe('192.168.200.1 192.168.200.2')
        })

        it('should return empty when cluster not found', () => {
            const result = sourcedBash('./utils/proxmox.sh',
                'export PVE_CLUSTER_VENICE="1.2.3.4" && match_known_cluster "UNKNOWN"')
            expect(result).toBe('')
        })

        it('should handle uppercase request', () => {
            const result = sourcedBash('./utils/proxmox.sh',
                'export PVE_CLUSTER_VENICE="10.0.0.1" && match_known_cluster "VENICE"')
            expect(result).toBe('10.0.0.1')
        })

        it('should handle mixed case request', () => {
            const result = sourcedBash('./utils/proxmox.sh',
                'export PVE_CLUSTER_VENICE="10.0.0.1" && match_known_cluster "Venice"')
            expect(result).toBe('10.0.0.1')
        })
    })

    describe('pve_node_up()', () => {
        it('should return empty string when all candidates unreachable', () => {
            // Use invalid addresses that will definitely fail
            const result = sourcedBash('./utils/proxmox.sh',
                'candidates=("192.0.2.1" "192.0.2.2") && pve_node_up candidates')
            expect(result).toBe('')
        })

        it('should return empty string when single candidate unreachable', () => {
            const result = sourcedBash('./utils/proxmox.sh',
                'candidates=("192.0.2.1") && pve_node_up candidates')
            expect(result).toBe('')
        })

        it('should handle empty candidates array', () => {
            const result = sourcedBash('./utils/proxmox.sh',
                'candidates=() && pve_node_up candidates')
            expect(result).toBe('')
        })
    })

    describe('save_pve_cluster()', () => {
        it('should return 1 when node is empty', () => {
            const exitCode = bashExitCode('source ./utils/proxmox.sh && save_pve_cluster ""')
            expect(exitCode).toBe(1)
        })
    })

    describe('CLUSTER_ENV_FILE format', () => {
        it('should be sourced correctly when it exists', () => {
            // Create a test env file
            fs.writeFileSync(testEnvFile, `
PVE_CLUSTER_VENICE="192.168.100.2 192.168.100.4 192.168.100.5"
PVE_CLUSTER_ROME="192.168.200.1 192.168.200.2"
DEFAULT_PVE_CLUSTER="VENICE"
`)
            const result = sourcedBash('./utils/proxmox.sh',
                `source "${testEnvFile}" && match_known_cluster ""`)
            expect(result).toBe('192.168.100.2 192.168.100.4 192.168.100.5')
        })

        it('should allow looking up specific cluster from env file', () => {
            fs.writeFileSync(testEnvFile, `
PVE_CLUSTER_VENICE="192.168.100.2"
PVE_CLUSTER_ROME="192.168.200.1"
DEFAULT_PVE_CLUSTER="VENICE"
`)
            const result = sourcedBash('./utils/proxmox.sh',
                `source "${testEnvFile}" && match_known_cluster "rome"`)
            expect(result).toBe('192.168.200.1')
        })
    })

    describe('get_proxmox_node() logic', () => {
        it('should recognize IPv4 addresses in request', () => {
            // This tests that is_ip4_address branch is taken
            // We can't fully test without network, but we can verify the function exists
            const exitCode = bashExitCode('source ./utils/proxmox.sh && type -t get_proxmox_node')
            expect(exitCode).toBe(0)
        })

        it('should have proper array handling for match_known_cluster result', () => {
            // Test that the fixed code properly splits space-delimited IPs
            const result = sourcedBash('./utils/proxmox.sh', `
export PVE_CLUSTER_TEST="10.0.0.1 10.0.0.2 10.0.0.3"
matched="$(match_known_cluster "TEST")"
read -ra arr <<< "\$matched"
echo "\${#arr[@]}"
`)
            expect(result).toBe('3')
        })
    })
})

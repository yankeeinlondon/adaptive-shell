import { describe, it, expect } from 'vitest'
import { sourceScript } from './helpers'

describe('Proxmox VE utilities - API Functions', () => {
    describe('has_pve_api_key()', () => {
        describe('environment variable checks', () => {
            it('should return success when PVE_API_KEY env var is set', () => {
                const api = sourceScript('./utils/pve.sh', {
                    env: { ...process.env, PVE_API_KEY: 'test-api-key-12345' }
                })('has_pve_api_key')()
                expect(api).toBeSuccessful()
            })

            it('should return success when PVE_API_KEY is non-empty', () => {
                const api = sourceScript('./utils/pve.sh', {
                    env: { ...process.env, PVE_API_KEY: 'any-value' }
                })('has_pve_api_key')()
                expect(api).toBeSuccessful()
            })

            it('should return failure when PVE_API_KEY is empty', () => {
                const api = sourceScript('./utils/pve.sh', {
                    env: { ...process.env, PVE_API_KEY: '' }
                })('has_pve_api_key')()
                expect(api).toFail()
            })

            it('should return failure when PVE_API_KEY is not set', () => {
                // Create env without PVE_API_KEY
                const envWithoutKey = { ...process.env }
                delete envWithoutKey.PVE_API_KEY

                const api = sourceScript('./utils/pve.sh', {
                    env: envWithoutKey
                })('has_pve_api_key')()
                expect(api).toFail()
            })
        })

        describe('behavior on non-container hosts', () => {
            it('should return failure on normal host without API key', () => {
                // On a normal (non-LXC, non-VM) host without env var
                const envWithoutKey = { ...process.env }
                delete envWithoutKey.PVE_API_KEY

                const api = sourceScript('./utils/pve.sh', {
                    env: envWithoutKey
                })('has_pve_api_key')()
                // Should fail because: no env var, not in LXC/VM
                expect(api).toFail()
            })
        })
    })

    describe('is_pve_container()', () => {
        describe('on non-container hosts', () => {
            it('should return failure when not in LXC or VM', () => {
                // On a standard macOS/Linux host (not a container)
                const api = sourceScript('./utils/pve.sh', {
                    env: { ...process.env, PVE_API_KEY: 'test-key' }
                })('is_pve_container')()
                // Should fail because host is not an LXC or VM
                expect(api).toFail()
            })

            it('should return failure even with API key when not in container', () => {
                const api = sourceScript('./utils/pve.sh', {
                    env: { ...process.env, PVE_API_KEY: 'any-key-value' }
                })('is_pve_container')()
                expect(api).toFail()
            })
        })
    })

    describe('pve_api_get()', () => {
        describe('parameter validation', () => {
            it('should require a path parameter', () => {
                const api = sourceScript('./utils/pve.sh', {
                    env: { ...process.env }
                })('pve_api_get')()
                expect(api).toFail()
                expect(api).toContainInStdErr('pve_api_get requires an API path')
            })
        })
    })

    describe('about_container()', () => {
        describe('on non-container hosts', () => {
            it('should return failure when not in LXC or VM', () => {
                const api = sourceScript('./utils/pve.sh', {
                    env: { ...process.env }
                })('about_container')()
                expect(api).toFail()
            })
        })
    })

    describe('script sanity', () => {
        it('should source without errors', () => {
            // Just source the script - should not fail
            const api = sourceScript('./utils/pve.sh')('true')()
            expect(api).toBeSuccessful()
        })

        it('should define expected functions', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('declare')('-F', 'has_pve_api_key')
            expect(api).toBeSuccessful()
        })

        it('should define is_pve_container function', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('declare')('-F', 'is_pve_container')
            expect(api).toBeSuccessful()
        })

        it('should define pve_api_get function', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('declare')('-F', 'pve_api_get')
            expect(api).toBeSuccessful()
        })

        it('should define get_proxmox_node function', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('declare')('-F', 'get_proxmox_node')
            expect(api).toBeSuccessful()
        })

        it('should define about_container function', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('declare')('-F', 'about_container')
            expect(api).toBeSuccessful()
        })
    })

    describe('exit code constants', () => {
        it('should define EXIT_OK as 0', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('echo')('$EXIT_OK')
            expect(api).toReturn('0')
        })

        it('should define EXIT_FALSE as 1', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('echo')('$EXIT_FALSE')
            expect(api).toReturn('1')
        })

        it('should define EXIT_API as 2', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('echo')('$EXIT_API')
            expect(api).toReturn('2')
        })

        it('should define EXIT_CONFIG as 1', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('echo')('$EXIT_CONFIG')
            expect(api).toReturn('1')
        })

        it('should define EXIT_NOTFOUND as 3', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('echo')('$EXIT_NOTFOUND')
            expect(api).toReturn('3')
        })
    })

    describe('configuration constants', () => {
        it('should set default PROXMOX_API_PORT to 8006', () => {
            const envWithoutPort = { ...process.env }
            delete envWithoutPort.PROXMOX_API_PORT

            const api = sourceScript('./utils/pve.sh', {
                env: envWithoutPort
            })('echo')('$PROXMOX_API_PORT')
            expect(api).toReturn('8006')
        })

        it('should respect custom PROXMOX_API_PORT', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env, PROXMOX_API_PORT: '9999' }
            })('echo')('$PROXMOX_API_PORT')
            expect(api).toReturn('9999')
        })

        it('should set API_BASE to /api2/json/', () => {
            const api = sourceScript('./utils/pve.sh', {
                env: { ...process.env }
            })('echo')('$API_BASE')
            expect(api).toReturn('/api2/json/')
        })
    })
})

import { describe, it, expect } from 'vitest'
import { sourcedBash } from "../helpers"

describe('Network utilities - highlight_ip_addresses()', () => {
    describe('IPv4 highlighting', () => {
        it('should highlight a single IPv4 address', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "test 192.168.1.1 text" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })

        it('should highlight multiple IPv4 addresses on one line', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "from 10.0.0.1 to 192.168.1.1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}10.0.0.1{{RESET}}')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })

        it('should highlight IPv4 at start of line', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "192.168.1.1 is the gateway" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })

        it('should highlight IPv4 at end of line', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "gateway is 192.168.1.1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })

        it('should highlight IPv4 with surrounding punctuation', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "IP: 192.168.1.1, gateway" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })

        it('should highlight loopback address', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "localhost 127.0.0.1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}127.0.0.1{{RESET}}')
        })

        it('should highlight broadcast address', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "broadcast 255.255.255.255" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}255.255.255.255{{RESET}}')
        })

        it('should highlight zero address', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "any 0.0.0.0" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}0.0.0.0{{RESET}}')
        })

        it('should highlight multiple addresses across lines', () => {
            const result = sourcedBash('./utils/network.sh', 'echo -e "line1 10.0.0.1\\nline2 192.168.1.1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}10.0.0.1{{RESET}}')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })
    })

    describe('IPv6 highlighting', () => {
        it('should highlight full IPv6 address', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "address 2001:0db8:85a3:0000:0000:8a2e:0370:7334" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}2001:0db8:85a3:0000:0000:8a2e:0370:7334{{RESET}}')
        })

        it('should highlight compressed IPv6 address', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "address 2001:db8::1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}2001:db8::1{{RESET}}')
        })

        it('should highlight loopback IPv6', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "localhost ::1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}::1{{RESET}}')
        })

        it('should highlight all zeros IPv6', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "unspecified ::" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}::{{RESET}}')
        })

        it('should highlight IPv4-mapped IPv6', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "mapped ::ffff:192.168.1.1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}::ffff:192.168.1.1{{RESET}}')
        })

        it('should highlight IPv6 with zone identifier', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "link-local fe80::1%eth0" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}fe80::1%eth0{{RESET}}')
        })

        it('should highlight link-local address', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "link fe80::1234:5678:90ab:cdef" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}fe80::1234:5678:90ab:cdef{{RESET}}')
        })
    })

    describe('mixed IPv4 and IPv6', () => {
        it('should highlight both IPv4 and IPv6 on same line', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "v4: 192.168.1.1 v6: 2001:db8::1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
            expect(result).toContain('{{BOLD}}2001:db8::1{{RESET}}')
        })

        it('should highlight mixed addresses across multiple lines', () => {
            const result = sourcedBash('./utils/network.sh', 'echo -e "inet 192.168.1.1\\ninet6 fe80::1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
            expect(result).toContain('{{BOLD}}fe80::1{{RESET}}')
        })
    })

    describe('custom format parameter', () => {
        it('should use custom format tag', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "test 192.168.1.1" | highlight_ip_addresses "{{RED}}"')
            expect(result).toContain('{{RED}}192.168.1.1{{RESET}}')
        })

        it('should accept UNDERLINE format', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "test 10.0.0.1" | highlight_ip_addresses "{{UNDERLINE}}"')
            expect(result).toContain('{{UNDERLINE}}10.0.0.1{{RESET}}')
        })

        it('should accept DIM format', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "test 172.16.0.1" | highlight_ip_addresses "{{DIM}}"')
            expect(result).toContain('{{DIM}}172.16.0.1{{RESET}}')
        })

        it('should accept combined format tags', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "test 8.8.8.8" | highlight_ip_addresses "{{BOLD}}{{BLUE}}"')
            expect(result).toContain('{{BOLD}}{{BLUE}}8.8.8.8{{RESET}}')
        })
    })

    describe('edge cases', () => {
        it('should handle empty input', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "" | highlight_ip_addresses')
            expect(result).toBe('')
        })

        it('should handle text with no IP addresses', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "no addresses here" | highlight_ip_addresses')
            expect(result).toBe('no addresses here')
        })

        it('should not highlight invalid IPv4 (out of range octets)', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "invalid 256.256.256.256" | highlight_ip_addresses')
            // Should not be highlighted
            expect(result).not.toContain('{{BOLD}}256.256.256.256{{RESET}}')
        })

        it('should not highlight partial IP addresses', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "version 1.2.3" | highlight_ip_addresses')
            // Should not be highlighted (only 3 octets)
            expect(result).not.toContain('{{BOLD}}1.2.3{{RESET}}')
        })

        it('should preserve internal whitespace', () => {
            // Note: Leading/trailing whitespace is trimmed by the test framework (sourcedBash)
            // This test verifies internal whitespace between tokens is preserved
            const result = sourcedBash('./utils/network.sh', 'echo "IP:  192.168.1.1  and  10.0.0.1" | highlight_ip_addresses')
            expect(result).toContain('IP:  {{BOLD}}192.168.1.1{{RESET}}  and  {{BOLD}}10.0.0.1{{RESET}}')
        })

        it('should handle addresses in complex text formats', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "inet 192.168.10.65 netmask 0xffffff00 broadcast 192.168.10.255" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.10.65{{RESET}}')
            expect(result).toContain('{{BOLD}}192.168.10.255{{RESET}}')
        })

        it('should handle addresses in ifconfig-style output', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "inet 127.0.0.1 netmask 0xff000000" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}127.0.0.1{{RESET}}')
            // Should not highlight hex values
            expect(result).not.toContain('{{BOLD}}0xff000000{{RESET}}')
        })
    })

    describe('realistic network interface output', () => {
        it('should highlight addresses in macOS ifconfig output', () => {
            const result = sourcedBash('./utils/network.sh', `echo "inet 192.168.1.100 netmask 0xffffff00 broadcast 192.168.1.255" | highlight_ip_addresses`)
            expect(result).toContain('{{BOLD}}192.168.1.100{{RESET}}')
            expect(result).toContain('{{BOLD}}192.168.1.255{{RESET}}')
            expect(result).toContain('netmask 0xffffff00')
        })

        it('should highlight addresses in Linux ip addr output', () => {
            const result = sourcedBash('./utils/network.sh', `echo "    inet 10.0.0.5/24 brd 10.0.0.255 scope global eth0" | highlight_ip_addresses`)
            expect(result).toContain('{{BOLD}}10.0.0.5{{RESET}}')
            expect(result).toContain('{{BOLD}}10.0.0.255{{RESET}}')
        })

        it('should highlight addresses in multi-line interface output', () => {
            const input = `inet 127.0.0.1 netmask 0xff000000
inet 192.168.1.100 netmask 0xffffff00 broadcast 192.168.1.255
inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1`
            const result = sourcedBash('./utils/network.sh', `echo "${input}" | highlight_ip_addresses`)
            expect(result).toContain('{{BOLD}}127.0.0.1{{RESET}}')
            expect(result).toContain('{{BOLD}}192.168.1.100{{RESET}}')
            expect(result).toContain('{{BOLD}}192.168.1.255{{RESET}}')
            expect(result).toContain('{{BOLD}}fe80::1%lo0{{RESET}}')
        })
    })

    describe('colorize integration', () => {
        it('should produce ANSI codes after colorize', () => {
            // colorize() takes arguments, not stdin, so we capture the output first
            const result = sourcedBash('./utils/network.sh', `
                source ./utils/color.sh
                setup_colors
                output=$(echo "test 192.168.1.1" | highlight_ip_addresses)
                colorize "\$output"
            `)
            // Should contain actual ANSI escape sequences (not the tags)
            expect(result).not.toContain('{{BOLD}}')
            expect(result).not.toContain('{{RESET}}')
            // Should contain the IP address
            expect(result).toContain('192.168.1.1')
        })

        it('should produce colored output with custom format', () => {
            // colorize() takes arguments, not stdin, so we capture the output first
            const result = sourcedBash('./utils/network.sh', `
                source ./utils/color.sh
                setup_colors
                output=$(echo "test 10.0.0.1" | highlight_ip_addresses "{{RED}}")
                colorize "\$output"
            `)
            // Should not contain the tags
            expect(result).not.toContain('{{RED}}')
            // Should contain the IP
            expect(result).toContain('10.0.0.1')
        })
    })

    describe('default format behavior', () => {
        it('should use BOLD as default when no format specified', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "test 192.168.1.1" | highlight_ip_addresses')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })

        it('should use BOLD when empty string passed', () => {
            const result = sourcedBash('./utils/network.sh', 'echo "test 192.168.1.1" | highlight_ip_addresses ""')
            expect(result).toContain('{{BOLD}}192.168.1.1{{RESET}}')
        })
    })
})

import { describe, it, expect } from 'vitest'
import { sourceScript } from "../helpers"

describe('Proxmox VE utilities - Network Validation', () => {
    describe('is_dns_name()', () => {
        describe('valid single-label names', () => {
            it('should accept "localhost"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('localhost')
                expect(api).toBeSuccessful()
            })

            it('should accept "server1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('server1')
                expect(api).toBeSuccessful()
            })

            it('should accept "web"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('web')
                expect(api).toBeSuccessful()
            })

            it('should accept single character label "a"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('a')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid multi-label FQDNs', () => {
            it('should accept "example.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example.com')
                expect(api).toBeSuccessful()
            })

            it('should accept "sub.domain.org"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('sub.domain.org')
                expect(api).toBeSuccessful()
            })

            it('should accept "mail.example.co.uk"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('mail.example.co.uk')
                expect(api).toBeSuccessful()
            })

            it('should accept "very-long-subdomain.example.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('very-long-subdomain.example.com')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid FQDN with trailing dot', () => {
            it('should accept "example.com."', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example.com.')
                expect(api).toBeSuccessful()
            })

            it('should accept "sub.domain.org."', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('sub.domain.org.')
                expect(api).toBeSuccessful()
            })

            it('should accept "localhost."', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('localhost.')
                expect(api).toBeSuccessful()
            })
        })

        describe('invalid: empty or missing', () => {
            it('should reject empty string', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('')
                expect(api).toFail()
            })
        })

        describe('invalid: leading hyphen in label', () => {
            it('should reject "-example.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('-example.com')
                expect(api).toFail()
            })

            it('should reject "sub.-domain.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('sub.-domain.com')
                expect(api).toFail()
            })

            it('should reject "-localhost"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('-localhost')
                expect(api).toFail()
            })
        })

        describe('invalid: trailing hyphen in label', () => {
            it('should reject "example-.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example-.com')
                expect(api).toFail()
            })

            it('should reject "sub.domain-.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('sub.domain-.com')
                expect(api).toFail()
            })

            it('should reject "localhost-"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('localhost-')
                expect(api).toFail()
            })
        })

        describe('invalid: double dots', () => {
            it('should reject "example..com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example..com')
                expect(api).toFail()
            })

            it('should reject "sub..domain.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('sub..domain.com')
                expect(api).toFail()
            })

            it('should reject "...example.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('...example.com')
                expect(api).toFail()
            })
        })

        describe('invalid: label exceeds 63 characters', () => {
            it('should reject label with 64 characters', () => {
                const longLabel = 'a'.repeat(64)
                const api = sourceScript('./utils/pve.sh')('is_dns_name')(`${longLabel}.com`)
                expect(api).toFail()
            })

            it('should reject label with 70 characters', () => {
                const longLabel = 'verylonglabelname'.repeat(5) // 85 chars
                const api = sourceScript('./utils/pve.sh')('is_dns_name')(`${longLabel}.com`)
                expect(api).toFail()
            })

            it('should accept label with exactly 63 characters', () => {
                const maxLabel = 'a'.repeat(63)
                const api = sourceScript('./utils/pve.sh')('is_dns_name')(`${maxLabel}.com`)
                expect(api).toBeSuccessful()
            })
        })

        describe('invalid: total length exceeds 253 characters', () => {
            it('should reject domain name with 254+ characters', () => {
                // Create a name that's just over 253 chars
                // Using 63-char labels separated by dots: "aaa...aaa.bbb...bbb.ccc...ccc.ddd...ddd"
                const label = 'a'.repeat(63)
                const longName = `${label}.${label}.${label}.${label}` // 63*4 + 3 = 255 chars
                const api = sourceScript('./utils/pve.sh')('is_dns_name')(longName)
                expect(api).toFail()
            })

            it('should accept domain name with exactly 253 characters', () => {
                // Create a name that's exactly 253 chars
                // 253 = 63 + 1 + 63 + 1 + 63 + 1 + 61
                const label63 = 'a'.repeat(63)
                const label61 = 'b'.repeat(61)
                const maxName = `${label63}.${label63}.${label63}.${label61}`
                const api = sourceScript('./utils/pve.sh')('is_dns_name')(maxName)
                expect(api).toBeSuccessful()
            })
        })

        describe('invalid: special characters (except hyphen)', () => {
            it('should reject "example_com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example_com')
                expect(api).toFail()
            })

            it('should reject "exam ple.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('exam ple.com')
                expect(api).toFail()
            })

            it('should reject "example@com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example@com')
                expect(api).toFail()
            })

            it('should reject "example!.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example!.com')
                expect(api).toFail()
            })

            it('should reject "example$.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('example$.com')
                expect(api).toFail()
            })
        })

        describe('edge case: all-numeric labels', () => {
            it('should accept "192.example.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('192.example.com')
                expect(api).toBeSuccessful()
            })

            it('should accept "1.2.example.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('1.2.example.com')
                expect(api).toBeSuccessful()
            })

            it('should accept "server123"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('server123')
                expect(api).toBeSuccessful()
            })
        })

        describe('edge case: single character labels', () => {
            it('should accept "a.b.c"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('a.b.c')
                expect(api).toBeSuccessful()
            })

            it('should accept "x.example.com"', () => {
                const api = sourceScript('./utils/pve.sh')('is_dns_name')('x.example.com')
                expect(api).toBeSuccessful()
            })
        })
    })

    describe('is_ip4_address()', () => {
        describe('valid standard addresses', () => {
            it('should accept "192.168.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.1.1')
                expect(api).toBeSuccessful()
            })

            it('should accept "10.0.0.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('10.0.0.1')
                expect(api).toBeSuccessful()
            })

            it('should accept "172.16.0.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('172.16.0.1')
                expect(api).toBeSuccessful()
            })

            it('should accept "8.8.8.8"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('8.8.8.8')
                expect(api).toBeSuccessful()
            })

            it('should accept "127.0.0.1" (loopback)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('127.0.0.1')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid boundary values', () => {
            it('should accept "0.0.0.0" (all zeros)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('0.0.0.0')
                expect(api).toBeSuccessful()
            })

            it('should accept "255.255.255.255" (all max)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('255.255.255.255')
                expect(api).toBeSuccessful()
            })

            it('should accept "255.0.0.0"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('255.0.0.0')
                expect(api).toBeSuccessful()
            })

            it('should accept "1.1.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('1.1.1.1')
                expect(api).toBeSuccessful()
            })
        })

        describe('invalid: empty string', () => {
            it('should reject empty string', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('')
                expect(api).toFail()
            })
        })

        describe('invalid: too few octets', () => {
            it('should reject "192.168.1" (3 octets)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.1')
                expect(api).toFail()
            })

            it('should reject "10.0" (2 octets)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('10.0')
                expect(api).toFail()
            })

            it('should reject "192" (1 octet)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192')
                expect(api).toFail()
            })
        })

        describe('invalid: too many octets', () => {
            it('should reject "192.168.1.1.1" (5 octets)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.1.1.1')
                expect(api).toFail()
            })

            it('should reject "10.0.0.1.2.3" (6 octets)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('10.0.0.1.2.3')
                expect(api).toFail()
            })
        })

        describe('invalid: octet exceeds 255', () => {
            it('should reject "256.1.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('256.1.1.1')
                expect(api).toFail()
            })

            it('should reject "192.256.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.256.1.1')
                expect(api).toFail()
            })

            it('should reject "192.168.256.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.256.1')
                expect(api).toFail()
            })

            it('should reject "192.168.1.256"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.1.256')
                expect(api).toFail()
            })

            it('should reject "999.999.999.999"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('999.999.999.999')
                expect(api).toFail()
            })
        })

        describe('invalid: negative values', () => {
            it('should reject "-1.168.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('-1.168.1.1')
                expect(api).toFail()
            })

            it('should reject "192.-168.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.-168.1.1')
                expect(api).toFail()
            })
        })

        describe('invalid: leading zeros', () => {
            it('should reject "192.168.01.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.01.1')
                expect(api).toFail()
            })

            it('should reject "192.168.001.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.001.1')
                expect(api).toFail()
            })

            it('should reject "010.0.0.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('010.0.0.1')
                expect(api).toFail()
            })
        })

        describe('invalid: non-numeric characters', () => {
            it('should reject "192.168.a.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.a.1')
                expect(api).toFail()
            })

            it('should reject "abc.def.ghi.jkl"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('abc.def.ghi.jkl')
                expect(api).toFail()
            })

            it('should reject "192.168.1.x"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.1.x')
                expect(api).toFail()
            })
        })

        describe('invalid: trailing or leading dots', () => {
            it('should reject ".192.168.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('.192.168.1.1')
                expect(api).toFail()
            })

            it('should reject "192.168.1.1."', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192.168.1.1.')
                expect(api).toFail()
            })

            it('should reject "192..168.1.1" (double dot)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip4_address')('192..168.1.1')
                expect(api).toFail()
            })
        })
    })

    describe('is_ip6_address()', () => {
        describe('valid full form', () => {
            it('should accept "2001:0db8:85a3:0000:0000:8a2e:0370:7334"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:0db8:85a3:0000:0000:8a2e:0370:7334')
                expect(api).toBeSuccessful()
            })

            it('should accept "2001:0db8:0000:0000:0000:0000:0000:0001"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:0db8:0000:0000:0000:0000:0000:0001')
                expect(api).toBeSuccessful()
            })

            it('should accept "fe80:0000:0000:0000:0204:61ff:fe9d:f156"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('fe80:0000:0000:0000:0204:61ff:fe9d:f156')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid compressed form', () => {
            it('should accept "2001:db8::1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:db8::1')
                expect(api).toBeSuccessful()
            })

            it('should accept "2001:db8::8a2e:370:7334"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:db8::8a2e:370:7334')
                expect(api).toBeSuccessful()
            })

            it('should accept "2001:db8:85a3::8a2e:370:7334"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:db8:85a3::8a2e:370:7334')
                expect(api).toBeSuccessful()
            })

            it('should accept "fe80::1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('fe80::1')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid loopback', () => {
            it('should accept "::1" (loopback)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('::1')
                expect(api).toBeSuccessful()
            })

            it('should accept "0000:0000:0000:0000:0000:0000:0000:0001" (full loopback)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('0000:0000:0000:0000:0000:0000:0000:0001')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid all-zeros', () => {
            it('should accept "::" (all zeros)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('::')
                expect(api).toBeSuccessful()
            })

            it('should accept "0000:0000:0000:0000:0000:0000:0000:0000" (full zeros)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('0000:0000:0000:0000:0000:0000:0000:0000')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid IPv4-mapped addresses', () => {
            it('should accept "::ffff:192.168.1.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('::ffff:192.168.1.1')
                expect(api).toBeSuccessful()
            })

            it('should accept "::ffff:10.0.0.1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('::ffff:10.0.0.1')
                expect(api).toBeSuccessful()
            })

            it('should accept "64:ff9b::192.0.2.33"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('64:ff9b::192.0.2.33')
                expect(api).toBeSuccessful()
            })
        })

        describe('valid link-local with zone identifier', () => {
            it('should accept "fe80::1%eth0"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('fe80::1%eth0')
                expect(api).toBeSuccessful()
            })

            it('should accept "fe80::204:61ff:fe9d:f156%en0"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('fe80::204:61ff:fe9d:f156%en0')
                expect(api).toBeSuccessful()
            })

            it('should accept "fe80::1%lo0"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('fe80::1%lo0')
                expect(api).toBeSuccessful()
            })
        })

        describe('invalid: empty string', () => {
            it('should reject empty string', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('')
                expect(api).toFail()
            })
        })

        describe('invalid: multiple :: (double colon)', () => {
            it('should reject "2001::db8::1" (multiple ::)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001::db8::1')
                expect(api).toFail()
            })

            it('should reject "2001::25de::cade" (multiple ::)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001::25de::cade')
                expect(api).toFail()
            })

            it('should reject "::1::" (multiple ::)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('::1::')
                expect(api).toFail()
            })
        })

        describe('invalid: too many groups', () => {
            it('should reject "2001:0db8:85a3:0000:0000:8a2e:0370:7334:extra"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:0db8:85a3:0000:0000:8a2e:0370:7334:extra')
                expect(api).toFail()
            })

            it('should reject "1:2:3:4:5:6:7:8:9"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('1:2:3:4:5:6:7:8:9')
                expect(api).toFail()
            })
        })

        describe('invalid: invalid hexadecimal characters', () => {
            it('should reject "2001:0db8:85g3:0000:0000:8a2e:0370:7334" (g is invalid)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:0db8:85g3:0000:0000:8a2e:0370:7334')
                expect(api).toFail()
            })

            it('should reject "2001:xyz::1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:xyz::1')
                expect(api).toFail()
            })

            it('should reject "gggg::1"', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('gggg::1')
                expect(api).toFail()
            })
        })

        describe('invalid: group exceeds 4 hex digits', () => {
            it('should reject "2001:0db8:85a3:00000:0000:8a2e:0370:7334" (5 digits)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:0db8:85a3:00000:0000:8a2e:0370:7334')
                expect(api).toFail()
            })

            it('should reject "12345::1" (5 digits)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('12345::1')
                expect(api).toFail()
            })

            it('should reject "2001:abcdef::1" (6 digits)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:abcdef::1')
                expect(api).toFail()
            })
        })

        describe('invalid: malformed addresses', () => {
            it('should reject ":::" (too many colons)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')(':::')
                expect(api).toFail()
            })

            it('should reject "2001:db8:" (trailing colon)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')('2001:db8:')
                expect(api).toFail()
            })

            it('should reject ":2001:db8::1" (leading single colon)', () => {
                const api = sourceScript('./utils/pve.sh')('is_ip6_address')(':2001:db8::1')
                expect(api).toFail()
            })
        })
    })
})

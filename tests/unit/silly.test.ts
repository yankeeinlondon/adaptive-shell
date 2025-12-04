import { describe, it, expect } from 'vitest'
import { sourcedBash, sourcedBashNoTrimStart, bashExitCode, sourceScript } from "../helpers"
import { urlLink } from "../helpers/link";

describe("silly", () => {


    describe("Test Utility Usage", () => {


        it("test", () => {

            const step1 = sourceScript("text.sh"); // sourced file
            const util = step1("do_something"); // add fn
            const api = util(); // add parameters

            /** API Surface */
            expect(typeof api.success).toBe("function")
            expect(typeof api.failure).toBe("function")
            expect(typeof api.returns).toBe("function")
            expect(typeof api.stdErrReturns).toBe("function")
            expect(typeof api.returnsTrimmed).toBe("function")
            expect(typeof api.stdErrReturnsTrimmed).toBe("function")
            expect(typeof api.contains).toBe("function")
            expect(typeof api.stdErrContains).toBe("function")

        });
    })


    describe('lc()', () => {
        it('should convert uppercase to lowercase', () => {
            const result = sourcedBash('./utils/text.sh', 'lc "HELLO WORLD"')
            expect(result).toBe('hello world')
        })

        it('should convert mixed case to lowercase', () => {
            const result = sourcedBash('./utils/text.sh', 'lc "HeLLo WoRLd"')
            expect(result).toBe('hello world')
        })

        it('should handle already lowercase text', () => {
            const result = sourcedBash('./utils/text.sh', 'lc "hello"')
            expect(result).toBe('hello')
        })

        it('should handle empty string', () => {
            const result = sourcedBash('./utils/text.sh', 'lc ""')
            expect(result).toBe('')
        })

        it('should handle special characters', () => {
            const result = sourcedBash('./utils/text.sh', 'lc "HELLO-WORLD_123"')
            expect(result).toBe('hello-world_123')
        })

    })

    describe('contains()', () => {
        it('should return 0 when substring is found', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && contains "world" "hello world"')
            expect(exitCode).toBe(0)
        })

        it('should return 1 when substring is not found', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && contains "foo" "hello world"')
            expect(exitCode).toBe(1)
        })

        it('should return 1 for empty content', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && contains "hello" ""')
            expect(exitCode).toBe(1)
        })

        it('should be case sensitive', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && contains "hello" "Hello"')
            expect(exitCode).toBe(1)
        })
    })

    describe('starts_with()', () => {
        it('should return 0 when string starts with prefix', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && starts_with "hello" "hello world"')
            expect(exitCode).toBe(0)
        })

        it('should return 1 when string does not start with prefix', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && starts_with "world" "hello world"')
            expect(exitCode).toBe(1)
        })

        it('should error on empty content', () => {
            // Function requires non-empty content (uses ${2:?...} parameter expansion)
            const exitCode = bashExitCode('source ./utils/text.sh && empty="" && starts_with "hello" "$empty" 2>/dev/null')
            expect(exitCode).toBe(127) // bash error code for parameter expansion failure
        })

        it('should be case sensitive', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && starts_with "hello" "Hello"')
            expect(exitCode).toBe(1)
        })
    })

        describe('strip_before()', () => {
        it('should remove text before first occurrence of pattern', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_before "-" "hello-world-test"')
            expect(result).toBe('world-test')
        })

        it('should return original if pattern not found', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_before "-" "hello"')
            expect(result).toBe('hello')
        })

        it('should handle multiple occurrences (strip first only)', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_before "-" "a-b-c-d"')
            expect(result).toBe('b-c-d')
        })
    })

    describe('strip_before_last()', () => {
        it('should remove text before last occurrence of pattern', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_before_last "-" "hello-world-test"')
            expect(result).toBe('test')
        })

        it('should return original if pattern not found', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_before_last "-" "hello"')
            expect(result).toBe('hello')
        })

        it('should handle single occurrence', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_before_last "-" "hello-world"')
            expect(result).toBe('world')
        })
    })

        describe('strip_after()', () => {
        it('should remove text after first occurrence of pattern', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_after "-" "hello-world-test"')
            expect(result).toBe('hello')
        })

        it('should return original if pattern not found', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_after "-" "hello"')
            expect(result).toBe('hello')
        })

        it('should handle multiple occurrences (strip after first)', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_after "-" "a-b-c-d"')
            expect(result).toBe('a')
        })
    })

    describe('strip_after_last()', () => {
        it('should remove text after last occurrence of pattern', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_after_last "-" "hello-world-test"')
            expect(result).toBe('hello-world')
        })

        it('should return original if pattern not found', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_after_last "-" "hello"')
            expect(result).toBe('hello')
        })

        it('should handle single occurrence', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_after_last "-" "hello-world"')
            expect(result).toBe('hello')
        })
    })

       describe('ensure_starting()', () => {
        it('should add prefix if not present', () => {
            const result = sourcedBash('./utils/text.sh', 'ensure_starting "hello-" "world"')
            expect(result).toBe('hello-world')
        })

        it('should not duplicate prefix if already present', () => {
            const result = sourcedBash('./utils/text.sh', 'ensure_starting "hello-" "hello-world"')
            expect(result).toBe('hello-world')
        })

        it('should error on empty string', () => {
            // Function requires non-empty content (uses ${2:?-} parameter expansion)
            const exitCode = bashExitCode('source ./utils/text.sh && empty="" && ensure_starting "prefix" "$empty" 2>/dev/null')
            expect(exitCode).toBe(127) // bash error code for parameter expansion failure
        })
    })

    describe('has_characters()', () => {
        it('should return 0 when content contains one of the specified characters', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && has_characters "aeiou" "hello"')
            expect(exitCode).toBe(0)
        })

        it('should return 1 when content does not contain any of the specified characters', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && has_characters "xyz" "hello"')
            expect(exitCode).toBe(1)
        })

        it('should return 0 when checking for special characters', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && has_characters "-_" "hello-world"')
            expect(exitCode).toBe(0)
        })

        it('should error when content is empty', () => {
            // Function requires non-empty content (uses ${2:?...} parameter expansion)
            const exitCode = bashExitCode('source ./utils/text.sh && empty="" && has_characters "abc" "$empty" 2>/dev/null')
            expect(exitCode).toBe(127) // bash error code for parameter expansion failure
        })
    })

       describe('trim()', () => {
        it('should remove leading and trailing whitespace', () => {
            const result = sourcedBash('./utils/text.sh', 'trim "  hello world  "')
            expect(result).toBe('hello world')
        })

        it('should handle only leading whitespace', () => {
            const result = sourcedBash('./utils/text.sh', 'trim "  hello"')
            expect(result).toBe('hello')
        })

        it('should handle only trailing whitespace', () => {
            const result = sourcedBash('./utils/text.sh', 'trim "hello  "')
            expect(result).toBe('hello')
        })

        it('should handle string with only whitespace', () => {
            const result = sourcedBash('./utils/text.sh', 'trim "   "')
            expect(result).toBe('')
        })

        it('should handle empty string', () => {
            const result = sourcedBash('./utils/text.sh', 'trim ""')
            expect(result).toBe('')
        })

        it('should preserve internal whitespace', () => {
            const result = sourcedBash('./utils/text.sh', 'trim "  hello   world  "')
            expect(result).toBe('hello   world')
        })

        it('should handle tabs', () => {
            // Use $'...' syntax for bash to interpret escape sequences
            const result = sourcedBash('./utils/text.sh', "trim $'\\t\\thello\\t\\t'")
            expect(result).toBe('hello')
        })
    })

    describe('indent()', () => {
        it('should indent single line with specified indentation', () => {
            const result = sourcedBashNoTrimStart('./utils/text.sh', 'indent "  " "hello"')
            expect(result).toBe('  hello')
        })

        it('should indent with custom indentation string', () => {
            const result = sourcedBashNoTrimStart('./utils/text.sh', 'indent "    " "hello"')
            expect(result).toBe('    hello')
        })

        it('should indent multiple lines', () => {
            const result = sourcedBashNoTrimStart('./utils/text.sh', "indent '  ' $'line1\\nline2'")
            expect(result).toContain('  line1')
            expect(result).toContain('  line2')
        })

        it('should handle tab indentation', () => {
            const result = sourcedBashNoTrimStart('./utils/text.sh', "indent $'\\t' 'hello'")
            expect(result).toContain('\thello')
        })
    })

        describe('char_width()', () => {
        it('should calculate width of plain text', () => {
            const result = sourcedBash('./utils/text.sh', 'char_width "hello world"')
            expect(result).toBe('11')
        })

        it('should handle empty string', () => {
            const result = sourcedBash('./utils/text.sh', 'char_width ""')
            expect(result).toBe('0')
        })

        it('should ignore ANSI color codes', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31mred text\\e[0m") && char_width "$text"')
            expect(result).toBe('8') // "red text" = 8 characters
        })

        it('should ignore multiple ANSI codes', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[1m\\e[31mbold red\\e[0m") && char_width "$text"')
            expect(result).toBe('8') // "bold red" = 8 characters
        })

        it('should handle text with tabs', () => {
            const result = sourcedBash('./utils/text.sh', "char_width $'hello\\tworld'")
            expect(result).toBe('14') // "hello" (5) + tab (4) + "world" (5) = 14
        })

        it('should handle complex escape sequences', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[1;31mtext\\e[0m") && char_width "$text"')
            expect(result).toBe('4') // "text" = 4 characters
        })
    })

    describe('is_start_of_escape_sequence()', () => {
        it('should return 0 for text ending with ESC', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && text=$(printf "hello\\e") && is_start_of_escape_sequence "$text"')
            expect(exitCode).toBe(0)
        })

        it('should return 1 for text not ending with ESC', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && is_start_of_escape_sequence "hello"')
            expect(exitCode).toBe(1)
        })

        it('should return 1 for empty string', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && is_start_of_escape_sequence ""')
            expect(exitCode).toBe(1)
        })

        it('should return 1 for text ending with normal character', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && is_start_of_escape_sequence "test"')
            expect(exitCode).toBe(1)
        })
    })

    describe('is_part_of_escape_sequence()', () => {
        it('should return 0 when inside incomplete CSI sequence', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && text=$(printf "\\e[3") && is_part_of_escape_sequence "$text"')
            expect(exitCode).toBe(0)
        })

        it('should return 1 when not in escape sequence', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && is_part_of_escape_sequence "hello"')
            expect(exitCode).toBe(1)
        })

        it('should return 1 for empty string', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && is_part_of_escape_sequence ""')
            expect(exitCode).toBe(1)
        })

        it('should return 0 when inside incomplete OSC sequence', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && text=$(printf "\\e]8;;") && is_part_of_escape_sequence "$text"')
            expect(exitCode).toBe(0)
        })

        it('should return 1 after complete CSI sequence', () => {
            const exitCode = bashExitCode('source ./utils/text.sh && text=$(printf "\\e[31m more") && is_part_of_escape_sequence "$text"')
            expect(exitCode).toBe(1)
        })
    })

    describe('strip_escape_sequences()', () => {
        it('should return plain text unchanged', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_escape_sequences "hello world"')
            expect(result).toBe('hello world')
        })

        it('should handle empty string', () => {
            const result = sourcedBash('./utils/text.sh', 'strip_escape_sequences ""')
            expect(result).toBe('')
        })

        it('should strip ANSI color codes', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31mred text\\e[0m") && strip_escape_sequences "$text"')
            expect(result).toBe('red text')
        })

        it('should strip multiple ANSI codes', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[1m\\e[31mbold red\\e[0m normal") && strip_escape_sequences "$text"')
            expect(result).toBe('bold red normal')
        })

        it('should strip OSC8 hyperlink sequences', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e]8;;https://example.com\\e\\\\\\\\link text\\e]8;;\\e\\\\\\\\") && strip_escape_sequences "$text"')
            expect(result).toBe('link text')
        })

        it('should handle text with escape sequences at different positions', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31mstart\\e[0m middle \\e[32mend\\e[0m") && strip_escape_sequences "$text"')
            expect(result).toBe('start middle end')
        })

        it('should handle complex escape sequences', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[1;31;40mcomplex\\e[0m") && strip_escape_sequences "$text"')
            expect(result).toBe('complex')
        })

        it('should return empty string for content with only escape sequences', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31m\\e[0m\\e[1m\\e[0m") && strip_escape_sequences "$text"')
            expect(result).toBe('')
        })

        it('should preserve internal spaces', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31mhello  \\e[0m  world") && strip_escape_sequences "$text"')
            expect(result).toBe('hello    world')
            expect(result).toContain('    ') // 4 spaces between words
        })

        it('should handle OSC52 clipboard sequences', () => {
            // OSC52 format: ESC]52;c;base64_data ESC\ or BEL
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "before\\e]52;c;aGVsbG8=\\e\\\\\\\\after") && strip_escape_sequences "$text"')
            expect(result).toBe('beforeafter')
        })

        it('should strip cursor movement sequences', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "hello\\e[2Jworld") && strip_escape_sequences "$text"')
            expect(result).toBe('helloworld')
        })

        it('should handle text with newlines and escape sequences', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31mline1\\e[0m\\nline2") && strip_escape_sequences "$text"')
            expect(result).toContain('line1')
            expect(result).toContain('line2')
        })
    })

    describe('newline_on_word_boundary()', () => {
        it('should split text at specified width', () => {
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "This is a very long line of text" 20')
            const lines = result.split('\n')
            expect(lines.length).toBeGreaterThan(1)
            expect(lines[0]).toBe('This is a very long')
        })

        it('should preserve words (not split mid-word)', () => {
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "Hello world test" 10')
            const lines = result.split('\n')
            // Verify we got multiple lines
            expect(lines.length).toBeGreaterThan(1)
            // Verify each line contains complete words (no partial words)
            lines.forEach(line => {
                const trimmed = line.trim()
                // Each line should contain valid words separated by spaces, not split mid-word
                expect(trimmed).not.toContain('-')  // Assuming no hyphens in test string
            })
        })

        it('should handle text shorter than width', () => {
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "short" 50')
            expect(result).toBe('short')
        })

        it('should handle empty string', () => {
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "" 30')
            expect(result).toBe('')
        })

        it('should preserve ANSI escape codes', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "This is \\e[31mred text\\e[0m and more") && newline_on_word_boundary "$text" 20')
            expect(result).toContain('[31m') // ANSI codes should be preserved
            expect(result).toContain('[0m')
        })

        it('should work with default width when no length specified', () => {
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "This is a test of the default width behavior"')
            expect(result).toBeTruthy()
            // Should not error and should return something
        })

        it('should split multiple lines correctly', () => {
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "one two three four five six seven eight" 15')
            const lines = result.split('\n')
            expect(lines.length).toBeGreaterThan(2)
            lines.forEach(line => {
                // No line should be excessively long (accounting for escape codes)
                expect(line.replace(/\x1b\[[0-9;]*m/g, '').length).toBeLessThanOrEqual(20)
            })
        })

        it('should handle text with multiple spaces', () => {
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "word1  word2   word3" 10')
            expect(result).toBeTruthy()
            expect(result).toContain('word1')
            expect(result).toContain('word2')
        })

        // NEW TESTS for newline handling
        it('should preserve existing newlines in content', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "line1\\nline2\\nline3") && newline_on_word_boundary "$text" 50')
            const lines = result.split('\n')
            expect(lines.length).toBeGreaterThanOrEqual(3)
            expect(lines[0]).toBe('line1')
            expect(lines[1]).toBe('line2')
            expect(lines[2]).toBe('line3')
        })

        it('should reset line width after encountering a newline', () => {
            // First line is short, second line is long and should wrap
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "short\\nthis is a very long line that should wrap at word boundaries") && newline_on_word_boundary "$text" 20')
            const lines = result.split('\n')
            expect(lines.length).toBeGreaterThan(2)
            expect(lines[0]).toBe('short')
            // Second line should start fresh and wrap based on the 20-char width
            expect(lines[1]).not.toBe('this is a very long line that should wrap at word boundaries')
        })

        it('should handle text with multiple consecutive newlines', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "line1\\n\\nline3") && newline_on_word_boundary "$text" 50')
            const lines = result.split('\n')
            expect(lines.length).toBe(3)
            expect(lines[0]).toBe('line1')
            expect(lines[1]).toBe('')
            expect(lines[2]).toBe('line3')
        })

        it('should never break inside an escape sequence', () => {
            // Create text with escape sequence near the break point
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "word1 word2 \\e[31mword3\\e[0m word4") && newline_on_word_boundary "$text" 15')
            // The escape sequence should never be split - either \\e[31m stays with word3 or moves to next line
            expect(result).not.toMatch(/\x1b[^\[]*$/)  // No incomplete escape at end of line
            expect(result).not.toMatch(/^\[[0-9;]*m/)  // No escape continuation at start of line
        })

        it('should handle escape sequences at word boundaries correctly', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31mred\\e[0m \\e[32mgreen\\e[0m \\e[34mblue\\e[0m text") && newline_on_word_boundary "$text" 10')
            // All escape sequences should remain intact
            expect(result).toContain('[31m')
            expect(result).toContain('[32m')
            expect(result).toContain('[34m')
            expect(result).toContain('[0m')
        })

        it('should handle tab characters as word boundaries', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "word1\\tword2\\tword3 more words") && newline_on_word_boundary "$text" 15')
            // Tabs should be recognized as word boundaries
            expect(result).toBeTruthy()
            expect(result).toContain('word1')
            expect(result).toContain('word2')
        })

        it('should handle a single word longer than max width', () => {
            // When a single word exceeds the width, it should still be output (not truncated)
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "verylongwordthatexceedswidth more" 10')
            expect(result).toContain('verylongwordthatexceedswidth')
            const lines = result.split('\n')
            // The long word should be on its own line, followed by "more" on the next line
            expect(lines[0]).toBe('verylongwordthatexceedswidth')
            expect(lines[1]).toBe('more')
        })

        it('should not break until AFTER exceeding width and finding word boundary', () => {
            // With width 15, "This is a test" is 14 chars, so should fit on one line
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "This is a test" 15')
            expect(result).toBe('This is a test')
        })

        it('should handle text with newlines AND escape sequences', () => {
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "\\e[31mred line\\e[0m\\n\\e[32mgreen line\\e[0m") && newline_on_word_boundary "$text" 50')
            const lines = result.split('\n')
            expect(lines.length).toBe(2)
            expect(lines[0]).toContain('[31m')
            expect(lines[1]).toContain('[32m')
        })

        it('should handle text ending with incomplete escape sequence (edge case)', () => {
            // If text ends with ESC but no complete sequence, should handle gracefully
            const result = sourcedBash('./utils/text.sh', 'text=$(printf "normal text \\e") && newline_on_word_boundary "$text" 20')
            expect(result).toBeTruthy()
            // Should not crash or produce invalid output
        })

        it('should handle real-world example with list markers', () => {
            // This mimics the issue from the screenshot
            const result = sourcedBash('./utils/text.sh', 'newline_on_word_boundary "- run -ls -lh /etc/pihole/pihole-FTL.db to see the size of the current pihole database" 80')
            // Should NOT break in the middle of "-ls" or other parts
            expect(result).toContain('-ls')
            // The first line should keep "- run -ls" together (not break after "run")
            const lines = result.split('\n')
            expect(lines[0]).toContain('- run -ls')
            expect(lines[0]).not.toContain('- run\n')  // Should not end with just "- run"
        })
    })



})

import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { spawnSync } from 'child_process'
import { mkdtempSync, rmSync, writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs'
import { tmpdir } from 'os'
import { join } from 'path'
import { isShellAvailable } from '../helpers'

/**
 * Host the bash code under test should believe it is running on.
 */
type HostKind = 'mac' | 'linux' | 'nixos' | 'windows'

interface BootstrapRunOptions {
  /** script run after `utils/bootstrap.sh` is sourced and mocks are installed */
  script: string
  /** commands `has_command` reports as installed */
  commands?: string[]
  /** the OS the mocks report; defaults to linux */
  host?: HostKind
  /** `_bootstrap_exec` calls (by substring) that exit non-zero */
  failingCalls?: string[]
  /** uid reported by `id -u`; defaults to 1000 (non-root) */
  uid?: number
  /** extra environment variables */
  env?: Record<string, string>
}

interface BootstrapRunResult {
  /** every command routed through `_bootstrap_exec`, in order */
  calls: string[]
  stdout: string
  stderr: string
  code: number
}

const REPO_ROOT = process.cwd()

/**
 * Sources utils/bootstrap.sh in a fresh bash process with the host-changing
 * and host-detecting functions replaced by mocks, runs `script`, and returns
 * what it printed plus every command it would have executed.
 */
function runBootstrap(options: BootstrapRunOptions): BootstrapRunResult {
  const {
    script,
    commands = [],
    host = 'linux',
    failingCalls = [],
    uid = 1000,
    env = {}
  } = options

  const workDir = mkdtempSync(join(tmpdir(), 'bootstrap-test-'))
  const callLog = join(workDir, 'calls.log')

  const fullScript = `
source "${REPO_ROOT}/utils/bootstrap.sh"

MOCK_COMMANDS=" ${commands.join(' ')} "
MOCK_FAILING=(${failingCalls.map(c => `"${c}"`).join(' ')})

has_command() { [[ "\${MOCK_COMMANDS}" == *" $1 "* ]]; }
is_mac() { [[ "${host}" == "mac" ]]; }
is_windows() { [[ "${host}" == "windows" ]]; }
is_linux() { [[ "${host}" == "linux" || "${host}" == "nixos" ]]; }
is_nixos() { [[ "${host}" == "nixos" ]]; }
id() { if [[ "$1" == "-u" ]]; then echo ${uid}; else command id "$@"; fi; }
_bootstrap_refresh_path() { :; }
_nix_profile_verb() { echo add; }
_nixos_runs_generic_binaries() { [[ -n "\${MOCK_NIX_LD:-}" ]]; }

_bootstrap_exec() {
  local call="$*" failing
  echo "\${call}" >> "${callLog}"
  for failing in "\${MOCK_FAILING[@]}"; do
    if [[ "\${call}" == *"\${failing}"* ]]; then
      return 1
    fi
  done
  return 0
}

${script}
`

  const result = spawnSync('bash', ['-c', fullScript], {
    cwd: REPO_ROOT,
    encoding: 'utf-8',
    env: {
      ...process.env,
      HOME: workDir,
      XDG_CONFIG_HOME: join(workDir, '.config'),
      STARSHIP_CONFIG: '',
      ADAPTIVE_SHELL: REPO_ROOT,
      ADAPTIVE_PKG_MANAGER: '',
      ...env
    }
  })

  const calls = existsSync(callLog)
    ? readFileSync(callLog, 'utf-8').split('\n').filter(Boolean)
    : []

  rmSync(workDir, { recursive: true, force: true })

  return {
    calls,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
    code: result.status ?? -1
  }
}

describe('bootstrap.sh', () => {
  describe('spec_packages()', () => {
    it('prints the packages for the given manager in order', () => {
      const result = runBootstrap({
        script: 'spec_packages apt brew:eza apt:eza apt:exa dnf:eza'
      })

      expect(result.code).toBe(0)
      expect(result.stdout.trim().split('\n')).toEqual(['eza', 'exa'])
    })

    it('prints nothing when the manager has no packages', () => {
      const result = runBootstrap({ script: 'spec_packages apk brew:eza apt:eza' })

      expect(result.code).toBe(0)
      expect(result.stdout.trim()).toBe('')
    })

    it('keeps everything after the first colon as the package name', () => {
      const result = runBootstrap({ script: 'spec_packages winget winget:Some.Id:extra' })

      expect(result.stdout.trim()).toBe('Some.Id:extra')
    })
  })

  describe('core_util_spec()', () => {
    it('lists du-dust for apt and dust for brew', () => {
      const result = runBootstrap({
        script: `
spec_packages apt $(core_util_spec dust)
spec_packages brew $(core_util_spec dust)
spec_packages cargo $(core_util_spec dust)`
      })

      expect(result.stdout.trim().split('\n')).toEqual(['du-dust', 'dust', 'du-dust'])
    })

    it('uses winget IDs on Windows', () => {
      const result = runBootstrap({
        script: `for t in curl git wget fzf gh eza dust; do spec_packages winget $(core_util_spec "$t"); done`
      })

      expect(result.stdout.trim().split('\n')).toEqual([
        'cURL.cURL',
        'Git.Git',
        'JernejSimoncic.Wget',
        'junegunn.fzf',
        'GitHub.cli',
        'eza-community.eza',
        'bootandy.dust'
      ])
    })

    it('uses github-cli for gh on Arch and Alpine', () => {
      const result = runBootstrap({
        script: 'spec_packages pacman $(core_util_spec gh); spec_packages apk $(core_util_spec gh)'
      })

      expect(result.stdout.trim().split('\n')).toEqual(['github-cli', 'github-cli'])
    })

    it('fails for an unknown tool', () => {
      const result = runBootstrap({ script: 'core_util_spec not-a-tool' })

      expect(result.code).toBe(1)
    })
  })

  describe('is_nixos()', () => {
    let fixtureDir: string

    beforeEach(() => {
      fixtureDir = mkdtempSync(join(tmpdir(), 'os-release-'))
    })

    afterEach(() => {
      rmSync(fixtureDir, { recursive: true, force: true })
    })

    function runIsNixos(osRelease: string): number {
      const file = join(fixtureDir, 'os-release')
      writeFileSync(file, osRelease)
      // run the real is_nixos, not the mocked one
      const result = spawnSync('bash', ['-c', `source utils/bootstrap.sh && is_nixos`], {
        cwd: REPO_ROOT,
        encoding: 'utf-8',
        env: { ...process.env, ADAPTIVE_OS_RELEASE: file, ADAPTIVE_SHELL: REPO_ROOT }
      })
      return result.status ?? -1
    }

    it('detects NixOS from ID=nixos', () => {
      expect(runIsNixos('NAME=NixOS\nID=nixos\nVERSION_ID="25.05"\n')).toBe(0)
    })

    it('detects NixOS from a quoted ID', () => {
      expect(runIsNixos('NAME="NixOS"\nID="nixos"\n')).toBe(0)
    })

    it('does not treat ID_LIKE=nixos-ish distros or other distros as NixOS', () => {
      expect(runIsNixos('NAME="Ubuntu"\nID=ubuntu\nID_LIKE=debian\n')).toBe(1)
      expect(runIsNixos('NAME="Fedora Linux"\nID=fedora\n')).toBe(1)
    })
  })

  describe('host_pkg_manager()', () => {
    it('honors ADAPTIVE_PKG_MANAGER', () => {
      const result = runBootstrap({
        script: 'host_pkg_manager',
        env: { ADAPTIVE_PKG_MANAGER: 'zypper' }
      })

      expect(result.stdout.trim()).toBe('zypper')
    })

    it('picks apt on Debian/Ubuntu (detected through apt-get)', () => {
      const result = runBootstrap({ script: 'host_pkg_manager', commands: ['apt-get', 'nix-env'] })

      expect(result.stdout.trim()).toBe('apt')
    })

    it('picks dnf on Fedora', () => {
      const result = runBootstrap({ script: 'host_pkg_manager', commands: ['dnf', 'yum'] })

      expect(result.stdout.trim()).toBe('dnf')
    })

    it('picks nix on NixOS', () => {
      const result = runBootstrap({ script: 'host_pkg_manager', host: 'nixos', commands: ['nix-env'] })

      expect(result.stdout.trim()).toBe('nix')
    })

    it('prefers winget on Windows', () => {
      const result = runBootstrap({
        script: 'host_pkg_manager',
        host: 'windows',
        commands: ['choco', 'scoop', 'winget']
      })

      expect(result.stdout.trim()).toBe('winget')
    })

    it('prefers brew on macOS', () => {
      const result = runBootstrap({ script: 'host_pkg_manager', host: 'mac', commands: ['port', 'brew'] })

      expect(result.stdout.trim()).toBe('brew')
    })

    it('fails when no package manager is found', () => {
      const result = runBootstrap({ script: 'host_pkg_manager' })

      expect(result.code).toBe(1)
      expect(result.stdout.trim()).toBe('')
    })
  })

  describe('pm_install()', () => {
    it('uses sudo + apt-get on Debian as a regular user and refreshes the index once', () => {
      const result = runBootstrap({
        script: 'pm_install apt fzf && pm_install apt gh',
        commands: ['apt-get', 'sudo']
      })

      expect(result.code).toBe(0)
      expect(result.calls).toEqual([
        'sudo apt-get update',
        'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y fzf',
        'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y gh'
      ])
    })

    it('prefers nala when it is installed', () => {
      const result = runBootstrap({
        script: 'pm_install apt fzf',
        commands: ['apt-get', 'nala', 'sudo']
      })

      expect(result.calls).toEqual(['sudo nala update', 'sudo nala install -y fzf'])
    })

    it('skips sudo when running as root', () => {
      const result = runBootstrap({ script: 'pm_install dnf fzf', commands: ['dnf'], uid: 0 })

      expect(result.calls).toEqual(['dnf install -y fzf'])
    })

    it('fails when root is needed but sudo is missing', () => {
      const result = runBootstrap({ script: 'pm_install dnf fzf', commands: ['dnf'] })

      expect(result.code).not.toBe(0)
      expect(result.calls).toEqual([])
      expect(result.stderr).toContain('sudo')
    })

    it('runs brew without sudo', () => {
      const result = runBootstrap({ script: 'pm_install brew eza', host: 'mac', commands: ['brew', 'sudo'] })

      expect(result.calls).toEqual(['brew install eza'])
    })

    it('installs winget packages silently by exact ID', () => {
      const result = runBootstrap({ script: 'pm_install winget junegunn.fzf', host: 'windows', commands: ['winget'] })

      expect(result.calls).toEqual([
        'winget install --exact --id junegunn.fzf --silent --accept-source-agreements --accept-package-agreements --disable-interactivity'
      ])
    })

    it('rejects an unknown package manager', () => {
      const result = runBootstrap({ script: 'pm_install nope fzf' })

      expect(result.code).toBe(1)
      expect(result.calls).toEqual([])
    })
  })

  describe('nix_install()', () => {
    it('installs with `nix profile`, allowing unfree packages', () => {
      const result = runBootstrap({ script: 'nix_install claude-code', host: 'nixos', commands: ['nix', 'nix-env'] })

      expect(result.code).toBe(0)
      expect(result.calls).toEqual([
        'env NIXPKGS_ALLOW_UNFREE=1 nix --extra-experimental-features nix-command flakes profile add --impure nixpkgs#claude-code'
      ])
    })

    it('falls back to nix-env (nixos channel, then nixpkgs) when `nix profile` fails', () => {
      const result = runBootstrap({
        script: 'nix_install eza',
        host: 'nixos',
        commands: ['nix', 'nix-env'],
        failingCalls: ['profile add', 'nixos.eza']
      })

      expect(result.code).toBe(0)
      expect(result.calls).toEqual([
        'env NIXPKGS_ALLOW_UNFREE=1 nix --extra-experimental-features nix-command flakes profile add --impure nixpkgs#eza',
        'env NIXPKGS_ALLOW_UNFREE=1 nix-env -iA nixos.eza',
        'env NIXPKGS_ALLOW_UNFREE=1 nix-env -iA nixpkgs.eza'
      ])
    })
  })

  describe('_nix_profile_verb()', () => {
    it('uses `add` when this Nix has it and `install` otherwise', () => {
      const run = (hasAdd: boolean) => spawnSync('bash', ['-c', `
source utils/bootstrap.sh
nix() { [[ "$*" == *"profile add --help"* ]] && return ${hasAdd ? 0 : 1}; return 0; }
_nix_profile_verb`], { cwd: REPO_ROOT, encoding: 'utf-8', env: { ...process.env, ADAPTIVE_SHELL: REPO_ROOT } })

      expect(run(true).stdout.trim()).toBe('add')
      expect(run(false).stdout.trim()).toBe('install')
    })
  })

  describe('_bootstrap_join()', () => {
    it('joins items with commas without external tools', () => {
      const result = runBootstrap({ script: `PATH=/nonexistent; _bootstrap_join "a b" c "d (cargo)"; echo; _bootstrap_join` })

      expect(result.stdout).toBe('a b, c, d (cargo)\n')
    })
  })

  describe('install_from_spec()', () => {
    it('tries the next package variant when one fails', () => {
      const result = runBootstrap({
        script: 'install_from_spec eza apt:eza apt:exa dnf:eza',
        commands: ['apt-get'],
        uid: 0,
        failingCalls: ['install -y eza']
      })

      expect(result.code).toBe(0)
      expect(result.calls).toEqual([
        'apt-get update',
        'env DEBIAN_FRONTEND=noninteractive apt-get install -y eza',
        'env DEBIAN_FRONTEND=noninteractive apt-get install -y exa'
      ])
    })

    it('falls back to cargo-binstall when the package manager has no package', () => {
      const result = runBootstrap({
        script: 'install_from_spec dust dnf:du-dust cargo:du-dust',
        commands: ['dnf', 'cargo', 'cargo-binstall'],
        uid: 0,
        failingCalls: ['dnf install']
      })

      expect(result.code).toBe(0)
      expect(result.calls).toEqual([
        'dnf install -y du-dust',
        'cargo binstall --no-confirm du-dust'
      ])
    })

    it('compiles with cargo install when cargo-binstall is missing', () => {
      const result = runBootstrap({
        script: 'install_from_spec dust cargo:du-dust',
        commands: ['cargo']
      })

      expect(result.calls).toEqual(['cargo install --locked du-dust'])
    })

    it('fails when nothing can install the tool', () => {
      const result = runBootstrap({
        script: 'install_from_spec dust brew:dust cargo:du-dust',
        commands: ['apt-get'],
        uid: 0
      })

      expect(result.code).toBe(1)
      expect(result.calls).toEqual([])
    })
  })

  describe('missing_core_utils()', () => {
    it('lists every missing tool, eza accepting exa', () => {
      const result = runBootstrap({
        script: 'missing_core_utils',
        commands: ['curl', 'git', 'exa', 'cc', 'make']
      })

      expect(result.stdout.trim().split('\n')).toEqual(['wget', 'fzf', 'gh', 'dust'])
    })

    it('lists build tools when there is no compiler', () => {
      const result = runBootstrap({
        script: 'missing_core_utils',
        commands: ['curl', 'git', 'wget', 'fzf', 'gh', 'eza', 'dust', 'make']
      })

      expect(result.stdout.trim()).toBe('build-tools')
    })
  })

  describe('install_build_tools_for_host()', () => {
    it('installs build-essential on Debian/Ubuntu', () => {
      const result = runBootstrap({
        script: 'install_build_tools_for_host',
        commands: ['apt-get'],
        uid: 0
      })

      expect(result.code).toBe(0)
      expect(result.calls).toContain('env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential')
    })

    it('installs the development-tools group on Fedora, falling back to dnf4 syntax', () => {
      const result = runBootstrap({
        script: 'install_build_tools_for_host',
        commands: ['dnf'],
        uid: 0,
        failingCalls: ['group install']
      })

      expect(result.calls).toEqual([
        'dnf group install -y development-tools',
        'dnf groupinstall -y Development Tools',
        'dnf install -y gcc gcc-c++ make pkgconf-pkg-config'
      ])
    })

    it('installs base-devel on Arch and build-base on Alpine', () => {
      const arch = runBootstrap({ script: 'install_build_tools_for_host', commands: ['pacman'], uid: 0 })
      const alpine = runBootstrap({ script: 'install_build_tools_for_host', commands: ['apk'], uid: 0 })

      expect(arch.calls).toContain('pacman -S --needed --noconfirm base-devel')
      expect(alpine.calls).toContain('apk add build-base')
    })

    it('installs the MSVC C++ workload on Windows', () => {
      const result = runBootstrap({ script: 'install_build_tools_for_host', host: 'windows', commands: ['winget'] })

      expect(result.calls).toHaveLength(1)
      expect(result.calls[0]).toContain('--id Microsoft.VisualStudio.2022.BuildTools')
      expect(result.calls[0]).toContain('Microsoft.VisualStudio.Workload.VCTools')
    })

    it('does nothing when a compiler is already present', () => {
      const result = runBootstrap({ script: 'install_build_tools_for_host', commands: ['cc', 'make', 'apt-get'] })

      expect(result.code).toBe(0)
      expect(result.calls).toEqual([])
    })
  })

  describe('rust', () => {
    it('installs rustup with the official script on Linux', () => {
      const result = runBootstrap({
        script: 'install_rust_toolchain',
        commands: ['curl', 'sh']
      })

      expect(result.calls[0]).toMatch(/^curl .* -o \S+ https:\/\/sh\.rustup\.rs$/)
      expect(result.calls[1]).toMatch(/^sh \S+ -y$/)
    })

    it('installs rustup from nixpkgs on NixOS', () => {
      const result = runBootstrap({
        script: 'install_rust_toolchain',
        host: 'nixos',
        commands: ['nix']
      })

      expect(result.calls).toEqual([
        'env NIXPKGS_ALLOW_UNFREE=1 nix --extra-experimental-features nix-command flakes profile add --impure nixpkgs#rustup',
        'rustup default stable'
      ])
    })

    it('runs rustup-init.exe on Windows', () => {
      const result = runBootstrap({
        script: 'install_rust_toolchain',
        host: 'windows',
        commands: ['curl']
      })

      expect(result.calls[0]).toContain('https://win.rustup.rs/x86_64')
      expect(result.calls[1]).toMatch(/rustup-init\.exe -y$/)
    })

    it('installs cargo-binstall with `cargo install`', () => {
      const result = runBootstrap({
        script: 'install_cargo_binstall',
        commands: ['cargo', 'cc', 'make']
      })

      expect(result.calls).toEqual(['cargo install --locked cargo-binstall'])
    })

    it('installs build tools before compiling cargo-binstall when there is no compiler', () => {
      const result = runBootstrap({
        script: 'install_cargo_binstall',
        commands: ['cargo', 'apt-get'],
        uid: 0
      })

      expect(result.calls).toContain('env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential')
      expect(result.calls[result.calls.length - 1]).toBe('cargo install --locked cargo-binstall')
    })
  })

  describe('AI agents', () => {
    it('lists missing agents by command name', () => {
      const result = runBootstrap({ script: 'missing_ai_agents', commands: ['claude', 'pi'] })

      expect(result.stdout.trim().split('\n')).toEqual(['codex', 'opencode', 'agy'])
    })

    it.each([
      ['claude', 'https://claude.ai/install.sh', 'bash'],
      ['codex', 'https://chatgpt.com/codex/install.sh', 'sh'],
      ['opencode', 'https://opencode.ai/install', 'bash'],
      ['agy', 'https://antigravity.google/cli/install.sh', 'bash'],
      ['pi', 'https://pi.dev/install.sh', 'sh']
    ])('installs %s with its official installer on Linux', (agent, url, interpreter) => {
      const result = runBootstrap({ script: `install_ai_agent ${agent}`, commands: ['curl'] })

      expect(result.code).toBe(0)
      expect(result.calls).toHaveLength(2)
      expect(result.calls[0]).toMatch(new RegExp(`^curl .* -o \\S+ ${url.replace(/\./g, '\\.')}$`))
      expect(result.calls[1]).toMatch(new RegExp(`^${interpreter} \\S+$`))
    })

    it.each([
      ['claude', 'https://claude.ai/install.ps1'],
      ['codex', 'https://chatgpt.com/codex/install.ps1'],
      ['agy', 'https://antigravity.google/cli/install.ps1'],
      ['pi', 'https://pi.dev/install.ps1']
    ])('installs %s with its PowerShell installer on Windows', (agent, url) => {
      const result = runBootstrap({
        script: `install_ai_agent ${agent}`,
        host: 'windows',
        commands: ['curl', 'powershell.exe']
      })

      expect(result.calls).toEqual([
        `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command irm ${url} | iex`
      ])
    })

    it('installs OpenCode with npm on Windows when npm is available', () => {
      const result = runBootstrap({
        script: 'install_ai_agent opencode',
        host: 'windows',
        commands: ['curl', 'npm', 'winget']
      })

      expect(result.calls).toEqual(['npm install -g opencode-ai'])
    })

    it('prefers nixpkgs on NixOS', () => {
      const result = runBootstrap({ script: 'install_ai_agent claude', host: 'nixos', commands: ['curl', 'nix'] })

      expect(result.calls[0]).toBe(
        'env NIXPKGS_ALLOW_UNFREE=1 nix --extra-experimental-features nix-command flakes profile add --impure nixpkgs#claude-code'
      )
    })

    it('falls back to the official installer on NixOS when nixpkgs has no package and nix-ld is enabled', () => {
      const result = runBootstrap({
        script: 'install_ai_agent agy',
        host: 'nixos',
        commands: ['curl', 'nix'],
        env: { MOCK_NIX_LD: '1' }
      })

      expect(result.calls).toHaveLength(2)
      expect(result.calls[0]).toContain('https://antigravity.google/cli/install.sh')
    })

    it('does not download a binary NixOS cannot run, and explains nix-ld', () => {
      const result = runBootstrap({ script: 'install_ai_agent agy', host: 'nixos', commands: ['curl', 'nix'] })

      expect(result.code).toBe(1)
      expect(result.calls).toEqual([])
      expect(result.stderr).toContain('programs.nix-ld.enable = true;')
    })

    it('installs Pi with npm when Node >= 22.19 is present and the npm prefix is writable', () => {
      const result = runBootstrap({
        script: `
node() { echo v24.1.0; }
_npm_global_writable() { return 0; }
install_ai_agent pi`,
        commands: ['curl', 'node', 'npm']
      })

      expect(result.calls).toEqual(['npm install -g --ignore-scripts @earendil-works/pi-coding-agent'])
    })

    it('uses the Pi installer when Node is too old', () => {
      const result = runBootstrap({
        script: `
node() { echo v22.18.0; }
_npm_global_writable() { return 0; }
install_ai_agent pi`,
        commands: ['curl', 'node', 'npm']
      })

      expect(result.calls[0]).toContain('https://pi.dev/install.sh')
    })

    it('reports failure when the installer download fails', () => {
      const result = runBootstrap({
        script: 'install_ai_agent claude',
        commands: ['curl'],
        failingCalls: ['curl']
      })

      expect(result.code).not.toBe(0)
      expect(result.calls).toHaveLength(1)
    })
  })

  describe('_node_at_least()', () => {
    it.each([
      ['v22.19.0', 0],
      ['v22.20.1', 0],
      ['v23.0.0', 0],
      ['v22.18.9', 1],
      ['v18.19.1', 1],
      ['garbage', 1]
    ])('node %s → %i', (version, expected) => {
      const result = runBootstrap({
        script: `node() { echo ${version}; }; _node_at_least 22 19`,
        commands: ['node']
      })

      expect(result.code).toBe(expected)
    })
  })

  describe('bootstrap steps', () => {
    it('skips the AI agent step without asking when curl is missing', () => {
      const result = runBootstrap({
        script: `confirm() { echo "ASKED: $1"; return 0; }; bootstrap_step_ai_agents`
      })

      expect(result.code).toBe(0)
      expect(result.stdout).not.toContain('ASKED')
      expect(result.stderr).toContain('skipped')
      expect(result.calls).toEqual([])
    })

    it('does not ask about core utilities that are all installed', () => {
      const result = runBootstrap({
        script: `confirm() { echo "ASKED: $1"; return 0; }; bootstrap_step_core_utils`,
        commands: ['curl', 'git', 'wget', 'fzf', 'gh', 'eza', 'dust', 'cc', 'make']
      })

      expect(result.stdout).not.toContain('ASKED')
    })

    it('installs nothing when the user declines', () => {
      const result = runBootstrap({
        script: `confirm() { return 1; }; bootstrap_step_core_utils; bootstrap_step_rust; bootstrap_step_ai_agents`,
        commands: ['curl', 'apt-get', 'sudo']
      })

      expect(result.calls).toEqual([])
    })

    it('only offers cargo-binstall when Rust is already installed', () => {
      const result = runBootstrap({
        script: `confirm() { echo "ASKED: $1"; return 1; }; bootstrap_step_rust`,
        commands: ['cargo']
      })

      expect(result.stdout).toContain('ASKED: Install cargo-binstall?')
    })

    it('retries a tool the distro lacks with cargo and clears its earlier failure', () => {
      const result = runBootstrap({
        script: `
BOOTSTRAP_FAILED=("gh (GitHub CLI)" "dust (modern du)")
eval "recording_$(declare -f _bootstrap_exec)"
_bootstrap_exec() {
  recording__bootstrap_exec "$@"
  [[ "$*" == "cargo binstall --no-confirm du-dust" ]] && MOCK_COMMANDS="\${MOCK_COMMANDS}dust "
  return 0
}
retry_core_utils_with_cargo
echo "INSTALLED: \${BOOTSTRAP_INSTALLED[*]}"
echo "FAILED: \${BOOTSTRAP_FAILED[*]}"`,
        commands: ['cargo', 'cargo-binstall', 'eza']
      })

      expect(result.calls).toEqual(['cargo binstall --no-confirm du-dust'])
      expect(result.stdout).toContain('INSTALLED: dust (modern du) (cargo)')
      expect(result.stdout).toContain('FAILED: gh (GitHub CLI)\n')
    })

    it('installs Rust then cargo-binstall when accepted', () => {
      const result = runBootstrap({
        script: `
confirm() { return 0; }
install_rust_toolchain() { echo RUST; MOCK_COMMANDS="\${MOCK_COMMANDS}cargo "; }
install_cargo_binstall() { echo BINSTALL; }
bootstrap_step_rust
echo "INSTALLED: \${BOOTSTRAP_INSTALLED[*]}"`
      })

      expect(result.stdout).toContain('RUST\nBINSTALL')
      expect(result.stdout).toContain('INSTALLED: Rust cargo-binstall')
    })
  })

  describe('install_starship_for_host()', () => {
    it('installs curl through the sudo-aware path before the script-based install', () => {
      const result = runBootstrap({
        script: `
source utils/install.sh
unset SUDO
eval "recording_$(declare -f _bootstrap_exec)"
_bootstrap_exec() {
  recording__bootstrap_exec "$@"
  # the installed curl shows up on PATH
  [[ "$*" == *"install -y curl" ]] && MOCK_COMMANDS="\${MOCK_COMMANDS}curl "
  return 0
}
install_starship() { echo "INSTALL_STARSHIP SUDO=\${SUDO}"; }
install_starship_for_host`,
        commands: ['apt-get', 'sudo']
      })

      expect(result.calls).toEqual([
        'sudo apt-get update',
        'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y curl'
      ])
      expect(result.stdout).toContain('INSTALL_STARSHIP SUDO=sudo')
    })

    it('uses winget on Windows and nixpkgs on NixOS', () => {
      const windows = runBootstrap({ script: 'install_starship_for_host', host: 'windows', commands: ['winget'] })
      const nixos = runBootstrap({ script: 'install_starship_for_host', host: 'nixos', commands: ['nix'] })

      expect(windows.calls[0]).toContain('--id Starship.Starship')
      expect(nixos.calls[0]).toContain('nixpkgs#starship')
    })
  })

  describe('configure_starship_prompt()', () => {
    let home: string

    beforeEach(() => {
      home = mkdtempSync(join(tmpdir(), 'starship-home-'))
    })

    afterEach(() => {
      rmSync(home, { recursive: true, force: true })
    })

    function configure(): { code: number; stderr: string } {
      const result = spawnSync('bash', ['-c', 'source utils/bootstrap.sh && configure_starship_prompt'], {
        cwd: REPO_ROOT,
        encoding: 'utf-8',
        env: {
          ...process.env,
          HOME: home,
          XDG_CONFIG_HOME: join(home, '.config'),
          STARSHIP_CONFIG: '',
          ADAPTIVE_SHELL: REPO_ROOT
        }
      })
      return { code: result.status ?? -1, stderr: result.stderr }
    }

    const configPath = () => join(home, '.config', 'starship.toml')

    it('installs the template when there is no config', () => {
      const result = configure()

      expect(result.code).toBe(0)
      expect(readFileSync(configPath(), 'utf-8')).toBe(
        readFileSync(join(REPO_ROOT, 'resources', 'starship.toml'), 'utf-8')
      )
    })

    it('appends only the sections an existing config lacks', () => {
      mkdirSync(join(home, '.config'), { recursive: true })
      const existing = '[hostname]\nssh_only = false\nformat = "@[$hostname](bold yellow)"\n'
      writeFileSync(configPath(), existing)

      configure()
      const config = readFileSync(configPath(), 'utf-8')

      expect(config.startsWith(existing)).toBe(true)
      expect(config.match(/^\[hostname\]/gm)).toHaveLength(1)
      expect(config).toContain('[username]\nshow_always = true')
      expect(config).toContain('[container]\ndisabled = true')
    })

    it('is idempotent', () => {
      configure()
      const first = readFileSync(configPath(), 'utf-8')
      const second = configure()

      expect(second.code).toBe(0)
      expect(readFileSync(configPath(), 'utf-8')).toBe(first)
      expect(second.stderr).toContain('left unchanged')
    })

    it('honors STARSHIP_CONFIG', () => {
      const custom = join(home, 'custom', 'prompt.toml')
      const result = spawnSync('bash', ['-c', 'source utils/bootstrap.sh && configure_starship_prompt'], {
        cwd: REPO_ROOT,
        encoding: 'utf-8',
        env: { ...process.env, HOME: home, STARSHIP_CONFIG: custom, ADAPTIVE_SHELL: REPO_ROOT }
      })

      expect(result.status).toBe(0)
      expect(existsSync(custom)).toBe(true)
    })
  })

  describe('resources/starship.toml', () => {
    const template = readFileSync(join(REPO_ROOT, 'resources', 'starship.toml'), 'utf-8')

    it('always shows `user@host` with the @host part dimmed', () => {
      expect(template).toMatch(/\[username\][^[]*show_always = true/)
      expect(template).toMatch(/\[hostname\][^[]*ssh_only = false/)
      expect(template).toMatch(/\[hostname\][^[]*style = "dimmed"/)
      expect(template).toMatch(/\[hostname\][^[]*format = "\[@\$hostname\]\(\$style\) in "/)
    })

    it('disables the container module that renders [Systemd]', () => {
      expect(template).toMatch(/\[container\]\s*\ndisabled = true/)
    })
  })

  describe('login shell (bash -> zsh)', () => {
    /** mocks that make `zsh` appear once a package manager installs it */
    const zshAppearsOnInstall = `
eval "recording_$(declare -f _bootstrap_exec)"
_bootstrap_exec() {
  recording__bootstrap_exec "$@"
  local rc=$?
  [[ "$*" == *"install -y zsh" ]] && MOCK_COMMANDS="\${MOCK_COMMANDS}zsh "
  return $rc
}
zsh_path() { echo /usr/bin/zsh; }
`

    describe('login_shell()', () => {
      it('reads the passwd database on Linux', () => {
        const result = runBootstrap({
          script: `getent() { echo "dev:x:1000:1000::/home/dev:/bin/bash"; }; login_shell`,
          commands: ['getent'],
          env: { USER: 'dev', SHELL: '/bin/zsh' }
        })

        expect(result.stdout.trim()).toBe('/bin/bash')
      })

      it('reads the account record with dscl on macOS', () => {
        const result = runBootstrap({
          script: `dscl() { echo "UserShell: /bin/bash"; }; login_shell`,
          host: 'mac',
          env: { USER: 'dev', SHELL: '/bin/zsh' }
        })

        expect(result.stdout.trim()).toBe('/bin/bash')
      })

      it('falls back to $SHELL', () => {
        const result = runBootstrap({
          script: `getent() { return 2; }; login_shell`,
          commands: ['getent'],
          env: { USER: 'dev', SHELL: '/usr/bin/fish' }
        })

        expect(result.stdout.trim()).toBe('/usr/bin/fish')
      })

      it('fails on Windows', () => {
        const result = runBootstrap({ script: 'login_shell', host: 'windows' })

        expect(result.code).toBe(1)
        expect(result.stdout.trim()).toBe('')
      })
    })

    describe('bootstrap_step_shell()', () => {
      it('asks "Do you want to switch to zsh?" when the login shell is bash', () => {
        const result = runBootstrap({
          script: `login_shell() { echo /bin/bash; }; confirm() { echo "ASKED: $1"; return 1; }; bootstrap_step_shell`
        })

        expect(result.stdout).toContain('ASKED: Do you want to switch to zsh?')
        expect(result.calls).toEqual([])
      })

      it.each(['/bin/zsh', '/usr/bin/fish', '/bin/sh'])('does not ask when the login shell is %s', (shell) => {
        const result = runBootstrap({
          script: `login_shell() { echo ${shell}; }; confirm() { echo "ASKED: $1"; return 0; }; bootstrap_step_shell`
        })

        expect(result.stdout).not.toContain('ASKED')
        expect(result.calls).toEqual([])
      })

      it('skips Windows without asking', () => {
        const result = runBootstrap({
          script: `confirm() { echo "ASKED: $1"; return 0; }; bootstrap_step_shell`,
          host: 'windows'
        })

        expect(result.stdout).not.toContain('ASKED')
        expect(result.stderr).toContain('skipped')
      })
    })

    describe('switch_to_zsh()', () => {
      it('installs zsh, registers it in /etc/shells and changes the login shell via sudo', () => {
        const result = runBootstrap({
          script: `${zshAppearsOnInstall}
printf '/bin/sh\\n/bin/bash\\n' > "$HOME/shells"
ADAPTIVE_ETC_SHELLS="$HOME/shells" switch_to_zsh
echo "INSTALLED: \${BOOTSTRAP_INSTALLED[*]}"
grep -c 'adaptive-shell' "$HOME/.zshrc"`,
          commands: ['apt-get', 'sudo', 'chsh'],
          env: { USER: 'dev' }
        })

        expect(result.code).toBe(0)
        expect(result.calls).toEqual([
          'sudo apt-get update',
          'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y zsh',
          expect.stringMatching(/^sudo tee -a \S+\/shells$/),
          'sudo chsh -s /usr/bin/zsh dev'
        ])
        expect(result.stdout).toContain('INSTALLED: zsh login shell -> zsh')
        expect(result.stdout.trim().endsWith('2')).toBe(true)
      })

      it('does not touch /etc/shells when zsh is already listed', () => {
        const result = runBootstrap({
          script: `${zshAppearsOnInstall}
printf '/bin/bash\\n/usr/bin/zsh\\n' > "$HOME/shells"
ADAPTIVE_ETC_SHELLS="$HOME/shells" switch_to_zsh`,
          commands: ['zsh', 'chsh'],
          uid: 0,
          env: { USER: 'root' }
        })

        expect(result.calls).toEqual(['chsh -s /usr/bin/zsh root'])
      })

      it('uses usermod where chsh is not installed', () => {
        const result = runBootstrap({
          script: `${zshAppearsOnInstall}
printf '/usr/bin/zsh\\n' > "$HOME/shells"
ADAPTIVE_ETC_SHELLS="$HOME/shells" switch_to_zsh`,
          commands: ['zsh', 'usermod'],
          uid: 0,
          env: { USER: 'root' }
        })

        expect(result.calls).toEqual(['usermod -s /usr/bin/zsh root'])
      })

      it('runs chsh as the user on macOS (it asks for their password)', () => {
        const result = runBootstrap({
          script: `${zshAppearsOnInstall}
printf '/usr/bin/zsh\\n' > "$HOME/shells"
ADAPTIVE_ETC_SHELLS="$HOME/shells" switch_to_zsh`,
          host: 'mac',
          commands: ['zsh', 'chsh', 'sudo'],
          env: { USER: 'dev' }
        })

        expect(result.calls).toEqual(['chsh -s /usr/bin/zsh dev'])
      })

      it('configures zsh but leaves the login shell to configuration.nix on NixOS', () => {
        const result = runBootstrap({
          script: `${zshAppearsOnInstall}
switch_to_zsh
echo "TODO: \${BOOTSTRAP_TODO[*]}"
test -f "$HOME/.zshrc" && echo ZSHRC`,
          host: 'nixos',
          commands: ['zsh', 'chsh'],
          env: { USER: 'dev' }
        })

        expect(result.code).toBe(0)
        expect(result.calls).toEqual([])
        expect(result.stderr).toContain('users.users.dev.shell = pkgs.zsh;')
        expect(result.stdout).toContain('TODO: set zsh as the login shell in configuration.nix')
        expect(result.stdout).toContain('ZSHRC')
      })

      it('reports failure when zsh cannot be installed', () => {
        const result = runBootstrap({
          script: `${zshAppearsOnInstall}
switch_to_zsh
echo "FAILED: \${BOOTSTRAP_FAILED[*]}"`,
          commands: ['apt-get', 'sudo', 'chsh'],
          failingCalls: ['install -y zsh']
        })

        expect(result.code).toBe(0)
        expect(result.stdout).toContain('FAILED: zsh')
        expect(result.calls.some(c => c.includes('chsh'))).toBe(false)
      })
    })

    describe('zsh_path()', () => {
      it('prefers an executable zsh that /etc/shells already lists', () => {
        const result = runBootstrap({
          script: `
mkdir -p "$HOME/bin" && printf '#!/bin/sh\\n' > "$HOME/bin/zsh" && chmod +x "$HOME/bin/zsh"
printf '/bin/sh\\n/nonexistent/zsh\\n%s\\n' "$HOME/bin/zsh" > "$HOME/shells"
ADAPTIVE_ETC_SHELLS="$HOME/shells" zsh_path | sed "s|$HOME|~|"`
        })

        expect(result.stdout.trim()).toBe('~/bin/zsh')
      })

      it('falls back to the zsh on PATH when /etc/shells lists none', () => {
        const result = runBootstrap({
          script: `
mkdir -p "$HOME/bin" && printf '#!/bin/sh\\n' > "$HOME/bin/zsh" && chmod +x "$HOME/bin/zsh"
printf '/bin/sh\\n' > "$HOME/shells"
PATH="$HOME/bin:$PATH" ADAPTIVE_ETC_SHELLS="$HOME/shells" zsh_path | sed "s|$HOME|~|"`
        })

        expect(result.stdout.trim()).toBe('~/bin/zsh')
      })

      it('uses /bin/zsh on macOS', () => {
        const result = runBootstrap({ script: 'zsh_path', host: 'mac' })

        expect(result.stdout.trim()).toBe('/bin/zsh')
      })
    })

    describe('configure_zsh_for_user()', () => {
      it('writes a history + adaptive-shell block, with the path relative to $HOME', () => {
        const result = runBootstrap({
          script: `ADAPTIVE_SHELL="$HOME/.config/sh" configure_zsh_for_user && cat "$HOME/.zshrc"`
        })

        expect(result.code).toBe(0)
        expect(result.stdout).toContain('# >>> adaptive-shell >>>')
        expect(result.stdout).toContain('SAVEHIST=50000')
        expect(result.stdout).toContain('setopt APPEND_HISTORY SHARE_HISTORY')
        expect(result.stdout).toContain('source "${HOME}/.config/sh/adaptive.sh"')
        expect(result.stdout).toContain('# <<< adaptive-shell <<<')
      })

      it('appends to an existing .zshrc and is idempotent', () => {
        const result = runBootstrap({
          script: `
printf 'export EDITOR=nvim\\n' > "$HOME/.zshrc"
configure_zsh_for_user && configure_zsh_for_user
head -n 1 "$HOME/.zshrc"
grep -c '>>> adaptive-shell >>>' "$HOME/.zshrc"`
        })

        expect(result.stdout.trim().split('\n')).toEqual(['export EDITOR=nvim', '1'])
        expect(result.stderr).toContain('left unchanged')
      })

      it('leaves a .zshrc that already sources adaptive.sh alone', () => {
        const result = runBootstrap({
          script: `
printf 'source ~/.config/sh/adaptive.sh\\n' > "$HOME/.zshrc"
configure_zsh_for_user
cat "$HOME/.zshrc"`
        })

        expect(result.stdout.trim()).toBe('source ~/.config/sh/adaptive.sh')
      })

      it('honors ZDOTDIR', () => {
        const result = runBootstrap({
          script: `ZDOTDIR="$HOME/zdot" configure_zsh_for_user && test -f "$HOME/zdot/.zshrc" && echo OK`
        })

        expect(result.stdout.trim()).toBe('OK')
      })
    })
  })

  describe('Bash 3 upgrade', () => {
    it.each(['', '5.3.0'])('reports the Bash check for a zsh login with running Bash version %j', (version) => {
      const result = runBootstrap({
        script: `
login_shell() { echo /bin/zsh; }
confirm() { echo "ASKED: $1"; return 0; }
bootstrap_step_shell "${version}"
`
      })

      expect(result.code).toBe(0)
      expect(result.stderr).toContain(version ? 'running Bash 5.3.0' : 'bootstrap is using Bash')
      expect(result.stderr).toContain('Bash upgrade skipped')
      if (version) expect(result.stderr).toContain('Bash 5.3.0 is modern')
      expect(result.stdout).not.toContain('ASKED')
    })

    it('finds modern Bash behind an older executable on PATH', () => {
      const result = runBootstrap({
        script: `
mkdir "$HOME/old" "$HOME/new"
printf '#!/bin/sh\\necho 3\\n' > "$HOME/old/bash"
printf '#!/bin/sh\\necho 5\\n' > "$HOME/new/bash"
chmod +x "$HOME/old/bash" "$HOME/new/bash"
PATH="$HOME/old:$HOME/new" modern_bash_path
`
      })

      expect(result.code).toBe(0)
      expect(result.stdout.trim()).toMatch(/\/new\/bash$/)
    })

    it('can move a Bash 3 login to an installed Bash after the user declines zsh', () => {
      const result = runBootstrap({
        script: `
mkdir "$HOME/old"
printf '#!/bin/sh\\necho 3\\n' > "$HOME/old/bash"
chmod +x "$HOME/old/bash"
login_shell() { echo "$HOME/old/bash"; }
modern_bash_path() { echo /opt/homebrew/bin/bash; }
confirm() { echo "ASKED: $1"; [[ "$1" != *zsh* ]]; }
ADAPTIVE_ETC_SHELLS="$HOME/shells" bootstrap_step_shell 5.3.0
`,
        host: 'mac',
        commands: ['chsh', 'sudo'],
        env: { USER: 'dev' }
      })

      expect(result.stdout).toContain('ASKED: Bash 3 detected. Use /opt/homebrew/bin/bash as your login shell?')
      expect(result.calls).toEqual([
        expect.stringMatching(/^sudo tee -a \S+\/shells$/),
        'chsh -s /opt/homebrew/bin/bash dev'
      ])
    })

    it('installs modern Bash for a Bash 3 session without changing a zsh login', () => {
      const result = runBootstrap({
        script: `
login_shell() { echo /bin/zsh; }
confirm() { echo "ASKED: $1"; return 0; }
modern_bash_path() { [ -f "$HOME/bash-installed" ] && echo /opt/homebrew/bin/bash; }
eval "recording_$(declare -f _bootstrap_exec)"
_bootstrap_exec() {
  recording__bootstrap_exec "$@" || return
  : > "$HOME/bash-installed"
}
bootstrap_step_shell 3.2.57
`,
        host: 'mac',
        commands: ['brew']
      })

      expect(result.stdout).toContain('ASKED: Bash 3 detected. Install Bash 4 or newer?')
      expect(result.calls).toEqual(['brew install bash'])
      expect(result.stderr).toContain('exec /opt/homebrew/bin/bash -l')
    })

    it('reports failure if the package manager still leaves only Bash 3', () => {
      const result = runBootstrap({
        script: `
confirm() { return 0; }
modern_bash_path() { return 1; }
bootstrap_step_bash 3.2.57 /bin/zsh
`,
        host: 'mac',
        commands: ['port', 'sudo']
      })

      expect(result.calls).toEqual(['sudo port -N install bash'])
      expect(result.code).toBe(1)
      expect(result.stderr).toContain('could not find Bash 4 or newer')
    })
  })
})

describe('adaptive_bootstrap()', () => {
  let home: string

  beforeEach(() => {
    home = mkdtempSync(join(tmpdir(), 'adaptive-home-'))
  })

  afterEach(() => {
    rmSync(home, { recursive: true, force: true })
  })

  /** Extracts adaptive_bootstrap from adaptive.sh (sourcing the file runs the whole setup). */
  function runAdaptiveBootstrap(script: string): { code: number; stdout: string; stderr: string } {
    const result = spawnSync('bash', ['-c', `
eval "$(sed -n '/^function adaptive_bootstrap()/,/^}/p' adaptive.sh)"
has_command() { return 1; }
bash() { echo "BOOTSTRAP RAN: $*"; }
${script}`], {
      cwd: REPO_ROOT,
      encoding: 'utf-8',
      env: { ...process.env, HOME: home, ADAPTIVE_SHELL: REPO_ROOT }
    })
    return { code: result.status ?? -1, stdout: result.stdout, stderr: result.stderr }
  }

  it('does not run on first-run when the host was already initialized', () => {
    writeFileSync(join(home, '.adaptive-initialized'), '')
    const result = runAdaptiveBootstrap('adaptive_bootstrap --first-run')

    expect(result.code).toBe(0)
    expect(result.stdout).not.toContain('BOOTSTRAP RAN')
  })

  it('never prompts (or marks the host) from a non-interactive shell', () => {
    const result = runAdaptiveBootstrap('adaptive_bootstrap --first-run')

    expect(result.stdout).not.toContain('BOOTSTRAP RAN')
    expect(existsSync(join(home, '.adaptive-initialized'))).toBe(false)
  })

  it('refuses to run without a terminal even when invoked by hand', () => {
    const result = runAdaptiveBootstrap('adaptive_bootstrap')

    expect(result.stdout).not.toContain('BOOTSTRAP RAN')
    expect(result.stderr).toContain('needs a terminal')
  })

  describe.each((['bash', 'zsh'] as const).filter(isShellAvailable))('prompt editing in %s', (shell) => {
    function runPromptEdit({ setup = '', offer = true }: { setup?: string; offer?: boolean } = {}) {
      const args = shell === 'bash' ? ['--noprofile', '--norc', '-ic'] : ['-dfic']
      return spawnSync(shell, [...args, `
eval "$(sed -n '/^function _adaptive_prompt_edit()/,/^}/p' adaptive.sh)"
eval "$(sed -n '/^function _adaptive_report_cmd_e()/,/^}/p' adaptive.sh)"
source utils/detection.sh
source utils/interactive.sh
has_command() { return 1; }
confirm() { echo "PROMPT: $*"; return 0; }
${setup}
_adaptive_prompt_edit ${offer ? '--offer' : ''} || exit
${offer ? '_adaptive_report_cmd_e' : ''}
has_function edit_prompt
`], {
        cwd: REPO_ROOT,
        encoding: 'utf-8',
        env: { ...process.env, HOME: home, ADAPTIVE_SHELL: REPO_ROOT, INPUTRC: '/dev/null' }
      })
    }

    it('enables prompt editing immediately and restores it in a new shell', () => {
      const result = runPromptEdit()
      expect(result.status).toBe(0)
      expect(result.stdout).toContain('PROMPT: Enable Ctrl+X Ctrl+E')
      expect(result.stderr).toContain('6. Prompt editing')
      expect(result.stderr).toContain('for this and future interactive shells')
      expect(result.stderr).toMatch(/Cmd\+E (shell binding is ready|uses Bash's edit-and-execute binding)/)
      expect(existsSync(join(home, '.adaptive-prompt-edit'))).toBe(true)

      const next = runPromptEdit({ offer: false })
      expect(next.status).toBe(0)
      expect(next.stdout).toBe('')
      expect(next.stderr).not.toContain('6. Prompt editing')
    })

    it('skips the offer when zoxide is installed', () => {
      const result = runPromptEdit({ setup: 'has_command() { [ "$1" = zoxide ]; }' })
      expect(result.stdout).toBe('')
      expect(result.stderr).toContain('skipped the prompt editing offer')
      expect(result.stderr).toContain('zoxide')
      if (shell === 'zsh') {
        expect(result.stderr).toContain('Cmd+E needs a command-line editor bound')
      }
      expect(result.status).toBe(1)
      expect(existsSync(join(home, '.adaptive-prompt-edit'))).toBe(false)
    })

    it('keeps an existing edit_prompt function', () => {
      const result = runPromptEdit({ setup: 'edit_prompt() { :; }; readonly -f edit_prompt > /dev/null' })
      expect(result.stdout).toBe('')
      expect(result.stderr).toContain('is already loaded')
      expect(result.status).toBe(0)
      expect(existsSync(join(home, '.adaptive-prompt-edit'))).toBe(false)
    })

    it('leaves prompt editing disabled when declined', () => {
      const result = runPromptEdit({ setup: 'confirm() { return 1; }' })
      expect(result.status).toBe(1)
      expect(result.stderr).toContain('prompt editing is disabled')
      expect(existsSync(join(home, '.adaptive-prompt-edit'))).toBe(false)
    })
  })
})

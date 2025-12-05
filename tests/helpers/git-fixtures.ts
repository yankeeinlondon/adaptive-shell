/**
 * Git Fixture Management Utility
 *
 * Provides a centralized way to create and manage git-based test fixtures.
 * Git fixtures must be created dynamically because they require actual git
 * repository initialization, which cannot be included in version control.
 */

import { mkdirSync, rmSync, existsSync, writeFileSync } from 'fs'
import { join, dirname } from 'path'
import { execSync } from 'child_process'

/**
 * Definition for a git-based fixture
 */
export interface GitFixtureDef {
  /** Subdirectories to create within the fixture */
  subdirs?: string[]
  /** Files to create: path -> content */
  files: Record<string, string>
  /** Commits to make in the git repo */
  commits: Array<{ file: string; content: string; message: string }>
}

/**
 * Manages the lifecycle of git-based test fixtures.
 *
 * Usage:
 * ```typescript
 * const gitManager = new GitFixtureManager('lang-js-git')
 *
 * beforeAll(() => {
 *   const gitDirs = gitManager.setup(GIT_FIXTURES)
 *   Object.assign(dirs, gitDirs)
 * })
 *
 * afterAll(() => {
 *   gitManager.teardown()
 * })
 * ```
 */
export class GitFixtureManager {
  private tempDir: string
  private fixtures: Map<string, string> = new Map()

  /**
   * Create a new GitFixtureManager
   * @param baseName - Base name for the temp directory (e.g., 'lang-js-git')
   */
  constructor(private baseName: string) {
    this.tempDir = join(process.cwd(), 'tests', `.tmp-${baseName}`)
  }

  /**
   * Initialize a git repository in the given directory
   */
  private initGitRepo(dir: string): void {
    execSync('git init', { cwd: dir, stdio: 'pipe' })
    execSync('git config user.email "test@test.com"', { cwd: dir, stdio: 'pipe' })
    execSync('git config user.name "Test User"', { cwd: dir, stdio: 'pipe' })
  }

  /**
   * Create a single git fixture
   */
  private createGitFixture(name: string, def: GitFixtureDef): string {
    const fixtureDir = join(this.tempDir, name)

    // Create subdirectories first
    if (def.subdirs) {
      for (const subdir of def.subdirs) {
        mkdirSync(join(fixtureDir, subdir), { recursive: true })
      }
    } else {
      mkdirSync(fixtureDir, { recursive: true })
    }

    // Initialize git repo
    this.initGitRepo(fixtureDir)

    // Write all files
    for (const [filename, content] of Object.entries(def.files)) {
      const filePath = join(fixtureDir, filename)
      const fileDir = dirname(filePath)
      if (!existsSync(fileDir)) {
        mkdirSync(fileDir, { recursive: true })
      }
      writeFileSync(filePath, content)
    }

    // Create commits
    for (const commit of def.commits) {
      execSync(`git add "${commit.file}"`, { cwd: fixtureDir, stdio: 'pipe' })
      execSync(`git commit --no-gpg-sign -m "${commit.message}"`, { cwd: fixtureDir, stdio: 'pipe' })
    }

    this.fixtures.set(name, fixtureDir)
    return fixtureDir
  }

  /**
   * Set up all git fixtures from the provided definitions
   * @param definitions - Map of fixture names to their definitions
   * @returns Map of fixture names to their directory paths
   */
  setup(definitions: Record<string, GitFixtureDef>): Record<string, string> {
    // Clean up any previous run
    if (existsSync(this.tempDir)) {
      rmSync(this.tempDir, { recursive: true, force: true })
    }
    mkdirSync(this.tempDir, { recursive: true })

    const dirs: Record<string, string> = {}
    for (const [name, def] of Object.entries(definitions)) {
      dirs[name] = this.createGitFixture(name, def)
    }
    return dirs
  }

  /**
   * Clean up all git fixtures created by this manager
   */
  teardown(): void {
    if (existsSync(this.tempDir)) {
      rmSync(this.tempDir, { recursive: true, force: true })
    }
    this.fixtures.clear()
  }

  /**
   * Get the path to a specific fixture
   */
  getFixturePath(name: string): string | undefined {
    return this.fixtures.get(name)
  }

  /**
   * Get the temp directory path
   */
  getTempDir(): string {
    return this.tempDir
  }
}

/**
 * Common git fixture patterns that can be reused across test files.
 * These factory functions create standardized fixture definitions.
 */
export const COMMON_GIT_PATTERNS = {
  /**
   * Creates a "prefer cwd" pattern fixture.
   * Used to test that a file in the current directory is preferred over repo root.
   *
   * @param rootFile - File name at repository root
   * @param rootContent - Content for root file
   * @param subdirPath - Path to subdirectory (e.g., 'packages/app')
   * @param subdirContent - Content for file in subdirectory
   */
  preferCwd: (
    rootFile: string,
    rootContent: string,
    subdirPath: string,
    subdirContent: string
  ): GitFixtureDef => ({
    subdirs: [subdirPath],
    files: {
      [rootFile]: rootContent,
      [`${subdirPath}/${rootFile}`]: subdirContent
    },
    commits: [
      { file: rootFile, content: rootContent, message: 'init' }
    ]
  }),

  /**
   * Creates a "repo root" pattern fixture.
   * Used to test that a file at repo root is found from a subdirectory.
   *
   * @param rootFile - File name at repository root
   * @param rootContent - Content for root file
   * @param subdirPath - Path to subdirectory (e.g., 'src/app')
   */
  repoRoot: (
    rootFile: string,
    rootContent: string,
    subdirPath: string
  ): GitFixtureDef => ({
    subdirs: [subdirPath],
    files: {
      [rootFile]: rootContent
    },
    commits: [
      { file: rootFile, content: rootContent, message: 'init' }
    ]
  }),

  /**
   * Creates a "subdir with package manager" pattern fixture.
   * Used to test package manager detection from subdirectories.
   *
   * @param configFile - Main config file (e.g., 'package.json', 'pyproject.toml')
   * @param configContent - Content for config file
   * @param lockFile - Lock file name (e.g., 'pnpm-lock.yaml', 'poetry.lock')
   * @param lockContent - Content for lock file
   * @param subdirPath - Path to subdirectory
   */
  pkgMgrSubdir: (
    configFile: string,
    configContent: string,
    lockFile: string,
    lockContent: string,
    subdirPath: string
  ): GitFixtureDef => ({
    subdirs: [subdirPath],
    files: {
      [configFile]: configContent,
      [lockFile]: lockContent
    },
    commits: [
      { file: configFile, content: configContent, message: 'init' }
    ]
  }),

  /**
   * Creates a "workspace" pattern fixture.
   * Used to test workspace detection from subdirectories.
   *
   * @param workspaceFile - Workspace config file (e.g., 'Cargo.toml')
   * @param workspaceContent - Workspace config content
   * @param memberPath - Path to workspace member (e.g., 'crates/app')
   * @param memberFile - Member config file name
   * @param memberContent - Member config content
   */
  workspace: (
    workspaceFile: string,
    workspaceContent: string,
    memberPath: string,
    memberFile: string,
    memberContent: string
  ): GitFixtureDef => ({
    subdirs: [memberPath],
    files: {
      [workspaceFile]: workspaceContent,
      [`${memberPath}/${memberFile}`]: memberContent
    },
    commits: [
      { file: workspaceFile, content: workspaceContent, message: 'init' }
    ]
  }),

  /**
   * Creates a "config at repo root" pattern fixture.
   * Used to test that config files at repo root are found from subdirectories.
   *
   * @param workspaceFile - Workspace/project config file
   * @param workspaceContent - Workspace/project config content
   * @param configFile - Linter/formatter config file (e.g., 'clippy.toml')
   * @param configContent - Config file content
   * @param subdirPath - Path to subdirectory
   */
  configAtRoot: (
    workspaceFile: string,
    workspaceContent: string,
    configFile: string,
    configContent: string,
    subdirPath: string
  ): GitFixtureDef => ({
    subdirs: [subdirPath],
    files: {
      [workspaceFile]: workspaceContent,
      [configFile]: configContent
    },
    commits: [
      { file: workspaceFile, content: workspaceContent, message: 'init' }
    ]
  })
}

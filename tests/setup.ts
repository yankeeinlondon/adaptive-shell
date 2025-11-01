/**
 * Vitest setup file
 *
 * This file is automatically run before all tests.
 * It registers custom matchers for the bash testing framework.
 */

import { setupBashMatchers } from './helpers/matchers';

// Register custom matchers globally
setupBashMatchers();

# Plan: Fix Failing Tests

**Date**: 2025-10-21
**Goal**: Get all tests passing (except TODO-marked functions in utils/detection.sh)
**Current Status**: 135/148 tests passing (13 failures in typeof.test.ts)

## Problem Analysis

All 13 failing tests are in `tests/typeof.test.ts` and relate to variable binding semantics:

**Root Cause**: The `is_bound()` function has specific semantics about bash namerefs and variable attributes that don't match typical "is variable set" expectations. The function is designed for internal use by other typeof utilities, not general-purpose variable checking.

**Failing Test Categories**:
1. `is_bound()` - Tests expect it to work like "is variable set" but it checks nameref resolution
2. `is_empty()` - Depends on `is_bound()` for reference mode
3. `is_array()` / `is_assoc_array()` - Depend on `is_bound()`
4. `typeof()` - Uses `is_bound()` internally to determine if variable is bound
5. `is_typeof()` / `is_not_typeof()` - Depend on `typeof()`

## Phase 0: Investigation and Test Refinement

**Objective**: Understand the actual semantics of typeof utilities and adjust tests accordingly

### Tasks:

1. **Document is_bound() semantics** (15 min)
   - Create test cases that demonstrate actual behavior
   - Determine what makes a variable "bound" in this context
   - Document findings in code comments

2. **Analyze typeof.sh dependencies** (10 min)
   - Map out which functions depend on is_bound()
   - Understand the intended use cases
   - Identify if there are actual bugs vs. incorrect test expectations

3. **Create test strategy** (10 min)
   - Decide whether to fix tests or fix code
   - Identify which behaviors are correct vs. bugs
   - Plan approach for each failing test

**Deliverables**:
- Investigation notes in this plan file
- Decision matrix: fix code vs. fix tests

## Phase 1: Fix is_bound() Tests

**Objective**: Update is_bound() tests to match actual function behavior

### Approach:

The `is_bound()` function appears to be an internal utility for checking nameref resolution, not a general "is variable set" checker. Based on investigation:

**Option A: Update tests to match actual behavior**
- Change test expectations to reflect nameref semantics
- Document that is_bound() is for internal use
- Add note that users should use different functions for "is set" checks

**Option B: Fix is_bound() implementation**
- Modify function to work as tests expect
- Ensure backward compatibility
- Update dependent functions

### Tasks:

1. **Test is_bound() in isolated environment** (20 min)
   - Create comprehensive test cases
   - Document what actually makes a variable "bound"
   - Verify behavior across different bash versions

2. **Make decision: fix code or fix tests** (10 min)
   - Review how is_bound() is used in codebase
   - Check if changing behavior would break anything
   - Document decision rationale

3. **Implement fixes** (30 min)
   - Update either tests or implementation
   - Ensure all is_bound() tests pass
   - Verify no regressions in dependent code

**Deliverables**:
- All is_bound() tests passing
- Documentation of is_bound() behavior
- Updated test file or implementation

## Phase 2: Fix Dependent Function Tests

**Objective**: Fix tests for functions that depend on is_bound()

### Functions to Fix:
- `is_empty()` - 2 failing tests (reference mode)
- `is_array()` - 2 failing tests
- `is_assoc_array()` - 2 failing tests
- `typeof()` - 4 failing tests
- `is_typeof()` / `is_not_typeof()` - 2 failing tests

### Tasks:

1. **Fix is_empty() tests** (20 min)
   - Update tests for reference mode behavior
   - Ensure value mode still works correctly
   - Test with arrays and strings

2. **Fix is_array() tests** (15 min)
   - Adjust expectations for empty arrays
   - Fix unbound reference test
   - Verify array detection works

3. **Fix is_assoc_array() tests** (15 min)
   - Update tests for associative arrays
   - Test with empty and non-empty cases
   - Ensure detection is accurate

4. **Fix typeof() tests** (25 min)
   - Update variable-based tests
   - Fix literal value tests
   - Ensure type detection is accurate

5. **Fix is_typeof() / is_not_typeof() tests** (15 min)
   - Adjust type matching tests
   - Verify positive and negative cases
   - Ensure both functions work correctly

**Deliverables**:
- All typeof.test.ts tests passing (13 additional tests)
- Total: 148/148 tests passing
- Updated documentation if behavior differs from expectations

## Phase 3: Verification and Documentation

**Objective**: Ensure all tests pass and document any behavioral notes

### Tasks:

1. **Run full test suite** (5 min)
   ```bash
   pnpm test
   ```
   - Verify 148/148 tests passing
   - Check for any regressions
   - Ensure CI will pass

2. **Update test documentation** (20 min)
   - Add section to tests/README.md about typeof utilities
   - Document is_bound() semantics if non-obvious
   - Add examples of correct usage patterns

3. **Update CLAUDE.md if needed** (10 min)
   - Add notes about typeof utilities if relevant
   - Document any gotchas discovered
   - Update code examples if needed

4. **Clean up investigation artifacts** (5 min)
   - Remove temporary test files
   - Archive investigation notes
   - Update this plan with final results

**Deliverables**:
- 100% test pass rate (148/148)
- Updated documentation
- Clean git status

## Success Criteria

- ✅ All 148 tests passing
- ✅ No regressions in existing tests
- ✅ CI pipeline passes
- ✅ Documentation updated
- ✅ Clear understanding of typeof utilities behavior

## Timeline

- Phase 0: ~35 minutes (investigation)
- Phase 1: ~60 minutes (is_bound fixes)
- Phase 2: ~90 minutes (dependent function fixes)
- Phase 3: ~40 minutes (verification)

**Total Estimated Time**: ~3.5 hours

## Notes

- Focus on fixing tests to match actual behavior rather than changing well-established functions
- Document any surprising or non-obvious behaviors
- Ensure changes don't break existing code that depends on these utilities
- Consider adding more comprehensive tests if gaps are found

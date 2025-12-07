# SentinelService Tests

This directory contains comprehensive tests for the SentinelService native library wrapper.

## Test Files

- **`sentinel_service_test.dart`** - Complete test suite for all native functions

## Running Tests

### Run All Tests

```bash
dart test
```

### Run Specific Test Group

```bash
# Mouse operations only
dart test -n "Mouse Operations"

# Keyboard operations only
dart test -n "Keyboard Operations"

# Screen operations only
dart test -n "Screen Operations"
```

### Run Individual Test

```bash
dart test -n "should move mouse to absolute coordinates"
```

### Run with Verbose Output

```bash
dart test --reporter expanded
```

## Test Coverage

The test suite covers:

### Mouse Operations ✓
- Absolute positioning (`move`)
- Relative positioning (`moveRelative`)
- Mouse clicks (left, right, double)
- Mouse location (`getLocation`)
- Scrolling (`scroll`)
- Smooth movements (`moveSmoothStart`)
- Smooth drag (`dragSmoothStart`)
- Task control (`stopTask`)

### Keyboard Operations ✓
- String typing (`typeStr`)
- Key tapping (`keyTap`)
- Key combinations with modifiers
- Special keys (Enter, Backspace, Tab, etc.)

### Clipboard Operations ✓
- Writing to clipboard (`writeClipboard`)
- Reading from clipboard (`readClipboard`)
- Handling special characters
- Empty string handling

### Screen Operations ✓
- Screen size detection (`getScreenSize`)
- Pixel color reading (`getPixelColor`)
- Screen capture as base64 (`captureScreenBase64`)
- Screen capture to file (`captureScreenSave`)
- Multi-display support (`getDisplaysNum`, `getDisplayBounds`)

### System Monitoring ✓
- Real-time monitoring (`startMonitor`)
- Service control (Linux - `controlService`)

### Hook Operations ✓
- Hotkey registration (`hookRegisterCombo`)
- Hook lifecycle (`hookStart`, `hookStop`)

### Utility Functions ✓
- Sleeping (`milliSleep`)
- Mouse delay configuration (`setMouseSleep`)
- Keyboard delay configuration (`setKeySleep`)

### Error Handling ✓
- Invalid coordinates
- Invalid key names
- Invalid display indices
- Invalid screen regions

### Integration Tests ✓
- Complete workflows
- Multi-step operations
- Cross-feature interactions

### Performance Tests ✓
- Operation latency benchmarks
- Throughput testing

## Prerequisites

Before running tests, ensure:

1. **Native Library Built**: The native library must be compiled and available at:
   - Windows: `native/windows/sentinel.dll`
   - Linux: `native/linux/sentinel.so`
   - macOS: `native/macos/sentinel.dylib`

2. **Permissions**: Some tests require system permissions:
   - Input simulation (mouse/keyboard)
   - Screen capture
   - Service control (Linux)

3. **Active Display**: Tests assume at least one active display

## Test Notes

### Platform-Specific Tests

Some tests are platform-specific and will be skipped on other platforms:
- `controlService` - Linux only

### Visual Tests

⚠️ **Warning**: These tests will actually control your mouse and keyboard!

Some tests perform visible actions:
- Moving the mouse cursor
- Clicking
- Typing text
- Scrolling

**Recommendation**: Don't touch your mouse/keyboard while tests are running.

### Performance Tests

Performance tests measure operation latency. Results may vary based on:
- System load
- Hardware capabilities
- OS scheduler

### Cleanup

Tests automatically clean up:
- Temporary screenshot files
- Background tasks (monitoring, smooth movements)
- Hook registrations

## Troubleshooting

### Library Not Found

```
Error: DynamicLibrary not found
```

**Solution**: Build the native library first:
```bash
cd sentinel
make
```

### Permission Denied

```
Error: Permission denied
```

**Solution**: Run with appropriate permissions or adjust system security settings.

### Test Timeout

Some tests have extended timeouts for monitoring operations. If tests timeout:
- Check if native library is responsive
- Verify system resources are available
- Increase timeout in specific test

### Flaky Tests

If tests fail intermittently:
- Ensure no other applications are interfering with input
- Check system load
- Increase delay times in tests

## Adding New Tests

When adding new tests:

1. Follow existing patterns for async operations
2. Use appropriate test groups
3. Add cleanup in `tearDown` or `tearDownAll` if needed
4. Handle platform-specific features gracefully
5. Add performance benchmarks for critical paths

## Continuous Integration

For CI environments:

```bash
# Run tests without interactive features
dart test -x integration -x performance
```

Use tags to exclude tests that require human interaction or specific hardware.

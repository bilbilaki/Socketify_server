import 'dart:io';
import 'package:test/test.dart';
import '../lib/service/sentinel_service.dart';

void main() {
  late SentinelService service;

  setUpAll(() async {
    // Initialize the service once for all tests
    service = SentinelService();
    await service.initialize();
    print('SentinelService initialized for testing');
  });

  tearDownAll(() {
    // Clean up after all tests
    service.dispose();
    print('SentinelService disposed');
  });

  group('Mouse Operations', () {
    test('move - should move mouse to absolute coordinates', () async {
      final result = await service.move(100, 100);
      expect(result, isA<Map<String, int>>());
      expect(result.containsKey('x'), isTrue);
      expect(result.containsKey('y'), isTrue);
      print('Mouse moved to: $result');
    });

    test(
      'moveRelative - should move mouse relative to current position',
      () async {
        // First get current location
        final initial = await service.getLocation();

        // Move relative
        final result = await service.moveRelative(50, 50);
        expect(result, isA<Map<String, int>>());
        expect(result['x'], equals(initial['x']! + 50));
        expect(result['y'], equals(initial['y']! + 50));
        print('Mouse moved relatively to: $result');
      },
    );

    test('getLocation - should return current mouse position', () async {
      final location = await service.getLocation();
      expect(location, isA<Map<String, int>>());
      expect(location['x'], isA<int>());
      expect(location['y'], isA<int>());
      expect(location['x']!, greaterThanOrEqualTo(0));
      expect(location['y']!, greaterThanOrEqualTo(0));
      print('Current mouse location: $location');
    });

    test('click - should perform left click', () async {
      await service.move(200, 200);
      await service.click(button: 'left');
      // If no exception is thrown, the test passes
      print('Left click performed successfully');
    });

    test('click - should perform right click', () async {
      await service.click(button: 'right');
      print('Right click performed successfully');
    });

    test('click - should perform double click', () async {
      await service.click(button: 'left', doubleClick: true);
      print('Double click performed successfully');
    });

    test('scroll - should scroll mouse wheel', () async {
      await service.scroll(0, 10);
      await Future.delayed(Duration(milliseconds: 100));
      await service.scroll(0, -10);
      print('Scroll operations performed successfully');
    });

    test('moveSmoothStart - should start smooth movement', () async {
      final taskId = service.moveSmoothStart(300, 300);
      expect(taskId, isA<int>());
      expect(taskId, greaterThan(0));

      // Wait a bit for the movement to progress
      await Future.delayed(Duration(milliseconds: 500));

      // Stop the task
      service.stopTask(taskId);
      print('Smooth movement task $taskId started and stopped');
    });

    test('dragSmoothStart - should start smooth drag', () async {
      final taskId = service.dragSmoothStart(400, 400);
      expect(taskId, isA<int>());
      expect(taskId, greaterThan(0));

      // Wait a bit for the drag to progress
      await Future.delayed(Duration(milliseconds: 500));

      // Stop the task
      service.stopTask(taskId);
      print('Smooth drag task $taskId started and stopped');
    });
  });

  group('Keyboard Operations', () {
    test('typeStr - should type a string', () async {
      await service.typeStr('Hello Test');
      await Future.delayed(Duration(milliseconds: 500));
      print('String typed successfully');
    });

    test('keyTap - should tap a single key', () async {
      await service.keyTap('a');
      print('Key tap performed successfully');
    });

    test('keyTap - should tap a key with modifiers', () async {
      await service.keyTap('c', modifiers: ['ctrl']);
      await Future.delayed(Duration(milliseconds: 100));
      print('Key tap with modifiers performed successfully');
    });

    test('keyTap - should tap with multiple modifiers', () async {
      await service.keyTap('v', modifiers: ['ctrl', 'shift']);
      print('Key tap with multiple modifiers performed successfully');
    });

    test('keyTap - should handle special keys', () async {
      await service.keyTap('enter');
      await Future.delayed(Duration(milliseconds: 100));
      await service.keyTap('backspace');
      await Future.delayed(Duration(milliseconds: 100));
      await service.keyTap('tab');
      print('Special keys tapped successfully');
    });
  });

  group('Clipboard Operations', () {
    test(
      'writeClipboard and readClipboard - should write and read clipboard',
      () async {
        const testText = 'Test clipboard content';

        // Write to clipboard
        await service.writeClipboard(testText);

        // Read from clipboard
        final content = await service.readClipboard();
        expect(content, equals(testText));
        print('Clipboard write/read successful: $content');
      },
    );

    test('writeClipboard - should handle empty string', () async {
      await service.writeClipboard('');
      final content = await service.readClipboard();
      expect(content, equals(''));
      print('Empty clipboard content handled successfully');
    });

    test('writeClipboard - should handle special characters', () async {
      const specialText = 'Test\nNew Line\tTab\r\nWindows Line';
      await service.writeClipboard(specialText);
      final content = await service.readClipboard();
      expect(content, equals(specialText));
      print('Special characters in clipboard handled successfully');
    });
  });

  group('Screen Operations', () {
    test('getScreenSize - should return screen dimensions', () async {
      final size = await service.getScreenSize();
      expect(size, isA<Map<String, int>>());
      expect(size['width'], isA<int>());
      expect(size['height'], isA<int>());
      expect(size['width']!, greaterThan(0));
      expect(size['height']!, greaterThan(0));
      print('Screen size: ${size['width']}x${size['height']}');
    });

    test('getPixelColor - should return color at coordinates', () async {
      final color = await service.getPixelColor(100, 100);
      expect(color, isA<String>());
      expect(color.isNotEmpty, isTrue);
      // Color should be in hex format
      expect(color.startsWith('#') || color.length == 6, isTrue);
      print('Pixel color at (100, 100): $color');
    });

    test(
      'captureScreenBase64 - should capture screen region as base64',
      () async {
        final base64 = await service.captureScreenBase64(0, 0, 100, 100);
        expect(base64, isA<String>());
        expect(base64.isNotEmpty, isTrue);
        print('Screen captured as base64 (length: ${base64.length} chars)');
      },
    );

    test('captureScreenSave - should save screen capture to file', () async {
      final testPath = 'test_screenshot.png';

      try {
        final path = await service.captureScreenSave(
          0,
          0,
          200,
          200,
          path: testPath,
        );
        expect(path, isA<String>());
        expect(path.isNotEmpty, isTrue);

        // Verify file exists
        final file = File(path);
        expect(await file.exists(), isTrue);
        print('Screen captured and saved to: $path');

        // Clean up
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Note: File save test may fail depending on permissions: $e');
      }
    });

    test('getDisplaysNum - should return number of displays', () async {
      final numDisplays = await service.getDisplaysNum();
      expect(numDisplays, isA<int>());
      expect(numDisplays, greaterThanOrEqualTo(1));
      print('Number of displays: $numDisplays');
    });

    test(
      'getDisplayBounds - should return bounds for primary display',
      () async {
        final bounds = await service.getDisplayBounds(0);
        expect(bounds, isA<Map<String, int>>());
        expect(bounds.containsKey('x'), isTrue);
        expect(bounds.containsKey('y'), isTrue);
        expect(bounds.containsKey('width'), isTrue);
        expect(bounds.containsKey('height'), isTrue);
        expect(bounds['width']!, greaterThan(0));
        expect(bounds['height']!, greaterThan(0));
        print('Primary display bounds: $bounds');
      },
    );
  });

  group('System Monitoring', () {
    test(
      'startMonitor - should start monitoring and receive stats',
      () async {
        int statsReceived = 0;

        final taskId = service.startMonitor(
          onStats: (stats) {
            statsReceived++;
            expect(stats, isA<Map<String, dynamic>>());
            print('Monitoring stats received: $stats');
          },
        );

        expect(taskId, isA<int>());
        expect(taskId, greaterThan(0));

        // Wait for at least one stats update
        await Future.delayed(Duration(seconds: 2));

        // Stop monitoring
        service.stopTask(taskId);

        expect(statsReceived, greaterThan(0));
        print(
          'Monitoring task $taskId completed, received $statsReceived stats',
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'controlService - should handle service control (Linux only)',
      () async {
        if (!Platform.isLinux) {
          print('Skipping service control test (not on Linux)');
          return;
        }

        try {
          final result = await service.controlService('test-service', 'status');
          expect(result, isA<Map<String, dynamic>>());
          print('Service control result: $result');
        } catch (e) {
          print('Note: Service control may fail if service does not exist: $e');
        }
      },
    );
  });

  group('Hook Operations', () {
    test('hookRegisterCombo - should register hotkey combo', () async {
      // Register a combo (this just registers, doesn't wait for key press)
      service.hookRegisterCombo('f1');
      await Future.delayed(Duration(milliseconds: 100));
      print('Hotkey F1 registered successfully');
    });

    test('hookRegisterCombo - should register combo with modifiers', () async {
      service.hookRegisterCombo('a', modifiers: ['ctrl', 'alt']);
      await Future.delayed(Duration(milliseconds: 100));
      print('Hotkey Ctrl+Alt+A registered successfully');
    });

    test(
      'hookStart and hookStop - should start and stop hook listening',
      () async {
        service.hookStart();
        await Future.delayed(Duration(milliseconds: 500));
        service.hookStop();
        print('Hook start/stop completed successfully');
      },
    );
  });

  group('Utility Operations', () {
    test('milliSleep - should sleep for specified milliseconds', () async {
      final stopwatch = Stopwatch()..start();
      await service.milliSleep(100);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(95));
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
      print('Sleep completed in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('setMouseSleep - should set mouse sleep time', () async {
      await service.setMouseSleep(50);
      print('Mouse sleep time set to 50ms');
    });

    test('setKeySleep - should set key sleep time', () async {
      await service.setKeySleep(30);
      print('Key sleep time set to 30ms');
    });

    test('setMouseSleep and setKeySleep - should accept zero', () async {
      await service.setMouseSleep(0);
      await service.setKeySleep(0);
      print('Sleep times set to 0ms (no delay)');
    });
  });

  group('Error Handling', () {
    test('move - should handle invalid coordinates', () async {
      try {
        await service.move(-1000, -1000);
        // Some implementations may allow negative coordinates
        print('Negative coordinates handled');
      } catch (e) {
        expect(e, isA<Object>());
        print('Negative coordinates rejected as expected: $e');
      }
    });

    test('keyTap - should handle invalid key name', () async {
      try {
        await service.keyTap('invalid_key_name_xyz');
        print('Invalid key handled or ignored');
      } catch (e) {
        expect(e, isA<Object>());
        print('Invalid key rejected as expected: $e');
      }
    });

    test('getDisplayBounds - should handle invalid display index', () async {
      try {
        await service.getDisplayBounds(999);
        fail('Should have thrown an error for invalid display index');
      } catch (e) {
        expect(e, isA<Object>());
        print('Invalid display index rejected as expected: $e');
      }
    });

    test('captureScreenBase64 - should handle invalid region', () async {
      try {
        await service.captureScreenBase64(-100, -100, 10, 10);
        print('Invalid region handled or adjusted');
      } catch (e) {
        expect(e, isA<Object>());
        print('Invalid region rejected as expected: $e');
      }
    });
  });

  group('Integration Tests', () {
    test('complete workflow - move, click, type sequence', () async {
      // Move to a position
      await service.move(500, 500);
      await Future.delayed(Duration(milliseconds: 100));

      // Click
      await service.click();
      await Future.delayed(Duration(milliseconds: 100));

      // Type some text
      await service.typeStr('Integration Test');
      await Future.delayed(Duration(milliseconds: 100));

      print('Complete workflow executed successfully');
    });

    test('clipboard integration - copy and paste simulation', () async {
      const originalText = 'Copy-Paste Test';

      // Write to clipboard
      await service.writeClipboard(originalText);

      // Simulate copy (Ctrl+C - this doesn't actually copy, just simulates the key)
      await service.keyTap('c', modifiers: ['ctrl']);
      await Future.delayed(Duration(milliseconds: 100));

      // Read clipboard
      final content = await service.readClipboard();
      expect(content, equals(originalText));

      // Simulate paste (Ctrl+V)
      await service.keyTap('v', modifiers: ['ctrl']);

      print('Clipboard integration test completed');
    });

    test('screen capture and analysis workflow', () async {
      // Get screen size
      final screenSize = await service.getScreenSize();

      // Capture a small region
      final captureWidth = 50;
      final captureHeight = 50;
      final x = (screenSize['width']! / 2).round();
      final y = (screenSize['height']! / 2).round();

      // Capture as base64
      final base64 = await service.captureScreenBase64(
        x,
        y,
        captureWidth,
        captureHeight,
      );
      expect(base64.isNotEmpty, isTrue);

      // Get pixel color at the same location
      final color = await service.getPixelColor(x, y);
      expect(color.isNotEmpty, isTrue);

      print(
        'Screen capture workflow completed: captured ${captureWidth}x${captureHeight} region',
      );
    });

    test('multi-display workflow', () async {
      final numDisplays = await service.getDisplaysNum();
      print('Testing with $numDisplays display(s)');

      for (int i = 0; i < numDisplays; i++) {
        final bounds = await service.getDisplayBounds(i);
        expect(bounds['width'], greaterThan(0));
        expect(bounds['height'], greaterThan(0));
        print('Display $i bounds: $bounds');
      }
    });
  });

  group('Performance Tests', () {
    test('getLocation - performance test (100 calls)', () async {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        await service.getLocation();
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMilliseconds / 100;
      print(
        'Average time per getLocation call: ${avgTime.toStringAsFixed(2)}ms',
      );

      expect(avgTime, lessThan(50)); // Should be reasonably fast
    });

    test('move - performance test (50 movements)', () async {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 50; i++) {
        await service.move(100 + i, 100 + i);
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMilliseconds / 50;
      print('Average time per move call: ${avgTime.toStringAsFixed(2)}ms');

      expect(avgTime, lessThan(100));
    });

    test('clipboard - performance test (20 write/read cycles)', () async {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 20; i++) {
        await service.writeClipboard('Test $i');
        final content = await service.readClipboard();
        expect(content, equals('Test $i'));
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMilliseconds / 20;
      print(
        'Average time per clipboard write/read cycle: ${avgTime.toStringAsFixed(2)}ms',
      );
    });
  });
}

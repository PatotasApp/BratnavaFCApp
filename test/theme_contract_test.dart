import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation layer uses only centralized theme colors and Poppins', () {
    final roots = [
      Directory('lib/features'),
      Directory('lib/shared/presentation'),
    ];

    final violations = <String>[];
    final directHex = RegExp(r'Color\(0x[0-9a-fA-F]{8}\)');
    final materialColor = RegExp(r'\bColors\.');
    final explicitFont = RegExp(r'fontFamily\s*:');

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (normalizedPath.startsWith('lib/features/') &&
            !normalizedPath.contains('/presentation/')) {
          continue;
        }

        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          if (directHex.hasMatch(line) ||
              materialColor.hasMatch(line) ||
              explicitFont.hasMatch(line)) {
            violations.add('${entity.path}:${index + 1}: ${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Use Theme.of(context), context.app* ou AppColors. '
          'Cores e fontes diretas impedem a troca global de tema.\n'
          '${violations.join('\n')}',
    );
  });
}

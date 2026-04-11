import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  int replacedCount = 0;
  for (var file in files) {
    if (file.path.contains('colors.dart') ||
        file.path.contains('theme_controller.dart')) {
      continue;
    }

    var content = file.readAsStringSync();

    // ClassName
    final newContent =
        content.replaceAllMapped(RegExp(r'const\s+([A-Z])'), (match) {
      replacedCount++;
      return match.group(1)!;
    });

    if (content != newContent) {
      file.writeAsStringSync(newContent);
    }
  }

  stdout.writeln("Removed $replacedCount const modifiers.");
}

import 'dart:io';

import 'package:ffigen/ffigen.dart';

/// Regenerates go/ffi/libbitbox.h from the Go exports, then lib/ffi/libbitbox.g.dart from it.
///
/// Requires Go. Run from anywhere: `dart run tool/ffigen.dart`.
void main() {
  final packageRoot = Platform.script.resolve('../');
  _generateHeader(packageRoot);

  FfiGenerator(
    headers: Headers(entryPoints: [packageRoot.resolve('go/ffi/libbitbox.h')]),
    output: Output(
      dartFile: packageRoot.resolve('lib/ffi/libbitbox.g.dart'),
      preamble: '// ignore_for_file: unused_field\n',
      style: const DynamicLibraryBindings(
        wrapperName: 'BitBoxFlutter',
        wrapperDocComment: 'Bindings to `go/libbitbox.h`.',
      ),
    ),
    // The legacy YAML config included every declaration by default; the Dart API
    // excludes everything by default.
    functions: Functions.includeAll,
    structs: const Structs(
      include: Declarations.includeAll,
      dependencies: CompoundDependencies.full,
    ),
    unions: const Unions(
      include: Declarations.includeAll,
      dependencies: CompoundDependencies.full,
    ),
    enums: Enums.includeAll,
    unnamedEnums: UnnamedEnums.includeAll,
    globals: Globals.includeAll,
    macros: Macros.includeAll,
    typedefs: Typedefs.includeAll,
  ).generate();
}

/// Builds go/ffi for the host, only to have cgo write the export header; the header doesn't
/// depend on the target, so this needs no cross toolchain.
void _generateHeader(Uri packageRoot) {
  final tmp = Directory.systemTemp.createTempSync('libbitbox');
  try {
    final result = Process.runSync(
      'go',
      [
        'build',
        '-buildmode=c-archive',
        '-o',
        '${tmp.path}/libbitbox.a',
        './ffi',
      ],
      workingDirectory: packageRoot.resolve('go/').toFilePath(),
      environment: {'CGO_ENABLED': '1'},
    );
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      exit(result.exitCode);
    }
    File(
      '${tmp.path}/libbitbox.h',
    ).copySync(packageRoot.resolve('go/ffi/libbitbox.h').toFilePath());
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

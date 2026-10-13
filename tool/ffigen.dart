import 'dart:io';

import 'package:ffigen/ffigen.dart';

/// Generates lib/src/libbitbox.g.dart from the header written by build_ffi.sh.
///
/// Run from anywhere: `dart run tool/ffigen.dart`.
void main() {
  final packageRoot = Platform.script.resolve('../');

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

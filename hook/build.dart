import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// Builds the Go dart:ffi bridge (go/ffi) for the target and bundles it with the app,
/// where `_openLibrary()` in lib/ffi/bitbox_ffi.dart loads it.
///
/// Requires Go. It is looked up on PATH and in the usual install locations, since Xcode
/// runs builds with a minimal PATH.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;

    final goDir = input.packageRoot.resolve('go/');
    final lib = input.outputDirectory.resolve(
      code.targetOS.dylibFileName('bitbox'),
    );

    switch (code.targetOS) {
      case OS.android:
        await _buildAndroid(code, goDir, lib);
      case OS.iOS:
        await _buildIOS(code, goDir, input.outputDirectory, lib);
      default:
        // Other platforms are not supported yet.
        return;
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'libbitbox',
        linkMode: DynamicLoadingBundled(),
        file: lib,
      ),
    );
    // Directory dependencies only track their direct children, so list the sources.
    output.dependencies.addAll(_goSources(goDir));
  });
}

Future<void> _buildAndroid(CodeConfig code, Uri goDir, Uri lib) async {
  final (goarch, clangTarget) = switch (code.targetArchitecture) {
    Architecture.arm64 => ('arm64', 'aarch64-linux-android'),
    Architecture.arm => ('arm', 'armv7a-linux-androideabi'),
    Architecture.x64 => ('amd64', 'x86_64-linux-android'),
    Architecture.ia32 => ('386', 'i686-linux-android'),
    final arch => throw UnsupportedError(
      'Unsupported Android architecture $arch',
    ),
  };
  final clang =
      code.cCompiler?.compiler ??
      (throw StateError(
        'No C compiler configured; is the Android NDK installed?',
      ));
  // Flutter's minimum, raised to what the NDK still supports.
  final api = code.android.targetNdkApi < 21 ? 21 : code.android.targetNdkApi;

  await _go(
    goDir,
    [
      'build', '-buildmode=c-shared', '-trimpath',
      // 16 KB page alignment is required for apps targeting Android 15+ on Google Play.
      '-ldflags=-s -w -extldflags=-Wl,-z,max-page-size=16384',
      '-o', lib.toFilePath(), './ffi',
    ],
    {
      'GOOS': 'android',
      'GOARCH': goarch,
      if (goarch == 'arm') 'GOARM': '7',
      'CC': '${_quote(clang.toFilePath())} --target=$clangTarget$api',
    },
  );
}

/// Go can't build shared libraries for iOS, so build a static archive and link it into a
/// dylib, which Flutter then wraps into a framework.
Future<void> _buildIOS(CodeConfig code, Uri goDir, Uri outDir, Uri lib) async {
  final simulator = code.iOS.targetSdk == IOSSdk.iPhoneSimulator;
  final (goarch, arch) = switch (code.targetArchitecture) {
    Architecture.arm64 => ('arm64', 'arm64'),
    Architecture.x64 when simulator => ('amd64', 'x86_64'),
    final a => throw UnsupportedError('Unsupported iOS architecture $a'),
  };
  final target =
      '$arch-apple-ios${code.iOS.targetVersion}${simulator ? '-simulator' : ''}';
  final sdk = await _run('xcrun', [
    '--sdk',
    code.iOS.targetSdk.type,
    '--show-sdk-path',
  ]);
  final clang =
      code.cCompiler?.compiler.toFilePath() ??
      await _run('xcrun', [
        '--sdk',
        code.iOS.targetSdk.type,
        '--find',
        'clang',
      ]);
  final clangArgs = ['-target', target, '-isysroot', sdk];

  final archive = outDir.resolve('libbitbox.a').toFilePath();
  await _go(
    goDir,
    [
      'build',
      '-buildmode=c-archive',
      '-trimpath',
      '-ldflags=-s -w',
      '-o',
      archive,
      './ffi',
    ],
    {
      'GOOS': 'ios',
      'GOARCH': goarch,
      'CC': [clang, ...clangArgs].map(_quote).join(' '),
    },
  );

  await _run(clang, [
    ...clangArgs,
    '-dynamiclib',
    '-install_name',
    '@rpath/${lib.pathSegments.last}',
    '-Wl,-all_load',
    archive,
    '-framework',
    'CoreFoundation',
    '-framework',
    'Security',
    '-lresolv',
    '-o',
    lib.toFilePath(),
  ]);
}

Future<void> _go(Uri goDir, List<String> args, Map<String, String> env) => _run(
  _findGo(),
  args,
  workingDirectory: goDir.toFilePath(),
  environment: {'CGO_ENABLED': '1', ...env},
);

String _findGo() {
  final home = Platform.environment['HOME'];
  final candidates = [
    for (final dir in (Platform.environment['PATH'] ?? '').split(':'))
      if (dir.isNotEmpty) '$dir/go',
    '/opt/homebrew/bin/go',
    '/usr/local/go/bin/go',
    '/usr/local/bin/go',
    if (home != null) '$home/go/bin/go',
  ];
  return candidates.firstWhere(
    (path) => File(path).existsSync(),
    orElse: () =>
        throw StateError('Go not found; install it from https://go.dev/dl'),
  );
}

Future<String> _run(
  String executable,
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    executable,
    args,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      args,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return (result.stdout as String).trim();
}

/// Quotes [arg] for the CC variable, which Go splits on whitespace.
String _quote(String arg) => arg.contains(' ') ? "'$arg'" : arg;

Iterable<Uri> _goSources(Uri goDir) => Directory.fromUri(goDir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => RegExp(r'(\.go|\.h|\.c|go\.mod|go\.sum)$').hasMatch(f.path))
    .map((f) => f.uri);

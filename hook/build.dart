import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:hooks/hooks.dart';
import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final logger = Logger('')
      ..level = Level.ALL
      ..onRecord.listen((record) {
        // ignore: avoid_print
        print(record.message);
      });

    final Map<String, dynamic> inputMap = jsonDecode(input.toString());
    
    // Fallback extraction for target OS and architecture
    String osStr = 'macos';
    String archStr = 'arm64';
    
    try {
      if (inputMap['config'] != null && inputMap['config']['code'] != null) {
        osStr = inputMap['config']['code']['target_os'] as String;
        archStr = inputMap['config']['code']['target_architecture'] as String;
      } else if (inputMap['config'] != null && inputMap['config']['extensions'] != null && inputMap['config']['extensions']['code_assets'] != null) {
        final ext = inputMap['config']['extensions']['code_assets'];
        osStr = ext['target_os'] as String;
        archStr = ext['target_architecture'] as String;
      } else {
        // Just try to use the BuildInput API directly if available
        // Note: we can't reliably cast without knowing the version, so we rely on string parsing if possible.
        final jsonStr = input.toString();
        if (jsonStr.contains('"target_os":"ios"')) { osStr = 'ios'; }
        else if (jsonStr.contains('"target_os":"android"')) { osStr = 'android'; }
        else if (jsonStr.contains('"target_os":"windows"')) { osStr = 'windows'; }
        else if (jsonStr.contains('"target_os":"linux"')) { osStr = 'linux'; }
        else if (jsonStr.contains('"target_os":"macos"')) { osStr = 'macos'; }
        
        if (jsonStr.contains('"target_architecture":"x64"')) { archStr = 'x64'; }
        else if (jsonStr.contains('"target_architecture":"x86_64"')) { archStr = 'x86_64'; }
        else if (jsonStr.contains('"target_architecture":"arm64"')) { archStr = 'arm64'; }
        else if (jsonStr.contains('"target_architecture":"arm"')) { archStr = 'arm'; }
      }
    } catch (e) {
      logger.severe('Failed to parse OS/arch from input: $e. Input was: $input');
    }
    
    
    // 1. Run CMake to build liboqs
    final buildDir = Directory('src/liboqs/build_${osStr}_$archStr');
    if (!buildDir.existsSync()) {
      buildDir.createSync(recursive: true);
    }
    
    final cmakeArgs = [
      '-DBUILD_SHARED_LIBS=OFF', // Static library
      '-DOQS_USE_OPENSSL=OFF',
      '-DOQS_BUILD_ONLY_LIB=ON',
    ];
    
    // Map OS to CMake System Name
    if (osStr == 'macos') {
      cmakeArgs.add('-DCMAKE_SYSTEM_NAME=Darwin');
      cmakeArgs.add('-DCMAKE_OSX_ARCHITECTURES=${archStr == 'arm64' ? 'arm64' : 'x86_64'}');
      cmakeArgs.add('-DCMAKE_SYSTEM_PROCESSOR=${archStr == 'arm64' ? 'arm64' : 'x86_64'}');
    } else if (osStr == 'ios') {
      cmakeArgs.add('-DCMAKE_SYSTEM_NAME=iOS');
      cmakeArgs.add('-DCMAKE_OSX_ARCHITECTURES=${archStr == 'arm64' ? 'arm64' : 'x86_64'}');
      cmakeArgs.add('-DCMAKE_SYSTEM_PROCESSOR=${archStr == 'arm64' ? 'arm64' : 'x86_64'}');
    } else if (osStr == 'android') {
      cmakeArgs.add('-DCMAKE_SYSTEM_NAME=Android');
      cmakeArgs.add('-DCMAKE_ANDROID_ARCH_ABI=${_getAndroidArch(archStr)}');
      cmakeArgs.add('-DCMAKE_SYSTEM_PROCESSOR=${archStr == 'arm64' ? 'aarch64' : 'x86_64'}');
    } else if (osStr == 'windows') {
      cmakeArgs.add('-DCMAKE_SYSTEM_NAME=Windows');
      cmakeArgs.add('-DCMAKE_SYSTEM_PROCESSOR=AMD64');
    } else if (osStr == 'linux') {
      cmakeArgs.add('-DCMAKE_SYSTEM_NAME=Linux');
      cmakeArgs.add('-DCMAKE_SYSTEM_PROCESSOR=${archStr == 'arm64' ? 'aarch64' : 'x86_64'}');
    }
    
    // In case liboqs still complains about architecture detection, fallback to C compile only
    cmakeArgs.add('-DOQS_PERMIT_UNSUPPORTED_ARCHITECTURE=ON');
    
    cmakeArgs.add('..'); // liboqs root relative to build dir
    
    logger.info('Configuring liboqs with CMake...');
    final cmakeResult = await Process.run('cmake', cmakeArgs, workingDirectory: buildDir.path);
    if (cmakeResult.exitCode != 0) {
      logger.severe('CMake configure failed: ${cmakeResult.stderr}\n${cmakeResult.stdout}');
      throw Exception('CMake configure failed');
    }
    
    logger.info('Building liboqs with CMake...');
    final makeResult = await Process.run('cmake', ['--build', '.', '--parallel', '4'], workingDirectory: buildDir.path);
    if (makeResult.exitCode != 0) {
      logger.severe('CMake build failed: ${makeResult.stderr}\n${makeResult.stdout}');
      throw Exception('CMake build failed');
    }
    
    // 2. Build our C wrapper linking against liboqs
    final packageName = input.packageName;
    final liboqsPath = '${buildDir.path}/lib/liboqs.a';
    
    final flags = <String>[];
    if (osStr == 'macos' || osStr == 'ios') {
      flags.addAll(['-Wl,-force_load', liboqsPath]);
    } else if (osStr == 'android' || osStr == 'linux') {
      flags.addAll(['-Wl,--whole-archive', liboqsPath, '-Wl,--no-whole-archive']);
    } else if (osStr == 'windows') {
      final defFile = File('${buildDir.path}/exports.def');
      final bindingsFile = File('lib/flutter_pqc_bindings_generated.dart');
      if (bindingsFile.existsSync()) {
        final content = bindingsFile.readAsStringSync();
        final regex = RegExp(r'external\s+.*?(OQS_[a-zA-Z0-9_]+)\s*\(');
        final matches = regex.allMatches(content);
        final symbols = matches.map((m) => m.group(1)!).toSet();
        
        final defContent = StringBuffer();
        defContent.writeln('EXPORTS');
        for (final sym in symbols) {
          defContent.writeln('  $sym');
        }
        defFile.writeAsStringSync(defContent.toString());
      } else {
        logger.warning('Could not find bindings file to generate .def');
      }
      
      flags.add(defFile.path);
      flags.add(liboqsPath);
    } else {
      flags.add(liboqsPath);
    }
    
    final cbuilder = CBuilder.library(
      name: packageName,
      assetName: '${packageName}_bindings_generated.dart',
      sources: ['src/$packageName.c'],
      includes: ['src/liboqs/src', '${buildDir.path}/include'],
      flags: flags,
    );
    
    await cbuilder.run(
      input: input,
      output: output,
      logger: logger,
    );
  });
}

String _getAndroidArch(String dartArch) {
  switch (dartArch) {
    case 'arm64': return 'arm64-v8a';
    case 'arm': return 'armeabi-v7a';
    case 'x64': return 'x86_64';
    case 'x86': return 'x86';
    default: return 'arm64-v8a';
  }
}

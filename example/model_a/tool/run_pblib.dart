


import 'package:mhu_dart_pbgen/mhu_dart_pbgen.dart';

Future<void> main() async {
  await runProtoc();
  await runPbLibGenerator();

  // // final dart = lib.pbgenDart;
  // final dart = generatePbLibDart(
  //   package: modelAname,
  //   fileDescriptorSet: fds,
  //   importedPackages: [],
  // );
  // final file = Directory.current.file('lib/src/generated/model_a.pblib.dart');
  //
  // final formatted = dart.formattedDartCode(file);
  // await file.writeAsString(formatted);
  //
  // stdout.writeln(formatted);
  // stdout.writeln(file.uri);
}

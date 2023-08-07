import 'dart:io';

import 'package:mhu_dart_commons/commons.dart';
import 'package:mhu_dart_commons/io.dart';
import 'package:mhu_dart_sourcegen/mhu_dart_sourcegen.dart';

extension ProtocDirectoryX on Directory {
  Directory get dartOut => dirTo(['lib', 'src', 'generated']);

  File get descriptorSetOut => fileTo([
        'proto',
        'generated',
        'descriptor.pb.bin',
      ]);

  Directory get protoPath => dirTo(['proto']);

  File pbFile(String package) => dartOut.file('$package.pb.dart');

  File pbenumFile(String package) => dartOut.file('$package.pbenum.dart');

  File pblibFile(String package) => dartOut.file('$package.pblib.dart');

  File pbfieldFile(String package) => dartOut.file('$package.pbfield.dart');

  File exportFile(String package) => fileTo(['lib', 'proto.dart']);
}

String protoImportUri(String package) =>
    'package:$package/${skipPath(1, (dir) => dir.exportFile(package))}';

String skipPath(int skip, File Function(Directory dir) path) =>
    Directory('.').let(path).filePath.skip(skip + 1).join('/');

Future<void> runProtoc({
  String? packageName,
  List<String> dependencies = const [],
  Directory? cwd,
}) async {
  cwd ??= Directory.current;
  packageName ??= await packageNameFromPubspec(cwd);
  final dartOut = cwd.dartOut;
  await dartOut.create(recursive: true);
  await cwd.descriptorSetOut.parent.create(recursive: true);

  await cwd.run(
    "protoc",
    [
      "--dart_out=${dartOut.path}",
      '--descriptor_set_out=${cwd.descriptorSetOut.path}',
      "--proto_path=${cwd.protoPath.path}",
      for (final dep in dependencies) "--proto_path=${await _protoPath(dep)}",
      cwd.protoPath.file("$packageName.proto").path,
    ],
  );

  for (final dep in dependencies) {
    Future<void> create(File Function(Directory dir) type) async {
      final file = type(cwd!);
      final content = "export '${protoImportUri(dep)}';";
      await file.writeAsString(content);
    }

    await create((d) => d.pbFile(dep));
    await create((d) => d.pbenumFile(dep));
  }

  await cwd.exportFile(packageName).writeAsString([
    'export "${skipPath(1, (dir) => dir.pbFile(packageName!))}";',
    'export "${skipPath(1, (dir) => dir.pblibFile(packageName!))}";',
    'export "${skipPath(1, (dir) => dir.pbfieldFile(packageName!))}";',
  ].joinLines);
}

Future<String> _protoPath(String package) async {
  final root = await packageRootDir(package);
  return root.protoPath.path;
}

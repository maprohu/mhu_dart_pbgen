import 'dart:convert';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:mhu_dart_commons/io.dart';
import 'package:mhu_dart_proto/mhu_dart_proto.dart';
import 'package:mhu_dart_protoc/mhu_dart_protoc.dart';
import 'package:mhu_dart_sourcegen/mhu_dart_sourcegen.dart';
import 'package:recase/recase.dart';

Future<void> runPbLibGenerator({
  String? packageName,
  List<String> dependencies = const [],
  Directory? cwd,
  bool protoc = true,
}) async {
  cwd ??= Directory.current;
  packageName ??= await packageNameFromPubspec(cwd);

  if (protoc) {
    await runProtoc(
      packageName: packageName,
      dependencies: dependencies,
      cwd: cwd,
    );
  }

  final metaFile = cwd.pblibFile(packageName);

  final fileDescriptorSetBytes = await cwd.descriptorSetOut.readAsBytes();

  final fileDescriptorSet =
      FileDescriptorSet.fromBuffer(fileDescriptorSetBytes);

  final content = generatePbLibDart(
    package: packageName,
    importedPackages: dependencies,
    fileDescriptorSet: fileDescriptorSet,
  );

  await metaFile.parent.create(recursive: true);
  await metaFile.writeAsString(
    content.formattedDartCode(
      cwd.fileTo(
        ['.dart_tool', 'mhu', metaFile.filename],
      ),
    ),
  );
  stdout.writeln(
    "wrote: ${metaFile.uri}",
  );
}

typedef MsgOos = ({
  String name,
  DescriptorProto decriptor,
  Iterable<String> oos,
});

extension DescriptorProtoX on DescriptorProto {
  Iterable<MsgOos> messages(IList<String> path) sync* {
    final newPath = path.add(name);
    yield (
      name: newPath.join('_'),
      decriptor: this,
      oos: oneofDecl.map((e) => e.name),
    );
    for (final m in nestedType) {
      if (m.options.mapEntry) continue;
      yield* m.messages(newPath);
    }
  }

  Iterable<String> enums(IList<String> path) sync* {
    final newPath = path.add(name);
    for (final m in enumType) {
      yield newPath.add(m.name).join('_');
    }
    for (final m in nestedType) {
      if (m.options.mapEntry) continue;
      yield* m.enums(newPath);
    }
  }
}

extension FileDescriptorSetX on FileDescriptorSet {
  Iterable<String> get enums sync* {
    for (final f in file) {
      for (final e in f.enumType) {
        yield e.name;
      }
      for (final m in f.messageType) {
        if (m.options.mapEntry) continue;
        yield* m.enums(IList());
      }
    }
  }

  Iterable<MsgOos> get messages sync* {
    for (final f in file) {
      for (final m in f.messageType) {
        if (m.options.mapEntry) continue;
        yield* m.messages(IList());
      }
    }
  }
}

String pblibVarName(String package) => package.camelCase.plus('Lib');

String generatePbLibDart({
  required String package,
  required Iterable<String> importedPackages,
  required FileDescriptorSet fileDescriptorSet,
}) {
  const mdp = r"$mdp";
  return [
    "import 'package:mhu_dart_proto/mhu_dart_proto.dart' as $mdp;",
    "import '$package.pb.dart';",
    for (final dep in importedPackages) "import '${protoImportUri(dep)}';",
    "final ${pblibVarName(package)} = $mdp.PbiLib(",
    "  name: ${package.dartRawSingleQuoteStringLiteral},",
    "  messages: [",
    for (final m in fileDescriptorSet.messages) ...[
      "${m.name}.getDefault().toPbiMessage(",
      "oneofs: [",
      for (final oo in m.oos) ...[
        "const $mdp.PbiOneof(",
        "name: ",
        oo.dartRawSingleQuoteStringLiteral.plusComma,
        "which: ",
        "${m.name}_${oo.pascalCase}.values,",
        "),",
      ],
      "],",
      "tags: [",
      for (final f in m.decriptor.field) f.number.toString().plusComma,
      "],),",
    ],
    "  ], enums: [",
    for (final m in fileDescriptorSet.enums) "$m.values.toPbiEnum,",
    "  ], importedLibraries: [",
    for (final dep in importedPackages) pblibVarName(dep).plusComma,
    "  ],",
    "  fileDescriptorSetBase64: r'${base64.encode(fileDescriptorSet.writeToBuffer())}',",
    ");",
  ].joinLines;
}

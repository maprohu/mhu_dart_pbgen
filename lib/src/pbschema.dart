import 'dart:convert';
import 'dart:io';

import 'package:mhu_dart_annotation/mhu_dart_annotation.dart';
import 'package:mhu_dart_commons/commons.dart';
import 'package:mhu_dart_commons/io.dart';
import 'package:mhu_dart_pbschema/mhu_dart_pbschema.dart';
import 'package:mhu_dart_protoc/mhu_dart_protoc.dart';
import 'package:mhu_dart_sourcegen/mhu_dart_sourcegen.dart';
import 'package:recase/recase.dart';

import 'pbschema.dart' as $lib;

// part 'pbschema.g.has.dart';
part 'pbschema.g.dart';
// part 'pbschema.freezed.dart';

File packagePbschemaFile({
  @ext required Directory packageDir,
  required String packageName,
}) {
  return packageDir.dartOut.file('$packageName.pbschema.dart');
}

Future<void> runPbSchemaGenerator({
  String? packageName,
  List<Pbschema> dependencies = const [],
  Directory? sourcePackageDirectory,
  Directory? targetPackageDirectory,
  bool protoc = true,
}) async {
  sourcePackageDirectory ??= Directory.current;
  targetPackageDirectory ??= Directory.current;
  packageName ??= await packageNameFromPubspec(sourcePackageDirectory);

  final flatDependencies = dependencies
      .pbschemaFlattenHierarchy()
      .map((e) => e.packageName)
      .toList();

  if (protoc) {
    await runProtoc(
      packageName: packageName,
      dependencies: flatDependencies,
      sourcePackageDirectory: sourcePackageDirectory,
      targetPackageDirectory: targetPackageDirectory,
    );
  }

  final metaFile = targetPackageDirectory.packagePbschemaFile(packageName: packageName);

  final fileDescriptorSetBytes = await sourcePackageDirectory.descriptorSetOut.readAsBytes();

  final fileDescriptorSet =
      FileDescriptorSet.fromBuffer(fileDescriptorSetBytes);

  final schemaCollection = fileDescriptorSet.descriptorSchemaCollection(
    messageReference: memoryCreateTypeReference(),
    dependencies: dependencies,
  );

  final schemaCtx = await schemaCollection.schemaCollectionBuildCtx(
    lookupMessageMarkerByName: (messageClassName) => throw messageClassName,
  );

  final content = generatePbschemaDart(
    packageName: packageName,
    importedPackages: flatDependencies,
    messages: schemaCollection.schemaCollectionMessageCtxIterable(
      schemaCtx: schemaCtx,
    ),
    dependencies: dependencies,
    fileDescriptorSetBase64: base64Encode(fileDescriptorSetBytes),
  ).joinLines;

  await metaFile.parent.create(recursive: true);
  await metaFile.writeAsString(
    content.formattedDartCode(
      targetPackageDirectory.fileTo(
        ['.dart_tool', 'mhu', metaFile.filename],
      ),
    ),
  );
  stdout.writeln(
    "wrote: ${metaFile.uri}",
  );
}

String pbschemaVariableName({
  @ext required Pbschema pbschema,
}) {
  return pbschema.packageName.camelCase.plus(nm(Pbschema));
}

Strings importStatement({
  @ext required String uri,
  String? prefix,
}) sync* {
  yield "import";
  yield uri.dartRawSingleQuoteStringLiteral;
  if (prefix != null) {
    yield "as";
    yield prefix;
  }
  yield ';';
}

Strings generatePbschemaDart({
  required String packageName,
  required Iterable<String> importedPackages,
  required Iterable<MessageCtx> messages,
  required List<Pbschema> dependencies,
  required FileDescriptorSetBase64 fileDescriptorSetBase64,
}) sync* {
  const pbschemaPrefix = "\$pbschema";
  const pbschemaRef = "$pbschemaPrefix.";
  const commonsPrefix = "\$commons";
  const commonsRef = "$commonsPrefix.";
  const messageMarkerVar = "messageMarker\$";
  const fieldMarkersVar = "fieldMarkers\$";
  const oneofMarkersVar = "oneofMarkers\$";

  Strings protoImport(String package) sync* {
    yield "import";
    yield "'package:$package/proto.dart'";
    yield ";";
  }

  yield "import 'package:fixnum/fixnum.dart';";
  yield* "package:mhu_dart_pbschema/mhu_dart_pbschema.dart".importStatement(
    prefix: pbschemaPrefix,
  );
  yield* "package:mhu_dart_commons/commons.dart".importStatement(
    prefix: commonsPrefix,
  );

  yield* protoImport(packageName);
  for (final dep in importedPackages) {
    yield* protoImport(dep);
  }

  final pbschema = ComposedPbschema(
    packageName: packageName,
    pbschemaDependencies: dependencies,
    fileDescriptorSetBase64: fileDescriptorSetBase64,
    messageMarkers: [],
  );

  yield "final";
  yield pbschema.pbschemaVariableName();
  yield "=";
  yield pbschemaRef;
  yield nm(ComposedPbschema);
  yield* run(() sync* {
    yield "packageName:";
    yield packageName.dartRawSingleQuoteStringLiteral;
    yield ",";
    yield "pbschemaDependencies:";
    yield* run(() sync* {
      for (final dep in dependencies) {
        yield dep.pbschemaVariableName();
        yield ",";
      }
    }).enclosedInSquareBracket;
    yield ",";
    yield "fileDescriptorSetBase64:";
    yield fileDescriptorSetBase64.dartRawSingleQuoteStringLiteral;
    yield ",";

    yield "messageMarkers:";
    yield* run(() sync* {
      for (final messageCtx in messages) {
        yield messageCtx.messageCtxMarkersClassName();
        yield '.';
        yield messageMarkerVar;
        yield ',';
      }
    }).enclosedInSquareBracket;
    yield ",";
  }).enclosedInParen;
  yield ";";

  for (final messageCtx in messages) {
    final messageTypeName = messageCtx.messageCtxTypeName();
    final markersName = messageCtx.messageCtxMarkersClassName();

    yield "extension";
    yield "$messageTypeName\$OptX";
    yield "on";
    yield messageTypeName;

    yield* run(() sync* {
      for (final field in messageCtx.messageFieldCtxIterable()) {
        final typeActions = field.typeActions;
        final fieldName = field.fieldCtxJsonName();
        final pascalName = fieldName.pascalCase;

        if (typeActions case SingleTypeActions()) {
          yield typeActions.singleTypeName();
          yield "?";
          yield "get";
          yield "${fieldName}Opt";
          yield "=>";
          yield "has$pascalName()";
          yield "?";
          yield fieldName;
          yield ":";
          yield "null";
          yield ";";

          yield "set";
          yield "${fieldName}Opt";
          yield* run(() sync* {
            yield typeActions.singleTypeName();
            yield "?";
            yield "value";
          }).enclosedInParen;
          yield "=>";
          yield "value == null ?";
          yield "clear$pascalName()";
          yield ":";
          yield fieldName;
          yield "= value";
          yield ";";
        }
      }
    }).enclosedInCurly;

    yield "final class";
    yield markersName;
    yield* run(() sync* {
      yield markersName;
      yield "._();";

      yield "static final";
      yield pbschemaRef;
      yield nm(MessageMarker);
      yield* [
        messageTypeName,
      ].enclosedInChevron;
      yield messageMarkerVar;
      yield "=";
      yield pbschemaRef;
      yield "messageMarker";
      yield* run(() sync* {

        yield "msgClassActions:";
        yield messageTypeName;
        yield ".getDefault().staticMsgClassActions(),";

        yield "callFieldMarkers: () =>";
        yield fieldMarkersVar;
        yield ',';
        yield "callOneofMarkers: () =>";
        yield oneofMarkersVar;
        yield ',';
      }).enclosedInParen;
      yield ';';

      yield "static";
      yield messageTypeName;
      yield "create";
      yield* run(() sync* {
        for (final field in messageCtx.messageFieldCtxIterable()) {
          final typeActions = field.typeActions;
          final fieldName = field.fieldCtxJsonName();

          switch (typeActions) {
            case SingleTypeActions():
              yield typeActions.singleTypeName();
            case RepeatedTypeActions():
              yield "Iterable";
              yield* [
                typeActions.collectionElementTypeActions.singleTypeName(),
              ].enclosedInChevron;
            case MapTypeActions():
              yield "Map";
              yield* [
                typeActions.mapKeyTypeActions.scalarTypeName(),
                typeActions.collectionElementTypeActions.singleTypeName(),
              ].separatedByCommas.enclosedInChevron;
          }
          yield '?';
          yield fieldName;
          yield ',';
        }
      }).enclosedInCurlyOrEmpty.enclosedInParen;
      yield* run(() sync* {
        const result = "result\$";
        yield "final";
        yield result;
        yield '=';
        yield messageTypeName;
        yield "();";

        for (final field in messageCtx.messageFieldCtxIterable()) {
          final typeActions = field.typeActions;
          final fieldName = field.fieldCtxJsonName();

          yield "if ($fieldName != null)";

          yield* run(() sync* {
            yield result;
            yield '.';
            yield fieldName;
            switch (typeActions) {
              case SingleTypeActions():
                yield '=';
                yield fieldName;

              case RepeatedTypeActions():
              case MapTypeActions():
                yield '.';
                yield "addAll";
                yield* [fieldName].enclosedInParen;
            }
            yield ';';
          }).enclosedInCurly;
        }

        yield "return";
        yield result;
        yield ';';
      }).enclosedInCurly;

      yield "static final";
      yield fieldMarkersVar;
      yield "=";
      yield* [
        pbschemaRef,
        nm(FieldMarker),
        ...[
          messageTypeName,
          "dynamic",
        ].separatedByCommas.enclosedInChevron,
      ].enclosedInChevron;
      yield* run(() sync* {
        for (final field in messageCtx.messageFieldCtxIterable()) {
          yield field.fieldMsg.fieldInfo.description.jsonName;
          yield ',';
        }
      }).enclosedInSquareBracket;
      yield ';';

      yield "static final";
      yield oneofMarkersVar;
      yield "=";
      yield* [
        pbschemaRef,
        nm(OneofMarker),
        ...[messageTypeName].enclosedInChevron,
      ].enclosedInChevron;
      yield* run(() sync* {
        for (final field in messageCtx.messageOneofCtxIterable()) {
          yield field.oneofMsg.description.jsonName;
          yield ',';
        }
      }).enclosedInSquareBracket;
      yield ';';

      for (final fieldCtx in messageCtx.messageFieldCtxIterable()) {
        final fieldProtoName =
            fieldCtx.fieldMsg.fieldInfo.description.protoName;
        final fieldJsonName = fieldCtx.fieldMsg.fieldInfo.description.jsonName;
        yield "static final";
        yield fieldJsonName;
        yield "=";

        final typeActions = fieldCtx.typeActions;
        final fieldName = fieldCtx.fieldCtxJsonName();

        Strings field<M extends FieldMarker>({
          required Iterable<String> typeArgs,
          required Strings markerParams,
        }) sync* {
          yield pbschemaRef;
          yield nm(M);
          yield* [
            messageTypeName,
            ...typeArgs,
          ].separatedByCommas.enclosedInChevron;
          yield* run(() sync* {
            yield "fieldProtoName:";
            yield fieldProtoName.dartRawSingleQuoteStringLiteral;
            yield ',';
            yield 'tagNumberValue:';
            yield fieldCtx.fieldCtxTagNumber().toString();
            yield ',';
            yield* markerParams;
          }).enclosedInParen;
        }

        Strings singleMarkerParams() sync* {
          yield "readAttribute: (msg) => msg.";
          yield "${fieldName}Opt";
          yield ',';
          yield "writeAttribute: (msg, value) => msg.";
          yield "${fieldName}Opt";
          yield "= value";
          yield ',';
        }

        Strings valueMessageMarker({
          required MessageTypeActions messageTypeActions,
        }) sync* {
          yield "valueMessageMarker:";
          yield messageTypeActions.messageCtx.messageCtxMarkersClassName();
          yield ".";
          yield messageMarkerVar;
          yield ",";
        }

        switch (typeActions) {
          case ScalarTypeActions():
            yield* field<ComposedScalarFieldMarker>(
              typeArgs: [
                typeActions.singleTypeName(),
              ],
              markerParams: singleMarkerParams(),
            );
          case MessageTypeActions():
            yield* field<ComposedMessageFieldMarker>(
              typeArgs: [
                typeActions.singleTypeName(),
              ],
              markerParams: [
                ...singleMarkerParams(),
                ...valueMessageMarker(messageTypeActions: typeActions),
              ],
            );
          case EnumTypeActions():
            yield* field<ComposedEnumFieldMarker>(
              typeArgs: [
                typeActions.singleTypeName(),
              ],
              markerParams: singleMarkerParams(),
            );
          case RepeatedTypeActions():
            yield* field<ComposedRepeatedFieldMarker>(
              typeArgs: [
                typeActions.collectionElementTypeActions.singleTypeName(),
              ],
              markerParams: [],
            );
          case MapTypeActions():
            yield* field<ComposedMapFieldMarker>(
              typeArgs: [
                typeActions.mapKeyTypeActions.scalarTypeName(),
                typeActions.collectionElementTypeActions.singleTypeName(),
              ],
              markerParams: [],
            );
        }
        yield ";";
      }

      for (final logicalField in messageCtx.messageOneofCtxIterable()) {
        final fieldProtoName = logicalField.oneofMsg.description.protoName;
        final fieldJsonName = logicalField.oneofMsg.description.jsonName;
        yield "static final";
        yield fieldJsonName;
        yield "=";

        yield pbschemaRef;
        yield nm(ComposedOneofMarker);
        yield* [
          messageTypeName,
        ].enclosedInChevron;
        yield* run(() sync* {
          yield "fieldProtoName:";
          yield fieldProtoName.dartRawSingleQuoteStringLiteral;
          yield ',';
          yield 'oneofIndex:';
          yield logicalField.oneofMsg.oneofIndex.toString();
          yield ',';
        }).enclosedInParen;

        yield ";";
      }
    }).enclosedInCurly;

    for (final logicalField in messageCtx.callLogicalFieldsList()) {
      switch (logicalField) {
        case FieldCtx():
          final typeActions = logicalField.typeActions;
          final fieldName = logicalField.fieldCtxJsonName();

          Strings method() sync* {
            switch (typeActions) {
              case MessageTypeActions():
                yield commonsRef;
                yield nm(WatchProto);
                yield* [
                  typeActions.messageCtx.messageCtxTypeName(),
                ].enclosedInChevron;
                yield "get";
                yield fieldName;
                yield "=>";
                yield "// ignore: unnecessary_this";
                yield "this.mapWatchProtoMessage";
                yield* run(() sync* {
                  yield "readWriteAttribute:";
                  yield markersName;
                  yield ".";
                  yield fieldName;
                  yield ",";
                  yield "defaultMessage:";
                  yield typeActions.messageCtx.messageCtxTypeName();
                  yield ".getDefault()";
                  yield ",";
                }).enclosedInParen;
                yield ";";

              case SingleTypeActions():
                yield commonsRef;
                yield nm(WatchWrite);
                yield* [
                  typeActions.singleTypeName(),
                  "?",
                ].enclosedInChevron;
                yield "get";
                yield fieldName;
                yield "=>";
                yield "// ignore: unnecessary_this";
                yield "this.mapWatchProtoWrite";
                yield* run(() sync* {
                  yield "readWriteAttribute:";
                  yield markersName;
                  yield ".";
                  yield fieldName;
                  yield ",";
                }).enclosedInParen;
                yield ";";

              case RepeatedTypeActions():
              case MapTypeActions():
            }
          }

          yield "extension";
          yield messageTypeName.plusDollar
              .plus(fieldName)
              .plusDollar
              .plus("WatchExt");
          yield "on";
          yield commonsRef;
          yield nm(WatchProto);
          yield* [
            messageTypeName,
          ].enclosedInChevron;

          yield* method().enclosedInCurly;

        case OneofCtx():
      }
    }
  }
}

String scalarTypeName(
  @ext ScalarTypeLogicActions typeActions,
) {
  return typeActions.singleTypeGeneric(
    <T extends Object>() => T.toString(),
  );
}

String singleTypeName(
  @ext SingleTypeActions typeActions,
) {
  switch (typeActions) {
    case ScalarTypeActions():
      return typeActions.scalarTypeName();
    case MessageTypeActions():
      return typeActions.messageCtx.messageCtxTypeName();
    case EnumTypeActions():
      return typeActions.enumCtx.enumCtxTypeName();
  }
}

String messageCtxMarkersClassName({
  @ext required MessageCtx messageCtx,
}) {
  return messageCtx.messageCtxTypeName().plusDollar;
}

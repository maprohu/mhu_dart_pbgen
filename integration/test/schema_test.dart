import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:mhu_dart_commons/commons.dart';
import 'package:mhu_dart_pbschema/mhu_dart_pbschema.dart';
import 'package:model_dart_pbgen_integration/proto.dart';
import 'package:protobuf/protobuf.dart';
import 'package:test/test.dart';

void main() {
  test('proto schema', () async {
    final descriptorFile = File("proto/generated/descriptor.pb.bin");
    final fileDescriptorSet =
        descriptorFile.readAsBytesSync().let(FileDescriptorSet.fromBuffer);

    final schemaLookupByName =
        await fileDescriptorSet.descriptorSchemaLookupByName(
      dependencies: [],
    );

    final fieldTypesCtx =
        schemaLookupByName.lookupMessageCtxOfType<TstFieldTypesMsg>();

    final int32ValueAccess = TstFieldTypesMsg$.int32Value;

    final fieldTypesMsg1 = TstFieldTypesMsg$.create(
      int32Value: 1,
    )..freeze();

    final fields = fieldTypesCtx.messageFieldCtxIterable().toList();

    final int32ValueCtx = fields.singleWhere(
      (e) => e.fieldCtxTagNumber() == int32ValueAccess.tagNumberValue,
    );

    final typeActions = int32ValueCtx.typeActions as ScalarTypeActions<int>;

    final int32ValueFieldCoordinates = int32ValueCtx.callFieldCoordinates();
    final fieldTypesMsg2 = fieldTypesMsg1.rebuild(
      (msg) {
        typeActions.writeFieldValue(
          msg,
          int32ValueFieldCoordinates,
          2,
        );
      },
    );

    expect(fieldTypesMsg2.int32Value, 2);

    final genericMsg = fieldTypesCtx.createGenericMsg()..freeze();

    final genericFieldTypesMsg3 = genericMsg.rebuild(
      (msg) {
        typeActions.writeFieldValue(
          msg,
          int32ValueFieldCoordinates,
          3,
        );
      },
    );

    final readGeneric = typeActions.readFieldValue(
      genericFieldTypesMsg3,
      int32ValueFieldCoordinates.fieldIndex,
    );

    expect(readGeneric, 3);
  });
}

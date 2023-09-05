import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:mhu_dart_commons/commons.dart';
import 'package:mhu_dart_pbschema/mhu_dart_pbschema.dart';
import 'package:model_dart_pbgen_integration/proto.dart';
import 'package:protobuf/protobuf.dart';
import 'package:test/test.dart';

void main() {
  test('proto attr', () async {
    final tstWatch = watchVar(
      TstFieldTypesMsg.getDefault(),
    ).watchWriteMessage(
      getDefault: TstFieldTypesMsg.getDefault,
    );

    tstWatch.rebuildWatchProto((object) {
      object.stringValue = "x";
    });

    tstWatch.stringValue.value = "y";

  });
}

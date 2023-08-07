import 'dart:io';

import 'package:mhu_dart_commons/io.dart';
import 'package:mhu_dart_pbgen/src/protoc.dart';
import 'package:mhu_dart_proto/mhu_dart_proto.dart';

final modelAname = 'model_a';
final modelAdir = Directory.current.dir('example/model_a');

final modelAfds =
    modelAdir.descriptorSetOut.readAsBytes().then(FileDescriptorSet.fromBuffer);

final modelArunProtoc = runProtoc(
  packageName: modelAname,
  cwd: modelAdir,
);

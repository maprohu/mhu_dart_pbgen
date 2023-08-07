import 'dart:io';

import 'package:mhu_dart_commons/io.dart';

import 'run_pblib.dart' as lib;

Future<void> main() async {
  await lib.main();

  Directory.current.run(
    'dart',
    ['tool/run_pbfield.dart'],
  );

}
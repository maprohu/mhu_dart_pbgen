
import 'package:mhu_dart_pbgen/mhu_dart_pbgen.dart';
import 'package:model_a/src/generated/model_a.pblib.dart';


void main() async {
  runPbFieldGenerator(lib: modelALib);
}

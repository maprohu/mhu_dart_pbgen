import 'package:model_a/src/generated/model_a.pb.dart';

import 'src/generated/model_a.pbfield.dart';

void main() {
  final a = MsgA();

  // final bi = a.info_;

  // final GeneratedMessage gm = a;

  MsgA$.fldMessage.set(a, MsgB());


  MsgA$.optDouble.set(a, 2);

  print(a);

  print(MsgA$.ooSample2.which(a));
}

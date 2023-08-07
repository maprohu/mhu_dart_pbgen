import 'dart:io';


import 'package:model_a/proto.dart';

import 'model_a.dart';

void main() async {
  await modelArunProtoc;
  stdout.write(await modelAfds);

  final bi = OrderTest.getDefault().info_;
  print(bi.byIndex);
}

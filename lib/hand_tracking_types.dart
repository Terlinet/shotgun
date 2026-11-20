import 'package:flutter/widgets.dart';

class HandPose {
  const HandPose({
    required this.x,
    required this.y,
    required this.isPinching,
    this.isPoking = false,
  });

  final double x;
  final double y;
  final bool isPinching;
  final bool isPoking;
}

typedef HandPoseCallback = void Function(HandPose? pose);
typedef HandStatusCallback = void Function(String status);

abstract interface class HandTrackingController {
  Widget buildPreview();

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}

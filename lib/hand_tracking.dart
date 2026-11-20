import 'package:flutter/widgets.dart';

import 'hand_tracking_stub.dart'
    if (dart.library.html) 'hand_tracking_web.dart'
    as platform;
import 'hand_tracking_types.dart';

export 'hand_tracking_types.dart';

HandTrackingController createHandTrackingController({
  required HandPoseCallback onPose,
  required HandStatusCallback onStatus,
}) => platform.createHandTrackingController(onPose: onPose, onStatus: onStatus);

class HandTrackingService {
  HandTrackingService._() {
    _controller = createHandTrackingController(
      onPose: (pose) => this.pose.value = pose,
      onStatus: (status) => this.status.value = status,
    );
  }

  static final HandTrackingService instance = HandTrackingService._();

  late final HandTrackingController _controller;
  final ValueNotifier<HandPose?> pose = ValueNotifier(null);
  final ValueNotifier<String> status = ValueNotifier('Câmera desligada');
  final ValueNotifier<bool> isActive = ValueNotifier(false);
  bool _isBusy = false;

  bool get isBusy => _isBusy;

  Widget buildPreview() => _controller.buildPreview();

  Future<void> start() async {
    if (_isBusy || isActive.value) return;
    _isBusy = true;
    try {
      await _controller.start();
      isActive.value = true;
    } finally {
      _isBusy = false;
    }
  }

  Future<void> stop() async {
    if (_isBusy || !isActive.value) return;
    _isBusy = true;
    try {
      await _controller.stop();
      isActive.value = false;
      pose.value = null;
    } finally {
      _isBusy = false;
    }
  }
}

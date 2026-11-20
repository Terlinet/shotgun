import 'package:flutter/material.dart';

import 'hand_tracking_types.dart';

HandTrackingController createHandTrackingController({
  required HandPoseCallback onPose,
  required HandStatusCallback onStatus,
}) => _UnsupportedHandTrackingController(onStatus);

class _UnsupportedHandTrackingController implements HandTrackingController {
  _UnsupportedHandTrackingController(this._onStatus);

  final HandStatusCallback _onStatus;

  @override
  Widget buildPreview() => const ColoredBox(
    color: Color(0xFF120B24),
    child: Center(
      child: Icon(Icons.videocam_off_rounded, color: Color(0xFF00F5FF)),
    ),
  );

  @override
  Future<void> start() async {
    const message = 'A câmera com pinça está disponível na versão Web.';
    _onStatus(message);
    throw UnsupportedError(message);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'hand_tracking_types.dart';

@JS('bubblesStartHandTracking')
external JSPromise<JSAny?> _startHandTracking(
  web.HTMLVideoElement video,
  JSFunction onPose,
);

@JS('bubblesStopHandTracking')
external JSPromise<JSAny?> _stopHandTracking();

int _nextCameraId = 0;

HandTrackingController createHandTrackingController({
  required HandPoseCallback onPose,
  required HandStatusCallback onStatus,
}) => _WebHandTrackingController(onPose, onStatus);

class _WebHandTrackingController implements HandTrackingController {
  _WebHandTrackingController(this._onPose, this._onStatus) {
    _viewType = 'bubbles-chain-camera-${_nextCameraId++}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );
  }

  final HandPoseCallback _onPose;
  final HandStatusCallback _onStatus;
  final web.HTMLVideoElement _video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', '')
    ..style.objectFit = 'cover'
    ..style.width = '100%'
    ..style.height = '100%';

  late final String _viewType;
  bool _isRunning = false;
  bool _isDisposed = false;

  @override
  Widget buildPreview() => HtmlElementView(viewType: _viewType);

  @override
  Future<void> start() async {
    if (_isRunning) return;
    _onStatus('Solicitando permissão da câmera…');
    await _startHandTracking(_video, _receivePose.toJS).toDart;
    if (_isDisposed) {
      await _stopHandTracking().toDart;
      return;
    }
    _isRunning = true;
  }

  void _receivePose(
    JSNumber x,
    JSNumber y,
    JSBoolean isPinching,
    JSBoolean isPoking,
    JSBoolean hasHand,
  ) {
    if (_isDisposed) return;
    if (!hasHand.toDart) {
      _onPose(null);
      _onStatus('Câmera ativa · mostre sua mão');
      return;
    }

    final pinching = isPinching.toDart;
    _onPose(
      HandPose(
        x: x.toDartDouble,
        y: y.toDartDouble,
        isPinching: pinching,
        isPoking: isPoking.toDart,
      ),
    );
    _onStatus(
      pinching
          ? 'Pinça fechada · mova para posicionar'
          : isPoking.toDart
          ? 'Indicador à frente · clique por gesto'
          : 'Pinça aberta · peça parada; feche para mover',
    );
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _stopHandTracking().toDart;
    _onPose(null);
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await stop();
    _video.removeAttribute('src');
  }
}

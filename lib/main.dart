import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'hand_tracking.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BubbleGunScreen(),
    );
  }
}

class BubbleGunScreen extends StatefulWidget {
  const BubbleGunScreen({super.key});

  @override
  State<BubbleGunScreen> createState() => _BubbleGunScreenState();
}

class _BubbleGunScreenState extends State<BubbleGunScreen>
    with TickerProviderStateMixin {
  late final VideoPlayerController _videoController;
  late final AnimationController _shotController;
  late final AnimationController _explosionController;
  final AudioPlayer _shotAudioPlayer = AudioPlayer();
  final AudioPlayer _targetAudioPlayer = AudioPlayer();
  final AudioPlayer _laughAudioPlayer = AudioPlayer();
  final HandTrackingService _handTracking = HandTrackingService.instance;
  final Random _random = Random();
  Timer? _respawnTimer;
  bool _wasPinching = false;
  bool _isShooting = false;
  bool _cameraBusy = false;
  bool _targetVisible = true;
  bool _targetExploding = false;
  bool _laughVisible = false;
  double _gunPosition = 0.5;
  double _targetPosition = 0.5;
  DateTime _lastShot = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _shotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addStatusListener(_handleExplosionStatus);
    _handTracking.pose.addListener(_handleHandPose);
    _handTracking.isActive.addListener(_syncCameraState);
    _videoController =
        VideoPlayerController.asset('assets/videos/BubblesChain.mp4')
          ..setLooping(true)
          ..setVolume(0)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController.play();
            }
          });
  }

  @override
  void dispose() {
    _handTracking.pose.removeListener(_handleHandPose);
    _handTracking.isActive.removeListener(_syncCameraState);
    _respawnTimer?.cancel();
    _shotController.dispose();
    _explosionController.dispose();
    _videoController.dispose();
    _shotAudioPlayer.dispose();
    _targetAudioPlayer.dispose();
    _laughAudioPlayer.dispose();
    super.dispose();
  }

  void _syncCameraState() {
    if (mounted) setState(() {});
  }

  void _handleHandPose() {
    final pose = _handTracking.pose.value;
    if (pose == null) {
      _wasPinching = false;
      return;
    }

    final triggerPulled = pose.isPoking || (pose.isPinching && !_wasPinching);
    _wasPinching = pose.isPinching;
    final nextPosition = pose.x.clamp(0.0, 1.0);
    if ((_gunPosition - nextPosition).abs() > 0.002) {
      setState(() => _gunPosition = nextPosition);
    }
    if (triggerPulled) {
      _fireShot();
    }
  }

  Future<void> _fireShot() async {
    final now = DateTime.now();
    if (now.difference(_lastShot).inMilliseconds < 350) return;
    _lastShot = now;
    final size = MediaQuery.sizeOf(context);
    await _shotAudioPlayer.stop();
    await _shotAudioPlayer.play(
      AssetSource('tirosom.mp3'),
      mode: PlayerMode.lowLatency,
    );
    final gunWidth = min(280.0, size.width * 0.72);
    final targetWidth = min(150.0, size.width * 0.34);
    final gunCenter = (_gunPosition * size.width).clamp(
      gunWidth / 2,
      size.width - gunWidth / 2,
    );
    final targetCenter = (_targetPosition * size.width).clamp(
      targetWidth / 2,
      size.width - targetWidth / 2,
    );
    final hitTarget =
        _targetVisible &&
        !_targetExploding &&
        (gunCenter - targetCenter).abs() <= (gunWidth + targetWidth) / 2;

    setState(() => _isShooting = true);
    if (hitTarget) _explodeTarget();
    await _shotController.forward(from: 0);
    await _shotController.reverse();
    if (mounted) setState(() => _isShooting = false);
  }

  Future<void> _explodeTarget() async {
    await _targetAudioPlayer.stop();
    final screamCompleted = _targetAudioPlayer.onPlayerComplete.first;
    await _targetAudioPlayer.play(
      AssetSource('gritomale.mp3'),
      mode: PlayerMode.lowLatency,
    );
    setState(() => _targetExploding = true);
    _explosionController.forward(from: 0);
    await screamCompleted;
    if (!mounted) return;

    setState(() => _laughVisible = true);
    await _laughAudioPlayer.stop();
    final laughCompleted = _laughAudioPlayer.onPlayerComplete.first;
    await _laughAudioPlayer.play(
      AssetSource('picapau.mp3'),
      mode: PlayerMode.lowLatency,
    );
    await laughCompleted;
    if (mounted) setState(() => _laughVisible = false);
  }

  void _handleExplosionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _targetVisible = false;
      _targetExploding = false;
    });
    _respawnTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _targetPosition = 0.12 + (_random.nextDouble() * 0.76);
        _targetVisible = true;
      });
    });
  }

  Future<void> _toggleCamera() async {
    if (_cameraBusy) return;
    setState(() => _cameraBusy = true);
    try {
      if (_handTracking.isActive.value) {
        await _handTracking.stop();
      } else {
        await _handTracking.start();
      }
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconhecimento disponível na versão Web.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final gunWidth = min(280.0, screenSize.width * 0.72);
    final targetWidth = min(150.0, screenSize.width * 0.34);
    final gunLeft = (_gunPosition * screenSize.width - gunWidth / 2).clamp(
      0.0,
      screenSize.width - gunWidth,
    );
    final targetLeft = (_targetPosition * screenSize.width - targetWidth / 2)
        .clamp(0.0, screenSize.width - targetWidth);
    final aimCenter = (_gunPosition * screenSize.width).clamp(
      gunWidth / 2,
      screenSize.width - gunWidth / 2,
    );
    final targetCenter = (_targetPosition * screenSize.width).clamp(
      targetWidth / 2,
      screenSize.width - targetWidth / 2,
    );
    final isAimingAtTarget =
        _targetVisible &&
        !_targetExploding &&
        (aimCenter - targetCenter).abs() <= (gunWidth + targetWidth) / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            const ColoredBox(color: Colors.black),
          if (_targetVisible)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              left: targetLeft,
              top: screenSize.height * 0.28,
              width: targetWidth,
              height: targetWidth,
              child: _targetExploding
                  ? AnimatedBuilder(
                      animation: _explosionController,
                      builder: (context, child) {
                        final progress = _explosionController.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: 0.5 + progress * 1.5,
                              child: Opacity(
                                opacity: 1 - progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.yellow.withValues(alpha: 0.95),
                                        Colors.orange.withValues(alpha: 0.75),
                                        Colors.red.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Opacity(opacity: 1 - progress, child: child),
                          ],
                        );
                      },
                      child: Image.asset(
                        'assets/videos/pepe.gif',
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset('assets/videos/pepe.gif', fit: BoxFit.contain),
            ),
          if (_laughVisible)
            Positioned(
              top: screenSize.height * 0.14,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Image.asset(
                    'assets/pengurindo.gif',
                    width: min(220.0, screenSize.width * 0.55),
                    height: min(220.0, screenSize.width * 0.55),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          Positioned(
            left: aimCenter - 22,
            top: screenSize.height * 0.28 + targetWidth / 2 - 22,
            child: IgnorePointer(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAimingAtTarget
                        ? Colors.greenAccent
                        : Colors.white.withValues(alpha: 0.9),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isAimingAtTarget
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),
                    Positioned(
                      top: 3,
                      child: Container(
                        width: 2,
                        height: 8,
                        color: isAimingAtTarget
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: 2,
                        height: 8,
                        color: isAimingAtTarget
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),
                    Positioned(
                      left: 3,
                      child: Container(
                        width: 8,
                        height: 2,
                        color: isAimingAtTarget
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),
                    Positioned(
                      right: 3,
                      child: Container(
                        width: 8,
                        height: 2,
                        color: isAimingAtTarget
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            left: gunLeft,
            bottom: 24,
            width: gunWidth,
            height: gunWidth,
            child: AnimatedBuilder(
              animation: _shotController,
              builder: (context, child) {
                final recoil = _shotController.value * 14;
                return Transform.translate(
                  offset: Offset(0, recoil),
                  child: Transform.scale(
                    scale: 1 + (_shotController.value * 0.025),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: gunWidth,
                height: gunWidth,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    if (_isShooting)
                      Positioned(
                        top: 18,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white,
                                Colors.yellow.withValues(alpha: 0.9),
                                Colors.orange.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        'assets/tirosemfundo.png',
                        width: gunWidth,
                        height: gunWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: Image.asset(
              'assets/videos/gun-shoot.gif',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _cameraBusy ? null : _toggleCamera,
                icon: Icon(
                  _handTracking.isActive.value
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                ),
                label: Text(
                  _cameraBusy
                      ? 'Aguarde'
                      : _handTracking.isActive.value
                      ? 'Câmera ativa'
                      : 'Ativar gesto',
                ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 24,
            child: SafeArea(
              child: IgnorePointer(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w100,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'E R L I N E',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w100,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

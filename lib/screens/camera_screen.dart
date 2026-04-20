import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pose_suggestion.dart';
import '../models/pose_template.dart';
import '../services/pose_service.dart';
import '../widgets/pose_silhouette_painter.dart';
import '../widgets/match_ring_painter.dart';
import '../widgets/suggestion_sheet.dart';
import '../env.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Camera
  CameraController? _controller;
  int _cameraIndex = 0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  // ML Kit
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  List<Pose> _poses = [];
  bool _processingPose = false;

  // AI suggestions
  final PoseService _poseService = PoseService(apiKey: Env.openAiApiKey);
  bool _fetchingSuggestions = false;
  PoseSuggestion? _activeSuggestion;
  double _matchScore = 0.0;
  Color _accentColor = kAccentColors[0];

  // Auto-capture
  bool _autoCaptureFired = false;

  // Coaching hint
  String? _coachingHint;
  DateTime _lastCoachUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  // Post-capture overlay
  Uint8List? _lastCaptureBytes;
  bool _showPostCapture = false;

  // Animations
  late AnimationController _silhouetteController;
  late AnimationController _flashController;
  late Animation<double> _silhouetteOpacity;
  late Animation<double> _flashOpacity;

  // UI state
  bool _showGrid = false;
  bool _timerActive = false;
  int _timerCountdown = 3;
  bool _takingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _silhouetteController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _silhouetteOpacity =
        CurvedAnimation(parent: _silhouetteController, curve: Curves.easeInOut);

    _flashController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _flashOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _flashController, curve: Curves.easeOut));

    _requestAndInit();
  }

  Future<void> _requestAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) await _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    final cam = widget.cameras[_cameraIndex];
    _controller = CameraController(
      cam, ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    if (!mounted) return;
    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    _currentZoom = 1.0;
    _controller!.startImageStream(_onFrame);
    setState(() {});
  }

  void _onFrame(CameraImage image) async {
    if (_processingPose) return;
    _processingPose = true;
    try {
      final input = _buildInputImage(image);
      if (input == null) return;
      final poses = await _poseDetector.processImage(input);
      if (!mounted) return;

      double newScore = 0;
      String? newHint;

      if (_activeSuggestion != null && poses.isNotEmpty) {
        newScore = _computeMatch(poses.first, _activeSuggestion!.poseType);

        // Throttle coaching hint to once per second
        final now = DateTime.now();
        if (now.difference(_lastCoachUpdate).inMilliseconds > 900) {
          _lastCoachUpdate = now;
          newHint = newScore < 0.85
              ? _computeCoachingHint(poses.first, _activeSuggestion!.poseType)
              : null;
        } else {
          newHint = _coachingHint;
        }

        // Auto-capture at 90% match
        if (newScore >= 0.90 && !_autoCaptureFired && !_takingPhoto && !_timerActive) {
          _autoCaptureFired = true;
          HapticFeedback.heavyImpact();
          _capturePhoto();
        }
      }

      setState(() {
        _poses = poses;
        _matchScore = newScore;
        _coachingHint = newHint;
      });
    } finally {
      _processingPose = false;
    }
  }

  double _computeMatch(Pose detected, PoseType targetType) {
    final template = PoseTemplate.all[targetType];
    if (template == null) return 0;

    final pairs = <List<dynamic>>[
      ['lShoulder', PoseLandmarkType.leftShoulder],
      ['rShoulder', PoseLandmarkType.rightShoulder],
      ['lElbow', PoseLandmarkType.leftElbow],
      ['rElbow', PoseLandmarkType.rightElbow],
      ['lWrist', PoseLandmarkType.leftWrist],
      ['rWrist', PoseLandmarkType.rightWrist],
      ['lHip', PoseLandmarkType.leftHip],
      ['rHip', PoseLandmarkType.rightHip],
    ];

    double minX = double.infinity, maxX = 0, minY = double.infinity, maxY = 0;
    for (final lm in detected.landmarks.values) {
      if (lm.x < minX) minX = lm.x;
      if (lm.x > maxX) maxX = lm.x;
      if (lm.y < minY) minY = lm.y;
      if (lm.y > maxY) maxY = lm.y;
    }
    final rangeX = (maxX - minX).clamp(1.0, double.infinity);
    final rangeY = (maxY - minY).clamp(1.0, double.infinity);

    double totalScore = 0;
    int count = 0;

    for (final pair in pairs) {
      final templateKey = pair[0] as String;
      final detectedKey = pair[1] as PoseLandmarkType;
      final tPos = template.landmarks[templateKey];
      final dLm = detected.landmarks[detectedKey];
      if (tPos == null || dLm == null || dLm.likelihood < 0.5) continue;

      final dNormX = (dLm.x - minX) / rangeX;
      final dNormY = (dLm.y - minY) / rangeY;
      final dist = sqrt(pow(dNormX - tPos.dx, 2) + pow(dNormY - tPos.dy, 2));
      totalScore += (1 - dist.clamp(0.0, 1.0));
      count++;
    }

    return count > 0 ? (totalScore / count).clamp(0.0, 1.0) : 0.0;
  }

  String? _computeCoachingHint(Pose detected, PoseType targetType) {
    final template = PoseTemplate.all[targetType];
    if (template == null) return null;

    double minX = double.infinity, maxX = 0, minY = double.infinity, maxY = 0;
    for (final lm in detected.landmarks.values) {
      if (lm.x < minX) minX = lm.x;
      if (lm.x > maxX) maxX = lm.x;
      if (lm.y < minY) minY = lm.y;
      if (lm.y > maxY) maxY = lm.y;
    }
    final rangeX = (maxX - minX).clamp(1.0, double.infinity);
    final rangeY = (maxY - minY).clamp(1.0, double.infinity);

    final joints = <List<dynamic>>[
      ['lWrist', PoseLandmarkType.leftWrist],
      ['rWrist', PoseLandmarkType.rightWrist],
      ['lElbow', PoseLandmarkType.leftElbow],
      ['rElbow', PoseLandmarkType.rightElbow],
      ['lShoulder', PoseLandmarkType.leftShoulder],
      ['rShoulder', PoseLandmarkType.rightShoulder],
    ];

    String? worstHint;
    double worstDist = 0.12; // minimum threshold to show any hint

    for (final joint in joints) {
      final key = joint[0] as String;
      final type = joint[1] as PoseLandmarkType;
      final tPos = template.landmarks[key];
      final dLm = detected.landmarks[type];
      if (tPos == null || dLm == null || dLm.likelihood < 0.5) continue;

      final dNormX = (dLm.x - minX) / rangeX;
      final dNormY = (dLm.y - minY) / rangeY;
      final dx = dNormX - tPos.dx;
      final dy = dNormY - tPos.dy;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist > worstDist) {
        final hint = _hintForJoint(key, dx, dy);
        if (hint != null) {
          worstDist = dist;
          worstHint = hint;
        }
      }
    }

    return worstHint;
  }

  String? _hintForJoint(String joint, double dx, double dy) {
    final side = joint.startsWith('l') ? 'left' : 'right';
    if (joint == 'lWrist' || joint == 'rWrist') {
      if (dy > 0.12) return 'Lift your $side hand';
      if (dy < -0.12) return 'Lower your $side hand';
      if (dx.abs() > 0.15) return dx > 0 ? 'Bring your $side hand in' : 'Stretch your $side hand out';
    } else if (joint == 'lElbow' || joint == 'rElbow') {
      if (dy > 0.12) return 'Raise your $side elbow';
      if (dy < -0.12) return 'Lower your $side elbow';
      if (dx.abs() > 0.15) return dx > 0 ? 'Pull your $side elbow in' : 'Push your $side elbow out';
    } else if (joint == 'lShoulder' || joint == 'rShoulder') {
      if (dy.abs() > 0.10) return dy > 0 ? 'Drop your $side shoulder' : 'Lift your $side shoulder';
    }
    return null;
  }

  InputImage? _buildInputImage(CameraImage image) {
    final cam = widget.cameras[_cameraIndex];
    final sensorOri = cam.sensorOrientation;
    final rotation = cam.lensDirection == CameraLensDirection.front
        ? InputImageRotationValue.fromRawValue(360 - sensorOri)
        : InputImageRotationValue.fromRawValue(sensorOri);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _getSuggestions() async {
    if (_poses.isEmpty) { _toast('Step into frame first'); return; }
    setState(() => _fetchingSuggestions = true);
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      final suggestions = await _poseService.getSuggestions(
          imageBytes: bytes, personCount: _poses.length);
      if (!mounted) return;
      await SuggestionSheet.show(context,
          suggestions: suggestions, onSelected: _selectSuggestion);
    } catch (_) {
      _toast('Could not fetch suggestions. Check internet.');
    } finally {
      if (mounted) setState(() => _fetchingSuggestions = false);
    }
  }

  void _selectSuggestion(PoseSuggestion s) {
    _silhouetteController.forward(from: 0);
    setState(() {
      _activeSuggestion = s;
      _matchScore = 0;
      _coachingHint = null;
      _autoCaptureFired = false;
      _accentColor = accentForPoseType(s.poseType);
    });
  }

  Future<void> _capturePhoto() async {
    if (_takingPhoto) return;
    HapticFeedback.mediumImpact();
    setState(() => _takingPhoto = true);
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      await Gal.putImage(xFile.path);
      if (mounted) {
        setState(() {
          _lastCaptureBytes = bytes;
          _showPostCapture = true;
        });
        Future.delayed(const Duration(milliseconds: 2800), () {
          if (mounted) setState(() => _showPostCapture = false);
        });
      }
    } catch (_) {
      _toast('Failed to save photo');
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _startTimer() async {
    if (_timerActive) return;
    HapticFeedback.lightImpact();
    setState(() { _timerActive = true; _timerCountdown = 3; });
    for (int i = 3; i > 0; i--) {
      if (!mounted || !_timerActive) break;
      setState(() => _timerCountdown = i);
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted && _timerActive) {
      setState(() => _timerActive = false);
      await _capturePhoto();
    }
  }

  void _cancelTimer() => setState(() => _timerActive = false);

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2) return;
    _controller?.stopImageStream();
    await _controller?.dispose();
    _cameraIndex = _cameraIndex == 0 ? 1 : 0;
    await _initCamera();
  }

  void _handleTapFocus(TapDownDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final box = context.findRenderObject() as RenderBox;
    final offset = box.globalToLocal(details.globalPosition);
    final point = Offset(offset.dx / box.size.width, offset.dy / box.size.height);
    _controller!.setFocusPoint(point);
    _controller!.setExposurePoint(point);
  }

  void _handleScaleStart(ScaleStartDetails _) => _baseZoom = _currentZoom;

  Future<void> _handleScaleUpdate(ScaleUpdateDetails d) async {
    if (_controller == null) return;
    final zoom = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(zoom);
    setState(() => _currentZoom = zoom);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
          style: const TextStyle(color: Color(0xFFF5F0E8), fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1A1A14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating));
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      await _controller?.dispose();
      _controller = null;
      await _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector.close();
    _silhouetteController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC8F04A))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _handleTapFocus,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),

            if (_showGrid) const _GridOverlay(),

            if (_activeSuggestion != null)
              AnimatedBuilder(
                animation: _silhouetteOpacity,
                builder: (_, __) => CustomPaint(
                  painter: PoseSilhouettePainter(
                    template: PoseTemplate.all[_activeSuggestion!.poseType] ??
                        PoseTemplate.all[PoseType.neutral]!,
                    matchScore: _matchScore,
                    opacity: _silhouetteOpacity.value,
                    accentColor: _accentColor,
                  ),
                ),
              ),

            AnimatedBuilder(
              animation: _flashOpacity,
              builder: (_, __) => Opacity(
                opacity: _flashOpacity.value * 0.8,
                child: Container(color: Colors.white),
              ),
            ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16, right: 16,
              child: _TopBar(
                showGrid: _showGrid,
                onGridToggle: () => setState(() => _showGrid = !_showGrid),
              ),
            ),

            if (_activeSuggestion != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                left: 16, right: 16,
                child: Column(
                  children: [
                    _PoseGuideCard(
                      suggestion: _activeSuggestion!,
                      matchScore: _matchScore,
                      accentColor: _accentColor,
                      onDismiss: () {
                        _silhouetteController.reverse();
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted) setState(() {
                            _activeSuggestion = null;
                            _matchScore = 0;
                            _coachingHint = null;
                          });
                        });
                      },
                    ),
                    if (_coachingHint != null) ...[
                      const SizedBox(height: 8),
                      _CoachingHint(hint: _coachingHint!, accentColor: _accentColor),
                    ],
                  ],
                ),
              ),

            if (_timerActive)
              Center(
                child: GestureDetector(
                  onTap: _cancelTimer,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A14).withValues(alpha: 0.92),
                      border: Border.all(color: _accentColor, width: 3),
                    ),
                    child: Center(
                      child: Text('$_timerCountdown',
                          style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              color: _accentColor)),
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomControls(
                onSuggest: _fetchingSuggestions ? null : _getSuggestions,
                onShutter: _timerActive ? null : _capturePhoto,
                onTimer: _timerActive ? _cancelTimer : _startTimer,
                onFlip: _flipCamera,
                matchScore: _matchScore,
                accentColor: _accentColor,
                isFetchingSuggestions: _fetchingSuggestions,
                timerActive: _timerActive,
              ),
            ),

            // Post-capture overlay
            if (_showPostCapture && _lastCaptureBytes != null)
              GestureDetector(
                onTap: () => setState(() => _showPostCapture = false),
                child: _PostCaptureOverlay(
                  imageBytes: _lastCaptureBytes!,
                  accentColor: _accentColor,
                  poseTitle: _activeSuggestion?.title,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Coaching hint pill ────────────────────────────────────────────────────────

class _CoachingHint extends StatelessWidget {
  final String hint;
  final Color accentColor;

  const _CoachingHint({required this.hint, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(hint),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_upward_rounded, color: accentColor, size: 14),
            const SizedBox(width: 6),
            Text(hint,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          ],
        ),
      ),
    );
  }
}

// ── Post-capture overlay ──────────────────────────────────────────────────────

class _PostCaptureOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final Color accentColor;
  final String? poseTitle;

  const _PostCaptureOverlay({
    required this.imageBytes,
    required this.accentColor,
    this.poseTitle,
  });

  @override
  State<_PostCaptureOverlay> createState() => _PostCaptureOverlayState();
}

class _PostCaptureOverlayState extends State<_PostCaptureOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _messages = [
    'You nailed it.',
    'That\'s the one.',
    'Main character energy.',
    'Absolutely you.',
    'Pure fire.',
  ];

  @override
  Widget build(BuildContext context) {
    final message = _messages[
        (widget.poseTitle?.hashCode ?? 0).abs() % _messages.length];

    return FadeTransition(
      opacity: _fadeIn,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(widget.imageBytes, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('SAVED',
                  style: const TextStyle(
                    color: Color(0xFF1A1A14),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  )),
              ),
              const SizedBox(height: 16),
              Text(message,
                style: const TextStyle(
                  color: Color(0xFFF5F0E8),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.poseTitle != null) ...[
                const SizedBox(height: 8),
                Text(widget.poseTitle!,
                  style: TextStyle(
                    color: widget.accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
              ],
              const SizedBox(height: 48),
              Text('tap to dismiss',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool showGrid;
  final VoidCallback onGridToggle;

  const _TopBar({required this.showGrid, required this.onGridToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('PosePal',
            style: TextStyle(
                color: Color(0xFFF5F0E8),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        GestureDetector(
          onTap: onGridToggle,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: showGrid
                  ? const Color(0xFFC8F04A).withValues(alpha: 0.9)
                  : const Color(0xFF1A1A14).withValues(alpha: 0.8),
            ),
            child: Icon(Icons.grid_on_rounded,
              color: showGrid ? const Color(0xFF1A1A14) : const Color(0xFFF5F0E8),
              size: 20),
          ),
        ),
      ],
    );
  }
}

// ── Pose guide card ───────────────────────────────────────────────────────────

class _PoseGuideCard extends StatelessWidget {
  final PoseSuggestion suggestion;
  final double matchScore;
  final Color accentColor;
  final VoidCallback onDismiss;

  const _PoseGuideCard({
    required this.suggestion,
    required this.matchScore,
    required this.accentColor,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (matchScore * 100).round();
    final matchColor = Color.lerp(const Color(0xFFF5F0E8), accentColor, matchScore)!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A14).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: matchColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: matchColor.withValues(alpha: 0.15),
              border: Border.all(color: matchColor.withValues(alpha: 0.7)),
            ),
            child: Center(
              child: Text('$pct%',
                  style: TextStyle(
                      color: matchColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.title,
                    style: TextStyle(
                        color: matchColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text(suggestion.instruction,
                    style: const TextStyle(color: Color(0xFF9A9A8A), fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded, color: Color(0xFF4A4A3A), size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Bottom controls ───────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final VoidCallback? onSuggest;
  final VoidCallback? onShutter;
  final VoidCallback onTimer;
  final VoidCallback onFlip;
  final double matchScore;
  final Color accentColor;
  final bool isFetchingSuggestions;
  final bool timerActive;

  const _BottomControls({
    required this.onSuggest,
    required this.onShutter,
    required this.onTimer,
    required this.onFlip,
    required this.matchScore,
    required this.accentColor,
    required this.isFetchingSuggestions,
    required this.timerActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 28, right: 28, top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SuggestButton(onTap: onSuggest, isLoading: isFetchingSuggestions),
          _ShutterButton(onTap: onShutter, matchScore: matchScore, accentColor: accentColor),
          Column(
            children: [
              _IconBtn(icon: Icons.flip_camera_ios_rounded, onTap: onFlip),
              const SizedBox(height: 8),
              _IconBtn(
                icon: timerActive ? Icons.timer_off_rounded : Icons.timer_rounded,
                onTap: onTimer,
                active: timerActive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _SuggestButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: onTap == null ? const Color(0xFF2E2E24) : const Color(0xFFC8F04A),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF1A1A14)))
            : Row(children: [
                Icon(Icons.auto_awesome_rounded,
                  color: onTap == null ? const Color(0xFF4A4A3A) : const Color(0xFF1A1A14),
                  size: 16),
                const SizedBox(width: 7),
                Text('Suggest',
                    style: TextStyle(
                        color: onTap == null ? const Color(0xFF4A4A3A) : const Color(0xFF1A1A14),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double matchScore;
  final Color accentColor;

  const _ShutterButton({
    required this.onTap,
    required this.matchScore,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84, height: 84,
        child: CustomPaint(
          painter: MatchRingPainter(matchScore: matchScore, accentColor: accentColor),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                        const Color(0xFFF5F0E8).withValues(alpha: 0.3),
                        accentColor.withValues(alpha: 0.55),
                        matchScore)!,
                    blurRadius: 16 + matchScore * 12,
                    spreadRadius: matchScore * 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _IconBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0xFFC8F04A) : const Color(0xFF2E2E24),
        ),
        child: Icon(icon,
          color: active ? const Color(0xFF1A1A14) : const Color(0xFFF5F0E8),
          size: 22),
      ),
    );
  }
}

// ── Grid overlay ──────────────────────────────────────────────────────────────

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter());
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

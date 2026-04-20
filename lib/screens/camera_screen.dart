import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pose_suggestion.dart';
import '../services/claude_service.dart';
import '../widgets/skeleton_painter.dart';
import '../widgets/suggestion_sheet.dart';
import '../env.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  final ClaudeService _claudeService = ClaudeService(apiKey: Env.claudeApiKey);

  List<Pose> _poses = [];
  bool _isProcessingPose = false;
  bool _isFetchingSuggestions = false;
  bool _isTakingPhoto = false;
  PoseSuggestion? _activeSuggestion;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndInit();
  }

  Future<void> _requestPermissionsAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    final camera = widget.cameras[_currentCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    if (!mounted) return;
    _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessingPose) return;
    _isProcessingPose = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;
      final poses = await _poseDetector.processImage(inputImage);
      if (mounted) setState(() => _poses = poses);
    } finally {
      _isProcessingPose = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = widget.cameras[_currentCameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (camera.lensDirection == CameraLensDirection.front) {
      rotation = InputImageRotationValue.fromRawValue(360 - sensorOrientation);
    } else {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
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
    if (_poses.isEmpty) {
      _showToast('Step into frame first');
      return;
    }
    setState(() => _isFetchingSuggestions = true);

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      final personCount = _poses.length;
      final suggestions = await _claudeService.getSuggestions(
        imageBytes: bytes,
        personCount: personCount,
      );
      if (!mounted) return;
      await SuggestionSheet.show(
        context,
        suggestions: suggestions,
        onSelected: (s) => setState(() => _activeSuggestion = s),
      );
    } catch (e) {
      _showToast('Could not fetch suggestions. Check internet connection.');
    } finally {
      if (mounted) setState(() => _isFetchingSuggestions = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;
    setState(() => _isTakingPhoto = true);
    try {
      final xFile = await _controller!.takePicture();
      await Gal.putImage(xFile.path);
      _showToast('Saved to gallery');
    } catch (e) {
      _showToast('Failed to save photo');
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2) return;
    _controller?.stopImageStream();
    await _controller?.dispose();
    _currentCameraIndex = _currentCameraIndex == 0 ? 1 : 0;
    await _initCamera();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isFront = widget.cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          CustomPaint(
            painter: SkeletonPainter(
              poses: _poses,
              imageSize: Size(
                _controller!.value.previewSize!.height,
                _controller!.value.previewSize!.width,
              ),
              isFrontCamera: isFront,
            ),
          ),
          if (_activeSuggestion != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _PoseGuideCard(
                suggestion: _activeSuggestion!,
                onDismiss: () => setState(() => _activeSuggestion = null),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _BottomControls(
              onSuggest: _isFetchingSuggestions ? null : _getSuggestions,
              onShutter: _isTakingPhoto ? null : _takePhoto,
              onFlip: _flipCamera,
              isFetchingSuggestions: _isFetchingSuggestions,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseGuideCard extends StatelessWidget {
  final PoseSuggestion suggestion;
  final VoidCallback onDismiss;

  const _PoseGuideCard({required this.suggestion, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.instruction,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final VoidCallback? onSuggest;
  final VoidCallback? onShutter;
  final VoidCallback onFlip;
  final bool isFetchingSuggestions;

  const _BottomControls({
    required this.onSuggest,
    required this.onShutter,
    required this.onFlip,
    required this.isFetchingSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SuggestButton(onTap: onSuggest, isLoading: isFetchingSuggestions),
          _ShutterButton(onTap: onShutter),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
            onPressed: onFlip,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Suggest', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ShutterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tryp_driver/app/theme.dart';

/// Captures a selfie for admin review using the front camera inside the app.
/// This screen does not perform automated face or anti-spoof liveness checks.
class LiveSelfieScreen extends StatefulWidget {
  const LiveSelfieScreen({super.key});

  @override
  State<LiveSelfieScreen> createState() => _LiveSelfieScreenState();
}

class _LiveSelfieScreenState extends State<LiveSelfieScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  XFile? _capturedImage;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _isCapturing = false;
  int _initializationToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _initializationToken++;
      if (controller == null) return;
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _capturedImage == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted || _isInitializing) return;
    final token = ++_initializationToken;
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'No camera is available on this device.',
        );
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      CameraController? controller;
      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      try {
        await controller.initialize();
      } catch (error) {
        await controller.dispose();
        rethrow;
      }

      if (!mounted || token != _initializationToken) {
        await controller.dispose();
        return;
      }
      await _controller?.dispose();
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            error.description ?? 'Camera permission was not granted.';
      });
    } catch (_) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'We could not start the camera. Check camera permissions and try again.';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      setState(() => _capturedImage = image);
      await controller.dispose();
      _controller = null;
    } on CameraException {
      // Keep capture failures in the screen state instead of showing a bottom toast.
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _retake() async {
    setState(() => _capturedImage = null);
    await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _capturedImage;
    return Scaffold(
      backgroundColor: TRYPColors.dark,
      appBar: AppBar(
        backgroundColor: TRYPColors.dark,
        foregroundColor: TRYPColors.white,
        title: const Text('Selfie capture for review'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              const Text(
                'Keep your face inside the frame',
                style: TextStyle(
                  color: TRYPColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use good lighting, remove sunglasses, and look directly at the camera. Your selfie will be reviewed by TRYP.',
                style: TextStyle(color: TRYPColors.secondaryLight, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: double.infinity,
                    color: TRYPColors.secondary,
                    child: image != null
                        ? _buildCapturedImage(image)
                        : _buildCameraPreview(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (image != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _retake,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TRYPColors.white,
                          side: const BorderSide(color: TRYPColors.white),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(image),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TRYPColors.white,
                          foregroundColor: TRYPColors.dark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Use selfie'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isInitializing || _errorMessage != null
                        ? null
                        : _capture,
                    icon: _isCapturing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                    label: Text(
                      _isCapturing ? 'Capturing...' : 'Capture selfie',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TRYPColors.white,
                      foregroundColor: TRYPColors.dark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapturedImage(XFile image) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: TRYPColors.white),
          );
        }
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      },
    );
  }

  Widget _buildCameraPreview() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: TRYPColors.white),
      );
    }
    if (_errorMessage != null || _controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: TRYPColors.white,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Camera unavailable',
                style: const TextStyle(color: TRYPColors.secondaryLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _initializeCamera,
                child: const Text(
                  'Try again',
                  style: TextStyle(color: TRYPColors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        CameraPreview(controller),
        IgnorePointer(
          child: CustomPaint(
            painter: _SelfieGuidePainter(),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

/// Paints a subtle oval guide without obscuring the live preview.
class _SelfieGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TRYPColors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 8),
      width: size.width * 0.62,
      height: size.height * 0.62,
    );
    canvas.drawOval(oval, paint);
  }

  @override
  bool shouldRepaint(covariant _SelfieGuidePainter oldDelegate) => false;
}

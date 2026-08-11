import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';

/// The two images required by passenger identity verification.
enum PassengerCaptureKind { idDocument, selfie }

/// Captures verification images inside TRYP instead of opening an external
/// camera application.
class InAppCameraCaptureScreen extends StatefulWidget {
  const InAppCameraCaptureScreen({super.key, required this.kind});

  final PassengerCaptureKind kind;

  @override
  State<InAppCameraCaptureScreen> createState() =>
      _InAppCameraCaptureScreenState();
}

class _InAppCameraCaptureScreenState extends State<InAppCameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  XFile? _capturedImage;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _isCapturing = false;
  int _initializationToken = 0;

  bool get _isSelfie => widget.kind == PassengerCaptureKind.selfie;

  String get _title => _isSelfie ? 'Live selfie' : 'ID card photo';

  String get _instruction => _isSelfie
      ? 'Keep your face inside the oval and look directly at the camera.'
      : 'Place the front of your ID card inside the frame. Keep all text visible.';

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
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _initializationToken++;
      if (controller != null) {
        controller.dispose();
        _controller = null;
      }
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

      final desiredLens = _isSelfie
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final matchingCameras = cameras
          .where((item) => item.lensDirection == desiredLens)
          .toList();
      if (matchingCameras.isEmpty) {
        throw CameraException(
          'RequestedCameraUnavailable',
          _isSelfie
              ? 'This device does not have a front camera for selfie capture.'
              : 'This device does not have a rear camera for ID capture.',
        );
      }
      final camera = matchingCameras.first;

      // Medium is enough for manual verification while using considerably
      // less memory than a max/high-resolution camera stream.
      final nextController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      try {
        await nextController.initialize();
      } catch (error) {
        await nextController.dispose();
        rethrow;
      }

      if (!mounted) {
        await nextController.dispose();
        return;
      }
      if (token != _initializationToken) {
        await nextController.dispose();
        if (mounted) setState(() => _isInitializing = false);
        return;
      }

      await _controller?.dispose();
      setState(() {
        _controller = nextController;
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      if (token != _initializationToken) {
        setState(() => _isInitializing = false);
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage =
            error.description ?? 'Camera permission was not granted.';
      });
    } catch (_) {
      if (!mounted) return;
      if (token != _initializationToken) {
        setState(() => _isInitializing = false);
        return;
      }
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
      await controller.dispose();
      _controller = null;
      setState(() => _capturedImage = image);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo capture failed. Please try again.'),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
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
      backgroundColor: TRYPColors.secondary,
      appBar: AppBar(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        title: Text(_title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Text(
                _isSelfie
                    ? 'Take a live selfie holding your ID'
                    : 'Capture the front of your ID',
                style: const TextStyle(
                  color: TRYPColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _instruction,
                style: const TextStyle(
                  color: TRYPColors.secondaryLight,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: double.infinity,
                    color: TRYPColors.dark,
                    child: image == null
                        ? _buildCameraPreview()
                        : _buildCapturedImage(image),
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
                          backgroundColor: TRYPColors.primary,
                          foregroundColor: TRYPColors.secondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Use photo'),
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
                    label: Text(_isCapturing ? 'Capturing…' : 'Capture photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TRYPColors.primary,
                      foregroundColor: TRYPColors.secondary,
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

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        CameraPreview(_controller!),
        IgnorePointer(
          child: CustomPaint(
            painter: _CaptureGuidePainter(isSelfie: _isSelfie),
            size: Size.infinite,
          ),
        ),
      ],
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
        return Image.memory(snapshot.data!, fit: BoxFit.contain);
      },
    );
  }
}

class _CaptureGuidePainter extends CustomPainter {
  const _CaptureGuidePainter({required this.isSelfie});

  final bool isSelfie;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TRYPColors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final guide = isSelfie
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2 - 8),
            width: size.width * 0.62,
            height: size.height * 0.62,
          )
        : Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.86,
            height: size.height * 0.46,
          );

    if (isSelfie) {
      canvas.drawOval(guide, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(guide, const Radius.circular(16)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CaptureGuidePainter oldDelegate) =>
      oldDelegate.isSelfie != isSelfie;
}

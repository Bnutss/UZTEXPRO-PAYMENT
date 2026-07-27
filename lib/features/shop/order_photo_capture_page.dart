import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';

/// Captures a confirmation photo of the buyer with the rear camera at
/// pickup time. Pops with a base64-encoded JPEG string, or null if
/// cancelled.
class OrderPhotoCapturePage extends StatefulWidget {
  const OrderPhotoCapturePage({super.key});

  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  @override
  State<OrderPhotoCapturePage> createState() => _OrderPhotoCapturePageState();
}

class _OrderPhotoCapturePageState extends State<OrderPhotoCapturePage> {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;
  XFile? _captured;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = S.of(context).shopPhotoNoCamera);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      // Without this, some Android devices save the sensor's native
      // (sideways) pixel orientation and rely on an EXIF tag to display it
      // upright — that tag doesn't survive the base64/WEBP round trip, so
      // the photo comes out visibly rotated. Locking capture orientation
      // makes the plugin bake the correct rotation into the saved file.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = S.of(context).shopPhotoNoAccess);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() => _captured = file);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = S.of(context).shopPhotoFailed);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _retake() => setState(() => _captured = null);

  Future<void> _confirm() async {
    final file = _captured;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.of(context).pop(base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(s.shopPhotoTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            );
          }
          if (_controller == null || !_controller!.value.isInitialized) {
            return const Center(child: CircularProgressIndicator(color: OrderPhotoCapturePage._g1));
          }

          if (_captured != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(_captured!.path), fit: BoxFit.cover),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(label: s.shopPhotoRetake, icon: Icons.replay_rounded, onTap: _retake, filled: false),
                      const SizedBox(width: 16),
                      _ActionButton(label: s.shopPhotoConfirm, icon: Icons.check_rounded, onTap: _confirm, filled: true),
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              Center(
                child: Container(
                  width: 240,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: OrderPhotoCapturePage._g1, width: 3),
                    borderRadius: BorderRadius.circular(140),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 100,
                child: Text(
                  s.shopPhotoHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: Center(
                  child: GestureDetector(
                    onTap: _capturing ? null : _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [OrderPhotoCapturePage._g1, OrderPhotoCapturePage._g2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: _capturing
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap, required this.filled});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(colors: [OrderPhotoCapturePage._g1, OrderPhotoCapturePage._g2])
                : null,
            color: filled ? null : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

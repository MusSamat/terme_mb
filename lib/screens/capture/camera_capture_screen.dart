import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/image_pick.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/capture_overlay.dart';

/// In-app live camera with the guide overlay drawn on top of the feed (the web
/// uses getUserMedia for the same effect; image_picker can't, since it opens the
/// system camera app). Returns the captured File via Navigator.pop, or null if
/// cancelled. Falls back to image_picker when the camera can't initialise.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen(
      {super.key, required this.guide, this.front = false, this.hint});
  final CaptureGuide guide;
  final bool front;
  final String? hint;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _initFailed = false;
  bool _denied = false; // camera permission explicitly denied
  bool _switching = false;
  bool _shooting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
      await _start(front: widget.front);
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
    }
  }

  Future<void> _start({required bool front}) async {
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _initFailed = true);
      return;
    }
    final desc = _cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (front ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => _cameras.first,
    );
    final ctrl = CameraController(desc, ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await ctrl.initialize();
      // Lock capture to portrait so document photos never come out sideways,
      // regardless of how the phone is held.
      await ctrl.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _initFailed = false;
      });
    } on CameraException catch (e) {
      // Tell a denied permission apart from a genuinely unavailable camera so we
      // can show the right message (Settings hint vs. system-camera fallback).
      final denied = e.code.toLowerCase().contains('denied') ||
          e.code.toLowerCase().contains('permission');
      if (mounted) {
        setState(() {
          _denied = denied;
          _initFailed = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _switching) return;
    setState(() => _switching = true);
    final wasFront =
        _controller?.description.lensDirection == CameraLensDirection.front;
    await _controller?.dispose();
    _controller = null;
    await _start(front: !wasFront);
    if (mounted) setState(() => _switching = false);
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _shooting) return;
    setState(() => _shooting = true);
    try {
      final shot = await c.takePicture();
      final file = await compressToJpeg(shot.path);
      if (mounted) Navigator.of(context).pop(file);
    } catch (_) {
      if (mounted) {
        setState(() => _shooting = false);
        Toasts.error('camera.capture_failed'.tr());
      }
    }
  }

  // Fallback: the system camera via image_picker (still a live shot, no overlay).
  Future<void> _fallback() async {
    final file = await captureCompressedImage(front: widget.front);
    if (mounted) Navigator.of(context).pop(file);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      c?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed &&
        c == null &&
        !_initFailed) {
      _start(front: widget.front);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (_initFailed)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    _denied
                        ? 'camera.permission_denied'.tr()
                        : 'camera.no_camera'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                AppButton(
                    label: 'camera.open_camera'.tr(),
                    variant: AppButtonVariant.grape,
                    onPressed: _fallback),
              ]),
            ),
          )
        else if (ready)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.previewSize!.height,
                height: c.value.previewSize!.width,
                child: CameraPreview(c),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Guide overlay on top of the live feed.
        if (!_initFailed)
          Positioned.fill(
              child: IgnorePointer(
                  child: CustomPaint(
                      painter: CaptureOverlayPainter(widget.guide)))),

        if (widget.hint != null && !_initFailed)
          Positioned(
            top: topPad + 56,
            left: 24,
            right: 24,
            child: Text(widget.hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
          ),

        // Close.
        Positioned(
          top: topPad + 6,
          right: 8,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ),

        // Controls.
        if (!_initFailed)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 28,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 52),
                  GestureDetector(
                    onTap: ready && !_shooting ? _shoot : null,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white, width: 4)),
                      child: _shooting
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white))
                          : const Icon(Icons.photo_camera,
                              color: Colors.white, size: 30),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: _cameras.length >= 2
                        ? IconButton(
                            onPressed: _switching ? null : _flip,
                            icon: const Icon(Icons.cameraswitch,
                                color: Colors.white, size: 28))
                        : null,
                  ),
                ]),
          ),
      ]),
    );
  }
}

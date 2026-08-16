import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:anti_counterfeit_app/services/camera_service.dart';

class CustomScannerWidget extends StatefulWidget {
  /// Callback fired when a QR / barcode is detected.
  final Function(String) onCodeDetected;
  final bool isActive;

  const CustomScannerWidget({
    super.key, 
    required this.onCodeDetected,
    this.isActive = true,
  });

  @override
  State<CustomScannerWidget> createState() => _CustomScannerWidgetState();
}

class _CustomScannerWidgetState extends State<CustomScannerWidget>
    with SingleTickerProviderStateMixin {
  CameraService? _cameraService;

  late AnimationController _animationController;
  StreamSubscription<String>? _barcodeSub;
  bool _hasScanned = false;
  bool _isInitialized = false;
  bool _isTorchOn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Scan-line animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    if (widget.isActive) {
      _initCamera();
    }
  }

  @override
  void didUpdateWidget(CustomScannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initCamera();
      } else {
        _disposeCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    _cameraService = CameraService();
    try {
      await _cameraService!.initialize();

      // Listen for barcodes coming from our custom service
      _barcodeSub = _cameraService!.barcodeStream.listen(_onBarcodeDetected);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    _barcodeSub?.cancel();
    _barcodeSub = null;
    await _cameraService?.dispose();
    _cameraService = null;
    
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isTorchOn = false;
      });
    }
  }

  void _onBarcodeDetected(String value) {
    if (_hasScanned) return;

    _hasScanned = true;
    _cameraService?.pauseDetection();
    widget.onCodeDetected(value);

    // Reset after a delay so user can scan again after dismissing the result
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _hasScanned = false;
        _cameraService?.resumeDetection();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(color: Colors.black);
    }

    // Error state
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!);
    }

    // Loading state
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                'Starting camera…',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // ── Native camera preview via AVCapturePreviewLayer / CameraX ──
        SizedBox.expand(
          child: defaultTargetPlatform == TargetPlatform.iOS
              ? const UiKitView(
                  viewType: kScannerViewType,
                  creationParamsCodec: StandardMessageCodec(),
                )
              : const AndroidView(
                  viewType: kScannerViewType,
                  creationParamsCodec: StandardMessageCodec(),
                ),
        ),

        // ── Scanning overlay with viewfinder cutout ─────────────────
        _ScanOverlay(animationController: _animationController),

        // ── Top toolbar: flash toggle ──────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ToolbarButton(
                icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                label: _isTorchOn ? 'Flash On' : 'Flash Off',
                isActive: _isTorchOn,
                onTap: () async {
                  await _cameraService?.toggleTorch();
                  if (mounted) {
                    setState(() {
                      _isTorchOn = _cameraService?.isTorchOn ?? false;
                    });
                  }
                },
              ),
            ],
          ),
        ),

        // ── Bottom instruction text ─────────────────────────────────
        Positioned(
          bottom: 40,
          left: 40,
          right: 40,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Text(
                    'Point camera at a QR code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error view shown when camera fails to initialize
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Camera Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar button used for flash control
// ─────────────────────────────────────────────────────────────────────────────
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF4F46E5).withOpacity(0.8)
                  : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark overlay with a transparent square "viewfinder" cutout + scan line
// ─────────────────────────────────────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  final AnimationController animationController;

  const _ScanOverlay({required this.animationController});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;

    return Stack(
      children: [
        // Semi-transparent background with a clear centre
        ColorFiltered(
          colorFilter:
              const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  decoration: BoxDecoration(
                    color: Colors.red, // colour is irrelevant – it's cut out
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Corner decorations
        Center(
          child: SizedBox(
            width: scanAreaSize,
            height: scanAreaSize,
            child: CustomPaint(
              painter: _CornerPainter(),
            ),
          ),
        ),

        // Animated scan line
        Center(
          child: SizedBox(
            width: scanAreaSize,
            height: scanAreaSize,
            child: AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                return Align(
                  alignment: Alignment(
                    0,
                    -1 + 2 * animationController.value,
                  ),
                  child: Container(
                    width: scanAreaSize - 24,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4F46E5).withOpacity(0.0),
                          const Color(0xFF4F46E5),
                          const Color(0xFF4F46E5).withOpacity(0.0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter for corner bracket decorations
// ─────────────────────────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cornerLen = 28;
    const double strokeWidth = 4;
    const double radius = 16;

    final paint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLen)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0),
            radius: const Radius.circular(radius))
        ..lineTo(cornerLen, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(Offset(size.width, radius),
            radius: const Radius.circular(radius))
        ..lineTo(size.width, cornerLen),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLen)
        ..lineTo(0, size.height - radius)
        ..arcToPoint(Offset(radius, size.height),
            radius: const Radius.circular(radius))
        ..lineTo(cornerLen, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, size.height)
        ..lineTo(size.width - radius, size.height)
        ..arcToPoint(Offset(size.width, size.height - radius),
            radius: const Radius.circular(radius))
        ..lineTo(size.width, size.height - cornerLen),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_handled) return;
    final values = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty);
    if (values.isEmpty) return;
    _handled = true;
    await _controller.stop();
    if (mounted) Navigator.pop(context, values.first);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detected,
            errorBuilder: (_, error) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error.errorCode.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: MediaQuery.sizeOf(context).width * .78,
                constraints: const BoxConstraints(maxWidth: 420),
                height: 190,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xff48d477), width: 3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  _ScannerButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close scanner',
                      icon: LucideIcons.x),
                  const Spacer(),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (_, state, __) => _ScannerButton(
                      onPressed: state.torchState == TorchState.unavailable
                          ? null
                          : _controller.toggleTorch,
                      tooltip: 'Toggle flashlight',
                      icon: state.torchState == TorchState.on
                          ? LucideIcons.flashlightOff
                          : LucideIcons.flashlight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ScannerButton(
                      onPressed: _controller.switchCamera,
                      tooltip: 'Switch camera',
                      icon: LucideIcons.switchCamera),
                ]),
              ),
            ),
          ),
        ]),
      );
}

class _ScannerButton extends StatelessWidget {
  const _ScannerButton(
      {required this.onPressed, required this.tooltip, required this.icon});
  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
            color: Color(0xaa000000),
            borderRadius: BorderRadius.all(Radius.circular(6))),
        child: IconButton(
            onPressed: onPressed,
            tooltip: tooltip,
            color: Colors.white,
            icon: Icon(icon, size: 21)),
      );
}

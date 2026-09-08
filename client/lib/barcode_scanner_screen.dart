import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// What the caller made of a scanned barcode, shown back on the scanner so the
/// cashier can see the item land without leaving the camera.
class ScanFeedback {
  const ScanFeedback(
      {required this.key,
      required this.found,
      required this.label,
      this.detail});

  /// Identifies the thing scanned — the product id, or the barcode when
  /// nothing matched. Scanning the same item again updates its existing row
  /// instead of stacking another one, mirroring what the cart does.
  final String key;

  /// Whether the barcode matched a product.
  final bool found;

  /// Product name, or the raw barcode when nothing matched.
  final String label;
  final String? detail;
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, this.onBarcode});

  /// Handles each scan and describes the result. When given, the scanner stays
  /// open and keeps reading, listing what it has picked up; the cashier closes
  /// it when the basket is done. Without it the first scan pops with the value,
  /// which is what a one-shot "capture a barcode" caller wants.
  final Future<ScanFeedback> Function(String barcode)? onBarcode;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final bool _continuous = widget.onBarcode != null;

  late final MobileScannerController _controller = MobileScannerController(
    // Continuous mode has to re-read the same code so two identical items can
    // be rung up; `noDuplicates` would swallow the second one for the life of
    // the controller. The repeat guard below handles the camera's own repeats.
    detectionSpeed:
        _continuous ? DetectionSpeed.normal : DetectionSpeed.noDuplicates,
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

  /// A barcode held in front of the lens fires on nearly every frame. Ignore
  /// repeats of the same value until the cashier has had time to move on.
  static const _repeatGuard = Duration(milliseconds: 1600);

  /// Where the aiming frame sits, as a fraction of the preview. Alignment
  /// `(0, -.35)` puts its centre 35% of the way from the middle to the top.
  static const _aimPoint = Offset(.5, (1 - .35) / 2);

  final List<ScanFeedback> _scans = [];
  bool _handled = false;
  bool _busy = false;
  String? _lastValue;
  DateTime? _lastAt;

  /// Whether [_lastValue] matched a product, so tapping can only re-add
  /// something that is actually in the cart.
  bool _lastFound = false;
  int _found = 0;

  /// Where the last focus request landed, in local pixels, so it can be shown.
  Offset? _focusRing;
  int _focusToken = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Drives the camera's focus at [point] (normalized) instead of waiting for
  /// continuous autofocus to hunt, which on cheaper sensors costs seconds per
  /// item. [at] is the same spot in local pixels, for the on-screen ring.
  Future<void> _focusAt(Offset point, {Offset? at, Size? size}) async {
    final target = at ??
        (size == null
            ? null
            : Offset(point.dx * size.width, point.dy * size.height));
    final token = ++_focusToken;
    if (mounted) setState(() => _focusRing = target);
    try {
      await _controller.setFocusPoint(point);
      unawaited(HapticFeedback.selectionClick());
    } catch (_) {
      // Not every platform implements manual focus; the preview still works.
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // Only clear the ring if no newer focus request has started since.
    if (mounted && token == _focusToken) setState(() => _focusRing = null);
  }

  Future<void> _detected(BarcodeCapture capture) async {
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .firstOrNull;
    if (value == null) return;

    final handler = widget.onBarcode;
    if (handler == null) {
      // One-shot mode: hand the value back to whoever pushed this screen.
      if (_handled) return;
      _handled = true;
      await _controller.stop();
      if (mounted) Navigator.pop(context, value);
      return;
    }

    final now = DateTime.now();
    if (_busy) return;
    if (value == _lastValue &&
        _lastAt != null &&
        now.difference(_lastAt!) < _repeatGuard) {
      return;
    }
    await _apply(value, handler);
  }

  /// Adds the barcode currently in view again, so a cashier holding three of
  /// the same item can tap twice more instead of pulling the code away and
  /// back to beat the repeat guard.
  Future<void> _addAgain() async {
    final handler = widget.onBarcode;
    final value = _lastValue;
    if (handler == null || value == null || !_lastFound || _busy) return;
    await _apply(value, handler);
  }

  Future<void> _apply(
      String value, Future<ScanFeedback> Function(String) handler) async {
    _lastValue = value;
    _lastAt = DateTime.now();
    _busy = true;
    try {
      final feedback = await handler(value);
      _lastFound = feedback.found;
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      setState(() {
        // Rescanning an item updates its row and lifts it back to the top,
        // rather than repeating it — the same way it adds quantity to the one
        // cart line instead of creating a second one.
        final existing =
            _scans.indexWhere((entry) => entry.key == feedback.key);
        if (existing != -1) _scans.removeAt(existing);
        _scans.insert(0, feedback);
        if (feedback.found) _found++;
        // Only the last few matter on a viewfinder; the cart is the record.
        if (_scans.length > 12) _scans.removeRange(12, _scans.length);
      });
    } finally {
      _busy = false;
      // Restart the guard from the end of the write, so the camera's own
      // repeats of the code still in view don't pile on another unit.
      _lastAt = DateTime.now();
    }
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
          Align(
            alignment: const Alignment(0, -.35),
            child: IgnorePointer(
              child: Container(
                width: MediaQuery.sizeOf(context).width * .78,
                constraints: const BoxConstraints(maxWidth: 420),
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xff48d477), width: 3),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          // Tap the preview to add another of whatever is in view; long-press
          // to focus on a particular spot. Sits above the camera but below the
          // controls, so the buttons still get their own taps.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _continuous ? _addAgain : null,
                onLongPressStart: (details) => _focusAt(
                  Offset(
                    details.localPosition.dx / constraints.maxWidth,
                    details.localPosition.dy / constraints.maxHeight,
                  ),
                  at: details.localPosition,
                ),
              ),
            ),
          ),
          if (_focusRing != null)
            Positioned(
              left: _focusRing!.dx - 34,
              top: _focusRing!.dy - 34,
              child: const IgnorePointer(child: _FocusRing()),
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
          // Focus and Done live at the bottom, within thumb reach — the top
          // corners are a stretch one-handed while holding an item.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(children: [
                    const Spacer(),
                    _FocusButton(
                      onPressed: () =>
                          _focusAt(_aimPoint, size: MediaQuery.sizeOf(context)),
                    ),
                  ]),
                ),
                if (_continuous) _scanPanel(),
              ]),
            ),
          ),
        ]),
      );

  Widget _scanPanel() => Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 290),
      decoration: BoxDecoration(
        color: const Color(0xf2101a16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x2a48d477)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(LucideIcons.scanBarcode,
              size: 18, color: Color(0xff48d477)),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _scans.isEmpty
                    ? 'Point the camera at a barcode'
                    : '$_found item${_found == 1 ? '' : 's'} added to the cart',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                _lastFound
                    ? 'Tap anywhere to add one more'
                    : 'Long-press the view to focus',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xff9fb5aa), fontSize: 11),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xff48d477),
              foregroundColor: const Color(0xff08301c),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ]),
        if (_scans.isNotEmpty) ...[
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _scans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (_, index) =>
                  _ScanRow(feedback: _scans[index], highlighted: index == 0),
            ),
          ),
        ],
      ]));
}

/// Deliberate refocus, sized and placed for a thumb.
class _FocusButton extends StatelessWidget {
  const _FocusButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xe6101a16),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x5548d477)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.crosshair, size: 19, color: Color(0xff48d477)),
              SizedBox(width: 9),
              Text('Focus',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5)),
            ]),
          ),
        ),
      );
}

/// Brief marker showing where a focus request was sent, so the cashier can see
/// the camera was told to refocus rather than wondering whether the tap landed.
class _FocusRing extends StatefulWidget {
  const _FocusRing();

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260))
    ..forward();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.35, end: 1).animate(
              CurvedAnimation(parent: _animation, curve: Curves.easeOut)),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffffe08a), width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
}

class _ScanRow extends StatelessWidget {
  const _ScanRow({required this.feedback, required this.highlighted});
  final ScanFeedback feedback;

  /// The newest scan is lifted so the cashier sees what just went in.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color =
        feedback.found ? const Color(0xff48d477) : const Color(0xffffb020);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: .16)
            : const Color(0x14ffffff),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(feedback.found ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(feedback.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
            if (feedback.detail != null) ...[
              const SizedBox(height: 2),
              Text(feedback.detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xff9fb5aa), fontSize: 11)),
            ],
          ]),
        ),
      ]),
    );
  }
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
            borderRadius: BorderRadius.all(Radius.circular(14))),
        child: IconButton(
            onPressed: onPressed,
            tooltip: tooltip,
            color: Colors.white,
            icon: Icon(icon, size: 21)),
      );
}

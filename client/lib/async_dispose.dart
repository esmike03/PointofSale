import 'package:flutter/widgets.dart';

/// Disposes controllers owned by a modal sheet/dialog only after its exit and
/// keyboard-hide animations finish.
///
/// Disposing them the instant the sheet closes crashes with
/// "A TextEditingController was used after being disposed", because the
/// still-animating [TextField]s keep rebuilding against a controller that is
/// already disposed. Deferring past the transition avoids the race.
void disposeAfterClose(List<TextEditingController> controllers) {
  Future.delayed(const Duration(milliseconds: 400), () {
    for (final controller in controllers) {
      controller.dispose();
    }
  });
}

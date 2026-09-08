import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'receipt_profile.dart';
import 'sale_tax.dart';

Future<String?> saveReceiptPng(
    GlobalKey boundaryKey, String receiptNumber) async {
  await WidgetsBinding.instance.endOfFrame;
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw StateError('Receipt image is not ready.');
  final image = await boundary.toImage(pixelRatio: 2.5);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) throw StateError('Could not create the receipt image.');
  final bytes = byteData.buffer.asUint8List();
  final safeName = receiptNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final mobile = Platform.isAndroid || Platform.isIOS;
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save receipt image',
    fileName: '$safeName.png',
    type: FileType.custom,
    allowedExtensions: const ['png'],
    bytes: mobile ? Uint8List.fromList(bytes) : null,
    lockParentWindow: true,
  );
  if (path == null) return null;
  if (!mobile) await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

class ReceiptImage extends StatelessWidget {
  const ReceiptImage({
    super.key,
    required this.receiptNumber,
    required this.items,
    required this.payments,
    required this.total,
    this.receiptName,
    this.occurredAt,
    this.discount = 0,
    this.discountReason,
    this.refunded = 0,
    this.profile,
    this.tax,
  });

  final String receiptNumber;
  final String? receiptName;
  final String? occurredAt;
  final List<Map<String, Object?>> items;
  final List<Map<String, Object?>> payments;
  final double total;
  final double discount;
  final String? discountReason;
  final double refunded;
  final ReceiptProfile? profile;
  final SaleTaxSummary? tax;

  @override
  Widget build(BuildContext context) {
    final date =
        DateTime.tryParse(occurredAt ?? '')?.toLocal() ?? DateTime.now();
    final seller = profile ?? ReceiptProfile.empty();
    final taxSummary = tax ??
        const SaleTaxSummary(
            mode: 'unregistered',
            vatRate: 0,
            vatableSales: 0,
            vatAmount: 0,
            vatExemptSales: 0,
            zeroRatedSales: 0);
    final posPermitted = seller.posPermitStatus == 'permitted';
    final invoiceTitle = !posPermitted
        ? 'CHIRPY POS SALES SLIP'
        : taxSummary.mode == 'vat'
            ? 'VAT INVOICE'
            : taxSummary.mode == 'non_vat'
                ? 'NON-VAT INVOICE'
                : 'SALE RECEIPT';
    // Every receipt tears differently, but the same receipt always tears the
    // same way: seeding from the receipt number keeps the on-screen sheet and
    // the exported PNG identical.
    final tear = _TornEdge(seed: receiptNumber.hashCode);
    return CustomPaint(
      painter: _TornPaperShadow(tear),
      child: ClipPath(
        clipper: _TornPaperClipper(tear),
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                22, 22 + _TornEdge.depth, 22, 22 + _TornEdge.depth),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (seller.logoPath.isNotEmpty &&
                      File(seller.logoPath).existsSync()) ...[
                    Center(
                      child: Image.file(File(seller.logoPath),
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(seller.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff173323))),
                  if (seller.registeredName.isNotEmpty &&
                      seller.registeredName != seller.displayName)
                    Text(seller.registeredName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11)),
                  if (seller.registeredAddress.isNotEmpty)
                    Text(seller.registeredAddress,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10)),
                  if (seller.tin.isNotEmpty)
                    Text(
                        'TIN ${seller.tin}${seller.branchCode.isEmpty ? '' : '  Branch ${seller.branchCode}'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(invoiceTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff173323))),
                  if (!posPermitted) ...[
                    const SizedBox(height: 3),
                    const Text('NOT VALID AS BIR INVOICE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xffb42318))),
                  ],
                  const SizedBox(height: 8),
                  Text(receiptNumber,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  if (receiptName != null) ...[
                    const SizedBox(height: 4),
                    Text(receiptName!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                      '${date.month}/${date.day}/${date.year}  ${TimeOfDay.fromDateTime(date).format(context)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xff66756a))),
                  const Divider(height: 28),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(item['product_name']! as String,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      '${(item['quantity'] as num).toStringAsFixed(2)} x PHP ${(item['unit_price'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xff66756a))),
                                ])),
                            const SizedBox(width: 10),
                            Text(
                                'PHP ${(item['line_total'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                  const Divider(height: 24),
                  if (discount > 0)
                    _ReceiptImageLine(
                        label: discountReason == null
                            ? 'Discount'
                            : 'Discount - $discountReason',
                        value: '-PHP ${discount.toStringAsFixed(2)}'),
                  _ReceiptImageLine(
                      label: 'Total',
                      value: 'PHP ${total.toStringAsFixed(2)}',
                      strong: true),
                  if (taxSummary.mode == 'vat') ...[
                    const SizedBox(height: 4),
                    _ReceiptImageLine(
                        label: 'VATable sales',
                        value:
                            'PHP ${taxSummary.vatableSales.toStringAsFixed(2)}'),
                    _ReceiptImageLine(
                        label:
                            'VAT (${(taxSummary.vatRate * 100).toStringAsFixed(0)}%)',
                        value:
                            'PHP ${taxSummary.vatAmount.toStringAsFixed(2)}'),
                    _ReceiptImageLine(
                        label: 'VAT-exempt sales',
                        value:
                            'PHP ${taxSummary.vatExemptSales.toStringAsFixed(2)}'),
                    _ReceiptImageLine(
                        label: 'Zero-rated sales',
                        value:
                            'PHP ${taxSummary.zeroRatedSales.toStringAsFixed(2)}'),
                  ] else if (taxSummary.mode == 'non_vat')
                    _ReceiptImageLine(
                        label: 'Non-VAT sales',
                        value: 'PHP ${total.toStringAsFixed(2)}'),
                  if (refunded > 0) ...[
                    _ReceiptImageLine(
                        label: 'Refunded',
                        value: '-PHP ${refunded.toStringAsFixed(2)}'),
                    _ReceiptImageLine(
                        label: 'Net retained',
                        value: 'PHP ${(total - refunded).toStringAsFixed(2)}',
                        strong: true),
                  ],
                  const SizedBox(height: 12),
                  const Text('PAYMENT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff66756a))),
                  const SizedBox(height: 3),
                  for (final payment in payments)
                    _ReceiptImageLine(
                        label: _title(payment['method']! as String),
                        value:
                            'PHP ${(payment['amount'] as num).toStringAsFixed(2)}'),
                  const Divider(height: 28),
                  if (posPermitted) ...[
                    if (seller.permitNumber.isNotEmpty)
                      Text('PTU ${seller.permitNumber}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9)),
                    if (seller.machineIdentificationNumber.isNotEmpty)
                      Text('MIN ${seller.machineIdentificationNumber}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9)),
                    const SizedBox(height: 6),
                  ],
                  const Text('Thank you for your purchase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xff146c34))),
                ]),
          ),
        ),
      ),
    );
  }
}

/// A hand-torn paper edge for the top and bottom of a receipt.
///
/// The teeth deliberately vary in width, depth and direction — a perfectly
/// repeating saw pattern reads as a graphic, not as paper someone tore off a
/// thermal printer.
class _TornEdge {
  _TornEdge({required this.seed});

  /// How far a tear may bite into the paper.
  static const double depth = 11;

  final int seed;
  List<double>? _topProfile;
  List<double>? _bottomProfile;
  double? _profileWidth;

  /// Cached so a repaint (or the PNG export) never re-rolls the tear.
  void _build(double width) {
    if (_profileWidth == width && _topProfile != null) return;
    final random = Random(seed);
    _topProfile = _teeth(width, random);
    _bottomProfile = _teeth(width, random);
    _profileWidth = width;
  }

  /// Alternating x/y pairs describing one edge, flattened into a single list.
  List<double> _teeth(double width, Random random) {
    final points = <double>[0, depth * (.25 + random.nextDouble() * .5)];
    var x = 0.0;
    var deep = random.nextBool();
    while (x < width) {
      x = min(width, x + 7 + random.nextDouble() * 15);
      // A tear rarely alternates cleanly: sometimes two shallow nicks or two
      // deep bites land in a row.
      if (random.nextDouble() < .22) deep = !deep;
      final bite = deep
          ? depth * (.62 + random.nextDouble() * .38)
          : depth * (.04 + random.nextDouble() * .34);
      points
        ..add(x)
        ..add(bite);
      deep = !deep;
    }
    return points;
  }

  Path path(Size size) {
    _build(size.width);
    final top = _topProfile!;
    final bottom = _bottomProfile!;
    final path = Path()..moveTo(0, top[1]);
    for (var i = 2; i < top.length; i += 2) {
      path.lineTo(top[i], top[i + 1]);
    }
    path.lineTo(size.width, size.height - bottom[bottom.length - 1]);
    for (var i = bottom.length - 4; i >= 0; i -= 2) {
      path.lineTo(bottom[i], size.height - bottom[i + 1]);
    }
    return path..close();
  }
}

class _TornPaperClipper extends CustomClipper<Path> {
  const _TornPaperClipper(this.edge);
  final _TornEdge edge;

  @override
  Path getClip(Size size) => edge.path(size);

  @override
  bool shouldReclip(_TornPaperClipper oldClipper) => oldClipper.edge != edge;
}

/// Lifts the torn sheet off whatever sits behind it.
class _TornPaperShadow extends CustomPainter {
  const _TornPaperShadow(this.edge);
  final _TornEdge edge;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      edge.path(size).shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x1a12321f)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(_TornPaperShadow oldDelegate) => oldDelegate.edge != edge;
}

class _ReceiptImageLine extends StatelessWidget {
  const _ReceiptImageLine(
      {required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
          const SizedBox(width: 12),
          Text(value,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

String _title(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

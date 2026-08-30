import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import 'slide_deck.dart';
import 'slide_panel.dart';

const _navy = PdfColor.fromInt(0xFF1A2438);
const _rust = PdfColor.fromInt(0xFFC44F35);
const _cream = PdfColor.fromInt(0xFFF7F3EE);
const _muted = PdfColor.fromInt(0xFF5E584F);
const _stroke = PdfColor.fromInt(0xFFE6DCD2);
const _voidMid = PdfColor.fromInt(0xFFEFE8E0);

Future<void> downloadSlideDeck({
  required SlideDeck deck,
  required String topic,
  String? subject,
  String? board,
  String? level,
}) async {
  final bytes = await buildSlideDeckPdf(
    deck: deck,
    topic: topic,
    subject: subject,
    board: board,
    level: level,
  );
  await Printing.sharePdf(
    bytes: bytes,
    filename: '${_fileSafe(topic)}-slides.pdf',
  );
}

Future<Uint8List> buildSlideDeckPdf({
  required SlideDeck deck,
  required String topic,
  String? subject,
  String? board,
  String? level,
}) async {
  final doc = pw.Document();
  final crumbs = [
    if (subject != null && subject.trim().isNotEmpty) subject.trim(),
    if (board != null && board.trim().isNotEmpty) board.trim(),
    if (level != null && level.trim().isNotEmpty) level.trim(),
  ];
  final images = <int, pw.MemoryImage>{};
  for (final slide in deck.slides) {
    final image = await _pdfImage(slide);
    if (image != null) images[slide.number] = image;
  }

  for (var i = 0; i < deck.slides.length; i++) {
    final slide = deck.slides[i];
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(960, 540),
        margin: const pw.EdgeInsets.all(28),
        build: (context) => _SlidePage(
          topic: topic,
          crumbs: crumbs,
          slide: slide,
          index: i,
          total: deck.slides.length,
          image: images[slide.number],
        ),
      ),
    );
  }
  return doc.save();
}

class _SlidePage extends pw.StatelessWidget {
  _SlidePage({
    required this.topic,
    required this.crumbs,
    required this.slide,
    required this.index,
    required this.total,
    this.image,
  });

  final String topic;
  final List<String> crumbs;
  final Slide slide;
  final int index;
  final int total;
  final pw.MemoryImage? image;

  @override
  pw.Widget build(pw.Context context) {
    final pairs = comparisonPairs(slide);
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _cream,
        border: pw.Border.all(color: _stroke, width: 1.2),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  crumbs.isEmpty ? topic : crumbs.join('  ·  '),
                  style: pw.TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                'Slide ${index + 1} / $total',
                style: pw.TextStyle(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            slide.title,
            style: pw.TextStyle(
              color: _navy,
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          if (slide.visualType == 'comparison' && pairs.length >= 2)
            pw.Expanded(child: _comparison(pairs))
          else ...[
            if (slide.content.isNotEmpty) _bullets(slide.content),
            if ((slide.equation ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFE8EEF0),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  slide.equation!,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (image != null) ...[
              pw.SizedBox(height: 12),
              pw.Expanded(
                child: pw.ClipRRect(
                  horizontalRadius: 12,
                  verticalRadius: 12,
                  child: pw.Image(image!, fit: pw.BoxFit.cover),
                ),
              ),
            ] else
              pw.Spacer(),
          ],
        ],
      ),
    );
  }

  pw.Widget _bullets(List<String> lines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines.take(5))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 7,
                  height: 7,
                  margin: const pw.EdgeInsets.only(top: 5, right: 8),
                  decoration: const pw.BoxDecoration(
                    color: _rust,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    line,
                    style: const pw.TextStyle(
                      color: _navy,
                      fontSize: 13,
                      lineSpacing: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _comparison(List<({String title, String body})> pairs) {
    return pw.Row(
      children: [
        for (var i = 0; i < pairs.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _voidMid,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    pairs[i].title,
                    style: pw.TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    pairs[i].body,
                    style: const pw.TextStyle(
                      color: _muted,
                      fontSize: 12,
                      lineSpacing: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Future<pw.MemoryImage?> _pdfImage(Slide slide) async {
  final url = slide.visualAsset?.url?.trim() ?? '';
  if (url.isEmpty) return null;
  try {
    if (isSlideAssetUrl(url)) {
      final data = await rootBundle.load(slideAssetPath(url));
      return pw.MemoryImage(data.buffer.asUint8List());
    }
    final bytes = decodeSlideImageBytes(url);
    if (bytes != null) return pw.MemoryImage(bytes);
  } catch (_) {}
  return null;
}

String _pdfText(String value) {
  const replacements = {
    '∝': '~',
    '×': 'x',
    '—': '-',
    '–': '-',
    '…': '...',
    '→': '->',
    '‘': "'",
    '’': "'",
    '“': '"',
    '”': '"',
  };
  var text = value;
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text;
}

String _fileSafe(String topic) {
  final trimmed = topic.trim().isEmpty ? 'syntra-lesson' : topic.trim();
  return trimmed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

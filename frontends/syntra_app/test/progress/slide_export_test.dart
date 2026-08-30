import 'package:flutter_test/flutter_test.dart';
import 'package:syntra_app/debug/mock_lesson.dart';
import 'package:syntra_app/progress/slide_deck.dart';
import 'package:syntra_app/progress/slide_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a PDF for the coastal slide deck', () async {
    final deck = SlideDeck.tryParse(mockPipeline().slides);
    expect(deck, isNotNull);
    expect(deck!.slides.any((slide) => slide.visualAsset?.ready == true), isTrue);

    final bytes = await buildSlideDeckPdf(
      deck: deck,
      topic: mockTopic,
      subject: 'Geography',
      board: 'AQA',
      level: 'GCSE',
    );
    expect(bytes.length, greaterThan(2000));
    expect(bytes[0], 0x25); // %PDF
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syntra_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('intake studio shows SYNTRA briefing canvas', (tester) async {
    await tester.pumpWidget(const SyntraApp());
    await tester.pump();

    expect(find.text('SYNTRA'), findsWidgets);
    expect(find.text('Your AI teaching companion.'), findsOneWidget);
    expect(find.text('GCSE'), findsOneWidget);
    expect(find.text('A-Level'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

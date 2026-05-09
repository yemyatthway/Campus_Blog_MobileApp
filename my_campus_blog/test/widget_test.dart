import 'package:flutter_test/flutter_test.dart';
import 'package:my_campus_blog/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('shows blog home screen', (tester) async {
    await tester.pumpWidget(const MyCampusBlogApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('My Campus Blog'), findsOneWidget);
    expect(find.text('New post'), findsOneWidget);
  });
}

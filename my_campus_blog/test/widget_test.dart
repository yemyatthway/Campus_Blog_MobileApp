import 'package:flutter_test/flutter_test.dart';
import 'package:my_campus_blog/main.dart';

void main() {
  testWidgets('shows blog home screen', (tester) async {
    await tester.pumpWidget(const MyCampusBlogApp());

    expect(find.text('My Campus Blog'), findsOneWidget);
    expect(find.text('No posts yet'), findsOneWidget);
  });
}

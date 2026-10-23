import 'package:flutter_test/flutter_test.dart';
import 'package:almajed_pro/main.dart';

void main() {
  testWidgets('renders the almajedPRO login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AlmajedProApp());

    expect(find.text('الماجد PRO'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
  });
}

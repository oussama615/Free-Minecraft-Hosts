import 'package:flutter_test/flutter_test.dart';
import 'package:emp_control_app/main.dart';
import 'package:emp_control_app/services/api_client.dart';

void main() {
  testWidgets('shows the EMP Control login screen', (tester) async {
    await tester.pumpWidget(EMPControlApp(api: ApiClient()));
    await tester.pumpAndSettle();

    expect(find.text('EMP CONTROL'), findsOneWidget);
    expect(find.text('Enter Control Panel'), findsOneWidget);
  });
}

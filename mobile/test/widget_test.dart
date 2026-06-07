import 'package:flutter_test/flutter_test.dart';
import 'package:strawio_voicechat/main.dart';

void main() {
  testWidgets('shows StrawIO VoiceChat startup screen', (tester) async {
    await tester.pumpWidget(const StrawIOVoiceChatApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('StrawIO'), findsOneWidget);
    expect(find.text('VOICECHAT'), findsOneWidget);
    expect(find.text('StrawIO Studio'), findsOneWidget);
  });
}

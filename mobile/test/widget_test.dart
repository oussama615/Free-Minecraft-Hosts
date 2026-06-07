import 'package:flutter_test/flutter_test.dart';
import 'package:strawio_voicechat/main.dart';

void main() {
  testWidgets('shows StrawIO VoiceChat standby screen', (tester) async {
    await tester.pumpWidget(const StrawIOVoiceChatApp());
    await tester.pumpAndSettle();

    expect(find.text('StrawIO'), findsOneWidget);
    expect(find.text('VOICECHAT'), findsOneWidget);
    expect(find.text('Not detected'), findsOneWidget);
    expect(find.text('Waiting for Minecraft'), findsOneWidget);
    expect(find.text('StrawIO Studio'), findsOneWidget);
  });
}

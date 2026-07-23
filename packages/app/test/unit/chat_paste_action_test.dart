import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/page/chat/chat_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chat paste action consumes key and calls paste handler', () async {
    var calls = 0;
    final action = buildChatPasteTextAction(() async {
      calls++;
    });
    const intent = PasteTextIntent(SelectionChangedCause.keyboard);

    expect(action.consumesKey(intent), isTrue);

    const ActionDispatcher().invokeAction(action, intent);
    await pumpEventQueue();

    expect(calls, 1);
  });
}

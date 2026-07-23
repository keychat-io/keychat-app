import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/models/models.dart';
import 'package:super_clipboard/super_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildPasteboardFileName', () {
    test('adds a MIME extension when suggested name has no extension', () {
      final result = buildPasteboardFileName(
        suggestedName: 'keychat-key-derivation',
        sourceFileName: '',
        mimeType: 'image/jpeg',
        timestamp: 123,
      );

      expect(result.fileName, 'keychat-key-derivation.jpg');
      expect(result.shouldClearText, isFalse);
    });

    test('keeps suggested name when it already has an extension', () {
      final result = buildPasteboardFileName(
        suggestedName: 'keychat-key-derivation.jpg',
        sourceFileName: '',
        mimeType: 'image/png',
        timestamp: 123,
      );

      expect(result.fileName, 'keychat-key-derivation.jpg');
      expect(result.shouldClearText, isFalse);
    });

    test(
      'uses typed filename with MIME extension for unnamed clipboard data',
      () {
        final result = buildPasteboardFileName(
          suggestedName: null,
          sourceFileName: 'diagram.custom',
          mimeType: 'image/png',
          timestamp: 123,
        );

        expect(result.fileName, 'diagram.png');
        expect(result.shouldClearText, isTrue);
      },
    );

    test('falls back to generated filename when clipboard has no name', () {
      final result = buildPasteboardFileName(
        suggestedName: null,
        sourceFileName: '',
        mimeType: 'image/png',
        timestamp: 123,
      );

      expect(result.fileName, 'pasteboard_123.png');
      expect(result.shouldClearText, isFalse);
    });
  });

  group('buildPasteboardFileFormats', () {
    test('prefers markdown files before generic plain text files', () {
      final formats = buildPasteboardFileFormats();
      final mdIndex = formats.indexWhere(
        (entry) => entry.format == Formats.md,
      );
      final plainTextIndex = formats.indexWhere(
        (entry) => entry.format == Formats.plainTextFile,
      );

      expect(mdIndex, isNonNegative);
      expect(plainTextIndex, isNonNegative);
      expect(mdIndex, lessThan(plainTextIndex));
      expect(formats[mdIndex].mediaType, MessageMediaType.file);
    });
  });

  group('localPasteboardFilePathFromUri', () {
    test('returns local path for file URI', () {
      expect(
        localPasteboardFilePathFromUri(Uri.file('/tmp/notes.md')),
        '/tmp/notes.md',
      );
    });

    test('ignores non-file URI', () {
      expect(
        localPasteboardFilePathFromUri(Uri.parse('https://example.com/a.md')),
        isNull,
      );
    });
  });

  group('pasteboardMediaTypeForFilePath', () {
    test('classifies markdown as a file', () {
      expect(
        pasteboardMediaTypeForFilePath('/tmp/notes.md'),
        MessageMediaType.file,
      );
    });

    test('classifies clipboard-specific image extensions as images', () {
      expect(
        pasteboardMediaTypeForFilePath('/tmp/photo.heic'),
        MessageMediaType.image,
      );
    });

    test('classifies clipboard-specific video extensions as videos', () {
      expect(
        pasteboardMediaTypeForFilePath('/tmp/movie.mpeg'),
        MessageMediaType.video,
      );
    });
  });

  group('handlePasteboard', () {
    test(
      'falls back to Flutter clipboard when SystemClipboard is unavailable',
      () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        void clearSystemClipboardMock() {
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        }

        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': 'world'};
          }
          return null;
        });
        addTearDown(clearSystemClipboardMock);

        final controller = ChatController(
          Room(identityId: 1, toMainPubkey: '', npub: ''),
        );
        final textController = TextEditingController(text: 'hello ')
          ..selection = const TextSelection.collapsed(offset: 6);
        controller.textEditingController = textController;

        await controller.handlePasteboard();

        expect(textController.text, 'hello world');
        expect(textController.selection.baseOffset, 11);
      },
    );
  });
}

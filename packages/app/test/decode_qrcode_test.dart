import 'package:app/models/keychat/qrcode_user_model.dart';
import 'package:app/utils.dart';
import 'package:test/test.dart';

void main() {
  // Add your test cases here
  test('Example test', () {
    String str =
        'H4sIAAAAAAAAEx2SybEYIQxEc/nnOUhCC4rDEaAtAudf1veJGjQ03a/5+fP+/nzfmLEjPZbwLg9prLgghFF6n53X4eYIxXytK8XhBstjxOabH0hW+is87onxSNGa0WSH/tDdymTOHXIwHbsY+7dfjcJEZIEvGJOnqBCQDB5JPLM3FoEyg90WwoGW01AOapyU+VZezzn8IQMT3ZUCaVY1UWFivNCaDh3lcwbo3scPRGgQDOPk6b1ld45qE+4KG8hafZFAr5b02k5JFcvgUAG/IYibbxUc7z38ZGxE3txN9qx+yU27UP8acFhSVGTLyQtVaZry8oqO4DmlEQNhJdvCsasfMf83YLRxAAvO7Zdk2FZrGW+AaoWSmh3eBMgHCqirNHdfNpZuCwRk+e2Ke4blmsu3BfoSlncS1lstRRHbWe40jM6Lvvv5LPdJaIMT+rDmMbwdh8xbqccvbiEHn5dnam6gaKAB34q39cMOB9S7Z+T1wvMlN/wPhAltpHYCAAA=';
    QRUserModel model = QRUserModel.fromShortString(str);
    logger.i(model);

    logger.d(DateTime.fromMillisecondsSinceEpoch(model.time));
    expect(2 + 2, equals(4));
  });
}

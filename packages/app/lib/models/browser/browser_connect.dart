import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'browser_connect.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class BrowserConnect extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String host;
  late String pubkey;
  bool autoLogin = false;
  String? favicon;
  late DateTime createdAt;

  BrowserConnect({required this.host, required this.pubkey, this.favicon}) {
    createdAt = DateTime.now();
  }

  @override
  List get props => [id, host, pubkey, favicon];

  static Future<List<BrowserConnect>> getAll(
      {int limit = 20, int offset = 0}) async {
    var list = await DBProvider.database.browserConnects
        .where(sort: Sort.desc)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return list;
  }

  static Future<List<BrowserConnect>> getAllByPubkey(
      {required String pubkey, int limit = 20, int offset = 0}) async {
    var list = await DBProvider.database.browserConnects
        .filter()
        .pubkeyEqualTo(pubkey)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return list;
  }

  static delete(Id id) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserConnects.delete(id);
    });
  }

  static Future<BrowserConnect?> getByHost(String host) async {
    return await DBProvider.database.browserConnects
        .filter()
        .hostEqualTo(host)
        .findFirst();
  }

  static save(BrowserConnect bc) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserConnects.put(bc);
    });
  }

  static Future deleteByPubkey(String pubkey) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserConnects
          .filter()
          .pubkeyEqualTo(pubkey)
          .deleteAll();
    });
  }
}

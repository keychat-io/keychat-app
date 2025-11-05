import 'package:keychat/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';

part 'browser_connect.g.dart';

@Collection(
  ignore: {
    'props',
  },
)
// ignore: must_be_immutable
class BrowserConnect extends Equatable {
  BrowserConnect({required this.host, required this.pubkey, this.favicon}) {
    createdAt = DateTime.now();
  }
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String host;
  late String pubkey;
  bool autoLogin = false;
  String? favicon;
  late DateTime createdAt;

  @override
  List get props => [id, host, pubkey, favicon];

  static Future<List<BrowserConnect>> getAll({
    int limit = 20,
    int offset = 0,
  }) async {
    final list = await DBProvider.database.browserConnects
        .where(sort: Sort.desc)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return list;
  }

  static Future<List<BrowserConnect>> getAllByPubkey({
    required String pubkey,
    int limit = 20,
    int offset = 0,
  }) async {
    final list = await DBProvider.database.browserConnects
        .filter()
        .pubkeyEqualTo(pubkey)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return list;
  }

  static Future<void> delete(Id id) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserConnects.delete(id);
    });
  }

  static Future<BrowserConnect?> getByHost(String host) async {
    return DBProvider.database.browserConnects
        .filter()
        .hostEqualTo(host)
        .findFirst();
  }

  static Future<int> save(BrowserConnect bc) async {
    late int id;
    await DBProvider.database.writeTxn(() async {
      id = await DBProvider.database.browserConnects.put(bc);
    });
    return id;
  }

  static Future<void> deleteByPubkey(String pubkey) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserConnects
          .filter()
          .pubkeyEqualTo(pubkey)
          .deleteAll();
    });
  }
}

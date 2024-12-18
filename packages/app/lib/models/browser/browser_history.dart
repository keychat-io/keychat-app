import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'browser_history.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class BrowserHistory extends Equatable {
  Id id = Isar.autoIncrement;

  late String url;
  String? title;
  late DateTime createdAt;

  BrowserHistory({required this.url, this.title}) {
    createdAt = DateTime.now();
  }

  @override
  List get props => [id, url, title];

  static Future<List<BrowserHistory>> getAll(
      {int limit = 20, int offset = 0}) async {
    var list = await DBProvider.database.browserHistorys
        .where()
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return list;
  }

  static deleteAll() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserHistorys.where().deleteAll();
    });
  }

  static delete(Id id) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserHistorys.delete(id);
    });
  }
}

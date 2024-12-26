import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'browser_bookmark.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class BrowserBookmark extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String url;
  int weight = 0;
  String? title;
  String? favicon;
  late DateTime createdAt;

  BrowserBookmark({required this.url, this.title, this.favicon}) {
    createdAt = DateTime.now();
  }

  @override
  List get props => [id, url, title, favicon];

  static Future<List<BrowserBookmark>> getAll(
      {int limit = 20, int offset = 0}) async {
    var list = await DBProvider.database.browserBookmarks
        .where(sort: Sort.desc)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return list;
  }

  static deleteAll() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserBookmarks.where().deleteAll();
    });
  }

  static delete(Id id) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserBookmarks.delete(id);
    });
  }
}

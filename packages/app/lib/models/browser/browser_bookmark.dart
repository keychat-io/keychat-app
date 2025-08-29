import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';

part 'browser_bookmark.g.dart';

@Collection(ignore: {'props'})
// ignore: must_be_immutable
class BrowserBookmark extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String url;
  int weight = 0;
  String? title;
  String? favicon;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isPin = false;

  BrowserBookmark({required this.url, this.title, this.favicon}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  @override
  List get props => [id, url, title, favicon];

  static Future<List<BrowserBookmark>> getAll() async {
    var list = await DBProvider.database.browserBookmarks
        .where()
        .sortByWeightDesc()
        .thenByUpdatedAtDesc()
        .findAll();
    return list;
  }

  static Future<void> deleteAll() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserBookmarks.where().deleteAll();
    });
  }

  static Future<void> delete(Id id) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserBookmarks.delete(id);
    });
  }

  static Future update(BrowserBookmark site) async {
    site.updatedAt = DateTime.now();
    await DBProvider.database.writeTxn(() async {
      DBProvider.database.browserBookmarks.put(site);
    });
  }

  static Future<void> add(
      {required String url, String? title, String? favicon}) async {
    await DBProvider.database.writeTxn(() async {
      BrowserBookmark model =
          BrowserBookmark(url: url, title: title, favicon: favicon);
      await DBProvider.database.browserBookmarks.put(model);
    });
  }

  static Future<BrowserBookmark?>? getByUrl(String url) async {
    return await DBProvider.database.browserBookmarks
        .filter()
        .urlEqualTo(url)
        .findFirst();
  }

  static Future<void> batchUpdateWeights(
      List<BrowserBookmark> bookmarks) async {
    await DBProvider.database.writeTxn(() async {
      for (int i = 0; i < bookmarks.length; i++) {
        bookmarks[i].weight = bookmarks.length - i;
        bookmarks[i].updatedAt = DateTime.now();
        await DBProvider.database.browserBookmarks.put(bookmarks[i]);
      }
    });
  }
}

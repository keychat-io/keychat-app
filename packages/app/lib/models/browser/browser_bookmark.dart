import 'package:keychat/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';

part 'browser_bookmark.g.dart';

@Collection(ignore: {'props'})
// ignore: must_be_immutable
class BrowserBookmark extends Equatable {
  BrowserBookmark({required this.url, this.title, this.favicon}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String url;
  int weight = 0;
  String? title;
  String? favicon;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isPin = false;

  @override
  List get props => [id, url, title, favicon];

  static Future<List<BrowserBookmark>> getAll() async {
    final list = await DBProvider.database.browserBookmarks
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

  static Future<void> update(BrowserBookmark site) async {
    site.updatedAt = DateTime.now();
    await DBProvider.database.writeTxn(() async {
      DBProvider.database.browserBookmarks.put(site);
    });
  }

  static Future<void> add({
    required String url,
    String? title,
    String? favicon,
  }) async {
    await DBProvider.database.writeTxn(() async {
      // Get the maximum weight from existing bookmarks
      final maxWeightBookmark = await DBProvider.database.browserBookmarks
          .where()
          .sortByWeightDesc()
          .findFirst();

      final newWeight = maxWeightBookmark?.weight ?? 0;

      final model = BrowserBookmark(url: url, title: title, favicon: favicon);
      model.weight = newWeight;
      await DBProvider.database.browserBookmarks.put(model);
    });
  }

  static Future<BrowserBookmark?>? getByUrl(String url) async {
    return DBProvider.database.browserBookmarks
        .filter()
        .urlEqualTo(url)
        .findFirst();
  }

  static Future<void> batchUpdateWeights(
    List<BrowserBookmark> bookmarks,
  ) async {
    await DBProvider.database.writeTxn(() async {
      for (var i = 0; i < bookmarks.length; i++) {
        bookmarks[i].weight = bookmarks.length - i;
        bookmarks[i].updatedAt = DateTime.now();
        await DBProvider.database.browserBookmarks.put(bookmarks[i]);
      }
    });
  }
}

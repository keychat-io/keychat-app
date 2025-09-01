import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';

part 'browser_favorite.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class BrowserFavorite extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String url;
  int weight = 0;
  String? title;
  String? favicon;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isPin = false;

  BrowserFavorite({required this.url, this.title, this.favicon}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  @override
  List get props => [id, url, title, favicon];

  static Future<List<BrowserFavorite>> getAll() async {
    return await DBProvider.database.browserFavorites
        .where()
        .sortByWeight()
        .thenByUpdatedAtDesc()
        .findAll();
  }

  static Future<void> delete(Id id) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserFavorites.delete(id);
    });
  }

  static Future<void> deleteByUrl(String url) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserFavorites
          .filter()
          .urlEqualTo(url)
          .deleteFirst();
    });
  }

  static Future update(BrowserFavorite site) async {
    site.updatedAt = DateTime.now();
    await DBProvider.database.writeTxn(() async {
      DBProvider.database.browserFavorites.put(site);
    });
  }

  static Future<BrowserFavorite?> getByUrl(String string) async {
    return await DBProvider.database.browserFavorites
        .filter()
        .urlEqualTo(string)
        .findFirst();
  }

  static Future<void> add(
      {required String url, String? title, String? favicon}) async {
    await DBProvider.database.writeTxn(() async {
      BrowserFavorite model =
          BrowserFavorite(url: url, title: title, favicon: favicon);
      await DBProvider.database.browserFavorites.put(model);
    });
  }

  static Future<void> updateWeight(BrowserFavorite bf, int newWeight) async {
    bf.weight = newWeight;
    bf.updatedAt = DateTime.now();
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserFavorites.put(bf);
    });
  }

  static Future<void> batchUpdateWeights(
      List<BrowserFavorite> favorites) async {
    await DBProvider.database.writeTxn(() async {
      for (int i = 0; i < favorites.length; i++) {
        favorites[i].weight = i;
        favorites[i].updatedAt = DateTime.now();
        await DBProvider.database.browserFavorites.put(favorites[i]);
      }
    });
  }

  static Future<void> setPin(BrowserFavorite bf) async {
    bf.weight = -1;
    bf.isPin = true;
    bf.updatedAt = DateTime.now();
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserFavorites.put(bf);
    });
  }
}

import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'browser_bookmark.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class BrowserBookmark extends Equatable {
  Id id = Isar.autoIncrement;

  late String url;
  int weight = 0;
  String? title;
  late DateTime createdAt;

  BrowserBookmark({required this.url, this.title}) {
    createdAt = DateTime.now();
  }

  @override
  List get props => [id, url, title];
}

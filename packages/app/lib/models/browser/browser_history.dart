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
}

import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'relay.g.dart';

enum RelayStatusEnum {
  init,
  noAcitveRelay,
  connecting,
  failed,
  allFailed,
  connected,
  noNetwork
}

@Collection(ignore: {'props'})
// ignore: must_be_immutable
class Relay extends Equatable {
  Id id = Isar.autoIncrement;

  late String url;
  bool isDefault = false;
  bool read = true;
  bool write = true;
  bool active = true;
  DateTime updatedAt = DateTime.now();
  String? errorMessage;
  bool isEnableNip104 = false;

  Relay(this.url);

  @override
  List<Object> get props => [id, url, read, write, active, isDefault];

  static Relay empty() {
    return Relay('');
  }
}

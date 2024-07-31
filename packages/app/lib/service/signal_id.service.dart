class SignalIdService {
  static SignalIdService? _instance;
  SignalIdService._();
  static SignalIdService get instance => _instance ??= SignalIdService._();
}

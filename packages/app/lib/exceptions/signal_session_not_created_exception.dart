/// Exception thrown when Signal session has not been created yet
class SignalSessionNotCreatedException implements Exception {
  SignalSessionNotCreatedException();

  @override
  String toString() {
    return 'The signal session has not yet been created or deleted.';
  }
}

class ConnectivityReconnectState {
  bool _hasObservedConnectivity = false;
  bool _wasOnline = false;
  bool _workPending = false;

  bool get workPending => _workPending;

  bool observe(bool online) {
    if (online && (!_hasObservedConnectivity || !_wasOnline)) {
      _workPending = true;
    }
    _hasObservedConnectivity = true;
    _wasOnline = online;
    return online && _workPending;
  }

  void complete({required bool succeeded}) {
    _workPending = !succeeded;
  }
}

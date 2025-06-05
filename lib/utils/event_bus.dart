import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  final _controllers = <String, StreamController>{};

  factory EventBus() => _instance;

  EventBus._internal();

  void emit(String event, [dynamic data]) {
    if (!_controllers.containsKey(event)) {
      _controllers[event] = StreamController.broadcast();
    }
    _controllers[event]!.add(data);
  }

  Stream on(String event) {
    if (!_controllers.containsKey(event)) {
      _controllers[event] = StreamController.broadcast();
    }
    return _controllers[event]!.stream;
  }

  void dispose(String event) {
    if (_controllers.containsKey(event)) {
      _controllers[event]!.close();
      _controllers.remove(event);
    }
  }

  void disposeAll() {
    for (var controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}

// Event names
class AppEvents {
  static const String balanceUpdated = 'balance_updated';
  static const String powerUpUsed = 'power_up_used';
  static const String profileUpdated = 'profile_updated';
  static const String locationUpdated = 'location_updated';
  static const String gameStateChanged = 'game_state_changed';
  static const String purchaseCompleted = 'purchase_completed';
  static const String errorOccurred = 'error_occurred';
}

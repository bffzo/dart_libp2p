import 'package:dart_libp2p/p2p/security/noise/handshake_state.dart';
import 'package:meta/meta.dart';

/// Manages state transitions for the Noise XX handshake pattern
class NoiseStateMachine {
  NoiseStateMachine(this._isInitiator) : _state = XXHandshakeState.initial;
  final bool _isInitiator;
  XXHandshakeState _state;

  /// Gets the current state
  XXHandshakeState get state => _state;

  /// Validates if a read operation is allowed in the current state
  @visibleForTesting
  void validateRead() {
    switch (_state) {
      case XXHandshakeState.initial:
        if (_isInitiator) {
          throw StateError('Initiator cannot receive first message');
        }
      case XXHandshakeState.sentE:
        if (!_isInitiator) {
          throw StateError('Responder cannot receive second message');
        }
      case XXHandshakeState.sentEES:
        if (_isInitiator) {
          throw StateError('Initiator cannot receive third message');
        }
      case XXHandshakeState.complete:
        throw StateError('Cannot read message in completed state');
      case XXHandshakeState.error:
        throw StateError('Cannot read message in error state');
    }
  }

  /// Validates if a write operation is allowed in the current state
  @visibleForTesting
  void validateWrite() {
    switch (_state) {
      case XXHandshakeState.initial:
        if (!_isInitiator) {
          throw StateError('Responder cannot send first message');
        }
      case XXHandshakeState.sentE:
        if (_isInitiator) {
          throw StateError('Initiator cannot send second message');
        }
      case XXHandshakeState.sentEES:
        if (!_isInitiator) {
          throw StateError('Responder cannot send third message');
        }
      case XXHandshakeState.complete:
        throw StateError('Cannot write message in completed state');
      case XXHandshakeState.error:
        throw StateError('Cannot write message in error state');
    }
  }

  /// Transitions to the next state after a successful read
  void transitionAfterRead() {
    validateRead();
    switch (_state) {
      case XXHandshakeState.initial:
        _state = XXHandshakeState.sentE;
      case XXHandshakeState.sentE:
        _state = XXHandshakeState.sentEES;
      case XXHandshakeState.sentEES:
        _state = XXHandshakeState.complete;
      default:
        throw StateError('Invalid state transition from $_state');
    }
  }

  /// Transitions to the next state after a successful write
  void transitionAfterWrite() {
    validateWrite();
    switch (_state) {
      case XXHandshakeState.initial:
        _state = XXHandshakeState.sentE;
      case XXHandshakeState.sentE:
        _state = XXHandshakeState.sentEES;
      case XXHandshakeState.sentEES:
        _state = XXHandshakeState.complete;
      default:
        throw StateError('Invalid state transition from $_state');
    }
  }

  /// Transitions to error state
  void transitionToError() {
    _state = XXHandshakeState.error;
  }

  /// Returns true if the handshake is complete
  bool get isComplete => _state == XXHandshakeState.complete;
}

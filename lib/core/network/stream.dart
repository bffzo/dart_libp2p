import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_libp2p/core/network/common.dart';
import 'package:dart_libp2p/core/network/conn.dart';
import 'package:dart_libp2p/core/network/rcmgr.dart'
    show StreamManagementScope;
import 'package:dart_libp2p/utils/varint.dart'; // Import new types

/// Represents a bidirectional channel between two agents in
/// a libp2p network. "agent" is as granular as desired, potentially
/// being a "request -> reply" pair, or whole protocols.
///
/// Streams are backed by a multiplexer underneath the hood.
abstract class P2PStream implements Stream<int>, IOSink {
  P2PStream({
    this.encoding = utf8,
  }) {
    _inputController.stream.listen((chunk) async {
      final writeFuture = rawWrite(chunk);
      _pendingWrites.add(writeFuture);
      await writeFuture.whenComplete(() => _pendingWrites.remove(writeFuture));
    });
  }

  final Encoding encoding;

  /// Returns an identifier that uniquely identifies this Stream within this
  /// host, during this run. Stream IDs may repeat across restarts.
  String id();

  /// Returns the protocol ID associated with this stream
  String protocol();

  /// Sets the protocol for this stream
  Future<void> setProtocol(String id);

  /// Returns metadata pertaining to this stream
  StreamStats stat();

  /// Returns the connection this stream is part of
  Conn get conn; // Changed to a getter, represents the underlying connection

  /// Returns the management view of this stream's resource scope
  StreamManagementScope scope(); // Changed to StreamManagementScope

  /// Reads data from the stream
  Future<Uint8List> rawRead([int? maxLength]);

  /// Writes data to the stream
  Future<void> rawWrite(Uint8List data);

  /// Returns a Dart Stream of the incoming data
  P2PStream get incoming;

  /// Closes the stream for writing but leaves it open for reading
  Future<void> closeWrite();

  /// Closes the stream for reading but leaves it open for writing
  Future<void> closeRead();

  /// Closes both ends of the stream
  Future<void> reset();

  /// Sets a deadline for both reading and writing operations
  Future<void> setDeadline(DateTime? time);

  /// Sets a deadline for reading operations
  Future<void> setReadDeadline(DateTime time);

  /// Sets a deadline for writing operations
  Future<void> setWriteDeadline(DateTime time);

  /// Returns true if the stream is closed
  bool get isClosed;

  /// Returns true if the stream is ready for writing
  /// More precise than !isClosed as it excludes closing state
  bool get isWritable;

  @override
  void write(Object? object) {
    add(encoding.encode(object.toString()));
  }

  final _inputController = StreamController<Uint8List>();
  var _leftover = Uint8List(0);
  final List<Future<void>> _pendingWrites = [];

  @override
  void add(List<int> data) => _inputController.add(Uint8List.fromList(data));

  @override
  Stream<int> takeWhile(bool Function(int element) test) async* {
    while (true) {
      final value = await first;
      if (test(value)) {
        break;
      }
      yield value;
    }
  }

  @override
  Stream<int> take(int count) async* {
    if (count <= 0) return;

    var emitted = 0;

    // First, use any bytes left over from the previous call.
    if (_leftover.isNotEmpty) {
      for (final byte in _leftover) {
        if (emitted >= count) {
          // Store the remaining part of the buffer for the next call.
          final start = _leftover.indexOf(byte);
          _leftover = Uint8List.fromList(_leftover.sublist(start));
          break;
        }
        yield byte;
        emitted++;
      }
      if (emitted >= count) {
        // All requested items came from the leftover buffer.
        _leftover = Uint8List(0);
        return;
      }
      // Leftover buffer exhausted.
      _leftover = Uint8List(0);
    }

    // Then keep reading from the underlying source until we have enough.
    while (emitted < count) {
      final buffer = await rawRead();

      // End‑of‑stream signal.
      if (buffer.isEmpty) break;

      // If the buffer contains more bytes than we still need,
      // emit what we need and keep the rest.
      if (buffer.length > (count - emitted)) {
        final needed = count - emitted;
        for (var i = 0; i < needed; i++) {
          yield buffer[i];
          emitted++;
        }
        // Save the surplus for the next `take` call.
        _leftover = Uint8List.fromList(buffer.sublist(needed));
        break;
      } else {
        // Buffer fits entirely into the remaining quota.
        for (final byte in buffer) {
          yield byte;
          emitted++;
        }
      }
    }
  }

  Future<Uint8List> readBytes() async {
    final count = await parseVarintStream(this);
    final data = await take(count).toList();
    return Uint8List.fromList(data);
  }

  void writeBytes(List<int> data) {
    sendVarint(data.length);
    add(data);
  }

  void sendVarint(int count) {
    final encodedVarint = encodeVarint(count);
    add(encodedVarint);
  }

  @override
  Future<void> close() async {
    await _inputController.close();
    await flush();
  }

  @override
  Future<int> get first => take(1).first;

  @override
  Future<dynamic> flush() async {
    while (_pendingWrites.isNotEmpty) {
      // copying the current set to avoid a race
      final current = List<Future<void>>.from(_pendingWrites);
      await Future.wait(current);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stores metadata pertaining to a given Stream
class StreamStats {
  StreamStats({
    required this.direction,
    required this.opened,
    this.limited = false,
    this.extra = const {},
  });

  /// Direction specifies whether this is an inbound or an outbound connection
  final Direction direction; // Will now come from common.dart

  /// Timestamp when this connection was opened
  final DateTime opened;

  /// Indicates that this connection is limited
  final bool limited;

  /// Additional metadata about this connection
  final Map<dynamic, dynamic> extra;
}

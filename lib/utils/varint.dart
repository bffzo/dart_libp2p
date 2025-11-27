import 'dart:typed_data';

/// Encodes an integer as a variable-length integer (VarInt).
///
/// [value]: The integer to encode.
///
/// Returns: A list of bytes representing the VarInt encoding of the input integer.
Uint8List encodeVarint(int value) {
  final bytes = <int>[];
  var localValue = value;
  do {
    var byte = localValue & 0x7F;
    localValue = localValue >> 7;
    if (localValue != 0) {
      byte |= 0x80;
    }
    bytes.add(byte);
  } while (localValue != 0);

  return Uint8List.fromList(bytes);
}

/// Decodes a varint from a byte array.
int decodeVarint(Uint8List data) {
  var result = 0;
  var shift = 0;
  var i = 0;

  while (i < data.length) {
    final byte = data[i];
    result |= (byte & 0x7F) << shift;
    if ((byte & 0x80) == 0) {
      return result;
    }
    shift += 7;
    i++;
  }

  throw const FormatException('Invalid varint encoding');
}

Future<int> parseVarintStream(Stream<int> stream) async {
  var value = 0;
  var shift = 0;
  var bytesRead = 0;

  // Maximum number of bytes to represent a 64-bit varint is 10.
  const maxBytes = 10;

  for (var i = 0; bytesRead < maxBytes; i++) {
    final byte = await stream.first;
    // Add to the result.
    value |= (byte & 0x7F) << shift;
    bytesRead++;

    // If the MSB is not set, this is the last byte.
    if ((byte & 0x80) == 0) {
      return value;
    }

    shift += 7;
  }

  // If we exit the loop without returning, the varint is malformed
  // because we either hit the end of input or exceeded the maximum allowed bytes.
  throw const FormatException('Malformed varint or insufficient bytes.');
}

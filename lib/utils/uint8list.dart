import 'dart:typed_data';

/// Concatenates a list of [Uint8List] objects into a single [Uint8List].
///
/// This function efficiently combines multiple `Uint8List`s into one, avoiding unnecessary copying.
/// It calculates the total length of all input lists and creates a new `Uint8List` with that size.
/// Then, it copies each input list's contents into the result in order.
///
/// # Parameters
/// * [lists]: A [List] of [Uint8List] objects to be concatenated.  Must not be null or contain null elements.
///
/// # Returns
/// A new [Uint8List] containing all the data from the input lists, concatenated together.
///
/// # Example
/// ```dart
/// final list1 = Uint8List.fromList([1, 2, 3]);
/// final list2 = Uint8List.fromList([4, 5, 6]);
/// final list3 = Uint8List.fromList([7, 8, 9]);
///
/// final concatenatedList = concatenateUint8Lists([list1, list2, list3]);
/// print(concatenatedList); // Output: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9])
/// ```
Uint8List concatenateUint8Lists(List<Uint8List> lists) {
  // Calculate the total length
  final totalLength = lists.fold(0, (sum, list) => sum + list.length);

  // Create a new Uint8List with the total length
  final result = Uint8List(totalLength);

  // Copy each Uint8List into the result
  var offset = 0;
  for (final list in lists) {
    result.setRange(offset, offset + list.length, list);
    offset += list.length;
  }

  return result;
}

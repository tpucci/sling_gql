import 'dart:typed_data';

/// Transforms every row value on its way to and from the database: the hook
/// to encrypt the store with the cipher of the app's choice (this package
/// ships none).
///
/// Without a codec rows hold their JSON as text; with one they hold
/// `encode(utf8 JSON bytes)` as a blob, and [decode] gets those bytes back.
/// Both run synchronously, on every saved row and on every row read at open
/// (in the background isolate with `hydrateInIsolate`, which then needs a
/// codec it can send there: plain Dart fields, no native handles).
///
/// ```dart
/// final class AesGcmCodec implements SqfliteCodec {
///   AesGcmCodec(this.key, this.keyId);
///   final Uint8List key; // from the platform keystore
///   final String keyId;
///
///   @override
///   String get id => 'aes-gcm:$keyId';
///   @override
///   Uint8List encode(Uint8List bytes) => /* nonce + seal(bytes) */;
///   @override
///   Uint8List decode(Uint8List bytes) => /* open(bytes) */;
/// }
/// ```
///
/// For whole-file encryption (indexes and metadata included) pass an
/// SQLCipher `databaseFactory` instead.
abstract interface class SqfliteCodec {
  /// Names the codec and its key in the database. A store written under
  /// another id (or without a codec) is wiped at open, not decoded: change
  /// it whenever stored rows can no longer be decoded (another cipher, a
  /// rotated key).
  String get id;

  /// The stored form of a row's UTF-8 JSON [bytes].
  Uint8List encode(Uint8List bytes);

  /// The UTF-8 JSON bytes back from what [encode] returned. Throwing (a
  /// wrong key, a tampered row) wipes the store at open, reported to
  /// `onError`.
  Uint8List decode(Uint8List bytes);
}

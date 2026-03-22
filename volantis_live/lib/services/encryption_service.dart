import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Service for encrypting and decrypting downloaded recordings
/// Uses AES-256-CBC encryption with keys stored in secure storage
class EncryptionService {
  static EncryptionService? _instance;
  static const String _keyStorageKey = 'volantis_recording_encryption_key';
  static const String _ivStorageKey = 'volantis_recording_encryption_iv';

  final FlutterSecureStorage _secureStorage;
  Key? _encryptionKey;
  IV? _encryptionIV;

  EncryptionService._()
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  static EncryptionService get instance {
    _instance ??= EncryptionService._();
    return _instance!;
  }

  /// Initialize the encryption service - must be called before using encryption
  Future<void> init() async {
    await _loadOrGenerateKey();
  }

  /// Load existing key or generate a new one
  Future<void> _loadOrGenerateKey() async {
    // Try to load existing key
    final storedKey = await _secureStorage.read(key: _keyStorageKey);
    final storedIV = await _secureStorage.read(key: _ivStorageKey);

    if (storedKey != null && storedIV != null) {
      // Use existing key
      _encryptionKey = Key(base64Decode(storedKey));
      _encryptionIV = IV(base64Decode(storedIV));
    } else {
      // Generate new key and IV
      _encryptionKey = Key.fromSecureRandom(32); // 256-bit key
      _encryptionIV = IV.fromSecureRandom(16); // 128-bit IV

      // Store them securely
      await _secureStorage.write(
        key: _keyStorageKey,
        value: base64Encode(_encryptionKey!.bytes),
      );
      await _secureStorage.write(
        key: _ivStorageKey,
        value: base64Encode(_encryptionIV!.bytes),
      );
    }
  }

  /// Get the encryption key (for storage reference only - never exposed)
  String _getKeyFingerprint() {
    if (_encryptionKey == null) {
      throw Exception('Encryption service not initialized');
    }
    // Create a hash of the key for identification without exposing the key
    final keyBytes = _encryptionKey!.bytes;
    final hash = sha256.convert(keyBytes);
    return hash.toString();
  }

  /// Encrypt data
  Uint8List encrypt(Uint8List data) {
    if (_encryptionKey == null || _encryptionIV == null) {
      throw Exception('Encryption service not initialized');
    }

    final encrypter = Encrypter(AES(_encryptionKey!, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: _encryptionIV);
    return encrypted.bytes;
  }

  /// Decrypt data
  Uint8List decrypt(Uint8List encryptedData) {
    if (_encryptionKey == null || _encryptionIV == null) {
      throw Exception('Encryption service not initialized');
    }

    final encrypter = Encrypter(AES(_encryptionKey!, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      Encrypted(encryptedData),
      iv: _encryptionIV,
    );
    return Uint8List.fromList(decrypted);
  }

  /// Encrypt a file and save to destination
  Future<void> encryptFile(String sourcePath, String destPath) async {
    final sourceFile = File(sourcePath);
    final sourceData = await sourceFile.readAsBytes();
    final encryptedData = encrypt(sourceData);

    final destFile = File(destPath);
    await destFile.writeAsBytes(encryptedData);
  }

  /// Decrypt a file and return the decrypted data
  Future<Uint8List> decryptFile(String encryptedPath) async {
    final encryptedFile = File(encryptedPath);
    final encryptedData = await encryptedFile.readAsBytes();
    return decrypt(encryptedData);
  }

  /// Decrypt a file and save to destination (for temporary playback)
  Future<String> decryptToTempFile(
    String encryptedPath,
    String fileName,
  ) async {
    final decryptedData = await decryptFile(encryptedPath);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(decryptedData);

    return tempFile.path;
  }

  /// Delete encryption keys (use with caution - will make all downloads unreadable)
  Future<void> deleteKeys() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    _encryptionKey = null;
    _encryptionIV = null;
  }

  /// Check if encryption is initialized
  bool get isInitialized => _encryptionKey != null && _encryptionIV != null;
}

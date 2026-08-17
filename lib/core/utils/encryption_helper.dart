import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionHelper {
  // In a real production app, retrieve this from a secure backend or Keystore/KeyChain.
  // For this implementation, we use a fixed key.
  static final _key = encrypt.Key.fromUtf8(
    'TalentBaySecureMessagingKey2024!',
  ); // 32 chars
  static final _iv = encrypt.IV.fromUtf8(
    'TalentBayIV2024!',
  ); // 16 chars Fixed IV
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  /// Encrypts a plain text string.
  static String encryptMessage(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      // Fallback or rethrow depending on needs. For now return original to avoid loss,
      // or empty string to fail safe.
      print('Encryption error: $e');
      return plainText;
    }
  }

  /// Decrypts an encrypted string (base64).
  static String decryptMessage(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    try {
      return _encrypter.decrypt64(encryptedText, iv: _iv);
    } catch (e) {
      print('Decryption error: $e');
      return 'Error decrypting message';
    }
  }
}

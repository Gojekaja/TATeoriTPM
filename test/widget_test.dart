import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:millionaire_game/utils/password_hasher.dart';
import 'package:millionaire_game/main.dart'; // Pastikan ini ada

void main() {
  group('PasswordHasher', () {
    test('password should be hashed correctly', () {
      const String password = 'mySecurePassword123';
      final String hashedPassword = PasswordHasher.hashPassword(password);

      // Menampilkan hasil hashing di konsol test
      debugPrint('Original Password: $password');
      debugPrint('Hashed Password: $hashedPassword');

      // Verifikasi yang sudah ada
      expect(hashedPassword, isNot(equals(password)));
      expect(hashedPassword.length, equals(64));

      final String hashedPasswordAgain = PasswordHasher.hashPassword(password);
      expect(hashedPassword, equals(hashedPasswordAgain));

      const String anotherPassword = 'anotherSecurePassword456';
      final String anotherHashedPassword = PasswordHasher.hashPassword(
        anotherPassword,
      );
      expect(hashedPassword, isNot(equals(anotherHashedPassword)));
    });

    test('password verification should work correctly', () {
      const String password = 'mySecurePassword123';
      final String hashedPassword = PasswordHasher.hashPassword(password);

      // Verifikasi bahwa password asli yang benar dapat diverifikasi
      expect(PasswordHasher.verifyPassword(password, hashedPassword), isTrue);

      // Verifikasi bahwa password yang salah tidak dapat diverifikasi
      const String wrongPassword = 'wrongPassword';
      expect(
        PasswordHasher.verifyPassword(wrongPassword, hashedPassword),
        isFalse,
      );

      // Verifikasi penanganan kasus jika hashed password kosong
      expect(PasswordHasher.verifyPassword(password, ''), isFalse);
      // Verifikasi penanganan kasus jika input password kosong
      expect(PasswordHasher.verifyPassword('', hashedPassword), isFalse);
    });

    test('empty password should throw an exception when hashing', () {
      // Menguji kondisi di mana password kosong seharusnya memicu exception saat hashing
      expect(() => PasswordHasher.hashPassword(''), throwsA(isA<Exception>()));
    });
  });
}

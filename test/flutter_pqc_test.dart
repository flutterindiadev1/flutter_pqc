import 'package:flutter_pqc/flutter_pqc.dart';
import 'package:test/test.dart';
import 'dart:convert';

void main() {
  group('ML-KEM-512 Encapsulation and Decapsulation', () {
    test('Successfully matches shared secrets', () {
      final kem = PqCryptoKem(PqKemAlgorithm.mlKem512);
      
      // 1. Alice generates Keypair
      final keypair = kem.generateKeyPair();
      final alicePublicKey = keypair[0];
      final aliceSecretKey = keypair[1];
      
      // 2. Bob encapsulates a shared secret using Alice's public key
      final encaps = kem.encapsulate(alicePublicKey);
      final ciphertext = encaps[0];
      final bobSharedSecret = encaps[1];
      
      // 3. Alice decapsulates the ciphertext using her secret key
      final aliceSharedSecret = kem.decapsulate(ciphertext, aliceSecretKey);
      
      // 4. Verify shared secrets match perfectly
      expect(aliceSharedSecret, equals(bobSharedSecret));
      
      kem.dispose();
    });
  });

  group('ML-DSA-44 Digital Signatures', () {
    test('Successfully signs and verifies a message', () {
      final sig = PqCryptoSig(PqSigAlgorithm.mlDsa44);
      
      // 1. Generate Keypair
      final keypair = sig.generateKeyPair();
      final publicKey = keypair[0];
      final secretKey = keypair[1];
      
      // 2. Sign a message
      final message = utf8.encode('Hello Post-Quantum World!');
      final signature = sig.sign(message, secretKey);
      
      // 3. Verify the signature
      final isValid = sig.verify(message, signature, publicKey);
      expect(isValid, isTrue);
      
      // 4. Verify a tampered message fails
      final tamperedMessage = utf8.encode('Hello Post-Quantum World?');
      final isTamperedValid = sig.verify(tamperedMessage, signature, publicKey);
      expect(isTamperedValid, isFalse);
      
      sig.dispose();
    });
  });
}

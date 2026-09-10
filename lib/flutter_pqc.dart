import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'flutter_pqc_bindings_generated.dart';

export 'flutter_pqc_sig.dart';

/// Supported Post-Quantum Key Encapsulation Mechanism (KEM) algorithms.
class PqKemAlgorithm {
  static const String mlKem512 = 'ML-KEM-512';
  static const String mlKem768 = 'ML-KEM-768';
  static const String mlKem1024 = 'ML-KEM-1024';
  static const String kyber512 = 'Kyber512';
  static const String kyber768 = 'Kyber768';
  static const String kyber1024 = 'Kyber1024';
  static const String frodoKem640Aes = 'FrodoKEM-640-AES';
  static const String frodoKem640Shake = 'FrodoKEM-640-SHAKE';
  
  // Private constructor to prevent instantiation
  PqKemAlgorithm._();
}

/// Wrapper class for Post-Quantum Key Encapsulation Mechanisms (KEMs).
class PqCryptoKem {
  late final Pointer<OQS_KEM> _kem;

  /// Creates a new KEM instance for the given algorithm name (e.g., 'ML-KEM-512').
  PqCryptoKem(String algName) {
    final algNameC = algName.toNativeUtf8().cast<Char>();
    _kem = OQS_KEM_new(algNameC);
    calloc.free(algNameC);

    if (_kem == nullptr) {
      throw Exception('Algorithm not supported or disabled: $algName');
    }
  }

  /// Disposes of the KEM instance and frees native memory.
  void dispose() {
    if (_kem != nullptr) {
      OQS_KEM_free(_kem);
    }
  }

  /// Generates a public and secret key pair.
  /// 
  /// Returns a tuple containing `[publicKey, secretKey]` as Uint8Lists.
  List<Uint8List> generateKeyPair() {
    final pubKey = calloc<Uint8>(_kem.ref.length_public_key);
    final secKey = calloc<Uint8>(_kem.ref.length_secret_key);

    final status = OQS_KEM_keypair(_kem, pubKey, secKey);
    if (status != OQS_STATUS.OQS_SUCCESS) {
      calloc.free(pubKey);
      calloc.free(secKey);
      throw Exception('Failed to generate keypair');
    }

    final pubList = Uint8List.fromList(
        pubKey.asTypedList(_kem.ref.length_public_key));
    final secList = Uint8List.fromList(
        secKey.asTypedList(_kem.ref.length_secret_key));

    calloc.free(pubKey);
    calloc.free(secKey);

    return [pubList, secList];
  }

  /// Encapsulates a shared secret using the given public key.
  /// 
  /// Returns a tuple containing `[ciphertext, sharedSecret]`.
  List<Uint8List> encapsulate(Uint8List publicKey) {
    if (publicKey.length != _kem.ref.length_public_key) {
      throw ArgumentError('Invalid public key length');
    }

    final pubKeyPtr = calloc<Uint8>(publicKey.length);
    pubKeyPtr.asTypedList(publicKey.length).setAll(0, publicKey);

    final ciphertextPtr = calloc<Uint8>(_kem.ref.length_ciphertext);
    final sharedSecretPtr = calloc<Uint8>(_kem.ref.length_shared_secret);

    final status =
        OQS_KEM_encaps(_kem, ciphertextPtr, sharedSecretPtr, pubKeyPtr);

    if (status != OQS_STATUS.OQS_SUCCESS) {
      calloc.free(pubKeyPtr);
      calloc.free(ciphertextPtr);
      calloc.free(sharedSecretPtr);
      throw Exception('Failed to encapsulate shared secret');
    }

    final cipherList = Uint8List.fromList(
        ciphertextPtr.asTypedList(_kem.ref.length_ciphertext));
    final secretList = Uint8List.fromList(
        sharedSecretPtr.asTypedList(_kem.ref.length_shared_secret));

    calloc.free(pubKeyPtr);
    calloc.free(ciphertextPtr);
    calloc.free(sharedSecretPtr);

    return [cipherList, secretList];
  }

  /// Decapsulates the ciphertext using the secret key.
  /// 
  /// Returns the `sharedSecret`.
  Uint8List decapsulate(Uint8List ciphertext, Uint8List secretKey) {
    if (ciphertext.length != _kem.ref.length_ciphertext) {
      throw ArgumentError('Invalid ciphertext length');
    }
    if (secretKey.length != _kem.ref.length_secret_key) {
      throw ArgumentError('Invalid secret key length');
    }

    final cipherPtr = calloc<Uint8>(ciphertext.length);
    cipherPtr.asTypedList(ciphertext.length).setAll(0, ciphertext);

    final secKeyPtr = calloc<Uint8>(secretKey.length);
    secKeyPtr.asTypedList(secretKey.length).setAll(0, secretKey);

    final sharedSecretPtr = calloc<Uint8>(_kem.ref.length_shared_secret);

    final status =
        OQS_KEM_decaps(_kem, sharedSecretPtr, cipherPtr, secKeyPtr);

    if (status != OQS_STATUS.OQS_SUCCESS) {
      calloc.free(cipherPtr);
      calloc.free(secKeyPtr);
      calloc.free(sharedSecretPtr);
      throw Exception('Failed to decapsulate ciphertext');
    }

    final secretList = Uint8List.fromList(
        sharedSecretPtr.asTypedList(_kem.ref.length_shared_secret));

    calloc.free(cipherPtr);
    calloc.free(secKeyPtr);
    calloc.free(sharedSecretPtr);

    return secretList;
  }
}

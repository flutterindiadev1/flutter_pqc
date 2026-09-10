import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'flutter_pqc_bindings_generated.dart';

/// Supported Post-Quantum Digital Signature algorithms.
class PqSigAlgorithm {
  static const String mlDsa44 = 'ML-DSA-44';
  static const String mlDsa65 = 'ML-DSA-65';
  static const String mlDsa87 = 'ML-DSA-87';
  static const String falcon512 = 'Falcon-512';
  static const String falcon1024 = 'Falcon-1024';
  static const String sphincsSha2_128fSimple = 'SPHINCS+-SHA2-128f-simple';
  static const String sphincsShake_128fSimple = 'SPHINCS+-SHAKE-128f-simple';

  // Private constructor to prevent instantiation
  PqSigAlgorithm._();
}

/// Wrapper class for Post-Quantum Digital Signatures (e.g., ML-DSA / Dilithium).
class PqCryptoSig {
  late final Pointer<OQS_SIG> _sig;

  /// Creates a new Digital Signature instance for the given algorithm name (e.g., 'ML-DSA-44').
  PqCryptoSig(String algName) {
    final algNameC = algName.toNativeUtf8().cast<Char>();
    _sig = OQS_SIG_new(algNameC);
    calloc.free(algNameC);

    if (_sig == nullptr) {
      throw Exception('Algorithm not supported or disabled: $algName');
    }
  }

  /// Disposes of the SIG instance and frees native memory.
  void dispose() {
    if (_sig != nullptr) {
      OQS_SIG_free(_sig);
    }
  }

  /// Generates a public and secret key pair.
  /// 
  /// Returns a tuple containing `[publicKey, secretKey]` as Uint8Lists.
  List<Uint8List> generateKeyPair() {
    final pubKey = calloc<Uint8>(_sig.ref.length_public_key);
    final secKey = calloc<Uint8>(_sig.ref.length_secret_key);

    final status = OQS_SIG_keypair(_sig, pubKey, secKey);
    if (status != OQS_STATUS.OQS_SUCCESS) {
      calloc.free(pubKey);
      calloc.free(secKey);
      throw Exception('Failed to generate keypair');
    }

    final pubList = Uint8List.fromList(
        pubKey.asTypedList(_sig.ref.length_public_key));
    final secList = Uint8List.fromList(
        secKey.asTypedList(_sig.ref.length_secret_key));

    calloc.free(pubKey);
    calloc.free(secKey);

    return [pubList, secList];
  }

  /// Signs a message using the secret key.
  /// 
  /// Returns the signature as a Uint8List.
  Uint8List sign(Uint8List message, Uint8List secretKey) {
    if (secretKey.length != _sig.ref.length_secret_key) {
      throw ArgumentError('Invalid secret key length');
    }

    final msgPtr = calloc<Uint8>(message.length);
    msgPtr.asTypedList(message.length).setAll(0, message);

    final secKeyPtr = calloc<Uint8>(secretKey.length);
    secKeyPtr.asTypedList(secretKey.length).setAll(0, secretKey);

    final signaturePtr = calloc<Uint8>(_sig.ref.length_signature);
    final signatureLenPtr = calloc<Size>();

    final status = OQS_SIG_sign(
      _sig,
      signaturePtr,
      signatureLenPtr,
      msgPtr,
      message.length,
      secKeyPtr,
    );

    if (status != OQS_STATUS.OQS_SUCCESS) {
      calloc.free(msgPtr);
      calloc.free(secKeyPtr);
      calloc.free(signaturePtr);
      calloc.free(signatureLenPtr);
      throw Exception('Failed to sign message');
    }

    final sigLength = signatureLenPtr.value;
    final signatureList = Uint8List.fromList(
        signaturePtr.asTypedList(sigLength));

    calloc.free(msgPtr);
    calloc.free(secKeyPtr);
    calloc.free(signaturePtr);
    calloc.free(signatureLenPtr);

    return signatureList;
  }

  /// Verifies a signature for a given message using the public key.
  /// 
  /// Returns `true` if the signature is valid, `false` otherwise.
  bool verify(Uint8List message, Uint8List signature, Uint8List publicKey) {
    if (publicKey.length != _sig.ref.length_public_key) {
      throw ArgumentError('Invalid public key length');
    }

    final msgPtr = calloc<Uint8>(message.length);
    msgPtr.asTypedList(message.length).setAll(0, message);

    final sigPtr = calloc<Uint8>(signature.length);
    sigPtr.asTypedList(signature.length).setAll(0, signature);

    final pubKeyPtr = calloc<Uint8>(publicKey.length);
    pubKeyPtr.asTypedList(publicKey.length).setAll(0, publicKey);

    final status = OQS_SIG_verify(
      _sig,
      msgPtr,
      message.length,
      sigPtr,
      signature.length,
      pubKeyPtr,
    );

    calloc.free(msgPtr);
    calloc.free(sigPtr);
    calloc.free(pubKeyPtr);

    return status == OQS_STATUS.OQS_SUCCESS;
  }
}

# Flutter Post-Quantum Cryptography (`flutter_pqc`)

A state-of-the-art, production-ready Flutter FFI plugin for Post-Quantum Cryptography (PQC).

This package provides a secure, zero-dependency, 100% cross-platform wrapper around the industry standard [liboqs](https://github.com/open-quantum-safe/liboqs) C-library. It natively supports **ML-KEM** (Kyber) and **ML-DSA** (Dilithium), which are the primary quantum-resistant cryptographic algorithms standardized by NIST.

## Why `flutter_pqc`? (Architecture & Performance)

Unlike pure-Dart cryptographic implementations, `flutter_pqc` is an **FFI Wrapper** around the industry-standard **`liboqs`** C-library (maintained by the [Open Quantum Safe](https://openquantumsafe.org/) project). 

This architectural decision provides several massive benefits for production-grade applications:

*   **⚡ Bare-Metal Performance & Hardware Acceleration**: Cryptography in pure Dart is often bottlenecked by the Dart Virtual Machine. Because `flutter_pqc` uses `liboqs` under the hood, all cryptographic operations execute at native C speeds. The C-library is highly optimized to utilize CPU-specific hardware instructions (such as AVX2/AVX512 on Intel and NEON on ARM/Apple Silicon), making it **significantly faster** for heavy lattice mathematics and hash functions.
*   **🛡️ Industry-Standard Trust & Security**: A lone developer's pure-Dart implementation rarely receives professional third-party security audits, and it is notoriously difficult to write pure-Dart code that is resistant to side-channel (timing) attacks. `liboqs` is the de-facto global standard. It receives massive funding, continuous cryptanalysis, side-channel attack mitigations, and rigorous audits by the world's leading security experts. It is the exact same engine powering post-quantum cryptography in OpenSSL, AWS, and Cloudflare.
*   **🚀 100% Cross-Platform (Mobile & Desktop)**: Uses a custom CMake build system integrated into Dart's `native_toolchain_c` to automatically compile `liboqs` natively for Android, iOS, macOS, Windows, and Linux.
*   **📦 Zero Bloat & Maximum Transparency**: No pre-compiled `.so` or `.framework` binaries are bundled in the repository. The library builds directly from the C source code on the target machine, ensuring transparency and maximum security.
*   **🔒 Quantum-Safe**: Protects your users against future threats from quantum computers (Harvest Now, Decrypt Later).
*   **🧩 Type-Safe APIs**: Strong typing and enums for all supported algorithms (`PqKemAlgorithm.mlKem512`, `PqSigAlgorithm.mlDsa44`, etc.) prevent typos and runtime errors.

## Supported Algorithms

### Key Encapsulation Mechanisms (KEMs)
*   **ML-KEM (FIPS 203)**: `ML-KEM-512`, `ML-KEM-768`, `ML-KEM-1024`
*   **Kyber**: `Kyber512`, `Kyber768`, `Kyber1024`
*   **FrodoKEM**: `FrodoKEM-640-AES`, `FrodoKEM-640-SHAKE`

### Digital Signatures
*   **ML-DSA (FIPS 204)**: `ML-DSA-44`, `ML-DSA-65`, `ML-DSA-87`
*   **Falcon**: `Falcon-512`, `Falcon-1024`
*   **SPHINCS+**: `SPHINCS+-SHA2-128f-simple`, `SPHINCS+-SHAKE-128f-simple`

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_pqc: ^0.0.1
```

> **Note**: Because this package builds the C library from source, the developer environment must have CMake installed and available in the system `PATH`.

## Usage

### 1. Key Encapsulation (ML-KEM)
Securely exchange a shared secret between Alice and Bob.

```dart
import 'package:flutter_pqc/flutter_pqc.dart';

void main() {
  // Initialize the ML-KEM-512 algorithm
  final kem = PqCryptoKem(PqKemAlgorithm.mlKem512);

  // 1. Alice generates a Keypair
  final keypair = kem.generateKeyPair();
  final alicePublicKey = keypair[0];
  final aliceSecretKey = keypair[1];

  // 2. Bob receives Alice's public key, and encapsulates a shared secret
  final encaps = kem.encapsulate(alicePublicKey);
  final ciphertext = encaps[0]; // Send this to Alice
  final bobSharedSecret = encaps[1]; // Bob keeps this

  // 3. Alice receives the ciphertext, and decapsulates to reveal the shared secret
  final aliceSharedSecret = kem.decapsulate(ciphertext, aliceSecretKey);

  // Both secrets are exactly the same!
  print(aliceSharedSecret == bobSharedSecret); // true

  // Free memory
  kem.dispose();
}
```

### 2. Digital Signatures (ML-DSA)
Securely sign and verify a digital message.

```dart
import 'package:flutter_pqc/flutter_pqc.dart';
import 'dart:convert';

void main() {
  // Initialize the ML-DSA-44 algorithm
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
  print(isValid); // true

  // Free memory
  sig.dispose();
}
```

## Contributing
Contributions are welcome! Please open an issue or submit a pull request on GitHub.

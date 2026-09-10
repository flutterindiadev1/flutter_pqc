import 'package:flutter/material.dart';
import 'package:flutter_pqc/flutter_pqc.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _kemStatus = 'Running KEM...';
  String _sigStatus = 'Running SIG...';

  @override
  void initState() {
    super.initState();
    _runCrypto();
  }

  void _runCrypto() {
    // --- ML-KEM ---
    try {
      final kem = PqCryptoKem(PqKemAlgorithm.mlKem512);
      final keypair = kem.generateKeyPair();
      final alicePublicKey = keypair[0];
      final aliceSecretKey = keypair[1];

      final encaps = kem.encapsulate(alicePublicKey);
      final ciphertext = encaps[0];
      final bobSharedSecret = encaps[1];

      final aliceSharedSecret = kem.decapsulate(ciphertext, aliceSecretKey);

      setState(() {
        _kemStatus = (aliceSharedSecret.toString() == bobSharedSecret.toString()) 
            ? 'Success! Secrets Match.' 
            : 'Failed! Secrets mismatch.';
      });
      kem.dispose();
    } catch (e) {
      setState(() {
        _kemStatus = 'Error: $e';
      });
    }

    // --- ML-DSA ---
    try {
      final sig = PqCryptoSig(PqSigAlgorithm.mlDsa44);
      final keypair = sig.generateKeyPair();
      final pubKey = keypair[0];
      final secKey = keypair[1];
      
      final msg = utf8.encode('Hello Post-Quantum World!');
      final signature = sig.sign(msg, secKey);
      final isValid = sig.verify(msg, signature, pubKey);
      
      setState(() {
        _sigStatus = isValid ? 'Success! Signature is VALID.' : 'Failed! Invalid signature.';
      });
      sig.dispose();
    } catch (e) {
      setState(() {
        _sigStatus = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter PQC Demo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('--- ML-KEM-512 (Key Encapsulation) ---', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('1. Alice generated Keypair (Pub/Sec)'),
                const Text('2. Bob generated Ciphertext & Shared Secret'),
                const Text('3. Alice decapsulated to exact same Shared Secret:'),
                Text(_kemStatus, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const Text('--- ML-DSA-44 (Digital Signatures) ---', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('1. Generated Signature Keypair'),
                const Text('2. Signed message: "Hello Post-Quantum World!"'),
                const Text('3. Signature Verification Result:'),
                Text(_sigStatus, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

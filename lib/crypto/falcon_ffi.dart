import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _secureStorage = FlutterSecureStorage();

class FalconCrypto {
  FalconCrypto._private();
  static final FalconCrypto instance = FalconCrypto._private();

  DynamicLibrary? _dylib;

  late final _generateKeypairNative;
  late final _signNative;
  late final _verifyNative;

  Future<void> init() async {
    if (_dylib != null) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _dylib = DynamicLibrary.open('libfalcon_bridge.so');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        _dylib = DynamicLibrary.process();
      } else {
        // Unsupported platform for native Falcon in this prototype.
        _dylib = null;
      }
    } catch (e) {
      _dylib = null;
    }

    if (_dylib != null) {
      _generateKeypairNative = _dylib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Pointer<Uint64>, Pointer<Uint8>, Pointer<Uint64>),
          int Function(Pointer<Uint8>, Pointer<Uint64>, Pointer<Uint8>, Pointer<Uint64>)>('generate_keypair');

      _signNative = _dylib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Uint64, Pointer<Uint8>, Uint64, Pointer<Uint8>, Pointer<Uint64>),
          int Function(Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Uint64>)>('sign_message');

      _verifyNative = _dylib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Uint64, Pointer<Uint8>, Uint64, Pointer<Uint8>, Uint64),
          int Function(Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>, int)>('verify_signature');
    }
  }

  Future<bool> hasNative() async {
    await init();
    return _dylib != null;
  }

  Future<void> ensureKeypair() async {
    // Check secure storage for existing keys
    String? pubB64 = await _secureStorage.read(key: 'falcon_pub');
    String? privB64 = await _secureStorage.read(key: 'falcon_priv');
    if (pubB64 != null && privB64 != null) return;

    // Generate keypair using native library
    await init();
    if (_dylib == null) throw Exception('Native Falcon library not available');

    // Probe sizes by passing small sizes first; native may return required sizes.
    int pubBufLen = 4096;
    int privBufLen = 8192;

    final pubBuf = calloc<Uint8>(pubBufLen);
    final privBuf = calloc<Uint8>(privBufLen);
    final pubLenPtr = calloc<Uint64>();
    final privLenPtr = calloc<Uint64>();
    pubLenPtr.value = pubBufLen;
    privLenPtr.value = privBufLen;

    final rc = _generateKeypairNative(pubBuf, pubLenPtr, privBuf, privLenPtr);
    if (rc == -2) {
      // native asked for larger buffers
      final requiredPub = pubLenPtr.value.toInt();
      final requiredPriv = privLenPtr.value.toInt();
      calloc.free(pubBuf);
      calloc.free(privBuf);
      calloc.free(pubLenPtr);
      calloc.free(privLenPtr);

      final pubBuf2 = calloc<Uint8>(requiredPub);
      final privBuf2 = calloc<Uint8>(requiredPriv);
      final pubLenPtr2 = calloc<Uint64>();
      final privLenPtr2 = calloc<Uint64>();
      pubLenPtr2.value = requiredPub;
      privLenPtr2.value = requiredPriv;
      final rc2 = _generateKeypairNative(pubBuf2, pubLenPtr2, privBuf2, privLenPtr2);
      if (rc2 != 0) {
        calloc.free(pubBuf2);
        calloc.free(privBuf2);
        calloc.free(pubLenPtr2);
        calloc.free(privLenPtr2);
        throw Exception('generate_keypair failed with code $rc2');
      }
      final pubBytes = pubBuf2.asTypedList(pubLenPtr2.value.toInt());
      final privBytes = privBuf2.asTypedList(privLenPtr2.value.toInt());
      await _secureStorage.write(key: 'falcon_pub', value: base64Encode(pubBytes));
      await _secureStorage.write(key: 'falcon_priv', value: base64Encode(privBytes));
      calloc.free(pubBuf2);
      calloc.free(privBuf2);
      calloc.free(pubLenPtr2);
      calloc.free(privLenPtr2);
      return;
    }

    if (rc != 0) {
      calloc.free(pubBuf);
      calloc.free(privBuf);
      calloc.free(pubLenPtr);
      calloc.free(privLenPtr);
      throw Exception('generate_keypair failed with code $rc');
    }

    final pubLen = pubLenPtr.value.toInt();
    final privLen = privLenPtr.value.toInt();
    final pubBytes = pubBuf.asTypedList(pubLen);
    final privBytes = privBuf.asTypedList(privLen);

    await _secureStorage.write(key: 'falcon_pub', value: base64Encode(pubBytes));
    await _secureStorage.write(key: 'falcon_priv', value: base64Encode(privBytes));

    calloc.free(pubBuf);
    calloc.free(privBuf);
    calloc.free(pubLenPtr);
    calloc.free(privLenPtr);
  }

  Future<Uint8List> signChallenge(Uint8List challenge) async {
    await ensureKeypair();
    final privB64 = await _secureStorage.read(key: 'falcon_priv');
    if (privB64 == null) throw Exception('Private key not found');
    final priv = base64Decode(privB64);

    await init();
    if (_dylib == null) throw Exception('Native Falcon library not available');

    final privPtr = calloc<Uint8>(priv.length);
    final msgPtr = calloc<Uint8>(challenge.length);

    final sigMaxLen = 2000; // conservative
    final sigBuf = calloc<Uint8>(sigMaxLen);
    final sigLenPtr = calloc<Uint64>();
    sigLenPtr.value = sigMaxLen;

    final privList = privPtr.asTypedList(priv.length);
    privList.setAll(0, priv);
    final msgList = msgPtr.asTypedList(challenge.length);
    msgList.setAll(0, challenge);

    final rc = _signNative(privPtr, priv.length, msgPtr, challenge.length, sigBuf, sigLenPtr);
    if (rc != 0) {
      calloc.free(privPtr);
      calloc.free(msgPtr);
      calloc.free(sigBuf);
      calloc.free(sigLenPtr);
      throw Exception('sign_message failed with code $rc');
    }

    final sig = sigBuf.asTypedList(sigLenPtr.value.toInt());
    final out = Uint8List.fromList(sig);

    calloc.free(privPtr);
    calloc.free(msgPtr);
    calloc.free(sigBuf);
    calloc.free(sigLenPtr);

    return out;
  }

  Future<Uint8List?> getPublicKey() async {
    final pubB64 = await _secureStorage.read(key: 'falcon_pub');
    if (pubB64 == null) return null;
    return base64Decode(pubB64);
  }
}

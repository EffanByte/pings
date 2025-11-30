#include <jni.h>
#include <string>
#include <vector>
#include <oqs/oqs.h>

// Helper to throw a Java exception from C++
void ThrowJNIException(JNIEnv *env, const char *message) {
    jclass exClass = env->FindClass("java/lang/RuntimeException");
    if (exClass != nullptr) {
        env->ThrowNew(exClass, message);
    }
}

// Define the signature algorithm to use
const char *sig_alg = "Falcon-512";

extern "C"
JNIEXPORT jobject JNICALL
Java_com_example_instructor_MainActivity_generateFalconKeyPairJNI(JNIEnv *env, jobject /* this */) {
    OQS_SIG *sig = OQS_SIG_new(sig_alg);
    if (sig == nullptr) {
        ThrowJNIException(env, "Failed to initialize Falcon-512 algorithm");
        return nullptr;
    }

    std::vector<uint8_t> public_key(sig->length_public_key);
    std::vector<uint8_t> secret_key(sig->length_secret_key);

    if (OQS_SIG_keypair(sig, public_key.data(), secret_key.data()) != OQS_SUCCESS) {
        OQS_SIG_free(sig);
        ThrowJNIException(env, "OQS_SIG_keypair failed");
        return nullptr;
    }

    // Create Java byte arrays and copy the key data
    jbyteArray publicKeyJ = env->NewByteArray(public_key.size());
    env->SetByteArrayRegion(publicKeyJ, 0, public_key.size(), (jbyte *) public_key.data());

    jbyteArray privateKeyJ = env->NewByteArray(secret_key.size());
    env->SetByteArrayRegion(privateKeyJ, 0, secret_key.size(), (jbyte *) secret_key.data());

    // Find the HashMap class and its constructor
    jclass mapClass = env->FindClass("java/util/HashMap");
    jmethodID mapConstructor = env->GetMethodID(mapClass, "<init>", "()V");
    jobject map = env->NewObject(mapClass, mapConstructor);

    // Find the 'put' method of HashMap
    jmethodID putMethod = env->GetMethodID(mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

    // Put the keys into the map
    env->CallObjectMethod(map, putMethod, env->NewStringUTF("publicKey"), publicKeyJ);
    env->CallObjectMethod(map, putMethod, env->NewStringUTF("privateKey"), privateKeyJ);

    OQS_SIG_free(sig);
    return map;
}

extern "C"
JNIEXPORT jbyteArray JNICALL
Java_com_example_instructor_MainActivity_signWithFalconJNI(JNIEnv *env, jobject /* this */, jbyteArray message, jbyteArray privateKey) {
    OQS_SIG *sig = OQS_SIG_new(sig_alg);
     if (sig == nullptr) {
        ThrowJNIException(env, "Failed to initialize Falcon-512 algorithm");
        return nullptr;
    }

    jbyte *message_ptr = env->GetByteArrayElements(message, nullptr);
    jsize message_len = env->GetArrayLength(message);

    jbyte *privateKey_ptr = env->GetByteArrayElements(privateKey, nullptr);
    jsize privateKey_len = env->GetArrayLength(privateKey);

    std::vector<uint8_t> signature(sig->length_signature);
    size_t signature_len;

    if (OQS_SIG_sign(sig, signature.data(), &signature_len, (uint8_t *) message_ptr, message_len, (uint8_t *) privateKey_ptr) != OQS_SUCCESS) {
        env->ReleaseByteArrayElements(message, message_ptr, JNI_ABORT);
        env->ReleaseByteArrayElements(privateKey, privateKey_ptr, JNI_ABORT);
        OQS_SIG_free(sig);
        ThrowJNIException(env, "OQS_SIG_sign failed");
        return nullptr;
    }

    // Create Java byte array for the signature
    jbyteArray signatureJ = env->NewByteArray(signature_len);
    env->SetByteArrayRegion(signatureJ, 0, signature_len, (jbyte *) signature.data());

    // Release resources
    env->ReleaseByteArrayElements(message, message_ptr, JNI_ABORT);
    env->ReleaseByteArrayElements(privateKey, privateKey_ptr, JNI_ABORT);
    OQS_SIG_free(sig);

    return signatureJ;
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_example_instructor_MainActivity_verifyFalconSignatureJNI(JNIEnv *env, jobject /* this */, jbyteArray message, jbyteArray signature, jbyteArray publicKey) {
    OQS_SIG *sig = OQS_SIG_new(sig_alg);
    if (sig == nullptr) {
        ThrowJNIException(env, "Failed to initialize Falcon-512 algorithm");
        return JNI_FALSE;
    }

    jbyte *message_ptr = env->GetByteArrayElements(message, nullptr);
    jsize message_len = env->GetArrayLength(message);

    jbyte *signature_ptr = env->GetByteArrayElements(signature, nullptr);
    jsize signature_len = env->GetArrayLength(signature);

    jbyte *publicKey_ptr = env->GetByteArrayElements(publicKey, nullptr);
    jsize publicKey_len = env->GetArrayLength(publicKey);

    // Verify the signature
    int result = OQS_SIG_verify(sig, (uint8_t *) message_ptr, message_len, (uint8_t *) signature_ptr, signature_len, (uint8_t *) publicKey_ptr);

    // Release resources
    env->ReleaseByteArrayElements(message, message_ptr, JNI_ABORT);
    env->ReleaseByteArrayElements(signature, signature_ptr, JNI_ABORT);
    env->ReleaseByteArrayElements(publicKey, publicKey_ptr, JNI_ABORT);
    OQS_SIG_free(sig);

    return (result == OQS_SUCCESS) ? JNI_TRUE : JNI_FALSE;
}
#include "falcon_bridge.h"
#include <string.h>

// Attempt to use liboqs if available
#ifdef HAVE_LIBOQS
#include <oqs/oqs.h>
#endif

// Note: This file is a small wrapper. For full functionality you must
// build liboqs (with Falcon-512) and link it into the Android/iOS binaries.

int generate_keypair(uint8_t* pub, size_t* pub_len, uint8_t* priv, size_t* priv_len) {
#ifdef HAVE_LIBOQS
    OQS_SIG *sig = OQS_SIG_new("Falcon-512");
    if (!sig) return -1;
    if (*pub_len < (size_t)OQS_SIG_public_key_length(sig) || *priv_len < (size_t)OQS_SIG_secret_key_length(sig)) {
        // caller buffer too small; return required lengths by setting them
        *pub_len = OQS_SIG_public_key_length(sig);
        *priv_len = OQS_SIG_secret_key_length(sig);
        OQS_SIG_free(sig);
        return -2;
    }
    if (OQS_SIG_keypair(sig, pub, priv) != OQS_SUCCESS) {
        OQS_SIG_free(sig);
        return -3;
    }
    *pub_len = OQS_SIG_public_key_length(sig);
    *priv_len = OQS_SIG_secret_key_length(sig);
    OQS_SIG_free(sig);
    return 0;
#else
    // liboqs not available — return error code
    (void)pub; (void)pub_len; (void)priv; (void)priv_len;
    return -100; // stub error
#endif
}

int sign_message(const uint8_t* priv, size_t priv_len, const uint8_t* msg, size_t msg_len, uint8_t* sig, size_t* sig_len) {
#ifdef HAVE_LIBOQS
    OQS_SIG *s = OQS_SIG_new("Falcon-512");
    if (!s) return -1;
    size_t required = OQS_SIG_max_signature_length(s);
    if (*sig_len < required) {
        *sig_len = required;
        OQS_SIG_free(s);
        return -2;
    }
    size_t out_len = 0;
    if (OQS_SIG_sign(s, sig, &out_len, msg, msg_len, priv) != OQS_SUCCESS) {
        OQS_SIG_free(s);
        return -3;
    }
    *sig_len = out_len;
    OQS_SIG_free(s);
    return 0;
#else
    (void)priv; (void)priv_len; (void)msg; (void)msg_len; (void)sig; (void)sig_len;
    return -100; // stub
#endif
}

int verify_signature(const uint8_t* pub, size_t pub_len, const uint8_t* msg, size_t msg_len, const uint8_t* sig, size_t sig_len) {
#ifdef HAVE_LIBOQS
    OQS_SIG *s = OQS_SIG_new("Falcon-512");
    if (!s) return -1;
    if (OQS_SIG_verify(s, msg, msg_len, sig, sig_len, pub) != OQS_SUCCESS) {
        OQS_SIG_free(s);
        return 0; // verification failed
    }
    OQS_SIG_free(s);
    return 1; // verification success
#else
    (void)pub; (void)pub_len; (void)msg; (void)msg_len; (void)sig; (void)sig_len;
    return -100; // stub
#endif
}

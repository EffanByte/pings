#ifndef FALCON_BRIDGE_H
#define FALCON_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Return 0 on success, negative on error.
int generate_keypair(uint8_t* pub, size_t* pub_len, uint8_t* priv, size_t* priv_len);
int sign_message(const uint8_t* priv, size_t priv_len, const uint8_t* msg, size_t msg_len, uint8_t* sig, size_t* sig_len);
int verify_signature(const uint8_t* pub, size_t pub_len, const uint8_t* msg, size_t msg_len, const uint8_t* sig, size_t sig_len);

#ifdef __cplusplus
}
#endif

#endif // FALCON_BRIDGE_H

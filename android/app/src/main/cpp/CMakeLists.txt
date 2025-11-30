cmake_minimum_required(VERSION 3.10)
project(student)

# 2) Configure liboqs itself
set(OQS_USE_OPENSSL OFF)
set(OQS_BUILD_ONLY_LIB ON)

# Disable problematic algorithm families that cause build issues on Android ARM64
set(OQS_ENABLE_KEM_BIKE OFF)
set(OQS_ENABLE_KEM_FRODOKEM OFF)
set(OQS_ENABLE_KEM_NTRUPRIME OFF)
set(OQS_ENABLE_KEM_CLASSIC_MCELIECE OFF)
set(OQS_ENABLE_KEM_HQC OFF)
set(OQS_ENABLE_SIG_DILITHIUM OFF)
set(OQS_ENABLE_SIG_ML_DSA OFF)
set(OQS_ENABLE_SIG_SPHINCS OFF)
set(OQS_ENABLE_SIG_MAYO OFF)
set(OQS_ENABLE_SIG_CROSS OFF)
set(OQS_ENABLE_SIG_UOV OFF)
set(OQS_ENABLE_SIG_SNOVA OFF)

# Disable Falcon variants you don't need (keep only falcon_512)
set(OQS_ENABLE_SIG_falcon_1024 OFF)
set(OQS_ENABLE_SIG_falcon_padded_512 OFF)
set(OQS_ENABLE_SIG_falcon_padded_1024 OFF)

add_subdirectory(liboqs EXCLUDE_FROM_ALL)

# 1) Point the compiler at the liboqs public headers
#    (where oqs/oqs.h lives) - use the build directory where headers are generated
include_directories(
  "${CMAKE_CURRENT_BINARY_DIR}/liboqs/include"
)

# 3) Our JNI wrapper
add_library(pqc_wrapper SHARED
  pqc_wrapper.cpp
)

# (If you need any internal headers from the liboqs src tree, you can also add:)
target_include_directories(pqc_wrapper PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/liboqs/src"
)

# 4) Android log lib
find_library(log-lib log)

# 5) Link against liboqs + log
target_link_libraries(
  pqc_wrapper
  oqs        # the target name created by liboqs's CMakeLists
  ${log-lib}
)

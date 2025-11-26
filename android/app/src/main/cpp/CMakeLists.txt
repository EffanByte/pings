cmake_minimum_required(VERSION 3.4.1)
project(falcon_bridge)

add_library(falcon_bridge SHARED
    falcon_bridge.c
)

# Try to find liboqs library (built and copied to jniLibs/<abi>/)
find_library(OQS_LIB oqs)

if (OQS_LIB)
    message(STATUS "Found liboqs: ${OQS_LIB}")
    target_link_libraries(falcon_bridge PRIVATE ${OQS_LIB})
    target_compile_definitions(falcon_bridge PRIVATE HAVE_LIBOQS=1)
else()
    message(WARNING "liboqs library not found. Building falcon_bridge as stub (will return errors at runtime).")
    message(STATUS "To enable Falcon-512, ensure liboqs.so is in jniLibs/<abi>/ and oqs.h is available.")
endif()

# Try to find oqs headers
find_path(OQS_INCLUDE_DIR oqs/oqs.h)
if (OQS_INCLUDE_DIR)
    message(STATUS "Found oqs headers at: ${OQS_INCLUDE_DIR}")
    target_include_directories(falcon_bridge PRIVATE ${OQS_INCLUDE_DIR})
else()
    message(WARNING "oqs/oqs.h not found. Build will still work but functions may fail at runtime if liboqs is not linked.")
endif()

# Include current source dir for header
target_include_directories(falcon_bridge PRIVATE ${CMAKE_SOURCE_DIR})

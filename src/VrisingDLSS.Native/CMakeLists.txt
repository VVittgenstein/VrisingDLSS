cmake_minimum_required(VERSION 3.22)

if (POLICY CMP0091)
    cmake_policy(SET CMP0091 NEW)
endif()

project(VrisingDLSS.Native LANGUAGES CXX)

option(
    VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER
    "Enable local research build that links NVIDIA NGX SDK wrapper. Off for release-safe builds."
    OFF)
set(VRISINGDLSS_NGX_SDK_ROOT "" CACHE PATH "Path to a local NVIDIA/DLSS SDK checkout. Used only when VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER is ON.")

add_library(VrisingDLSS.Native SHARED
    src/VrisingDlssNative.cpp
)

set_target_properties(VrisingDLSS.Native PROPERTIES
    PREFIX ""
    OUTPUT_NAME "VrisingDLSS.Native"
)

if (CMAKE_CONFIGURATION_TYPES)
    foreach (CONFIG Debug Release RelWithDebInfo MinSizeRel)
        string(TOUPPER "${CONFIG}" CONFIG_UPPER)
        set_target_properties(VrisingDLSS.Native PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/${CONFIG}"
            LIBRARY_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/${CONFIG}"
            ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_UPPER} "${CMAKE_BINARY_DIR}/${CONFIG}"
        )
    endforeach()
else()
    if (NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Release)
    endif()

    set_target_properties(VrisingDLSS.Native PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}"
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}"
    )
endif()

target_compile_features(VrisingDLSS.Native PRIVATE cxx_std_20)
target_compile_definitions(VrisingDLSS.Native PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_include_directories(VrisingDLSS.Native PRIVATE include)
target_link_libraries(VrisingDLSS.Native PRIVATE d3d11)

if (MSVC)
    target_compile_options(VrisingDLSS.Native PRIVATE /W4 /permissive-)
endif()

if (VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
    if (NOT MSVC)
        message(FATAL_ERROR "VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER currently requires MSVC because the NVIDIA wrapper library is a Windows .lib.")
    endif()

    if (NOT VRISINGDLSS_NGX_SDK_ROOT)
        message(FATAL_ERROR "Set VRISINGDLSS_NGX_SDK_ROOT to a local NVIDIA/DLSS SDK checkout when enabling the NGX SDK wrapper.")
    endif()

    set(NGX_SDK_INCLUDE_DIR "${VRISINGDLSS_NGX_SDK_ROOT}/include")
    set(NGX_SDK_WRAPPER_LIB "${VRISINGDLSS_NGX_SDK_ROOT}/lib/Windows_x86_64/x64/nvsdk_ngx_s.lib")

    if (NOT EXISTS "${NGX_SDK_INCLUDE_DIR}/nvsdk_ngx.h")
        message(FATAL_ERROR "NVIDIA NGX SDK header not found: ${NGX_SDK_INCLUDE_DIR}/nvsdk_ngx.h")
    endif()

    if (NOT EXISTS "${NGX_SDK_WRAPPER_LIB}")
        message(FATAL_ERROR "NVIDIA NGX SDK wrapper lib not found: ${NGX_SDK_WRAPPER_LIB}")
    endif()

    target_compile_definitions(VrisingDLSS.Native PRIVATE VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=1)
    target_include_directories(VrisingDLSS.Native PRIVATE "${NGX_SDK_INCLUDE_DIR}")
    target_link_libraries(VrisingDLSS.Native PRIVATE "${NGX_SDK_WRAPPER_LIB}")
    set_property(TARGET VrisingDLSS.Native PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

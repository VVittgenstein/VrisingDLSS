cmake_minimum_required(VERSION 3.22)

project(VrisingDLSS.Native LANGUAGES CXX)

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

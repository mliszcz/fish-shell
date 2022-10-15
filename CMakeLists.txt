cmake_minimum_required(VERSION 3.5)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

project(fish LANGUAGES C)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(DEFAULT_BUILD_TYPE "Debug")

# Generate Xcode schemas (but not for tests).
set(CMAKE_XCODE_GENERATE_SCHEME 1)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    message(STATUS "Setting build type to default '${DEFAULT_BUILD_TYPE}'")
    set(CMAKE_BUILD_TYPE "${DEFAULT_BUILD_TYPE}")
endif()

# Set up standard directories.
include(GNUInstallDirs)
add_definitions(-D_UNICODE=1)

include(cmake/gettext.cmake)

# Set up PCRE2
# This sets an environment variable that needs to be available before the Rust stanzas
include(cmake/PCRE2.cmake)

include(cmake/Rust.cmake)

# Error out when linking statically, it doesn't work.
# This can be conditionally enabled only for the purpose of creating an AppImage.
option(FISH_ALLOW_UNSUPPORTED_STATIC_LINKING "Allow static linking" OFF)
mark_as_advanced(FORCE FISH_ALLOW_UNSUPPORTED_STATIC_LINKING)
if (NOT FISH_ALLOW_UNSUPPORTED_STATIC_LINKING AND CMAKE_EXE_LINKER_FLAGS MATCHES ".*-static.*")
    message(FATAL_ERROR "Fish does not support static linking")
endif()

# Force colored warnings in Ninja's output, if the compiler has -fdiagnostics-color support.
# Rationale in https://github.com/ninja-build/ninja/issues/814
if (CMAKE_GENERATOR STREQUAL "Ninja" AND
    ((CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND NOT CMAKE_CXX_COMPILER_VERSION VERSION_LESS 4.9) OR
     (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND NOT CMAKE_CXX_COMPILER_VERSION VERSION_LESS 3.5) OR
     (CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang" AND NOT CMAKE_CXX_COMPILER_VERSION VERSION_LESS 6.0)))
      add_compile_options(-fdiagnostics-color=always)
endif()

# Enable a whole bunch of warnings, but turn off:
# - comment because we use a bunch of those, and they're not really all that harmful.
# - address, because that occurs for our mkostemp check (weak-linking requires us to compare `&mkostemp == nullptr`).
add_compile_options(-Wall -Wextra -Wno-comment -Wno-address)

# Get extra C++ files from Rust.
get_property(FISH_EXTRA_SOURCES TARGET fish-rust PROPERTY fish_extra_cpp_files)

if ((CMAKE_CXX_COMPILER_ID STREQUAL "Clang") OR (CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"))
  add_compile_options(-Wunused-template -Wunused-local-typedef -Wunused-macros)
endif()

# Disable exception handling.
add_compile_options(-fno-exceptions)

# Undefine NDEBUG to keep assert() in release builds.
add_definitions(-UNDEBUG)

# Allow including Rust headers in normal (not bindgen) builds.
add_definitions(-DINCLUDE_RUST_HEADERS)

# Enable large files on GNU.
add_definitions(-D_LARGEFILE_SOURCE
                -D_LARGEFILE64_SOURCE
                -D_FILE_OFFSET_BITS=64
                -D_ATFILE_SOURCE)

# Hide the CMake Rules directories in Xcode projects.
source_group("CMake Rules" REGULAR_EXPRESSION "^$")

# Put source and header files at top level under targets.
source_group("Source Files" REGULAR_EXPRESSION ".*\\.cpp")
source_group("Header Files" REGULAR_EXPRESSION ".*\\.h")
source_group("Builtins" "builtins/")

# Support folders.
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Work around issue where archive-built libs go in the wrong place.
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR})

if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_CURRENT_BINARY_DIR)
  set(FISH_IN_TREE_BUILD TRUE)
else()
  set(FISH_IN_TREE_BUILD FALSE)
endif()

# Set up the machinery around FISH-BUILD-VERSION-FILE
# This defines the FBVF variable.
include(Version)

# Let fish pick up when we're running out of the build directory without installing
get_filename_component(REAL_CMAKE_BINARY_DIR "${CMAKE_BINARY_DIR}" REALPATH)
get_filename_component(REAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" REALPATH)
add_definitions(-DCMAKE_BINARY_DIR="${REAL_CMAKE_BINARY_DIR}")
add_definitions(-DCMAKE_SOURCE_DIR="${REAL_CMAKE_SOURCE_DIR}")

# Define a function to build and link dependencies.
function(CREATE_TARGET target)
  add_custom_target(
    ${target} ALL
    COMMAND
      "${CMAKE_COMMAND}" -E
        env ${VARS_FOR_CARGO}
          ${Rust_CARGO}
            build --bin ${target}
            $<$<CONFIG:Release>:--release>
            $<$<CONFIG:RelWithDebInfo>:--release>
            --target ${Rust_CARGO_TARGET}
            ${CARGO_FLAGS}
            ${FEATURES_ARG}
      &&
      "${CMAKE_COMMAND}" -E
        copy "${rust_target_dir}/${rust_profile}/${target}" "${CMAKE_CURRENT_BINARY_DIR}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    USES_TERMINAL
  )
endfunction(CREATE_TARGET)

# Define fish.
create_target(fish)

# Define fish_indent.
create_target(fish_indent)

# Define fish_key_reader.
create_target(fish_key_reader)

# Set up the docs.
include(cmake/Docs.cmake)

# A helper for running tests.
add_executable(fish_test_helper src/fish_test_helper.c)
# Set up tests.
include(cmake/Tests.cmake)

# Benchmarking support.
include(cmake/Benchmark.cmake)

# Set up install.
include(cmake/Install.cmake)

# Mac app.
include(cmake/MacApp.cmake)

include(FeatureSummary)
feature_summary(WHAT ALL)

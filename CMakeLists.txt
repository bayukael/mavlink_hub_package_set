cmake_minimum_required(VERSION 3.13)
project(mavlink_hub_package_set VERSION 0.1.0)

# mavlink_hub_package_set
#
# A multi-bundle CMake superbuild home for the mavlink_hub ecosystem. Each
# "bundle" collects a set of upstream repositories and builds them together,
# in dependency order, into a single install prefix. Pick which bundle to build
# with the -DBUNDLE=<name> cache variable (see README.md for the available
# bundles).

# ---------------------------------------------------------------------------
# Bundle selection
# ---------------------------------------------------------------------------
set(BUNDLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bundles")

file(GLOB _bundle_files RELATIVE "${BUNDLE_DIR}" "${BUNDLE_DIR}/*.cmake")
set(AVAILABLE_BUNDLES)
foreach(_bf IN LISTS _bundle_files)
    if(_bf MATCHES "^([A-Za-z0-9_-]+)\.cmake$")
        list(APPEND AVAILABLE_BUNDLES "${CMAKE_MATCH_1}")
    endif()
endforeach()
list(SORT AVAILABLE_BUNDLES)

set(BUNDLE "" CACHE STRING "Which bundle to build (e.g. deps). See bundles/ and README.md.")

if(NOT BUNDLE)
    message(FATAL_ERROR
        "No bundle selected. Configure with: -DBUNDLE=<name>\n"
        "Available bundles: ${AVAILABLE_BUNDLES}")
endif()

if(NOT EXISTS "${BUNDLE_DIR}/${BUNDLE}.cmake")
    message(FATAL_ERROR
        "Unknown bundle '${BUNDLE}'. Expected a file ${BUNDLE_DIR}/${BUNDLE}.cmake.\n"
        "Available bundles: ${AVAILABLE_BUNDLES}")
endif()

message(STATUS "Configuring bundle: ${BUNDLE}")
include("${BUNDLE_DIR}/${BUNDLE}.cmake")

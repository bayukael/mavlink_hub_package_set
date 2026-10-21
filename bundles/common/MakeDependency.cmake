# MakeDependency.cmake
#
# Helpers shared by the bundles in mavlink_hub_package_set. Bundles include them
# to turn an upstream repository into an ExternalProject that is configured,
# built, and installed into the package-set's single install prefix.
#
# The helper builds every dependency with its own CMake configure (a true
# superbuild), in dependency order, into ONE install prefix so that a final
# consumer can point CMAKE_PREFIX_PATH at the prefix and find every package the
# bundle provides.

include(ExternalProject)

# ---------------------------------------------------------------------------
# add_mhp_dependency(<name>
#   GIT_REPOSITORY <url>
#   [GIT_TAG <ref>]
#   [DEPENDS <dep>...]
#   [INIT_SUBMODULES <https-url-mapping...>]  # in the form "rel/path:https://.."
#   [CMAKE_ARGS <arg>...]
#   [EXTRA_ARGS <arg>...])                    # appended after the standard args
# ---------------------------------------------------------------------------
function(add_mhp_dependency name)
    cmake_parse_arguments(MHP
        ""
        "GIT_REPOSITORY;GIT_TAG"
        "DEPENDS;INIT_SUBMODULES;CMAKE_ARGS;EXTRA_ARGS"
        ${ARGN}
    )

    if(NOT MHP_GIT_REPOSITORY)
        message(FATAL_ERROR "add_mhp_dependency(${name}): GIT_REPOSITORY is required")
    endif()
    if(NOT MHP_GIT_TAG)
        set(MHP_GIT_TAG "main")
    endif()

    set(_dep_args)
    if(MHP_DEPENDS)
        set(_dep_args DEPENDS ${MHP_DEPENDS})
    endif()

    # Optional submodule initialization. Because some upstreams declare their
    # submodules over SSH (e.g. git@github.com:...), we allow the bundle to map
    # a submodule path to an HTTPS URL that can be fetched anonymously, then
    # rewrite and initialize it after checkout.
    set(_patch)
    if(MHP_INIT_SUBMODULES)
        set(_submodule_script
            "${CMAKE_CURRENT_LIST_DIR}/init_submodules.cmake")
        set(_patch
            PATCH_COMMAND "${CMAKE_COMMAND}"
                "-DSOURCE_DIR=<SOURCE_DIR>"
                "-DSUBMODULES=${MHP_INIT_SUBMODULES}"
                -P "${_submodule_script}")
    endif()

    ExternalProject_Add(${name}
        GIT_REPOSITORY ${MHP_GIT_REPOSITORY}
        GIT_TAG ${MHP_GIT_TAG}
        ${_patch}
        PREFIX "${CMAKE_CURRENT_BINARY_DIR}/_deps/${name}"
        INSTALL_DIR "${CMAKE_INSTALL_PREFIX}"
        CMAKE_ARGS
            "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
            "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
            "-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH};${CMAKE_INSTALL_PREFIX}"
            ${MHP_CMAKE_ARGS}
            ${MHP_EXTRA_ARGS}
        ${_dep_args}
    )
endfunction()

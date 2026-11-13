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

# Directory of THIS helper file (bundles/common). Captured at include time,
# because CMAKE_CURRENT_LIST_DIR inside a function refers to the caller's dir.
set(_MHP_COMMON_DIR "${CMAKE_CURRENT_LIST_DIR}")

# ---------------------------------------------------------------------------
# add_mhp_dependency(<name>
#   GIT_REPOSITORY <url>
#   [GIT_TAG <ref>]
#   [DEPENDS <dep>...]
#   [INIT_SUBMODULES <https-url-mapping...>]  # in the form "rel/path:https://.."
#   [CMAKE_ARGS <arg>...]
#   [EXTRA_ARGS <arg>...])                    # appended after the standard args
#   [SKIP_INSTALL]                            # don't run the dependency's install step
#   [INSTALL_COPY <rel-file>...]              # copy built artifacts from <BINARY_DIR> into <prefix>/lib
#
# By default the ExternalProject runs its normal CMake install step (each
# dependency is expected to install its own headers/libs/configs into the shared
# install prefix). Pass SKIP_INSTALL to skip the install step entirely (for
# upstreams whose build tree already carries the artifact, e.g. a runnable
# executable that is run straight from its build directory).
#
# Pass INSTALL_COPY for upstreams that produce artifacts but define no install
# rules (e.g. runtime plugin .so files). Each <rel-file> names a file relative to
# the dependency's build directory (<BINARY_DIR>); on install it is copied into
# the shared install prefix's lib/ directory, so a runtime loader (e.g. mavlink_hub
# dlopen'ing agent/transport plugins) can find it at <prefix>/lib/<rel-file>.
# INSTALL_COPY and SKIP_INSTALL are mutually exclusive.
function(add_mhp_dependency name)
    cmake_parse_arguments(MHP
        "SKIP_INSTALL"
        "GIT_REPOSITORY;GIT_TAG"
        "DEPENDS;INIT_SUBMODULES;CMAKE_ARGS;EXTRA_ARGS;INSTALL_COPY"
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

    # Optional install-command override. By default the ExternalProject runs the
    # dependency's own CMake install step. SKIP_INSTALL disables it; INSTALL_COPY
    # replaces it with a copy of the built artifacts into <prefix>/lib. We use a
    # harmless no-op command for SKIP_INSTALL (rather than an empty
    # INSTALL_COMMAND) because an empty string expanded through a variable is
    # dropped by CMake's argument handling, which would silently fall back to the
    # default install step.
    set(_install_args)
    if(MHP_SKIP_INSTALL)
        set(_install_args
            INSTALL_COMMAND "${CMAKE_COMMAND}" -E echo "install step skipped")
    elseif(MHP_INSTALL_COPY)
        set(_copy_args)
        foreach(_f IN LISTS MHP_INSTALL_COPY)
            list(APPEND _copy_args
                COMMAND "${CMAKE_COMMAND}" -E copy
                    "<BINARY_DIR>/${_f}"
                    "${CMAKE_INSTALL_PREFIX}/lib/${_f}")
        endforeach()
        set(_install_args INSTALL_COMMAND ${_copy_args})
    endif()

    # Optional submodule initialization. Because some upstreams declare their
    # submodules over SSH (e.g. git@github.com:...), we allow the bundle to map
    # a submodule path to an HTTPS URL that can be fetched anonymously, then
    # rewrite and initialize it after checkout.
    set(_patch)
    if(MHP_INIT_SUBMODULES)
        set(_submodule_script
            "${_MHP_COMMON_DIR}/init_submodules.cmake")
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
        ${_install_args}
        CMAKE_ARGS
            "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
            "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
            "-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH};${CMAKE_INSTALL_PREFIX}"
            ${MHP_CMAKE_ARGS}
            ${MHP_EXTRA_ARGS}
        ${_dep_args}
    )
endfunction()

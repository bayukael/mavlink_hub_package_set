# init_submodules.cmake
#
# Best-effort initialization of the git submodules of a freshly downloaded
# dependency, invoked as the ExternalProject PATCH step.
#
# Usage:
#   cmake -DSOURCE_DIR=<git-checkout-dir>
#         -DSUBMODULES="rel/path1:https://override1;rel/path2:https://override2"
#         -P init_submodules.cmake
#
# Each entry in SUBMODULES is "path:url". If the url part is empty the
# submodule's declared URL is used as-is. This lets a superbuild fetch
# submodules that upstream declared over SSH by overriding them to public
# HTTPS URLs, so the whole bundle can be built anonymously.
#
# SUCCESS_OVERRIDE / FAILURE_OVERRIDE are standard CMake script variables; the
# external project build keeps going (and may still succeed) if a submodule
# cannot be fetched, because submodules are often only needed by optional test
# targets.

if(NOT SOURCE_DIR)
    message(FATAL_ERROR "init_submodules.cmake: SOURCE_DIR is required")
endif()

set(cmd git -C "${SOURCE_DIR}")

execute_process(
    COMMAND ${cmd} submodule status
    RESULT_VARIABLE _status_rc
    OUTPUT_QUIET
)
if(_status_rc EQUAL 0)
    message(STATUS "[init_submodules] initializing submodules under ${SOURCE_DIR}")
else()
    message(STATUS "[init_submodules] '${SOURCE_DIR}' is not a git checkout; skipping")
    return()
endif()

foreach(_entry IN LISTS SUBMODULES)
    string(REGEX MATCH "^([^:]*):(.*)$" _m "${_entry}")
    set(_path "${CMAKE_MATCH_1}")
    set(_url "${CMAKE_MATCH_2}")

    if(_url)
        execute_process(
            COMMAND git -C "${SOURCE_DIR}" submodule set-url "${_path}" "${_url}"
            RESULT_VARIABLE _seturl_rc
            OUTPUT_QUIET
        )
        if(NOT _seturl_rc EQUAL 0)
            message(WARNING "[init_submodules] could not set URL for submodule '${_path}'")
        endif()
    endif()

    execute_process(
        COMMAND git -C "${SOURCE_DIR}" submodule update --init --recursive -- "${_path}"
        RESULT_VARIABLE _init_rc
        OUTPUT_VARIABLE _init_out
        ERROR_VARIABLE _init_err
    )
    if(_init_rc EQUAL 0)
        message(STATUS "[init_submodules] submodule '${_path}' initialized")
    else()
        message(WARNING
            "[init_submodules] could not initialize submodule '${_path}'\n"
            "${_init_err}")
    endif()
endforeach()

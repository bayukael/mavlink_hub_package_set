# minimal.cmake — the minimal mavlink_hub bundle
#
# Aggregates the mavlink_hub dependencies plus the mavlink_hub app itself:
#     byte_transport -> mavlink_endpoint -> mavlink_hub_sdk -> mavlink_hub
# and builds them together, in dependency order, into the bundle's single
# install prefix. The result is a runnable, minimal mavlink_hub built entirely
# from mavlink_hub_package_set.
#
# This bundle is deliberately minimal: it contains no plugins (heartbeat
# generator / UDP transport) and no Gazebo / serial pieces (gz_agent,
# serial_byte_transport, serial_device). Those land in the PX4 HITL plugin
# bundle.

include("${CMAKE_CURRENT_LIST_DIR}/common/MakeDependency.cmake")

# byte_transport — the base transport abstraction. No upstream dependencies.
add_mhp_dependency(byte_transport
    GIT_REPOSITORY https://github.com/bayukael/byte_transport.git
    GIT_TAG main
)

# mavlink_endpoint — MAVLink message send/receive over byte_transport.
# Depends on byte_transport's installed package (PendarlabByteTransport).
# Its external/mavlink submodule is declared over SSH upstream, so we override
# it to the public HTTPS URL so the bundle can be fetched and built anonymously.
add_mhp_dependency(mavlink_endpoint
    GIT_REPOSITORY https://github.com/bayukael/mavlink_endpoint.git
    GIT_TAG main
    DEPENDS byte_transport
    INIT_SUBMODULES "external/mavlink:https://github.com/mavlink/c_library_v2.git"
)

# mavlink_hub_sdk — the mavlink_hub Agent interface, built on mavlink_endpoint.
add_mhp_dependency(mavlink_hub_sdk
    GIT_REPOSITORY https://github.com/bayukael/mavlink_hub_sdk.git
    GIT_TAG main
    DEPENDS mavlink_endpoint
)

# mavlink_hub — the runnable mavlink_hub CLI application. It discovers the three
# dependencies above through the shared install prefix (CMAKE_PREFIX_PATH), and
# builds the mavlink_hub executable via its activated main target. Its CLI11,
# FTXUI and jsoncons dependencies are vendored inside the repository, so no
# separate submodule handling is needed. The repository's CMakeLists.txt defines
# no install rules, so we disable the ExternalProject install step; the runnable
# executable is produced in the bundle's build tree and run from there.
add_mhp_dependency(mavlink_hub
    GIT_REPOSITORY https://github.com/bayukael/mavlink_hub.git
    GIT_TAG main
    DEPENDS mavlink_hub_sdk
    SKIP_INSTALL
)

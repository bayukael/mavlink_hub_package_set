# deps.cmake — the mavlink_hub dependencies bundle
#
# Aggregates the mavlink_hub dependency libraries:
#     byte_transport -> mavlink_endpoint -> mavlink_hub_sdk
# and builds them together, in dependency order, into the bundle's single
# install prefix. This bundle is dependency-only: it deliberately contains no
# plugins (heartbeat generator / UDP transport) and no Gazebo / serial pieces
# (gz_agent, serial_byte_transport, serial_device) and does not produce a
# runnable app.

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

# px4_hitl.cmake — the PX4 HITL plugin bundle
#
# Aggregates the full MAVLink/Gazebo bridge needed to run PX4 in Hardware-In-The-
# Loop (HITL) with Gazebo: the mavlink_hub app, its dependencies, and every
# plugin that the bridge needs (heartbeat generator, UDP transport, gz_agent,
# serial transport/device). Everything is built together, in dependency order,
# into the bundle's single install prefix:
#
#     byte_transport
#        ├──> mavlink_endpoint ──> mavlink_hub_sdk ──> mavlink_hub
#        ├──> udp_byte_transport
#        ├──> mavlink_hub_heartbeat_generator (plugin)
#        └──> mavlink_hub_gz_agent           (plugin)
#     serial_device ──> serial_byte_transport
#
# This bundle is distinct from the minimal mavlink_hub bundle (bundles/minimal.cmake):
# it is the complete assembled bridge, including the plugins (heartbeat generator,
# UDP transport) and the Gazebo/serial pieces (gz_agent, serial_byte_transport,
# serial_device) that the minimal bundle deliberately omits.
#
# Built artifacts that are only runtime-loadable plugins (the agent .so files and
# the transport libs) are installed into <prefix>/lib so that mavlink_hub can
# dlopen them; the shipped app config in resources/px4_hitl/ references them
# there. The gz_agent additionally requires the Gazebo system packages
# (gz-cmake3, gz-msgs10, gz-transport13, sdformat14), which are found via
# find_package at configure time.

include("${CMAKE_CURRENT_LIST_DIR}/common/MakeDependency.cmake")

# byte_transport — the base transport abstraction. No upstream dependencies.
add_mhp_dependency(byte_transport
    GIT_REPOSITORY https://github.com/bayukael/byte_transport.git
    GIT_TAG main
)

# serial_device — the serial device library (backend for the serial transport).
# No upstream dependencies.
add_mhp_dependency(serial_device
    GIT_REPOSITORY https://github.com/bayukael/serial_device.git
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

# udp_byte_transport — byte_transport over UDP (the PX4 HITL autopilot link).
# Depends on byte_transport's installed package.
add_mhp_dependency(udp_byte_transport
    GIT_REPOSITORY https://github.com/bayukael/udp_byte_transport.git
    GIT_TAG main
    DEPENDS byte_transport
)

# serial_byte_transport — byte_transport over serial (the PX4 HITL serial/USB link).
# Depends on byte_transport and serial_device's installed packages.
add_mhp_dependency(serial_byte_transport
    GIT_REPOSITORY https://github.com/bayukael/serial_byte_transport.git
    GIT_TAG main
    DEPENDS byte_transport serial_device
)

# mavlink_hub — the runnable mavlink_hub CLI application. It discovers the
# dependency libraries above through the shared install prefix
# (CMAKE_PREFIX_PATH), and builds the mavlink_hub executable via its activated
# main target. Its CLI11, FTXUI and jsoncons dependencies are vendored inside
# the repository, so no separate submodule handling is needed. The repository's
# CMakeLists.txt defines no install rules, so we disable the ExternalProject
# install step; the runnable executable is produced in the bundle's build tree
# and run from there.
add_mhp_dependency(mavlink_hub
    GIT_REPOSITORY https://github.com/bayukael/mavlink_hub.git
    GIT_TAG main
    DEPENDS mavlink_hub_sdk
    SKIP_INSTALL
)

# mavlink_hub_heartbeat_generator — an mavlink_hub Agent plugin that periodically
# emits MAVLink HEARTBEAT messages to the connected MAVLink endpoints (needed for
# PX4 to recognize a transport as carrying a MAVLink device). It builds against
# the installed SDK and has no install rules, so INSTALL_COPY places the plugin
# .so into <prefix>/lib where mavlink_hub's app config can dlopen it.
add_mhp_dependency(mavlink_hub_heartbeat_generator
    GIT_REPOSITORY https://github.com/bayukael/mavlink_hub_heartbeat_generator.git
    GIT_TAG main
    DEPENDS mavlink_hub_sdk
    INSTALL_COPY libmavlink_hub_heartbeat_generator.so
)

# mavlink_hub_gz_agent — an mavlink_hub Agent plugin that bridges the autopilot's
# MAVLink messages to Gazebo Simulator (HIL_SENSOR/HIL_GPS out, HIL_ACTUATOR_CONTROLS
# in). It builds against the installed SDK plus the Gazebo system packages
# (find_package gz-cmake3/gz-msgs10/gz-transport13/sdformat14). It has no install
# rules, so INSTALL_COPY places the plugin .so into <prefix>/lib.
add_mhp_dependency(mavlink_hub_gz_agent
    GIT_REPOSITORY https://github.com/bayukael/mavlink_hub_gz_agent.git
    GIT_TAG main
    DEPENDS mavlink_hub_sdk
    INSTALL_COPY libmavlink_hub_gz_agent.so
)

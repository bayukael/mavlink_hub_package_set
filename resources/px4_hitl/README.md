# PX4 HITL plugin bundle

The `px4_hitl` bundle (`-DBUNDLE=px4_hitl`) is the **complete** MAVLink/Gazebo
bridge, ready to run PX4 in Hardware-In-The-Loop (HITL) with Gazebo Simulator. It
builds the minimal `mavlink_hub` stack **plus** every plugin the bridge needs,
all together into one install prefix:

| Piece | Repo | Kind |
| ----- | ---- | ---- |
| `byte_transport` | base transport abstraction | dependency |
| `serial_device` | serial device library (POSIX termios) | dependency |
| `mavlink_endpoint` | MAVLink send/receive over `byte_transport` | dependency |
| `mavlink_hub_sdk` | the `Agent` interface `mavlink_hub` programs against | dependency |
| `udp_byte_transport` | `byte_transport` over UDP (PX4 HITL autopilot link) | transport plugin |
| `serial_byte_transport` | `byte_transport` over serial/USB (PX4 HITL link) | transport plugin |
| `mavlink_hub_heartbeat_generator` | periodically emits MAVLink `HEARTBEAT` | agent plugin |
| `mavlink_hub_gz_agent` | bridges the autopilot's MAVLink to Gazebo | agent plugin |
| `mavlink_hub` | the runnable hub application | app |

It is distinct from the minimal `mavlink_hub` bundle (`bundles/minimal.cmake`),
which deliberately omits all the plugins and Gazebo/serial pieces.

## Requirements

- CMake >= 3.13, a C++17 compiler, and a build tool (Ninja or Make).
- Git (to fetch the upstream repositories).
- GoogleTest (`find_package(GTest CONFIG REQUIRED)`), e.g. the `libgtest-dev`
  package.
- The **Gazebo Garden** packages for `mavlink_hub_gz_agent` (found via
  `find_package` at configure time): `gz-cmake3`, `gz-msgs10`, `gz-transport13`,
  `sdformat14`.
- Network access to GitHub (repos are cloned at configure time).

## Building the bundle

Pick an install prefix and configure, build, and install:

```sh
cmake -S . -B build-px4-hitl \
  -DBUNDLE=px4_hitl \
  -DCMAKE_INSTALL_PREFIX=<prefix>
cmake --build build-px4-hitl -j8
cmake --install build-px4-hitl
```

The bundle builds in dependency order and installs everything into `<prefix>`.
The transport libraries (`libpendarlab-serial_byte_transport.so`,
`libpendarlab-udp_byte_transport.so`) and the agent plugins
(`libmavlink_hub_heartbeat_generator.so`, `libmavlink_hub_gz_agent.so`) all land
in `<prefix>/lib/`. The `mavlink_hub` executable is **not** installed (its repo
defines no install rules); it is produced in the bundle's build tree and run from
there:

```sh
build-px4-hitl/_deps/mavlink_hub/src/mavlink_hub-build/mavlink_hub --help
```

## Running the assembled bridge

1. **Copy the example files** where you can reference them, substituting your
   actual `<prefix>`:

   ```sh
   sed "s|<PREFIX>|$HOME/mavlink_hub_package/install|g" \
       <prefix>/share/mavlink_hub_package_set/px4_hitl/app_config.json \
       > app_config.json
   ```

   The `app_config.json` already loads all four bundled plugins (the two agent
   plugins and the two transport plugins) and points
   `path_to_startup_user_plan` at `user_plan_udp.json`, applying it on startup.
   To run the serial/USB path instead, point `path_to_startup_user_plan` at
   `user_plan_serial.json`.

2. **Run** `mavlink_hub` with that config, pointing `LD_LIBRARY_PATH` at
   `<prefix>/lib` so the dlopen'ed plugin transports can resolve their
   dependencies:

   ```sh
   LD_LIBRARY_PATH=<prefix>/lib \
     build-px4-hitl/_deps/mavlink_hub/src/mavlink_hub-build/mavlink_hub \
     -c app_config.json
   ```

   On startup `mavlink_hub` loads the four plugin libraries and applies the
   startup UserPlan, which brings up the declared MAVLink endpoints and agents.

## What the UserPlan examples declare

`resources/px4_hitl/user_plan_udp.json` — the PX4 HITL-over-UDP path:

- endpoint `px4_udp` of type `UdpByteTransport` (local port, remote
  address:port of the autopilot), connected on create;
- agent `heartbeat` of type `heartbeat_generator` (sends a MAVLink `HEARTBEAT`
  every second to the registered endpoint so PX4 recognizes a MAVLink device);
- agent `gz_bridge` of type `gz_agent`, bridging the `px4_udp` endpoint to the
  `iris` model in the `default` Gazebo world (topic names auto-generated), with
  the sensor send-loop at 250 Hz.

`resources/px4_hitl/user_plan_serial.json` — the PX4 HITL-over-serial/USB path:

- endpoint `px4_serial` of type `SerialByteTransport` (device path and baud
  rate of the flight controller), connected on create;
- agent `heartbeat` of type `heartbeat_generator`;
- agent `gz_bridge` of type `gz_agent`, bridging the `px4_serial` endpoint to
  the `iris` model in the `default` world.

Both plans use the `best_effort` policy: an invalid/missing entry is skipped
while the remaining valid entries are still applied (use `discard` for strict
behavior). All `config` values are JSON strings, as `mavlink_hub`'s plan parser
requires.

> Establishing or keeping a live PX4 HITL MAVLink link is a system-level,
> end-to-end property and is **not** a goal of this bundle on its own: the bundle
> assembles and brings up the endpoints and agents, after which the MAVLink
> traffic path (PX4 HITL ⇄ `mavlink_hub` ⇄ `gz_agent` ⇄ Gazebo) is complete and
> ready for a live autopilot/Gazebo run.

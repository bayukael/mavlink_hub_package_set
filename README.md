# mavlink_hub_package_set

A multi-bundle CMake superbuild home for the **mavlink_hub** ecosystem.

`mavlink_hub` is built from several separate repositories. `mavlink_hub_package_set`
collects them into reusable **bundles**: each bundle groups a set of upstream
repositories and builds them together, in dependency order, into a single install
prefix. A user picks which bundle to build with `-DBUNDLE=<name>`.

## Layout

```
mavlink_hub_package_set/
├── CMakeLists.txt          # reads -DBUNDLE=<name>; includes bundles/<name>.cmake
├── bundles/
│   ├── deps.cmake          # the mavlink_hub dependencies bundle (-DBUNDLE=deps)
│   ├── minimal.cmake       # the minimal mavlink_hub bundle (-DBUNDLE=minimal)
│   ├── px4_hitl.cmake      # the PX4 HITL plugin bundle (-DBUNDLE=px4_hitl)
│   └── common/             # helpers shared by bundles
│       ├── MakeDependency.cmake    # wraps a repo as an ExternalProject
│       └── init_submodules.cmake   # best-effort submodule init (HTTPS override)
├── resources/
│   └── px4_hitl/           # example UserPlan docs + app config for the PX4 HITL bundle
└── README.md
```

## Available bundles

| Bundle | Contents | Notes |
| ------ | -------- | ----- |
| `deps` | `byte_transport`, `mavlink_endpoint`, `mavlink_hub_sdk` | Dependency-only. No plugins, no Gazebo/serial pieces, no runnable app. |
| `minimal` | `byte_transport`, `mavlink_endpoint`, `mavlink_hub_sdk`, `mavlink_hub` | Runs the minimal `mavlink_hub` app. No plugins, no Gazebo/serial pieces. |
| `px4_hitl` | `byte_transport`, `serial_device`, `mavlink_endpoint`, `mavlink_hub_sdk`, `udp_byte_transport`, `serial_byte_transport`, `mavlink_hub`, `mavlink_hub_heartbeat_generator`, `mavlink_hub_gz_agent` | The complete MAVLink/Gazebo bridge for PX4 HITL: the minimal stack plus all the plugins (heartbeat generator, UDP/serial transports) and the Gazebo/serial pieces. Ships example UserPlans + app config in `resources/px4_hitl/`. Requires the Gazebo Garden system packages to build `mavlink_hub_gz_agent`. |

## Requirements

- CMake >= 3.13
- A C++17 compiler and a build tool (Ninja or Make)
- Git (to fetch the upstream repositories)
- GoogleTest (`find_package(GTest CONFIG REQUIRED)` is used by the
  dependencies; on Debian/Ubuntu install the `libgtest-dev` package, providing
  `/usr/lib/x86_64-linux-gnu/cmake/GTest`)
- Network access to GitHub (repos are cloned at configure time)

## Building a bundle

Choose a bundle and an install prefix, then configure, build, and install:

```sh
cmake -S . -B build -DBUNDLE=deps -DCMAKE_INSTALL_PREFIX=<prefix>
cmake --build build -j
cmake --install build
```

For example:

```sh
cmake -S . -B build -DBUNDLE=deps -DCMAKE_INSTALL_PREFIX=$HOME/mavlink_hub_package/install
cmake --build build -j8
cmake --install build
```

After install, the bundle's packages (headers, libraries, and CMake package
configs) are available under `<prefix>`. Point `CMAKE_PREFIX_PATH` at
`<prefix>` when configuring downstream CMake projects that consume them, e.g.
`cmake -S <consumer> -B <consumer>/build -DCMAKE_PREFIX_PATH=<prefix>`.

### What the `deps` bundle installs

The `deps` bundle builds the three mavlink_hub dependencies in order and
installs their headers, libraries, and CMake package configs into the install
prefix:

- **byte_transport** — `PendarlabByteTransport` (target `pendarlab::ByteTransport`)
- **mavlink_endpoint** — `PendarlabMavlinkEndpoint` (target `pendarlab::MavlinkEndpoint`)
- **mavlink_hub_sdk** — `PendarlabMavlinkHubSdk` (target `pendarlab::MavlinkHubSdk`)

It is deliberately dependency-only: it does **not** build the mavlink_hub app
itself, nor any plugin (heartbeat generator, UDP transport), nor any
Gazebo/serial piece (`mavlink_hub_gz_agent`, `serial_byte_transport`,
`serial_device`). Those belong to later bundles.

### What the `minimal` bundle builds

The `minimal` bundle is the runnable minimal mavlink_hub. It builds the three
`deps` components (byte_transport, mavlink_endpoint, mavlink_hub_sdk) and then
the `mavlink_hub` app itself on top of them, in dependency order:

1. **byte_transport** — `PendarlabByteTransport` (target `pendarlab::ByteTransport`)
2. **mavlink_endpoint** — `PendarlabMavlinkEndpoint` (target `pendarlab::MavlinkEndpoint`)
3. **mavlink_hub_sdk** — `PendarlabMavlinkHubSdk` (target `pendarlab::MavlinkHubSdk`)
4. **mavlink_hub** — the runnable CLI application (`mavlink_hub` executable)

The `mavlink_hub` dependency is configured as an ExternalProject against the
same shared install prefix, so it discovers the three dependencies through
`CMAKE_PREFIX_PATH`. Build it with:

```sh
cmake -S . -B build-minimal -DBUNDLE=minimal -DCMAKE_INSTALL_PREFIX=<prefix>
cmake --build build-minimal -j8
```

The `mavlink_hub` executable is produced in the bundle's build tree at
`build-minimal/_deps/mavlink_hub/src/mavlink_hub-build/mavlink_hub`; the
executable already carries an `$ORIGIN`/`<prefix>/lib` RUNPATH, so it runs
directly, e.g. `build-minimal/_deps/mavlink_hub/src/mavlink_hub-build/mavlink_hub
--help`.

Like the `deps` bundle, it is deliberately minimal: it does **not** build any
plugin (heartbeat generator, UDP transport) nor any Gazebo/serial piece
(`mavlink_hub_gz_agent`, `serial_byte_transport`, `serial_device`). Those belong
to the PX4 HITL plugin bundle.

### What the `px4_hitl` bundle builds

The `px4_hitl` bundle is the **complete** MAVLink/Gazebo bridge for running PX4 in
HITL with Gazebo. On top of the minimal stack it adds the plugins and the
Gazebo/serial pieces:

1. **byte_transport** — `PendarlabByteTransport` (target `pendarlab::ByteTransport`)
2. **serial_device** — `PendarlabSerialDevice` (target `pendarlab::SerialDevice`)
3. **mavlink_endpoint** — `PendarlabMavlinkEndpoint` (target `pendarlab::MavlinkEndpoint`)
4. **mavlink_hub_sdk** — `PendarlabMavlinkHubSdk` (target `pendarlab::MavlinkHubSdk`)
5. **udp_byte_transport** — `PendarlabUdpByteTransport` (target `pendarlab::UdpByteTransport`)
6. **serial_byte_transport** — `PendarlabSerialByteTransport` (target `pendarlab::SerialByteTransport`)
7. **mavlink_hub** — the runnable CLI application (`mavlink_hub` executable)
8. **mavlink_hub_heartbeat_generator** — the `heartbeat_generator` agent plugin (`libmavlink_hub_heartbeat_generator.so`)
9. **mavlink_hub_gz_agent** — the `gz_agent` agent plugin (`libmavlink_hub_gz_agent.so`)

The transport libraries and agent plugins are all installed into `<prefix>/lib`,
so `mavlink_hub`'s runtime loader (`dlopen`) can find them; shipped `resources/px4_hitl/app_config.json` loads all four. Build it with:

```sh
cmake -S . -B build-px4-hitl -DBUNDLE=px4_hitl -DCMAKE_INSTALL_PREFIX=<prefix>
cmake --build build-px4-hitl -j8
cmake --install build-px4-hitl
```

The `mavlink_hub` executable is produced in the bundle's build tree (its repo has
no install rules) and runs from there. See `resources/px4_hitl/README.md` for the
full run instructions, the example UserPlan documents (UDP and serial/USB PX4 HITL
paths), and the app config that loads all the bundled plugins.

## Bundle mechanism

The top-level `CMakeLists.txt` requires `-DBUNDLE=<name>` and, if
`bundles/<name>.cmake` exists, includes it. Each bundle file defines its
`ExternalProject`s (via `bundles/common/MakeDependency.cmake`). Dependencies
are declared in dependency order with `DEPENDS`, so upstream projects configure,
build, and install first, and each downstream project discovers them through the
shared `CMAKE_PREFIX_PATH`.

Submodules: upstreams may declare submodules over SSH. Each bundle can pass
`INIT_SUBMODULES "rel/path:https-url"` to the helper, which overrides the
submodule URL to a public HTTPS URL and initializes it after checkout so the
bundle can be built anonymously.

## Adding a new bundle

Bundles are discovered automatically: any `bundles/<name>.cmake` file becomes a
`-DBUNDLE=<name>` option. To add a bundle:

1. **Create `bundles/<name>.cmake`.** It runs when the user passes
   `-DBUNDLE=<name>`. Define the bundle's external projects there, usually by
   calling `add_mhp_dependency(...)` from `bundles/common/MakeDependency.cmake`
   (which `deps.cmake` already includes).
2. **Declare the dependencies in order.** List upstream repositories with
   `add_mhp_dependency`, giving each a `GIT_REPOSITORY` and, when one depends on
   another already built by the bundle, a `DEPENDS <upstream-name>`. Order and
   `DEPENDS` together ensure upstream projects configure, build, and install
   first.
3. **Handle submodules.** If an upstream declares a submodule over SSH, pass
   `INIT_SUBMODULES "rel/path:https-url"` so it can be fetched anonymously.
4. **Update the README.** Add the bundle to the "Available bundles" table with
    its contents and notes.
5. **Verify.** Configure with `-DBUNDLE=<name>`, build and install, and confirm
    a consumer can discover the bundle's packages from the shared install prefix.

Notes on plugin-only upstreams (repos that produce runtime `.so` plugins but
define no `install()` rules): pass `INSTALL_COPY <rel-file...>` to
`add_mhp_dependency` to copy the built artifact(s) from the dependency's build tree
into `<prefix>/lib` (e.g. `INSTALL_COPY libmavlink_hub_gz_agent.so`); skip the
install step entirely with `SKIP_INSTALL` for runnable executables that run from
their build tree. If the bundle ships example UserPlan documents or an app config,
place them under `resources/` — the top-level `CMakeLists.txt` installs that whole
directory into `<prefix>/share/mavlink_hub_package_set/`.

Example skeleton:

```cmake
# bundles/<name>.cmake
include("${CMAKE_CURRENT_LIST_DIR}/common/MakeDependency.cmake")

add_mhp_dependency(<comp-a>
    GIT_REPOSITORY https://github.com/<owner>/<comp-a>.git
    GIT_TAG main
)

add_mhp_dependency(<comp-b>
    GIT_REPOSITORY https://github.com/<owner>/<comp-b>.git
    GIT_TAG main
    DEPENDS <comp-a>
)
```

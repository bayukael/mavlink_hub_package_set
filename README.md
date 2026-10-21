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
│   └── common/             # helpers shared by bundles
│       ├── MakeDependency.cmake    # wraps a repo as an ExternalProject
│       └── init_submodules.cmake   # best-effort submodule init (HTTPS override)
└── README.md
```

## Available bundles

| Bundle | Contents | Notes |
| ------ | -------- | ----- |
| `deps` | `byte_transport`, `mavlink_endpoint`, `mavlink_hub_sdk` | Dependency-only. No plugins, no Gazebo/serial pieces, no runnable app. |

More bundles (the minimal runnable mavlink_hub, the PX4 HITL plugin bundle) are
added to this same repository by later tasks.

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
cmake -S . -B build -DBUNDLE=deps -DCMAKE_INSTALL_PREFIX=$HOME/mhp/install
cmake --build build -j8
cmake --install build
```

After install, the bundle's packages are available under `<prefix>`; point
`CMAKE_PREFIX_PATH` at `<prefix>` to consume them from downstream CMake
projects:

```sh
export CMAKE_PREFIX_PATH=<prefix>
```

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

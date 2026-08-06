# meta-torizon

Torizon OS is an embedded Linux distribution for the Torizon platform. It
features, among other essential services, a container runtime and components
for secure remote over-the-air (OTA) updates.

`meta-torizon` is the distro layer: it defines the board-independent Torizon OS
distribution configuration, image recipes, OTA/SOTA stack, container runtime,
and OS policy.

Board and BSP adaptations live in the companion
[`meta-torizon-bsp`](https://github.com/torizon/meta-torizon-bsp) layer, which
depends on this layer. Together, the two layers provide the metadata for these
Torizon OS flavors:

- **Torizon**: built on top of Toradex's BSP.
- **Common Torizon**: built on top of BSPs from third parties.

## Building and documentation

Build instructions for Torizon and Common Torizon, including the complete set
of machine-specific guides, are maintained in the
[`meta-torizon-bsp` README](https://github.com/torizon/meta-torizon-bsp#building-torizon-os).

For an overview of the responsibilities and integration between the two layers,
see [Architecture & Migration](https://github.com/torizon/meta-torizon-bsp/blob/master/docs/architecture-migration.md).

For contribution guidelines specific to this repository, see
[CONTRIBUTING.md](./docs/CONTRIBUTING.md).

## Reporting issues

If you encounter an issue while using or developing Torizon OS, open an issue
in the relevant layer repository or create a Technical Support topic in the
[Toradex Developer Community](https://community.toradex.com/).

## License

All metadata is MIT licensed unless otherwise stated. Source code and binaries
included in the tree for individual recipes are under the license stated in
each recipe (`.bb` file), unless otherwise stated.

This README document is Copyright (C) 2019-2025 Toradex AG.

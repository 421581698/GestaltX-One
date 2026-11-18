# Native dependency pin

GestaltX One pins the upstream repository as a Git submodule at:

- Repository: https://github.com/huamidev/GestaltX
- Commit: `311f78999d9f5f062f7e3b4c6374684782be5382`
- Native component: `Native/DeviceConsole`
- License: GPL-3.0-only for `gx_device_console`

The submodule is intentionally pinned rather than tracking upstream `main`.
Update it only after reviewing the upstream diff, license notices, native FFI
surface, and device-pairing behavior.

The native console implements the pairing host and RSD/syslog transport. It
does not implement MobileGestalt file access or writes. Those remain a separate
capability and must not be advertised as available until independently
implemented and verified.

The upstream source and its complete notices are available through the
submodule. Any distributed combined build that incorporates this GPL component
must satisfy GPL-3.0 obligations, including providing corresponding source and
preserving notices. This repository does not claim that the upstream code is
relicensed under a different license.

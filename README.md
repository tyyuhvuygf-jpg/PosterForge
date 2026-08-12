# PosterForge

PosterForge is a rootless iOS 16 jailbreak tweak that creates custom entries in Apple's
PosterBoard wallpaper gallery directly on the device.

## Current feature set

- PreferenceLoader page in the system Settings app.
- Photo and video selection through the system Photos picker.
- Full-screen crop/zoom editor for photos.
- Optional pre-blurred background layer for the paired Home Screen.
- On-device conversion of video into a looping Core Animation poster.
- Safe `.tendies` descriptor import with ZIP path validation and randomized IDs.
- Native gallery placement under **Add New Wallpaper → Collections**.
- Swipe-to-delete library management.
- Rootless privileged daemon so the Settings process never edits another app container.
- Runtime storage under `/var/mobile/Library/Application Support/PosterForge`.

## Compatibility

- iOS 16.0 through the iOS 16.7.x family.
- Rootless jailbreaks (palera1n on iPhone X/8; compatible Dopamine configurations on
  supported devices/versions).
- `arm64` and `arm64e` builds.

This code deliberately avoids hooking private SpringBoard view classes. PosterBoard itself
renders each installed descriptor, which is substantially safer across iOS 16 point releases.

## Build

Install current Theos and use an iOS 16 or newer SDK:

```sh
export THEOS=/opt/theos
make clean package FINALPACKAGE=1
```

The package is emitted in `packages/`. To install while the phone is reachable by SSH:

```sh
make package install THEOS_DEVICE_IP=iphone.local
```

The project forces `THEOS_PACKAGE_SCHEME=rootless`. The resulting package expects the
rootless prefix `/var/jb`.

## Operational notes

- PosterBoard's descriptor store on iOS 16 is structure version `59`.
- Apple/Nugget-compatible descriptor packages appear under Collections.
- PosterBoard has a practical gallery descriptor limit. If a new entry does not appear,
  remove older custom entries and restart PosterBoard or respring.
- Video is capped at 400 frames. At 15 fps this is about 26.6 seconds. This avoids extreme
  storage use and PosterBoard instability. A 10-second video creates 150 JPEG frames.
- Audio is intentionally discarded because WallpaperKit posters do not play wallpaper audio.
- The Home blur is produced as the descriptor's background layer while the sharp image is
  placed in the floating layer. Apple's renderer controls the final Lock/Home transition;
  users can still adjust the native Home Screen blur after adding the poster.
- `.tendies` container-format restores are intentionally rejected. Descriptor-format packages
  are supported; blindly restoring an entire PosterBoard container is too risky for an
  on-device root daemon.
- Animated packages created for newer iOS releases can reference classes or assets absent on
  iOS 16. PosterForge can import the package but cannot make missing Apple frameworks exist.

## Branding

The project intentionally ships without final artwork. Add a Settings icon before release and
change the package ID, daemon label, preference bundle ID, and display strings to your brand.

## License

MIT. Selling compiled copies is allowed. Third-party `.tendies` packages and Apple wallpaper
assets may have their own copyright and distribution terms; do not bundle assets you cannot
redistribute.

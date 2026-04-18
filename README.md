# ginko

ginko is the backend for [tsumi](https://github.com/kirara-research/tsumi), 
a Project Sekai story viewer. It is a Vapor app written in Swift.

## Configuration

- `DATA_ROOT` - Path containing story.db and master.db. Use hime from the
  Python repo to manage these. There are no plans to port the importers
  to Swift.
- `TSUMI_ALLOWED_ORIGINS` - For CORS. The live server allows access from
  127.0.0.1 and 10.x.x.x. If you're running the svelte dev server, make sure
  it listens on one of those IPs.

`./tsumi/lib/libfts5_icu_legacy.so` also needs to exist relative to cwd.
Build it from https://github.com/cwt/fts5-icu-tokenizer.

The docker files in this repo are from the vapor template, and aren't used
for deployment.

## Building for deployment

ginko is currently deployed on `mafuyu`, the arm64 SBC under my desk.
To set up cross-compilers for similar targets, do:

1. Get the linux SDK generator: https://github.com/swiftlang/swift-sdk-generator
2. Make your SDK. `swift run swift-sdk-generator make-linux-sdk --host-toolchain --target-arch aarch64 --distribution-name debian --distribution-version 12`
   Change the distro args as needed. 
3. Install the generated SDK. `swift sdk install .../6.2.4-RELEASE_debian_bookworm_aarch64.artifactbundle`
4. Inject the sqlite3 dev packages if needed: https://packages.debian.org/source/bookworm/sqlite3
   The SDK is unpacked to `~/.swiftpm/swift-sdks`, inside there will be a sysroot you can extract files into.
5. Now you can build against the custom SDK. `swift build --swift-sdk 6.2.4-RELEASE_debian_bookworm_aarch64 --triple aarch64-unknown-linux-gnu -c release --static-swift-stdlib`

# moonbit-binaries

> Binaries archiving service for MoonBit programming language.

[![Snap Schedule][ci-badge]][cicd]
[![Snap Schedule Nighly][ci-badge-nightly]][cicd-nightly]
[![license][license-badge]](LICENSE)
[![downloads][downloads-badge]][releases]
[![downloads][downloads-badge-nightly]][releases-nightly]

For more information about the MoonBit programming language, see [moonbitlang's website][moonbit-website].

## Why

While MoonBit in its early stages of development, only the latest build of the toolchain and the standard library is available on its website. There is currently no official way to obtain earlier versions of the toolchain and the standard library of MoonBit. This repository aims to provide a service to archive every release of the toolchain and the standard library, so that users may download and use them for research and development purposes.

## Getting Started

If you are using [Moonup] then you are all set. Moonup already provides you MoonBit toolchains available in this repository:

```
moonup install --list-available
```

If not, you may grab one from the [releases] page, the release index is available on the [gh-pages] branch of this repository.

NOTE: Earlier versions released before this service went live are not available.

## License

**moonbit-binaries** © [Chawye Hsu](https://github.com/chawyehsu). Released under the [MIT](LICENSE) license.  
For the license of the binaries/archives of MoonBit, please refer to its website.

> [Blog](https://chawyehsu.com) · GitHub [@chawyehsu](https://github.com/chawyehsu) · Twitter [@chawyehsu](https://twitter.com/chawyehsu)


[ci-badge]: https://github.com/chawyehsu/moonbit-binaries/actions/workflows/schedule.yml/badge.svg
[cicd]: https://github.com/chawyehsu/moonbit-binaries/actions/workflows/schedule.yml
[ci-badge-nightly]: https://github.com/chawyehsu/moonbit-binaries/actions/workflows/schedule_nightly.yml/badge.svg
[cicd-nightly]: https://github.com/chawyehsu/moonbit-binaries/actions/workflows/schedule_nightly.yml
[license-badge]: https://img.shields.io/github/license/chawyehsu/moonbit-binaries?label=License
[releases]: https://github.com/chawyehsu/moonbit-binaries/releases
[releases-nightly]: https://github.com/chawyehsu/moonbit-dist-nightly/releases
[downloads-badge]: https://img.shields.io/github/downloads/chawyehsu/moonbit-binaries/total?label=Downloads
[downloads-badge-nightly]: https://img.shields.io/github/downloads/chawyehsu/moonbit-dist-nightly/total?label=Downloads%20(Nightly)
[moonbit-website]: https://moonbitlang.com/
[gh-pages]: https://github.com/chawyehsu/moonbit-binaries/tree/gh-pages
[Moonup]: https://github.com/chawyehsu/moonup

emacs-dmg-build: DMG Package Builder of Gnu Emacs
===========================

[![Emacs 29 Ready](https://img.shields.io/badge/Emacs29-Ready-green?style=flag&logo=gnuemacs&logoColor=white&labelColor=7F5AB6)](https://github.com/jado4810/emacs-dmg-build/releases/tag/29.4)
[![macOS15 Ready](https://img.shields.io/badge/macOS15-Ready-green?style=flat&logo=apple&logoColor=white&labelColor=black)](https://www.apple.com/macos/macos-sequoia/)
[![Intel Universal Binary](https://img.shields.io/badge/Universal_Binary-0071C5?style=flat&logo=intel&logoColor=white&logoSize=auto)](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
[![arm Universal Binary](https://img.shields.io/badge/Universal_Binary-0091BD?style=flat&logo=arm&logoColor=white&logoSize=auto)](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)

EN|[JA](./README-ja.md)

Overview
--------

A build script to make a dmg package of Gnu Emacs for macOS.
It will generate the universal binaries with Apple Silicon.

It works without any dependencies on external libraries; having GnuTLS runtimes for SSL/TLS connections, and handling images by standard ns GUI functions.

Applies some patches from [Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus).
Also, [inline patch](https://github.com/takaxp/ns-inline-patch) would be available useful for CJK environment.

How to build
------------

### 1\. Get sources

Fetch below and store under `sources`.
It will recognize both `.tar.gz` and `.tar.xz` formats automatically.

#### a. Source of Gnu Emacs

Available on Gnu mirror ( https://ftpmirror.gnu.org/emacs/ ).

#### b. Source of nettle

Imprementation of cryptographic algorithm, required for GnuTLS.

Available on Gnu mirror ( https://ftpmirror.gnu.org/nettle/ ).

#### c. Source of GnuTLS

Imprementation of SSL/TLS.
Emacs requires GnuTLS, not OpenSSL coming with macOS.

Available on official site ( https://www.gnutls.org/download.html ).

#### d. High resolution icons for Emacs MacPort

Requires only if set `USEHRICON=yes`.
In that case, it will replace application icons and toolbar icons to what it provides.

Available on FTP server of Chiba univ. ( ftp://ftp.math.s.chiba-u.ac.jp/emacs/ ) where the MacPort patch is provided.

> [!NOTE]
>
> We checked the versions specified in the build script, but newer ones should work, especially for required libraries.
> In that case, set versions in the script to match retrieved ones.

### 2\. Setup build environment

Edit the build script ( `emacs-dmg-build.sh` ) to modify the following variables near the top.

#### a. Versions of each sources

Set `EMACSVER`, `NETTLEVER`, `GNUTLSVER` and `HRICONVER` values to match those of retrieved ones.

#### b. Path where site-lisp will be stored

Set `SITELISP` value to site-lisp path, where the lisps available system-wide will be stored.

The default value is `/Library/Application Support/Emacs/site-lisp`, and recommended such path outside the package.

#### c. Whether to activate the inline patch

To apply inline patch which Ishikawa Takaaki coordinates at https://github.com/takaxp/ns-inline-patch , set `USEINLINE` to `yes`.

Although, in recent versions of Emacsen, the inline (on the spot) input via OS-native input method is available, activate it if necessary because of some useful extentions, such as changing input modes with `toggle-input-method`, or hooks when changing input modes.

#### d. Whether to apply high resolution icons

To use high resolution icons by Emacs MacPort (emacs-hires-icons), set `USEHRICON` to `yes`.

If enabled, the images from those icons will be used for application icons and toolbar.
  However, the splash images will not be used as the SVG images used by recent versions of Emacsen are preferred.

#### e. Whether to customize application icons

To customize application icons as you like, set `USEAPPICON` to `yes`.

It would be useful when using icons which the EmacsPlus project coordinates to be available in their build options.
If enabled, `Emacs.icns` and `document.icns` are preferred to those of emacs-hires-icons.

#### f. Whether to customize splash images

To customize splash images as you like, set `USESPLASH` to `yes`.

If enabled, `splash.png`, `splash.xpm` and `splash.pbm` are overridden, and the default SVG splash image is disabled.

In the macOS environment, virtually only PNG images are likely to be used, but XPM and PBM images may be used if the system is launched in a display environment with a low number of colors.

It seems that only PNG images are actually used in the macOS environment, but XPM or PBM images might be used in the environment with low color depth.

#### g. Target architectures

Set `ARCHES` as an array of target architectures names.
By default, it will build the universal binaries of arm64 and x86_64.

In intel environment, set `ARCHES=(x86_64)` because it cannot build arm64 binaries.

> [!NOTE]
>
> To build Apple Silicon only binaries, set `ARCHES=(arm64)`.
> This will save a little on installation size, however it will not have much impact on space as other applications, because of most footprint by lisps and pdumps in the case of Emacsen.

#### h. Number of cores to use on build

Set `CORES` to the number of parallel processes on build.
It will be an argument of `-j` option for make.

The default value is 4, and it works fine in the recent mac environments.

> [!NOTE]
>
> In the environment with more than 4 performance cores, it will reduce a little on build time to set it to the number of those cores.
> However, since most of build time is spent in executing configure on cross building of GnuTLS, it seems to be within the variability.

### 3\. Store custom images

When setting `USEAPPICON` or `USESPLASH` to `yes`, store corresponding images under `custom-images`.
It is not necessary to store all of image files since only the found files would be replaced.

* In the case of `USEAPPICON=yes` - `Emacs.icns` and `document.icns`
* In the case of `USESPLASH=yes` - `splash.png`, `splash.xpm` and `splash.pbm`

### 4\. Prepare the required tools

Install the tools required to build if not installed yet.
These would be used only when building and have no dependencies from the dmg package contents to be built.

#### a. Compiler sets (make, clang/gcc and ld)

Install the Xcode command line tools.

```console
$ xcode-select --install
```

#### b. Texinfo

Install it via homebrew and so on.

```console
$ brew install texinfo
```

#### c. Automake

Requires only if set `USEINLINE=yes`.
Install it via homebrew and so on.

```console
$ brew install automake
```

### 5\. Execute the build script

Execute the build script to create the dmg package under `build`.
It takes about 10 minutes in the environment of Apple M3.

```console
$ sh emacs-dmg-build.sh
```

The source packages are expanded under `build`.
You can delete them if not necessary.

LICENSE
-------

The script and the patches under [patches/custom](./patches/custom) are provided under [CC0](./LICENSE.txt).

Refer to the distributors below about the external patches under [patches/plus](./patches/plus) and [patches/inline](./patches/inline).

### Distributors of included patches

* homebrew-emacs-plus - https://github.com/d12frosted/homebrew-emacs-plus
* ns-inline-patch - https://github.com/takaxp/ns-inline-patch

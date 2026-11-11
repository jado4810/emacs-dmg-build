# emacs-dmg-build - Changelog

## 31.2

* For Emacs-31.2
* Some tweaks on build environment
    * Avoid error about Xcode SDK version mismatch especially with older macOS
    * Fix some values of constants derived from build environment, such as,
      emacs-repository-version, emacs-repository-branch and source-directory
    * Suppress warning on site-init.el while building
* Update middlewares below
    * tree-sitter-0.27.2

## 31.1 (2026-08-25)

* For Emacs-31.1
* Change default configuration to build arm64 uni-arch binaries
* Remove "arch" options and commands for native build without Rosetta2
* Now builtin libraries are built with install_name defined relative to @rpath
  and executables are built with LC_RPATH defined, so it can be run from any
  location where it is extracted
* Support treesit and add some builtin grammars
* Added new patches for older Versions
    * Scrolling issue on macOS Tahoe - for Emacs-30.2
    * Updating ns-x-color - for Emacs-30.1 and later
    * Compatibility issue on tree-sitter - for Emacs-29.1 and later
* Update middlewares below
    * Nettle-4.0
    * GnuTLS-3.8.13

## 30.2 (2025-08-15)

* For Emacs-30.2
* Include emacs-hires-icons so no longer necessary to fetch it
* Update middlewares below
    * Nettle-3.10.2
    * GnuTLS-3.8.10

## 30.1 (2025-02-25)

* For Emacs-30.1
* Update middlewares below
    * Nettle-3.10.1
    * GnuTLS-3.8.9
* NOTE: pkgconf (pkg-config) is now additionally required to build GnuTLS-3.8.9

## 29.4 (2024-11-28)

* Initial version for Emacs-29.4

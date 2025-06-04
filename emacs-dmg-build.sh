#!/bin/bash

# DMG Package Builder of Gnu Emacs
#
# Provided under CC0
# https://creativecommons.org/publicdomain/zero/1.0/

set -e -o pipefail

# CONFIGURATIONS start -----------------

# Emacs version
#EMACSVER=29.4
EMACSVER=30.1
#EMACSVER=31.0.50

# nettle version
NETTLEVER=3.10.1

# GnuTLS version
GNUTLSVER=3.8.9

# site-lisp path
SITELISP="/Library/Application Support/Emacs/site-lisp"

# Set 'yes' to apply ns-inline-patch
USEINLINE=yes

# Set 'yes' to use modern high resolution icons from Emacs MacPort
USEHRICON=yes

# Set 'yes' to customize application icons
USEAPPICON=no

# Set 'yes' to customize splash images
USESPLASH=no

# Target architectures
ARCHES=(arm64 x86_64)

# Number of parallel processes on build
CORES=4

# CONFIGURATIONS end -----------------

SCRIPTDIR=$(cd $(dirname $0); echo $PWD)
SRCDIR=$SCRIPTDIR/sources
BUILDDIR=$SCRIPTDIR/build
PATCHDIR=$SCRIPTDIR/patches
HRICONDIR=$SCRIPTDIR/icons
IMAGEDIR=$SCRIPTDIR/custom-images

# Sources

EMACSSRC=$SRCDIR/emacs-$EMACSVER
NETTLESRC=$SRCDIR/nettle-$NETTLEVER
GNUTLSSRC=$SRCDIR/gnutls-$GNUTLSVER

case $EMACSVER in
*-rc*)
  EMACS=$BUILDDIR/emacs-${EMACSVER%-rc*}
  ;;
*)
  EMACS=$BUILDDIR/emacs-$EMACSVER
  ;;
esac
NETTLE=$BUILDDIR/nettle-$NETTLEVER
GNUTLS=$BUILDDIR/gnutls-$GNUTLSVER

# Directories

PKGROOT=$EMACS/pkgroot
APPROOT=/Applications
CTSROOT=$APPROOT/Emacs.app/Contents
PREFIX=$CTSROOT/Resources
EXEPREFIX=$CTSROOT/MacOS
LIBDIR=$EXEPREFIX/lib
BUILD_PREFIX=/build-opt
BUILD_INCLUDEDIR=$BUILD_PREFIX/include

LOGFILE=$SCRIPTDIR/build.log

# Options

ARCH_FLAGS=()
for arch in ${ARCHES[@]}; do
  ARCH_FLAGS+=("-arch $arch")
done
ARCH_FLAGS="${ARCH_FLAGS[*]}"

EMACS_CFLAGS="-O2 -DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT"

BUILD_CFLAGS=-I$PKGROOT$BUILD_INCLUDEDIR
BUILD_LDFLAGS=-L$PKGROOT$LIBDIR

# Patches

parse_versions () {
  major=(${1%%.*})
  rest=${1#*.}

  case $1 in
  *.*.*)
    minor=${rest%%.*}
    beta=${rest#*.}
    ;;
  *.*-rc*)
    minor=${rest%-rc*}
    beta=$((${rest#$minor-rc} - 100))
    ;;
  *.*)
    minor=$rest
    beta=0
    ;;
  *)
    echo >&2 "Illegal version"
    exit 1
  esac

  echo "$major $minor $beta"
}

comp_versions () {
  [ $1 -lt $4 ] && return 0
  [ $1 -gt $4 ] && return 1
  [ $2 -lt $5 ] && return 0
  [ $2 -gt $5 ] && return 1
  [ $3 -lt $6 ] && return 0
  return 1
}

find_patches () {
  topdir=$PATCHDIR/$1
  patchtype=${2:+-$2}

  target=(`parse_versions $EMACSVER`)

  patchdir=
  latest=()
  for dir in $topdir/*; do
    [ -d $dir ] || continue

    curr=(`parse_versions ${dir##*/}`)
    comp_versions "${target[@]}" "${curr[@]}" && continue

    if [ -n "$patchdir" ]; then
      comp_versions "${curr[@]}" "${latest[@]}" && continue
    fi

    patchdir=$dir
    latest=("${curr[@]}")
  done

  if [ -z "$patchdir" ]; then
    echo >&2 "No patches matching emacs-$EMACSVER found."
    exit 1
  fi

  for file in `cat $patchdir/.index$patchtype`; do
    [ "${file:0:1}" = "#" ] || echo $topdir/$file
  done
}

PATCHES=(`find_patches plus`)
[ "$USEINLINE" = "yes" ] && PATCHES+=(`find_patches inline`)
[ "$USEHRICON" = "yes" ] && PATCHES+=(`find_patches custom icons`)
[ "$USESPLASH" = "yes" ] && PATCHES+=(`find_patches custom splash`)

# Common operations

do_extract_src () {
  src=$1
  dir=$2

  if [ -f $src.tar.gz ]; then
    echo "tar zxpf $src.tar.gz"
    tar zxpf $src.tar.gz
  elif [ -f $src.tar.xz ]; then
    echo "tar Jxpf $src.tar.xz"
    tar Jxpf $src.tar.xz
  else
    echo >&2 "not found: $src.tar.gz|xz"
    exit 1
  fi
  echo "xattr -cr $dir"
  xattr -cr $dir
}

extract_src () {
  src=$1
  dir=$2
  mode=$3

  # Delete old source directories
  if [ -d $dir ]; then
    echo "rm -rf $dir"
    rm -rf $dir
  fi
  for arch in ${ARCHES[@]}; do
    if [ -d ${dir}_$arch ]; then
      echo "rm -rf ${dir}_$arch"
      rm -rf ${dir}_$arch
    fi
  done

  if [ -z "$mode" ]; then
    do_extract_src $src $dir
  else
    for arch in ${ARCHES[@]}; do
      do_extract_src $src $dir
      echo "mv $dir ${dir}_$arch"
      mv $dir ${dir}_$arch
    done
  fi
}

install_arch () {
  arch=$1
  shift

  for dir in ${PKGROOT}_*; do
    # Install under $PKGROOT only in the first time (to be the base tree)
    if [ $dir = "${PKGROOT}_*" ]; then
      echo "DESTDIR=$PKGROOT $@"
      DESTDIR=$PKGROOT "$@"
    fi
    break
  done

  if [ ${#ARCHES[@]} -gt 1 ]; then
    # Install under trees for each architectures (to pick binaries)
    echo "DESTDIR=${PKGROOT}_$arch $@"
    DESTDIR=${PKGROOT}_$arch "$@"
  fi
}

gen_univ_binaries () {
  # List target files
  cd ${PKGROOT}_${ARCHES[0]}
  BINARY_FILES=()
  for file in `find . -type f -print`; do
    case `file -b --mime-type $file` in
    application/*binary*)
      BINARY_FILES+=(${file#./})
      ;;
    esac
  done

  for file in ${BINARY_FILES[@]}; do
    # Gather binary files among architectures into the universal binaries
    files=()
    for arch in ${ARCHES[@]}; do
      files+=(${PKGROOT}_$arch/$file)
    done

    echo "lipo -create ${files[@]} -output $PKGROOT/$file"
    lipo -create ${files[@]} -output $PKGROOT/$file
  done

  # Delete trees for each architectures
  for arch in ${ARCHES[@]}; do
    echo "rm -rf ${PKGROOT}_$arch"
    rm -rf ${PKGROOT}_$arch
  done
}

fake_libs () {
  if [ -d $LIBDIR ]; then

    # Escape existing libraries
    mv $LIBDIR ${LIBDIR}_
    # Make symlink to the place where the libraries are to be installed,
    # since the libraries can be linked only on the actual path in macOS
    ln -s $PKGROOT$LIBDIR $LIBDIR || {
      mv ${LIBDIR}_ $LIBDIR
      exit 1
    }

    echo "$@"
    "$@" || {
      rm -f $LIBDIR && mv ${LIBDIR}_ $LIBDIR
      exit 1
    }

    # Restore libraries
    rm -f $LIBDIR && mv ${LIBDIR}_ $LIBDIR

  else

    # Temporarily mkdir the app directory since it has not been installed yet
    mkdir -p $EXEPREFIX
    # Make symlink to the place where the libraries are to be installed,
    # since the libraries can be linked only on the actual path in macOS
    ln -s $PKGROOT$LIBDIR $LIBDIR || {
      for dir in $EXEPREFIX $CTSROOT $APPROOT/Emacs.app; do
        rmdir $dir
      done
      exit 1
    }

    echo "$@"
    "$@" || {
      rm -f $LIBDIR
      for dir in $EXEPREFIX $CTSROOT $APPROOT/Emacs.app; do
        rmdir $dir
      done
      exit 1
    }

    # Restore libraries
    rm -f $LIBDIR && {
      # Delete temporarily-made app directory
      for dir in $EXEPREFIX $CTSROOT $APPROOT/Emacs.app; do
        rmdir $dir || break
      done
    }
  fi
}

# Extract source archives -----------------

echo
echo "*******************************************"
echo "**************** Preparing ****************"
echo "*******************************************"
echo
date +"%Y/%m/%d %T - Prepare" > $LOGFILE

echo "cd $BUILDDIR"
cd $BUILDDIR

extract_src $EMACSSRC $EMACS
extract_src $NETTLESRC $NETTLE arch
extract_src $GNUTLSSRC $GNUTLS arch

# Build required libraries to include into the package -----------------

echo
echo "*************************************************"
echo "**************** Building nettle ****************"
echo "*************************************************"

# Build by each architectures and concat, due to existence of assembly codes
for arch in ${ARCHES[@]}; do
  echo
  echo "================ Target arch: $arch ================"
  echo
  date +"%Y/%m/%d %T - nettle/$arch" >> $LOGFILE

  echo "cd ${NETTLE}_$arch"
  cd ${NETTLE}_$arch

  echo "CFLAGS=\"-arch $arch\" LDFLAGS=\"-arch $arch\" arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --disable-static --enable-mini-gmp"
  CFLAGS="-arch $arch" LDFLAGS="-arch $arch" arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --disable-static --enable-mini-gmp

  echo "make -j$CORES"
  make -j$CORES

  install_arch $arch make install
done

if [ ${#ARCHES[@]} -gt 1 ]; then
  echo
  echo "================ Creating universal binaries ================"
  echo
  date +"%Y/%m/%d %T - nettle/universal" >> $LOGFILE

  gen_univ_binaries
fi

echo
echo "*************************************************"
echo "**************** Building GnuTLS ****************"
echo "*************************************************"

# Build by each architectures and concat, due to existence of assembly codes
for arch in ${ARCHES[@]}; do
  echo
  echo "================ Target arch: $arch ================"
  echo
  date +"%Y/%m/%d %T - GnuTLS/$arch" >> $LOGFILE

  echo "cd ${GNUTLS}_$arch"
  cd ${GNUTLS}_$arch

  echo "CFLAGS=\"-arch $arch\" LDFLAGS=\"-arch $arch\" NETTLE_CFLAGS=\"$BUILD_CFLAGS\" NETTLE_LIBS=\"$BUILD_LDFLAGS -lnettle\" HOGWEED_CFLAGS=\"$BUILD_CFLAGS\" HOGWEED_LIBS=\"$BUILD_LDFLAGS -lhogweed\" arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --with-nettle-mini --with-included-libtasn1 --with-included-unistring --without-p11-kit --disable-static --disable-tools"
  CFLAGS="-arch $arch" LDFLAGS="-arch $arch" NETTLE_CFLAGS="$BUILD_CFLAGS" NETTLE_LIBS="$BUILD_LDFLAGS -lnettle" HOGWEED_CFLAGS="$BUILD_CFLAGS" HOGWEED_LIBS="$BUILD_LDFLAGS -lhogweed" arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --with-nettle-mini --with-included-libtasn1 --with-included-unistring --without-p11-kit --disable-static --disable-tools

  fake_libs make -j$CORES

  install_arch $arch make install
done

if [ ${#ARCHES[@]} -gt 1 ]; then
  echo
  echo "================ Creating universal binaries ================"
  echo
  date +"%Y/%m/%d %T - GnuTLS/lipo" >> $LOGFILE

  gen_univ_binaries
fi

# move unnecessary pkgconfig
echo "mv $PKGROOT$LIBDIR/pkgconfig $PKGROOT$BUILD_PREFIX/share/"
mv $PKGROOT$LIBDIR/pkgconfig $PKGROOT$BUILD_PREFIX/share/

# Build Emacs -----------------

echo
echo "************************************************"
echo "**************** Building Emacs ****************"
echo "************************************************"
echo
date +"%Y/%m/%d %T - Emacs" >> $LOGFILE

echo "cd $EMACS"
cd $EMACS

for patch in "${PATCHES[@]}"; do
  echo "cat $patch | patch -p1"
  cat $patch | patch -p1
done

if [ "$USEHRICON" = "yes" ]; then
  echo "cp -pf $HRICONDIR/toolbar/* etc/images"
  cp -pf $HRICONDIR/toolbar/* etc/images

  echo "cp -pf $HRICONDIR/app/* nextstep/Cocoa/Emacs.base/Contents/Resources"
  cp -pf $HRICONDIR/app/* nextstep/Cocoa/Emacs.base/Contents/Resources
fi

if [ "$USEAPPICON" = "yes" ]; then
  for file in Emacs.icns document.icns; do
    if [ -f $IMAGEDIR/$file ]; then
      echo "cp -pf $IMAGEDIR/$file nextstep/Cocoa/Emacs.base/Contents/Resources"
      cp -pf $IMAGEDIR/$file nextstep/Cocoa/Emacs.base/Contents/Resources
    fi
  done
fi

if [ "$USESPLASH" = "yes" ]; then
  for ext in png xpm pbm; do
    if [ -f $IMAGEDIR/splash.$ext ]; then
      echo "cp -pf $IMAGEDIR/splash.$ext etc/images"
      cp -pf $IMAGEDIR/splash.$ext etc/images
    fi
  done

  echo "rm -f etc/images/splash.svg"
  rm -f etc/images/splash.svg
fi

echo "rm -f etc/images/splash.bmp"
rm -f etc/images/splash.bmp

if [ "$USEINLINE" = "yes" ]; then
  echo "./autogen.sh"
  ./autogen.sh
fi

# archlibdir fix
#echo "sed -e 's/\${libexecdir}\\/emacs\\/\${version}\\/\${configuration}/\${libexecdir}/' -i '' configure Makefile.in"
#sed -e 's/${libexecdir}\/emacs\/${version}\/${configuration}/${libexecdir}/' -i '' configure Makefile.in

echo "CFLAGS=\"$ARCH_FLAGS $EMACS_CFLAGS\" LDFLAGS=\"$ARCH_FLAGS\" LIBGNUTLS_CFLAGS=\"$BUILD_CFLAGS\" LIBGNUTLS_LIBS=\"$BUILD_LDFLAGS -lgnutls\" ./configure --with-ns --enable-locallisppath=\"$SITELISP\""
CFLAGS="$ARCH_FLAGS $EMACS_CFLAGS" LDFLAGS="$ARCH_FLAGS" LIBGNUTLS_CFLAGS="$BUILD_CFLAGS" LIBGNUTLS_LIBS="$BUILD_LDFLAGS -lgnutls" ./configure --with-ns --enable-locallisppath="$SITELISP"

fake_libs make -j$CORES

fake_libs make install

#mkdir -p $PKGROOT$APPROOT
#cp -Rp mac/Emacs.app $PKGROOT$APPROOT

echo "tar cf - -C nextstep/Emacs.app/Contents . | tar xpf - -C $PKGROOT$CTSROOT"
tar cf - -C nextstep/Emacs.app/Contents . | tar xpf - -C $PKGROOT$CTSROOT

# duplicated binaries fix
#ln -sf bin/emacs $PKGROOT$EXEPREFIX/Emacs

#cp $PATCHDIR/site-start.el $PKGROOT$PREFIX/share/emacs/site-lisp

echo "cp -p $PATCHDIR/plus/LICENSE $PKGROOT$PREFIX/etc/LICENSE-homebrew-emacs-plus"
cp -p $PATCHDIR/plus/LICENSE $PKGROOT$PREFIX/etc/LICENSE-homebrew-emacs-plus

if [ "$USEINLINE" = "yes" ]; then
  echo "cp -p $PATCHDIR/inline/LICENSE $PKGROOT$PREFIX/etc/LICENSE-ns-inline-patch"
  cp -p $PATCHDIR/inline/LICENSE $PKGROOT$PREFIX/etc/LICENSE-ns-inline-patch
fi

if [ "$USEHRICON" = "yes" ]; then
  for file in README NEWS; do
    echo "cp -p $HRICONDIR/$file-hires-icons $PKGROOT$PREFIX/etc"
    cp -p $HRICONDIR/$file-hires-icons $PKGROOT$PREFIX/etc
  done
fi

echo
echo "************************************************"
echo "**************** Making Package ****************"
echo "************************************************"
echo
date +"%Y/%m/%d %T - Package" >> $LOGFILE

echo "ln -s $APPROOT $PKGROOT$APPROOT"
ln -s $APPROOT $PKGROOT$APPROOT

echo "hdiutil create -ov -srcfolder $PKGROOT$APPROOT -fs HFS+ -format UDBZ -volname Emacs $BUILDDIR/Emacs-$EMACSVER.dmg"
hdiutil create -ov -srcfolder $PKGROOT$APPROOT -fs HFS+ -format UDBZ -volname Emacs $BUILDDIR/Emacs-$EMACSVER.dmg

echo "xattr -c $BUILDDIR/Emacs-$EMACSVER.dmg"
xattr -c $BUILDDIR/Emacs-$EMACSVER.dmg

date +"%Y/%m/%d %T - Done" >> $LOGFILE

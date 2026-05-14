#!/bin/bash

# DMG Package Builder of Gnu Emacs
#
# Provided under CC0
# https://creativecommons.org/publicdomain/zero/1.0/

set -e -o pipefail

# CONFIGURATIONS start -----------------

# Emacs version
#EMACSVER=29.4
EMACSVER=30.2
#EMACSVER=31.0.50

# nettle version
NETTLEVER=4.0

# GnuTLS version
GNUTLSVER=3.8.13

# tree-sitter version
TREESITVER=0.26.8

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

# Target language grammars
TSGRAMMARS=(
  'bash;https://github.com/tree-sitter/tree-sitter-bash'
  'json;https://github.com/tree-sitter/tree-sitter-json'
  'yaml;https://github.com/tree-sitter-grammars/tree-sitter-yaml'
  'dockerfile;https://github.com/camdencheek/tree-sitter-dockerfile'
#  'c;http://github.com/tree-sitter/tree-sitter-c'
#  'cpp;https://github.com/tree-sitter/tree-sitter-cpp'
#  'javascript;https://github.com/tree-sitter/tree-sitter-javascript'
#  'typescript;https://github.com/tree-sitter/tree-sitter-typescript;typescript'
#  'tsx;https://github.com/tree-sitter/tree-sitter-typescript;tsx'
#  'go;https://github.com/tree-sitter/tree-sitter-go'
#  'python;https://github.com/tree-sitter/tree-sitter-python'
#  'ruby;https://github.com/tree-sitter/tree-sitter-ruby'
)

# Target architectures
ARCHES=(arm64)

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
TREESITSRC=$SRCDIR/tree-sitter-$TREESITVER
GRAMMARSSRC=$SRCDIR/tree-sitter-grammars

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
TREESIT=$BUILDDIR/tree-sitter-$TREESITVER
GRAMMARS=$BUILDDIR/tree-sitter-grammars

# Directories

PKGROOT=$EMACS/pkgroot
APPROOT=/Applications
CTSROOT=$APPROOT/Emacs.app/Contents
PREFIX=$CTSROOT/Resources
EXEPREFIX=$CTSROOT/MacOS
LIBDIR=$EXEPREFIX/lib
GRAMMAR_LIBDIR=$EXEPREFIX/tree-sitter
BUILD_PREFIX=/build-opt
BUILD_INCLUDEDIR=$BUILD_PREFIX/include

LOGFILE=$SCRIPTDIR/build.log

# Options

if [ ${#ARCHES[@]} -gt 1 ]; then
  BUILD_MODE=universal
  ARCH_FLAGS=()
  for arch in ${ARCHES[@]}; do
    ARCH_FLAGS+=("-arch $arch")
  done
elif [ ! ${ARCHES[0]} = `arch` ]; then
  BUILD_MODE=cross
  ARCH_FLAGS=("-arch ${ARCHES[0]}")
else
  BUILD_MODE=
fi

EMACS_CFLAGS="-O2 -DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT"
TREESIT_CFLAGS="-O3 -Wall"

BUILD_CFLAGS=-I$PKGROOT$BUILD_INCLUDEDIR
BUILD_LDFLAGS=-L$PKGROOT$LIBDIR
BUILD_PKG_CONFIG_PATH=$PKGROOT$BUILD_PREFIX/share/pkgconfig

NOFTRS=(x xpm jpeg tiff gif png rsvg webp lcms2 native-compilation)
NOFTR_FLAGS=()
for ftr in ${NOFTRS[@]}; do
  NOFTR_FLAGS+=("--without-$ftr")
done

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

PATCHES=(`find_patches plus` `find_patches original`)
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

make_install_arch () {
  arch=$1

  if [ $arch = ${ARCHES[0]} ]; then
    # Install under $PKGROOT only in the first time (to be the base tree)
    echo "make install DESTDIR=$PKGROOT"
    make install DESTDIR=$PKGROOT
  fi

  if [ "$BUILD_MODE" = "universal" ]; then
    # Install under trees for each architectures (to pick binaries)
    echo "make install DESTDIR=${PKGROOT}_$arch"
    make install DESTDIR=${PKGROOT}_$arch
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

# Clone or pull tree-sitter grammars source repositories -----------------

if [ "$1" = "-n" -o "$1" = "--no-pull" ]; then

  notfound=0
  for spec in ${TSGRAMMARS[@]}; do
    name=${spec%%;*}

    if [ ! -d $GRAMMARSSRC/$name ]; then
      echo >&2 "tree-sitter grammar source for $name not found."
      notfound=1
    fi
  done

  if [ $notfound -ne 0 ]; then
    exit 1
  fi

else

  echo
  echo "**********************************************************************"
  echo "**************** Pulling tree-sitter grammars sources ****************"
  echo "**********************************************************************"
  echo
  date +"%Y/%m/%d %T - Pull" > $LOGFILE

  for spec in ${TSGRAMMARS[@]}; do
    repo=${spec#*;}
    repo=${repo%%;*}
    name=${spec%%;*}

    if [ -d $GRAMMARSSRC/$name ]; then
      echo "cd $GRAMMARSSRC/$name"
      cd $GRAMMARSSRC/$name
      echo "git pull"
      git pull
    else
      if [ ! -d $GRAMMARSSRC ]; then
        echo "mkdir $GRAMMARSSRC"
        mkdir $GRAMMARSSRC
      fi
      echo "cd $GRAMMARSSRC"
      cd $GRAMMARSSRC
      echo "git clone $repo $name"
      git clone $repo $name
    fi
  done

fi

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

if [ "$BUILD_MODE" = "universal" ]; then
  extract_src $NETTLESRC $NETTLE arch
  extract_src $GNUTLSSRC $GNUTLS arch
else
  extract_src $NETTLESRC $NETTLE
  extract_src $GNUTLSSRC $GNUTLS
fi

extract_src $TREESITSRC $TREESIT

if [ -d $GRAMMARS ]; then
  echo "rm -rf $GRAMMARS"
  rm -rf $GRAMMARS
fi

echo "cp -rp $GRAMMARSSRC $GRAMMARS"
cp -rp $GRAMMARSSRC $GRAMMARS

# Build required libraries to include into the package -----------------

echo
echo "*************************************************"
echo "**************** Building nettle ****************"
echo "*************************************************"

for arch in ${ARCHES[@]}; do
  if [ "$BUILD_MODE" = "universal" ]; then
    echo
    echo "================ Target arch: $arch ================"
    echo
    date +"%Y/%m/%d %T - nettle/$arch" >> $LOGFILE

    # Build by each architectures and concat, due to existence of assembly codes
    echo "cd ${NETTLE}_$arch"
    cd ${NETTLE}_$arch
  else
    echo
    date +"%Y/%m/%d %T - nettle" >> $LOGFILE

    echo "cd ${NETTLE}"
    cd ${NETTLE}
  fi

  (
    echo
    echo "---- Entering subshell ----"
    echo
    if [ -n "$BUILD_MODE" ]; then
      echo "export CFLAGS=\"-arch $arch\""
      echo "export LDFLAGS=\"-arch $arch\""
      export CFLAGS="-arch $arch"
      export LDFLAGS="-arch $arch"
    fi
    echo "export PKG_CONFIG_PATH=$BUILD_PKG_CONFIG_PATH"
    export PKG_CONFIG_PATH=$BUILD_PKG_CONFIG_PATH

    if [ -n "$BUILD_MODE" ]; then
      echo "arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --disable-static --enable-mini-gmp --disable-documentation"
      arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --disable-static --enable-mini-gmp --disable-documentation
    else
      echo "./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --disable-static --enable-mini-gmp --disable-documentation"
      ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --disable-static --enable-mini-gmp --disable-documentation
    fi

    echo
    echo "---- Exiting subshell ----"
    echo
  )

  # Adjust install_name to be relative to @rpath for bundled libraries
  echo "make -j$CORES libdir=@rpath"
  make -j$CORES libdir=@rpath

  make_install_arch $arch
done

if [ "$BUILD_MODE" = "universal" ]; then
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

for arch in ${ARCHES[@]}; do
  if [ "$BUILD_MODE" = "universal" ]; then
    echo
    echo "================ Target arch: $arch ================"
    echo
    date +"%Y/%m/%d %T - GnuTLS/$arch" >> $LOGFILE

    # Build by each architectures and concat, due to existence of assembly codes
    echo "cd ${GNUTLS}_$arch"
    cd ${GNUTLS}_$arch
  else
    echo
    date +"%Y/%m/%d %T - GnuTLS" >> $LOGFILE

    echo "cd ${GNUTLS}"
    cd ${GNUTLS}
  fi

  (
    echo
    echo "---- Entering subshell ----"
    echo
    if [ -n "$BUILD_MODE" ]; then
      echo "export CFLAGS=\"-arch $arch\""
      echo "export LDFLAGS=\"-arch $arch\""
      export CFLAGS="-arch $arch"
      export LDFLAGS="-arch $arch"
    fi
    echo "export NETTLE_CFLAGS=\"$BUILD_CFLAGS\""
    echo "export NETTLE_LIBS=\"$BUILD_LDFLAGS -lnettle\""
    echo "export HOGWEED_CFLAGS=\"$BUILD_CFLAGS\""
    echo "export HOGWEED_LIBS=\"$BUILD_LDFLAGS -lhogweed\""
    echo "export PKG_CONFIG_PATH=$BUILD_PKG_CONFIG_PATH"
    export NETTLE_CFLAGS="$BUILD_CFLAGS"
    export NETTLE_LIBS="$BUILD_LDFLAGS -lnettle"
    export HOGWEED_CFLAGS="$BUILD_CFLAGS"
    export HOGWEED_LIBS="$BUILD_LDFLAGS -lhogweed"
    export PKG_CONFIG_PATH=$BUILD_PKG_CONFIG_PATH

    if [ -n "$BUILD_MODE" ]; then
      echo "arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --with-nettle-mini --with-included-libtasn1 --with-included-unistring --without-p11-kit --without-zstd --without-brotli --disable-cxx --disable-static --disable-tools --disable-doc"
      arch -$arch ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --with-nettle-mini --with-included-libtasn1 --with-included-unistring --without-p11-kit --without-zstd --without-brotli --disable-cxx --disable-static --disable-tools --disable-doc
    else
      echo "./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --with-nettle-mini --with-included-libtasn1 --with-included-unistring --without-p11-kit --without-zstd --without-brotli --disable-cxx --disable-static --disable-tools --disable-doc"
      ./configure --prefix=$BUILD_PREFIX --libdir=$LIBDIR --with-nettle-mini --with-included-libtasn1 --with-included-unistring --without-p11-kit --without-zstd --without-brotli --disable-cxx --disable-static --disable-tools --disable-doc
    fi

    echo
    echo "---- Exiting subshell ----"
    echo
  )

  # Adjust install_name to be relative to @rpath for bundled libraries
  # xxx libtool requires absolute libdir, so "make libdir=@rpath" will not work
  echo "sed -e '/-install_name/s/\\\\\\$rpath/@rpath/' -i '' libtool"
  sed -e '/-install_name/s/\\\$rpath/@rpath/' -i '' libtool

  echo "make -j$CORES"
  make -j$CORES

  make_install_arch $arch
done

if [ "$BUILD_MODE" = "universal" ]; then
  echo
  echo "================ Creating universal binaries ================"
  echo
  date +"%Y/%m/%d %T - GnuTLS/lipo" >> $LOGFILE

  gen_univ_binaries
fi

echo
echo "******************************************************"
echo "**************** Building tree-sitter ****************"
echo "******************************************************"
echo
date +"%Y/%m/%d %T - tree-sitter" >> $LOGFILE

echo "cd $TREESIT"
cd $TREESIT

(
  echo
  echo "---- Entering subshell ----"
  echo
  if [ -n "$BUILD_MODE" ]; then
    echo "export CFLAGS=\"${ARCH_FLAGS[*]} $TREESIT_CFLAGS\""
    echo "export LDFLAGS=\"${ARCH_FLAGS[*]}\""
    export CFLAGS="${ARCH_FLAGS[*]} $TREESIT_CFLAGS"
    export LDFLAGS="${ARCH_FLAGS[*]}"
  else
    echo "export CFLAGS=\"$TREESIT_CFLAGS\""
    export CFLAGS="$TREESIT_CFLAGS"
  fi
  echo "export PREFIX=$BUILD_PREFIX"
  echo "export LIBDIR=$LIBDIR"
  export PREFIX=$BUILD_PREFIX
  export LIBDIR=$LIBDIR

  echo "make tree-sitter.pc"
  make tree-sitter.pc

  # Adjust install_name to be relative to @rpath for bundled libraries
  echo "make -j$CORES LIBDIR=@rpath"
  make -j$CORES LIBDIR=@rpath

  echo "make install DESTDIR=$PKGROOT"
  make install DESTDIR=$PKGROOT
  echo
  echo "---- Exiting subshell ----"
)

# Build builtin language grammar modules for tree-sitter -----------------

echo
echo "***************************************************************"
echo "**************** Building tree-sitter grammars ****************"
echo "***************************************************************"

for spec in ${TSGRAMMARS[@]}; do
  repo=${spec#*;}
  name=${spec%%;*}
  case $repo in
  *\;*)
    subdir=${repo#*;}
    ;;
  *)
    subdir=
    ;;
  esac

  echo
  echo "================ $name ================"
  echo
  date +"%Y/%m/%d %T - tree-sitter-grammar/$name" >> $LOGFILE

  if [ -n "$subdir" ]; then
    echo "cd $GRAMMARSSRC/$name/$subdir"
    cd $GRAMMARSSRC/$name/$subdir
  else
    echo "cd $GRAMMARSSRC/$name"
    cd $GRAMMARSSRC/$name
  fi
  echo "make clean"
  make clean

  (
    echo
    echo "---- Entering subshell ----"
    echo
    if [ -n "$BUILD_MODE" ]; then
      echo "export CFLAGS=\"${ARCH_FLAGS[*]} $BUILD_CFLAGS\""
      echo "export LDFLAGS=\"${ARCH_FLAGS[*]} $BUILD_LDFLAGS\""
      export CFLAGS="${ARCH_FLAGS[*]} $BUILD_CFLAGS"
      export LDFLAGS="${ARCH_FLAGS[*]} $BUILD_LDFLAGS"
    else
      echo "export CFLAGS=\"$BUILD_CFLAGS\""
      echo "export LDFLAGS=\"$BUILD_LDFLAGS\""
      export CFLAGS="$BUILD_CFLAGS"
      export LDFLAGS="$BUILD_LDFLAGS"
    fi
    echo "export LIBDIR=$GRAMMAR_LIBDIR"
    export LIBDIR=$GRAMMAR_LIBDIR

    # Adjust install_name to be relative to @rpath for bundled libraries
    echo "make -j$CORES LIBDIR=@rpath SOEXTVER=dylib"
    make -j$CORES LIBDIR=@rpath SOEXTVER=dylib

    echo "install -d $PKGROOT$GRAMMAR_LIBDIR"
    install -d $PKGROOT$GRAMMAR_LIBDIR
    echo "install -m644 libtree-sitter-$name.dylib $PKGROOT$GRAMMAR_LIBDIR/libtree-sitter-$name.dylib"
    install -m644 libtree-sitter-$name.dylib $PKGROOT$GRAMMAR_LIBDIR/libtree-sitter-$name.dylib
    echo
    echo "---- Exiting subshell ----"
  )
done

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

(
  echo
  echo "---- Entering subshell ----"
  echo
  # Set LC_RPATH to @executable_path/lib via LDFLAGS for bundled libraries
  if [ -n "$BUILD_MODE" ]; then
    echo "export CFLAGS=\"${ARCH_FLAGS[*]} $EMACS_CFLAGS\""
    echo "export LDFLAGS=\"${ARCH_FLAGS[*]} -Wl,-rpath,@executable_path/lib\""
    export CFLAGS="${ARCH_FLAGS[*]} $EMACS_CFLAGS"
    export LDFLAGS="${ARCH_FLAGS[*]} -Wl,-rpath,@executable_path/lib"
  else
    echo "export CFLAGS=\"$EMACS_CFLAGS\""
    echo "export LDFLAGS=\"-Wl,-rpath,@executable_path/lib\""
    export CFLAGS="$EMACS_CFLAGS"
    export LDFLAGS="-Wl,-rpath,@executable_path/lib"
  fi
  echo "export LIBGNUTLS_CFLAGS=\"$BUILD_CFLAGS\""
  echo "export LIBGNUTLS_LIBS=\"$BUILD_LDFLAGS -lgnutls\""
  echo "export TREE_SITTER_CFLAGS=\"$BUILD_CFLAGS\""
  echo "export TREE_SITTER_LIBS=\"$BUILD_LDFLAGS -ltreesit\""
  echo "export PKG_CONFIG_PATH=$BUILD_PKG_CONFIG_PATH"
  export LIBGNUTLS_CFLAGS="$BUILD_CFLAGS"
  export LIBGNUTLS_LIBS="$BUILD_LDFLAGS -lgnutls"
  export TREE_SITTER_CFLAGS="$BUILD_CFLAGS"
  export TREE_SITTER_LIBS="$BUILD_LDFLAGS -ltree-sitter"
  export PKG_CONFIG_PATH=$BUILD_PKG_CONFIG_PATH

  echo "./configure --with-ns --with-modules ${NOFTR_FLAGS[*]} --enable-locallisppath=\"$SITELISP\""
  ./configure --with-ns --with-modules ${NOFTR_FLAGS[*]} --enable-locallisppath="$SITELISP"
  echo
  echo "---- Exiting subshell ----"
  echo
)

# Bundles libraries are to be shown under src/lib while dumping emacs
echo "ln -s $PKGROOT$LIBDIR src/lib"
ln -s $PKGROOT$LIBDIR src/lib

echo "make -j$CORES"
make -j$CORES

echo "make install"
make install

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

# Move unnecessary pkgconfig
if [ ! -d $PKGROOT$BUILD_PREFIX/share ]; then
  echo "mkdir $PKGROOT$BUILD_PREFIX/share"
  mkdir $PKGROOT$BUILD_PREFIX/share
fi
echo "mv $PKGROOT$LIBDIR/pkgconfig $PKGROOT$BUILD_PREFIX/share"
mv $PKGROOT$LIBDIR/pkgconfig $PKGROOT$BUILD_PREFIX/share

# Remove library symlinks, static libraries and library stabs
dylibs=()
for file in $PKGROOT$LIBDIR/*; do
  if [ -L $file ]; then
    echo "rm -f $file"
    rm -f $file
  else
    case $file in
    *.a|*.la)
      echo "rm -f $file"
      rm -f $file
      ;;
    *.dylib)
      dylibs+=($file)
      ;;
    esac
  fi
done

# Adjust filenaes and permissions of libraries
for file in "${dylibs[@]}"; do
  iname=`otool -D $file | grep @rpath | uniq`
  ifile=$PKGROOT$LIBDIR/${iname#*/}
  if [ ! $file = $ifile ]; then
    echo "mv $file $ifile"
    mv $file $ifile
  fi
  if [ -x $ifile ]; then
    echo "chmod 644 $ifile"
    chmod 644 $ifile
  fi
done

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

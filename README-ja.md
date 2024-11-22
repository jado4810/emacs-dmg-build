emacs-dmg-build: Gnu Emacs DMGパッケージビルダー
================================================

[![Emacs 29 Ready](https://img.shields.io/badge/Emacs29-Ready-green?style=flag&logo=gnuemacs&logoColor=white&labelColor=7F5AB6)](./releases/tags/v29.4)
![macOS15 Ready](https://img.shields.io/badge/macOS15-Ready-green?style=flat&logo=apple&logoColor=white&labelColor=black)
![Intel Universal Binary](https://img.shields.io/badge/Universal_Binary-0071C5?style=flat&logo=intel&logoColor=white&logoSize=auto)
![arm Universal Binary](https://img.shields.io/badge/Universal_Binary-0091BD?style=flat&logo=arm&logoColor=white&logoSize=auto)

[EN](./README.md)|JA

概要
----

Gnu EmacsのmacOS向けdmgパッケージを作成するビルドスクリプトです。
Apple Silicon環境では、ユニバーサルバイナリーを作成できます。

SSL/TLS接続用に、GnuTLSのランタイムを同梱しており、外部ライブラリーに依存せずに動作します。
画像については、ns GUIの標準機能で対応します。

[Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus)のパッチをいくつか適用しています。
また、CJK環境で有用な[インラインパッチ](https://github.com/takaxp/ns-inline-patch)も選択可能です。

使い方
------

### 1\. ソースの取得

以下を取得して`sources`以下に格納してください。
`.tar.gz`・`.tar.xz`どちらの形式でも自動認識します。

* Gnu Emacs本体のソース

  Gnuミラー ( https://ftpmirror.gnu.org/emacs/ ) からダウンロードできます。

* nettleのソース

  GnuTLSに必須となる、暗号アルゴリズムの実装です。

  Gnuミラー ( https://ftpmirror.gnu.org/nettle/ ) からダウンロードできます。

* GnuTLSのソース

  SSL/TLSの実装です。
  EmacsはmacOS標準のOpenSSLではなく、GnuTLSが必要です。

  公式サイト ( https://www.gnutls.org/download.html ) からダウンロードできます。

* Emacs MacPortが採用している高解像アイコン

  `USEHRICON=yes`を設定した場合のみ必要です。
  この場合、アプリケーションアイコンとツールバーアイコンをこれに置き換えます。

  MacPortパッチを配布している千葉大のFTPサーバー ( ftp://ftp.math.s.chiba-u.ac.jp/emacs/ ) からダウンロードできます。

> [!NOTE]
>
> #### バージョンについて
>
> ビルドスクリプト中に指定したバージョンのものは動作確認済みですが、特に依存ライブラリーについては、それより新しいものでもおそらく動作します。
> その場合、ビルドスクリプト中の指定を取得したバージョンに合わせてください。

### 2\. ビルド環境の設定

ビルドスクリプト ( `emacs-dmg-build.sh` ) を編集し、先頭付近の以下の設定値を修正してください。

* 各ソース等のバージョン

  `EMACSVER`・`NETTLEVER`・`GNUTLSVER`・`HRICONVER`の値を、実際に取得したものと一致するようにしてください。

* site-lispの格納先パス

  システムワイドで有効なlispの格納先であるsite-lispのパスを`SITELISP`に設定してください。

  デフォルトでは`/Library/Application Support/Emacs/site-lisp`で、このようなパッケージ外の場所を推奨します。

* インラインパッチを使用するか

  Ishikawa Takaaki氏が https://github.com/takaxp/ns-inline-patch で取りまとめているインラインパッチを適用する場合は、`USEINLINE`に`yes`を設定してください。

  最近のEmacsは、そのままでもOSのインプットメソッドでインライン入力が可能となっていますが、`toggle-input-method`による入力モード変更や、入力モード変更時のフックといった有用な機能が使えますので、必要であれば適用してください。

* 高解像アイコンを使用するか

  Emacs MacPortが採用している高解像アイコン(emacs-hires-icons)を使用する場合は、`USEHRICON`に`yes`を設定してください。

  有効にすると、アプリケーションアイコンとツールバーアイコンに、当該アイコンセットの画像を使用します。
  スプラッシュ画像については、現在Emacsが採用しているSVG画像を優先するため、ここで提供されている画像は使用しません。

* アプリケーションアイコンを置き換えるか

  別途用意したアプリケーションアイコンを用いる場合は、`USEAPPICON`に`yes`を設定してください。

  EmacsPlusでは、オプションで指定可能なアイコン群を取りまとめていますが、このようなアイコンを使用する場合に有用です。
  有効にした場合、`Emacs.icns`・`document.icns`があればemacs-hires-iconsよりも優先してこちらを使用します。

* スプラッシュ画像を置き換えるか

  別途用意したスプラッシュ画像を用いる場合は、`USESPLASH`に`yes`を設定してください。

  有効にした場合、`splash.png`・`splash.xpm`・`splash.pbm`があればこちらを使用します。
  また、この場合標準のSVGスプラッシュ画像は無効化されます。

  macOS環境では事実上PNG画像しか使われないと思われますが、仮に色数が少ない表示環境で起動した場合はXPM画像やPBM画像が使われるかもしれません。

* ビルド対象のアーキテクチャー

  対応するアーキテクチャーを`ARCHES`に配列として設定してください。
  デフォルトでは、arm64とx86_64のユニバーサルバイナリーをビルドする設定となっています。

  Intel環境ではarm64のビルドができないため、`ARCHES=(x86_64)`とする必要があります。

  > [!NOTE]
  >
  > Apple Silicon専用バイナリーとする場合は`ARCHES=(arm64)`としてください。
  > これによって、インストールサイズを若干節約できますが、Emacsの場合フットプリントの大半がlispやpdumpであることから、他のアプリケーションほど容量への影響はありません。

* ビルド時に使用するコア数

  ビルド時の並列処理数を`CORES`に設定してください。
  この値は、makeの`-j`オプションの引数となります。

  デフォルト値は4です。
  最近のmac環境では概ねこれで問題ありません。

  > [!NOTE]
  >
  > パフォーマンスコアの数が4より多い場合は、その数に合わせると若干ビルド時間の短縮が可能です。
  > ただ、ビルド時間の大半はGnuTLSクロスコンパイル時のconfigureとなっている状況であることから、ほぼ誤差の範囲ではないかと思われます。

### 3\. カスタム画像の格納

`USEAPPICON`あるいは`USESPLASH`を`yes`に設定した場合、対応する画像データを`custom-images`以下に格納してください。
いずれも、格納したファイルのみを置き換えるため、全てを格納する必要はありません。

* `USEAPPICON=yes`を設定した場合

  `Emacs.icns`・`document.icns`

* `USESPLASH=yes`を設定した場合

  `splash.png`・`splash.xpm`・`splash.pbm`

### 4\. 必要なツールの準備

ビルドに必要なツールがインストールされていない場合は適宜インストールしてください。
これらはビルド時のみに用いられ、作成されるdmgパッケージからの依存は発生しません。

* コンパイラー環境(make・clang/gcc・ld)

  Xcodeのコマンドラインツールをインストールしてください。

  ```console
  $ xcode-select --install
  ```

* Texinfo

  homebrew等でインストールしてください。

  ```console
  $ brew install texinfo
  ```

* Automake

  `USEINLINE=yes`を設定した場合のみ必要です。
  homebrew等でインストールしてください。

  ```console
  $ brew install automake
  ```

### 5\. ビルドスクリプトを実行

ビルドスクリプトを実行すると、`build`以下にdmgパッケージを生成します。
Apple M3の環境で10分程度かかります。

```console
$ ./emacs-dmg-build.sh
```

`build`以下にはソースパッケージが展開されているが、不要であれば削除しても構いません。

ライセンス
----------

本スクリプトと[patch/custom](./patch/custom)以下のパッチについては[CC0](./LICENSE.txt)で配布します。

[patch/plus](./patch/plus)および[patch/inline](./patch/inline)以下に収録している外部パッチのライセンスは、以下の配布元を参照ください。

### 同梱しているパッチの配布元

* homebrew-emacs-plus

  https://github.com/d12frosted/homebrew-emacs-plus

* ns-inline-patch

  https://github.com/takaxp/ns-inline-patch

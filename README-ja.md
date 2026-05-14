emacs-dmg-build: Gnu Emacs DMGパッケージビルダー
================================================

[![Emacs 30 Ready](https://img.shields.io/badge/Emacs30-Ready-green?style=flag&logo=gnuemacs&logoColor=white&labelColor=7F5AB6)](https://github.com/jado4810/emacs-dmg-build/releases/tag/30.2)
[![Emacs 29 Ready](https://img.shields.io/badge/Emacs29-Ready-green?style=flag&logo=gnuemacs&logoColor=white&labelColor=7F5AB6)](https://github.com/jado4810/emacs-dmg-build/releases/tag/29.4)
[![macOS26 Ready](https://img.shields.io/badge/macOS26-Ready-green?style=flat&logo=apple&logoColor=white&labelColor=black)](https://www.apple.com/macos/)
[![Intel Universal Binary](https://img.shields.io/badge/Universal_Binary-0071C5?style=flat&logo=intel&logoColor=white&logoSize=auto)](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
[![arm Universal Binary](https://img.shields.io/badge/Universal_Binary-0091BD?style=flat&logo=arm&logoColor=white&logoSize=auto)](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)

[EN](./README.md)|JA

概要
----

Gnu EmacsのmacOS向けdmgパッケージを作成するビルドスクリプトです。
macOS26 Tahoe以前のApple Silicon環境では、ユニバーサルバイナリーを作成できます。

Emacs29以降で標準となったtreesitに対応しており、いくつかの言語文法規則を同梱しています。
また、SSL/TLS接続用に、GnuTLSのランタイムを同梱しており、外部ライブラリーに依存せずに動作します。
画像については、ns GUIの標準機能で対応します。

[Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus)のパッチをいくつか適用しています。
また、CJK環境で有用な[インラインパッチ](https://github.com/takaxp/ns-inline-patch)も選択可能です。

加えて、[Emacs MacPort](https://bitbucket.org/mituharu/emacs-mac)が採用している高解像度アイコンも利用できます。

使い方
------

### 1\. ソースの取得

以下を取得して`sources`以下に格納してください。
`.tar.gz`・`.tar.xz`どちらの形式でも自動認識します。

#### a. Gnu Emacs本体のソース

Gnuミラー([https://ftpmirror.gnu.org/emacs/](https://ftpmirror.gnu.org/emacs/))からダウンロードできます。

#### b. nettleのソース

GnuTLSに必須となる、暗号アルゴリズムの実装です。

Gnuミラー([https://ftpmirror.gnu.org/nettle/](https://ftpmirror.gnu.org/nettle/))からダウンロードできます。

#### c. GnuTLSのソース

SSL/TLSの実装です。
EmacsはmacOS標準のOpenSSLではなく、GnuTLSが必要です。

公式サイト([https://www.gnutls.org/download.html](https://www.gnutls.org/download.html))からダウンロードできます。

> [!NOTE]
>
> ビルドスクリプト中に指定したバージョンのものは動作確認済みですが、特に依存ライブラリーについては、それより新しいものでもおそらく動作します。
> その場合、ビルドスクリプト中の指定を取得したバージョンに合わせてください。

#### d. tree-sitterのソース

treesitが用いる構文解析アルゴリズムの実装です。

GitHubプロジェクトのリリースページ([https://github.com/tree-sitter/tree-sitter/releases](https://github.com/tree-sitter/tree-sitter/releases))からダウンロードできます。

> [!NOTE]
>
> 文法規則のソースは、必要なものをgitで自動的に取得します。

### 2\. ビルド環境の設定

ビルドスクリプト(`emacs-dmg-build.sh`)を編集し、先頭付近の以下の設定値を修正してください。

#### a. 各ソース等のバージョン

`EMACSVER`・`NETTLEVER`・`GNUTLSVER`・`TREESITVER`の値を、実際に取得したものと一致するようにしてください。

#### b. site-lispの格納先パス

システムワイドで有効なlispの格納先であるsite-lispのパスを`SITELISP`に設定してください。

デフォルトでは`/Library/Application Support/Emacs/site-lisp`で、このようなパッケージ外の場所を推奨します。

#### c. インラインパッチを使用するか

Ishikawa Takaaki氏が[https://github.com/takaxp/ns-inline-patch](https://github.com/takaxp/ns-inline-patch)で取りまとめているインラインパッチを適用する場合は、`USEINLINE`に`yes`を設定してください。

最近のEmacsは、そのままでもOSのインプットメソッドでインライン入力が可能となっていますが、`toggle-input-method`による入力モード変更や、入力モード変更時のフックといった有用な機能が使えますので、必要であれば適用してください。

#### d. 高解像アイコンを使用するか

Emacs MacPortが採用している高解像アイコンを使用する場合は、`USEHRICON`に`yes`を設定してください。

有効にすると、アプリケーションアイコンとツールバーアイコンに、当該アイコンセットの画像を使用します。

#### e. アプリケーションアイコンを置き換えるか

別途用意したアプリケーションアイコンを用いる場合は、`USEAPPICON`に`yes`を設定してください。

EmacsPlusでは、オプションで指定可能なアイコン群を取りまとめていますが、このようなアイコンを使用する場合に有用です。
有効にした場合、`Emacs.icns`・`document.icns`があればEmacs MacPort由来のものよりも優先してこちらを使用します。

#### f. スプラッシュ画像を置き換えるか

別途用意したスプラッシュ画像を用いる場合は、`USESPLASH`に`yes`を設定してください。

有効にした場合、`splash.png`・`splash.xpm`・`splash.pbm`があればこちらを使用します。
また、この場合標準のSVGスプラッシュ画像は無効化されます。

macOS環境では事実上PNG画像しか使われないと思われますが、仮に色数が少ない表示環境で起動した場合はXPM画像やPBM画像が使われるかもしれません。

#### g. 組み込む文法規則

treesit用に組み込む言語の文法規則の言語と取得元の情報を`TSGRAMMARS`に設定してください。

デフォルトでは、Emacs30で動作確認が取れている言語を指定しています。
適宜取捨選択してください。

書式は以下のとおりです。
取得したリポジトリーのサブディレクトリーでビルドする場合、3番目の要素を定義してください。

```bash
'言語名;取得元GitリポジトリーURL[;サブディレクトリー]'
```

#### h. ビルド対象のアーキテクチャー

対応するアーキテクチャーを`ARCHES`に配列として設定してください。
デフォルトは`ARCHES=(arm64)`で、Apple Siliconの単一バイナリーをビルドする設定となっています。
Intel環境では`ARCHES=(x86_64)`としてください。

macOS26 Tahoe以前のApple Silicon環境では、`ARCHES=(arm64 x86_64)`とするとユニバーサルバイナリーをビルドすることができます。
また、`ARCHES=(x86_64)`とすることで、Intel向けバイナリーをクロスビルドすることもできます。

#### i. ビルド時に使用するコア数

ビルド時の並列処理数を`CORES`に設定してください。
この値は、makeの`-j`オプションの引数となります。

デフォルト値は4です。
最近のmac環境では概ねこれで問題ありません。

> [!NOTE]
>
> パフォーマンスコアの数が4より多い場合は、その数に合わせると若干ビルド時間の短縮が可能です。
> ただ、ビルド時間の過半数はconfigureが費やしている状況であることから、ほぼ誤差の範囲ではないかと思われます。

### 3\. カスタム画像の格納

`USEAPPICON`あるいは`USESPLASH`を`yes`に設定した場合、対応する画像データを`custom-images`以下に格納してください。
いずれも、格納したファイルのみを置き換えるため、全てを格納する必要はありません。

* `USEAPPICON=yes`を設定した場合 … `Emacs.icns`・`document.icns`
* `USESPLASH=yes`を設定した場合 … `splash.png`・`splash.xpm`・`splash.pbm`

### 4\. 必要なツールの準備

ビルドに必要なツールがインストールされていない場合は適宜インストールしてください。
これらはビルド時のみに用いられ、作成されるdmgパッケージからの依存は発生しません。

#### a. コンパイラー環境(make・clang/gcc・ld)

Xcodeのコマンドラインツールをインストールしてください。

```console
$ xcode-select --install
```

#### b. Texinfo

homebrew等でインストールしてください。

```console
$ brew install texinfo
```

#### c. Automake

`USEINLINE=yes`を設定した場合のみ必要です。
homebrew等でインストールしてください。

```console
$ brew install automake
```

#### d. pkgconf

GnuTLS-3.8.9以降で必要です。
homebrew等でインストールしてください。

``` console
$ brew install pkgconf
```

### 5\. ビルドスクリプトを実行

ビルドスクリプトを実行すると、`build`以下にdmgパッケージを生成します。

まず、treesitの文法規則のソースを取得します。
取得済みの場合 git pull で最新への更新を行いますが、更新が不要な場合は`-n`を追加してください。

文法規則のソース取得、更新を除くと、Apple M5の環境で3分程度かかります。
ユニバーサルバイナリーの場合、6分程度となります。

```console
$ sh emacs-dmg-build.sh [-n]
```

`build`以下にはソースパッケージが展開されていますが、不要であれば削除しても構いません。

ライセンス
----------

本スクリプトと[patches/custom](./patches/custom)以下のパッチについては[CC0](./LICENSE.txt)で配布します。

[patches/plus](./patches/plus)および[patches/inline](./patches/inline)以下のパッチや、[icons](./icons)以下のアイコンデータは、異なるライセンス条件で配布されているものを収録したものです。
詳細は各ディレクトリー以下のLICENSEファイルもしくはREADMEファイルを参照ください。

### 同梱しているリソースの配布元

* Emacs Plus … https://github.com/d12frosted/homebrew-emacs-plus
* ns-inline-patch … https://github.com/takaxp/ns-inline-patch
* Emacs MacPort … https://bitbucket.org/mituharu/emacs-mac

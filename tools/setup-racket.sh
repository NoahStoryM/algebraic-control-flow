#!/bin/sh
# 在 AI 的临时环境里装好最新版 Racket，并把本仓库装成包 acf。
#
# 前提：会话里挂着 NoahStoryM/racket-dist（安装包放在它的 Release 上），gh 已登录。
# 这类环境连不上 Racket 的下载站和包目录，所以：
#   - Racket 用完整版安装包（自带 Scribble、Typed Racket 和带交叉引用数据的文档）；
#   - control-context、amb 从 GitHub 克隆后以链接方式安装。
#
# 用法：sh tools/setup-racket.sh            # 默认版本见 VERSION
#       VERSION=9.3 sh tools/setup-racket.sh
# 装好后照最后打印的那行设 PATH。
set -eu

VERSION=${VERSION:-9.3}
DIST_REPO=NoahStoryM/racket-dist
PREFIX=${PREFIX:-/opt/racket-$VERSION}
DEPS_DIR=${DEPS_DIR:-$HOME/racket-deps}
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export LC_ALL=C.UTF-8

if [ ! -x "$PREFIX/bin/racket" ]; then
  # 草稿 Release 与 gh release download（走 GraphQL）在这类会话里都不可用，用 REST 接口按附件 id 下载。
  ASSET=$(gh api "repos/$DIST_REPO/releases/tags/v$VERSION" \
            --jq '.assets[] | select(.name | test("x86_64-linux.*-cs[.]sh$")) | .id' | head -n 1)
  [ -n "$ASSET" ] || { echo "v$VERSION 的 Release 里没有 x86_64 Linux CS 安装包" >&2; exit 1; }
  echo "下载 Racket $VERSION（附件 $ASSET）"
  gh api -H 'Accept: application/octet-stream' "repos/$DIST_REPO/releases/assets/$ASSET" > "$TMP/racket.sh"
  sh "$TMP/racket.sh" --in-place --dest "$PREFIX" < /dev/null
fi
PATH=$PREFIX/bin:$PATH
racket --version

mkdir -p "$DEPS_DIR"
for repo in control-context amb; do
  [ -d "$DEPS_DIR/$repo/.git" ] || git clone -q --depth 1 "https://github.com/NoahStoryM/$repo" "$DEPS_DIR/$repo"
done
raco pkg install --user --auto --skip-installed --link \
  "$DEPS_DIR/control-context" "$DEPS_DIR/amb/pkgs/amb"

cd "$REPO_DIR"
raco pkg install --user --skip-installed --link --name acf --deps fail

echo
echo "装好了。请在 shell 里设：export PATH=$PREFIX/bin:\$PATH LC_ALL=C.UTF-8"

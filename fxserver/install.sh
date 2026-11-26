#!/bin/bash
# FXServer install: DOWNLOAD_URL (set by the FiveM extension's Artifacts page), else
# FIVEM_VERSION recommended/latest. Fails loudly so the panel offers a retry.
set -Eeuo pipefail

SERVER=/mnt/server
CHANGELOG=https://changelogs-live.fivem.net/api/changelog/versions/linux/server
DEFAULT_RESOURCES=https://github.com/citizenfx/cfx-server-data.git
UA="HostZen-FXServer-Installer/1.0 (+https://hostzen.net)"
WORK=$(mktemp -d)

if [ -z "${NO_COLOR:-}" ]; then
  B=$'\e[1m' D=$'\e[2m' A=$'\e[38;2;59;130;246m' G=$'\e[38;2;34;197;94m' X=$'\e[38;2;239;68;68m' R=$'\e[0m'
else
  B='' D='' A='' G='' X='' R=''
fi
step() { printf '\n%s▸%s %s%s%s\n' "$A" "$R" "$B" "$*" "$R"; }
info() { printf '  %s%s%s\n' "$D" "$*" "$R"; }
ok() { printf '  %s✔%s %s\n' "$G" "$R" "$*"; }
fail() {
  printf '\n%s✖ Install failed:%s %s\n' "$X$B" "$R" "$1" >&2
  [ -n "${2:-}" ] && printf '  %s\n' "$2" >&2
  printf '  %sThe server was left as it was. Fix the above and reinstall to try again.%s\n\n' "$D" "$R" >&2
  exit 1
}
trap 'fail "unexpected error (line $LINENO: $BASH_COMMAND)."' ERR
trap 'rm -rf "$WORK" "$SERVER/.alpine-staging" "$SERVER/alpine.new" "$SERVER/alpine.old"' EXIT

fetch() { curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 20 -A "$UA" "$@"; }

printf '\n  %s%sHOSTZEN%s  FXServer install\n' "$B" "$A" "$R"
cd "$SERVER" || fail "the server folder isn't mounted."

step "Finding the build"
url="${DOWNLOAD_URL:-}"
version="${FIVEM_VERSION:-recommended}"
if [ -n "$url" ]; then
  info "Chosen on the Artifacts page."
elif [ "$version" = "recommended" ] || [ "$version" = "latest" ] || [ -z "$version" ]; then
  version=${version:-recommended}
  changelog=$(fetch "$CHANGELOG") || fail "couldn't reach CFX's version list." "CFX may be down. Try again in a few minutes."
  url=$(jq -r --arg v "$version" '.[$v + "_download"] // empty' <<<"$changelog")
  [ -n "$url" ] || fail "CFX's version list has no $version build." "Try again later, or pick a version on the Artifacts page."
  info "CFX's $version build."
else
  fail "build $version needs its download link." "Pick it on the Artifacts page, which sets the link and reinstalls for you."
fi
[[ "$url" =~ ^https:// ]] || fail "the download link isn't an https:// link: $url"
build=$(grep -oE '/[0-9]+-[0-9a-f]{40}/' <<<"$url" | grep -oE '^/[0-9]+' | tr -d / || true)
ok "FXServer ${build:-build} from ${url%%/artifacts/*}"

step "Downloading"
fetch -o "$WORK/fx.tar.xz" "$url" || fail "the download failed." "CFX may have removed this build. Pick another on the Artifacts page."
info "$(du -h "$WORK/fx.tar.xz" | cut -f1) downloaded."
xz -t "$WORK/fx.tar.xz" 2>/dev/null || fail "the download is damaged or isn't an FXServer build."
tar -tJf "$WORK/fx.tar.xz" alpine/opt/cfx-server/FXServer >/dev/null 2>&1 ||
  fail "the download isn't an FXServer Linux build." "Pick a version on the Artifacts page."
ok "Archive checked."

step "Installing"
# Unpack beside the live build, then swap, so a failure leaves the old build in place.
rm -rf .alpine-staging alpine.new alpine.old
mkdir .alpine-staging
tar -xJf "$WORK/fx.tar.xz" -C .alpine-staging --no-same-owner alpine
mv .alpine-staging/alpine alpine.new
rmdir .alpine-staging
mkdir -p alpine.new/.hostzen
[ -n "$build" ] && printf '%s\n' "$build" >alpine.new/.hostzen/build
[ -d alpine ] && mv alpine alpine.old
mv alpine.new alpine
rm -rf alpine.old run.sh
ok "FXServer ${build:-} installed in alpine/."

txadmin="${TXADMIN_ENABLE:-1}"
if [ "${CFX_DEFAULT_RESOURCES:-0}" = "1" ] || { [ ! -d resources ] && [ "$txadmin" != "1" ]; }; then
  step "Default resources"
  git clone -q --depth 1 "$DEFAULT_RESOURCES" "$WORK/cfx-server-data" ||
    fail "couldn't download CFX's default resources." "GitHub may be down. Try again, or reinstall without them."
  mkdir -p resources
  cp -a "$WORK/cfx-server-data/resources/." resources/
  ok "CFX's default resources copied into resources/."
fi

if [ "$txadmin" != "1" ] && [ ! -f server.cfg ]; then
  step "server.cfg"
  gamename=gta5
  [ "${CFX_GAME:-fivem}" = "redm" ] && gamename=rdr3
  cat >server.cfg <<CFG
# server.cfg: written once by the installer, then yours to edit.
# The panel keeps the ports, hostname and player count in step with the
# server's Startup page.
endpoint_add_tcp "0.0.0.0:30120"
endpoint_add_udp "0.0.0.0:30120"

sv_hostname "${SERVER_HOSTNAME:-My FXServer}"
sets sv_projectName "${SERVER_HOSTNAME:-My FXServer}"
sv_maxclients ${MAX_PLAYERS:-48}
set gamename "$gamename"
set onesync on
sv_enforceGameBuild 3095

ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap

add_ace group.admin command allow
add_ace group.admin command.quit deny
CFG
  ok "server.cfg written."
fi

rmdir logs 2>/dev/null || true

printf '\n%s✔ Install complete.%s FXServer %s is ready to start.\n\n' "$G$B" "$R" "${build:-}"

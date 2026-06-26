#!/bin/bash
set -e

cd "${GITHUB_WORKSPACE}"

echo "::group::Lint PKGBUILD"
namcap PKGBUILD
echo "::endgroup::"

echo "::group::Check .SRCINFO is up to date"
chown builder .
su builder -c "makepkg --printsrcinfo" > /tmp/.SRCINFO.generated
if ! diff -u .SRCINFO /tmp/.SRCINFO.generated; then
  echo "::error::.SRCINFO is out of date — regenerate it with: makepkg --printsrcinfo > .SRCINFO"
  exit 1
fi
echo "::endgroup::"

echo "::group::Build package"
paru -Syu --noconfirm
chown -R builder .
su builder -c "paru -B . --noconfirm --skipreview --noprogressbar --removemake --mflags '--nocheck'"
echo "::endgroup::"

if [ "${GITHUB_EVENT_NAME}" = "push" ] && [ "${GITHUB_REF}" = "refs/heads/main" ]; then
  echo "::group::Create release"
  git config --global --add safe.directory "${GITHUB_WORKSPACE}"
  _ver=$(grep '^pkgver=' PKGBUILD | cut -d= -f2)
  _rel=$(grep '^pkgrel=' PKGBUILD | cut -d= -f2)
  gh release delete "${_ver}-${_rel}" --yes --cleanup-tag 2>/dev/null || true
  gh release create "${_ver}-${_rel}" --title "${_ver}-${_rel}" *.pkg.tar.zst
  echo "::endgroup::"
fi

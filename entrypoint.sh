#!/bin/bash
set -exu # Increase bash strictness
shopt -s globstar # Enable globstar

if [[ -n "${GITHUB_WORKSPACE}" ]]; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

export REVIEWDOG_VERSION=v0.23.3
export RD_URL="https://github.com/reviewdog/reviewdog/releases/download/v0.20.3/reviewdog_0.20.3_Linux_x86_64.tar.gz"
RD_CHECKSUM=2c634dbc00bd4a86e4d4c47029d2af9185fab06643a9df0ae10e7c4d644781b6

echo "[action-pylint] Installing reviewdog ${REVIEWDOG_VERSION}..."
#wget -O - -q https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b /tmp "${REVIEWDOG_VERSION}"
curl -sSL -o /tmp/reviewdog.tar.gz "${RD_URL}"
echo "${RD_CHECKSUM}  /tmp/reviewdog.tar.gz" | sha256sum -c -
tar -xzf /tmp/reviewdog.tar.gz -C /tmp
install /tmp/reviewdog /usr/local/bin/
chmod 755 /usr/local/bin/reviewdog

if [[ "$(which pylint)" == "" ]]; then
  echo "[action-pylint] Installing pylint package..."
  python -m pip install --upgrade pylint
fi
echo "[action-pylint] pylint version:"
pylint --version

rcfile_option=""
if [[ "$INPUT_PYLINT_RC" != "" ]]; then
  rcfile_option="--rcfile=${INPUT_PYLINT_RC}"
fi

echo "[action-pylint] Checking python code with the pylint linter and reviewdog..."
exit_val="0"

pylint --score n ${rcfile_option} ${INPUT_PYLINT_ARGS} ${INPUT_GLOB_PATTERN} 2>&1 | # Removes ansi codes see https://github.com/reviewdog/errorformat/issues/51
  /tmp/reviewdog -efm="%f:%l:%c: %m" \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    -level="${INPUT_LEVEL}" \
    ${INPUT_REVIEWDOG_FLAGS} || exit_val="$?"

echo "[action-pylint] Clean up reviewdog..."
rm /tmp/reviewdog

if [[ "${exit_val}" -ne '0' ]]; then
  exit 1
fi

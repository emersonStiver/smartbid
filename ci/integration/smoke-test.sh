#!/usr/bin/env bash
# Black-box tests against the service started by ci/integration/docker-compose.yml.
# Writes a JUnit report (for the CodeBuild report group) to $1 and exits non-zero if any test fails.
set -uo pipefail

REPORT="${1:-integration-tests.xml}"
BASE_URL="${BASE_URL:-http://localhost:8080}"
MGMT_URL="${MGMT_URL:-http://localhost:8081}"

cases=""
failures=0
total=0

# run_test <name> <command...>
run_test() {
  local name="$1"
  shift
  total=$((total + 1))
  local output
  if output=$("$@" 2>&1); then
    echo "PASS  $name"
    cases+="<testcase classname=\"integration\" name=\"$name\"/>"
  else
    echo "FAIL  $name: $output"
    failures=$((failures + 1))
    cases+="<testcase classname=\"integration\" name=\"$name\"><failure message=\"assertion failed\"><![CDATA[$output]]></failure></testcase>"
  fi
}

# expect_body <url> <expected substring>
expect_body() {
  local body
  body=$(curl -sf --max-time 10 "$1") || { echo "request to $1 failed"; return 1; }
  [[ "$body" == *"$2"* ]] || { echo "expected '$2' in: $body"; return 1; }
}

# expect_status <url> <expected HTTP status>
expect_status() {
  local status
  status=$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "$1")
  [[ "$status" == "$2" ]] || { echo "expected HTTP $2 from $1, got $status"; return 1; }
}

run_test "actuator health is UP" expect_body "$MGMT_URL/actuator/health" '"status":"UP"'
run_test "test endpoint responds" expect_body "$BASE_URL/api/v1/analyzer-service/testEndpoint" "Hello from Analyzer Service"
run_test "unknown path returns 404" expect_status "$BASE_URL/does-not-exist" 404
run_test "actuator is not served on the app port" expect_status "$BASE_URL/actuator/health" 404

cat > "$REPORT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="analyzer-service-integration" tests="$total" failures="$failures">$cases</testsuite>
</testsuites>
EOF

echo "$((total - failures))/$total passed"
[[ "$failures" -eq 0 ]]

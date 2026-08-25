#!/usr/bin/env bash
# Walks the criteria in .scratch/scan-to-recap/issues/05-the-worker.md and
# 10-the-recap.md that need a deployed Worker, a real key and a real Firebase
# user — the ones no test can reach. Everything it prints is either a status code or the field the app would
# read, so what passed and what did not is visible rather than inferred.
#
#   ./verify-deployed.sh https://where-money.<subdomain>.workers.dev receipt.jpg
#
# Two ID tokens, for two different users, in ID_TOKEN and SECOND_ID_TOKEN. Get
# one by signing into the app and printing
# FirebaseAuth.instance.currentUser!.getIdToken(), or from the Firebase Auth
# REST API.

set -uo pipefail

base=${1:-}
image=${2:-}
if [[ -z $base || -z $image ]]; then
  echo "usage: $0 <worker base url> <receipt image>" >&2
  exit 2
fi
if [[ ! -f $image ]]; then
  echo "no such image: $image" >&2
  exit 2
fi

if [[ -z ${ID_TOKEN:-} ]]; then
  read -rsp "Firebase ID token: " ID_TOKEN && echo
fi
if [[ -z ${SECOND_ID_TOKEN:-} ]]; then
  read -rsp "A second user's ID token (blank to skip that check): " SECOND_ID_TOKEN && echo
fi

# Git Bash on Windows has `python` and a python3 shim that only offers to
# install one, so ask which actually runs.
py=python3
$py -c 'pass' 2>/dev/null || py=python
encoded=$(mktemp)
trap 'rm -f "$encoded"' EXIT
base64 -w0 "$image" >"$encoded" 2>/dev/null || base64 -i "$image" | tr -d '\n' >"$encoded"
echo "image: $(wc -c <"$encoded" | tr -d ' ') characters of base64"
echo

# Prints the status, then the body, of one Scan. Extra query is appended.
scan() {
  local token=$1 query=${2:-}
  curl -sS -o /tmp/where-money-scan.json -w '%{http_code}' \
    -X POST "$base/extract$query" \
    -H "authorization: Bearer $token" \
    -H 'content-type: text/plain' \
    --data-binary "@$encoded"
}

step() { printf '\n== %s\n' "$1"; }

step 'deployed and reachable'
curl -sS -w ' <- %{http_code}\n' "$base/health"

step 'a request with no token is refused'
curl -sS -w ' <- %{http_code}\n' -X POST "$base/extract" \
  -H 'content-type: text/plain' --data-binary "@$encoded"

step 'a malformed token is refused differently'
curl -sS -w ' <- %{http_code}\n' -X POST "$base/extract" \
  -H 'authorization: Bearer not.a.token' \
  -H 'content-type: text/plain' --data-binary "@$encoded"

step 'an expired token is refused as its own reason'
echo 'Sign in, wait an hour without refreshing, and rerun the line above with'
echo 'that token: the reason should read "expired" rather than "malformed".'

step 'a real receipt comes back read'
status=$(scan "$ID_TOKEN")
echo "status: $status"
$py - <<'PY' || cat /tmp/where-money-scan.json
import json
body = json.load(open('/tmp/where-money-scan.json'))
if body.get('error') or body.get('status') is None:
    print('failed:', json.dumps(body)[:400])
    raise SystemExit
text = next(
    (c['text'] for item in body.get('output', []) if item.get('type') == 'message'
     for c in item.get('content', []) if c.get('type') == 'output_text'),
    None,
)
print('status:', body.get('status'), 'model:', body.get('model'))
print('usage:', body.get('usage'))
if text is None:
    print('no output_text — refusal or incomplete. The app has a state for each.')
else:
    read = json.loads(text)
    print('merchant:', read['merchant'])
    print('total:', read['total'], read['currency'])
    print('date:', read['purchased_at'])
    print('line items:', len(read['line_items']))
PY

step 'the counter increments, and the cap has a status of its own'
echo "first with cap=1:  $(scan "$ID_TOKEN" '?cap=1')"
echo "second with cap=1: $(scan "$ID_TOKEN" '?cap=1')  <- expect 429"
cat /tmp/where-money-scan.json
echo

step 'a second user has their own counter'
if [[ -n ${SECOND_ID_TOKEN:-} ]]; then
  echo "the other user, still capped at 1: $(scan "$SECOND_ID_TOKEN" '?cap=1')  <- expect 200"
else
  echo 'skipped: no SECOND_ID_TOKEN'
fi

step 'a client-supplied model is ignored'
echo "asking for gpt-5-pro: $(scan "$ID_TOKEN" '?model=gpt-5-pro')"
grep -oE '"model": ?"[^"]*"' /tmp/where-money-scan.json | head -1
echo 'expect gpt-5-nano, whatever was asked for.'

step 'reasoning effort, if the nano tier takes one'
for effort in low omit; do
  echo "effort=$effort: $(scan "$ID_TOKEN" "?effort=$effort")"
done
echo 'A 400 on effort=low and a 200 on effort=omit means the tier does not take'
echo 'the parameter, and the omit path is the one to configure.'

step 'a Rollup comes back written up'
recap() {
  local token=$1 query=${2:-}
  curl -sS -o /tmp/where-money-recap.json -w '%{http_code}'     -X POST "$base/recap$query"     -H "authorization: Bearer $token"     -H 'content-type: application/json'     --data-binary @- <<'ROLLUP'
{"month":"August 2026","currency":"MYR","total":1806.75,"previous_month":"July 2026","previous_total":1262.10,"expenses":18,"daily_average":58.28,"by_category":[{"category":"Groceries","amount":423.10,"previous":289.60,"count":3},{"category":"Dining out","amount":135.60,"previous":188.20,"count":4},{"category":"Fuel","amount":235.00,"previous":118.00,"count":2}],"largest":[{"merchant":"Ikea Damansara","amount":289.90,"category":"Home","day":23},{"merchant":"Uniqlo Mid Valley","amount":219.00,"category":"Apparel","day":12}],"heaviest_day":{"day":23,"amount":311.90},"excluded":{"count":1,"currencies":["USD"]}}
ROLLUP
}
echo "status: $(recap "$ID_TOKEN")"
$py - <<'PY' || cat /tmp/where-money-recap.json
import json
body = json.load(open('/tmp/where-money-recap.json'))
if body.get('error'):
    print('failed:', json.dumps(body)[:400])
    raise SystemExit
text = next(
    (c['text'] for item in body.get('output', []) if item.get('type') == 'message'
     for c in item.get('content', []) if c.get('type') == 'output_text'),
    None,
)
print('status:', body.get('status'), 'model:', body.get('model'))
print('usage:', body.get('usage'))
print(text or 'no output_text — refusal or incomplete. The screen has words for both.')
PY
echo
echo 'Read it against the Rollup above: every figure in it should be one of'
echo 'those, and nothing else.'

step 'a Recap does not spend the allowance a Scan needs'
echo "recap at cap=1:        $(recap "$ID_TOKEN" '?cap=1')"
echo "recap again at cap=1:  $(recap "$ID_TOKEN" '?cap=1')  <- expect 429"
echo "a Scan at cap=1 after: $(scan "$ID_TOKEN" '?cap=1')  <- expect 200, its own counter"

step 'a Recap with no token is refused'
curl -sS -w ' <- %{http_code}
' -X POST "$base/recap"   -H 'content-type: application/json' --data '{"month":"August 2026"}'

step 'CPU time per request'
echo 'wrangler tail, or the Worker metrics page, next to npm run measure.'

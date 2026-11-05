#!/usr/bin/env bash
# Optional: add Sonny Boy's permission allowlist to a Claude Code settings file, so the agents'
# routine commands (git add/commit, tests, worktree add) do not prompt. A plugin cannot ship
# permission rules, so this is a separate step. Works on macOS, Linux/WSL and Windows Git Bash.
#
#   scripts/setup-permissions.sh                  # user settings: ${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json
#   scripts/setup-permissions.sh --file PATH      # another settings file, e.g. <repo>/.claude/settings.local.json
#   scripts/setup-permissions.sh --dry-run        # show how many rules would be added
#
# The settings file is backed up to <same dir>/backups/sonny-boy-<timestamp>/ before it changes.
# git push, gh pr create/edit, git worktree remove and branch deletion are deliberately NOT
# allowed, so they always ask you.
set -euo pipefail

FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

ALLOW='["Bash(git status*)","Bash(git diff*)","Bash(git log*)","Bash(git show*)","Bash(git rev-parse*)","Bash(git add *)","Bash(git commit *)","Bash(git worktree list*)","Bash(git worktree add *)","Bash(graphify *)","Bash(* -m pytest*)","Bash(npm test*)","Bash(npm run test*)","Bash(npm run build*)","Bash(npm ci*)","Bash(npx playwright test*)","Bash(npx playwright install*)","Bash(gh pr view*)","Bash(gh pr checks*)","Bash(gh auth status*)","Edit(.claude/sonny-boy/**)","Edit(.claude/worktrees/**)"]'

NODE_MERGE='
const fs=require("fs"),[p,allow,dry]=process.argv.slice(1);
let s={};try{s=JSON.parse(fs.readFileSync(p,"utf8"))}catch(e){if(e.code!=="ENOENT")throw e}
s.permissions=s.permissions||{};const cur=s.permissions.allow||[];
const add=JSON.parse(allow).filter(x=>!cur.includes(x));
if(add.length&&dry!=="1"){s.permissions.allow=cur.concat(add);fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n")}
console.log(add.length);'
PY_MERGE='
import json,sys,os
p,allow,dry=sys.argv[1:4]
s=json.load(open(p,encoding="utf-8")) if os.path.exists(p) else {}
perm=s.setdefault("permissions",{});cur=perm.get("allow",[])
add=[x for x in json.loads(allow) if x not in cur]
if add and dry!="1":
    perm["allow"]=cur+add;open(p,"w",encoding="utf-8").write(json.dumps(s,indent=2)+"\n")
print(len(add))'

merge() {  # merge <dry 0|1> → prints the number of missing rules
  if command -v node >/dev/null; then node -e "$NODE_MERGE" "$FILE" "$ALLOW" "$1"
  elif command -v python3 >/dev/null; then python3 -c "$PY_MERGE" "$FILE" "$ALLOW" "$1"
  elif command -v python >/dev/null; then python -c "$PY_MERGE" "$FILE" "$ALLOW" "$1"
  else echo "?"; fi
}

n="$(merge 1)"
if [ "$n" = "?" ]; then
  echo "node/python not found. Add these to permissions.allow in $FILE by hand:"; echo "$ALLOW"; exit 1
fi
if [ "$DRY" = 1 ] || [ "$n" = 0 ]; then echo "$FILE: $n rule(s) to add"; exit 0; fi
mkdir -p "$(dirname "$FILE")"
if [ -f "$FILE" ]; then
  B="$(dirname "$FILE")/backups/sonny-boy-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$B"; cp "$FILE" "$B/$(basename "$FILE")"; echo "backup: $B/$(basename "$FILE")"
fi
merge 0 >/dev/null
echo "$FILE: $n rule(s) added"

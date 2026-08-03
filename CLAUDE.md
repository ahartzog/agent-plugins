# agent-plugins

Alek Hartzog's personal Claude Code plugin marketplace (`ahartzog`). Three plugins live under `plugins/`: **second-brain**, **apiary**, **scout-generator-critic-mediator**. For orientation — what each plugin is, how to install — read [README.md](README.md).

## If you are changing a skill

**Read [CONTRIBUTING.md](CONTRIBUTING.md) first and follow it.** The load-bearing rule: any change to a plugin's content or behavior ships, in the same change, a `CHANGELOG.md` entry **and** a `version` bump in that plugin's `.claude-plugin/plugin.json`. apiary has a stricter [per-plugin CONTRIBUTING](plugins/apiary/CONTRIBUTING.md) (scenario verification) — follow it too when touching apiary.

## Always

- Validate JSON before committing: `python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('**/*.json', recursive=True)]"`.
- Verify the current branch. 

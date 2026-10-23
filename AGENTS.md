# <Project name>

## Bootstrap - go through it with the user, then delete this section

### When bootstrap starts and finishes

The human will start bootstrap by prompting exactly keyphrase `BOOTSTRAP BEGIN`. The human will confirm that bootstrap is finished by prompting exactly keyphrase `BOOTSTRAP DONE`. Both keyphrases are in upper-case. This Boostrap section must be deleted from this file when it's done.

### Pre-requisites

After `BOOTSTRAP BEGIN`, check these requirements. If any of these are missing let the human know what has to be done to satisfy them then stop. The human must fulfill these requirements and let you know about it or start a new session.

Requirements:
- Obsidian CLI is available.

### Bootstrap procedure

The main session bootstraps itself, without any features or gates:
1. Ask the human up to 10 questions using AskUserQuestion: project name, users of the project, what we ship (in general, not architecture, e.g. service, web, mobile, library, can be multiple), single package or monorepo, stack preferences.
2. Remove `.knaifu` from `.gitignore`.
3. Create new Obsidian Vault in `.knaifu`, the vault will also include these structure elements:
    - decisions
    - project knowledge and documentation
    - project state
4. If the stack is unclear - initiate a spike research in `.knaifu/work/spikes/bootstrap/<question>/`, one question per spike. Make sure the decisions are recorded into Obsidian Vault `.knaifu/knowledge`, the hooks must pick this up automatically.
5. Create `README.md` using the information received from the human.
6. AskUserQuestion which license to pick, propose best for the project with rationale:
    - keep MIT
    - Apache 2.0
    - Other
7. Commit the changes.

After all these things are completed, tell the human that `BOOTSTRAP DONE` can be used to finish this. Before doing so, the human may ask to do something else. Evaluate the human's request if that is a part of the bootstrap or not. Think if it is related to the product features or changes. If it's not related to bootstrap then refuse doing what the human wants until `BOOTSTRAP DONE` is called.

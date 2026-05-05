# git-scripts

A handful of `git` subcommands I lean on day-to-day. Drop the `scripts/` dir
on your `$PATH` and `git <name>` resolves them as native subcommands.

## What's in here

| Command            | What it does                                                              |
|--------------------|---------------------------------------------------------------------------|
| `git branchclean`  | Prune local branches whose upstream is gone, including worktree cleanup.  |
| `git amend-old`    | Fold staged changes into an older commit, preserving everything after it. |
| `git branchrename` | Rename the current branch locally and on its remote.                      |
| `git heartbeat`    | Pull current + master, then merge/rebase master into current.             |

Each script accepts `-h` / `--help` for full usage.

### `git branchclean` highlights

- Detects squash-merged branches (via `commit-tree` + `cherry`) and deletes
  them silently — no nagging prompts on the corporate squash-merge workflow.
- For branches with worktrees: removes the worktree first; if the worktree
  is dirty, lists the changed files and prompts before force-removing.
- For branches with unmerged commits: lists them and prompts before `-D`.

## Install

```sh
git clone https://github.com/cornwe19/git-scripts.git
cd git-scripts
./install
```

By default `install` symlinks `scripts/*` into `/usr/local/bin/` (using
`sudo` if needed) and points `git config --global init.templatedir` at
`.git_templates/`. Override either with env vars:

```sh
INSTALL_DIR="$HOME/.local/bin" ./install   # user-local install, no sudo
SKIP_TEMPLATES=1 ./install                 # skip the templatedir config
```

## Tests

```sh
./test/run-all.sh
```

Tests run against scratch repos under `/tmp` and use `expect` to drive the
interactive prompts in `git branchclean`. Requires `git` and `expect`.

## Templates

`.git_templates/hooks/pre-push` blocks `git push` directly to `develop` or
`master`. It's installed automatically by `init.templatedir` for any repo
created or cloned after running `./install`. To opt out, run with
`SKIP_TEMPLATES=1` or remove the hook from individual repos.

## License

MIT (see `LICENSE`). `scripts/git-amend-old` is adapted from work by
Colin O'Dell (2014); attribution is preserved in the script header.

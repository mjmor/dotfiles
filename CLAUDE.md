# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A macOS dotfiles repo. Config files are version-controlled here and symlinked to their expected locations on disk using `link_files.sh`.

## Applying Changes

Run the symlink script to apply configs to the live system:

```sh
./link_files.sh
```

The script assumes the repo lives at `~/Projects/dotfiles`. It uses `ln -sf` (force-overwrite), so it is safe to re-run.

## Repo Structure

| Path | Symlink target |
|------|----------------|
| `.zshrc`, `.zprofile` | `~/.zshrc`, `~/.zprofile` |
| `.bash_profile`, `.bashrc`, `.bash_aliases` | `~/.*` |
| `.gitconfig` | `~/.gitconfig` |
| `.gitignore` | `~/.git/.gitignore` (global ignores) |
| `.ssh/config` | `~/.ssh/config` |
| `.vimrc` | `~/.vim/.vimrc` |
| `.inputrc` | `~/.inputrc` |
| `Library/Application Support/Code/User/settings.json` | VS Code user settings |
| `Library/Application Support/Code/User/keybindings.json` | VS Code keybindings |

`link_files.sh` skips a section silently if the target directory doesn't exist (e.g., no `~/.vim` dir → vim configs skipped).

## Shell Config Load Order

`.zshrc` sources `.bash_profile`, which sources `.bashrc`. Aliases live in `.bash_aliases`, sourced from `.bashrc`. PATH additions and tool initializations (rbenv, nvm, pyenv, gcloud, Go, Yarn) are split across `.bash_profile` and `.zshrc` — check both when tracing a PATH issue.

## Known Gaps (from README TODO)

- AWS config symlinking not yet implemented in `link_files.sh`
- No OS/environment detection — all configs are macOS-centric (Homebrew paths, `~/Library`, etc.)
- Shell scripts are still bash, not zsh

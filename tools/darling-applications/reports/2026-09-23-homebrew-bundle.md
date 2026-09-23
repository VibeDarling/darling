# Native Homebrew Bundle in a disposable Darling prefix

This is a dated test record, not a claim that the full user Brewfile or the
Applications viewer's Homebrew installation action works.

- Prefix: `/home/cristi/src/.tmp-vd-homebrew-prefix`, cloned from the user's
  existing prefix. The original prefix was not changed.
- Native Homebrew source in that prefix: `cristim/brew` commit `403e51f`,
  branch `darling-bundle-glob`. This changes Bundle's subcommand and extension
  discovery to use `Dir.children` because this Darwin Ruby build returns no
  results from the corresponding absolute `Dir.glob` patterns under Darling.
- The tracked `brewfile-install` helper was staged at
  `/usr/libexec/darling/brewfile-install` in that prefix.
- With `Verification.Brewfile` containing `brew "tree"`, running the helper
  through `darling shell` exited 0 and reported `brew bundle complete! 1
  Brewfile dependency now installed.` `tree` was already installed and linked.
  `xcrun` also reported that guest `clang` is unavailable; this was nonfatal
  for this fixture and remains a blocker for source builds.
- On the Linux Homebrew fork, `brew lgtm --online` passed typecheck but found
  no tests directly associated with the changed loader files. Explicit style
  checks passed for both files, and `brew tests --only=bundle/bundle` passed all
  seven examples after placing Homebrew's cache and test temporary directory
  on the same filesystem. The first test invocation failed with `EXDEV` while
  hard-linking between separate filesystems, before exercising the examples.

The user Brewfile currently has 18 taps, 155 formulae, 83 casks, and 23 MAS
entries. Its full import has not been attempted. A one-cask fixture with
`cask "rectangle"` reached `Installing rectangle`, then the guest
`brew install --adopt homebrew/cask/rectangle` process made no further visible
progress for over five minutes while consuming CPU. It did not start a child
downloader. The process ignored the command's first timeout signal and was
stopped after the five-minute bound; no Rectangle app was installed. This is
the next cask-path failure to trace. Cask installation and the app's runtime
imports are distinct gates; a successful download would not show that the app
launches or works.

The launcher's `homebrew-bootstrap` action currently verifies an existing
payload; it does not install Homebrew into an empty prefix. The pinned fork
revision still needs a reproducible staging path in that action, and the
Darling Ruby absolute-glob behavior needs a root-cause fix.

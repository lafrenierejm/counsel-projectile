# Contributing

## `git blame` setup

This repository maintains a `.git-blame-ignore-revs` file listing commits that we recommend excluded from `git blame` output so blame continues to point at the commit that meaningfully changed a line.

To configure your local clone to use it:

```sh
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

This is a local setting and is _not_ applied automatically by simply cloning the repository.
The setting must be configured once for each fresh clone.

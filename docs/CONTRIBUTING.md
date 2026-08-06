# How to Contribute

This document describes the guidelines and common practices for contributing
to the `meta-torizon` and `meta-torizon-bsp` repositories, whether you are part
of the Toradex team or an external contributor.

## Contributor workflow

- Fork the repository.
- Create a development branch in your fork.
- Make and commit your changes on the development branch.
- Open a pull request against the repository's default branch.
- When the default branch is not `master`, open a second pull request against
  `master` unless the change does not apply there.

Reviewers are automatically assigned based on the
[`docs/CODEOWNERS`](./CODEOWNERS) file.

## Commit guidelines

Every commit must be signed off with a `Signed-off-by` line at the end of its
message, for example:

```text
Update README.md

Signed-off-by: Your Name <your-email@example.com>
```

Add this line automatically with the `-s` option of `git commit`. The sign-off
certifies that you authored the contribution or have the right to submit it
under the same license as this repository, as described by the
[Developer Certificate of Origin](https://developercertificate.org/).

Commit messages should generally follow this format:

```text
scope: brief one-line description of up to 72 characters

[Optional] Detailed description, with each line limited to 72
characters.

Signed-off-by: Your Name <your-email@example.com>
```

The scope can identify a specific file or recipe, such as
`images/torizon-base.inc` or `u-boot-distro-boot`. For changes spanning several
files, it can identify a machine or configuration area, such as
`intel-corei7-64` or `conf/distro`.

For broad changes, the subject can instead be an imperative sentence:

```text
Show spinner while processing raw images
```

For a simple change to one file, a concise subject is sufficient:

```text
Add README.md
```

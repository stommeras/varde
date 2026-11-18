---
name: implement-issue
description: "Implement a Varde GitHub issue end to end in its own worktree off origin/main: branch, build, test, look at it, check it against the issue, review, fix, and open the PR."
disable-model-invocation: true
---

# Implement issue

Takes an issue number, for example `/implement-issue 5`. Follow the conventions and the workflow in `AGENTS.md` throughout.

## Steps

1. **Read.** Run `gh issue view <number>` and state its title. Read the parts of `SPEC.md` it touches. If the issue leaves a design decision open, or you see a better choice than the issue or `SPEC.md` makes, follow step 2 of the workflow in `AGENTS.md`.
2. **Worktree.** Run `git fetch origin`. Each issue gets its own worktree off `origin/main`, so several runs can go at once without touching the main checkout.
   - If the session already runs in a linked worktree (`git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`), stay there and run `git switch -c <type>/<short-description> --no-track origin/main`.
   - Otherwise run `git worktree add --no-track -b <type>/<short-description> .claude/worktrees/<short-description> origin/main`, then call EnterWorktree with that `path`. All later steps run in the worktree.
   - Run `godot --headless --import` once, since the new checkout has no `.godot/` cache.
3. **Build.** Implement the issue. Add or extend tests in `tests/` for generator logic. Run the tests as you go. Commit when the tests pass.
4. **Look.** For anything visual, record frames as `AGENTS.md` describes and read the last one. Fix what looks wrong. Keep the image path for the report.
5. **Check against the issue.** Go through the issue line by line. For each requirement, note whether it is done, and if not, why. Finish what is missing, or keep the reason for the PR.
6. **Review.** Call the Skill tool with `code-review` and the args `medium --fix`. Run the tests again, read every change it made, and commit. Keep its report of what it fixed and what it skipped, with reasons.
7. **PR.** Push with `git push -u origin HEAD` and open the PR with `Closes #<number>` or `Part of #<number>`. Describe what changed, the requirement list from step 5, what the review fixed and skipped, any decision you changed and why, and what the user should judge by eye, such as a tuning value.
8. **Report.** Give the PR link, the image, the worktree path, and any question for the user. Leave the worktree in place for review fixes. After the PR merges, remove it with `git worktree remove <path>`.

---
name: implement-issue
description: "Implement a Varde GitHub issue end to end: branch, build, test, look at it, check it against the issue, review, fix, and open the PR."
disable-model-invocation: true
---

# Implement issue

Takes an issue number, for example `/implement-issue 5`. Follow the conventions and the workflow in `AGENTS.md` throughout.

## Steps

1. **Read.** Run `gh issue view <number>` and state its title. Read the parts of `SPEC.md` it touches. If the issue leaves a design decision open, or you see a better choice than the issue or `SPEC.md` makes, follow step 2 of the workflow in `AGENTS.md`.
2. **Branch.** Name the branch `<type>/<short-description>` after what the issue changes, for example `feat/fog-rising-land`. Never use the issue number or the command's name. Run `git fetch origin`. T3 Code starts a new worktree on a branch it names after the thread's first message, such as `feat/implement-issue-70`. If the current branch has no commits that `origin/main` lacks and no changes, rename it with `git branch -m <name>` and run `git reset --hard origin/main`. Otherwise run `git switch -c <name> --no-track origin/main`, which works in the main checkout and in a worktree, where `main` can't be checked out. Name the branch before the first push, because renaming the head branch of a pull request closes the pull request. If `.godot/` is missing, as in a new worktree, run `godot --headless --import` once.
3. **Build.** Implement the issue. Add or extend tests in `tests/` for generator logic. Run the tests as you go. Commit when the tests pass.
4. **Look.** For anything visual, record frames as `AGENTS.md` describes and read the last one. Fix what looks wrong. Keep the image path for the report.
5. **Check against the issue.** Go through the issue line by line. For each requirement, note whether it is done, and if not, why. Finish what is missing, or keep the reason for the PR.
6. **Review.** Call the Skill tool with `code-review` and the args `medium --fix`. Run the tests again, read every change it made, and commit. Keep its report of what it fixed and what it skipped, with reasons.
7. **PR.** Push with `git push -u origin HEAD` and open the PR with `Closes #<number>` or `Part of #<number>`. Describe what changed, the requirement list from step 5, what the review fixed and skipped, any decision you changed and why, and what the user should judge by eye, such as a tuning value.
8. **Report.** Give the PR link, the image, and any question for the user.

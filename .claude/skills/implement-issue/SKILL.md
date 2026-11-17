---
name: implement-issue
description: "Implement a Varde GitHub issue end to end: branch, build, test, look at it, check it against the issue, review, fix, and open the PR."
disable-model-invocation: true
---

# Implement issue

Takes an issue number, for example `/implement-issue 5`. Follow the conventions and the workflow in `AGENTS.md` throughout.

## Steps

1. **Read.** Run `gh issue view <number>` and state its title. Read the parts of `SPEC.md` it touches. If the issue leaves a design decision open, or you see a better choice than the issue or `SPEC.md` makes, follow step 2 of the workflow in `AGENTS.md`.
2. **Branch.** Update `main` and create `<type>/<short-description>`.
3. **Build.** Implement the issue. Add or extend tests in `tests/` for generator logic. Run the tests as you go. Commit when the tests pass.
4. **Look.** For anything visual, record frames as `AGENTS.md` describes and read the last one. Fix what looks wrong. Keep the image path for the report.
5. **Check against the issue.** Go through the issue line by line. For each requirement, note whether it is done, and if not, why. Finish what is missing, or keep the reason for the PR.
6. **Review.** Call the Skill tool with `code-review` and the args `medium --fix`. Run the tests again, read every change it made, and commit. Keep its report of what it fixed and what it skipped, with reasons.
7. **PR.** Push and open the PR with `Closes #<number>` or `Part of #<number>`. Describe what changed, the requirement list from step 5, what the review fixed and skipped, any decision you changed and why, and what the user should judge by eye, such as a tuning value.
8. **Report.** Give the PR link, the image, and any question for the user.

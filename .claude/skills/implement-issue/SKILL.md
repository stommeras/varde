---
name: implement-issue
description: "Implement a Varde GitHub issue end to end: branch, build, test, look at it, review, fix the findings, and open the PR."
disable-model-invocation: true
---

# Implement issue

Takes an issue number, for example `/implement-issue 5`. Follow the conventions and the workflow in `AGENTS.md` throughout.

## Subagents

Every subagent spawned during this run gets `model: "sonnet"` on its `Agent` call, including the reviewers that `code-review` starts.

## Steps

1. **Read.** Run `gh issue view <number>` and state its title. Read the parts of `SPEC.md` it touches. If the issue leaves a design decision open, ask the user before building, and don't guess.
2. **Branch.** Update `main` and create `<type>/<short-description>`. Run `git rev-parse HEAD` and keep the SHA as the base for the review.
3. **Build.** Implement the issue. Add or extend tests in `tests/` for generator logic. Run the tests as you go. Commit when the tests pass.
4. **Look.** For anything visual, record frames as `AGENTS.md` describes and read the last one. Fix what looks wrong. Keep the image path for the report.
5. **Review.** Call the Skill tool with `mattpocock-skills:code-review`, giving the base SHA as the fixed point. Fix each finding, or decline it with a one-line reason. Run the tests again and commit.
6. **PR.** Push and open the PR with `Closes #<number>` or `Part of #<number>`. Describe what changed, what you checked, and what the user should judge by eye, such as a tuning value.
7. **Report.** Give the PR link, each review finding as fixed or declined with its reason, the image, and any question for the user.

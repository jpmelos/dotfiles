---
description: Generate a plan in Markdown with implementation tickets for a new feature or change. Use exclusively when explicitly asked to create a plan from a feature or change specification.
argument-hint: spec_file=SPEC_FILE
---

## Important Context Information

Arguments:

```
$ARGUMENTS
```

Parse the following information from the arguments:

- `spec_file`: The Markdown file containing the feature or change
  specification.

## The Task

Create a detailed plan that is clear, actionable, and suitable for
implementation of the feature or change described in `spec_file`.

1. Ask as many clarifying questions as you deem necessary to be able to fully
   flesh out the feature or change into small, atomic tickets.
2. Study the project to understand the relevant aspects specific to the
   project.
   - For example, if you're going to create or change a REST API, make sure to
     understand how REST APIs work in the project.
   - Make sure you understand all project-specific terms and jargons. If you
     see terms whose meaning depend on the project, like "service layer", make
     sure you understand them completely before planning.
   - Include these details in the ticket descriptions as necessary to enable
     work and set up your colleagues for success.
3. Generate a structured plan document based on all the information you
   gathered.
4. Save the plan to a file in the same directory as the `spec_file` using the
   same filename as the `spec_file` but with the file extension `.plan.md`. For
   example, if the `spec_file` is named `feature-x.spec.md`, name the plan file
   as `feature-x.plan.md`.

**Important:** Do **not** implement anything. Just write the plan document.

### Clarifying Questions

Ask clarifying questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it **not** do?
- **Success Criteria:** How do we know it's done?

Organize questions in a clear way using ordered lists, ordered by most relevant
first.

### Plan Structure

Generate the plan with these sections:

1. Introduction/Overview

   Brief description of the feature and the problem it solves.

2. Goals

   Specific, measurable objectives (ordered list, ordered by most relevant
   first).

3. Tickets

   Each ticket needs:

   - **Title:** Short descriptive name.
   - **Description:** A description of what needs to be done in extensive
     detail.
   - **Acceptance Criteria:** Verifiable checklist of what "done" means.

   Each ticket should be small enough to implement in one focused session.

   **Format:**

   ```markdown
   ### 1: [Title]

   **Description:**

   The description.

   **Acceptance Criteria:**
   - [ ] Specific verifiable criterion
   - [ ] Another verifiable criterion
   - [ ] Yet another verifiable criterion
   ```

   **Important:** Acceptance criteria must be verifiable, not vague. "Works
   correctly" is bad. "Return payload includes `date` field with X format" is
   good.

4. Functional Requirements

   Numbered list of specific functionalities:

   1. The system must allow users to...
   2. When a user clicks X, the system must...

   Be explicit and unambiguous.

5. Non-Goals (Out of Scope)

   What this feature will **not** include. Critical for managing scope.

6. Technical Considerations

   1. Known constraints or dependencies
   2. Integration points with existing systems
   3. Performance requirements

7. Success Metrics

   How will success be measured?

   1. "Reduce time to complete X by 50%"
   2. "Increase conversion rate by 10%"

## Writing for Junior Developers

The plan reader may be a junior developer or an AI agent. Therefore:

- Be explicit and unambiguous.
- Avoid jargon or explain it.
- Provide enough detail that a very junior engineer can understand the purpose
  and the core logic of the feature.
- Number requirements for easy reference.
- Use concrete examples where helpful.

## Output

- **Format:** Markdown (`.plan.md`).
- **Location:** Same directory as the `spec_file`.

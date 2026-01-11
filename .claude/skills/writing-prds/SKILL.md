---
name: writing-prds
description: "Generate a Product Requirements Document (PRD) for a new feature. Use exclusively when explicitly asked to create a PRD from a feature specification."
---

Create a detailed Product Requirements Document that is clear, actionable, and
suitable for implementation.

## The Task

1. Receive a feature description.
2. Ask as many clarifying questions as you deem necessary to be able to fully
   flesh out the feature into small, atomic tasks.
3. Generate a structured Product Requirements Document (PRD) based on all the
   information you gathered.
4. Save it to `jpenv-scratch/PRD.md`.

**Important:** Do **not** implement anything. Just create the PRD.

### Step 1: Clarifying Questions

Ask clarifying questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it **not** do?
- **Success Criteria:** How do we know it's done?

Organize questions in a clear way using ordered lists, ordered by most relevant
first.

### Step 2: PRD Structure

Generate the PRD with these sections:

1. Introduction/Overview

   Brief description of the feature and the problem it solves.

2. Goals

   Specific, measurable objectives (ordered list, ordered by most relevant
   first).

3. User Stories

   Each story needs:

   - **Title:** Short descriptive name.
   - **Description:** "As a [user], I want [feature] so that [benefit]".
   - **Acceptance Criteria:** Verifiable checklist of what "done" means.

   Each story should be small enough to implement in one focused session.

   **Format:**

   ```markdown
   ### 1: [Title]
   **Description:** As a [user], I want [feature] so that [benefit].

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

The PRD reader may be a junior developer or an AI agent. Therefore:

- Be explicit and unambiguous.
- Avoid jargon or explain it.
- Provide enough detail that a very junior engineer can understand the purpose
  and the core logic of the feature.
- Number requirements for easy reference.
- Use concrete examples where helpful.

## Output

- **Format:** Markdown (`.md`).
- **Location:** `jpenv-scratch/PRD.md`.

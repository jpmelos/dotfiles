---
description: Create a detailed implementation plan through discussion.
argument-hint: '[additional instructions]'
disable-model-invocation: true
---

Create a detailed plan that is clear and actionable for the change described in
the conversation.

Do not implement anything. Create only the plan.

Complete each step below.

## 1. Study of the project

Study the project to understand aspects relevant to the change.

- Identify patterns and conventions for the affected area. For example, when
  the change affects a REST API, identify how a REST API works in this project.
- Define all project-specific terms in full. For example, when the plan
  mentions the service layer, define what the service layer means in this
  project.
- Add these details to ticket descriptions so that work can start at once.

Cite inspected code with paths relative to the repository root. Then proceed
to the next step.

## 2. Clarification questions

With study results in hand, ask clarification questions. Focus on these
topics:

- Problem and goal: what problem does this solve.
- Core functionality: what are the key actions.
- Scope and boundaries: what the work will not do.
- Success criteria: how the team knows that the work is done.

Phrase each question in a clear way. List questions in an ordered list. Order
questions from most relevant to least relevant. For questions with likely
answers, list the likely answers as a nested ordered list. When no likely
answer exists, leave the question open-ended with no alternatives. Base each
question on facts from the study where possible.

Example with alternatives:

```markdown
1. Which database do you prefer for this feature?
   a. PostgreSQL
   b. MySQL
   c. SQLite
   d. Other. Explain.

2. Which password algorithm do you prefer?
   a. Algorithm A.
   b. Algorithm B.
   d. Other. Explain.
```

The user can answer with short references. Example answers:

```markdown
1a 2b
```

```markdown
1a
2c I prefer Algorithm Z.
```

Ask directly in the chat. Do not use a tool to ask. Wait for answers. Then
proceed to the next step.

## 3. Plan structure

Generate the plan with these sections in this order.

### 1. Introduction and Overview

This section gives a brief description of the feature and the problem that it
solves.

### 2. Goals

This section lists specific and measurable objectives in an ordered list. Order
goals from most relevant to least relevant.

### 3. Tickets

This section lists small tickets. Each ticket must be small enough for
completion in one focused work session. Each ticket has these parts:

- Title: short descriptive name.
- Description: full detail of what the work requires.
- Acceptance Criteria: verifiable list of what done means.

Format each ticket as shown below.

```markdown
### 1: [Title]

**Description:**

The description.

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another verifiable criterion
- [ ] Yet another verifiable criterion
```

Write acceptance criteria that a reader can verify. Bad example is Works
correctly. Good example is Response payload includes `date` field in X format.

### 4. Functional Requirements

This section gives a numbered list of specific functions. Be explicit,
specific, and unambiguous. Example content:

1. The system must allow users to...
2. When a user clicks X, the system must...

### 5. Non-Goals

This section lists what this feature will not contain. Be explicit, specific,
and unambiguous. This list controls scope.

### 6. Technical Considerations

This section gives an ordered list of constraints, dependencies, and
integration points with other parts of the project or with other systems. Order
entries from most relevant to least relevant. Add performance requirements when
they exist.

### 7. Success Metrics

This section describes how the team measures success. Example content:

1. Reduce time to complete X by 50 percent.
2. Increase conversion rate by 10 percent.

## 4. Style rules

Write for a junior developer or an AI agent as the reader. Be explicit,
specific, and unambiguous. Avoid jargon. When jargon is required, explain it in
full. Provide enough detail so that a junior engineer understands the purpose
and the core logic. Number requirements for easy reference. Use concrete
examples where they help.

Use single backticks for identifiers. Write real newlines, not escape
sequences. Keep American spelling.

## 5. Output

Present the full plan in the chat as readable text. Do not wrap the plan in
a code block. Do not emit raw Markdown. Do not write the plan to a file. If
the user requests a save, write the plan as Markdown to the requested location
at that time.

Follow these additional instructions:

```
$ARGUMENTS
```

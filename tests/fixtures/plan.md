# Fixture Plan

Fixture used by the make-package tests. It mixes every task kind.

## Decisions recorded for this plan

- Deliverable: `deliverables/fixture/` (to confirm).

## Global Constraints

- Finding IDs are `<TASK>-F<NN>`.
- Cite a source for every claim.

## Review Focus

1. Every finding carries its evidence.

## Worker environment

- Read-only access to the sources named in each task.

## Data contract

`Order` has `id` and `total`.

## Findings format

Each finding has: ID, severity, description, evidence link.

## Severity scale

Critical, Important, Minor.

## Document outline

1. Summary
2. Details

## Sources

- S1: the product brief.

## Tasks

### Task T-001: Build the order model

**Model:** sonnet · **Depends on:** none · **Contracts:** Data contract · **Vault:** none

- [ ] **Step 1:** write the model.

### Task T-002: Audit the order flow

**Kind:** findings · **Model:** sonnet · **Depends on:** T-001 · **Contracts:** Findings format, Severity scale · **Vault:** none

- [ ] **Step 1:** survey the flow.

### Task T-003: Write the summary section

**Kind:** document · **Model:** sonnet · **Depends on:** T-002 · **Contracts:** Document outline, Sources · **Vault:** none

- [ ] **Step 1:** draft the section.

### Task T-004: Audit with odd Kind spacing

**Kind:**  Findings  · **Model:** sonnet · **Depends on:** none · **Contracts:** Findings format, Severity scale · **Vault:** none

- [ ] **Step 1:** survey the flow.

### Task T-005: Audit with an invalid Kind

**Kind:** audit · **Model:** sonnet · **Depends on:** none · **Contracts:** Findings format · **Vault:** none

- [ ] **Step 1:** survey the flow.

### Task T-006: Audit that lists a vault note

**Kind:** findings · **Model:** sonnet · **Depends on:** none · **Contracts:** Findings format, Severity scale · **Vault:** concepts/Pedido

- [ ] **Step 1:** survey the flow.

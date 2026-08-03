# Add Workflow Mode — Repeatable Operations

This document guides the Add Workflow mode of the `second-brain` skill. It helps users add structured, repeatable workflows to existing domain agents.

## Prerequisites

The SKILL.md has already run hub discovery. The user may have specified an agent and/or workflow type.

## Step 1: Select Target Agent

If not specified, list agents from the hub and ask which one should get the workflow.

## Step 2: Select Workflow Pattern

Read `references/workflow-patterns.md` and present the available patterns:

1. **Status Report (5-15)** — Recurring status updates organized by lines of effort. Good for programs with leadership reporting cadence.
2. **Collector Pipeline** — Automated data gathering from multiple sources with parallel dispatch. Good for self-retrospection or team dashboards.
3. **RFC / Document Authoring** — Template-driven document creation with stakeholder routing. Good for teams that produce technical proposals.
4. **Compliance Scanning** — Scanning runbooks with artifact generation. Good for any recurring compliance or audit process (SOC 2, HIPAA, PCI, internal policy).
5. **Schedule Assessment** — Readiness evaluation against deadlines. Good for programs with hard ship/review dates.
6. **Sprint Orchestration** — Time-boxed sprint management toward a deliverable. Good for demo prep or release sprints.
7. **Custodian Health Pulse** — Lightweight recurring vault health check whose checklist grows via Loop C. Good for any hub at L3+.
8. **Golden-Question Eval** — Quarterly regression harness against a per-domain eval set (`assets/golden-questions-template.md`). Good for hubs that want an objective compounding-vs-decaying signal.
9. **Correction Mining** — Monthly sweep of feedback memories not yet propagated to agent files (Loop A backlog). Good once corrections outpace sessions.
10. **Session-End Wrap** — Alias/wiring for the skill's wrap mode in this hub (`references/mode-wrap.md` owns the procedure). Good for every hub.
11. **Custom** — Start from the workflow template and customize from scratch.

For patterns 7-10, customize from their `references/workflow-patterns.md` catalog entries (there are no dedicated interview sections below — the catalog entry plus `assets/workflow-template.md` is the scaffold).

Ask: "Which pattern fits your needs?" using AskUserQuestion.

## Step 3: Customize the Workflow

Based on the selected pattern, run a focused interview. Questions vary by pattern:

### For Status Report (5-15)

1. **Report name** — e.g., "Ground Segment 5-15", "Platform Team Weekly"
2. **Lines of Effort** — what categories organize the work? (e.g., Software Development, External Dependencies, Compliance). Ask user to list 3-6 LOEs.
3. **Categories per LOE** — default: Accomplishments / Open Work / Blockers. Allow customization.
4. **Data sources** — which sources to trawl? Present the relevant subset from content-sources.md based on what the agent already has wired up. For each source, gather specifics (which Slack channels? which Jira filters?).
5. **Audience** — who reads this? Determines formality and content filtering.
6. **Frequency** — weekly (default), biweekly, or on-demand?
7. **Output location** — where should the draft be written?
8. **Content filtering rules** — any exclusions? (e.g., "exclude INTERNAL items", "scope to ground segment only")

### For Collector Pipeline

1. **Pipeline name** — e.g., "Weekly Activity Report", "Sprint Metrics"
2. **Collectors** — which data sources? For each, define:
   - Source name and access method
   - What to extract
   - Any filters or date ranges
3. **Wave dependencies** — which collectors depend on others' output?
4. **Output format** — what sections should the final report have?
5. **Frequency** — weekly, daily, on-demand?
6. **Batch mode** — should it support non-interactive `--batch` execution?

### For RFC / Document Authoring

1. **Document types** — what kinds of docs? (RFC, PRD, design doc, runbook, etc.)
2. **Template sections** — what standard sections should each doc type have?
3. **Reviewers** — who reviews which doc types? (Pull from stakeholders.md)
4. **Knowledge pre-fill** — which knowledge files should be loaded to pre-populate context?

### For Compliance Scanning

1. **Scan types** — what gets scanned? (vulnerabilities, config checks, dependency audits, etc.)
2. **Tools** — what scanning tools are used?
3. **Artifacts** — what documents are produced from scan results? (action-item register, evidence pack, risk assessments)
4. **Tracking** — where are findings tracked? (Jira, spreadsheet, knowledge file)

### For Schedule Assessment

1. **Target deadline** — what's the hard date?
2. **Milestones** — what are the key milestones leading to the deadline?
3. **Dependencies** — what depends on what?
4. **Risk thresholds** — how many days of slip before something goes from green to yellow to red?
5. **Data sources** — where to check status? (Jira, Slack, meeting notes, etc.)

### For Sprint Orchestration

1. **Sprint name** — e.g., "NSS Demo Sprint", "v2.0 Release Sprint"
2. **Deliverable** — what's the north star?
3. **Work areas** — what functional areas are in scope?
4. **Skills/tools** — which existing skills handle which work areas?
5. **Duration** — sprint start and end dates

### For Custom

Walk through the workflow template (`assets/workflow-template.md`) section by section, filling in each placeholder interactively.

## Step 4: Generate the Workflow

1. Read `assets/workflow-template.md`
2. Fill in all placeholders with the interview answers
3. Write the workflow file to the agent's directory: `{agent_dir}/{workflow-slug}-workflow.md`

## Step 5: Wire into the Agent

1. Read the target agent file
2. Add a routing rule to "Before Answering": "If asked to generate a {workflow_name} → read `{workflow-file}.md` and follow its process"
3. If the workflow introduces new sources not already in the agent's Domain Context, add them
4. If the workflow needs tools not in the agent's YAML (e.g., `Agent` for collector dispatch), add them

Show the proposed agent edits and confirm with the user before applying.

## Step 6: Set Up Automation (Optional)

Ask: "Would you like to run this workflow on a schedule?"

If yes:
1. Determine the cron schedule (e.g., "Every Friday at 9:00 AM" → `0 9 * * 5`)
2. Generate a shell script based on the template in `assets/workflow-template.md`
3. Show the user:
   - The cron entry to add
   - The script to save
   - How to test it manually first
4. Offer to create the script file and show the `crontab -e` command (do NOT modify crontab directly — let the user do it)

## Step 7: Verify

1. Confirm the workflow file was created
2. Confirm the agent was updated with routing
3. Suggest: "Test the workflow now by asking the agent: '{trigger phrase}'"
4. Remind: "You can refine this workflow anytime by editing `{workflow_file}`"

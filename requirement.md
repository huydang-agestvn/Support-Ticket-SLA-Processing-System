Junior Developer Training Programme
Phase 3 Delivery Project Briefs with AI
For the three Phase 2 backend and data engineering case-study projects

Field	Value
Document purpose	Provide complete Phase 3 project briefs for the three Phase 2 projects, with AI integration, agile delivery expectations, evidence requirements, and demo guidance.
Audience	Junior developers, facilitators, and engineering stakeholders.
Programme stage	Weeks 9-12: Delivery project with AI.
Source basis	Phase 2 Practical Case Study Guide + Junior Developer Training Programme Playbook.
Assumption	The uploaded Phase 2 guide contains three project tracks. This document therefore defines three Phase 3 project prompts, one per Phase 2 project.

Operating principle
Phase 3 should not become a playground for random AI features. Each team must add AI only where it improves a real workflow, remains explainable to reviewers, and can be tested with evidence.


Prepared date: 04 June 2026


1. Executive Summary	
This document extends the three Phase 2 backend/data engineering projects into Phase 3 delivery projects with practical AI integration. The intent is to keep the existing Go, PostgreSQL, REST API, batch processing, worker pool, testing, CI, and ETL foundation, then add one purposeful AI capability per project.
The Phase 3 work should be evaluated as a delivery project, not only as an AI demo. Teams must show product functionality, maintainable code, agile execution, AI guardrails, evaluation evidence, and the ability to defend trade-offs during peer review.
Team	Phase 2 foundation	Phase 3 project title	AI value
Team 1	Support Ticket SLA Processing System	AI Service Desk Triage and SLA Risk Assistant	Classify tickets, summarize history, estimate SLA breach risk, and recommend next actions without auto-changing ticket state.
Team 2	Order Fulfillment Tracking System	AI Fulfillment Exception and Customer Update Assistant	Detect delivery/order exceptions, explain likely causes, and draft safe customer-facing update messages without sending them automatically.
Team 3	Inventory Movement Processing System	AI Inventory Anomaly and Replenishment Assistant	Detect stock-risk/anomaly patterns, explain likely causes, and recommend audit/replenishment actions without modifying stock balances.

2. Shared Phase 3 Operating Model
All teams should keep the Phase 2 engineering baseline and improve it with a controlled AI feature. The key difference from Phase 2 is not the technology stack; it is the delivery expectation: teams must plan, iterate, harden, evaluate, document, and defend the system.
Area	Required Phase 3 expectation
Reuse from Phase 2	Reuse repo scaffolding, auth/token pattern, logging/request ID, error model, PostgreSQL migrations, Docker Compose, CI pipeline, and testing patterns where appropriate.
AI capability	One AI workflow per project, exposed through backend APIs, with JSON contracts, validation, logging, retry/timeout, fallback, and evaluation cases.
Backend scope	REST APIs, domain services, repositories, migrations, ETL/reporting job, tests, and runbook remain required. AI should be an extension, not a replacement for deterministic business rules.
Data safety	Use synthetic or approved training data only. Do not place secrets, real personal data, customer-confidential data, or production credentials in prompts.
No auto-critical actions	AI must not automatically close tickets, refund orders, update delivery status, or change inventory quantity. It may recommend actions and produce drafts for human review.
Evidence	Every significant claim in the demo must be backed by observable evidence: tests, logs, request/response samples, evaluation table, code reference, benchmark note, or runbook step.

Recommended AI architecture pattern
Controller/API -> Input validation -> Domain context builder -> AI adapter -> Output schema validator -> Confidence/fallback policy -> Audit log -> API response.

The AI adapter should be replaceable. Model/provider settings must be configuration-driven, not hardcoded.

3. Common Technical Baseline and Non-Goals
Language and service pattern: Go backend service with clear package boundaries: cmd, internal/api, internal/domain, internal/repository, internal/worker, internal/ai, internal/config, internal/observability.
Database: PostgreSQL with migrations, repository layer, indexes for read/report queries, and transaction boundaries where needed.
Batch/concurrency: Keep the worker-pool pattern from Phase 2. AI batch jobs should not introduce race conditions or uncontrolled parallel model calls.
Testing: Table-driven unit tests for domain rules, integration tests for API/repository flows, and AI workflow tests using deterministic fake/stub adapters.
Configuration: Use environment variables for AI provider, model name, timeout, retry limit, max input size, and feature enable/disable switch.
Observability: Log request ID, AI workflow name, prompt/template version, duration, success/failure, fallback reason, and validation errors without logging secrets.
Strict Phase 3 Non-Goals
No production frontend UI is required; API responses, Postman/cURL demos, and simple generated docs are enough.
No Kubernetes, Kafka/RabbitMQ, full data warehouse, advanced monitoring stack, or complex enterprise RBAC.
No uncontrolled autonomous AI action. AI can assist, classify, summarize, explain, or recommend, but domain state changes still require explicit API commands and deterministic validation.
No external confidential data. Use synthetic fixtures or approved internal sample data only.
4. Minimum AI Standards for All Three Projects
Standard	What the team must show
Problem fit	A clear explanation of the operational/user problem the AI feature solves, and why deterministic rules alone are insufficient or less useful.
Non-AI baseline	A simple baseline rule or heuristic that can run when AI is disabled or fails.
Prompt/context design	Prompt template version, input fields, context limits, and what information is deliberately excluded.
Schema validation	AI response must be parsed into a strict JSON schema. Invalid AI output must trigger fallback or a controlled error.
Guardrails	Input validation, timeout, retry, max input size, model/provider config, safe logging, and no automatic critical side effects.
Evaluation	At least 15-20 project-specific test cases with expected labels/outcomes, plus an evaluation summary table.
Failure path demo	One controlled failure scenario: AI disabled, timeout, invalid response, or low confidence leading to deterministic fallback.

5. Suggested Four-Member Role Model
Role	Main ownership	Required evidence
Product/API & Demo Owner	Owns user story framing, API contracts, acceptance criteria, and final demo narrative.	Project charter, API spec, demo script, acceptance checklist.
Domain/Data & Repository Owner	Owns schema evolution, SQL/migrations, reporting tables, domain data quality, and seed/demo datasets.	ERD update, migrations, sample data, query/index evidence.
AI Workflow & Evaluation Owner	Owns AI adapter, prompt/context builder, output schema, fallback policy, and evaluation cases.	AI design note, eval dataset, eval results, fallback tests.
QA/DevOps/Agile Owner	Owns CI, integration tests, Docker Compose, runbook, agile board hygiene, retrospectives, and release tag.	CI logs, test report, runbook, sprint board, retro notes.

Important
Ownership does not mean solo work. Every member must code, review PRs, and speak during the final demo.

6. Week-by-Week Delivery Plan (Weeks 9-12)
Week	Focus	Minimum outputs
Week 9	Kick-off and planning	Project charter; refined user stories; backlog and estimate; architecture draft; AI approach decision; reuse/refactor plan; evaluation dataset draft.
Week 10	Sprint 1	Core backend extension; AI adapter interface; first AI prototype endpoint; fake/stub AI tests; critical path tests; demo checkpoint.
Week 11	Sprint 2	Feature expansion; guardrails; retries/timeouts; fallback path; E2E tests; evaluation run; system documentation; optional peer review touchpoint.
Week 12	Final sprint and milestone	Code freeze; final runbook; demo deck; AI evaluation note; release tag; final peer review debate; captured follow-up actions.



7. Team 1 Project Brief
AI Service Desk Triage and SLA Risk Assistant
Field	Description
Phase 2 foundation	Support Ticket SLA Processing System
Phase 3 product direction	The Phase 2 system tracks tickets, status changes, batch ticket events, and daily SLA reporting. Phase 3 upgrades it into an operator-assist system that helps support leads triage work earlier and understand which tickets are likely to breach SLA.
Primary AI goal	Classify incoming tickets, summarize ticket history, estimate SLA breach risk, and recommend next actions for human review.
Non-AI baseline	Rule-based category/priority mapping using keywords plus deterministic SLA threshold calculation from existing ticket/report data.

User personas
Support Lead: monitors backlog and SLA risk.
Support Agent: reads ticket summary and recommended next action.
Operations Manager: reviews daily AI-assisted triage quality and SLA trends.
Inputs and outputs
Input context	Required AI output fields
- Ticket title, description, requester department, priority, created_at.
- Ticket event history, status flow, assigned agent/team if available.
- SLA policy values and daily report aggregates.
- Optional internal FAQ/category examples using synthetic text only.	- category
- urgency_level
- sla_breach_risk
- reason_summary
- recommended_next_action
- confidence_score
- fallback_used

Required backend/API extension
Expose the AI feature through backend REST APIs; do not call the model directly from scripts only.
Add an internal AI adapter interface so tests can use a fake model implementation.
Persist AI results, prompt/template version, confidence, fallback reason, and timestamps in PostgreSQL.
Return consistent error responses and preserve request ID logging from Phase 2.
API endpoints	Suggested new tables
- POST /ai/tickets/{id}/triage
- GET /ai/tickets/{id}/triage/latest
- POST /ai/tickets/triage:batch
- POST /ai/evaluations/ticket-triage	- ai_ticket_triage_results
- ai_evaluation_runs
- ai_evaluation_cases

Acceptance criteria
AI triage returns valid JSON matching the documented schema for every successful request.
Low confidence or invalid AI output triggers deterministic fallback, not a crash.
SLA breach risk is never decided only by AI; it must include deterministic SLA calculation evidence.
At least 20 evaluation cases cover category, urgency, SLA risk, duplicate events, and unclear descriptions.
Demo includes one happy path and one AI failure/fallback path.


Week-by-week backlog
Week	Backlog target
Week 9	Finalize charter, user stories, API contract, AI schema, baseline rules, evaluation case list, and reuse/refactor plan.
Week 10	Implement AI adapter, first endpoint, result persistence, fake AI tests, and a minimal happy path demo.
Week 11	Add batch/scan flow where applicable, retries/timeouts, fallback behavior, E2E tests, evaluation runner, and documentation.
Week 12	Freeze code, run final evaluation, prepare demo deck/runbook, tag release, and rehearse final peer review defence.

Final demo scenario
1. Create a ticket with ambiguous text and show AI category/priority suggestion.
2. Import a batch of ticket events and show accepted/rejected/duplicate counts still work.
3. Run triage batch and show high-risk SLA tickets with explanations.
4. Disable or stub the AI provider to return invalid JSON and show fallback response and logs.
Main risks and controls
Risk	Control
AI overreach	AI must not auto-close, auto-cancel, or silently change ticket status.
Prompt leakage	Do not include secrets, credentials, or real employee data in prompts.
False urgency	Use confidence and deterministic SLA evidence to avoid misleading escalations.



8. Team 2 Project Brief
AI Fulfillment Exception and Customer Update Assistant
Field	Description
Phase 2 foundation	Order Fulfillment Tracking System
Phase 3 product direction	The Phase 2 system manages order state transitions, validates events, processes driver updates, and reports daily order operations. Phase 3 upgrades it into an exception-assist system that explains abnormal orders and drafts safe customer communication for review.
Primary AI goal	Detect fulfillment exceptions, explain likely causes, recommend operational action, and draft a customer-facing update message that is never sent automatically.
Non-AI baseline	Rule-based exception detection using order age, missing event milestones, invalid transition attempts, duplicate events, and status thresholds.

User personas
Fulfillment Operator: identifies orders requiring attention.
Customer Support Agent: uses a draft update message after review.
Operations Manager: tracks exception patterns and delivery performance.
Inputs and outputs
Input context	Required AI output fields
- Order details, current status, status timestamps, payment/refund status.
- Order event timeline and delivery notes from synthetic drivers.
- Daily order report aggregates and expected delivery threshold.
- Optional customer message style guidelines with no real customer data.	- exception_type
- severity
- likely_reason
- internal_next_action
- customer_update_draft
- confidence_score
- fallback_used

Required backend/API extension
Expose the AI feature through backend REST APIs; do not call the model directly from scripts only.
Add an internal AI adapter interface so tests can use a fake model implementation.
Persist AI results, prompt/template version, confidence, fallback reason, and timestamps in PostgreSQL.
Return consistent error responses and preserve request ID logging from Phase 2.
API endpoints	Suggested new tables
- POST /ai/orders/{id}/exception-analysis
- GET /ai/orders/{id}/insights/latest
- POST /ai/orders/customer-update-draft
- POST /ai/evaluations/order-exceptions	- ai_order_exception_results
- ai_customer_update_drafts
- ai_evaluation_runs

Acceptance criteria
Invalid state transitions remain blocked by deterministic domain rules, not by AI judgment.
AI may draft customer updates but must not send messages, refund orders, or change order status.
Customer message drafts must avoid unsupported promises and must not expose internal technical details.
At least 20 evaluation cases cover delayed shipment, duplicate event, invalid transition, missing delivery scan, and refund/cancel edge cases.
Demo includes one delayed order happy path and one AI timeout/fallback path.


Week-by-week backlog
Week	Backlog target
Week 9	Finalize charter, user stories, API contract, AI schema, baseline rules, evaluation case list, and reuse/refactor plan.
Week 10	Implement AI adapter, first endpoint, result persistence, fake AI tests, and a minimal happy path demo.
Week 11	Add batch/scan flow where applicable, retries/timeouts, fallback behavior, E2E tests, evaluation runner, and documentation.
Week 12	Freeze code, run final evaluation, prepare demo deck/runbook, tag release, and rehearse final peer review defence.

Final demo scenario
1. Create and progress an order through paid, packed, and shipped states.
2. Import driver events with one delayed/missing delivery signal and one duplicate event.
3. Run exception analysis and show severity, reason, internal action, and customer update draft.
4. Show logs proving the prompt version, duration, fallback reason, and safe response handling.
Main risks and controls
Risk	Control
Customer trust risk	AI-generated customer text must be clearly marked as a draft requiring human approval.
Business rule bypass	AI must never override payment/refund/status transition rules.
Sensitive data	Use synthetic customer/order data and mask identifiers before prompt construction.



9. Team 3 Project Brief
AI Inventory Anomaly and Replenishment Assistant
Field	Description
Phase 2 foundation	Inventory Movement Processing System
Phase 3 product direction	The Phase 2 system processes inventory movements, protects stock updates with transactions, prevents negative stock, and produces daily inventory reports. Phase 3 upgrades it into an anomaly-assist system that helps warehouse operators identify suspicious stock patterns and replenishment risks.
Primary AI goal	Analyze movement history and reporting data to detect anomaly patterns, explain likely causes, and recommend audit or replenishment actions without changing stock quantity.
Non-AI baseline	Rule-based detection using low-stock threshold, unusual OUT spike, repeated ADJUST movements, and deterministic negative-stock prevention.

User personas
Warehouse Operator: reviews flagged items and movement history.
Inventory Controller: decides whether to audit, adjust, or reorder.
Operations Manager: reviews low-stock and anomaly trends.
Inputs and outputs
Input context	Required AI output fields
- Inventory item data, current stock, low-stock threshold, SKU/category/location.
- Movement history: IN, OUT, ADJUST, quantity, timestamp, scanner/source.
- Daily inventory report aggregates, top active items, received/issued quantities.
- Optional warehouse policy notes using synthetic data.	- risk_type
- risk_level
- evidence_summary
- likely_cause
- recommended_action
- confidence_score
- fallback_used

Required backend/API extension
Expose the AI feature through backend REST APIs; do not call the model directly from scripts only.
Add an internal AI adapter interface so tests can use a fake model implementation.
Persist AI results, prompt/template version, confidence, fallback reason, and timestamps in PostgreSQL.
Return consistent error responses and preserve request ID logging from Phase 2.
API endpoints	Suggested new tables
- POST /ai/items/{id}/stock-risk
- POST /ai/inventory/anomalies:scan
- GET /ai/items/{id}/advice/latest
- POST /ai/evaluations/inventory-anomalies	- ai_inventory_risk_results
- ai_inventory_anomaly_runs
- ai_evaluation_cases

Acceptance criteria
Database transactions and deterministic stock validation remain the source of truth for stock balance.
AI must not create IN/OUT/ADJUST movements or modify item quantity.
Risk explanation must cite observable movement/report facts from the system response.
At least 20 evaluation cases cover low stock, OUT spike, repeated adjustment, duplicate movements, and no-risk normal items.
Demo includes one concurrent movement safety case and one AI fallback path.


Week-by-week backlog
Week	Backlog target
Week 9	Finalize charter, user stories, API contract, AI schema, baseline rules, evaluation case list, and reuse/refactor plan.
Week 10	Implement AI adapter, first endpoint, result persistence, fake AI tests, and a minimal happy path demo.
Week 11	Add batch/scan flow where applicable, retries/timeouts, fallback behavior, E2E tests, evaluation runner, and documentation.
Week 12	Freeze code, run final evaluation, prepare demo deck/runbook, tag release, and rehearse final peer review defence.

Final demo scenario
1. Create an item with low-stock threshold and import several movement batches.
2. Show transaction-safe processing still prevents negative stock under concurrent requests.
3. Run anomaly scan and show top flagged items with risk explanations and recommended actions.
4. Force AI low-confidence/invalid output and show deterministic threshold fallback.
Main risks and controls
Risk	Control
Inventory integrity	AI recommendations must never bypass transaction-safe stock movement processing.
False positives	Risk explanation should show movement evidence so operators can verify the recommendation.
Cost/performance	Batch anomaly scans must limit item count, input size, and concurrent AI calls.


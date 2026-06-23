-- ============================================================
-- Internal Knowledge Base — Schema & Seed Data
-- Support Ticket SLA Processing System
-- AI Ticket Triage & Smart Routing Engine
--
-- Purpose:
--   1. departments / sub_departments / rule_patterns / sample_tickets
--      hold the structured Knowledge Base used by the Rule Engine
--      (rule_patterns.pattern) and by RAG Retrieval
--      (sub_departments.description -> embedding).
--
-- Requirements:
--   - PostgreSQL with the "vector" extension (pgvector) installed.
--   - Adjust the VECTOR(n) dimension below to match your embedding
--     model's output size (e.g. 1024 for bge-m3, 1536 for some
--     OpenAI-compatible models). Default here: 1024.
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;

-- ----------------------------------------------------------------
-- 1. departments — top-level organizational units
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    code        VARCHAR(10) PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------
-- 2. sub_departments — routing target for ticket classification.
--    `description` is the ONLY field used to generate the embedding.
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sub_departments (
    code             VARCHAR(10) PRIMARY KEY,
    department_code  VARCHAR(10) NOT NULL REFERENCES departments(code),
    name             VARCHAR(200) NOT NULL,
    floor            VARCHAR(30),
    description      TEXT NOT NULL,
    embedding        VECTOR(512) NULL,          -- populate after embedding generation
    embedding_model  VARCHAR(100),          -- e.g. 'bge-m3', for traceability
    embedding_updated_at TIMESTAMPTZ,
    is_active        BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sub_departments_department_code
    ON sub_departments(department_code);

-- Vector similarity index (cosine distance). Build/rebuild after
-- embeddings are populated and the table has a meaningful row count.
-- CREATE INDEX idx_sub_departments_embedding
--     ON sub_departments USING hnsw (embedding vector_cosine_ops);

-- ----------------------------------------------------------------
-- 3. rule_patterns — Rule Engine fast-path patterns.
--    Each pattern maps to exactly one sub_department.
--    `priority` is the rule's own priority (higher = checked first),
--    NOT the ticket's user-submitted priority field — keep these two
--    concepts separate when implementing the Rule Engine.
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rule_patterns (
    id                   SERIAL PRIMARY KEY,
    sub_department_code  VARCHAR(10) NOT NULL REFERENCES sub_departments(code),
    pattern              TEXT NOT NULL,      -- keyword or regex, lowercase match
    pattern_type         VARCHAR(20) NOT NULL DEFAULT 'keyword', -- 'keyword' | 'regex'
    priority             VARCHAR(20) NOT NULL, -- 'low' | 'medium' | 'high'
    is_active            BOOLEAN NOT NULL DEFAULT true,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rule_patterns_sub_department
    ON rule_patterns(sub_department_code);
CREATE INDEX IF NOT EXISTS idx_rule_patterns_priority
    ON rule_patterns(priority);

-- ----------------------------------------------------------------
-- 4. sample_tickets — Historical data for Hybrid RAG (K-NN Search)
--    These tickets are embedded to form the primary vector database.
--    When a new ticket arrives, the AI retrieves the top-k most 
--    similar sample tickets to determine the correct sub_department.
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sample_tickets (
    id                   SERIAL PRIMARY KEY,
    sub_department_code  VARCHAR(10) NOT NULL REFERENCES sub_departments(code),
    sample_text          TEXT NOT NULL,
    embedding            VECTOR(512) NULL,          -- Vector representation of the ticket
    embedding_model      VARCHAR(100),          -- e.g., 'bge-m3'
    embedding_updated_at TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sample_tickets_sub_department
    ON sample_tickets(sub_department_code);

-- ----------------------------------------------------------------
-- 5. unified_knowledge_base (VIEW) — Unified search space for RAG
--    Combines sub_department descriptions and sample tickets into
--    a single queryable vector space for the Backend.
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW unified_knowledge_base AS
SELECT 
    'policy' AS source_type,
    code AS sub_department_code,
    description AS content_text,
    embedding
FROM sub_departments
WHERE is_active = true
UNION ALL
SELECT 
    'example' AS source_type,
    sub_department_code,
    sample_text AS content_text,
    embedding
FROM sample_tickets;

COMMIT;

-- ============================================================
-- SEED DATA
-- ============================================================

BEGIN;

-- ----------------------------------------------------------------
-- Departments
-- ----------------------------------------------------------------
INSERT INTO departments (code, name) VALUES
    ('IT', 'Information Technology'),
    ('FC', 'Facilities & Administration'),
    ('HR', 'Human Resources')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, updated_at = now();

-- ----------------------------------------------------------------
-- Sub-departments (9 rows)
-- ----------------------------------------------------------------

-- IT001 — Hardware & Logistics
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'IT001',
    'IT',
    'Hardware Inventory & Equipment Provisioning',
    'Floor 18',
    'Handles physical hardware equipment for employees: issuing new equipment, replacing or repairing broken hardware, and temporary equipment loans. Covers items such as keyboards, mice, laptops, monitors, headsets, cables, and upgrade components. This team does not handle network configuration, operating system issues, or account access problems — those belong to IT002 and IT003 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- IT002 — Network & Software Support
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'IT002',
    'IT',
    'Network Infrastructure & System Software Support',
    'Floor 18',
    'Handles network configuration, operating system installation (Windows, macOS), internal software errors, Wi-Fi or VPN connectivity failures, and shared folder access permissions. This team does not issue physical hardware and does not manage account credentials, password resets, or security incidents — those belong to IT001 and IT003 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- IT003 — Account & Cyber Security
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'IT003',
    'IT',
    'Account & Cyber Security',
    'Floor 19',
    'Handles employee login accounts and information security: resetting email passwords, unlocking or creating accounts on internal systems such as Active Directory, Slack, and Jira, provisioning or revoking access for new or departing employees, and responding to suspected malware or phishing incidents. This team does not handle network connectivity problems or software installation — those belong to IT002.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- FC001 — Workplace & Utilities
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'FC001',
    'FC',
    'Workplace & Utilities',
    'Floor 18',
    'Handles physical office facility issues: electricity, water, air conditioning that is too hot or too cold, broken desks and chairs, malfunctioning lighting, repairs to windows or doors, and requests for office area cleaning. This team does not handle office supplies, pantry items, badge access, or company vehicle bookings — those belong to FC003 and FC002 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- FC002 — Reception, Mail & Transportation
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'FC002',
    'FC',
    'Reception, Mail & Transportation',
    'Lobby / Ground Floor',
    'Handles front-desk and logistics services: sending and receiving mail or courier packages, booking company vehicles for business trips, issuing or replacing employee access badges, and reserving large meeting rooms or internal event spaces. This team does not handle office facility repairs or office supplies — those belong to FC001 and FC003 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- FC003 — Office Supplies & Pantry
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'FC003',
    'FC',
    'Office Supplies & Pantry',
    'Floor 18',
    'Handles distribution of office supplies such as printer paper, pens, notebooks, and ink cartridges, as well as managing pantry items including tea, coffee, drinking water, and paper towels. This team does not handle facility repairs, badge access, or transportation bookings — those belong to FC001 and FC002 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- HR001 — Compensation & Benefits
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'HR001',
    'HR',
    'Compensation & Benefits (C&B)',
    'Floor 12A',
    'Handles questions and corrections related to employee pay and benefits: payroll discrepancies, annual leave balances, social insurance (BHXH), health insurance providers such as PVI or Bao Viet, allowances, and personal income tax matters. This team does not handle training registration or resignation procedures — those belong to HR002 and HR003 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- HR002 — Talent Acquisition & Learning and Development
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'HR002',
    'HR',
    'Talent Acquisition & Learning and Development (L&D)',
    'Floor 12A',
    'Handles new employee onboarding support such as preparing a workstation for a new hire, registration for internal or external training courses, and individual training budget requests. This team does not handle payroll or benefits questions, and does not handle resignation or workplace conflict matters — those belong to HR001 and HR003 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

-- HR003 — Employee Relations & Culture
INSERT INTO sub_departments (code, department_code, name, floor, description)
VALUES (
    'HR003',
    'HR',
    'Employee Relations & Culture',
    'Floor 12A',
    'Handles feedback about the work environment, resolution of internal workplace conflicts, resignation and offboarding procedures, and input on team building or year-end party activities. This team does not handle payroll, benefits, or training registration — those belong to HR001 and HR002 respectively.'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name, floor = EXCLUDED.floor,
    description = EXCLUDED.description,
    updated_at = now();

COMMIT;

-- ----------------------------------------------------------------
-- Rule patterns
-- One row per keyword/pattern, mapped to its sub_department.
-- Priority guidance: distinctive, single-department terms get
-- higher priority (200); broader terms shared across possible
-- overlaps get lower priority (100) so they are checked last and
-- ambiguous tickets fall through to RAG + AI instead of being
-- mis-routed with false confidence.
-- ----------------------------------------------------------------

BEGIN;

-- IT001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT001', 'new laptop request', 'keyword', 'high'),
    ('IT001', 'broken keyboard', 'keyword', 'high'),
    ('IT001', 'broken mouse', 'keyword', 'high'),
    ('IT001', 'monitor not working', 'keyword', 'high'),
    ('IT001', 'headset replacement', 'keyword', 'high'),
    ('IT001', 'laptop charger broken', 'keyword', 'high'),
    ('IT001', 'temporary equipment loan', 'keyword', 'medium'),
    ('IT001', 'hardware warranty', 'keyword', 'medium'),
    ('IT001', 'damaged screen', 'keyword', 'medium');

-- IT002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT002', 'no internet connection', 'keyword', 'high'),
    ('IT002', 'wifi not working', 'keyword', 'high'),
    ('IT002', 'vpn not connecting', 'keyword', 'high'),
    ('IT002', 'cannot connect to vpn', 'keyword', 'high'),
    ('IT002', 'software installation error', 'keyword', 'medium'),
    ('IT002', 'os installation', 'keyword', 'medium'),
    ('IT002', 'shared drive access', 'keyword', 'medium'),
    ('IT002', 'network down', 'keyword', 'medium'),
    ('IT002', 'slow internet', 'keyword', 'medium');

-- IT003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT003', 'reset password', 'keyword', 'high'),
    ('IT003', 'forgot password', 'keyword', 'high'),
    ('IT003', 'account locked', 'keyword', 'high'),
    ('IT003', 'active directory', 'keyword', 'high'),
    ('IT003', 'suspected phishing', 'keyword', 'high'),
    ('IT003', 'malware alert', 'keyword', 'high'),
    ('IT003', 'suspicious email', 'keyword', 'medium'),
    ('IT003', 'mfa issue', 'keyword', 'medium'),
    ('IT003', 'two factor authentication', 'keyword', 'medium');

-- FC001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC001', 'air conditioning broken', 'keyword', 'high'),
    ('FC001', 'ac not cooling', 'keyword', 'high'),
    ('FC001', 'broken chair', 'keyword', 'high'),
    ('FC001', 'broken desk', 'keyword', 'high'),
    ('FC001', 'light not working', 'keyword', 'medium'),
    ('FC001', 'water leak', 'keyword', 'medium'),
    ('FC001', 'power outage', 'keyword', 'medium'),
    ('FC001', 'cleaning request', 'keyword', 'low');

-- FC002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC002', 'send courier', 'keyword', 'high'),
    ('FC002', 'book company car', 'keyword', 'high'),
    ('FC002', 'replace employee badge', 'keyword', 'high'),
    ('FC002', 'lost badge', 'keyword', 'high'),
    ('FC002', 'book meeting room', 'keyword', 'medium'),
    ('FC002', 'reserve event space', 'keyword', 'medium');

-- FC003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC003', 'request office supplies', 'keyword', 'high'),
    ('FC003', 'need printer paper', 'keyword', 'high'),
    ('FC003', 'out of pens', 'keyword', 'high'),
    ('FC003', 'no coffee', 'keyword', 'medium'),
    ('FC003', 'pantry restock', 'keyword', 'medium'),
    ('FC003', 'printer ink request', 'keyword', 'medium');

-- HR001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR001', 'payroll error', 'keyword', 'high'),
    ('HR001', 'wrong salary', 'keyword', 'high'),
    ('HR001', 'social insurance', 'keyword', 'high'),
    ('HR001', 'bhxh', 'keyword', 'high'),
    ('HR001', 'maternity leave benefit', 'keyword', 'high'),
    ('HR001', 'health insurance pvi', 'keyword', 'medium'),
    ('HR001', 'bao viet insurance', 'keyword', 'medium'),
    ('HR001', 'personal income tax', 'keyword', 'medium'),
    ('HR001', 'dependent declaration', 'keyword', 'medium');

-- HR002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR002', 'register training course', 'keyword', 'high'),
    ('HR002', 'request training budget', 'keyword', 'high'),
    ('HR002', 'prepare desk for new hire', 'keyword', 'medium'),
    ('HR002', 'external course registration', 'keyword', 'medium'),
    ('HR002', 'recruitment request', 'keyword', 'medium'),
    ('HR002', 'new employee orientation', 'keyword', 'medium');

-- HR003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR003', 'resignation procedure', 'keyword', 'high'),
    ('HR003', 'offboarding process', 'keyword', 'high'),
    ('HR003', 'workplace conflict', 'keyword', 'high'),
    ('HR003', 'harassment report', 'keyword', 'high'),
    ('HR003', 'team building suggestion', 'keyword', 'low'),
    ('HR003', 'year end party feedback', 'keyword', 'low');

COMMIT;

-- ----------------------------------------------------------------
-- Sample tickets — retrieval & rule-match test fixtures
-- (never embedded, never sent to the AI model)
-- ----------------------------------------------------------------

BEGIN;

INSERT INTO sample_tickets (sub_department_code, sample_text) VALUES
    ('IT001', 'Kindly provision a new wireless mouse for the upcoming new hire starting next week.'),
    ('IT001', 'Please dispatch someone to check and replace my Dell monitor. Current status: it was dropped and shattered.'),
    ('IT001', 'I need to request a replacement wireless mouse as my current one keeps losing signal.'),
    ('IT001', 'I need to request a replacement external webcam as my current one has a frayed cable.'),
    ('IT001', 'Please dispatch someone to check and replace my laptop. Current status: it is randomly disconnecting.'),
    ('IT001', 'I need to request a temporary loaner Dell monitor for an upcoming business trip.'),
    ('IT001', 'Please dispatch someone to check and replace my laptop. Current status: it keeps losing signal.'),
    ('IT001', 'Please dispatch someone to check and replace my laptop stand. Current status: it has a frayed cable.'),
    ('IT001', 'Kindly provision a new USB-C to HDMI adapter for the upcoming new hire starting next week.'),
    ('IT001', 'I would like to file a warranty claim for my laptop; I noticed it has water damage.'),
    ('IT001', 'Please dispatch someone to check and replace my charging cable. Current status: it has sticky keys.'),
    ('IT001', 'I need to request a replacement Dell monitor as my current one is flickering constantly.'),
    ('IT001', 'I need to request a replacement wireless mouse as my current one has a frayed cable.'),
    ('IT001', 'I need to request a temporary loaner charging cable for an upcoming business trip.'),
    ('IT001', 'I would like to file a warranty claim for my noise-canceling headset; I noticed it is completely broken.'),
    ('IT001', 'Can someone from IT check my laptop stand? It is randomly disconnecting out of nowhere.'),
    ('IT001', 'Do we have any spare wireless mouses? I need to borrow one for a few days.'),
    ('IT001', 'My desk setup is missing a external webcam, please help me get one.'),
    ('IT001', 'Hey IT, my Dell monitor is randomly disconnecting, can I get a swap?'),
    ('IT001', 'Hey IT, my Dell monitor has sticky keys, can I get a swap?'),
    ('IT001', 'Can someone from IT check my Dell monitor? It is randomly disconnecting out of nowhere.'),
    ('IT001', 'Do we have any spare noise-canceling headsets? I need to borrow one for a few days.'),
    ('IT001', 'Do we have any spare mechanical keyboards? I need to borrow one for a few days.'),
    ('IT001', 'Hey IT, my Dell monitor has sticky keys, can I get a swap?'),
    ('IT001', 'My desk setup is missing a external webcam, please help me get one.'),
    ('IT001', 'Can someone from IT check my Dell monitor? It has water damage out of nowhere.'),
    ('IT001', 'My desk setup is missing a MacBook charger, please help me get one.'),
    ('IT001', 'Hey IT, my Dell monitor is flickering constantly, can I get a swap?'),
    ('IT001', 'Do we have any spare Dell monitors? I need to borrow one for a few days.'),
    ('IT001', 'Hey IT, my MacBook charger has sticky keys, can I get a swap?'),
    ('IT001', 'need a new monitor asap it static noise'),
    ('IT001', 'can i barrow a monitor'),
    ('IT001', 'need a new adapter asap it water damaged'),
    ('IT001', 'fix my keyboard pls its shattered cant work'),
    ('IT001', 'fix my stand pls its sticky keys cant work'),
    ('IT001', 'can i barrow a charger'),
    ('IT001', 'it guys can u swap my cable it shattered'),
    ('IT001', 'my stand not charging pls fix it'),
    ('IT001', 'it guys can u swap my laptap it disconnecting'),
    ('IT001', 'fix my keyboard pls its frayed cant work'),
    ('IT001', 'Our department is onboarding 3 new members next week. IT, please prepare 3 wireless mouses and thoroughly test them so they don''t end up has a frayed cable right away.'),
    ('IT001', 'Our department is onboarding 3 new members next week. IT, please prepare 3 USB-C to HDMI adapters and thoroughly test them so they don''t end up has sticky keys right away.'),
    ('IT001', 'Besides the fact that my laptop keeps losing signal, I''d also like to request an additional one for working from home if possible.'),
    ('IT001', 'Besides the fact that my charging cable has sticky keys, I''d also like to request an additional one for working from home if possible.'),
    ('IT001', 'Our department is onboarding 3 new members next week. IT, please prepare 3 mechanical keyboards and thoroughly test them so they don''t end up is completely broken right away.'),
    ('IT001', 'Our department is onboarding 3 new members next week. IT, please prepare 3 noise-canceling headsets and thoroughly test them so they don''t end up has water damage right away.'),
    ('IT001', 'Our department is onboarding 3 new members next week. IT, please prepare 3 wireless mouses and thoroughly test them so they don''t end up keeps losing signal right away.'),
    ('IT001', 'I turned on my workstation this morning and saw that the Dell monitor is flickering constantly. I have a massive presentation this Friday and really need IT to resolve this urgently.'),
    ('IT001', 'Our department is onboarding 3 new members next week. IT, please prepare 3 laptop stands and thoroughly test them so they don''t end up is completely broken right away.'),
    ('IT001', 'I turned on my workstation this morning and saw that the charging cable is completely broken. I have a massive presentation this Friday and really need IT to resolve this urgently.'),
    ('IT002', 'Please verify the configuration of the macOS system for our department; currently it is stuck on the loading screen.'),
    ('IT002', 'Please grant me access to the office Wi-Fi so I can retrieve project documents.'),
    ('IT002', 'I have been experiencing persistent issues with the VPN connection is extremely slow since this morning.'),
    ('IT002', 'Please verify the configuration of the VPN connection for our department; currently it shows a permission denied error.'),
    ('IT002', 'I require assistance installing the Office 365 suite on my assigned workstation.'),
    ('IT002', 'Please verify the configuration of the local admin account for our department; currently it is giving a server connection error.'),
    ('IT002', 'I require assistance installing the local admin account on my assigned workstation.'),
    ('IT002', 'I have been experiencing persistent issues with the Windows OS cannot be accessed since this morning.'),
    ('IT002', 'The system is throwing an error when I try to access the local admin account. It is completely unresponsive.'),
    ('IT002', 'The system is throwing an error when I try to access the accounting tool. It keeps crashing.'),
    ('IT002', 'Please grant me access to the macOS system so I can retrieve project documents.'),
    ('IT002', 'Please grant me access to the local admin account so I can retrieve project documents.'),
    ('IT002', 'The system is throwing an error when I try to access the accounting tool. It is completely unreachable.'),
    ('IT002', 'The system is throwing an error when I try to access the office Wi-Fi. It keeps crashing.'),
    ('IT002', 'The system is throwing an error when I try to access the office Wi-Fi. It cannot be accessed.'),
    ('IT002', 'IT, please take a look at the local admin account, it keeps crashing and I can''t get any work done.'),
    ('IT002', 'What''s wrong with the network today? The Office 365 suite keeps crashing constantly.'),
    ('IT002', 'Is the design software down for maintenance? It is completely unresponsive for me.'),
    ('IT002', 'Is the Office 365 suite down for maintenance? It is giving a server connection error for me.'),
    ('IT002', 'Can someone install the VPN connection on my new machine?'),
    ('IT002', 'Can someone install the macOS system on my new machine?'),
    ('IT002', 'Hey guys, the Office 365 suite is completely unreachable again, anyone else seeing this?'),
    ('IT002', 'IT, please take a look at the office Wi-Fi, it is giving a server connection error and I can''t get any work done.'),
    ('IT002', 'Is the VPN connection down for maintenance? It keeps crashing for me.'),
    ('IT002', 'Is the accounting tool down for maintenance? It is completely unresponsive for me.'),
    ('IT002', 'IT, please take a look at the Windows OS, it shows a permission denied error and I can''t get any work done.'),
    ('IT002', 'Hey guys, the Office 365 suite keeps crashing again, anyone else seeing this?'),
    ('IT002', 'Hey guys, the Office 365 suite is extremely slow again, anyone else seeing this?'),
    ('IT002', 'Hey guys, the local admin account is completely unreachable again, anyone else seeing this?'),
    ('IT002', 'Can someone install the accounting tool on my new machine?'),
    ('IT002', 'cant login to office it unresponsive'),
    ('IT002', 'cant login to windows it unreachable'),
    ('IT002', 'pls install windows for me'),
    ('IT002', 'need access to shared drive pls'),
    ('IT002', 'cant login to windows it unresponsive'),
    ('IT002', 'cant login to accounting tool it stuck'),
    ('IT002', 'need access to wifi pls'),
    ('IT002', 'the wifi is so unreachable today'),
    ('IT002', 'office permission error again'),
    ('IT002', 'cant login to admin account it slow'),
    ('IT002', 'In preparation for next week''s sprint review, our team needs stable access to the VPN connection, but lately it is extremely slow. Can IT do a full check on the 18th floor infrastructure?'),
    ('IT002', 'In preparation for next week''s sprint review, our team needs stable access to the accounting tool, but lately it is extremely slow. Can IT do a full check on the 18th floor infrastructure?'),
    ('IT002', 'In preparation for next week''s sprint review, our team needs stable access to the accounting tool, but lately it is completely unreachable. Can IT do a full check on the 18th floor infrastructure?'),
    ('IT002', 'I''m trying to download a huge client dataset but the VPN connection cannot be accessed. Can you also check the PC next to mine because it''s having the exact same problem?'),
    ('IT002', 'I''m trying to download a huge client dataset but the accounting tool keeps crashing. Can you also check the PC next to mine because it''s having the exact same problem?'),
    ('IT002', 'I''m trying to download a huge client dataset but the Windows OS is stuck on the loading screen. Can you also check the PC next to mine because it''s having the exact same problem?'),
    ('IT002', 'I''m trying to download a huge client dataset but the macOS system is completely unreachable. Can you also check the PC next to mine because it''s having the exact same problem?'),
    ('IT002', 'Ever since the system update yesterday, my LAN network is extremely slow. I''ve tried rebooting three times but nothing works, can IT please remote in and fix this?'),
    ('IT002', 'Ever since the system update yesterday, my local admin account is stuck on the loading screen. I''ve tried rebooting three times but nothing works, can IT please remote in and fix this?'),
    ('IT002', 'I''m trying to download a huge client dataset but the macOS system keeps crashing. Can you also check the PC next to mine because it''s having the exact same problem?'),
    ('IT003', 'I need to request the immediate revocation of the YubiKey for a contractor who left.'),
    ('IT003', 'I cannot pass the authentication step using my YubiKey; the screen shows it is failing to log in.'),
    ('IT003', 'I cannot pass the authentication step using my email password; the screen shows it is asking for an admin override.'),
    ('IT003', 'I require assistance resetting my YubiKey as the system indicates it is asking for an admin override.'),
    ('IT003', 'I require assistance resetting my antivirus software as the system indicates it is not being recognized.'),
    ('IT003', 'I cannot pass the authentication step using my Active Directory account; the screen shows it is asking for an admin override.'),
    ('IT003', 'Our security monitoring tool flagged an anomaly: my antivirus software is not being recognized.'),
    ('IT003', 'Our security monitoring tool flagged an anomaly: my Jira account is asking for an admin override.'),
    ('IT003', 'Our security monitoring tool flagged an anomaly: my Jira account is asking for an admin override.'),
    ('IT003', 'I require assistance resetting my Slack account as the system indicates it is not being recognized.'),
    ('IT003', 'I need to request the immediate revocation of the Active Directory account for a contractor who left.'),
    ('IT003', 'I require assistance resetting my YubiKey as the system indicates it is locked due to failed attempts.'),
    ('IT003', 'Please provision a new two-factor authentication (MFA) for the employee joining our team.'),
    ('IT003', 'I need to request the immediate revocation of the YubiKey for a contractor who left.'),
    ('IT003', 'I require assistance resetting my SSO portal as the system indicates it is failing to log in.'),
    ('IT003', 'Can you create a Active Directory account for our new intern?'),
    ('IT003', 'I plugged in my email password but it is showing a security error, can IT check it?'),
    ('IT003', 'Can you create a antivirus software for our new intern?'),
    ('IT003', 'I plugged in my email password but it is not being recognized, can IT check it?'),
    ('IT003', 'Can you create a email password for our new intern?'),
    ('IT003', 'Hey IT, please unlock my Jira account, I typed it wrong too many times and it is asking for an admin override.'),
    ('IT003', 'Why is my two-factor authentication (MFA) is showing a security error every time I try to log in today?'),
    ('IT003', 'Can you create a SSO portal for our new intern?'),
    ('IT003', 'Can you create a Jira account for our new intern?'),
    ('IT003', 'Hey IT, please unlock my antivirus software, I typed it wrong too many times and it has an expired token.'),
    ('IT003', 'I plugged in my antivirus software but it is asking for an admin override, can IT check it?'),
    ('IT003', 'Can you create a SSO portal for our new intern?'),
    ('IT003', 'Hey IT, please unlock my YubiKey, I typed it wrong too many times and it is triggering a malware alert.'),
    ('IT003', 'Hey IT, please unlock my SSO portal, I typed it wrong too many times and it is showing a security error.'),
    ('IT003', 'Can you create a Slack account for our new intern?'),
    ('IT003', 'make a slack for the new guy'),
    ('IT003', 'reset my jira pls'),
    ('IT003', 'make a jira for the new guy'),
    ('IT003', 'reset my yubikey pls'),
    ('IT003', 'delete yubikey for the guy who left'),
    ('IT003', 'delete sso for the guy who left'),
    ('IT003', 'reset my 2fa pls'),
    ('IT003', 'delete yubikey for the guy who left'),
    ('IT003', 'reset my yubikey pls'),
    ('IT003', 'make a sso for the new guy'),
    ('IT003', 'The sales department just offboarded 5 people today. I need IT to immediately review and revoke all their SSO portal access to prevent any data leaks.'),
    ('IT003', 'The sales department just offboarded 5 people today. I need IT to immediately review and revoke all their Jira account access to prevent any data leaks.'),
    ('IT003', 'The sales department just offboarded 5 people today. I need IT to immediately review and revoke all their SSO portal access to prevent any data leaks.'),
    ('IT003', 'I''m currently traveling abroad without my work phone, and my Jira account has an expired token. Is there any temporary bypass IT can provide so I can urgently check my email?'),
    ('IT003', 'I''m currently traveling abroad without my work phone, and my two-factor authentication (MFA) is asking for an admin override. Is there any temporary bypass IT can provide so I can urgently check my email?'),
    ('IT003', 'I accidentally clicked a strange link and now I''m getting a notification that my YubiKey is asking for an admin override. Can IT run a full sweep and force a password reset for safety?'),
    ('IT003', 'I accidentally clicked a strange link and now I''m getting a notification that my two-factor authentication (MFA) is asking for an admin override. Can IT run a full sweep and force a password reset for safety?'),
    ('IT003', 'The sales department just offboarded 5 people today. I need IT to immediately review and revoke all their antivirus software access to prevent any data leaks.'),
    ('IT003', 'The sales department just offboarded 5 people today. I need IT to immediately review and revoke all their SSO portal access to prevent any data leaks.'),
    ('IT003', 'I''m currently traveling abroad without my work phone, and my YubiKey is failing to log in. Is there any temporary bypass IT can provide so I can urgently check my email?'),
    ('FC001', 'Please adjust the temperature controls for the swivel chair in meeting room A, it is jammed shut.'),
    ('FC001', 'Please schedule a routine check for the pantry sink as I suspect it has a power short.'),
    ('FC001', 'Please adjust the temperature controls for the floor carpet in meeting room A, it is way too hot.'),
    ('FC001', 'Please adjust the temperature controls for the window blind in meeting room A, it is way too hot.'),
    ('FC001', 'Our department requires cleaning services for the fluorescent light because it is jammed shut.'),
    ('FC001', 'Please adjust the temperature controls for the power outlet in meeting room A, it is leaking water onto the floor.'),
    ('FC001', 'Please adjust the temperature controls for the swivel chair in meeting room A, it is completely broken.'),
    ('FC001', 'I would like to request maintenance for the glass door on the 18th floor. Current status: it is not working at all.'),
    ('FC001', 'Our department requires cleaning services for the office desk because it is way too hot.'),
    ('FC001', 'Please schedule a routine check for the fluorescent light as I suspect it is way too hot.'),
    ('FC001', 'Please schedule a routine check for the office desk as I suspect it smells terrible.'),
    ('FC001', 'Please adjust the temperature controls for the pantry sink in meeting room A, it is completely broken.'),
    ('FC001', 'Please schedule a routine check for the air conditioning as I suspect it is leaking water onto the floor.'),
    ('FC001', 'Our department requires cleaning services for the office desk because it is flickering non-stop.'),
    ('FC001', 'Our department requires cleaning services for the floor carpet because it is not working at all.'),
    ('FC001', 'My office desk is ruined, can I get a replacement from Facilities?'),
    ('FC001', 'Water is spilling everywhere because the glass door is way too hot, please send a cleaner ASAP.'),
    ('FC001', 'My window blind is ruined, can I get a replacement from Facilities?'),
    ('FC001', 'Water is spilling everywhere because the window blind smells terrible, please send a cleaner ASAP.'),
    ('FC001', 'My floor carpet is ruined, can I get a replacement from Facilities?'),
    ('FC001', 'Can someone fix the floor carpet? It is jammed shut and it''s impossible to work.'),
    ('FC001', 'My swivel chair is ruined, can I get a replacement from Facilities?'),
    ('FC001', 'My office desk is ruined, can I get a replacement from Facilities?'),
    ('FC001', 'Can someone fix the fluorescent light? It is jammed shut and it''s impossible to work.'),
    ('FC001', 'The room is so uncomfortable, the swivel chair has a power short, please adjust it.'),
    ('FC001', 'Can someone fix the window blind? It is leaking water onto the floor and it''s impossible to work.'),
    ('FC001', 'My glass door is ruined, can I get a replacement from Facilities?'),
    ('FC001', 'Admin team, please send someone to check the glass door, it is completely broken since this morning.'),
    ('FC001', 'The room is so uncomfortable, the pantry sink smells terrible, please adjust it.'),
    ('FC001', 'My window blind is ruined, can I get a replacement from Facilities?'),
    ('FC001', 'swap my ac pls'),
    ('FC001', 'the sink in my room is broken today'),
    ('FC001', 'fix the sink it too hot'),
    ('FC001', 'swap my outlet pls'),
    ('FC001', 'the sink in my room is too cold today'),
    ('FC001', 'the desk on floor 18 is too hot'),
    ('FC001', 'swap my chair pls'),
    ('FC001', 'need someone to clean the ac it smells'),
    ('FC001', 'swap my sink pls'),
    ('FC001', 'fix the door it too cold'),
    ('FC001', 'I reported that the pantry sink is leaking water onto the floor last week and no one has come to fix it yet. The situation has worsened, please resolve this urgently today.'),
    ('FC001', 'The pantry sink in my cubicle is way too hot, and the pantry sink in the adjacent room is also broken. Could Facilities send a technician to fix both at once?'),
    ('FC001', 'We have VIP guests arriving next week, please deep clean the carpets and thoroughly inspect the air conditioning to make sure it doesn''t end up smells terrible like last time.'),
    ('FC001', 'We have VIP guests arriving next week, please deep clean the carpets and thoroughly inspect the office desk to make sure it doesn''t end up has a power short like last time.'),
    ('FC001', 'We have VIP guests arriving next week, please deep clean the carpets and thoroughly inspect the pantry sink to make sure it doesn''t end up smells terrible like last time.'),
    ('FC001', 'I reported that the fluorescent light is not working at all last week and no one has come to fix it yet. The situation has worsened, please resolve this urgently today.'),
    ('FC001', 'The window blind in my cubicle has a power short, and the window blind in the adjacent room is also broken. Could Facilities send a technician to fix both at once?'),
    ('FC001', 'The fluorescent light in my cubicle is not working at all, and the fluorescent light in the adjacent room is also broken. Could Facilities send a technician to fix both at once?'),
    ('FC001', 'The office desk in my cubicle is flickering non-stop, and the office desk in the adjacent room is also broken. Could Facilities send a technician to fix both at once?'),
    ('FC001', 'I reported that the glass door is leaking water onto the floor last week and no one has come to fix it yet. The situation has worsened, please resolve this urgently today.'),
    ('FC002', 'I would like to request a replacement flight ticket as mine is arriving late.'),
    ('FC002', 'We need to prepare the large meeting room for a seminar, please keep in mind it has the wrong address.'),
    ('FC002', 'I need to reserve the express shipping service for next Friday.'),
    ('FC002', 'We need to prepare the employee badge for a seminar, please keep in mind it is needed urgently this afternoon.'),
    ('FC002', 'We need to prepare the courier package for a seminar, please keep in mind it has a broken magnetic strip.'),
    ('FC002', 'I need to reserve the event space for next Friday.'),
    ('FC002', 'Please book a mail for the CEO''s upcoming business trip; note that it has not been issued yet.'),
    ('FC002', 'We need to prepare the employee badge for a seminar, please keep in mind it is needed urgently this afternoon.'),
    ('FC002', 'We need to prepare the courier package for a seminar, please keep in mind it needs a projector setup.'),
    ('FC002', 'Please book a event space for the CEO''s upcoming business trip; note that it needs a projector setup.'),
    ('FC002', 'Please book a stationery delivery for the CEO''s upcoming business trip; note that it needs a projector setup.'),
    ('FC002', 'Please book a event space for the CEO''s upcoming business trip; note that it is arriving late.'),
    ('FC002', 'Could Reception track the event space sent to the Da Nang branch? It currently shows it needs a projector setup.'),
    ('FC002', 'I need to reserve the company car for next Friday.'),
    ('FC002', 'We need to prepare the stationery delivery for a seminar, please keep in mind it has a broken magnetic strip.'),
    ('FC002', 'I have a stationery delivery visiting today, please welcome them and guide them to floor 18.'),
    ('FC002', 'I lost my event space, can you print me a new one?'),
    ('FC002', 'I lost my flight ticket, can you print me a new one?'),
    ('FC002', 'I have a VIP guest visiting today, please welcome them and guide them to floor 18.'),
    ('FC002', 'I lost my express shipping service, can you print me a new one?'),
    ('FC002', 'I lost my courier package, can you print me a new one?'),
    ('FC002', 'Has my company car arrived yet? It is arriving late.'),
    ('FC002', 'I lost my large meeting room, can you print me a new one?'),
    ('FC002', 'Is the employee badge available this afternoon? I need to book it because my other room has a broken magnetic strip.'),
    ('FC002', 'Reception, please book a courier package for my client meeting this afternoon.'),
    ('FC002', 'I have a flight ticket visiting today, please welcome them and guide them to floor 18.'),
    ('FC002', 'I have a stationery delivery visiting today, please welcome them and guide them to floor 18.'),
    ('FC002', 'Reception, please book a VIP guest for my client meeting this afternoon.'),
    ('FC002', 'Has my mail arrived yet? It has a broken magnetic strip.'),
    ('FC002', 'I lost my event space, can you print me a new one?'),
    ('FC002', 'send this shipping to dist 1 it needs projector'),
    ('FC002', 'send this delivery to dist 1 it needs projector'),
    ('FC002', 'need new delivery mine is needs projector'),
    ('FC002', 'need new guest mine is broken'),
    ('FC002', 'book a badge for my trip tmrw'),
    ('FC002', 'book a flight for my trip tmrw'),
    ('FC002', 'did my delivery arrive'),
    ('FC002', 'need new flight mine is late'),
    ('FC002', 'book a shipping for my trip tmrw'),
    ('FC002', 'did my flight arrive'),
    ('FC002', 'We are expecting a delegation of 10 large meeting rooms from overseas next week. Reception, please arrange a large meeting room for airport pickup and prepare a polite waiting area.'),
    ('FC002', 'We are expecting a delegation of 10 stationery deliverys from overseas next week. Reception, please arrange a stationery delivery for airport pickup and prepare a polite waiting area.'),
    ('FC002', 'I dropped my courier package in the lobby yesterday. If security found it, please let me know. I can''t swipe through the doors and it''s has a broken magnetic strip.'),
    ('FC002', 'We are expecting a delegation of 10 company cars from overseas next week. Reception, please arrange a company car for airport pickup and prepare a polite waiting area.'),
    ('FC002', 'I need to send an important express shipping service to the US, and I need express service because it is arriving late. Can Admin get a quote and handle the customs paperwork?'),
    ('FC002', 'We are expecting a delegation of 10 VIP guests from overseas next week. Reception, please arrange a VIP guest for airport pickup and prepare a polite waiting area.'),
    ('FC002', 'We are expecting a delegation of 10 employee badges from overseas next week. Reception, please arrange a employee badge for airport pickup and prepare a polite waiting area.'),
    ('FC002', 'I dropped my event space in the lobby yesterday. If security found it, please let me know. I can''t swipe through the doors and it''s is needed urgently this afternoon.'),
    ('FC002', 'I dropped my courier package in the lobby yesterday. If security found it, please let me know. I can''t swipe through the doors and it''s has the wrong address.'),
    ('FC002', 'We are expecting a delegation of 10 employee badges from overseas next week. Reception, please arrange a employee badge for airport pickup and prepare a polite waiting area.'),
    ('FC003', 'The 18th floor printer is out of hand soap, please send someone to replace it.'),
    ('FC003', 'We need a fresh supply of notebook for the new batch of interns.'),
    ('FC003', 'The 18th floor printer is out of bottled water, please send someone to replace it.'),
    ('FC003', 'We need a fresh supply of tea bag for the new batch of interns.'),
    ('FC003', 'We need a fresh supply of bottled water for the new batch of interns.'),
    ('FC003', 'Please allocate additional A4 printer paper for the Marketing department this month.'),
    ('FC003', 'Kindly inspect and restock the notebook in the 18th floor pantry as it has not been restocked.'),
    ('FC003', 'Please allocate additional tea bag for the Marketing department this month.'),
    ('FC003', 'Kindly inspect and restock the ballpoint pen in the 18th floor pantry as it is running low.'),
    ('FC003', 'Kindly inspect and restock the hand soap in the 18th floor pantry as it is completely out.'),
    ('FC003', 'The 18th floor printer is out of A4 printer paper, please send someone to replace it.'),
    ('FC003', 'Please allocate additional paper towel for the Marketing department this month.'),
    ('FC003', 'I suggest we change the supplier for notebook because the recent batch is of terrible quality.'),
    ('FC003', 'Kindly inspect and restock the paper towel in the 18th floor pantry as it is completely out.'),
    ('FC003', 'We need a fresh supply of tea bag for the new batch of interns.'),
    ('FC003', 'Admin, the 18th floor needs an upgrade to a better brand notebook, please restock ASAP.'),
    ('FC003', 'Can our department get an extra box of hand soap? We run through it so fast.'),
    ('FC003', 'Can our department get an extra box of tea bag? We run through it so fast.'),
    ('FC003', 'Can our department get an extra box of color ink cartridge? We run through it so fast.'),
    ('FC003', 'I''d like to request my monthly allocation of tea bag.'),
    ('FC003', 'Admin, the 18th floor needs an upgrade to a better brand tea bag, please restock ASAP.'),
    ('FC003', 'The pantry is always out of paper towel lately, there''s nothing to use in the morning.'),
    ('FC003', 'I''d like to request my monthly allocation of bottled water.'),
    ('FC003', 'Please change the hand soap in the printer, everything is coming out blank.'),
    ('FC003', 'Admin, the 18th floor has damaged packaging color ink cartridge, please restock ASAP.'),
    ('FC003', 'The pantry is always out of bottled water lately, there''s nothing to use in the morning.'),
    ('FC003', 'Admin, the 18th floor is completely out tea bag, please restock ASAP.'),
    ('FC003', 'I''d like to request my monthly allocation of notebook.'),
    ('FC003', 'The pantry is always out of A4 printer paper lately, there''s nothing to use in the morning.'),
    ('FC003', 'Can our department get an extra box of A4 printer paper? We run through it so fast.'),
    ('FC003', 'kitchen is out of tissue'),
    ('FC003', 'give tea to the new guy'),
    ('FC003', 'kitchen is out of water'),
    ('FC003', 'printer has no ink change it'),
    ('FC003', 'printer has no water change it'),
    ('FC003', 'need some ink for the team'),
    ('FC003', 'kitchen is out of coffee'),
    ('FC003', 'kitchen is out of tea'),
    ('FC003', 'kitchen is out of soap'),
    ('FC003', 'printer has no ink change it'),
    ('FC003', 'I noticed the coffee bean we''ve been using lately is really bad, it is moldy. Can Facilities look into switching to a better brand?'),
    ('FC003', 'I just checked the 18th floor stationery cabinet and the hand soap has not been restocked. While you''re at it, please bring up 2 extra boxes of hand soap for backup storage.'),
    ('FC003', 'The company is hosting a 3-day continuous workshop next week. Admin, please prepare plenty of paper towel and paper towel for the guests, and ensure it doesn''t end up is completely out.'),
    ('FC003', 'I noticed the hand soap we''ve been using lately is really bad, it has damaged packaging. Can Facilities look into switching to a better brand?'),
    ('FC003', 'I noticed the paper towel we''ve been using lately is really bad, it is running low. Can Facilities look into switching to a better brand?'),
    ('FC003', 'I noticed the hand soap we''ve been using lately is really bad, it is of terrible quality. Can Facilities look into switching to a better brand?'),
    ('FC003', 'I just checked the 18th floor stationery cabinet and the paper towel is completely out. While you''re at it, please bring up 2 extra boxes of paper towel for backup storage.'),
    ('FC003', 'I just checked the 18th floor stationery cabinet and the notebook is of terrible quality. While you''re at it, please bring up 2 extra boxes of notebook for backup storage.'),
    ('FC003', 'The company is hosting a 3-day continuous workshop next week. Admin, please prepare plenty of A4 printer paper and A4 printer paper for the guests, and ensure it doesn''t end up needs an upgrade to a better brand.'),
    ('FC003', 'The company is hosting a 3-day continuous workshop next week. Admin, please prepare plenty of notebook and notebook for the guests, and ensure it doesn''t end up needs an upgrade to a better brand.'),
    ('HR001', 'I have an inquiry regarding my PVI health insurance which currently is not showing up on the app.'),
    ('HR001', 'Please issue an income verification letter and my overtime (OT) pay so I can apply for a bank loan.'),
    ('HR001', 'Please issue an income verification letter and my lunch allowance so I can apply for a bank loan.'),
    ('HR001', 'HR department, please guide me through the registration process for PVI health insurance.'),
    ('HR001', 'I would like to request a review of my PVI health insurance for this month as I noticed it has not been received yet.'),
    ('HR001', 'Please issue an income verification letter and my overtime (OT) pay so I can apply for a bank loan.'),
    ('HR001', 'I would like clarification regarding the personal income tax under the new benefits policy.'),
    ('HR001', 'I would like to request a review of my overtime (OT) pay for this month as I noticed it has not been received yet.'),
    ('HR001', 'I have an inquiry regarding my overtime (OT) pay which currently has confusing terms.'),
    ('HR001', 'HR department, please guide me through the registration process for lunch allowance.'),
    ('HR001', 'Please issue an income verification letter and my lunch allowance so I can apply for a bank loan.'),
    ('HR001', 'I would like clarification regarding the personal income tax under the new benefits policy.'),
    ('HR001', 'I have an inquiry regarding my dependent deduction form which currently is not showing up on the app.'),
    ('HR001', 'HR department, please guide me through the registration process for social insurance book.'),
    ('HR001', 'Please issue an income verification letter and my dependent deduction form so I can apply for a bank loan.'),
    ('HR001', 'How do we claim reimbursement for payslip?'),
    ('HR001', 'How long does it take to process the dependent deduction form paperwork?'),
    ('HR001', 'How long does it take to process the lunch allowance paperwork?'),
    ('HR001', 'Hey HR, can you double check my personal income tax for this month? I think it has not been received yet.'),
    ('HR001', 'When is the company issuing the new batch of lunch allowance cards?'),
    ('HR001', 'How long does it take to process the lunch allowance paperwork?'),
    ('HR001', 'How long does it take to process the dependent deduction form paperwork?'),
    ('HR001', 'I checked the app and my annual leave balance is not showing up on the app, can HR update it?'),
    ('HR001', 'How do we claim reimbursement for personal income tax?'),
    ('HR001', 'I checked the app and my annual leave balance has not been received yet, can HR update it?'),
    ('HR001', 'How do we claim reimbursement for dependent deduction form?'),
    ('HR001', 'Hey HR, can you double check my payslip for this month? I think it has an unjustified deduction.'),
    ('HR001', 'I checked the app and my social insurance book has confusing terms, can HR update it?'),
    ('HR001', 'Hey HR, can you double check my social insurance book for this month? I think it has confusing terms.'),
    ('HR001', 'Hey HR, can you double check my dependent deduction form for this month? I think it is calculated incorrectly.'),
    ('HR001', 'my allowance is not updated'),
    ('HR001', 'my payslip is calculated wrong'),
    ('HR001', 'my payslip is missing money'),
    ('HR001', 'how to register for tax'),
    ('HR001', 'when do we get social insurance'),
    ('HR001', 'how to register for pvi'),
    ('HR001', 'when do we get leave balance'),
    ('HR001', 'send me the social insurance form'),
    ('HR001', 'when do we get pvi'),
    ('HR001', 'my ot pay is not on app'),
    ('HR001', 'I went on a business trip and worked OT on Saturday last month, but the system shows my payslip is less than what was contracted. HR, please check the timesheet and adjust it in the next payroll.'),
    ('HR001', 'I''m going on maternity leave next month. Can HR provide a detailed consultation on finalizing my PVI health insurance and my PVI health insurance rights during my leave?'),
    ('HR001', 'I''m going on maternity leave next month. Can HR provide a detailed consultation on finalizing my overtime (OT) pay and my overtime (OT) pay rights during my leave?'),
    ('HR001', 'I''m going on maternity leave next month. Can HR provide a detailed consultation on finalizing my lunch allowance and my lunch allowance rights during my leave?'),
    ('HR001', 'I''m going on maternity leave next month. Can HR provide a detailed consultation on finalizing my lunch allowance and my lunch allowance rights during my leave?'),
    ('HR001', 'I''m going on maternity leave next month. Can HR provide a detailed consultation on finalizing my personal income tax and my personal income tax rights during my leave?'),
    ('HR001', 'When I received my payslip, I noticed the payslip is less than what was contracted, and the payslip hasn''t been added either. Can HR please review the entire payroll excel file for me?'),
    ('HR001', 'I''m going on maternity leave next month. Can HR provide a detailed consultation on finalizing my payslip and my payslip rights during my leave?'),
    ('HR001', 'I went on a business trip and worked OT on Saturday last month, but the system shows my social insurance book has not been updated. HR, please check the timesheet and adjust it in the next payroll.'),
    ('HR001', 'I went on a business trip and worked OT on Saturday last month, but the system shows my social insurance book has confusing terms. HR, please check the timesheet and adjust it in the next payroll.'),
    ('HR002', 'I would like to request approval for the Udemy Business account for my team next quarter.'),
    ('HR002', 'I am requesting leadership training course access so our employees can self-learn and upskill.'),
    ('HR002', 'What is the current status of the leadership training course for the Senior role? Is it was a no-show?'),
    ('HR002', 'What is the current status of the Udemy Business account for the Senior role? Is it has not been arranged yet?'),
    ('HR002', 'I am requesting probation review access so our employees can self-learn and upskill.'),
    ('HR002', 'Please prepare the Udemy Business account for the new employee joining on Monday.'),
    ('HR002', 'Please ask HR to schedule the probation review for the new intern.'),
    ('HR002', 'Please prepare the orientation session for the new employee joining on Monday.'),
    ('HR002', 'I am requesting orientation session access so our employees can self-learn and upskill.'),
    ('HR002', 'What is the current status of the orientation session for the Senior role? Is it is missing information?'),
    ('HR002', 'I would like to request approval for the workstation for my team next quarter.'),
    ('HR002', 'Please prepare the Udemy Business account for the new employee joining on Monday.'),
    ('HR002', 'Please ask HR to schedule the training budget for the new intern.'),
    ('HR002', 'I am requesting probation review access so our employees can self-learn and upskill.'),
    ('HR002', 'Please ask HR to schedule the leadership training course for the new intern.'),
    ('HR002', 'How did the workstation interview go yesterday? I feel it needs to be rescheduled.'),
    ('HR002', 'The new hire is starting soon, HR please get the orientation session ready.'),
    ('HR002', 'Can we get a probation review for the Dev team to learn new tech?'),
    ('HR002', 'Can you open a candidate to hire someone urgently for the new project?'),
    ('HR002', 'Can we get a probation review for the Dev team to learn new tech?'),
    ('HR002', 'The new hire is starting soon, HR please get the workstation ready.'),
    ('HR002', 'The new hire is starting soon, HR please get the orientation session ready.'),
    ('HR002', 'HR, please book the workstation for the new guy on our team.'),
    ('HR002', 'The new hire is starting soon, HR please get the leadership training course ready.'),
    ('HR002', 'Can we get a workstation for the Dev team to learn new tech?'),
    ('HR002', 'The new hire is starting soon, HR please get the Udemy Business account ready.'),
    ('HR002', 'Can you open a probation review to hire someone urgently for the new project?'),
    ('HR002', 'Can we get a training budget for the Dev team to learn new tech?'),
    ('HR002', 'HR, please book the training budget for the new guy on our team.'),
    ('HR002', 'The new hire is starting soon, HR please get the candidate ready.'),
    ('HR002', 'hire a orientation asap'),
    ('HR002', 'approve the job req pls'),
    ('HR002', 'hire a job req asap'),
    ('HR002', 'hire a desk asap'),
    ('HR002', 'approve the probation review pls'),
    ('HR002', 'register orientation for the team'),
    ('HR002', 'setup candidate for the new guy tmrw'),
    ('HR002', 'hire a training asap'),
    ('HR002', 'hr the job req yesterday was over budget'),
    ('HR002', 'hr the job req yesterday was not arranged'),
    ('HR002', 'Our team is welcoming 3 new members next month. HR, please handle the job requisition thoroughly and arrange the job requisition so they understand the company culture in their first week.'),
    ('HR002', 'I opened the probation review for the Tech Lead position last month and still haven''t received any CV that requires urgent approval. HR, let''s review the job description and push it through headhunters.'),
    ('HR002', 'Our team is welcoming 3 new members next month. HR, please handle the leadership training course thoroughly and arrange the leadership training course so they understand the company culture in their first week.'),
    ('HR002', 'Our team is welcoming 3 new members next month. HR, please handle the Udemy Business account thoroughly and arrange the Udemy Business account so they understand the company culture in their first week.'),
    ('HR002', 'Our team is welcoming 3 new members next month. HR, please handle the workstation thoroughly and arrange the workstation so they understand the company culture in their first week.'),
    ('HR002', 'I''d like to request a probation review for the entire Product team for 6 months, estimated budget is $2000. The director has approved, please process it as it was a no-show.'),
    ('HR002', 'Our team is welcoming 3 new members next month. HR, please handle the leadership training course thoroughly and arrange the leadership training course so they understand the company culture in their first week.'),
    ('HR002', 'Our team is welcoming 3 new members next month. HR, please handle the Udemy Business account thoroughly and arrange the Udemy Business account so they understand the company culture in their first week.'),
    ('HR002', 'I''d like to request a workstation for the entire Product team for 6 months, estimated budget is $2000. The director has approved, please process it as it needs to be rescheduled.'),
    ('HR002', 'Our team is welcoming 3 new members next month. HR, please handle the workstation thoroughly and arrange the workstation so they understand the company culture in their first week.'),
    ('HR003', 'I have officially submitted my internal conflict in the system, I await HR''s guidance on the next steps.'),
    ('HR003', 'I wish to report a resignation letter and request that it needs to be planned early.'),
    ('HR003', 'I request HR to act as a mediator for the internal conflict between the two departments.'),
    ('HR003', 'I wish to report a work environment feedback and request that it requires urgent director approval.'),
    ('HR003', 'I request HR to act as a mediator for the employee engagement between the two departments.'),
    ('HR003', 'I would like to submit some constructive feedback for the upcoming offboarding procedure to make it more engaging.'),
    ('HR003', 'Could the HR department clarify the team building trip in accordance with labor laws?'),
    ('HR003', 'I have officially submitted my resignation letter in the system, I await HR''s guidance on the next steps.'),
    ('HR003', 'I have officially submitted my harassment incident in the system, I await HR''s guidance on the next steps.'),
    ('HR003', 'I have officially submitted my resignation letter in the system, I await HR''s guidance on the next steps.'),
    ('HR003', 'I wish to report a work environment feedback and request that it is escalating seriously.'),
    ('HR003', 'I request HR to act as a mediator for the Year End Party between the two departments.'),
    ('HR003', 'I would like to submit some constructive feedback for the upcoming Year End Party to make it more engaging.'),
    ('HR003', 'I request HR to act as a mediator for the employee engagement between the two departments.'),
    ('HR003', 'I request HR to act as a mediator for the offboarding procedure between the two departments.'),
    ('HR003', 'I need to report a sensitive harassment incident, is anyone from HR free for a coffee chat?'),
    ('HR003', 'Just some quick feedback on the harassment incident last time, the food was really bad.'),
    ('HR003', 'HR, how many days does the offboarding procedure usually take?'),
    ('HR003', 'HR, how many days does the offboarding procedure usually take?'),
    ('HR003', 'Our team is dealing with a harassment incident, any ideas from HR on how to improve harassment incident?'),
    ('HR003', 'Our team is dealing with a internal conflict, any ideas from HR on how to improve internal conflict?'),
    ('HR003', 'HR, how many days does the harassment incident usually take?'),
    ('HR003', 'Just some quick feedback on the work environment feedback last time, the food was really bad.'),
    ('HR003', 'Our team is dealing with a internal conflict, any ideas from HR on how to improve internal conflict?'),
    ('HR003', 'HR, how many days does the resignation letter usually take?'),
    ('HR003', 'Just some quick feedback on the Year End Party last time, the food was really bad.'),
    ('HR003', 'I need to report a sensitive Year End Party, is anyone from HR free for a coffee chat?'),
    ('HR003', 'I need to report a sensitive harassment incident, is anyone from HR free for a coffee chat?'),
    ('HR003', 'Our team is dealing with a Year End Party, any ideas from HR on how to improve Year End Party?'),
    ('HR003', 'I need to report a sensitive internal conflict, is anyone from HR free for a coffee chat?'),
    ('HR003', 'report about conflict its not resolved'),
    ('HR003', 'report about resignation its confidential'),
    ('HR003', 'when is the conflict'),
    ('HR003', 'when is the feedback'),
    ('HR003', 'feedback for conflict yesterday'),
    ('HR003', 'need the yep form'),
    ('HR003', 'when is the engagement'),
    ('HR003', 'report about harassment its confidential'),
    ('HR003', 'when is the offboarding'),
    ('HR003', 'how to submit teambuilding'),
    ('HR003', 'Regarding the upcoming offboarding procedure, the board wants to host it at a 5-star resort. HR is responsible for working with the agency; make sure the program is unique and needs to be planned early.'),
    ('HR003', 'I have decided to submit my work environment feedback for personal reasons, my last day will be the end of this month. Please guide me through the work environment feedback and payout for my remaining leave.'),
    ('HR003', 'Regarding the upcoming work environment feedback, the board wants to host it at a 5-star resort. HR is responsible for working with the agency; make sure the program is unique and has not been resolved.'),
    ('HR003', 'Recently, there has been a offboarding procedure between employee A and employee B, creating a very tense atmosphere that needs to be planned early. We need an HR specialist to step in and mediate soon.'),
    ('HR003', 'Regarding the upcoming resignation letter, the board wants to host it at a 5-star resort. HR is responsible for working with the agency; make sure the program is unique and is affecting mental health.'),
    ('HR003', 'I have decided to submit my resignation letter for personal reasons, my last day will be the end of this month. Please guide me through the resignation letter and payout for my remaining leave.'),
    ('HR003', 'I have decided to submit my internal conflict for personal reasons, my last day will be the end of this month. Please guide me through the internal conflict and payout for my remaining leave.'),
    ('HR003', 'I have decided to submit my Year End Party for personal reasons, my last day will be the end of this month. Please guide me through the Year End Party and payout for my remaining leave.'),
    ('HR003', 'I have decided to submit my harassment incident for personal reasons, my last day will be the end of this month. Please guide me through the harassment incident and payout for my remaining leave.'),
    ('HR003', 'I have decided to submit my work environment feedback for personal reasons, my last day will be the end of this month. Please guide me through the work environment feedback and payout for my remaining leave.');

COMMIT;

-- ============================================================
-- Verification queries (run manually after seeding)
-- ============================================================
-- SELECT code, department_code, name FROM sub_departments ORDER BY code;
-- SELECT sub_department_code, count(*) FROM rule_patterns GROUP BY 1 ORDER BY 1;
-- SELECT sub_department_code, count(*) FROM sample_tickets GROUP BY 1 ORDER BY 1;

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
    title || ' ' || description AS content_text,
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
    'Floor 18',
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
-- ----------------------------------------------------------------

BEGIN;

-- IT001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT001', 'new laptop request', 'keyword', 200),
    ('IT001', 'broken keyboard', 'keyword', 200),
    ('IT001', 'broken mouse', 'keyword', 200),
    ('IT001', 'monitor not working', 'keyword', 200),
    ('IT001', 'headset replacement', 'keyword', 200),
    ('IT001', 'laptop charger broken', 'keyword', 200),
    ('IT001', 'temporary equipment loan', 'keyword', 150),
    ('IT001', 'hardware warranty', 'keyword', 150),
    ('IT001', 'damaged screen', 'keyword', 150);

-- IT002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT002', 'no internet connection', 'keyword', 200),
    ('IT002', 'wifi not working', 'keyword', 200),
    ('IT002', 'vpn not connecting', 'keyword', 200),
    ('IT002', 'cannot connect to vpn', 'keyword', 200),
    ('IT002', 'software installation error', 'keyword', 150),
    ('IT002', 'os installation', 'keyword', 150),
    ('IT002', 'shared drive access', 'keyword', 150),
    ('IT002', 'network down', 'keyword', 150),
    ('IT002', 'slow internet', 'keyword', 150);

-- IT003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT003', 'reset password', 'keyword', 200),
    ('IT003', 'forgot password', 'keyword', 200),
    ('IT003', 'account locked', 'keyword', 200),
    ('IT003', 'active directory', 'keyword', 200),
    ('IT003', 'suspected phishing', 'keyword', 200),
    ('IT003', 'malware alert', 'keyword', 200),
    ('IT003', 'suspicious email', 'keyword', 180),
    ('IT003', 'mfa issue', 'keyword', 150),
    ('IT003', 'two factor authentication', 'keyword', 150);

-- FC001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC001', 'air conditioning broken', 'keyword', 200),
    ('FC001', 'ac not cooling', 'keyword', 200),
    ('FC001', 'broken chair', 'keyword', 200),
    ('FC001', 'broken desk', 'keyword', 200),
    ('FC001', 'light not working', 'keyword', 180),
    ('FC001', 'water leak', 'keyword', 180),
    ('FC001', 'power outage', 'keyword', 150),
    ('FC001', 'cleaning request', 'keyword', 130);

-- FC002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC002', 'send courier', 'keyword', 200),
    ('FC002', 'book company car', 'keyword', 200),
    ('FC002', 'replace employee badge', 'keyword', 200),
    ('FC002', 'lost badge', 'keyword', 200),
    ('FC002', 'book meeting room', 'keyword', 150),
    ('FC002', 'reserve event space', 'keyword', 150);

-- FC003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC003', 'request office supplies', 'keyword', 200),
    ('FC003', 'need printer paper', 'keyword', 200),
    ('FC003', 'out of pens', 'keyword', 200),
    ('FC003', 'no coffee', 'keyword', 180),
    ('FC003', 'pantry restock', 'keyword', 180),
    ('FC003', 'printer ink request', 'keyword', 150);

-- HR001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR001', 'payroll error', 'keyword', 200),
    ('HR001', 'wrong salary', 'keyword', 200),
    ('HR001', 'social insurance', 'keyword', 200),
    ('HR001', 'bhxh', 'keyword', 200),
    ('HR001', 'maternity leave benefit', 'keyword', 200),
    ('HR001', 'health insurance pvi', 'keyword', 180),
    ('HR001', 'bao viet insurance', 'keyword', 180),
    ('HR001', 'personal income tax', 'keyword', 150),
    ('HR001', 'dependent declaration', 'keyword', 150);

-- HR002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR002', 'register training course', 'keyword', 200),
    ('HR002', 'request training budget', 'keyword', 200),
    ('HR002', 'prepare desk for new hire', 'keyword', 180),
    ('HR002', 'external course registration', 'keyword', 180),
    ('HR002', 'recruitment request', 'keyword', 150),
    ('HR002', 'new employee orientation', 'keyword', 150);

-- HR003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR003', 'resignation procedure', 'keyword', 200),
    ('HR003', 'offboarding process', 'keyword', 200),
    ('HR003', 'workplace conflict', 'keyword', 200),
    ('HR003', 'harassment report', 'keyword', 200),
    ('HR003', 'team building suggestion', 'keyword', 130),
    ('HR003', 'year end party feedback', 'keyword', 130);

COMMIT;

-- ----------------------------------------------------------------
-- Sample tickets — retrieval & rule-match test fixtures
-- (never embedded, never sent to the AI model)
-- ----------------------------------------------------------------

BEGIN;

INSERT INTO sample_tickets (
    sub_department_code,
    title,
    description,
    triage_category,
    triage_urgency_level,
    triage_sla_breach_risk,
    triage_reason_summary,
    triage_recommended_next_action,
    triage_confidence_score
) VALUES
    (
        'IT001',
        'Replacement laptop needed for newly hired Sales VP arriving in 30 minutes',
        'Our new VP of Sales is onboarding in exactly 30 minutes and their assigned Macbook Pro has a failed motherboard and will not power on. We need a replacement laptop provisioned and configured immediately.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under the Hardware Inventory & Equipment Provisioning team (IT001) of the IT Department as it requires physical provisioning of a replacement laptop. SLA BREACH WARNING: Urgent risk is detected with only 20 minutes left before the VIP onboarding window closes under our onboarding SLA policy.',
        'Prepare a backup pre-configured macOS laptop from the inventory, copy the profile, and deliver it directly to the VP''s desk on Floor 18.',
        0.98
    ),
    (
        'IT001',
        'Request for replacement external webcam and dual-monitor cables',
        'Hi Support, my current external webcam has a frayed cable and is flickering during video calls. Also, I need a USB-C to DisplayPort cable to connect my secondary monitor. Please let me know when I can pick them up.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 (Hardware Provisioning) since the user is requesting physical accessories (webcam and display cables). SLA Breach risk is LOW; this standard hardware request has a 48-hour resolution window, with 43 hours remaining on the clock.',
        'Verify inventory availability for the webcam and cable, prepare the items, and send a pickup notification email to the requestor.',
        0.95
    ),
    (
        'IT001',
        'Defective mechanical keyboard replacement request',
        'Dear Helpdesk, several keys (A, S, Space) on my issued Keychron mechanical keyboard have completely stopped responding this morning. I am unable to write code effectively. Can I get a replacement keyboard today?',
        'IT',
        'medium',
        'low',
        'Determined to be a hardware replacement case suitable for IT001 (Hardware Provisioning) because it involves swapping physical computer peripherals. SLA Breach risk is LOW: standard peripheral replacement has a 24-hour SLA window with 23 hours remaining.',
        'Verify Keychron keyboard stock in the inventory system, prepare a replacement unit, and log the barcode update.',
        0.97
    ),
    (
        'IT001',
        'Temporary laptop loan for business trip departure in 2 hours',
        'I am departing for a critical client site presentation in Da Nang in exactly 2 hours and my main workstation is undergoing motherboard repairs. I urgently need a temporary loaner laptop provisioned with VPN access before I leave.',
        'IT',
        'high',
        'high',
        'This request is forwarded to IT001 (Hardware Provisioning) as physical loaner laptop allocation is required. SLA BREACH WARNING: High urgency detected with the business trip departure in 2 hours, leaving only 45 minutes of buffer time under the emergency hardware loan policy.',
        'Immediately provision a temporary windows laptop from the loaner pool, configure basic corporate profiles, and coordinate immediate handover with the requestor.',
        0.96
    ),
    (
        'IT001',
        'Request for ergonomic mouse and keyboard wrist rest',
        'Hi, I have been experiencing wrist pain recently and my doctor recommended using an ergonomic vertical mouse and a keyboard wrist rest. I have attached the medical recommendation. Can the company provide these?',
        'IT',
        'low',
        'low',
        'Identified as a peripheral hardware request (IT001) for ergonomic accessories. SLA risk is LOW since this falls under standard non-urgent procurement with 71 hours remaining.',
        'Review the medical recommendation, check the ergonomic hardware inventory, and coordinate with procurement if ordering is needed.',
        0.94
    ),
    (
        'IT001',
        'Dual-monitor setup request for newly joined UI/UX Designer',
        'Hi, we have a new UI/UX Designer joining our team on Floor 18 next Monday. Designers require a dual-monitor setup (two 27-inch 4K monitors) for their high-fidelity mockups. Please allocate the hardware.',
        'IT',
        'medium',
        'low',
        'Allocated to IT001 (Hardware team) to prepare physical monitor setup and allocation for a new designer. SLA risk is LOW as the start date is next week, leaving over 83 hours on the onboarding SLA timeline.',
        'Allocate two 27-inch 4K monitors from inventory, schedule the installation with floor technician for Friday afternoon.',
        0.96
    ),
    (
        'IT001',
        'Malfunctioning laptop charger replacement (USB-C 96W)',
        'My Macbook 96W USB-C charger has started sparking when plugged in and no longer charges my laptop. I am currently running on 15% battery. I need a new charger block as soon as possible.',
        'IT',
        'high',
        'high',
        'Requires physical replacement of a charging accessory, which falls under the IT001 (Hardware Provisioning) scope. SLA BREACH WARNING: Severe risk is present as the user''s battery will die within 30 minutes, and only 25 minutes remain on the hardware failure SLA.',
        'Issue a replacement 96W USB-C power adapter from the service desk drawer immediately and mark the defective unit for disposal.',
        0.98
    ),
    (
        'IT001',
        'Broken laptop screen hinge repair or replacement',
        'The left hinge on my corporate laptop is completely broken, preventing me from opening the screen without damaging the display panel. The laptop itself works fine when docked. I need a repair or chassis swap.',
        'IT',
        'medium',
        'low',
        'Sent to IT001 (Hardware Support) for physical hinge repair or device swap. SLA risk is LOW because the laptop is functional when docked, allowing a standard 3-day window (70 hours remaining).',
        'Schedule a hardware inspection session with the user, prepare a replacement laptop if the hinge repair requires depot service.',
        0.95
    ),
    (
        'IT001',
        'Request for external SSD (1TB) for video editing team',
        'Our marketing team is starting a major video campaign and we require three external 1TB SSDs to store raw 4K video footages. The budget has been approved by the department head.',
        'IT',
        'low',
        'low',
        'Hardware logistics queue (IT001) is responsible for this request since it involves provisioning external storage devices. SLA risk is LOW with 58 hours remaining under standard procurement policies.',
        'Verify the budget approval, retrieve three 1TB SSDs from storage, and register the serial numbers to the marketing department asset list.',
        0.97
    ),
    (
        'IT001',
        'Preparing hardware setup for 5 new engineering interns next week',
        'We have 5 engineering interns joining next Monday. Please prepare 5 standard developer laptops (16GB RAM), keyboards, mice, and monitor stands. Please place them at their assigned desks on Floor 18.',
        'IT',
        'medium',
        'low',
        'Requires hardware provisioning and delivery by the IT001 team for bulk onboarding hardware setup. SLA risk is LOW since there are 4 days left before the interns start, leaving 95 hours on the clock.',
        'Retrieve 5 developer laptops, configure local base images, package with standard peripherals, and set up at the assigned desks.',
        0.93
    ),
    (
        'IT002',
        'Entire accounting department lost Wi-Fi and VPN access connection',
        'Dear IT Helpdesk, the entire accounting team on Floor 18 suddenly lost Wi-Fi connection and cannot authenticate via VPN. We are in the middle of closing the month-end financial statements. Please check the local access point immediately.',
        'IT',
        'high',
        'high',
        'Triage decision: IT002 (Network Support) should handle this due to the widespread Wi-Fi and VPN outage for Accounting. CRITICAL SLA WARNING: The risk of SLA breach is HIGH because there are only 15 minutes left before the ticket expires under the Critical Incident policy.',
        'Escalate immediately to the Network Infrastructure Lead. Dispatch a technician to Floor 18 to inspect the local switch/access point and verify the Accounting subnet routing profile.',
        0.98
    ),
    (
        'IT002',
        'Unable to access local shared drive (S:) after system update',
        'Since the automated Windows update last night, my machine keeps showing ''Network path not found'' when attempting to connect to the department shared drive. My internet and other applications are working fine.',
        'IT',
        'medium',
        'low',
        'Assigned to IT002 (System Software) because it requires resolving local OS and network share path configuration. SLA breach risk is LOW because it is an isolated client-side access issue with a standard 24-hour SLA window (24 hours remaining).',
        'Remote into the user''s machine, clear cached network credentials, and re-map the S: drive path using the active directory login script.',
        0.96
    ),
    (
        'IT002',
        'VPN gateway authentication timeout for all offsite developers',
        'None of our remote developers can log into the corporate VPN network. The connection times out during authentication. This is blocking the deployment of the critical security hotfix scheduled for tonight.',
        'IT',
        'high',
        'high',
        'System-wide VPN connection failure identified, placing this ticket in the IT002 network queue. CRITICAL SLA WARNING: The SLA risk is HIGH because the deployment deadline is in 30 minutes, and we only have 12 minutes remaining before breaching the system-wide service availability SLA.',
        'Check the VPN gateway logs, verify the RADIUS server connectivity status, and restart the secondary authentication helper if unresponsive.',
        0.99
    ),
    (
        'IT002',
        'Request for WSL2 and Docker Desktop installation on corporate Windows laptop',
        'I am a developer and I need WSL2 (Ubuntu 22.04) and Docker Desktop installed on my Windows machine to run local microservices. The installer requires local administrator privileges.',
        'IT',
        'medium',
        'low',
        'Software installation support (IT002) is required to run the Docker setup with local admin privileges. SLA risk is LOW since developer workstation configuration holds a standard 24-hour SLA (23 hours remaining).',
        'Initiate a remote control session, input temporary admin credentials, enable Hyper-V/WSL2 features, and install Docker Desktop configured for corporate proxies.',
        0.95
    ),
    (
        'IT002',
        'Extremely slow Wi-Fi speeds and dropouts in Conference Room 4B',
        'During client presentations in Room 4B, the Wi-Fi speed drops below 1 Mbps and frequently disconnects. This is causing video calls to drop. We need a network check for this area.',
        'IT',
        'medium',
        'low',
        'Wi-Fi signal degradation in a public meeting room maps this to IT002 network infrastructure. SLA risk is LOW with 25 hours remaining on the standard network inspection pipeline.',
        'Run a wireless site survey in Room 4B, adjust the transmit power of the closest access point, or shift client load to a less congested channel.',
        0.94
    ),
    (
        'IT002',
        'Office 365 license showing ''Unlicensed Product'' activation error',
        'When opening Word or Outlook, I receive an error stating my license cannot be verified, and editing is disabled. This is blocking me from updating the executive board presentation.',
        'IT',
        'medium',
        'low',
        'This concerns MS Office product activation and licensing issues, which is managed by IT002. SLA risk is LOW as it is an individual software license issue (23 hours remaining).',
        'Reset the local Office activation state, re-authenticate the user''s Azure AD account, and verify the assigned license SKU in Microsoft 365 admin center.',
        0.96
    ),
    (
        'IT002',
        'Unable to join corporate Slack workspace with new email alias',
        'My email was recently changed to my new department alias. Since then, I have been locked out of the corporate Slack workspace and cannot rejoin using the automated invite link.',
        'IT',
        'medium',
        'low',
        'Slack workspace invitation failure falls under the IT002 software access queue. SLA risk is LOW with 20 hours remaining.',
        'Verify the new email mapping, manually update the email address in the Slack admin control panel, and re-send the direct workspace invitation.',
        0.95
    ),
    (
        'IT002',
        'Network printer driver installation and mapping request for Floor 19',
        'I recently relocated my desk to Floor 19 and I need my laptop mapped to the main department printer (Model HP Laserjet 500) so I can print physical contracts.',
        'IT',
        'low',
        'low',
        'Identified as a printer driver installation and network mapping request for IT002. SLA risk is LOW since this is a standard configuration request with 46 hours remaining.',
        'Remotely install the correct printer driver, verify the network IP mapping, and run a test print page.',
        0.98
    ),
    (
        'IT002',
        'Blue Screen of Death (BSOD) loops after mandatory Windows Update',
        'My work laptop is stuck in a BSOD boot loop displaying ''INACCESSIBLE_BOOT_DEVICE'' immediately after the automated security update last night. I cannot access any files or start the system.',
        'IT',
        'high',
        'high',
        'Critical OS crash/BSOD loop requires advanced software troubleshooting by the IT002 desktop team. SLA BREACH WARNING: The SLA risk is HIGH because the user is completely blocked from working, and there are only 45 minutes remaining on the desktop support SLA.',
        'Boot the laptop into recovery mode, uninstall the latest quality update, or perform a system restore to a previous restore point.',
        0.97
    ),
    (
        'IT002',
        'Homebrew permissions error on corporate macOS laptop',
        'When trying to run `brew install git` on my macOS laptop, I receive a permission denied error for `/usr/local/Cellar`. I need help fixing the directory ownership.',
        'IT',
        'low',
        'low',
        'Terminal command permission issues on macOS fall under the IT002 software support scope. SLA risk is LOW with 53 hours remaining.',
        'Run remote commands to correct local ownership permissions for the homebrew directory according to the developer guidelines.',
        0.94
    ),
    (
        'IT003',
        'Suspected phishing link clicked on executive account',
        'I accidentally clicked on a link in a suspicious email claiming to be from the tax authority, and input my domain credentials. Shortly after, I received MFA prompts that I did not initiate. Please lock my account immediately.',
        'IT',
        'high',
        'high',
        'Security incident alert: Sent to IT003 for credential isolation and threat response. SLA breach risk is HIGH because security incidents require containment within 15 minutes, and only 8 minutes remain before potential data exfiltration starts.',
        'Immediately disable the user''s Active Directory account, revoke all active OAuth tokens/sessions, and initiate a password reset. Alert the SOC team for log analysis.',
        0.99
    ),
    (
        'IT003',
        'Active Directory account password reset request',
        'Hi, my password has expired and I am locked out of my corporate Windows login. I cannot access my email or Jira. Please help me reset my Active Directory password.',
        'IT',
        'medium',
        'low',
        'Password lockout issue resolved by the IT003 Active Directory administration desk. SLA risk is LOW because individual password resets have a quick turnaround but a 4-hour SLA window, with 3 hours remaining.',
        'Verify the user''s identity via manager confirmation or phone, reset the AD password, and configure ''User must change password at next logon''.',
        0.97
    ),
    (
        'IT003',
        'Account locked due to multiple failed Multi-Factor Authentication (MFA) attempts',
        'I tried to log in from my phone and entered the wrong MFA code too many times. Now my account is locked system-wide. I have a client call in 20 minutes and need my access restored.',
        'IT',
        'high',
        'high',
        'Identified as an MFA lockout, placing it in the IT003 authentication queue. SLA BREACH WARNING: The SLA risk is HIGH because the user is locked out of critical client channels, and only 15 minutes remain before the SLA breaches.',
        'Inspect the Azure AD logs, clear the failed MFA lock counter, and assist the user with a fresh MFA code validation.',
        0.98
    ),
    (
        'IT003',
        'Requesting access to corporate GitHub organization for new repository creation',
        'Our project needs a new private repository under the corporate GitHub organization for our new client module. I need owner permissions to initialize the repository and add team members.',
        'IT',
        'low',
        'low',
        'Access control request for GitHub repository admin permissions falls under IT003. SLA risk is LOW as it is a routine access request with 40 hours remaining.',
        'Verify the project approval, create the private repository, assign the correct team access profile, and close the request.',
        0.96
    ),
    (
        'IT003',
        'Immediately revoke all system access for offboarded contractor',
        'Contractor ID 9928 has been terminated effective immediately due to policy violations. Please revoke all their accounts, including Active Directory, VPN, AWS, and Slack, to prevent unauthorized data access.',
        'IT',
        'high',
        'high',
        'Immediate termination protocol requires access revocation across all accounts by IT003. SLA BREACH WARNING: SLA breach risk is HIGH because immediate terminations require access lockout within 30 minutes, and 10 minutes remain on the incident clock.',
        'Immediately disable the contractor''s AD account, revoke active sessions across Slack and AWS console, and terminate active VPN tunnels.',
        0.99
    ),
    (
        'IT003',
        'Antivirus warning: Malware/Trojan detection alert on local laptop',
        'My corporate antivirus (SentinelOne) just popped up an alert stating that a malicious trojan was detected and quarantined in my Downloads folder. I need security to check if my machine is safe.',
        'IT',
        'high',
        'high',
        'Malware containment alert: SentinelOne quarantine check is handled by the IT003 security team. SLA BREACH WARNING: The SLA risk is HIGH because security policy mandates host quarantine and verification within 1 hour, and we have only 15 minutes remaining.',
        'Remotely connect to the SentinelOne console, isolate the user''s network host, retrieve the malware hash details, and run a full deep scan.',
        0.97
    ),
    (
        'IT003',
        'Requesting Single Sign-On (SSO) integration for new internal HR tool',
        'We are launching a new internal benefits portal and we want to integrate it with Okta SSO so employees can log in using their standard corporate credentials. I have attached the SAML metadata details.',
        'IT',
        'low',
        'low',
        'Okta SSO configuration for a new portal is assigned to IT003 identity management. SLA risk is LOW as this is a project-based security task with 66 hours remaining.',
        'Review the SAML metadata, create the application profile in Okta, configure the attribute mappings, and schedule a testing session with the HR portal dev team.',
        0.96
    ),
    (
        'IT003',
        'Lost physical YubiKey hardware token and access request',
        'I lost my physical YubiKey token yesterday during my commute. I currently cannot log into AWS or our code repositories. I need the lost key revoked and a new one registered.',
        'IT',
        'medium',
        'low',
        'YubiKey hardware token loss and replacement falls under the IT003 security credentials queue. SLA risk is LOW with 21 hours remaining on the key replacement SLA.',
        'Revoke the lost YubiKey serial number from Okta, verify the user''s identity, issue a new YubiKey token, and register it to the user''s account.',
        0.95
    ),
    (
        'IT003',
        'Temporary database read access request for urgent production hotfix validation',
        'I need temporary read-only access to the production customer DB to validate a critical patch that we just deployed. I have manager approval. Access is needed for 2 hours.',
        'IT',
        'high',
        'high',
        'Urgent database IAM read-only access request maps to IT003 for compliance auditing. SLA BREACH WARNING: SLA risk is HIGH because production hotfix validation has a tight window and only 25 minutes remain before the SLA window closes.',
        'Review the manager approval, issue a temporary IAM credential role with a 2-hour automatic expiry, and log the action in the security audit log.',
        0.98
    ),
    (
        'IT003',
        'Setting up Okta MFA security credentials for new employee',
        'We have a new employee starting next Monday. Please initiate their Okta profile onboarding and email them the temporary registration link and instructions for setting up Google Authenticator.',
        'IT',
        'low',
        'low',
        'Okta MFA setup for new employee onboarding is managed by IT003. SLA risk is LOW since the employee starts next week, leaving 75 hours remaining.',
        'Create the user profile in Okta, assign them to the correct security groups, and send the MFA setup invitation link.',
        0.97
    ),
    (
        'FC001',
        'Main ceiling pipe burst causing water leak on Floor 18',
        'Water is pouring down from the ceiling in the Floor 18 corridor, flooding the floor near the server room backup generators. This is a severe safety hazard. We need maintenance here right now!',
        'Facilities',
        'high',
        'high',
        'Emergency building maintenance: FC001 handles water leaks and plumbing failures. SLA breach risk is HIGH because building flooding near electrical assets requires isolation within 20 minutes, and 12 minutes remain before water reaches critical server areas.',
        'Immediately contact the building management to shut off the main water valve on Floor 18. Dispatch the facility team to extract water and secure the backup generator area.',
        0.98
    ),
    (
        'FC001',
        'Office chair gas cylinder adjustment or replacement',
        'My desk chair (model ergonomic-X) is slowly sinking throughout the day. The gas cylinder seems to have lost pressure. I would appreciate it if someone could adjust or replace it.',
        'Facilities',
        'low',
        'low',
        'Office furniture repair request (ergonomic chair gas cylinder) is assigned to FC001. SLA breach risk is LOW as standard office comfort requests have a 3-day turnaround, leaving 72 hours left.',
        'Schedule a technician visit to inspect the chair cylinder and replace the chair body if the cylinder is leaking gas.',
        0.94
    ),
    (
        'FC001',
        'Fluorescent light tube flickering continuously in Meeting Room 3A',
        'The main overhead light in Meeting Room 3A is flickering heavily, making it unusable for presentations and causing eye strain. Please replace the bulb or ballast.',
        'Facilities',
        'low',
        'low',
        'Overhead lighting failure in Meeting Room 3A maps to the FC001 electrical maintenance desk. SLA risk is LOW since there are other functional meeting rooms and standard maintenance has 71 hours remaining.',
        'Assign a facility electrician to swap the defective T8 bulb in Room 3A with a new LED tube.',
        0.96
    ),
    (
        'FC001',
        'Air conditioning blowing warm air on Floor 18 Sales department',
        'The AC system in the Sales department zone on Floor 18 seems to be broken. It is blowing hot air and the room temperature has reached 29 degrees. People are unable to focus.',
        'Facilities',
        'medium',
        'low',
        'HVAC failure in the Sales zone requires physical inspection by FC001 technicians. SLA risk is LOW because zone temperature issues hold a 24-hour SLA (24 hours remaining).',
        'Inspect the Floor 18 HVAC condenser coils, check the thermostat setting, and reset the chiller valve for the Sales zone.',
        0.95
    ),
    (
        'FC001',
        'Broken power outlets under the Floor 18 central conference table',
        'All three electrical sockets built into the Floor 18 conference table are completely dead. Laptops cannot be charged during long sprint meetings. Please inspect the under-desk wiring.',
        'Facilities',
        'medium',
        'low',
        'Desk power outlet electrical wiring issue is forwarded to FC001. SLA risk is LOW as it is restricted to a single conference table (25 hours remaining).',
        'Check the breaker panel for the Floor 18 meeting room zone, reset the tripped GFI outlet under the table, and verify electrical current.',
        0.94
    ),
    (
        'FC001',
        'Main glass entrance door electronic lock jammed on Floor 19',
        'The electronic magnetic lock on the Floor 19 main glass entrance is jammed shut. Staff are locked out and unable to enter the workspace, creating a safety/fire evacuation hazard. Please override.',
        'Facilities',
        'high',
        'high',
        'Electronic door lock malfunction is a safety hazard assigned to FC001 facilities team. SLA BREACH WARNING: The SLA breach risk is HIGH because fire egress blockages must be bypassed within 30 minutes, and only 15 minutes remain on the priority SLA.',
        'Immediately trigger the emergency door override, release the magnetic lock voltage manually, and check the card reader wiring.',
        0.97
    ),
    (
        'FC001',
        'Large coffee stain on carpet in Floor 18 reception lobby',
        'A large cup of black coffee was dropped in the middle of the Floor 18 reception lobby, leaving a highly visible stain on the light gray carpet. We need carpet cleaning services.',
        'Facilities',
        'low',
        'low',
        'Lobby carpet cleaning and spot removal falls under the FC001 janitorial queue. SLA risk is LOW with a 48-hour cleaning window (60 hours remaining).',
        'Dispatch a cleaning staff member with a steam vacuum and carpet spot-cleaner chemical to the Floor 18 lobby.',
        0.93
    ),
    (
        'FC001',
        'Electrical power outage in meeting room 2B with sparks from wall outlet',
        'We were plugging in a projector in Room 2B when the wall outlet sparked, went black, and all power in the room cut out. There is a faint smell of smoke. Please send an electrician immediately.',
        'Facilities',
        'high',
        'high',
        'High priority electrical sparking and smoke hazard requires urgent FC001 electrician dispatch. SLA BREACH WARNING: The SLA risk is HIGH because electrical fire risks require immediate response, and only 10 minutes remain on the priority safety check window.',
        'Cut power to the Room 2B electrical circuit at the main breaker board immediately, inspect the wall outlet, and replace the burnt wiring.',
        0.98
    ),
    (
        'FC001',
        'Office temperature too cold in the Floor 18 engineering corner',
        'The AC ventilation is blowing freezing cold air directly onto the developer desks on Floor 18. It feels like winter and some employees are wearing coats. Please adjust the louvers or temp.',
        'Facilities',
        'low',
        'low',
        'Workplace comfort adjustment (temperature adjustments for engineering corner) is handled by FC001. SLA risk is LOW since it is a routine comfort query with 66 hours remaining.',
        'Adjust the local airflow dampers on the ceiling diffuser and increase the target thermostat temperature by 2 degrees.',
        0.94
    ),
    (
        'FC001',
        'Restroom washbasin clogged and overflowing in Floor 18 East wing',
        'The left washbasin in the Floor 18 East wing restroom is completely clogged and is slowly overflowing onto the tiled floor. Please send a plumber to clear the blockage.',
        'Facilities',
        'medium',
        'low',
        'East wing washbasin clog and bathroom flooding is routed to FC001 plumbing services. SLA risk is LOW since it is limited to a single restroom sink and other facilities are open (20 hours remaining).',
        'Clear the sink drain trap using a plunger/snake, inspect the drain pipe, and clean up the wet bathroom floor.',
        0.95
    ),
    (
        'FC002',
        'Airport pickup request for CEO of foreign partner arriving in 45 mins',
        'The flight of the CEO of our Japanese partner arrived early. They are exiting customs in 45 minutes. The scheduled corporate car booking is showing as unassigned. Please dispatch a driver urgently.',
        'Facilities',
        'high',
        'high',
        'VIP transport coordination maps to the FC002 vehicle dispatch desk. SLA breach risk is HIGH because there are only 30 minutes left to coordinate a driver to reach the airport in time.',
        'Manually override the automated booking, assign the on-call driver, and send the VIP''s name and contact number via SMS to the driver.',
        0.97
    ),
    (
        'FC002',
        'Request for access badge replacement',
        'Hi, I lost my security access badge yesterday. I am currently using a temporary guest pass. Could you please print a replacement badge for me? I will pay the replacement fee at the lobby reception.',
        'Facilities',
        'low',
        'low',
        'Lost employee security badge replacement is handled at the FC002 reception desk. SLA risk is LOW since the user has a guest pass and the replacement SLA is 24 hours (24 hours remaining).',
        'Verify employee ID, verify fee payment, print the badge, and notify the user to pick it up at the main reception desk.',
        0.96
    ),
    (
        'FC002',
        'Sending urgent international courier packages containing physical contracts',
        'I need to send original signed contracts to our client in Singapore via DHL Express today. The courier needs to pick up the documents from the Floor 18 reception before 4:00 PM for same-day dispatch.',
        'Facilities',
        'medium',
        'low',
        'Urgent courier package dispatch via DHL is managed by FC002 mailroom logistics. SLA risk is LOW since there are 6 hours left before the cutoff (20 hours left on the request SLA).',
        'Receive the document package, verify destination details, book the DHL express dispatch, and hand over the package to the courier.',
        0.95
    ),
    (
        'FC002',
        'Tracking missing parcel delivered to lobby reception',
        'My delivery status shows that a parcel containing client samples was delivered to the main lobby reception yesterday afternoon, but I did not receive any notification. Please verify if it is held there.',
        'Facilities',
        'low',
        'low',
        'Tracking undelivered packages held in the lobby registry falls under FC002. SLA risk is LOW with 40 hours remaining on the standard mail inquiry queue.',
        'Check the reception package log, locate the physical parcel in the package cabinet, and notify the employee for pickup.',
        0.96
    ),
    (
        'FC002',
        'Reserving corporate vehicle for client visit tomorrow',
        'I have a team of four visiting our client''s manufacturing plant in Binh Duong tomorrow morning. I need to book the corporate 7-seater SUV and a driver from 8:00 AM to 5:00 PM.',
        'Facilities',
        'medium',
        'low',
        'Corporate vehicle reservation request for client visits is managed by FC002. SLA risk is LOW because the booking request is placed one day in advance, leaving 33 hours on the SLA.',
        'Check the corporate SUV calendar, assign an available driver, and send booking confirmation with driver contact information.',
        0.95
    ),
    (
        'FC002',
        'Booking large meeting room for seminar next week',
        'Hi, our team is hosting a technology sharing seminar next Friday (July 3rd) for 50 attendees. We need to book the large Floor 18 townhall room and coordinate the setup of chairs and projector.',
        'Facilities',
        'low',
        'low',
        'Townhall seminar space booking and chair setup falls under FC002 facility scheduling. SLA risk is LOW since the event is next week, leaving over 83 hours on the booking timeline.',
        'Confirm the availability of the Floor 18 townhall room on July 3rd, block the calendar, and log setup instructions.',
        0.98
    ),
    (
        'FC002',
        'Visitor registration for upcoming developer interview',
        'We have an external developer candidate visiting the office today at 2:00 PM for an interview. Please register them in the visitor system and issue a visitor pass when they arrive at the lobby.',
        'Facilities',
        'low',
        'low',
        'Visitor pre-registration and pass printing is handled by FC002 receptionists. SLA risk is LOW with 80 hours remaining on the registration database.',
        'Log the candidate name in the lobby guest list, prepare the visitor pass, and notify the interview panel upon candidate arrival.',
        0.96
    ),
    (
        'FC002',
        'Mailroom notification: Package with broken contents received in lobby',
        'We received a package in the lobby address from a supplier, but the box is severely damaged and leaking fluid. We have held it in the mailroom. Please come and inspect it.',
        'Facilities',
        'medium',
        'low',
        'Damaged supplier package report goes to FC002 for receipt verification. SLA risk is LOW with 18 hours remaining on the logistics inspection SLA.',
        'Photograph the damaged packaging, notify the recipient employee, and hold the item in the secure containment area.',
        0.95
    ),
    (
        'FC002',
        'Access card reader not recognizing badge on Floor 18 East entrance',
        'My newly issued access card works on all other doors but keeps showing a red light and error code at the Floor 18 East entrance door. I am blocked from entering the office directly.',
        'Facilities',
        'high',
        'high',
        'East entrance card reader issue requires access validation by FC002 access control. SLA BREACH WARNING: SLA risk is HIGH because the employee is blocked from accessing their workspace, and only 20 minutes remain.',
        'Check the card configuration in the security portal, re-authorize Floor 18 East door permissions for the card ID, and verify the reader connectivity.',
        0.97
    ),
    (
        'FC002',
        'Arranging taxi coupons for late-night project overtime',
        'Our project team will be working until 11:30 PM this week for deployment. Please issue 15 Grab/Taxi corporate coupons so team members can safely travel home after public transit closes.',
        'Facilities',
        'low',
        'low',
        'Taxi coupon generation for late-night project work is handled by the FC002 travel desk. SLA risk is LOW with 63 hours remaining.',
        'Generate the corporate Grab promo codes from the business portal, log the cost code to the project, and email the codes to the team lead.',
        0.98
    ),
    (
        'FC003',
        'Pantry stock alert: Running out of drinking water and coffee beans',
        'The main pantry on Floor 18 has completely run out of drinking water bottles and espresso coffee beans. There is a large group meeting starting in 2 hours and we have nothing to serve. Please restock.',
        'Facilities',
        'medium',
        'low',
        'Floor 18 pantry water and coffee bean replenishment maps to FC003. SLA risk is LOW because it is a routine pantry alert with a 4-hour window (4 hours remaining).',
        'Dispatch a pantry staff member to transport 4 water bottles and 2kg of coffee beans from the central stock room to the Floor 18 pantry.',
        0.95
    ),
    (
        'FC003',
        'Request for whiteboard markers and post-it notes',
        'The marketing meeting room is out of dry-erase whiteboard markers. We also need 5 pads of yellow post-it notes for our upcoming brainstorming session tomorrow.',
        'Facilities',
        'low',
        'low',
        'Stationery requests (markers and post-it notes) are fulfilled by FC003 office supplies. SLA risk is LOW since the request is for the next day, and we have 24 hours left.',
        'Collect the requested markers and post-it notes and place them in the marketing room cabinet.',
        0.98
    ),
    (
        'FC003',
        'A4 printer paper depletion in Floor 18 copy room',
        'The primary printer in the Floor 18 engineering zone is completely out of A4 paper, and there are no spare boxes in the cabinet. We have urgent documents to print for the tax audit.',
        'Facilities',
        'medium',
        'low',
        'Copy room paper stock depletion requires restocking by the FC003 inventory team. SLA risk is LOW with a standard 4-hour response window (5 hours remaining).',
        'Deliver two boxes of standard 80gsm A4 printer paper from the storage room to the Floor 18 printer cabinet.',
        0.96
    ),
    (
        'FC003',
        'Restocking hand sanitizer and paper towels in Floor 18 kitchen',
        'Hi, the soap dispenser in the Floor 18 kitchen sink is empty and the paper towel roll has not been replaced. Please restock these sanitary items to maintain workplace hygiene.',
        'Facilities',
        'low',
        'low',
        'Hygiene consumables (hand soap and paper towels) are managed by FC003. SLA risk is LOW with 46 hours remaining on the facilities checklist.',
        'Fill the kitchen hand soap dispenser and place a fresh pack of paper towel rolls under the sink cabinet.',
        0.95
    ),
    (
        'FC003',
        'Ordering corporate notebooks and pens for upcoming engineering workshop',
        'We are hosting an engineering workshop in two weeks and we require 30 standard corporate branded notebooks and 30 blue gel pens for the participants. Can we allocate this from the store?',
        'Facilities',
        'low',
        'low',
        'Bulk stationery provisioning for training workshops falls under FC003 supply allocation. SLA risk is LOW since the event is in two weeks (53 hours remaining).',
        'Retrieve 30 branded notebooks and pens from the marketing asset locker and arrange delivery to the training coordinator.',
        0.97
    ),
    (
        'FC003',
        'Out of paper cups for drinking water dispenser in West wing',
        'The water dispenser in the West wing of Floor 18 has run out of disposable paper cups. Please deliver a sleeve of cups.',
        'Facilities',
        'low',
        'low',
        'Water dispenser paper cup restock request is forwarded to the FC003 pantry team. SLA risk is LOW with 43 hours remaining.',
        'Deliver two sleeves of paper cups to the West wing water station.',
        0.96
    ),
    (
        'FC003',
        'Requesting specialized color ink cartridges for designer printer',
        'The design studio printer (model Epson Stylus Pro) has run out of Cyan and Magenta ink. We cannot print physical mockup proofs for the client review tomorrow morning. Please purchase or release.',
        'Facilities',
        'medium',
        'low',
        'Specialized printer ink cartridge procurement belongs to FC003 office supplies. SLA risk is LOW with 16 hours remaining on the procurement SLA.',
        'Check ink cartridge storage for Epson model, release the Cyan/Magenta ink packs, and deliver to the design studio.',
        0.95
    ),
    (
        'FC003',
        'Tea bags and sugar refill request for Executive Conference Room',
        'The executive boardroom pantry is low on Lipton tea bags and sugar packets. There is a board meeting scheduled tomorrow morning. Please verify and refill.',
        'Facilities',
        'low',
        'low',
        'Refilling boardroom tea and sugar provisions is managed by FC003. SLA risk is LOW with 25 hours remaining.',
        'Refill the tea and sugar boxes in the boardroom pantry sideboard cabinet.',
        0.98
    ),
    (
        'FC003',
        'Hand soap dispenser refill in Floor 19 restroom corridor',
        'The hand soap dispenser at the washing corridor on Floor 19 East is empty. Please refill it to ensure proper sanitation.',
        'Facilities',
        'low',
        'low',
        'Hand soap dispenser replenishment in the Floor 19 restroom falls under FC003. SLA risk is LOW with 48 hours remaining.',
        'Refill the wall-mounted soap dispenser with corporate soap gel.',
        0.94
    ),
    (
        'FC003',
        'Allocating fruits and soft drinks for monthly townhall meeting',
        'Hi, we have our monthly townhall meeting this Friday. We need to allocate 50 cans of soft drinks, 20 bottles of juice, and 3 platters of mixed fruits. Budget code attached.',
        'Facilities',
        'medium',
        'low',
        'Townhall event catering and beverage orders are coordinated by the FC003 pantry team. SLA risk is LOW with 60 hours remaining.',
        'Order the soft drinks and juices from the supplier, coordinate with the fruit vendor for Friday morning delivery.',
        0.96
    ),
    (
        'HR001',
        'Payroll error: Incorrect bank routing for monthly salary disbursement',
        'My salary was not deposited into my bank account today. I checked my payroll portal and noticed that the bank account routing number was entered incorrectly. Today is the final payment cutoff. Please correct it urgently.',
        'HR',
        'high',
        'high',
        'Payroll processing failure with incorrect bank details is escalated to HR001. SLA breach risk is HIGH because the payroll bank cutoff window closes in 45 minutes, leaving only 30 minutes for manual payroll correction.',
        'Instantly contact the finance/payroll department, suspend the invalid bank transaction, update the routing details, and trigger a manual payroll wire transfer.',
        0.98
    ),
    (
        'HR001',
        'Question regarding Bao Viet Health Insurance coverage for dental',
        'Could you please clarify if our current corporate health insurance plan with Bao Viet covers orthodontics or regular dental scaling? I could not find this information in the employee handbook.',
        'HR',
        'low',
        'low',
        'Inquiry about health insurance provider benefits is handled by the HR001 C&B team. SLA risk is LOW since this is an informational query with a 3-day resolution window (72 hours left).',
        'Retrieve the Bao Viet dental benefits policy PDF, send it to the employee with the specific coverage limits highlighted, and close the ticket.',
        0.99
    ),
    (
        'HR001',
        'Maternity leave insurance process and allowance query',
        'Hi HR, I am starting my maternity leave next month. I need guidance on what documents to submit to finalise the social insurance (BHXH) maternity allowance claim and how the payment timeline works.',
        'HR',
        'medium',
        'low',
        'Social insurance maternity allowance application falls under HR001. SLA risk is LOW as it is an informational query with 46 hours remaining on the SLA.',
        'Provide the checklist of maternity documents (birth certificate, hospital discharge paper) and explain the BHXH submission process.',
        0.96
    ),
    (
        'HR001',
        'Discrepancy in monthly overtime (OT) payment calculation',
        'I reviewed my payslip for this month and noticed that my 15 hours of weekend overtime were not included in the salary disbursement. The payroll adjustment cutoff is today at 12:00 PM. Please verify.',
        'HR',
        'high',
        'high',
        'Overtime payment discrepancy requires auditing by HR001 payroll specialists. SLA BREACH WARNING: The SLA risk is HIGH because there are only 45 minutes left before the bank payroll file lock.',
        'Verify the timesheet approval in the system, issue a correction slip, and coordinate with the bank for a supplementary payroll deposit.',
        0.98
    ),
    (
        'HR001',
        'Requesting income verification letter for bank visa application',
        'Hi HR, I am applying for a travel visa and the embassy requires an official income verification letter signed by HR, along with my payslips for the last 3 months. I need this by Wednesday.',
        'HR',
        'medium',
        'low',
        'Generating income verification letters for visas is handled by the HR001 team. SLA risk is LOW as standard letters have a 48-hour response window (33 hours remaining).',
        'Generate the income verification letter, secure the HR director''s stamp, and notify the user to pick up the document.',
        0.95
    ),
    (
        'HR001',
        'Dependent tax deduction registration form submission',
        'I would like to register my newborn child as a dependent for personal income tax (PIT) reduction. I have attached the birth certificate and the completed registration form.',
        'HR',
        'low',
        'low',
        'Dependent PIT reduction registration forms are processed by the HR001 tax desk. SLA risk is LOW with a standard 5-day SLA (83 hours remaining).',
        'Review the birth certificate details, log the dependent registration in the tax filing portal, and update the payroll deduction profile.',
        0.97
    ),
    (
        'HR001',
        'Social insurance book (So BHXH) collection query after transfer',
        'I recently transferred from another branch and I need to submit my social insurance book to the head office for integration. Can you please confirm who I should hand it over to?',
        'HR',
        'low',
        'low',
        'Social insurance book integration for transferred employees belongs to HR001. SLA risk is LOW with 120 hours remaining.',
        'Provide instructions on physical delivery of the book to the C&B specialist and update the tracking status.',
        0.95
    ),
    (
        'HR001',
        'Meal allowance card not receiving monthly balance',
        'My corporate meal allowance card was not credited with this month''s balance ($50). All my colleagues received theirs yesterday. Please check if my card ID is mapped correctly.',
        'HR',
        'medium',
        'low',
        'Meal allowance card credit issues are investigated by the HR001 C&B department. SLA risk is LOW with 30 hours remaining.',
        'Verify the employee''s active record, cross-reference with the meal card vendor sheet, and issue a card balance reload order.',
        0.94
    ),
    (
        'HR001',
        'Clarification on annual leave balance correction',
        'The HR portal shows my annual leave balance as 10 days, but according to my calculations and previous approvals, it should be 12 days. I think my business trip leave was logged incorrectly.',
        'HR',
        'low',
        'low',
        'Leave balance correction and audit requests fall under HR001 administration. SLA risk is LOW with 66 hours remaining.',
        'Review the employee''s leave history, check the business trip attendance log, and adjust the balance count in the system.',
        0.96
    ),
    (
        'HR001',
        'Query about company wellness allowance reimbursement limits',
        'Hi, I want to sign up for a gym membership and I want to know if the company wellness allowance of $100 covers gym fees, or if it is restricted to medical checks. Please send the guideline.',
        'HR',
        'low',
        'low',
        'Wellness allowance program scope query is answered by HR001 benefits specialists. SLA risk is LOW with 58 hours remaining.',
        'Provide the wellness benefit policy PDF document outlining eligible expense items.',
        0.97
    ),
    (
        'HR002',
        'New workstation and desk setup request for incoming Backend Engineer',
        'We have a Senior Go Developer joining our team next Monday (July 1st). Please coordinate with IT to ensure their desk space is set up, monitor is mounted, and onboarding kit is prepared by Friday.',
        'HR',
        'medium',
        'low',
        'New employee workstation onboarding preparation is managed by the HR002 team. SLA risk is LOW because there are 96 hours remaining until the onboarding date.',
        'Coordinate with Floor Admin and IT to assign a desk location, place the welcoming onboarding package, and log a ticket for hardware provisioning.',
        0.94
    ),
    (
        'HR002',
        'Requesting budget approval for external training course',
        'I would like to request approval to attend the Advanced Concurrency in Go training course next month. The budget is $250. My manager has already signed the approval form attached below.',
        'HR',
        'low',
        'low',
        'External training course budget approval request is processed by HR002 L&D. SLA risk is LOW with over 166 hours remaining on the training approval pipeline.',
        'Review the training budget balance for the requestor''s department, approve the purchase request, and notify the employee of the registration procedure.',
        0.98
    ),
    (
        'HR002',
        'Leadership training course enrollment issue',
        'I was assigned to the Leadership Training Course, but when I click the link, it shows a registration error. The training session starts in 3 days. Please add me to the roster.',
        'HR',
        'low',
        'low',
        'Training enrollment and course registration issues fall under the HR002 LMS admin. SLA risk is LOW since the session is in 3 days (120 hours remaining).',
        'Verify the user eligibility in LMS, manually add the employee to the attendee list, and trigger the enrollment confirmation email.',
        0.95
    ),
    (
        'HR002',
        'Scheduling technical interview for senior role candidate today',
        'We have a strong Senior Architect candidate who is only available for a technical interview today at 5:00 PM. We need HR to coordinate the Zoom setup and invite the panel before 4:00 PM.',
        'HR',
        'high',
        'high',
        'Technical interview scheduling for active job candidates is coordinated by HR002. SLA BREACH WARNING: SLA risk is HIGH because there are only 40 minutes left to secure the panel slots.',
        'Quickly verify panel calendar availability, set up the Zoom meeting link, send the calendar invite, and notify the candidate.',
        0.96
    ),
    (
        'HR002',
        'Probation review meeting scheduling request',
        'Hi HR, our new frontend engineer is completing their 2-month probation next week. We need to schedule their probation review meeting with the engineering head and HR partner.',
        'HR',
        'medium',
        'low',
        'Employee probation review scheduling and documentation belongs to HR002. SLA risk is LOW with 40 hours remaining on the performance timeline.',
        'Send a calendar invitation to the manager and employee, attach the probation review form, and schedule the discussion slot.',
        0.95
    ),
    (
        'HR002',
        'Activating team access to corporate Udemy accounts',
        'Our project team requires access to Udemy Business to follow a course on Kubernetes administration. Please allocate 5 license keys for our team members.',
        'HR',
        'low',
        'low',
        'Udemy license provisioning for team upskilling is managed by the HR002 training desk. SLA risk is LOW since license allocation has a 3-day SLA (80 hours remaining).',
        'Assign 5 vacant Udemy Business licenses to the requested employee emails in the admin portal.',
        0.97
    ),
    (
        'HR002',
        'Uploading onboarding orientation materials for Q3 batch',
        'Hi, I have updated the company culture presentation slides and the employee handbook for the Q3 batch of new hires. Please upload these files to the onboarding portal.',
        'HR',
        'low',
        'low',
        'Uploading Q3 orientation materials to the LMS is assigned to HR002. SLA risk is LOW with 60 hours remaining.',
        'Upload the PDF files to the employee learning platform and update the default Q3 onboarding path package.',
        0.94
    ),
    (
        'HR002',
        'Scheduling post-probation contract signing',
        'The probation review for employee ID 8820 was successful. We need HR to prepare the official 1-year labor contract and schedule the signing session.',
        'HR',
        'medium',
        'low',
        'Labor contract preparation following a successful probation review is handled by HR002. SLA risk is LOW with 25 hours remaining on the HR contract queue.',
        'Prepare the standard 1-year labor contract draft, secure the director''s digital stamp, and schedule a physical signing meeting.',
        0.95
    ),
    (
        'HR002',
        'Arranging language training course sponsorship for Sales team',
        'Our Sales director has approved English language training sponsorship for 3 team members. Please coordinate with the partner language center to set up their placement tests.',
        'HR',
        'low',
        'low',
        'Language course sponsorship coordination with external partners falls under HR002. SLA risk is LOW with over 150 hours remaining.',
        'Contact the language center account manager, send candidate details, and arrange placement test slots.',
        0.97
    ),
    (
        'HR002',
        'Requisition approval request: Hiring additional QA Engineer',
        'We need to hire an additional QA Engineer for the logistics project due to scope increase. The director has approved the headcount. Please open the job requisition on the portal.',
        'HR',
        'medium',
        'low',
        'Creating job requisitions for QA engineering vacancies belongs to HR002 recruitment. SLA risk is LOW with 83 hours remaining.',
        'Review headcount approval details, publish the job opening on the corporate careers page, and assign the recruiting recruiter.',
        0.96
    ),
    (
        'HR003',
        'Harassment report and hostile work environment incident',
        'I need to report an incident of verbal abuse and bullying that occurred during our team meeting this morning. I feel completely unsafe working under my current supervisor. Please schedule an urgent confidential meeting.',
        'HR',
        'high',
        'high',
        'Confidential harassment report requires immediate intake and investigation by HR003. SLA risk is HIGH because company policy mandates initiation of a formal investigation within 2 hours of a hostile environment report, and only 40 minutes remain.',
        'Immediately contact the requestor to schedule a private, secure intake interview. Notify the Head of HR and document the incident timeline.',
        0.99
    ),
    (
        'HR003',
        'Proposal for Q3 Team Building activity and budget guidelines',
        'Our team is planning our Q3 team building trip for late August. Could you please send us the current guidelines on the budget limit per person and the list of approved travel agencies?',
        'HR',
        'low',
        'low',
        'Team building activity guidelines and travel agency lists are provided by HR003. SLA risk is LOW as it is a routine inquiry about event budgets with a 5-day SLA (120 hours remaining).',
        'Provide the team building budget policy document and the list of preferred vendor agencies via email response.',
        0.96
    ),
    (
        'HR003',
        'Offboarding process and resignation intake interview scheduling',
        'I am writing to officially submit my resignation. My last working day will be July 31st. I need HR to guide me through the offboarding checklist, asset return, and schedule my exit interview.',
        'HR',
        'medium',
        'low',
        'Resignation submission and offboarding exit interview scheduling falls under HR003. SLA risk is LOW since there are several weeks left before the last day (46 hours remaining on the request SLA).',
        'Acknowledge the resignation, share the offboarding guidelines PDF, and send a calendar invite for the exit interview.',
        0.95
    ),
    (
        'HR003',
        'Mediating critical interpersonal conflict within the Development squad',
        'There was a severe verbal conflict between the PM and Tech Lead during our planning session today. Both are refusing to work together, blocking the current sprint. We need HR to mediate immediately.',
        'HR',
        'high',
        'high',
        'Interpersonal conflict mediation within the engineering squad is handled by HR003. SLA BREACH WARNING: The SLA risk is HIGH because operations are blocked, and only 1 hour remains on the conflict resolution intervention SLA.',
        'Schedule a joint mediation session with the PM, Tech Lead, and the ER manager in a private meeting room.',
        0.97
    ),
    (
        'HR003',
        'Suggestion box: Office environment acoustic noise issues on Floor 18',
        'Hi HR, the open workspace on Floor 18 has become extremely noisy due to loud discussions in the adjacent corridor. It is hard to concentrate. Can we implement quiet zone rules or noise barrier panels?',
        'HR',
        'low',
        'low',
        'Acoustic noise feedback for Floor 18 workspace belongs to HR003 employee relations. SLA risk is LOW with 133 hours remaining.',
        'Acknowledge the feedback, review the noise complaints with the Admin Lead, and draft a ''Workplace Etiquette'' email announcement.',
        0.94
    ),
    (
        'HR003',
        'Submitting feedback on recent company Year End Party organization',
        'I want to submit some suggestions regarding the location and catering options for future corporate events based on my experience at the recent Year End Party. I hope this helps improve future planning.',
        'HR',
        'low',
        'low',
        'Year End Party suggestions and feedback are logged by the HR003 culture committee. SLA risk is LOW with 158 hours remaining.',
        'Log the feedback in the culture committee database for event planning reviews.',
        0.96
    ),
    (
        'HR003',
        'Requesting exit interview scheduling for departing Senior QA Engineer',
        'Our Senior QA Engineer is leaving next week. We need to schedule their exit interview to gather their feedback on our team structure and development pipeline.',
        'HR',
        'low',
        'low',
        'Exit interview scheduling for a departing employee is handled by HR003 relations. SLA risk is LOW with 48 hours remaining.',
        'Coordinate a 30-minute exit discussion slot and prepare the exit questionnaire.',
        0.97
    ),
    (
        'HR003',
        'Planning charity volunteer event and employee sign-up list',
        'We want to organize a weekend volunteer activity at the local shelter next month. Please check if the company can sponsor transportation and help distribute the sign-up sheet.',
        'HR',
        'low',
        'low',
        'Charity volunteer event planning and sign-up coordination is managed by HR003. SLA risk is LOW with 141 hours remaining.',
        'Review the CSR budget, approve the transport subsidy, and create the volunteer sign-up spreadsheet on the intranet.',
        0.95
    ),
    (
        'HR003',
        'Hostile workplace safety concern raised by junior engineer',
        'A junior developer just reported that their manager has been sending threatening messages and demanding they work unpaid hours. The developer is highly distressed. Please intervene.',
        'HR',
        'high',
        'high',
        'Intervention in unpaid overtime demands and manager abuse is escalated to HR003. SLA BREACH WARNING: SLA risk is HIGH because distress/threat reports require swift intervention, and only 30 minutes remain.',
        'Immediately schedule a separate interview with the developer to document the messages and escalate the case to the ER director.',
        0.98
    ),
    (
        'HR003',
        'Question regarding Non-Disclosure Agreement (NDA) rules for employee personal blogs',
        'Hi, I write technical articles on my personal Medium blog. I want to clarify if there are any corporate NDA restrictions about discussing general system architectures without naming the company.',
        'HR',
        'low',
        'low',
        'NDA policy clarification regarding personal blog articles is answered by HR003. SLA risk is LOW with 100 hours remaining.',
        'Review the company NDA policy details and send a formal response clarifying what information can be shared publicly.',
        0.96
    ),

    (
        'IT001',
        'Missing power adapter for conference room presentation screen',
        'The main presentation screen in Room 3B is missing its power adapter. I have a client presentation at 2 PM and need a replacement immediately.',
        'IT',
        'high',
        'high',
        'Hardware allocation required for presentation screen in Room 3B (IT001). SLA risk is LOW since there are 4 hours left before the presentation.',
        'Deliver a compatible power adapter to Room 3B immediately.',
        0.96
    ),
    (
        'IT001',
        'Upgrade RAM from 16GB to 32GB for data science workflow',
        'My current 16GB laptop is constantly freezing when processing large datasets. Manager approved a 32GB RAM upgrade. Please advise when I can bring my laptop in.',
        'IT',
        'medium',
        'low',
        'Hardware upgrade request for increased RAM falls under IT001. SLA risk is LOW with 72 hours remaining for standard hardware upgrades.',
        'Schedule a time with the user to install the 32GB RAM kit.',
        0.95
    ),
    (
        'IT001',
        'Damaged HDMI port on corporate laptop',
        'The HDMI port on my laptop is bent and no longer outputs video to external monitors. The laptop is still under warranty.',
        'IT',
        'low',
        'low',
        'Physical damage to laptop port maps to IT001 (Hardware Support) for repair or warranty claim. SLA risk is LOW with 48 hours remaining.',
        'Provide a temporary loaner laptop and send the damaged unit for warranty repair.',
        0.94
    ),
    (
        'IT001',
        'Request for noise-canceling headphones for open office plan',
        'The noise level on Floor 18 is making it hard to take client calls. I''d like to request a pair of standard corporate noise-canceling headphones.',
        'IT',
        'low',
        'low',
        'Peripheral hardware request for headphones is managed by IT001. SLA risk is LOW with 5 days remaining for standard procurement.',
        'Order or allocate a pair of noise-canceling headphones for the user.',
        0.92
    ),
    (
        'IT002',
        'Zoom client crashing repeatedly on startup after OS update',
        'After upgrading to macOS Sonoma, Zoom crashes immediately every time I open it. Reinstalling didn''t help. I need this fixed for my daily standups.',
        'IT',
        'high',
        'high',
        'Software troubleshooting for local application crash belongs to IT002. SLA risk is LOW since the user can use web clients temporarily, leaving 24 hours on the clock.',
        'Clear Zoom cache and application support files, then perform a clean installation.',
        0.97
    ),
    (
        'IT002',
        'Stale DNS records preventing access to staging environment',
        'The staging domain points to the old IP address from yesterday''s migration. Can we flush the internal DNS cache or update the records?',
        'IT',
        'medium',
        'low',
        'Internal DNS configuration issue is handled by IT002 network admins. SLA risk is LOW with 8 hours remaining for non-production environments.',
        'Flush the internal DNS cache and verify the new IP propagation.',
        0.98
    ),
    (
        'IT002',
        'Inconsistent VPN speeds during peak afternoon hours',
        'Every day around 3 PM, the VPN connection slows down to 100kbps, making it impossible to pull large docker images from the registry.',
        'IT',
        'medium',
        'low',
        'Network performance degradation investigation maps to IT002. SLA risk is LOW with 48 hours remaining for performance tuning tasks.',
        'Analyze VPN gateway throughput logs during peak hours and adjust bandwidth allocation.',
        0.95
    ),
    (
        'IT002',
        'Request installation of Adobe Creative Cloud suite',
        'I transferred to the marketing team and need the full Adobe CC suite installed and licensed on my workstation.',
        'IT',
        'low',
        'low',
        'Software installation and licensing request is assigned to IT002. SLA risk is LOW with 72 hours remaining for standard software provisioning.',
        'Deploy the Adobe Creative Cloud package to the user''s machine via MDM.',
        0.96
    ),
    (
        'IT003',
        'Email from CEO requesting urgent gift card purchase looks suspicious',
        'I received an email claiming to be from our CEO asking me to buy $500 in gift cards. The sender email domain looks slightly misspelled.',
        'IT',
        'high',
        'high',
        'Potential phishing attempt requires investigation by IT003 security team. SLA risk is HIGH as active phishing campaigns need to be blocked within 2 hours.',
        'Analyze email headers, block the sender domain, and run a message trace across the organization.',
        0.99
    ),
    (
        'IT003',
        'Revoke AWS admin access for transferred employee',
        'Employee John Doe moved from backend engineering to product management. Please remove his AWS production admin access but keep his Jira access.',
        'IT',
        'medium',
        'low',
        'Identity and Access Management (IAM) permissions update is handled by IT003. SLA risk is LOW with 24 hours remaining for access trimming.',
        'Remove the user from the AWS Admin IAM group.',
        0.98
    ),
    (
        'IT003',
        'Blocked by firewall when accessing partner API endpoint',
        'Our new payment gateway integration requires outbound calls to a specific IP range, but the corporate firewall is dropping the packets. Need a firewall rule exception.',
        'IT',
        'medium',
        'low',
        'Firewall rule modification for outbound traffic is managed by IT003 network security. SLA risk is LOW with 48 hours remaining on the request.',
        'Review the security implications and implement an outbound firewall rule exception.',
        0.96
    ),
    (
        'IT003',
        'Routine vulnerability scan showed outdated Apache version on dev server',
        'The weekly Nessus scan flagged dev-server-04 for running an old version of Apache with known CVEs. Please patch it.',
        'IT',
        'low',
        'low',
        'Vulnerability management and patching request assigned to IT003. SLA risk is LOW since it is a dev server with a 7-day remediation window.',
        'Schedule a patching window and update Apache to the latest stable version.',
        0.97
    ),
    (
        'FC001',
        'Leaking pipe under the sink in Floor 19 pantry',
        'There is a small puddle of water forming under the sink in the Floor 19 pantry. It looks like the P-trap is leaking.',
        'Facilities',
        'medium',
        'low',
        'Minor plumbing leak in the pantry is routed to FC001 maintenance. SLA risk is LOW with 24 hours remaining to fix non-critical leaks.',
        'Tighten or replace the P-trap under the sink and clean up the water.',
        0.95
    ),
    (
        'FC001',
        'Broken handle on the main exit door of stairwell B',
        'The handle on the fire exit door in stairwell B is loose and almost falling off. It needs to be tightened or replaced.',
        'Facilities',
        'high',
        'high',
        'Building hardware repair for egress doors falls under FC001. SLA risk is LOW with 48 hours remaining for standard door maintenance.',
        'Inspect and replace the door handle mechanism immediately to ensure fire safety.',
        0.98
    ),
    (
        'FC001',
        'Request for deep cleaning of the carpets in the boardroom',
        'The carpets in the main boardroom have several coffee stains and look dirty. Can we schedule a deep shampoo cleaning this weekend?',
        'Facilities',
        'low',
        'low',
        'Janitorial services for carpet deep cleaning are handled by FC001. SLA risk is LOW with 5 days remaining before the requested weekend cleaning.',
        'Schedule a commercial carpet cleaning vendor for the weekend.',
        0.94
    ),
    (
        'FC001',
        'Strange rattling noise from the ceiling AC vent in my cubicle',
        'Every time the AC turns on, there is a loud metallic rattling noise coming from the vent above desk 18-042. It''s very distracting.',
        'Facilities',
        'low',
        'low',
        'HVAC noise investigation requires physical inspection by FC001 technicians. SLA risk is LOW with 72 hours remaining for comfort-related maintenance.',
        'Inspect the AC vent and secure any loose metal louvers or ducting.',
        0.93
    ),
    (
        'FC002',
        'Register VIP guest parking space for client visit',
        'We have a VIP client arriving tomorrow at 10 AM. Please reserve a visitor parking spot near the elevator and register their license plate (51F-123.45).',
        'Facilities',
        'medium',
        'low',
        'Visitor parking reservation is managed by FC002 reception desk. SLA risk is LOW with 20 hours remaining before the client''s arrival.',
        'Reserve a VIP parking spot and notify building security of the license plate.',
        0.97
    ),
    (
        'FC002',
        'Outgoing mail: 50 envelopes to be stamped and mailed',
        'The marketing team has 50 promotional letters that need to be stamped and handed over to the postal service by Friday.',
        'Facilities',
        'low',
        'low',
        'Bulk outgoing mail processing falls under FC002 mailroom services. SLA risk is LOW with 48 hours remaining before the postal cutoff.',
        'Frank the envelopes and schedule a pickup with the local postal service.',
        0.96
    ),
    (
        'FC002',
        'Arrange catering for all-hands meeting next Wednesday',
        'Please arrange finger foods, coffee, and tea for 80 people for the quarterly all-hands meeting in the townhall space next Wednesday at 3 PM.',
        'Facilities',
        'low',
        'low',
        'Event catering coordination is handled by FC002 facility scheduling. SLA risk is LOW with 7 days remaining before the event.',
        'Contact the corporate caterer and finalize the menu and delivery time.',
        0.95
    ),
    (
        'FC002',
        'Missing umbrella from the lobby umbrella stand',
        'I left my blue corporate umbrella in the lobby stand yesterday, but it''s gone today. Can you check the lost and found or the CCTV?',
        'Facilities',
        'low',
        'low',
        'Lost and found inquiries at the lobby are managed by FC002 receptionists. SLA risk is LOW with 72 hours remaining for the investigation.',
        'Check the lost and found bin and review lobby CCTV footage if necessary.',
        0.92
    ),
    (
        'FC003',
        'Order new whiteboard markers for all meeting rooms',
        'Almost all the meeting rooms on Floor 18 have dry or missing whiteboard markers. Please order a bulk box of black and blue markers.',
        'Facilities',
        'low',
        'low',
        'Office supply replenishment for meeting rooms is handled by FC003. SLA risk is LOW with 48 hours remaining for standard stationery orders.',
        'Order a bulk supply of markers and distribute them to the meeting rooms.',
        0.96
    ),
    (
        'FC003',
        'Restock first aid kit in the Floor 19 breakroom',
        'The first aid kit is missing bandaids and antiseptic wipes. Please restock it as soon as possible.',
        'Facilities',
        'high',
        'low',
        'First aid consumable replenishment falls under FC003 inventory management. SLA risk is LOW with 24 hours remaining for safety supply restocking.',
        'Replenish the missing items in the first aid kit from the central medical supply.',
        0.98
    ),
    (
        'FC003',
        'Request for specific brand of green tea in the pantry',
        'Several team members have requested if we could stock Matcha green tea bags instead of just the standard Lipton tea.',
        'Facilities',
        'low',
        'low',
        'Pantry consumable requests are managed by FC003. SLA risk is LOW with 5 days remaining to review and process pantry inventory changes.',
        'Review the pantry budget and add Matcha green tea to the next grocery order.',
        0.93
    ),
    (
        'FC003',
        'Printer paper empty in the marketing department printer',
        'The high-volume printer in the marketing area is completely out of A4 and A3 paper. We have a large print run to do this afternoon.',
        'Facilities',
        'high',
        'high',
        'Copy room paper restocking requires immediate attention by FC003. SLA risk is LOW with 4 hours remaining before the print run.',
        'Immediately dispatch a facilities assistant with boxes of A4 and A3 paper.',
        0.97
    ),
    (
        'HR001',
        'Clarification on bonus tax deduction for last month',
        'My payslip shows a higher tax deduction on my quarterly bonus than I expected. Can someone explain the PIT calculation used?',
        'HR',
        'low',
        'low',
        'Payroll tax calculation inquiries are answered by the HR001 C&B team. SLA risk is LOW with 72 hours remaining for standard payroll queries.',
        'Review the employee''s PIT calculation and provide a detailed breakdown.',
        0.95
    ),
    (
        'HR001',
        'Apply for 3 days of paternity leave next week',
        'My wife is due next week, and I need to apply for 3 days of statutory paternity leave. Please let me know what documents are required.',
        'HR',
        'medium',
        'low',
        'Statutory leave applications and documentation fall under HR001 administration. SLA risk is LOW with 5 days remaining before the leave starts.',
        'Provide the paternity leave application form and request the birth certificate later.',
        0.96
    ),
    (
        'HR001',
        'Update bank account details for next payroll cycle',
        'I have closed my old bank account and opened a new one with Vietcombank. Please update my direct deposit details for the upcoming payroll.',
        'HR',
        'medium',
        'low',
        'Employee bank detail updates are processed by HR001 payroll specialists. SLA risk is LOW with 10 days remaining before the payroll cutoff.',
        'Send a secure link for the employee to update their direct deposit information.',
        0.97
    ),
    (
        'HR001',
        'Request for annual leave balance report for the engineering team',
        'As the engineering manager, I need a report showing the remaining annual leave balances for all my team members to plan holiday coverage.',
        'HR',
        'low',
        'low',
        'Leave balance reporting for managers is handled by HR001. SLA risk is LOW with 48 hours remaining to generate the administrative report.',
        'Export the leave balance report from the HRIS and send it to the manager.',
        0.94
    ),
    (
        'HR002',
        'Schedule final round interview for Senior Frontend Developer',
        'The candidate passed the technical test. Please schedule a 1-hour final interview with the CTO and HR Director for sometime next week.',
        'HR',
        'medium',
        'low',
        'Interview coordination for senior candidates is managed by HR002 recruitment. SLA risk is LOW with 48 hours remaining to secure the calendar slots.',
        'Coordinate calendar availability between the CTO, HR Director, and candidate.',
        0.96
    ),
    (
        'HR002',
        'Feedback on the recent leadership training workshop',
        'I attended the leadership workshop last Friday and wanted to submit some constructive feedback regarding the course material and pacing.',
        'HR',
        'low',
        'low',
        'Training feedback collection and review falls under HR002 Learning & Development. SLA risk is LOW with 7 days remaining for course evaluation processing.',
        'Log the feedback in the training evaluation system and forward to the instructor.',
        0.94
    ),
    (
        'HR002',
        'Request to open an internship position for the summer',
        'The marketing team would like to hire a summer intern to help with social media campaigns. Can we open a requisition and start posting to universities?',
        'HR',
        'low',
        'low',
        'Creating new internship requisitions belongs to HR002 recruitment. SLA risk is LOW with 14 days remaining before the target posting date.',
        'Create the internship job requisition and publish it to university portals.',
        0.95
    ),
    (
        'HR002',
        'Certificate of completion needed for compliance training',
        'I completed the mandatory data privacy compliance training on the LMS yesterday, but I cannot download my certificate. It shows an error.',
        'HR',
        'medium',
        'low',
        'LMS technical issues and certificate generation are handled by HR002 LMS admins. SLA risk is LOW with 72 hours remaining for training support.',
        'Investigate the LMS error and manually generate the completion certificate.',
        0.97
    ),
    (
        'HR003',
        'Request for ergonomic assessment of my workstation',
        'I''ve been having lower back pain recently. Can someone from HR conduct an ergonomic assessment of my desk and chair setup?',
        'HR',
        'low',
        'low',
        'Employee wellness assessments are coordinated by HR003 employee relations. SLA risk is LOW with 5 days remaining to schedule the assessment.',
        'Schedule an ergonomic evaluation with the workplace safety officer.',
        0.95
    ),
    (
        'HR003',
        'Suggestion for a company-wide steps challenge',
        'To promote health, I suggest we organize a month-long step counting challenge with small prizes for the most active teams.',
        'HR',
        'low',
        'low',
        'Wellness program suggestions are reviewed by the HR003 culture committee. SLA risk is LOW with 14 days remaining for program evaluation.',
        'Review the suggestion in the next culture committee meeting and allocate a budget.',
        0.94
    ),
    (
        'HR003',
        'Dispute over shared desk allocation on Floor 19',
        'There is an ongoing disagreement between the sales and marketing teams over who gets to use the hot desks near the windows. Need HR mediation.',
        'HR',
        'medium',
        'low',
        'Inter-team conflict mediation over office resources falls under HR003. SLA risk is LOW with 72 hours remaining for HR intervention.',
        'Schedule a mediation meeting with the managers of both teams to establish a fair rotation policy.',
        0.96
    ),
    (
        'HR003',
        'Update emergency contact information',
        'I recently got married and need to update my primary emergency contact from my parents to my spouse.',
        'HR',
        'low',
        'low',
        'Employee personal information updates are processed by HR003 administration. SLA risk is LOW with 5 days remaining for record updates.',
        'Direct the employee to the self-service portal to update their emergency contacts.',
        0.97
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming Designer',
        'Hi Helpdesk, We have a new Designer joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT001 for onboarding hardware allocation. SLA risk is LOW because we currently have 28 hours remaining before the standard SLA breach.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.94
    ),
    (
        'IT001',
        'Defective or broken corporate SSD',
        'Hello, I am working on an important project right now. My issued SSD has stopped working entirely. It started glitching yesterday. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Classification: Categorized under IT001 for physical hardware failure of SSD. SLA risk is MEDIUM because we currently have 35 hours remaining before the standard SLA breach.',
        'Verify warranty status, issue a replacement SSD from local stock, and recycle the defective unit.',
        0.93
    ),
    (
        'IT001',
        'Temporary loaner laptop needed for Hanoi branch travel',
        'Hi Helpdesk, I am travelling to Hanoi branch for a business trip next week. I prefer not to take my bulky engineering workstation. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Allocated to IT001 to handle temporary equipment loan for travel to Hanoi branch. SLA risk is LOW as the deadline is stable, leaving 52 hours on the operational timeline.',
        'Provision a lightweight 13-inch loaner laptop, configure basic VPN access, and schedule pickup.',
        0.95
    ),
    (
        'IT001',
        'Ergonomic workspace request: Footrest',
        'To whom it may concern, I have been experiencing some physical discomfort at my desk. My manager approved the request for a Footrest. This is causing medical strain. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT001 for medical or ergonomic peripheral request (Footrest). SLA risk is LOW because we currently have 54 hours remaining before the standard SLA breach.',
        'Check inventory for Footrest. If out of stock, initiate a purchase order through the IT procurement portal.',
        0.95
    ),
    (
        'IT001',
        'End-of-life hardware refresh for 2019 Macbook Pro',
        'To whom it may concern, My current device is over 4 years old and out of warranty. The 2019 Macbook Pro is severely impacting my productivity due to lag. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires lifecycle hardware replacement for 2019 Macbook Pro. SLA Breach risk is LOW; this standard request has a resolution window with 56 hours remaining on the clock.',
        'Verify the asset tag against the lifecycle database. If eligible, schedule a data migration and hardware swap.',
        0.95
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming PM',
        'To whom it may concern, We have a new PM joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires onboarding hardware allocation. SLA Breach risk is LOW; this standard request has a resolution window with 29 hours remaining on the clock.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.95
    ),
    (
        'IT001',
        'Defective or broken corporate Keyboard',
        'Hello, I am working on an important project right now. My issued Keyboard has stopped working entirely. It started glitching yesterday. I cannot complete my pending tasks without this. Please arrange a replacement today.',
        'IT',
        'medium',
        'low',
        'Allocated to IT001 to handle physical hardware failure of Keyboard. SLA risk is MEDIUM as the deadline is stable, leaving 49 hours on the operational timeline.',
        'Verify warranty status, issue a replacement Keyboard from local stock, and recycle the defective unit.',
        0.92
    ),
    (
        'IT001',
        'Temporary loaner laptop needed for Trade show travel',
        'Urgent request: I am travelling to Trade show for a business trip next week. I prefer not to take my bulky engineering workstation. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires temporary equipment loan for travel to Trade show. SLA Breach risk is LOW; this standard request has a resolution window with 44 hours remaining on the clock.',
        'Provision a lightweight 13-inch loaner laptop, configure basic VPN access, and schedule pickup.',
        0.96
    ),
    (
        'IT001',
        'Ergonomic workspace request: Footrest',
        'To whom it may concern, I have been experiencing some physical discomfort at my desk. My manager approved the request for a Footrest. This is severely impacting my daily work. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Allocated to IT001 to handle medical or ergonomic peripheral request (Footrest). SLA risk is LOW as the deadline is stable, leaving 57 hours on the operational timeline.',
        'Check inventory for Footrest. If out of stock, initiate a purchase order through the IT procurement portal.',
        0.93
    ),
    (
        'IT001',
        'End-of-life hardware refresh for old Thinkpad T480',
        'Hi Helpdesk, My current device is over 4 years old and out of warranty. The old Thinkpad T480 is severely impacting my productivity due to lag. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires lifecycle hardware replacement for old Thinkpad T480. SLA Breach risk is LOW; this standard request has a resolution window with 45 hours remaining on the clock.',
        'Verify the asset tag against the lifecycle database. If eligible, schedule a data migration and hardware swap.',
        0.96
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming HR Specialist',
        'Urgent request: We have a new HR Specialist joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. They cannot start working without the equipment. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires onboarding hardware allocation. SLA Breach risk is LOW; this standard request has a resolution window with 57 hours remaining on the clock.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.94
    ),
    (
        'IT001',
        'Defective or broken corporate Keyboard',
        'Dear Support Team, I am working on an important project right now. My issued Keyboard has stopped working entirely. It started glitching yesterday. I need a replacement to continue my work. Please advise on the next steps.',
        'IT',
        'medium',
        'low',
        'Assigned to IT001 since the user requires physical hardware failure of Keyboard. SLA Breach risk is MEDIUM; this standard request has a resolution window with 43 hours remaining on the clock.',
        'Verify warranty status, issue a replacement Keyboard from local stock, and recycle the defective unit.',
        0.93
    ),
    (
        'IT001',
        'Temporary loaner laptop needed for Remote WFH travel',
        'To whom it may concern, I am travelling to Remote WFH for a business trip next week. I prefer not to take my bulky engineering workstation. I need access to emails and VPN while travelling. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires temporary equipment loan for travel to Remote WFH. SLA Breach risk is LOW; this standard request has a resolution window with 67 hours remaining on the clock.',
        'Provision a lightweight 13-inch loaner laptop, configure basic VPN access, and schedule pickup.',
        0.94
    ),
    (
        'IT001',
        'Ergonomic workspace request: Monitor arm',
        'Hi Helpdesk, I have been experiencing some physical discomfort at my desk. My manager approved the request for a Monitor arm. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Allocated to IT001 to handle medical or ergonomic peripheral request (Monitor arm). SLA risk is LOW as the deadline is stable, leaving 42 hours on the operational timeline.',
        'Check inventory for Monitor arm. If out of stock, initiate a purchase order through the IT procurement portal.',
        0.97
    ),
    (
        'IT001',
        'End-of-life hardware refresh for outdated iPad',
        'Hello, My current device is over 4 years old and out of warranty. The outdated iPad is severely impacting my productivity due to lag. It frequently freezes during operations. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT001 for lifecycle hardware replacement for outdated iPad. SLA risk is LOW because we currently have 51 hours remaining before the standard SLA breach.',
        'Verify the asset tag against the lifecycle database. If eligible, schedule a data migration and hardware swap.',
        0.96
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming HR Specialist',
        'Urgent request: We have a new HR Specialist joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. I cannot complete my pending tasks without this. Needs to be placed at their assigned desk.',
        'IT',
        'low',
        'low',
        'Allocated to IT001 to handle onboarding hardware allocation. SLA risk is LOW as the deadline is stable, leaving 42 hours on the operational timeline.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.98
    ),
    (
        'IT001',
        'Defective or broken corporate Headset',
        'Hello, I am working on an important project right now. My issued Headset has stopped working entirely. It started glitching yesterday. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Determined to be a physical hardware failure of Headset case suitable for IT001. SLA risk is MEDIUM: the applicable policy allows a standard turnaround time, leaving 17 hours remaining.',
        'Verify warranty status, issue a replacement Headset from local stock, and recycle the defective unit.',
        0.92
    ),
    (
        'IT001',
        'Temporary loaner laptop needed for Singapore travel',
        'Urgent request: I am travelling to Singapore for a business trip next week. I prefer not to take my bulky engineering workstation. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Determined to be a temporary equipment loan for travel to Singapore case suitable for IT001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 15 hours remaining.',
        'Provision a lightweight 13-inch loaner laptop, configure basic VPN access, and schedule pickup.',
        0.95
    ),
    (
        'IT001',
        'Ergonomic workspace request: Split keyboard',
        'To whom it may concern, I have been experiencing some physical discomfort at my desk. My manager approved the request for a Split keyboard. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires medical or ergonomic peripheral request (Split keyboard). SLA Breach risk is LOW; this standard request has a resolution window with 25 hours remaining on the clock.',
        'Check inventory for Split keyboard. If out of stock, initiate a purchase order through the IT procurement portal.',
        0.93
    ),
    (
        'IT001',
        'End-of-life hardware refresh for 2019 Macbook Pro',
        'Hi Helpdesk, My current device is over 4 years old and out of warranty. The 2019 Macbook Pro is severely impacting my productivity due to lag. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires lifecycle hardware replacement for 2019 Macbook Pro. SLA Breach risk is LOW; this standard request has a resolution window with 64 hours remaining on the clock.',
        'Verify the asset tag against the lifecycle database. If eligible, schedule a data migration and hardware swap.',
        0.96
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming Data Analyst',
        'Hi Helpdesk, We have a new Data Analyst joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. They cannot start working without the equipment. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT001 for onboarding hardware allocation. SLA risk is LOW because we currently have 46 hours remaining before the standard SLA breach.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.97
    ),
    (
        'IT001',
        'Defective or broken corporate RAM',
        'Hi Helpdesk, I am working on an important project right now. My issued RAM has stopped working entirely. It started glitching yesterday. I need a replacement to continue my work. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Allocated to IT001 to handle physical hardware failure of RAM. SLA risk is MEDIUM as the deadline is stable, leaving 15 hours on the operational timeline.',
        'Verify warranty status, issue a replacement RAM from local stock, and recycle the defective unit.',
        0.96
    ),
    (
        'IT001',
        'Temporary loaner laptop needed for Da Nang office travel',
        'To whom it may concern, I am travelling to Da Nang office for a business trip next week. I prefer not to take my bulky engineering workstation. This is severely impacting my daily work. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Allocated to IT001 to handle temporary equipment loan for travel to Da Nang office. SLA risk is LOW as the deadline is stable, leaving 47 hours on the operational timeline.',
        'Provision a lightweight 13-inch loaner laptop, configure basic VPN access, and schedule pickup.',
        0.95
    ),
    (
        'IT001',
        'Ergonomic workspace request: Footrest',
        'Urgent request: I have been experiencing some physical discomfort at my desk. My manager approved the request for a Footrest. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Allocated to IT001 to handle medical or ergonomic peripheral request (Footrest). SLA risk is LOW as the deadline is stable, leaving 40 hours on the operational timeline.',
        'Check inventory for Footrest. If out of stock, initiate a purchase order through the IT procurement portal.',
        0.93
    ),
    (
        'IT001',
        'End-of-life hardware refresh for 2019 Macbook Pro',
        'Hello, My current device is over 4 years old and out of warranty. The 2019 Macbook Pro is severely impacting my productivity due to lag. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires lifecycle hardware replacement for 2019 Macbook Pro. SLA Breach risk is LOW; this standard request has a resolution window with 31 hours remaining on the clock.',
        'Verify the asset tag against the lifecycle database. If eligible, schedule a data migration and hardware swap.',
        0.95
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming HR Specialist',
        'To whom it may concern, We have a new HR Specialist joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. They cannot start working without the equipment. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires onboarding hardware allocation. SLA Breach risk is LOW; this standard request has a resolution window with 63 hours remaining on the clock.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.94
    ),
    (
        'IT001',
        'Defective or broken corporate Trackpad',
        'Urgent request: I am working on an important project right now. My issued Trackpad has stopped working entirely. It started glitching yesterday. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'IT',
        'medium',
        'low',
        'Assigned to IT001 since the user requires physical hardware failure of Trackpad. SLA Breach risk is MEDIUM; this standard request has a resolution window with 38 hours remaining on the clock.',
        'Verify warranty status, issue a replacement Trackpad from local stock, and recycle the defective unit.',
        0.95
    ),
    (
        'IT001',
        'Temporary loaner laptop needed for Hanoi branch travel',
        'Urgent request: I am travelling to Hanoi branch for a business trip next week. I prefer not to take my bulky engineering workstation. This is a major blocker for my current sprint. Can I get a lightweight loaner laptop?',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires temporary equipment loan for travel to Hanoi branch. SLA Breach risk is LOW; this standard request has a resolution window with 40 hours remaining on the clock.',
        'Provision a lightweight 13-inch loaner laptop, configure basic VPN access, and schedule pickup.',
        0.97
    ),
    (
        'IT001',
        'Ergonomic workspace request: Monitor arm',
        'Hi Helpdesk, I have been experiencing some physical discomfort at my desk. My manager approved the request for a Monitor arm. This is severely impacting my daily work. Please let me know the process to order this.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT001 for medical or ergonomic peripheral request (Monitor arm). SLA risk is LOW because we currently have 20 hours remaining before the standard SLA breach.',
        'Check inventory for Monitor arm. If out of stock, initiate a purchase order through the IT procurement portal.',
        0.94
    ),
    (
        'IT001',
        'End-of-life hardware refresh for aging Dell monitors',
        'To whom it may concern, My current device is over 4 years old and out of warranty. The aging Dell monitors is severely impacting my productivity due to lag. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Determined to be a lifecycle hardware replacement for aging Dell monitors case suitable for IT001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 64 hours remaining.',
        'Verify the asset tag against the lifecycle database. If eligible, schedule a data migration and hardware swap.',
        0.98
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming HR Specialist',
        'Urgent request: We have a new HR Specialist joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT001 for onboarding hardware allocation. SLA risk is LOW because we currently have 67 hours remaining before the standard SLA breach.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.97
    ),
    (
        'IT001',
        'Defective or broken corporate Headset',
        'To whom it may concern, I am working on an important project right now. My issued Headset has stopped working entirely. It started glitching yesterday. This is a major blocker for my current sprint. Please arrange a replacement today.',
        'IT',
        'medium',
        'low',
        'Allocated to IT001 to handle physical hardware failure of Headset. SLA risk is MEDIUM as the deadline is stable, leaving 42 hours on the operational timeline.',
        'Verify warranty status, issue a replacement Headset from local stock, and recycle the defective unit.',
        0.96
    ),
    (
        'IT001',
        'Temporary loaner laptop needed for Remote WFH travel',
        'Dear Support Team, I am travelling to Remote WFH for a business trip next week. I prefer not to take my bulky engineering workstation. I need access to emails and VPN while travelling. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT001 for temporary equipment loan for travel to Remote WFH. SLA risk is LOW because we currently have 66 hours remaining before the standard SLA breach.',
        'Provision a lightweight 13-inch loaner laptop, configure basic VPN access, and schedule pickup.',
        0.98
    ),
    (
        'IT001',
        'Ergonomic workspace request: Footrest',
        'Urgent request: I have been experiencing some physical discomfort at my desk. My manager approved the request for a Footrest. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Determined to be a medical or ergonomic peripheral request (Footrest) case suitable for IT001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 34 hours remaining.',
        'Check inventory for Footrest. If out of stock, initiate a purchase order through the IT procurement portal.',
        0.95
    ),
    (
        'IT001',
        'End-of-life hardware refresh for outdated iPad',
        'Dear Support Team, My current device is over 4 years old and out of warranty. The outdated iPad is severely impacting my productivity due to lag. I cannot complete my pending tasks without this. Can I qualify for the lifecycle hardware refresh?',
        'IT',
        'low',
        'low',
        'Assigned to IT001 since the user requires lifecycle hardware replacement for outdated iPad. SLA Breach risk is LOW; this standard request has a resolution window with 68 hours remaining on the clock.',
        'Verify the asset tag against the lifecycle database. If eligible, schedule a data migration and hardware swap.',
        0.94
    ),
    (
        'IT001',
        'New hire hardware provisioning for incoming QA',
        'Hello, We have a new QA joining next Monday. Please prepare a standard corporate laptop, dock, and dual monitors. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Allocated to IT001 to handle onboarding hardware allocation. SLA risk is LOW as the deadline is stable, leaving 46 hours on the operational timeline.',
        'Image a new laptop from inventory and deploy the standard hardware bundle to the requested desk.',
        0.96
    ),
    (
        'IT002',
        'Software installation request: IntelliJ Ultimate',
        'Hi Helpdesk, I transferred to a new team recently. I need IntelliJ Ultimate installed on my machine for an upcoming project. I believe the company has volume licenses. I cannot open the required project files. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle software installation and license allocation for IntelliJ Ultimate. SLA risk is LOW as the deadline is stable, leaving 64 hours on the operational timeline.',
        'Deploy the IntelliJ Ultimate package to the user''s workstation via endpoint management and consume one license seat.',
        0.93
    ),
    (
        'IT002',
        'Wi-Fi dead zone or poor connectivity in Floor 18 East',
        'Dear Support Team, We are having network issues on our floor. The wireless signal in Floor 18 East is extremely weak today. Multiple team members are experiencing dropouts. We cannot maintain video calls with clients. Can we get this resolved by today?',
        'IT',
        'medium',
        'low',
        'Allocated to IT002 to handle local network degradation in Floor 18 East. SLA risk is MEDIUM as the deadline is stable, leaving 67 hours on the operational timeline.',
        'Inspect the WAP (Wireless Access Point) serving Floor 18 East, check for channel interference, and reboot the AP if necessary.',
        0.94
    ),
    (
        'IT002',
        'VPN connection dropping frequently while offshore team',
        'To whom it may concern, I am offshore team today. The corporate GlobalProtect VPN disconnects every 15 minutes. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT002 since the user requires client-side VPN instability (offshore team). SLA Breach risk is LOW; this standard request has a resolution window with 23 hours remaining on the clock.',
        'Review the user''s VPN client logs, update the client version, and test connecting through a different regional gateway.',
        0.94
    ),
    (
        'IT002',
        'Application crashing: Figma client keeps freezing',
        'To whom it may concern, I updated my OS yesterday. Since then, Figma client freezes entirely after about 5 minutes of use and I have to Force Quit it. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT002 for OS or software instability regarding Figma client. SLA risk is LOW because we currently have 27 hours remaining before the standard SLA breach.',
        'Clear the application cache for Figma client, repair the installation, and check system event logs for conflict errors.',
        0.96
    ),
    (
        'IT002',
        'DNS resolution failure for local development server',
        'To whom it may concern, I am trying to run end-to-end tests. I cannot access the local development server via its hostname, getting a ''NXDOMAIN'' error. Connecting directly via IP address works fine. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Determined to be a internal routing and DNS configuration for local development server case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 41 hours remaining.',
        'Flush the DNS cache on the user''s machine and verify the A-records on the primary domain controller for local development server.',
        0.95
    ),
    (
        'IT002',
        'Software installation request: Visual Studio',
        'Dear Support Team, I transferred to a new team recently. I need Visual Studio installed on my machine for an upcoming project. I believe the company has volume licenses. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle software installation and license allocation for Visual Studio. SLA risk is LOW as the deadline is stable, leaving 27 hours on the operational timeline.',
        'Deploy the Visual Studio package to the user''s workstation via endpoint management and consume one license seat.',
        0.96
    ),
    (
        'IT002',
        'Wi-Fi dead zone or poor connectivity in Floor 18 East',
        'Hi Helpdesk, We are having network issues on our floor. The wireless signal in Floor 18 East is extremely weak today. Multiple team members are experiencing dropouts. We cannot maintain video calls with clients. I would appreciate a prompt resolution.',
        'IT',
        'medium',
        'low',
        'Allocated to IT002 to handle local network degradation in Floor 18 East. SLA risk is MEDIUM as the deadline is stable, leaving 33 hours on the operational timeline.',
        'Inspect the WAP (Wireless Access Point) serving Floor 18 East, check for channel interference, and reboot the AP if necessary.',
        0.94
    ),
    (
        'IT002',
        'VPN connection dropping frequently while using mobile hotspot',
        'To whom it may concern, I am using mobile hotspot today. The corporate GlobalProtect VPN disconnects every 15 minutes. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT002 since the user requires client-side VPN instability (using mobile hotspot). SLA Breach risk is LOW; this standard request has a resolution window with 26 hours remaining on the clock.',
        'Review the user''s VPN client logs, update the client version, and test connecting through a different regional gateway.',
        0.95
    ),
    (
        'IT002',
        'Application crashing: Docker Desktop keeps freezing',
        'To whom it may concern, I updated my OS yesterday. Since then, Docker Desktop freezes entirely after about 5 minutes of use and I have to Force Quit it. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Assigned to IT002 since the user requires OS or software instability regarding Docker Desktop. SLA Breach risk is LOW; this standard request has a resolution window with 49 hours remaining on the clock.',
        'Clear the application cache for Docker Desktop, repair the installation, and check system event logs for conflict errors.',
        0.96
    ),
    (
        'IT002',
        'DNS resolution failure for local development server',
        'Dear Support Team, I am trying to run end-to-end tests. I cannot access the local development server via its hostname, getting a ''NXDOMAIN'' error. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Determined to be a internal routing and DNS configuration for local development server case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 39 hours remaining.',
        'Flush the DNS cache on the user''s machine and verify the A-records on the primary domain controller for local development server.',
        0.97
    ),
    (
        'IT002',
        'Software installation request: IntelliJ Ultimate',
        'Urgent request: I transferred to a new team recently. I need IntelliJ Ultimate installed on my machine for an upcoming project. I believe the company has volume licenses. I cannot open the required project files. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Determined to be a software installation and license allocation for IntelliJ Ultimate case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 31 hours remaining.',
        'Deploy the IntelliJ Ultimate package to the user''s workstation via endpoint management and consume one license seat.',
        0.95
    ),
    (
        'IT002',
        'Wi-Fi dead zone or poor connectivity in Floor 19 West',
        'Hello, We are having network issues on our floor. The wireless signal in Floor 19 West is extremely weak today. Multiple team members are experiencing dropouts. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Assigned to IT002 since the user requires local network degradation in Floor 19 West. SLA Breach risk is MEDIUM; this standard request has a resolution window with 40 hours remaining on the clock.',
        'Inspect the WAP (Wireless Access Point) serving Floor 19 West, check for channel interference, and reboot the AP if necessary.',
        0.96
    ),
    (
        'IT002',
        'VPN connection dropping frequently while offshore team',
        'Hello, I am offshore team today. The corporate GlobalProtect VPN disconnects every 15 minutes. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle client-side VPN instability (offshore team). SLA risk is LOW as the deadline is stable, leaving 22 hours on the operational timeline.',
        'Review the user''s VPN client logs, update the client version, and test connecting through a different regional gateway.',
        0.98
    ),
    (
        'IT002',
        'Application crashing: Zoom keeps freezing',
        'To whom it may concern, I updated my OS yesterday. Since then, Zoom freezes entirely after about 5 minutes of use and I have to Force Quit it. Rebooting my computer did not resolve the issue. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT002 for OS or software instability regarding Zoom. SLA risk is LOW because we currently have 27 hours remaining before the standard SLA breach.',
        'Clear the application cache for Zoom, repair the installation, and check system event logs for conflict errors.',
        0.97
    ),
    (
        'IT002',
        'DNS resolution failure for Staging environment',
        'Hello, I am trying to run end-to-end tests. I cannot access the Staging environment via its hostname, getting a ''NXDOMAIN'' error. Connecting directly via IP address works fine. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle internal routing and DNS configuration for Staging environment. SLA risk is LOW as the deadline is stable, leaving 49 hours on the operational timeline.',
        'Flush the DNS cache on the user''s machine and verify the A-records on the primary domain controller for Staging environment.',
        0.93
    ),
    (
        'IT002',
        'Software installation request: IntelliJ Ultimate',
        'Urgent request: I transferred to a new team recently. I need IntelliJ Ultimate installed on my machine for an upcoming project. I believe the company has volume licenses. I cannot open the required project files. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Determined to be a software installation and license allocation for IntelliJ Ultimate case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 61 hours remaining.',
        'Deploy the IntelliJ Ultimate package to the user''s workstation via endpoint management and consume one license seat.',
        0.97
    ),
    (
        'IT002',
        'Wi-Fi dead zone or poor connectivity in Floor 18 East',
        'Hi Helpdesk, We are having network issues on our floor. The wireless signal in Floor 18 East is extremely weak today. Multiple team members are experiencing dropouts. We cannot maintain video calls with clients. Please investigate the local access point.',
        'IT',
        'medium',
        'low',
        'Classification: Categorized under IT002 for local network degradation in Floor 18 East. SLA risk is MEDIUM because we currently have 48 hours remaining before the standard SLA breach.',
        'Inspect the WAP (Wireless Access Point) serving Floor 18 East, check for channel interference, and reboot the AP if necessary.',
        0.96
    ),
    (
        'IT002',
        'VPN connection dropping frequently while connecting from coffee shop',
        'Hi Helpdesk, I am connecting from coffee shop today. The corporate GlobalProtect VPN disconnects every 15 minutes. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle client-side VPN instability (connecting from coffee shop). SLA risk is LOW as the deadline is stable, leaving 32 hours on the operational timeline.',
        'Review the user''s VPN client logs, update the client version, and test connecting through a different regional gateway.',
        0.97
    ),
    (
        'IT002',
        'Application crashing: Outlook keeps freezing',
        'To whom it may concern, I updated my OS yesterday. Since then, Outlook freezes entirely after about 5 minutes of use and I have to Force Quit it. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Determined to be a OS or software instability regarding Outlook case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 34 hours remaining.',
        'Clear the application cache for Outlook, repair the installation, and check system event logs for conflict errors.',
        0.94
    ),
    (
        'IT002',
        'DNS resolution failure for Staging environment',
        'Dear Support Team, I am trying to run end-to-end tests. I cannot access the Staging environment via its hostname, getting a ''NXDOMAIN'' error. Connecting directly via IP address works fine. Please update the internal DNS records.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT002 for internal routing and DNS configuration for Staging environment. SLA risk is LOW because we currently have 46 hours remaining before the standard SLA breach.',
        'Flush the DNS cache on the user''s machine and verify the A-records on the primary domain controller for Staging environment.',
        0.94
    ),
    (
        'IT002',
        'Software installation request: Final Cut Pro',
        'Hi Helpdesk, I transferred to a new team recently. I need Final Cut Pro installed on my machine for an upcoming project. I believe the company has volume licenses. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle software installation and license allocation for Final Cut Pro. SLA risk is LOW as the deadline is stable, leaving 57 hours on the operational timeline.',
        'Deploy the Final Cut Pro package to the user''s workstation via endpoint management and consume one license seat.',
        0.93
    ),
    (
        'IT002',
        'Wi-Fi dead zone or poor connectivity in Meeting Room 4A',
        'Dear Support Team, We are having network issues on our floor. The wireless signal in Meeting Room 4A is extremely weak today. Multiple team members are experiencing dropouts. This is severely impacting my daily work. Can we get this resolved by today?',
        'IT',
        'medium',
        'low',
        'Determined to be a local network degradation in Meeting Room 4A case suitable for IT002. SLA risk is MEDIUM: the applicable policy allows a standard turnaround time, leaving 59 hours remaining.',
        'Inspect the WAP (Wireless Access Point) serving Meeting Room 4A, check for channel interference, and reboot the AP if necessary.',
        0.98
    ),
    (
        'IT002',
        'VPN connection dropping frequently while offshore team',
        'Hello, I am offshore team today. The corporate GlobalProtect VPN disconnects every 15 minutes. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT002 since the user requires client-side VPN instability (offshore team). SLA Breach risk is LOW; this standard request has a resolution window with 30 hours remaining on the clock.',
        'Review the user''s VPN client logs, update the client version, and test connecting through a different regional gateway.',
        0.96
    ),
    (
        'IT002',
        'Application crashing: Docker Desktop keeps freezing',
        'Dear Support Team, I updated my OS yesterday. Since then, Docker Desktop freezes entirely after about 5 minutes of use and I have to Force Quit it. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT002 for OS or software instability regarding Docker Desktop. SLA risk is LOW because we currently have 64 hours remaining before the standard SLA breach.',
        'Clear the application cache for Docker Desktop, repair the installation, and check system event logs for conflict errors.',
        0.95
    ),
    (
        'IT002',
        'DNS resolution failure for external API gateway',
        'Dear Support Team, I am trying to run end-to-end tests. I cannot access the external API gateway via its hostname, getting a ''NXDOMAIN'' error. I cannot complete my pending tasks without this. Please update the internal DNS records.',
        'IT',
        'low',
        'low',
        'Determined to be a internal routing and DNS configuration for external API gateway case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 50 hours remaining.',
        'Flush the DNS cache on the user''s machine and verify the A-records on the primary domain controller for external API gateway.',
        0.97
    ),
    (
        'IT002',
        'Software installation request: Final Cut Pro',
        'To whom it may concern, I transferred to a new team recently. I need Final Cut Pro installed on my machine for an upcoming project. I believe the company has volume licenses. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT002 for software installation and license allocation for Final Cut Pro. SLA risk is LOW because we currently have 39 hours remaining before the standard SLA breach.',
        'Deploy the Final Cut Pro package to the user''s workstation via endpoint management and consume one license seat.',
        0.92
    ),
    (
        'IT002',
        'Wi-Fi dead zone or poor connectivity in Meeting Room 4A',
        'Hello, We are having network issues on our floor. The wireless signal in Meeting Room 4A is extremely weak today. Multiple team members are experiencing dropouts. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Classification: Categorized under IT002 for local network degradation in Meeting Room 4A. SLA risk is MEDIUM because we currently have 64 hours remaining before the standard SLA breach.',
        'Inspect the WAP (Wireless Access Point) serving Meeting Room 4A, check for channel interference, and reboot the AP if necessary.',
        0.98
    ),
    (
        'IT002',
        'VPN connection dropping frequently while connecting from coffee shop',
        'Dear Support Team, I am connecting from coffee shop today. The corporate GlobalProtect VPN disconnects every 15 minutes. It''s disrupting my SSH sessions to the production servers. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Determined to be a client-side VPN instability (connecting from coffee shop) case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 12 hours remaining.',
        'Review the user''s VPN client logs, update the client version, and test connecting through a different regional gateway.',
        0.93
    ),
    (
        'IT002',
        'Application crashing: Slack keeps freezing',
        'Hello, I updated my OS yesterday. Since then, Slack freezes entirely after about 5 minutes of use and I have to Force Quit it. Rebooting my computer did not resolve the issue. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT002 for OS or software instability regarding Slack. SLA risk is LOW because we currently have 58 hours remaining before the standard SLA breach.',
        'Clear the application cache for Slack, repair the installation, and check system event logs for conflict errors.',
        0.96
    ),
    (
        'IT002',
        'DNS resolution failure for legacy intranet',
        'Dear Support Team, I am trying to run end-to-end tests. I cannot access the legacy intranet via its hostname, getting a ''NXDOMAIN'' error. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'IT',
        'low',
        'low',
        'Determined to be a internal routing and DNS configuration for legacy intranet case suitable for IT002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 18 hours remaining.',
        'Flush the DNS cache on the user''s machine and verify the A-records on the primary domain controller for legacy intranet.',
        0.92
    ),
    (
        'IT002',
        'Software installation request: Visio',
        'Urgent request: I transferred to a new team recently. I need Visio installed on my machine for an upcoming project. I believe the company has volume licenses. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle software installation and license allocation for Visio. SLA risk is LOW as the deadline is stable, leaving 32 hours on the operational timeline.',
        'Deploy the Visio package to the user''s workstation via endpoint management and consume one license seat.',
        0.95
    ),
    (
        'IT002',
        'Wi-Fi dead zone or poor connectivity in Reception Area',
        'To whom it may concern, We are having network issues on our floor. The wireless signal in Reception Area is extremely weak today. Multiple team members are experiencing dropouts. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Assigned to IT002 since the user requires local network degradation in Reception Area. SLA Breach risk is MEDIUM; this standard request has a resolution window with 52 hours remaining on the clock.',
        'Inspect the WAP (Wireless Access Point) serving Reception Area, check for channel interference, and reboot the AP if necessary.',
        0.92
    ),
    (
        'IT002',
        'VPN connection dropping frequently while offshore team',
        'Hello, I am offshore team today. The corporate GlobalProtect VPN disconnects every 15 minutes. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT002 since the user requires client-side VPN instability (offshore team). SLA Breach risk is LOW; this standard request has a resolution window with 37 hours remaining on the clock.',
        'Review the user''s VPN client logs, update the client version, and test connecting through a different regional gateway.',
        0.96
    ),
    (
        'IT002',
        'Application crashing: Figma client keeps freezing',
        'Hi Helpdesk, I updated my OS yesterday. Since then, Figma client freezes entirely after about 5 minutes of use and I have to Force Quit it. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'low',
        'low',
        'Assigned to IT002 since the user requires OS or software instability regarding Figma client. SLA Breach risk is LOW; this standard request has a resolution window with 39 hours remaining on the clock.',
        'Clear the application cache for Figma client, repair the installation, and check system event logs for conflict errors.',
        0.94
    ),
    (
        'IT002',
        'DNS resolution failure for external API gateway',
        'Urgent request: I am trying to run end-to-end tests. I cannot access the external API gateway via its hostname, getting a ''NXDOMAIN'' error. This is severely impacting my daily work. Please advise on the next steps.',
        'IT',
        'low',
        'low',
        'Allocated to IT002 to handle internal routing and DNS configuration for external API gateway. SLA risk is LOW as the deadline is stable, leaving 36 hours on the operational timeline.',
        'Flush the DNS cache on the user''s machine and verify the A-records on the primary domain controller for external API gateway.',
        0.98
    ),
    (
        'IT002',
        'Software installation request: Tableau',
        'Hello, I transferred to a new team recently. I need Tableau installed on my machine for an upcoming project. I believe the company has volume licenses. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'IT',
        'low',
        'low',
        'Classification: Categorized under IT002 for software installation and license allocation for Tableau. SLA risk is LOW because we currently have 53 hours remaining before the standard SLA breach.',
        'Deploy the Tableau package to the user''s workstation via endpoint management and consume one license seat.',
        0.95
    ),
    (
        'IT003',
        'Suspicious email reported: Email from CFO',
        'Dear Support Team, I just received a highly suspicious email. It looks like a Email from CFO. I did not click any links. Others in my department might have received it too and it poses a security risk. I would appreciate a prompt resolution.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate phishing incident (Email from CFO). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 34 minutes remaining on the clock.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.96
    ),
    (
        'IT003',
        'Access revocation for departing Intern',
        'Hello, HR just notified me of an offboarding. The Intern contract has ended effectively today. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for offboarding access termination for Intern. SLA risk is HIGH because we currently have only 120 minutes remaining before the critical SLA breach.',
        'Disable the Intern''s AD account, terminate any active sessions, and remove them from all security groups.',
        0.97
    ),
    (
        'IT003',
        'Requesting elevated permissions for Jira Project Admin',
        'Hi Helpdesk, I am taking on new project responsibilities. My role requires elevated access to Jira Project Admin. My department head has approved this request in the attached email. I cannot deploy the required updates without this. Can we get this resolved by today?',
        'IT',
        'medium',
        'low',
        'Allocated to IT003 to handle privileged access request to Jira Project Admin. SLA risk is LOW as the deadline is stable, leaving 36 hours on the operational timeline.',
        'Verify approval chain, assign the appropriate RBAC role for Jira Project Admin, and enforce MFA on the elevated account.',
        0.97
    ),
    (
        'IT003',
        'MFA token reset required: authenticator app corrupted',
        'Dear Support Team, I am trying to log in but facing an authentication block. I am unable to pass the two-factor authentication prompt due to: authenticator app corrupted. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate MFA lockout (authenticator app corrupted). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 104 minutes remaining on the clock.',
        'Verify user identity via manager, reset the MFA token seed in the identity provider, and guide the user through re-registration.',
        0.92
    ),
    (
        'IT003',
        'Security vulnerability alert: Nessus vulnerability scan',
        'Hello, I am reviewing the morning security dashboard. Our automated monitoring generated a Nessus vulnerability scan on one of the backend nodes. This is a compliance violation for SOC2. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Allocated to IT003 to handle automated security alert (Nessus vulnerability scan). SLA risk is MEDIUM as the deadline is stable, leaving 53 hours on the operational timeline.',
        'Analyze the vulnerability report, isolate the affected node if necessary, and apply the required security patches.',
        0.95
    ),
    (
        'IT003',
        'Suspicious email reported: weird SharePoint link',
        'Urgent request: I just received a highly suspicious email. It looks like a weird SharePoint link. I did not click any links. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for phishing incident (weird SharePoint link). SLA risk is HIGH because we currently have only 98 minutes remaining before the critical SLA breach.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.93
    ),
    (
        'IT003',
        'Access revocation for departing Intern',
        'Hi Helpdesk, HR just notified me of an offboarding. The Intern contract has ended effectively today. We need to prevent any unauthorized access to our internal systems. Can we get this resolved by today?',
        'IT',
        'high',
        'high',
        'Forwarded to the IT003 queue because it involves offboarding access termination for Intern. SLA BREACH WARNING: Urgency is HIGH with only 63 minutes of buffer time left under the emergency policy.',
        'Disable the Intern''s AD account, terminate any active sessions, and remove them from all security groups.',
        0.92
    ),
    (
        'IT003',
        'Requesting elevated permissions for Finance DB',
        'Dear Support Team, I am taking on new project responsibilities. My role requires elevated access to Finance DB. My department head has approved this request in the attached email. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'IT',
        'medium',
        'low',
        'Allocated to IT003 to handle privileged access request to Finance DB. SLA risk is LOW as the deadline is stable, leaving 42 hours on the operational timeline.',
        'Verify approval chain, assign the appropriate RBAC role for Finance DB, and enforce MFA on the elevated account.',
        0.95
    ),
    (
        'IT003',
        'MFA token reset required: authenticator app corrupted',
        'To whom it may concern, I am trying to log in but facing an authentication block. I am unable to pass the two-factor authentication prompt due to: authenticator app corrupted. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'IT',
        'high',
        'high',
        'Forwarded to the IT003 queue because it involves MFA lockout (authenticator app corrupted). SLA BREACH WARNING: Urgency is HIGH with only 30 minutes of buffer time left under the emergency policy.',
        'Verify user identity via manager, reset the MFA token seed in the identity provider, and guide the user through re-registration.',
        0.94
    ),
    (
        'IT003',
        'Security vulnerability alert: Nessus vulnerability scan',
        'Dear Support Team, I am reviewing the morning security dashboard. Our automated monitoring generated a Nessus vulnerability scan on one of the backend nodes. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'IT',
        'medium',
        'low',
        'Assigned to IT003 since the user requires automated security alert (Nessus vulnerability scan). SLA Breach risk is MEDIUM; this standard request has a resolution window with 60 hours remaining on the clock.',
        'Analyze the vulnerability report, isolate the affected node if necessary, and apply the required security patches.',
        0.95
    ),
    (
        'IT003',
        'Suspicious email reported: weird SharePoint link',
        'Hello, I just received a highly suspicious email. It looks like a weird SharePoint link. I did not click any links. This is a major blocker for my current sprint. Please analyze it and block the sender.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate phishing incident (weird SharePoint link). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 129 minutes remaining on the clock.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.95
    ),
    (
        'IT003',
        'Access revocation for departing Consultant',
        'Urgent request: HR just notified me of an offboarding. The Consultant contract has ended effectively today. This is severely impacting my daily work. Please advise on the next steps.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for offboarding access termination for Consultant. SLA risk is HIGH because we currently have only 43 minutes remaining before the critical SLA breach.',
        'Disable the Consultant''s AD account, terminate any active sessions, and remove them from all security groups.',
        0.97
    ),
    (
        'IT003',
        'Requesting elevated permissions for Salesforce',
        'To whom it may concern, I am taking on new project responsibilities. My role requires elevated access to Salesforce. My department head has approved this request in the attached email. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'IT',
        'medium',
        'low',
        'Determined to be a privileged access request to Salesforce case suitable for IT003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 18 hours remaining.',
        'Verify approval chain, assign the appropriate RBAC role for Salesforce, and enforce MFA on the elevated account.',
        0.97
    ),
    (
        'IT003',
        'MFA token reset required: authenticator app corrupted',
        'Urgent request: I am trying to log in but facing an authentication block. I am unable to pass the two-factor authentication prompt due to: authenticator app corrupted. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate MFA lockout (authenticator app corrupted). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 33 minutes remaining on the clock.',
        'Verify user identity via manager, reset the MFA token seed in the identity provider, and guide the user through re-registration.',
        0.98
    ),
    (
        'IT003',
        'Security vulnerability alert: Nessus vulnerability scan',
        'To whom it may concern, I am reviewing the morning security dashboard. Our automated monitoring generated a Nessus vulnerability scan on one of the backend nodes. This is severely impacting my daily work. Can we get this resolved by today?',
        'IT',
        'medium',
        'low',
        'Determined to be a automated security alert (Nessus vulnerability scan) case suitable for IT003. SLA risk is MEDIUM: the applicable policy allows a standard turnaround time, leaving 28 hours remaining.',
        'Analyze the vulnerability report, isolate the affected node if necessary, and apply the required security patches.',
        0.94
    ),
    (
        'IT003',
        'Suspicious email reported: weird SharePoint link',
        'Hi Helpdesk, I just received a highly suspicious email. It looks like a weird SharePoint link. I did not click any links. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for phishing incident (weird SharePoint link). SLA risk is HIGH because we currently have only 65 minutes remaining before the critical SLA breach.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.97
    ),
    (
        'IT003',
        'Access revocation for departing Contractor',
        'Urgent request: HR just notified me of an offboarding. The Contractor contract has ended effectively today. We need to prevent any unauthorized access to our internal systems. Please advise on the next steps.',
        'IT',
        'high',
        'high',
        'Forwarded to the IT003 queue because it involves offboarding access termination for Contractor. SLA BREACH WARNING: Urgency is HIGH with only 75 minutes of buffer time left under the emergency policy.',
        'Disable the Contractor''s AD account, terminate any active sessions, and remove them from all security groups.',
        0.97
    ),
    (
        'IT003',
        'Requesting elevated permissions for Salesforce',
        'Urgent request: I am taking on new project responsibilities. My role requires elevated access to Salesforce. My department head has approved this request in the attached email. I cannot deploy the required updates without this. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Determined to be a privileged access request to Salesforce case suitable for IT003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 43 hours remaining.',
        'Verify approval chain, assign the appropriate RBAC role for Salesforce, and enforce MFA on the elevated account.',
        0.99
    ),
    (
        'IT003',
        'MFA token reset required: authenticator app corrupted',
        'To whom it may concern, I am trying to log in but facing an authentication block. I am unable to pass the two-factor authentication prompt due to: authenticator app corrupted. I am completely locked out of Okta and cannot work. Please reset my MFA token so I can re-register.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate MFA lockout (authenticator app corrupted). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 28 minutes remaining on the clock.',
        'Verify user identity via manager, reset the MFA token seed in the identity provider, and guide the user through re-registration.',
        0.97
    ),
    (
        'IT003',
        'Security vulnerability alert: Nessus vulnerability scan',
        'Hi Helpdesk, I am reviewing the morning security dashboard. Our automated monitoring generated a Nessus vulnerability scan on one of the backend nodes. This is a major blocker for my current sprint. Needs review and remediation immediately.',
        'IT',
        'medium',
        'low',
        'Allocated to IT003 to handle automated security alert (Nessus vulnerability scan). SLA risk is MEDIUM as the deadline is stable, leaving 41 hours on the operational timeline.',
        'Analyze the vulnerability report, isolate the affected node if necessary, and apply the required security patches.',
        0.96
    ),
    (
        'IT003',
        'Suspicious email reported: Email from CFO',
        'Urgent request: I just received a highly suspicious email. It looks like a Email from CFO. I did not click any links. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate phishing incident (Email from CFO). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 87 minutes remaining on the clock.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.96
    ),
    (
        'IT003',
        'Access revocation for departing Vendor',
        'Dear Support Team, HR just notified me of an offboarding. The Vendor contract has ended effectively today. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for offboarding access termination for Vendor. SLA risk is HIGH because we currently have only 90 minutes remaining before the critical SLA breach.',
        'Disable the Vendor''s AD account, terminate any active sessions, and remove them from all security groups.',
        0.95
    ),
    (
        'IT003',
        'Requesting elevated permissions for Salesforce',
        'Urgent request: I am taking on new project responsibilities. My role requires elevated access to Salesforce. My department head has approved this request in the attached email. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'IT',
        'medium',
        'low',
        'Determined to be a privileged access request to Salesforce case suitable for IT003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 67 hours remaining.',
        'Verify approval chain, assign the appropriate RBAC role for Salesforce, and enforce MFA on the elevated account.',
        0.94
    ),
    (
        'IT003',
        'MFA token reset required: changed phone',
        'Hello, I am trying to log in but facing an authentication block. I am unable to pass the two-factor authentication prompt due to: changed phone. This is severely impacting my daily work. Please reset my MFA token so I can re-register.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for MFA lockout (changed phone). SLA risk is HIGH because we currently have only 92 minutes remaining before the critical SLA breach.',
        'Verify user identity via manager, reset the MFA token seed in the identity provider, and guide the user through re-registration.',
        0.95
    ),
    (
        'IT003',
        'Security vulnerability alert: malware blocked',
        'Hello, I am reviewing the morning security dashboard. Our automated monitoring generated a malware blocked on one of the backend nodes. This is a compliance violation for SOC2. Please advise on the next steps.',
        'IT',
        'medium',
        'low',
        'Assigned to IT003 since the user requires automated security alert (malware blocked). SLA Breach risk is MEDIUM; this standard request has a resolution window with 19 hours remaining on the clock.',
        'Analyze the vulnerability report, isolate the affected node if necessary, and apply the required security patches.',
        0.94
    ),
    (
        'IT003',
        'Suspicious email reported: weird SharePoint link',
        'To whom it may concern, I just received a highly suspicious email. It looks like a weird SharePoint link. I did not click any links. Others in my department might have received it too and it poses a security risk. Can we get this resolved by today?',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate phishing incident (weird SharePoint link). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 15 minutes remaining on the clock.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.92
    ),
    (
        'IT003',
        'Access revocation for departing Vendor',
        'Dear Support Team, HR just notified me of an offboarding. The Vendor contract has ended effectively today. This is a major blocker for my current sprint. Please advise on the next steps.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate offboarding access termination for Vendor. SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 115 minutes remaining on the clock.',
        'Disable the Vendor''s AD account, terminate any active sessions, and remove them from all security groups.',
        0.94
    ),
    (
        'IT003',
        'Requesting elevated permissions for Salesforce',
        'To whom it may concern, I am taking on new project responsibilities. My role requires elevated access to Salesforce. My department head has approved this request in the attached email. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Assigned to IT003 since the user requires privileged access request to Salesforce. SLA Breach risk is LOW; this standard request has a resolution window with 39 hours remaining on the clock.',
        'Verify approval chain, assign the appropriate RBAC role for Salesforce, and enforce MFA on the elevated account.',
        0.95
    ),
    (
        'IT003',
        'MFA token reset required: changed phone',
        'Urgent request: I am trying to log in but facing an authentication block. I am unable to pass the two-factor authentication prompt due to: changed phone. I am completely locked out of Okta and cannot work. Please let me know when someone can look into this.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for MFA lockout (changed phone). SLA risk is HIGH because we currently have only 85 minutes remaining before the critical SLA breach.',
        'Verify user identity via manager, reset the MFA token seed in the identity provider, and guide the user through re-registration.',
        0.98
    ),
    (
        'IT003',
        'Security vulnerability alert: malware blocked',
        'Hi Helpdesk, I am reviewing the morning security dashboard. Our automated monitoring generated a malware blocked on one of the backend nodes. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'IT',
        'medium',
        'low',
        'Allocated to IT003 to handle automated security alert (malware blocked). SLA risk is MEDIUM as the deadline is stable, leaving 36 hours on the operational timeline.',
        'Analyze the vulnerability report, isolate the affected node if necessary, and apply the required security patches.',
        0.97
    ),
    (
        'IT003',
        'Suspicious email reported: urgent wire transfer request',
        'Dear Support Team, I just received a highly suspicious email. It looks like a urgent wire transfer request. I did not click any links. Others in my department might have received it too and it poses a security risk. Please let me know when someone can look into this.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate phishing incident (urgent wire transfer request). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 30 minutes remaining on the clock.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.94
    ),
    (
        'IT003',
        'Access revocation for departing Vendor',
        'Hello, HR just notified me of an offboarding. The Vendor contract has ended effectively today. I cannot complete my pending tasks without this. Please immediately revoke their Active Directory, VPN, and email access.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for offboarding access termination for Vendor. SLA risk is HIGH because we currently have only 81 minutes remaining before the critical SLA breach.',
        'Disable the Vendor''s AD account, terminate any active sessions, and remove them from all security groups.',
        0.92
    ),
    (
        'IT003',
        'Requesting elevated permissions for AWS Production',
        'Dear Support Team, I am taking on new project responsibilities. My role requires elevated access to AWS Production. My department head has approved this request in the attached email. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'IT',
        'medium',
        'low',
        'Classification: Categorized under IT003 for privileged access request to AWS Production. SLA risk is LOW because we currently have 61 hours remaining before the standard SLA breach.',
        'Verify approval chain, assign the appropriate RBAC role for AWS Production, and enforce MFA on the elevated account.',
        0.95
    ),
    (
        'IT003',
        'MFA token reset required: locked out after 5 attempts',
        'Urgent request: I am trying to log in but facing an authentication block. I am unable to pass the two-factor authentication prompt due to: locked out after 5 attempts. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'IT',
        'high',
        'high',
        'Assigned to IT003 since the incident requires immediate MFA lockout (locked out after 5 attempts). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 50 minutes remaining on the clock.',
        'Verify user identity via manager, reset the MFA token seed in the identity provider, and guide the user through re-registration.',
        0.94
    ),
    (
        'IT003',
        'Security vulnerability alert: malware blocked',
        'Hello, I am reviewing the morning security dashboard. Our automated monitoring generated a malware blocked on one of the backend nodes. This is a compliance violation for SOC2. Please let me know when someone can look into this.',
        'IT',
        'medium',
        'low',
        'Assigned to IT003 since the user requires automated security alert (malware blocked). SLA Breach risk is MEDIUM; this standard request has a resolution window with 63 hours remaining on the clock.',
        'Analyze the vulnerability report, isolate the affected node if necessary, and apply the required security patches.',
        0.99
    ),
    (
        'IT003',
        'Suspicious email reported: fake invoice attachment',
        'To whom it may concern, I just received a highly suspicious email. It looks like a fake invoice attachment. I did not click any links. Others in my department might have received it too and it poses a security risk. I would appreciate a prompt resolution.',
        'IT',
        'high',
        'high',
        'Classification: Categorized under IT003 for phishing incident (fake invoice attachment). SLA risk is HIGH because we currently have only 35 minutes remaining before the critical SLA breach.',
        'Extract the IOCs (Indicators of Compromise), purge the malicious email from all inboxes via Exchange Admin, and monitor proxy logs.',
        0.93
    ),
    (
        'FC001',
        'HVAC adjustment needed: Too hot',
        'Urgent request: Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: Too hot. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC001 since the user requires workplace comfort issue (Too hot). SLA Breach risk is LOW; this standard request has a resolution window with 12 hours remaining on the clock.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.94
    ),
    (
        'FC001',
        'Plumbing issue reported: toilet constantly running',
        'Hi Helpdesk, I noticed a facility issue in the common area. We have a plumbing issue that needs attention: toilet constantly running. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'Facilities',
        'medium',
        'low',
        'Assigned to FC001 since the user requires plumbing and water leak issue (toilet constantly running). SLA Breach risk is MEDIUM; this standard request has a resolution window with 67 hours remaining on the clock.',
        'Dispatch a facility plumber to isolate the water valve and repair the leak/clog.',
        0.96
    ),
    (
        'FC001',
        'Electrical maintenance: Flickering fluorescent light',
        'Dear Support Team, I am reporting an electrical hazard. There is an electrical fault in my area: Flickering fluorescent light. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'Facilities',
        'high',
        'high',
        'Assigned to FC001 since the incident requires immediate electrical fault (Flickering fluorescent light). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 51 minutes remaining on the clock.',
        'De-energize the affected circuit at the breaker panel and replace the faulty electrical component.',
        0.93
    ),
    (
        'FC001',
        'Office furniture repair: whiteboard falling off wall',
        'Urgent request: I have an issue with my assigned workstation. I need someone to fix a piece of office furniture. Problem: whiteboard falling off wall. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC001 to handle furniture repair (whiteboard falling off wall). SLA risk is LOW as the deadline is stable, leaving 51 hours on the operational timeline.',
        'Send a handyman with tools to tighten joints, lubricate tracks, or order replacement furniture parts.',
        0.93
    ),
    (
        'FC001',
        'Janitorial cleaning requested: overflowing trash bins',
        'To whom it may concern, The office environment needs some attention. We need a cleaning crew sent to our area to deal with: overflowing trash bins. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC001 for janitorial and deep cleaning request (overflowing trash bins). SLA risk is LOW because we currently have 35 hours remaining before the standard SLA breach.',
        'Notify the contracted cleaning staff to perform targeted spot cleaning in the specified area.',
        0.97
    ),
    (
        'FC001',
        'HVAC adjustment needed: noisy AC rattling',
        'To whom it may concern, Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: noisy AC rattling. My productivity has dropped significantly due to this. Can maintenance please take a look and adjust the system?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC001 to handle workplace comfort issue (noisy AC rattling). SLA risk is LOW as the deadline is stable, leaving 43 hours on the operational timeline.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.97
    ),
    (
        'FC001',
        'Plumbing issue reported: Restroom sink clog',
        'Urgent request: I noticed a facility issue in the common area. We have a plumbing issue that needs attention: Restroom sink clog. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'Facilities',
        'medium',
        'low',
        'Allocated to FC001 to handle plumbing and water leak issue (Restroom sink clog). SLA risk is MEDIUM as the deadline is stable, leaving 26 hours on the operational timeline.',
        'Dispatch a facility plumber to isolate the water valve and repair the leak/clog.',
        0.97
    ),
    (
        'FC001',
        'Electrical maintenance: blown circuit breaker',
        'To whom it may concern, I am reporting an electrical hazard. There is an electrical fault in my area: blown circuit breaker. This is potentially hazardous and poses a safety risk. I would appreciate a prompt resolution.',
        'Facilities',
        'high',
        'high',
        'Assigned to FC001 since the incident requires immediate electrical fault (blown circuit breaker). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 45 minutes remaining on the clock.',
        'De-energize the affected circuit at the breaker panel and replace the faulty electrical component.',
        0.98
    ),
    (
        'FC001',
        'Office furniture repair: wobbly chair mechanism',
        'Dear Support Team, I have an issue with my assigned workstation. I need someone to fix a piece of office furniture. Problem: wobbly chair mechanism. My productivity has dropped significantly due to this. Please send a handyman.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC001 for furniture repair (wobbly chair mechanism). SLA risk is LOW because we currently have 25 hours remaining before the standard SLA breach.',
        'Send a handyman with tools to tighten joints, lubricate tracks, or order replacement furniture parts.',
        0.92
    ),
    (
        'FC001',
        'Janitorial cleaning requested: overflowing trash bins',
        'Hello, The office environment needs some attention. We need a cleaning crew sent to our area to deal with: overflowing trash bins. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC001 since the user requires janitorial and deep cleaning request (overflowing trash bins). SLA Breach risk is LOW; this standard request has a resolution window with 67 hours remaining on the clock.',
        'Notify the contracted cleaning staff to perform targeted spot cleaning in the specified area.',
        0.94
    ),
    (
        'FC001',
        'HVAC adjustment needed: too cold',
        'Dear Support Team, Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: too cold. I cannot complete my pending tasks without this. Can maintenance please take a look and adjust the system?',
        'Facilities',
        'low',
        'low',
        'Determined to be a workplace comfort issue (too cold) case suitable for FC001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 14 hours remaining.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.98
    ),
    (
        'FC001',
        'Plumbing issue reported: water dripping from ceiling',
        'Hi Helpdesk, I noticed a facility issue in the common area. We have a plumbing issue that needs attention: water dripping from ceiling. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'Facilities',
        'medium',
        'low',
        'Classification: Categorized under FC001 for plumbing and water leak issue (water dripping from ceiling). SLA risk is MEDIUM because we currently have 18 hours remaining before the standard SLA breach.',
        'Dispatch a facility plumber to isolate the water valve and repair the leak/clog.',
        0.97
    ),
    (
        'FC001',
        'Electrical maintenance: sparking light switch',
        'Dear Support Team, I am reporting an electrical hazard. There is an electrical fault in my area: sparking light switch. I cannot complete my pending tasks without this. Please send an electrician immediately.',
        'Facilities',
        'high',
        'high',
        'Forwarded to the FC001 queue because it involves electrical fault (sparking light switch). SLA BREACH WARNING: Urgency is HIGH with only 32 minutes of buffer time left under the emergency policy.',
        'De-energize the affected circuit at the breaker panel and replace the faulty electrical component.',
        0.98
    ),
    (
        'FC001',
        'Office furniture repair: Broken desk leg',
        'Hi Helpdesk, I have an issue with my assigned workstation. I need someone to fix a piece of office furniture. Problem: Broken desk leg. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC001 to handle furniture repair (Broken desk leg). SLA risk is LOW as the deadline is stable, leaving 44 hours on the operational timeline.',
        'Send a handyman with tools to tighten joints, lubricate tracks, or order replacement furniture parts.',
        0.92
    ),
    (
        'FC001',
        'Janitorial cleaning requested: overflowing trash bins',
        'Urgent request: The office environment needs some attention. We need a cleaning crew sent to our area to deal with: overflowing trash bins. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a janitorial and deep cleaning request (overflowing trash bins) case suitable for FC001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 14 hours remaining.',
        'Notify the contracted cleaning staff to perform targeted spot cleaning in the specified area.',
        0.93
    ),
    (
        'FC001',
        'HVAC adjustment needed: noisy AC rattling',
        'Urgent request: Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: noisy AC rattling. This is severely impacting my daily work. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC001 for workplace comfort issue (noisy AC rattling). SLA risk is LOW because we currently have 44 hours remaining before the standard SLA breach.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.97
    ),
    (
        'FC001',
        'Plumbing issue reported: Restroom sink clog',
        'To whom it may concern, I noticed a facility issue in the common area. We have a plumbing issue that needs attention: Restroom sink clog. It''s causing a mess and might damage the flooring if not fixed soon. Please let me know when someone can look into this.',
        'Facilities',
        'medium',
        'low',
        'Assigned to FC001 since the user requires plumbing and water leak issue (Restroom sink clog). SLA Breach risk is MEDIUM; this standard request has a resolution window with 53 hours remaining on the clock.',
        'Dispatch a facility plumber to isolate the water valve and repair the leak/clog.',
        0.92
    ),
    (
        'FC001',
        'Electrical maintenance: Flickering fluorescent light',
        'Hi Helpdesk, I am reporting an electrical hazard. There is an electrical fault in my area: Flickering fluorescent light. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'high',
        'high',
        'Assigned to FC001 since the incident requires immediate electrical fault (Flickering fluorescent light). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 40 minutes remaining on the clock.',
        'De-energize the affected circuit at the breaker panel and replace the faulty electrical component.',
        0.95
    ),
    (
        'FC001',
        'Office furniture repair: Broken desk leg',
        'Hi Helpdesk, I have an issue with my assigned workstation. I need someone to fix a piece of office furniture. Problem: Broken desk leg. This is a major blocker for my current sprint. Please send a handyman.',
        'Facilities',
        'low',
        'low',
        'Determined to be a furniture repair (Broken desk leg) case suitable for FC001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 22 hours remaining.',
        'Send a handyman with tools to tighten joints, lubricate tracks, or order replacement furniture parts.',
        0.93
    ),
    (
        'FC001',
        'Janitorial cleaning requested: overflowing trash bins',
        'Hi Helpdesk, The office environment needs some attention. We need a cleaning crew sent to our area to deal with: overflowing trash bins. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a janitorial and deep cleaning request (overflowing trash bins) case suitable for FC001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 19 hours remaining.',
        'Notify the contracted cleaning staff to perform targeted spot cleaning in the specified area.',
        0.94
    ),
    (
        'FC001',
        'HVAC adjustment needed: noisy AC rattling',
        'Hello, Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: noisy AC rattling. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC001 for workplace comfort issue (noisy AC rattling). SLA risk is LOW because we currently have 42 hours remaining before the standard SLA breach.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.93
    ),
    (
        'FC001',
        'Plumbing issue reported: water dripping from ceiling',
        'Hello, I noticed a facility issue in the common area. We have a plumbing issue that needs attention: water dripping from ceiling. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'Facilities',
        'medium',
        'low',
        'Allocated to FC001 to handle plumbing and water leak issue (water dripping from ceiling). SLA risk is MEDIUM as the deadline is stable, leaving 53 hours on the operational timeline.',
        'Dispatch a facility plumber to isolate the water valve and repair the leak/clog.',
        0.92
    ),
    (
        'FC001',
        'Electrical maintenance: sparking light switch',
        'Hello, I am reporting an electrical hazard. There is an electrical fault in my area: sparking light switch. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'high',
        'high',
        'Assigned to FC001 since the incident requires immediate electrical fault (sparking light switch). SLA Breach risk is HIGH; this critical request has an emergency resolution window, with 25 minutes remaining on the clock.',
        'De-energize the affected circuit at the breaker panel and replace the faulty electrical component.',
        0.93
    ),
    (
        'FC001',
        'Office furniture repair: jammed cabinet drawer',
        'Dear Support Team, I have an issue with my assigned workstation. I need someone to fix a piece of office furniture. Problem: jammed cabinet drawer. My productivity has dropped significantly due to this. Please send a handyman.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC001 to handle furniture repair (jammed cabinet drawer). SLA risk is LOW as the deadline is stable, leaving 42 hours on the operational timeline.',
        'Send a handyman with tools to tighten joints, lubricate tracks, or order replacement furniture parts.',
        0.98
    ),
    (
        'FC001',
        'Janitorial cleaning requested: Coffee spill on carpet',
        'Hi Helpdesk, The office environment needs some attention. We need a cleaning crew sent to our area to deal with: Coffee spill on carpet. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC001 since the user requires janitorial and deep cleaning request (Coffee spill on carpet). SLA Breach risk is LOW; this standard request has a resolution window with 46 hours remaining on the clock.',
        'Notify the contracted cleaning staff to perform targeted spot cleaning in the specified area.',
        0.96
    ),
    (
        'FC001',
        'HVAC adjustment needed: Too hot',
        'Dear Support Team, Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: Too hot. It is causing physical discomfort and distraction. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC001 since the user requires workplace comfort issue (Too hot). SLA Breach risk is LOW; this standard request has a resolution window with 30 hours remaining on the clock.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.96
    ),
    (
        'FC001',
        'Plumbing issue reported: water dripping from ceiling',
        'Urgent request: I noticed a facility issue in the common area. We have a plumbing issue that needs attention: water dripping from ceiling. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'medium',
        'low',
        'Determined to be a plumbing and water leak issue (water dripping from ceiling) case suitable for FC001. SLA risk is MEDIUM: the applicable policy allows a standard turnaround time, leaving 17 hours remaining.',
        'Dispatch a facility plumber to isolate the water valve and repair the leak/clog.',
        0.97
    ),
    (
        'FC001',
        'Electrical maintenance: Flickering fluorescent light',
        'Urgent request: I am reporting an electrical hazard. There is an electrical fault in my area: Flickering fluorescent light. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'Facilities',
        'high',
        'high',
        'Forwarded to the FC001 queue because it involves electrical fault (Flickering fluorescent light). SLA BREACH WARNING: Urgency is HIGH with only 116 minutes of buffer time left under the emergency policy.',
        'De-energize the affected circuit at the breaker panel and replace the faulty electrical component.',
        0.95
    ),
    (
        'FC001',
        'Office furniture repair: whiteboard falling off wall',
        'Dear Support Team, I have an issue with my assigned workstation. I need someone to fix a piece of office furniture. Problem: whiteboard falling off wall. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a furniture repair (whiteboard falling off wall) case suitable for FC001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 29 hours remaining.',
        'Send a handyman with tools to tighten joints, lubricate tracks, or order replacement furniture parts.',
        0.98
    ),
    (
        'FC001',
        'Janitorial cleaning requested: overflowing trash bins',
        'Hi Helpdesk, The office environment needs some attention. We need a cleaning crew sent to our area to deal with: overflowing trash bins. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC001 to handle janitorial and deep cleaning request (overflowing trash bins). SLA risk is LOW as the deadline is stable, leaving 12 hours on the operational timeline.',
        'Notify the contracted cleaning staff to perform targeted spot cleaning in the specified area.',
        0.97
    ),
    (
        'FC001',
        'HVAC adjustment needed: Too hot',
        'To whom it may concern, Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: Too hot. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a workplace comfort issue (Too hot) case suitable for FC001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 14 hours remaining.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.94
    ),
    (
        'FC001',
        'Plumbing issue reported: toilet constantly running',
        'Dear Support Team, I noticed a facility issue in the common area. We have a plumbing issue that needs attention: toilet constantly running. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'Facilities',
        'medium',
        'low',
        'Allocated to FC001 to handle plumbing and water leak issue (toilet constantly running). SLA risk is MEDIUM as the deadline is stable, leaving 53 hours on the operational timeline.',
        'Dispatch a facility plumber to isolate the water valve and repair the leak/clog.',
        0.95
    ),
    (
        'FC001',
        'Electrical maintenance: sparking light switch',
        'Hi Helpdesk, I am reporting an electrical hazard. There is an electrical fault in my area: sparking light switch. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'high',
        'high',
        'Forwarded to the FC001 queue because it involves electrical fault (sparking light switch). SLA BREACH WARNING: Urgency is HIGH with only 80 minutes of buffer time left under the emergency policy.',
        'De-energize the affected circuit at the breaker panel and replace the faulty electrical component.',
        0.97
    ),
    (
        'FC001',
        'Office furniture repair: Broken desk leg',
        'Hello, I have an issue with my assigned workstation. I need someone to fix a piece of office furniture. Problem: Broken desk leg. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Assigned to FC001 since the user requires furniture repair (Broken desk leg). SLA Breach risk is LOW; this standard request has a resolution window with 60 hours remaining on the clock.',
        'Send a handyman with tools to tighten joints, lubricate tracks, or order replacement furniture parts.',
        0.97
    ),
    (
        'FC001',
        'Janitorial cleaning requested: dirty glass windows',
        'Hello, The office environment needs some attention. We need a cleaning crew sent to our area to deal with: dirty glass windows. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC001 to handle janitorial and deep cleaning request (dirty glass windows). SLA risk is LOW as the deadline is stable, leaving 40 hours on the operational timeline.',
        'Notify the contracted cleaning staff to perform targeted spot cleaning in the specified area.',
        0.95
    ),
    (
        'FC001',
        'HVAC adjustment needed: Too hot',
        'Hi Helpdesk, Our team is located on the East wing. The climate control in our zone is uncomfortable. Specifically: Too hot. This is a major blocker for my current sprint. Can maintenance please take a look and adjust the system?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC001 to handle workplace comfort issue (Too hot). SLA risk is LOW as the deadline is stable, leaving 22 hours on the operational timeline.',
        'Inspect the local HVAC diffuser, check the BMS (Building Management System) thermostat settings, and adjust as needed.',
        0.97
    ),
    (
        'FC002',
        'Guest registration and parking for Investor group',
        'Hi Helpdesk, We have an important visit scheduled. We are hosting a Investor group tomorrow. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for VIP guest and parking coordination for Investor group. SLA risk is LOW because we currently have 61 hours remaining before the standard SLA breach.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.92
    ),
    (
        'FC002',
        'Courier dispatch request: legal notice to supplier',
        'To whom it may concern, I need assistance from the mailroom. I have a package that needs to go out today: legal notice to supplier. The cost center code is attached. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a outgoing courier logistics (legal notice to supplier) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 34 hours remaining.',
        'Generate the shipping waybill, attach it to the parcel, and hand it over to the daily courier pickup.',
        0.95
    ),
    (
        'FC002',
        'Room booking and physical setup for Quarterly Townhall',
        'Urgent request: We are organizing a large department event. I''ve booked the main event space for a Quarterly Townhall. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for event space physical setup (Quarterly Townhall). SLA risk is LOW because we currently have 61 hours remaining before the standard SLA breach.',
        'Review the floor plan requirements and move furniture into the requested configuration prior to the event.',
        0.95
    ),
    (
        'FC002',
        'Lost and Found inquiry: temporary access pass return',
        'Dear Support Team, I am checking regarding a misplaced item. Regarding a temporary access pass return. I believe I left it in the lobby. My productivity has dropped significantly due to this. Can the reception desk check the lost and found log?',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for lost and found management (temporary access pass return). SLA risk is LOW because we currently have 12 hours remaining before the standard SLA breach.',
        'Check the secure lost and found locker and update the registry log.',
        0.95
    ),
    (
        'FC002',
        'Corporate vehicle booking: transporting heavy equipment',
        'Dear Support Team, I have an upcoming business requirement. I need to reserve a corporate 7-seater car and driver for tomorrow afternoon for a transporting heavy equipment. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires vehicle fleet scheduling (transporting heavy equipment). SLA Breach risk is LOW; this standard request has a resolution window with 19 hours remaining on the clock.',
        'Check the fleet calendar, assign an available driver, and send a calendar invite to the requestor.',
        0.92
    ),
    (
        'FC002',
        'Guest registration and parking for Key Client Executive',
        'Hi Helpdesk, We have an important visit scheduled. We are hosting a Key Client Executive tomorrow. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for VIP guest and parking coordination for Key Client Executive. SLA risk is LOW because we currently have 50 hours remaining before the standard SLA breach.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.97
    ),
    (
        'FC002',
        'Courier dispatch request: legal notice to supplier',
        'Dear Support Team, I need assistance from the mailroom. I have a package that needs to go out today: legal notice to supplier. The cost center code is attached. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC002 to handle outgoing courier logistics (legal notice to supplier). SLA risk is LOW as the deadline is stable, leaving 13 hours on the operational timeline.',
        'Generate the shipping waybill, attach it to the parcel, and hand it over to the daily courier pickup.',
        0.97
    ),
    (
        'FC002',
        'Room booking and physical setup for Team Lunch Setup',
        'Urgent request: We are organizing a large department event. I''ve booked the main event space for a Team Lunch Setup. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Determined to be a event space physical setup (Team Lunch Setup) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 33 hours remaining.',
        'Review the floor plan requirements and move furniture into the requested configuration prior to the event.',
        0.97
    ),
    (
        'FC002',
        'Lost and Found inquiry: found leather wallet',
        'Hello, I am checking regarding a misplaced item. Regarding a found leather wallet. I believe I left it in the lobby. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Determined to be a lost and found management (found leather wallet) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 55 hours remaining.',
        'Check the secure lost and found locker and update the registry log.',
        0.97
    ),
    (
        'FC002',
        'Corporate vehicle booking: transporting heavy equipment',
        'Urgent request: I have an upcoming business requirement. I need to reserve a corporate 7-seater car and driver for tomorrow afternoon for a transporting heavy equipment. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a vehicle fleet scheduling (transporting heavy equipment) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 71 hours remaining.',
        'Check the fleet calendar, assign an available driver, and send a calendar invite to the requestor.',
        0.98
    ),
    (
        'FC002',
        'Guest registration and parking for External Auditor',
        'Urgent request: We have an important visit scheduled. We are hosting a External Auditor tomorrow. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires VIP guest and parking coordination for External Auditor. SLA Breach risk is LOW; this standard request has a resolution window with 64 hours remaining on the clock.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.98
    ),
    (
        'FC002',
        'Courier dispatch request: legal notice to supplier',
        'Urgent request: I need assistance from the mailroom. I have a package that needs to go out today: legal notice to supplier. The cost center code is attached. It is time-sensitive and must be shipped today. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires outgoing courier logistics (legal notice to supplier). SLA Breach risk is LOW; this standard request has a resolution window with 27 hours remaining on the clock.',
        'Generate the shipping waybill, attach it to the parcel, and hand it over to the daily courier pickup.',
        0.93
    ),
    (
        'FC002',
        'Room booking and physical setup for Quarterly Townhall',
        'To whom it may concern, We are organizing a large department event. I''ve booked the main event space for a Quarterly Townhall. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for event space physical setup (Quarterly Townhall). SLA risk is LOW because we currently have 33 hours remaining before the standard SLA breach.',
        'Review the floor plan requirements and move furniture into the requested configuration prior to the event.',
        0.96
    ),
    (
        'FC002',
        'Lost and Found inquiry: missing umbrella',
        'To whom it may concern, I am checking regarding a misplaced item. Regarding a missing umbrella. I believe I left it in the lobby. This is severely impacting my daily work. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires lost and found management (missing umbrella). SLA Breach risk is LOW; this standard request has a resolution window with 18 hours remaining on the clock.',
        'Check the secure lost and found locker and update the registry log.',
        0.96
    ),
    (
        'FC002',
        'Corporate vehicle booking: airport pickup',
        'Hi Helpdesk, I have an upcoming business requirement. I need to reserve a corporate 7-seater car and driver for tomorrow afternoon for a airport pickup. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires vehicle fleet scheduling (airport pickup). SLA Breach risk is LOW; this standard request has a resolution window with 63 hours remaining on the clock.',
        'Check the fleet calendar, assign an available driver, and send a calendar invite to the requestor.',
        0.97
    ),
    (
        'FC002',
        'Guest registration and parking for External Auditor',
        'Dear Support Team, We have an important visit scheduled. We are hosting a External Auditor tomorrow. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC002 to handle VIP guest and parking coordination for External Auditor. SLA risk is LOW as the deadline is stable, leaving 37 hours on the operational timeline.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.97
    ),
    (
        'FC002',
        'Courier dispatch request: legal notice to supplier',
        'To whom it may concern, I need assistance from the mailroom. I have a package that needs to go out today: legal notice to supplier. The cost center code is attached. This is a major blocker for my current sprint. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Determined to be a outgoing courier logistics (legal notice to supplier) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 71 hours remaining.',
        'Generate the shipping waybill, attach it to the parcel, and hand it over to the daily courier pickup.',
        0.98
    ),
    (
        'FC002',
        'Room booking and physical setup for Quarterly Townhall',
        'To whom it may concern, We are organizing a large department event. I''ve booked the main event space for a Quarterly Townhall. The room is currently empty and needs to be prepared. I need the facilities team to arrange the chairs and set up the projector.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires event space physical setup (Quarterly Townhall). SLA Breach risk is LOW; this standard request has a resolution window with 71 hours remaining on the clock.',
        'Review the floor plan requirements and move furniture into the requested configuration prior to the event.',
        0.94
    ),
    (
        'FC002',
        'Lost and Found inquiry: missing umbrella',
        'Hi Helpdesk, I am checking regarding a misplaced item. Regarding a missing umbrella. I believe I left it in the lobby. It has personal/corporate value. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a lost and found management (missing umbrella) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 12 hours remaining.',
        'Check the secure lost and found locker and update the registry log.',
        0.95
    ),
    (
        'FC002',
        'Corporate vehicle booking: airport pickup',
        'Hello, I have an upcoming business requirement. I need to reserve a corporate 7-seater car and driver for tomorrow afternoon for a airport pickup. Public transport is not viable for this group. Please confirm availability.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC002 to handle vehicle fleet scheduling (airport pickup). SLA risk is LOW as the deadline is stable, leaving 26 hours on the operational timeline.',
        'Check the fleet calendar, assign an available driver, and send a calendar invite to the requestor.',
        0.95
    ),
    (
        'FC002',
        'Guest registration and parking for Key Client Executive',
        'Urgent request: We have an important visit scheduled. We are hosting a Key Client Executive tomorrow. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires VIP guest and parking coordination for Key Client Executive. SLA Breach risk is LOW; this standard request has a resolution window with 42 hours remaining on the clock.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.93
    ),
    (
        'FC002',
        'Courier dispatch request: marketing materials to branch',
        'To whom it may concern, I need assistance from the mailroom. I have a package that needs to go out today: marketing materials to branch. The cost center code is attached. It is time-sensitive and must be shipped today. Please arrange DHL/FedEx pickup.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for outgoing courier logistics (marketing materials to branch). SLA risk is LOW because we currently have 27 hours remaining before the standard SLA breach.',
        'Generate the shipping waybill, attach it to the parcel, and hand it over to the daily courier pickup.',
        0.95
    ),
    (
        'FC002',
        'Room booking and physical setup for Quarterly Townhall',
        'Hello, We are organizing a large department event. I''ve booked the main event space for a Quarterly Townhall. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC002 to handle event space physical setup (Quarterly Townhall). SLA risk is LOW as the deadline is stable, leaving 28 hours on the operational timeline.',
        'Review the floor plan requirements and move furniture into the requested configuration prior to the event.',
        0.95
    ),
    (
        'FC002',
        'Lost and Found inquiry: found leather wallet',
        'To whom it may concern, I am checking regarding a misplaced item. Regarding a found leather wallet. I believe I left it in the lobby. It has personal/corporate value. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for lost and found management (found leather wallet). SLA risk is LOW because we currently have 30 hours remaining before the standard SLA breach.',
        'Check the secure lost and found locker and update the registry log.',
        0.95
    ),
    (
        'FC002',
        'Corporate vehicle booking: Trip to factory',
        'Hello, I have an upcoming business requirement. I need to reserve a corporate 7-seater car and driver for tomorrow afternoon for a Trip to factory. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Determined to be a vehicle fleet scheduling (Trip to factory) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 61 hours remaining.',
        'Check the fleet calendar, assign an available driver, and send a calendar invite to the requestor.',
        0.92
    ),
    (
        'FC002',
        'Guest registration and parking for Key Client Executive',
        'Hello, We have an important visit scheduled. We are hosting a Key Client Executive tomorrow. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a VIP guest and parking coordination for Key Client Executive case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 23 hours remaining.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.96
    ),
    (
        'FC002',
        'Courier dispatch request: marketing materials to branch',
        'Hi Helpdesk, I need assistance from the mailroom. I have a package that needs to go out today: marketing materials to branch. The cost center code is attached. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC002 to handle outgoing courier logistics (marketing materials to branch). SLA risk is LOW as the deadline is stable, leaving 15 hours on the operational timeline.',
        'Generate the shipping waybill, attach it to the parcel, and hand it over to the daily courier pickup.',
        0.93
    ),
    (
        'FC002',
        'Room booking and physical setup for Client Pitch',
        'Dear Support Team, We are organizing a large department event. I''ve booked the main event space for a Client Pitch. The room is currently empty and needs to be prepared. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a event space physical setup (Client Pitch) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 48 hours remaining.',
        'Review the floor plan requirements and move furniture into the requested configuration prior to the event.',
        0.97
    ),
    (
        'FC002',
        'Lost and Found inquiry: missing umbrella',
        'Hello, I am checking regarding a misplaced item. Regarding a missing umbrella. I believe I left it in the lobby. My productivity has dropped significantly due to this. Can the reception desk check the lost and found log?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC002 to handle lost and found management (missing umbrella). SLA risk is LOW as the deadline is stable, leaving 46 hours on the operational timeline.',
        'Check the secure lost and found locker and update the registry log.',
        0.93
    ),
    (
        'FC002',
        'Corporate vehicle booking: transporting heavy equipment',
        'To whom it may concern, I have an upcoming business requirement. I need to reserve a corporate 7-seater car and driver for tomorrow afternoon for a transporting heavy equipment. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC002 to handle vehicle fleet scheduling (transporting heavy equipment). SLA risk is LOW as the deadline is stable, leaving 57 hours on the operational timeline.',
        'Check the fleet calendar, assign an available driver, and send a calendar invite to the requestor.',
        0.98
    ),
    (
        'FC002',
        'Guest registration and parking for External Auditor',
        'Urgent request: We have an important visit scheduled. We are hosting a External Auditor tomorrow. This is a major blocker for my current sprint. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for VIP guest and parking coordination for External Auditor. SLA risk is LOW because we currently have 43 hours remaining before the standard SLA breach.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.92
    ),
    (
        'FC002',
        'Courier dispatch request: bulk holiday cards',
        'To whom it may concern, I need assistance from the mailroom. I have a package that needs to go out today: bulk holiday cards. The cost center code is attached. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for outgoing courier logistics (bulk holiday cards). SLA risk is LOW because we currently have 28 hours remaining before the standard SLA breach.',
        'Generate the shipping waybill, attach it to the parcel, and hand it over to the daily courier pickup.',
        0.95
    ),
    (
        'FC002',
        'Room booking and physical setup for Product Workshop',
        'To whom it may concern, We are organizing a large department event. I''ve booked the main event space for a Product Workshop. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires event space physical setup (Product Workshop). SLA Breach risk is LOW; this standard request has a resolution window with 43 hours remaining on the clock.',
        'Review the floor plan requirements and move furniture into the requested configuration prior to the event.',
        0.94
    ),
    (
        'FC002',
        'Lost and Found inquiry: Lost ID badge',
        'Dear Support Team, I am checking regarding a misplaced item. Regarding a Lost ID badge. I believe I left it in the lobby. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a lost and found management (Lost ID badge) case suitable for FC002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 28 hours remaining.',
        'Check the secure lost and found locker and update the registry log.',
        0.97
    ),
    (
        'FC002',
        'Corporate vehicle booking: transporting heavy equipment',
        'To whom it may concern, I have an upcoming business requirement. I need to reserve a corporate 7-seater car and driver for tomorrow afternoon for a transporting heavy equipment. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC002 since the user requires vehicle fleet scheduling (transporting heavy equipment). SLA Breach risk is LOW; this standard request has a resolution window with 70 hours remaining on the clock.',
        'Check the fleet calendar, assign an available driver, and send a calendar invite to the requestor.',
        0.93
    ),
    (
        'FC002',
        'Guest registration and parking for VIP Partner',
        'Dear Support Team, We have an important visit scheduled. We are hosting a VIP Partner tomorrow. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC002 for VIP guest and parking coordination for VIP Partner. SLA risk is LOW because we currently have 63 hours remaining before the standard SLA breach.',
        'Log visitor details in the building security portal and block out the VIP parking bays.',
        0.97
    ),
    (
        'FC003',
        'Stationery restock request: staplers',
        'Hi Helpdesk, Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of staplers. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle office supply fulfillment (staplers). SLA risk is LOW as the deadline is stable, leaving 62 hours on the operational timeline.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.96
    ),
    (
        'FC003',
        'Pantry consumables empty: fresh milk',
        'To whom it may concern, The break room needs restocking. We run out of fresh milk in the East Wing pantry very quickly. Employees are complaining about the shortage. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a pantry consumable restocking (fresh milk) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 60 hours remaining.',
        'Restock the pantry area immediately and adjust the daily inventory par levels for future orders.',
        0.92
    ),
    (
        'FC003',
        'Restroom/Hygiene supplies needed: surface wipes',
        'Dear Support Team, I noticed an issue in the restrooms. The dispensers for surface wipes in the 18th floor restrooms are empty. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'Facilities',
        'medium',
        'low',
        'Determined to be a hygiene supply management (surface wipes) case suitable for FC003. SLA risk is MEDIUM: the applicable policy allows a standard turnaround time, leaving 63 hours remaining.',
        'Dispatch staff to refill the dispensers and verify stock levels in adjacent restrooms.',
        0.94
    ),
    (
        'FC003',
        'First Aid kit replenishment: paracetamol',
        'Urgent request: I was checking the emergency supplies. I used the last of the paracetamol from the wall-mounted first aid kit in the breakroom. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a medical consumable restocking (paracetamol) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 47 hours remaining.',
        'Log the consumption of medical supplies and place the required items into the first aid kit.',
        0.96
    ),
    (
        'FC003',
        'Special catering order for friday happy hour beverages',
        'Hi Helpdesk, We have an important event coming up. We have an upcoming friday happy hour beverages and need to order specialized food and beverages. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Determined to be a catering and event food coordination (friday happy hour beverages) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 21 hours remaining.',
        'Contact the approved catering vendor, place the food order, and arrange delivery timing.',
        0.96
    ),
    (
        'FC003',
        'Stationery restock request: A4 printer paper',
        'To whom it may concern, Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of A4 printer paper. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a office supply fulfillment (A4 printer paper) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 64 hours remaining.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.97
    ),
    (
        'FC003',
        'Pantry consumables empty: fresh milk',
        'To whom it may concern, The break room needs restocking. We run out of fresh milk in the East Wing pantry very quickly. This is severely impacting my daily work. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle pantry consumable restocking (fresh milk). SLA risk is LOW as the deadline is stable, leaving 18 hours on the operational timeline.',
        'Restock the pantry area immediately and adjust the daily inventory par levels for future orders.',
        0.97
    ),
    (
        'FC003',
        'Restroom/Hygiene supplies needed: paper towels',
        'Dear Support Team, I noticed an issue in the restrooms. The dispensers for paper towels in the 18th floor restrooms are empty. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'Facilities',
        'medium',
        'low',
        'Allocated to FC003 to handle hygiene supply management (paper towels). SLA risk is MEDIUM as the deadline is stable, leaving 19 hours on the operational timeline.',
        'Dispatch staff to refill the dispensers and verify stock levels in adjacent restrooms.',
        0.97
    ),
    (
        'FC003',
        'First Aid kit replenishment: Band-aids',
        'To whom it may concern, I was checking the emergency supplies. I used the last of the Band-aids from the wall-mounted first aid kit in the breakroom. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle medical consumable restocking (Band-aids). SLA risk is LOW as the deadline is stable, leaving 57 hours on the operational timeline.',
        'Log the consumption of medical supplies and place the required items into the first aid kit.',
        0.96
    ),
    (
        'FC003',
        'Special catering order for team building snacks',
        'To whom it may concern, We have an important event coming up. We have an upcoming team building snacks and need to order specialized food and beverages. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Determined to be a catering and event food coordination (team building snacks) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 13 hours remaining.',
        'Contact the approved catering vendor, place the food order, and arrange delivery timing.',
        0.96
    ),
    (
        'FC003',
        'Stationery restock request: A4 printer paper',
        'Urgent request: Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of A4 printer paper. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a office supply fulfillment (A4 printer paper) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 60 hours remaining.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.96
    ),
    (
        'FC003',
        'Pantry consumables empty: fresh milk',
        'To whom it may concern, The break room needs restocking. We run out of fresh milk in the East Wing pantry very quickly. This is a major blocker for my current sprint. Can we increase the daily allocation or get an urgent refill today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a pantry consumable restocking (fresh milk) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 41 hours remaining.',
        'Restock the pantry area immediately and adjust the daily inventory par levels for future orders.',
        0.96
    ),
    (
        'FC003',
        'Restroom/Hygiene supplies needed: paper towels',
        'Dear Support Team, I noticed an issue in the restrooms. The dispensers for paper towels in the 18th floor restrooms are empty. My productivity has dropped significantly due to this. Please alert the cleaning staff to refill them.',
        'Facilities',
        'medium',
        'low',
        'Assigned to FC003 since the user requires hygiene supply management (paper towels). SLA Breach risk is MEDIUM; this standard request has a resolution window with 27 hours remaining on the clock.',
        'Dispatch staff to refill the dispensers and verify stock levels in adjacent restrooms.',
        0.95
    ),
    (
        'FC003',
        'First Aid kit replenishment: burn cream',
        'To whom it may concern, I was checking the emergency supplies. I used the last of the burn cream from the wall-mounted first aid kit in the breakroom. We must maintain safety compliance at all times. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle medical consumable restocking (burn cream). SLA risk is LOW as the deadline is stable, leaving 34 hours on the operational timeline.',
        'Log the consumption of medical supplies and place the required items into the first aid kit.',
        0.92
    ),
    (
        'FC003',
        'Special catering order for team building snacks',
        'To whom it may concern, We have an important event coming up. We have an upcoming team building snacks and need to order specialized food and beverages. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle catering and event food coordination (team building snacks). SLA risk is LOW as the deadline is stable, leaving 23 hours on the operational timeline.',
        'Contact the approved catering vendor, place the food order, and arrange delivery timing.',
        0.97
    ),
    (
        'FC003',
        'Stationery restock request: notebooks',
        'Hi Helpdesk, Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of notebooks. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC003 for office supply fulfillment (notebooks). SLA risk is LOW because we currently have 47 hours remaining before the standard SLA breach.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.92
    ),
    (
        'FC003',
        'Pantry consumables empty: paper cups',
        'Hi Helpdesk, The break room needs restocking. We run out of paper cups in the East Wing pantry very quickly. This is a major blocker for my current sprint. Can we increase the daily allocation or get an urgent refill today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a pantry consumable restocking (paper cups) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 32 hours remaining.',
        'Restock the pantry area immediately and adjust the daily inventory par levels for future orders.',
        0.97
    ),
    (
        'FC003',
        'Restroom/Hygiene supplies needed: paper towels',
        'To whom it may concern, I noticed an issue in the restrooms. The dispensers for paper towels in the 18th floor restrooms are empty. My productivity has dropped significantly due to this. Please alert the cleaning staff to refill them.',
        'Facilities',
        'medium',
        'low',
        'Classification: Categorized under FC003 for hygiene supply management (paper towels). SLA risk is MEDIUM because we currently have 63 hours remaining before the standard SLA breach.',
        'Dispatch staff to refill the dispensers and verify stock levels in adjacent restrooms.',
        0.92
    ),
    (
        'FC003',
        'First Aid kit replenishment: Band-aids',
        'Urgent request: I was checking the emergency supplies. I used the last of the Band-aids from the wall-mounted first aid kit in the breakroom. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC003 since the user requires medical consumable restocking (Band-aids). SLA Breach risk is LOW; this standard request has a resolution window with 58 hours remaining on the clock.',
        'Log the consumption of medical supplies and place the required items into the first aid kit.',
        0.96
    ),
    (
        'FC003',
        'Special catering order for dietary requirement meals',
        'Dear Support Team, We have an important event coming up. We have an upcoming dietary requirement meals and need to order specialized food and beverages. This is severely impacting my daily work. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC003 for catering and event food coordination (dietary requirement meals). SLA risk is LOW because we currently have 46 hours remaining before the standard SLA breach.',
        'Contact the approved catering vendor, place the food order, and arrange delivery timing.',
        0.96
    ),
    (
        'FC003',
        'Stationery restock request: pens',
        'Dear Support Team, Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of pens. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle office supply fulfillment (pens). SLA risk is LOW as the deadline is stable, leaving 53 hours on the operational timeline.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.94
    ),
    (
        'FC003',
        'Pantry consumables empty: stir sticks',
        'To whom it may concern, The break room needs restocking. We run out of stir sticks in the East Wing pantry very quickly. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Determined to be a pantry consumable restocking (stir sticks) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 50 hours remaining.',
        'Restock the pantry area immediately and adjust the daily inventory par levels for future orders.',
        0.92
    ),
    (
        'FC003',
        'Restroom/Hygiene supplies needed: hand sanitizer',
        'Urgent request: I noticed an issue in the restrooms. The dispensers for hand sanitizer in the 18th floor restrooms are empty. This is severely impacting my daily work. Please advise on the next steps.',
        'Facilities',
        'medium',
        'low',
        'Assigned to FC003 since the user requires hygiene supply management (hand sanitizer). SLA Breach risk is MEDIUM; this standard request has a resolution window with 38 hours remaining on the clock.',
        'Dispatch staff to refill the dispensers and verify stock levels in adjacent restrooms.',
        0.96
    ),
    (
        'FC003',
        'First Aid kit replenishment: paracetamol',
        'Urgent request: I was checking the emergency supplies. I used the last of the paracetamol from the wall-mounted first aid kit in the breakroom. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC003 for medical consumable restocking (paracetamol). SLA risk is LOW because we currently have 47 hours remaining before the standard SLA breach.',
        'Log the consumption of medical supplies and place the required items into the first aid kit.',
        0.98
    ),
    (
        'FC003',
        'Special catering order for dietary requirement meals',
        'Dear Support Team, We have an important event coming up. We have an upcoming dietary requirement meals and need to order specialized food and beverages. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle catering and event food coordination (dietary requirement meals). SLA risk is LOW as the deadline is stable, leaving 15 hours on the operational timeline.',
        'Contact the approved catering vendor, place the food order, and arrange delivery timing.',
        0.97
    ),
    (
        'FC003',
        'Stationery restock request: Whiteboard markers',
        'Dear Support Team, Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of Whiteboard markers. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'Facilities',
        'low',
        'low',
        'Assigned to FC003 since the user requires office supply fulfillment (Whiteboard markers). SLA Breach risk is LOW; this standard request has a resolution window with 58 hours remaining on the clock.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.96
    ),
    (
        'FC003',
        'Pantry consumables empty: paper cups',
        'Hi Helpdesk, The break room needs restocking. We run out of paper cups in the East Wing pantry very quickly. Employees are complaining about the shortage. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Determined to be a pantry consumable restocking (paper cups) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 47 hours remaining.',
        'Restock the pantry area immediately and adjust the daily inventory par levels for future orders.',
        0.97
    ),
    (
        'FC003',
        'Restroom/Hygiene supplies needed: Hand soap',
        'Dear Support Team, I noticed an issue in the restrooms. The dispensers for Hand soap in the 18th floor restrooms are empty. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'Facilities',
        'medium',
        'low',
        'Allocated to FC003 to handle hygiene supply management (Hand soap). SLA risk is MEDIUM as the deadline is stable, leaving 30 hours on the operational timeline.',
        'Dispatch staff to refill the dispensers and verify stock levels in adjacent restrooms.',
        0.95
    ),
    (
        'FC003',
        'First Aid kit replenishment: burn cream',
        'Urgent request: I was checking the emergency supplies. I used the last of the burn cream from the wall-mounted first aid kit in the breakroom. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC003 for medical consumable restocking (burn cream). SLA risk is LOW because we currently have 61 hours remaining before the standard SLA breach.',
        'Log the consumption of medical supplies and place the required items into the first aid kit.',
        0.97
    ),
    (
        'FC003',
        'Special catering order for friday happy hour beverages',
        'Hello, We have an important event coming up. We have an upcoming friday happy hour beverages and need to order specialized food and beverages. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle catering and event food coordination (friday happy hour beverages). SLA risk is LOW as the deadline is stable, leaving 56 hours on the operational timeline.',
        'Contact the approved catering vendor, place the food order, and arrange delivery timing.',
        0.93
    ),
    (
        'FC003',
        'Stationery restock request: pens',
        'Urgent request: Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of pens. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle office supply fulfillment (pens). SLA risk is LOW as the deadline is stable, leaving 47 hours on the operational timeline.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.98
    ),
    (
        'FC003',
        'Pantry consumables empty: tea bags',
        'Hello, The break room needs restocking. We run out of tea bags in the East Wing pantry very quickly. This is severely impacting my daily work. Can we increase the daily allocation or get an urgent refill today?',
        'Facilities',
        'low',
        'low',
        'Determined to be a pantry consumable restocking (tea bags) case suitable for FC003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 26 hours remaining.',
        'Restock the pantry area immediately and adjust the daily inventory par levels for future orders.',
        0.94
    ),
    (
        'FC003',
        'Restroom/Hygiene supplies needed: surface wipes',
        'Urgent request: I noticed an issue in the restrooms. The dispensers for surface wipes in the 18th floor restrooms are empty. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'Facilities',
        'medium',
        'low',
        'Assigned to FC003 since the user requires hygiene supply management (surface wipes). SLA Breach risk is MEDIUM; this standard request has a resolution window with 22 hours remaining on the clock.',
        'Dispatch staff to refill the dispensers and verify stock levels in adjacent restrooms.',
        0.96
    ),
    (
        'FC003',
        'First Aid kit replenishment: antiseptic spray',
        'Hello, I was checking the emergency supplies. I used the last of the antiseptic spray from the wall-mounted first aid kit in the breakroom. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC003 for medical consumable restocking (antiseptic spray). SLA risk is LOW because we currently have 55 hours remaining before the standard SLA breach.',
        'Log the consumption of medical supplies and place the required items into the first aid kit.',
        0.93
    ),
    (
        'FC003',
        'Special catering order for dietary requirement meals',
        'Hi Helpdesk, We have an important event coming up. We have an upcoming dietary requirement meals and need to order specialized food and beverages. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'Facilities',
        'low',
        'low',
        'Allocated to FC003 to handle catering and event food coordination (dietary requirement meals). SLA risk is LOW as the deadline is stable, leaving 14 hours on the operational timeline.',
        'Contact the approved catering vendor, place the food order, and arrange delivery timing.',
        0.96
    ),
    (
        'FC003',
        'Stationery restock request: sticky notes',
        'Hi Helpdesk, Our floor''s supply closet is empty. The stationery cabinet on our floor is completely out of sticky notes. Our team needs these materials to function efficiently. I would appreciate a prompt resolution.',
        'Facilities',
        'low',
        'low',
        'Classification: Categorized under FC003 for office supply fulfillment (sticky notes). SLA risk is LOW because we currently have 42 hours remaining before the standard SLA breach.',
        'Pick the items from the central stationery store and deliver them to the requesting floor''s cabinet.',
        0.93
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: Bonus tax calculation',
        'Urgent request: I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding Bonus tax calculation. This is affecting my personal financial planning. Can we get this resolved by today?',
        'HR',
        'medium',
        'low',
        'Assigned to HR001 since the user requires payroll and compensation queries (Bonus tax calculation). SLA Breach risk is LOW; this standard request has a resolution window with 27 hours remaining on the clock.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.92
    ),
    (
        'HR001',
        'Application for statutory Maternity leave',
        'Dear Support Team, I need to apply for an extended absence. I need to formally apply for Maternity leave starting next month. This is severely impacting my daily work. Please let me know what medical or legal documents I need to submit to HR.',
        'HR',
        'low',
        'low',
        'Assigned to HR001 since the user requires statutory leave processing (Maternity leave). SLA Breach risk is LOW; this standard request has a resolution window with 58 hours remaining on the clock.',
        'Provide the employee with the required government forms and update their status in the HRIS system.',
        0.96
    ),
    (
        'HR001',
        'Update direct deposit details to ACB',
        'Hello, I have changed my personal banking provider. I have switched my primary bank account to ACB. I need to ensure my next salary is routed correctly. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Determined to be a bank account detail updates for payroll (ACB) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 45 hours remaining.',
        'Verify the employee''s identity, input the new bank details into the payroll software, and run a penny test if required.',
        0.98
    ),
    (
        'HR001',
        'Insurance benefit question: dependent registration',
        'Urgent request: I need clarification on our corporate insurance policy. I have a question about my corporate benefits concerning: dependent registration. My productivity has dropped significantly due to this. How do I proceed with this process?',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR001 for benefits and insurance inquiries (dependent registration). SLA risk is LOW because we currently have 17 hours remaining before the standard SLA breach.',
        'Check the company policy handbook or contact the insurance broker to provide an accurate answer.',
        0.96
    ),
    (
        'HR001',
        'Request for Employment Verification Letter for Visa application',
        'To whom it may concern, I need official documentation from the company. I need a signed and stamped letter confirming my salary, position, and tenure. It is required for a Visa application. The institution has a strict deadline for this document. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR001 for employment certification letters (Visa application). SLA risk is LOW because we currently have 54 hours remaining before the standard SLA breach.',
        'Generate the standard verification template, obtain the HR Director''s signature/stamp, and hand it to the employee.',
        0.93
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: Bonus tax calculation',
        'Hi Helpdesk, I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding Bonus tax calculation. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'HR',
        'medium',
        'low',
        'Assigned to HR001 since the user requires payroll and compensation queries (Bonus tax calculation). SLA Breach risk is LOW; this standard request has a resolution window with 40 hours remaining on the clock.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.96
    ),
    (
        'HR001',
        'Application for statutory Long-term Sick leave',
        'Hi Helpdesk, I need to apply for an extended absence. I need to formally apply for Long-term Sick leave starting next month. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Determined to be a statutory leave processing (Long-term Sick leave) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 31 hours remaining.',
        'Provide the employee with the required government forms and update their status in the HRIS system.',
        0.97
    ),
    (
        'HR001',
        'Update direct deposit details to ACB',
        'To whom it may concern, I have changed my personal banking provider. I have switched my primary bank account to ACB. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle bank account detail updates for payroll (ACB). SLA risk is LOW as the deadline is stable, leaving 69 hours on the operational timeline.',
        'Verify the employee''s identity, input the new bank details into the payroll software, and run a penny test if required.',
        0.97
    ),
    (
        'HR001',
        'Insurance benefit question: dependent registration',
        'Dear Support Team, I need clarification on our corporate insurance policy. I have a question about my corporate benefits concerning: dependent registration. I am planning to use this benefit soon. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle benefits and insurance inquiries (dependent registration). SLA risk is LOW as the deadline is stable, leaving 48 hours on the operational timeline.',
        'Check the company policy handbook or contact the insurance broker to provide an accurate answer.',
        0.94
    ),
    (
        'HR001',
        'Request for Employment Verification Letter for bank loan approval',
        'Urgent request: I need official documentation from the company. I need a signed and stamped letter confirming my salary, position, and tenure. It is required for a bank loan approval. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Assigned to HR001 since the user requires employment certification letters (bank loan approval). SLA Breach risk is LOW; this standard request has a resolution window with 21 hours remaining on the clock.',
        'Generate the standard verification template, obtain the HR Director''s signature/stamp, and hand it to the employee.',
        0.94
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: missing overtime hours',
        'Hello, I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding missing overtime hours. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'medium',
        'low',
        'Classification: Categorized under HR001 for payroll and compensation queries (missing overtime hours). SLA risk is LOW because we currently have 32 hours remaining before the standard SLA breach.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.95
    ),
    (
        'HR001',
        'Application for statutory Long-term Sick leave',
        'Dear Support Team, I need to apply for an extended absence. I need to formally apply for Long-term Sick leave starting next month. I want to ensure all statutory requirements are met in advance. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle statutory leave processing (Long-term Sick leave). SLA risk is LOW as the deadline is stable, leaving 46 hours on the operational timeline.',
        'Provide the employee with the required government forms and update their status in the HRIS system.',
        0.96
    ),
    (
        'HR001',
        'Update direct deposit details to Vietcombank',
        'Dear Support Team, I have changed my personal banking provider. I have switched my primary bank account to Vietcombank. This is a major blocker for my current sprint. Please update my payroll profile so my next salary goes to the new account.',
        'HR',
        'low',
        'low',
        'Determined to be a bank account detail updates for payroll (Vietcombank) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 59 hours remaining.',
        'Verify the employee''s identity, input the new bank details into the payroll software, and run a penny test if required.',
        0.96
    ),
    (
        'HR001',
        'Insurance benefit question: dependent registration',
        'Hi Helpdesk, I need clarification on our corporate insurance policy. I have a question about my corporate benefits concerning: dependent registration. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle benefits and insurance inquiries (dependent registration). SLA risk is LOW as the deadline is stable, leaving 55 hours on the operational timeline.',
        'Check the company policy handbook or contact the insurance broker to provide an accurate answer.',
        0.96
    ),
    (
        'HR001',
        'Request for Employment Verification Letter for bank loan approval',
        'Urgent request: I need official documentation from the company. I need a signed and stamped letter confirming my salary, position, and tenure. It is required for a bank loan approval. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR001 for employment certification letters (bank loan approval). SLA risk is LOW because we currently have 25 hours remaining before the standard SLA breach.',
        'Generate the standard verification template, obtain the HR Director''s signature/stamp, and hand it to the employee.',
        0.96
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: prorated pay for partial month',
        'Dear Support Team, I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding prorated pay for partial month. This is a major blocker for my current sprint. Please advise on the next steps.',
        'HR',
        'medium',
        'low',
        'Allocated to HR001 to handle payroll and compensation queries (prorated pay for partial month). SLA risk is LOW as the deadline is stable, leaving 65 hours on the operational timeline.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.96
    ),
    (
        'HR001',
        'Application for statutory Long-term Sick leave',
        'Hello, I need to apply for an extended absence. I need to formally apply for Long-term Sick leave starting next month. I want to ensure all statutory requirements are met in advance. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle statutory leave processing (Long-term Sick leave). SLA risk is LOW as the deadline is stable, leaving 38 hours on the operational timeline.',
        'Provide the employee with the required government forms and update their status in the HRIS system.',
        0.92
    ),
    (
        'HR001',
        'Update direct deposit details to Standard Chartered',
        'Urgent request: I have changed my personal banking provider. I have switched my primary bank account to Standard Chartered. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Assigned to HR001 since the user requires bank account detail updates for payroll (Standard Chartered). SLA Breach risk is LOW; this standard request has a resolution window with 45 hours remaining on the clock.',
        'Verify the employee''s identity, input the new bank details into the payroll software, and run a penny test if required.',
        0.95
    ),
    (
        'HR001',
        'Insurance benefit question: social insurance book extraction',
        'Hi Helpdesk, I need clarification on our corporate insurance policy. I have a question about my corporate benefits concerning: social insurance book extraction. I am planning to use this benefit soon. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Determined to be a benefits and insurance inquiries (social insurance book extraction) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 21 hours remaining.',
        'Check the company policy handbook or contact the insurance broker to provide an accurate answer.',
        0.92
    ),
    (
        'HR001',
        'Request for Employment Verification Letter for credit card application',
        'Dear Support Team, I need official documentation from the company. I need a signed and stamped letter confirming my salary, position, and tenure. It is required for a credit card application. The institution has a strict deadline for this document. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle employment certification letters (credit card application). SLA risk is LOW as the deadline is stable, leaving 62 hours on the operational timeline.',
        'Generate the standard verification template, obtain the HR Director''s signature/stamp, and hand it to the employee.',
        0.93
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: wrong base salary',
        'Hello, I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding wrong base salary. I cannot complete my pending tasks without this. Can someone from C&B explain the calculation?',
        'HR',
        'medium',
        'low',
        'Assigned to HR001 since the user requires payroll and compensation queries (wrong base salary). SLA Breach risk is LOW; this standard request has a resolution window with 49 hours remaining on the clock.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.93
    ),
    (
        'HR001',
        'Application for statutory Maternity leave',
        'Hi Helpdesk, I need to apply for an extended absence. I need to formally apply for Maternity leave starting next month. I want to ensure all statutory requirements are met in advance. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Assigned to HR001 since the user requires statutory leave processing (Maternity leave). SLA Breach risk is LOW; this standard request has a resolution window with 67 hours remaining on the clock.',
        'Provide the employee with the required government forms and update their status in the HRIS system.',
        0.92
    ),
    (
        'HR001',
        'Update direct deposit details to HSBC',
        'Hello, I have changed my personal banking provider. I have switched my primary bank account to HSBC. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR001 for bank account detail updates for payroll (HSBC). SLA risk is LOW because we currently have 14 hours remaining before the standard SLA breach.',
        'Verify the employee''s identity, input the new bank details into the payroll software, and run a penny test if required.',
        0.94
    ),
    (
        'HR001',
        'Insurance benefit question: social insurance book extraction',
        'Hello, I need clarification on our corporate insurance policy. I have a question about my corporate benefits concerning: social insurance book extraction. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Determined to be a benefits and insurance inquiries (social insurance book extraction) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 19 hours remaining.',
        'Check the company policy handbook or contact the insurance broker to provide an accurate answer.',
        0.93
    ),
    (
        'HR001',
        'Request for Employment Verification Letter for credit card application',
        'To whom it may concern, I need official documentation from the company. I need a signed and stamped letter confirming my salary, position, and tenure. It is required for a credit card application. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Determined to be a employment certification letters (credit card application) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 65 hours remaining.',
        'Generate the standard verification template, obtain the HR Director''s signature/stamp, and hand it to the employee.',
        0.97
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: wrong base salary',
        'Dear Support Team, I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding wrong base salary. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'HR',
        'medium',
        'low',
        'Determined to be a payroll and compensation queries (wrong base salary) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 66 hours remaining.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.94
    ),
    (
        'HR001',
        'Application for statutory Unpaid leave',
        'Urgent request: I need to apply for an extended absence. I need to formally apply for Unpaid leave starting next month. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR001 for statutory leave processing (Unpaid leave). SLA risk is LOW because we currently have 45 hours remaining before the standard SLA breach.',
        'Provide the employee with the required government forms and update their status in the HRIS system.',
        0.95
    ),
    (
        'HR001',
        'Update direct deposit details to Standard Chartered',
        'Hello, I have changed my personal banking provider. I have switched my primary bank account to Standard Chartered. This is severely impacting my daily work. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR001 for bank account detail updates for payroll (Standard Chartered). SLA risk is LOW because we currently have 59 hours remaining before the standard SLA breach.',
        'Verify the employee''s identity, input the new bank details into the payroll software, and run a penny test if required.',
        0.96
    ),
    (
        'HR001',
        'Insurance benefit question: dependent registration',
        'Hello, I need clarification on our corporate insurance policy. I have a question about my corporate benefits concerning: dependent registration. I am planning to use this benefit soon. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle benefits and insurance inquiries (dependent registration). SLA risk is LOW as the deadline is stable, leaving 17 hours on the operational timeline.',
        'Check the company policy handbook or contact the insurance broker to provide an accurate answer.',
        0.97
    ),
    (
        'HR001',
        'Request for Employment Verification Letter for bank loan approval',
        'To whom it may concern, I need official documentation from the company. I need a signed and stamped letter confirming my salary, position, and tenure. It is required for a bank loan approval. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Determined to be a employment certification letters (bank loan approval) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 24 hours remaining.',
        'Generate the standard verification template, obtain the HR Director''s signature/stamp, and hand it to the employee.',
        0.93
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: missing overtime hours',
        'To whom it may concern, I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding missing overtime hours. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'HR',
        'medium',
        'low',
        'Assigned to HR001 since the user requires payroll and compensation queries (missing overtime hours). SLA Breach risk is LOW; this standard request has a resolution window with 13 hours remaining on the clock.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.93
    ),
    (
        'HR001',
        'Application for statutory Bereavement leave',
        'To whom it may concern, I need to apply for an extended absence. I need to formally apply for Bereavement leave starting next month. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Allocated to HR001 to handle statutory leave processing (Bereavement leave). SLA risk is LOW as the deadline is stable, leaving 71 hours on the operational timeline.',
        'Provide the employee with the required government forms and update their status in the HRIS system.',
        0.95
    ),
    (
        'HR001',
        'Update direct deposit details to ACB',
        'Hello, I have changed my personal banking provider. I have switched my primary bank account to ACB. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR001 for bank account detail updates for payroll (ACB). SLA risk is LOW because we currently have 32 hours remaining before the standard SLA breach.',
        'Verify the employee''s identity, input the new bank details into the payroll software, and run a penny test if required.',
        0.95
    ),
    (
        'HR001',
        'Insurance benefit question: social insurance book extraction',
        'Hello, I need clarification on our corporate insurance policy. I have a question about my corporate benefits concerning: social insurance book extraction. This is severely impacting my daily work. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Determined to be a benefits and insurance inquiries (social insurance book extraction) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 39 hours remaining.',
        'Check the company policy handbook or contact the insurance broker to provide an accurate answer.',
        0.95
    ),
    (
        'HR001',
        'Request for Employment Verification Letter for credit card application',
        'Urgent request: I need official documentation from the company. I need a signed and stamped letter confirming my salary, position, and tenure. It is required for a credit card application. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Determined to be a employment certification letters (credit card application) case suitable for HR001. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 43 hours remaining.',
        'Generate the standard verification template, obtain the HR Director''s signature/stamp, and hand it to the employee.',
        0.97
    ),
    (
        'HR001',
        'Payroll discrepancy inquiry: Bonus tax calculation',
        'Hi Helpdesk, I have a question regarding my compensation. I reviewed my latest payslip and noticed an issue regarding Bonus tax calculation. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'HR',
        'medium',
        'low',
        'Assigned to HR001 since the user requires payroll and compensation queries (Bonus tax calculation). SLA Breach risk is LOW; this standard request has a resolution window with 60 hours remaining on the clock.',
        'Review the payroll ledger, verify the calculation formula, and reply to the employee with a breakdown.',
        0.94
    ),
    (
        'HR002',
        'Open new Job Requisition: Senior Backend Dev',
        'Urgent request: Our department is expanding. We have secured budget headcount for a new Senior Backend Dev. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for job requisition creation and recruitment sourcing (Senior Backend Dev). SLA risk is LOW because we currently have 48 hours remaining before the standard SLA breach.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.96
    ),
    (
        'HR002',
        'Interview scheduling: initial HR screening',
        'Hello, We are moving forward with a candidate. The candidate looks promising. We need to schedule a initial HR screening sometime next week. This is severely impacting my daily work. Please coordinate with the hiring managers to schedule this.',
        'HR',
        'low',
        'low',
        'Determined to be a interview coordination and scheduling (initial HR screening) case suitable for HR002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 19 hours remaining.',
        'Check availability on Outlook calendars, send invitations to the panel, and confirm timing with the candidate.',
        0.95
    ),
    (
        'HR002',
        'Training enrollment request: AWS Certification',
        'Urgent request: I am looking to upskill this quarter. My manager suggested I take the AWS Certification course to improve my skills. This aligns with my annual performance goals. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Determined to be a training course enrollment (AWS Certification) case suitable for HR002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 39 hours remaining.',
        'Add the employee to the roster for the upcoming course and send them the pre-reading materials.',
        0.97
    ),
    (
        'HR002',
        'LMS portal issue: course not assigned',
        'Hello, I am having trouble with the learning portal. I am trying to complete my mandatory compliance training but encountering an issue: course not assigned. This is preventing me from meeting the compliance deadline. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle Learning Management System technical support (course not assigned). SLA risk is LOW as the deadline is stable, leaving 62 hours on the operational timeline.',
        'Reset the user''s LMS session, check the course assignment logic, or manually issue the certificate.',
        0.96
    ),
    (
        'HR002',
        'Performance review outcome: Passed probation successfully',
        'To whom it may concern, I have completed the evaluation cycle. I have completed the performance review for my direct report. The outcome is: Passed probation successfully. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires performance and probation review processing (Passed probation successfully). SLA Breach risk is LOW; this standard request has a resolution window with 35 hours remaining on the clock.',
        'Draft the official letter reflecting the outcome, secure signatures, and update the HRIS employee status.',
        0.97
    ),
    (
        'HR002',
        'Open new Job Requisition: Marketing Manager',
        'Hi Helpdesk, Our department is expanding. We have secured budget headcount for a new Marketing Manager. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires job requisition creation and recruitment sourcing (Marketing Manager). SLA Breach risk is LOW; this standard request has a resolution window with 28 hours remaining on the clock.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.98
    ),
    (
        'HR002',
        'Interview scheduling: culture fit interview',
        'Urgent request: We are moving forward with a candidate. The candidate looks promising. We need to schedule a culture fit interview sometime next week. This is a major blocker for my current sprint. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires interview coordination and scheduling (culture fit interview). SLA Breach risk is LOW; this standard request has a resolution window with 19 hours remaining on the clock.',
        'Check availability on Outlook calendars, send invitations to the panel, and confirm timing with the candidate.',
        0.94
    ),
    (
        'HR002',
        'Training enrollment request: Leadership Skills',
        'Urgent request: I am looking to upskill this quarter. My manager suggested I take the Leadership Skills course to improve my skills. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires training course enrollment (Leadership Skills). SLA Breach risk is LOW; this standard request has a resolution window with 47 hours remaining on the clock.',
        'Add the employee to the roster for the upcoming course and send them the pre-reading materials.',
        0.94
    ),
    (
        'HR002',
        'LMS portal issue: training video won''t load',
        'To whom it may concern, I am having trouble with the learning portal. I am trying to complete my mandatory compliance training but encountering an issue: training video won''t load. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for Learning Management System technical support (training video won''t load). SLA risk is LOW because we currently have 68 hours remaining before the standard SLA breach.',
        'Reset the user''s LMS session, check the course assignment logic, or manually issue the certificate.',
        0.93
    ),
    (
        'HR002',
        'Performance review outcome: promotion assessment',
        'To whom it may concern, I have completed the evaluation cycle. I have completed the performance review for my direct report. The outcome is: promotion assessment. We need the official documentation finalized. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Determined to be a performance and probation review processing (promotion assessment) case suitable for HR002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 51 hours remaining.',
        'Draft the official letter reflecting the outcome, secure signatures, and update the HRIS employee status.',
        0.95
    ),
    (
        'HR002',
        'Open new Job Requisition: Marketing Manager',
        'Hi Helpdesk, Our department is expanding. We have secured budget headcount for a new Marketing Manager. This is severely impacting my daily work. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires job requisition creation and recruitment sourcing (Marketing Manager). SLA Breach risk is LOW; this standard request has a resolution window with 35 hours remaining on the clock.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.94
    ),
    (
        'HR002',
        'Interview scheduling: culture fit interview',
        'Hi Helpdesk, We are moving forward with a candidate. The candidate looks promising. We need to schedule a culture fit interview sometime next week. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle interview coordination and scheduling (culture fit interview). SLA risk is LOW as the deadline is stable, leaving 35 hours on the operational timeline.',
        'Check availability on Outlook calendars, send invitations to the panel, and confirm timing with the candidate.',
        0.98
    ),
    (
        'HR002',
        'Training enrollment request: Business English',
        'To whom it may concern, I am looking to upskill this quarter. My manager suggested I take the Business English course to improve my skills. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for training course enrollment (Business English). SLA risk is LOW because we currently have 37 hours remaining before the standard SLA breach.',
        'Add the employee to the roster for the upcoming course and send them the pre-reading materials.',
        0.97
    ),
    (
        'HR002',
        'LMS portal issue: Forgot LMS password',
        'Hi Helpdesk, I am having trouble with the learning portal. I am trying to complete my mandatory compliance training but encountering an issue: Forgot LMS password. This is severely impacting my daily work. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for Learning Management System technical support (Forgot LMS password). SLA risk is LOW because we currently have 36 hours remaining before the standard SLA breach.',
        'Reset the user''s LMS session, check the course assignment logic, or manually issue the certificate.',
        0.94
    ),
    (
        'HR002',
        'Performance review outcome: contract renewal',
        'To whom it may concern, I have completed the evaluation cycle. I have completed the performance review for my direct report. The outcome is: contract renewal. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Determined to be a performance and probation review processing (contract renewal) case suitable for HR002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 60 hours remaining.',
        'Draft the official letter reflecting the outcome, secure signatures, and update the HRIS employee status.',
        0.93
    ),
    (
        'HR002',
        'Open new Job Requisition: Sales Exec',
        'Hello, Our department is expanding. We have secured budget headcount for a new Sales Exec. This is severely impacting my daily work. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for job requisition creation and recruitment sourcing (Sales Exec). SLA risk is LOW because we currently have 66 hours remaining before the standard SLA breach.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.95
    ),
    (
        'HR002',
        'Interview scheduling: culture fit interview',
        'Hi Helpdesk, We are moving forward with a candidate. The candidate looks promising. We need to schedule a culture fit interview sometime next week. I cannot complete my pending tasks without this. Please coordinate with the hiring managers to schedule this.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle interview coordination and scheduling (culture fit interview). SLA risk is LOW as the deadline is stable, leaving 28 hours on the operational timeline.',
        'Check availability on Outlook calendars, send invitations to the panel, and confirm timing with the candidate.',
        0.96
    ),
    (
        'HR002',
        'Training enrollment request: Business English',
        'To whom it may concern, I am looking to upskill this quarter. My manager suggested I take the Business English course to improve my skills. This aligns with my annual performance goals. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle training course enrollment (Business English). SLA risk is LOW as the deadline is stable, leaving 16 hours on the operational timeline.',
        'Add the employee to the roster for the upcoming course and send them the pre-reading materials.',
        0.92
    ),
    (
        'HR002',
        'LMS portal issue: Forgot LMS password',
        'Urgent request: I am having trouble with the learning portal. I am trying to complete my mandatory compliance training but encountering an issue: Forgot LMS password. This is preventing me from meeting the compliance deadline. Please help fix this so I can finish.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires Learning Management System technical support (Forgot LMS password). SLA Breach risk is LOW; this standard request has a resolution window with 33 hours remaining on the clock.',
        'Reset the user''s LMS session, check the course assignment logic, or manually issue the certificate.',
        0.95
    ),
    (
        'HR002',
        'Performance review outcome: extending probation period',
        'Hello, I have completed the evaluation cycle. I have completed the performance review for my direct report. The outcome is: extending probation period. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for performance and probation review processing (extending probation period). SLA risk is LOW because we currently have 52 hours remaining before the standard SLA breach.',
        'Draft the official letter reflecting the outcome, secure signatures, and update the HRIS employee status.',
        0.93
    ),
    (
        'HR002',
        'Open new Job Requisition: Sales Exec',
        'Dear Support Team, Our department is expanding. We have secured budget headcount for a new Sales Exec. My productivity has dropped significantly due to this. Please open the requisition on the ATS and begin sourcing candidates.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle job requisition creation and recruitment sourcing (Sales Exec). SLA risk is LOW as the deadline is stable, leaving 47 hours on the operational timeline.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.97
    ),
    (
        'HR002',
        'Interview scheduling: culture fit interview',
        'Urgent request: We are moving forward with a candidate. The candidate looks promising. We need to schedule a culture fit interview sometime next week. I cannot complete my pending tasks without this. Please coordinate with the hiring managers to schedule this.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires interview coordination and scheduling (culture fit interview). SLA Breach risk is LOW; this standard request has a resolution window with 62 hours remaining on the clock.',
        'Check availability on Outlook calendars, send invitations to the panel, and confirm timing with the candidate.',
        0.95
    ),
    (
        'HR002',
        'Training enrollment request: Agile Scrum workshop',
        'Urgent request: I am looking to upskill this quarter. My manager suggested I take the Agile Scrum workshop course to improve my skills. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires training course enrollment (Agile Scrum workshop). SLA Breach risk is LOW; this standard request has a resolution window with 24 hours remaining on the clock.',
        'Add the employee to the roster for the upcoming course and send them the pre-reading materials.',
        0.95
    ),
    (
        'HR002',
        'LMS portal issue: course not assigned',
        'Hello, I am having trouble with the learning portal. I am trying to complete my mandatory compliance training but encountering an issue: course not assigned. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle Learning Management System technical support (course not assigned). SLA risk is LOW as the deadline is stable, leaving 69 hours on the operational timeline.',
        'Reset the user''s LMS session, check the course assignment logic, or manually issue the certificate.',
        0.98
    ),
    (
        'HR002',
        'Performance review outcome: Passed probation successfully',
        'Hello, I have completed the evaluation cycle. I have completed the performance review for my direct report. The outcome is: Passed probation successfully. We need the official documentation finalized. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for performance and probation review processing (Passed probation successfully). SLA risk is LOW because we currently have 13 hours remaining before the standard SLA breach.',
        'Draft the official letter reflecting the outcome, secure signatures, and update the HRIS employee status.',
        0.95
    ),
    (
        'HR002',
        'Open new Job Requisition: QA Tester',
        'To whom it may concern, Our department is expanding. We have secured budget headcount for a new QA Tester. I cannot complete my pending tasks without this. Please open the requisition on the ATS and begin sourcing candidates.',
        'HR',
        'low',
        'low',
        'Determined to be a job requisition creation and recruitment sourcing (QA Tester) case suitable for HR002. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 28 hours remaining.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.96
    ),
    (
        'HR002',
        'Interview scheduling: Final round with CTO',
        'Hello, We are moving forward with a candidate. The candidate looks promising. We need to schedule a Final round with CTO sometime next week. We want to secure them before they accept competing offers. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires interview coordination and scheduling (Final round with CTO). SLA Breach risk is LOW; this standard request has a resolution window with 20 hours remaining on the clock.',
        'Check availability on Outlook calendars, send invitations to the panel, and confirm timing with the candidate.',
        0.94
    ),
    (
        'HR002',
        'Training enrollment request: Business English',
        'To whom it may concern, I am looking to upskill this quarter. My manager suggested I take the Business English course to improve my skills. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for training course enrollment (Business English). SLA risk is LOW because we currently have 55 hours remaining before the standard SLA breach.',
        'Add the employee to the roster for the upcoming course and send them the pre-reading materials.',
        0.94
    ),
    (
        'HR002',
        'LMS portal issue: course not assigned',
        'Hello, I am having trouble with the learning portal. I am trying to complete my mandatory compliance training but encountering an issue: course not assigned. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for Learning Management System technical support (course not assigned). SLA risk is LOW because we currently have 42 hours remaining before the standard SLA breach.',
        'Reset the user''s LMS session, check the course assignment logic, or manually issue the certificate.',
        0.93
    ),
    (
        'HR002',
        'Performance review outcome: promotion assessment',
        'To whom it may concern, I have completed the evaluation cycle. I have completed the performance review for my direct report. The outcome is: promotion assessment. This is a major blocker for my current sprint. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle performance and probation review processing (promotion assessment). SLA risk is LOW as the deadline is stable, leaving 22 hours on the operational timeline.',
        'Draft the official letter reflecting the outcome, secure signatures, and update the HRIS employee status.',
        0.96
    ),
    (
        'HR002',
        'Open new Job Requisition: Product Owner',
        'To whom it may concern, Our department is expanding. We have secured budget headcount for a new Product Owner. This role is critical for our upcoming Q3 roadmap. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Assigned to HR002 since the user requires job requisition creation and recruitment sourcing (Product Owner). SLA Breach risk is LOW; this standard request has a resolution window with 35 hours remaining on the clock.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.97
    ),
    (
        'HR002',
        'Interview scheduling: Final round with CTO',
        'Hello, We are moving forward with a candidate. The candidate looks promising. We need to schedule a Final round with CTO sometime next week. I cannot complete my pending tasks without this. Please coordinate with the hiring managers to schedule this.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle interview coordination and scheduling (Final round with CTO). SLA risk is LOW as the deadline is stable, leaving 53 hours on the operational timeline.',
        'Check availability on Outlook calendars, send invitations to the panel, and confirm timing with the candidate.',
        0.94
    ),
    (
        'HR002',
        'Training enrollment request: Public Speaking',
        'Dear Support Team, I am looking to upskill this quarter. My manager suggested I take the Public Speaking course to improve my skills. This is a major blocker for my current sprint. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle training course enrollment (Public Speaking). SLA risk is LOW as the deadline is stable, leaving 65 hours on the operational timeline.',
        'Add the employee to the roster for the upcoming course and send them the pre-reading materials.',
        0.93
    ),
    (
        'HR002',
        'LMS portal issue: training video won''t load',
        'Hi Helpdesk, I am having trouble with the learning portal. I am trying to complete my mandatory compliance training but encountering an issue: training video won''t load. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR002 to handle Learning Management System technical support (training video won''t load). SLA risk is LOW as the deadline is stable, leaving 39 hours on the operational timeline.',
        'Reset the user''s LMS session, check the course assignment logic, or manually issue the certificate.',
        0.92
    ),
    (
        'HR002',
        'Performance review outcome: extending probation period',
        'Hello, I have completed the evaluation cycle. I have completed the performance review for my direct report. The outcome is: extending probation period. We need the official documentation finalized. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for performance and probation review processing (extending probation period). SLA risk is LOW because we currently have 23 hours remaining before the standard SLA breach.',
        'Draft the official letter reflecting the outcome, secure signatures, and update the HRIS employee status.',
        0.93
    ),
    (
        'HR002',
        'Open new Job Requisition: Sales Exec',
        'Hi Helpdesk, Our department is expanding. We have secured budget headcount for a new Sales Exec. This role is critical for our upcoming Q3 roadmap. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR002 for job requisition creation and recruitment sourcing (Sales Exec). SLA risk is LOW because we currently have 46 hours remaining before the standard SLA breach.',
        'Draft the job description, post the role on LinkedIn and internal portals, and notify external recruiters.',
        0.94
    ),
    (
        'HR003',
        'Confidential workplace grievance: uncooperative teammate',
        'Dear Support Team, I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a uncooperative teammate. I cannot complete my pending tasks without this. Can we get this resolved by today?',
        'HR',
        'high',
        'low',
        'Forwarded to the HR003 queue because it involves workplace grievance and conflict mediation (uncooperative teammate). SLA BREACH WARNING: Urgency is HIGH with only 131 minutes of buffer time left under the emergency policy.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.96
    ),
    (
        'HR003',
        'Employee wellness inquiry: eye strain from monitors',
        'To whom it may concern, I am looking for support from our wellness program. I am reaching out regarding corporate wellness programs, specifically a eye strain from monitors. This is severely impacting my daily work. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Determined to be a corporate wellness and health inquiries (eye strain from monitors) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 44 hours remaining.',
        'Provide the employee with the wellness program brochure and explain how to claim the relevant subsidy.',
        0.95
    ),
    (
        'HR003',
        'Clarification needed on company policy: WFH policy',
        'Hi Helpdesk, I have a question about the employee handbook. I read the handbook but I am still unclear about the WFH policy. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR003 to handle company policy clarification (WFH policy). SLA risk is LOW as the deadline is stable, leaving 26 hours on the operational timeline.',
        'Reply with a detailed explanation of the policy application and update the internal FAQ if necessary.',
        0.96
    ),
    (
        'HR003',
        'Suggestion for company culture event: Year End Party',
        'Urgent request: I have an idea to improve team engagement. To boost team morale, I suggest we organize a Year End Party. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR003 for culture and team-building event suggestions (Year End Party). SLA risk is LOW because we currently have 49 hours remaining before the standard SLA breach.',
        'Acknowledge the suggestion, present it at the next culture committee meeting, and assess budget feasibility.',
        0.96
    ),
    (
        'HR003',
        'Update personal employee record: updated emergency contact',
        'Dear Support Team, My personal details have recently changed. My personal circumstances have changed: updated emergency contact. My productivity has dropped significantly due to this. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires personal data and status updates (updated emergency contact). SLA Breach risk is LOW; this standard request has a resolution window with 27 hours remaining on the clock.',
        'Verify any required legal documentation (e.g., marriage certificate) and update the central HRIS database.',
        0.97
    ),
    (
        'HR003',
        'Confidential workplace grievance: inappropriate jokes',
        'To whom it may concern, I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a inappropriate jokes. It is severely affecting my mental health and ability to work. Please let me know when someone can look into this.',
        'HR',
        'high',
        'low',
        'Forwarded to the HR003 queue because it involves workplace grievance and conflict mediation (inappropriate jokes). SLA BREACH WARNING: Urgency is HIGH with only 67 minutes of buffer time left under the emergency policy.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.93
    ),
    (
        'HR003',
        'Employee wellness inquiry: Back pain assessment',
        'Hello, I am looking for support from our wellness program. I am reaching out regarding corporate wellness programs, specifically a Back pain assessment. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR003 for corporate wellness and health inquiries (Back pain assessment). SLA risk is LOW because we currently have 66 hours remaining before the standard SLA breach.',
        'Provide the employee with the wellness program brochure and explain how to claim the relevant subsidy.',
        0.94
    ),
    (
        'HR003',
        'Clarification needed on company policy: travel expense reimbursement',
        'Hi Helpdesk, I have a question about the employee handbook. I read the handbook but I am still unclear about the travel expense reimbursement. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Allocated to HR003 to handle company policy clarification (travel expense reimbursement). SLA risk is LOW as the deadline is stable, leaving 54 hours on the operational timeline.',
        'Reply with a detailed explanation of the policy application and update the internal FAQ if necessary.',
        0.97
    ),
    (
        'HR003',
        'Suggestion for company culture event: Charity marathon run',
        'Dear Support Team, I have an idea to improve team engagement. To boost team morale, I suggest we organize a Charity marathon run. This is severely impacting my daily work. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires culture and team-building event suggestions (Charity marathon run). SLA Breach risk is LOW; this standard request has a resolution window with 37 hours remaining on the clock.',
        'Acknowledge the suggestion, present it at the next culture committee meeting, and assess budget feasibility.',
        0.96
    ),
    (
        'HR003',
        'Update personal employee record: updated emergency contact',
        'Hello, My personal details have recently changed. My personal circumstances have changed: updated emergency contact. This is severely impacting my daily work. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR003 to handle personal data and status updates (updated emergency contact). SLA risk is LOW as the deadline is stable, leaving 13 hours on the operational timeline.',
        'Verify any required legal documentation (e.g., marriage certificate) and update the central HRIS database.',
        0.95
    ),
    (
        'HR003',
        'Confidential workplace grievance: inappropriate jokes',
        'Hi Helpdesk, I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a inappropriate jokes. It is severely affecting my mental health and ability to work. Please advise on the next steps.',
        'HR',
        'high',
        'low',
        'Classification: Categorized under HR003 for workplace grievance and conflict mediation (inappropriate jokes). SLA risk is HIGH because we currently have only 39 minutes remaining before the critical SLA breach.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.97
    ),
    (
        'HR003',
        'Employee wellness inquiry: eye strain from monitors',
        'To whom it may concern, I am looking for support from our wellness program. I am reaching out regarding corporate wellness programs, specifically a eye strain from monitors. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Allocated to HR003 to handle corporate wellness and health inquiries (eye strain from monitors). SLA risk is LOW as the deadline is stable, leaving 12 hours on the operational timeline.',
        'Provide the employee with the wellness program brochure and explain how to claim the relevant subsidy.',
        0.96
    ),
    (
        'HR003',
        'Clarification needed on company policy: travel expense reimbursement',
        'Urgent request: I have a question about the employee handbook. I read the handbook but I am still unclear about the travel expense reimbursement. I want to make sure I am fully compliant. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Allocated to HR003 to handle company policy clarification (travel expense reimbursement). SLA risk is LOW as the deadline is stable, leaving 62 hours on the operational timeline.',
        'Reply with a detailed explanation of the policy application and update the internal FAQ if necessary.',
        0.93
    ),
    (
        'HR003',
        'Suggestion for company culture event: Halloween decoration',
        'Hi Helpdesk, I have an idea to improve team engagement. To boost team morale, I suggest we organize a Halloween decoration. This is severely impacting my daily work. I have some ideas for venues and activities if HR is interested.',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires culture and team-building event suggestions (Halloween decoration). SLA Breach risk is LOW; this standard request has a resolution window with 44 hours remaining on the clock.',
        'Acknowledge the suggestion, present it at the next culture committee meeting, and assess budget feasibility.',
        0.98
    ),
    (
        'HR003',
        'Update personal employee record: new home address',
        'Hello, My personal details have recently changed. My personal circumstances have changed: new home address. This is severely impacting my daily work. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires personal data and status updates (new home address). SLA Breach risk is LOW; this standard request has a resolution window with 63 hours remaining on the clock.',
        'Verify any required legal documentation (e.g., marriage certificate) and update the central HRIS database.',
        0.95
    ),
    (
        'HR003',
        'Confidential workplace grievance: inappropriate jokes',
        'Hi Helpdesk, I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a inappropriate jokes. This is severely impacting my daily work. Can we get this resolved by today?',
        'HR',
        'high',
        'low',
        'Forwarded to the HR003 queue because it involves workplace grievance and conflict mediation (inappropriate jokes). SLA BREACH WARNING: Urgency is HIGH with only 47 minutes of buffer time left under the emergency policy.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.98
    ),
    (
        'HR003',
        'Employee wellness inquiry: mental health day request',
        'Urgent request: I am looking for support from our wellness program. I am reaching out regarding corporate wellness programs, specifically a mental health day request. I cannot complete my pending tasks without this. Does the company provide support for this?',
        'HR',
        'low',
        'low',
        'Determined to be a corporate wellness and health inquiries (mental health day request) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 13 hours remaining.',
        'Provide the employee with the wellness program brochure and explain how to claim the relevant subsidy.',
        0.96
    ),
    (
        'HR003',
        'Clarification needed on company policy: WFH policy',
        'Urgent request: I have a question about the employee handbook. I read the handbook but I am still unclear about the WFH policy. My productivity has dropped significantly due to this. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Determined to be a company policy clarification (WFH policy) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 41 hours remaining.',
        'Reply with a detailed explanation of the policy application and update the internal FAQ if necessary.',
        0.94
    ),
    (
        'HR003',
        'Suggestion for company culture event: Team outing',
        'Hi Helpdesk, I have an idea to improve team engagement. To boost team morale, I suggest we organize a Team outing. This is a major blocker for my current sprint. I have some ideas for venues and activities if HR is interested.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR003 for culture and team-building event suggestions (Team outing). SLA risk is LOW because we currently have 17 hours remaining before the standard SLA breach.',
        'Acknowledge the suggestion, present it at the next culture committee meeting, and assess budget feasibility.',
        0.95
    ),
    (
        'HR003',
        'Update personal employee record: updated emergency contact',
        'Dear Support Team, My personal details have recently changed. My personal circumstances have changed: updated emergency contact. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Determined to be a personal data and status updates (updated emergency contact) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 70 hours remaining.',
        'Verify any required legal documentation (e.g., marriage certificate) and update the central HRIS database.',
        0.97
    ),
    (
        'HR003',
        'Confidential workplace grievance: Dispute with manager',
        'Hi Helpdesk, I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a Dispute with manager. It is severely affecting my mental health and ability to work. I would appreciate a prompt resolution.',
        'HR',
        'high',
        'low',
        'Classification: Categorized under HR003 for workplace grievance and conflict mediation (Dispute with manager). SLA risk is HIGH because we currently have only 47 minutes remaining before the critical SLA breach.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.93
    ),
    (
        'HR003',
        'Employee wellness inquiry: Back pain assessment',
        'Hi Helpdesk, I am looking for support from our wellness program. I am reaching out regarding corporate wellness programs, specifically a Back pain assessment. I cannot complete my pending tasks without this. Please let me know when someone can look into this.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR003 for corporate wellness and health inquiries (Back pain assessment). SLA risk is LOW because we currently have 20 hours remaining before the standard SLA breach.',
        'Provide the employee with the wellness program brochure and explain how to claim the relevant subsidy.',
        0.96
    ),
    (
        'HR003',
        'Clarification needed on company policy: WFH policy',
        'Dear Support Team, I have a question about the employee handbook. I read the handbook but I am still unclear about the WFH policy. I cannot complete my pending tasks without this. Can someone provide a specific interpretation?',
        'HR',
        'low',
        'low',
        'Allocated to HR003 to handle company policy clarification (WFH policy). SLA risk is LOW as the deadline is stable, leaving 16 hours on the operational timeline.',
        'Reply with a detailed explanation of the policy application and update the internal FAQ if necessary.',
        0.98
    ),
    (
        'HR003',
        'Suggestion for company culture event: Year End Party',
        'To whom it may concern, I have an idea to improve team engagement. To boost team morale, I suggest we organize a Year End Party. I think many employees would love to participate. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Determined to be a culture and team-building event suggestions (Year End Party) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 66 hours remaining.',
        'Acknowledge the suggestion, present it at the next culture committee meeting, and assess budget feasibility.',
        0.93
    ),
    (
        'HR003',
        'Update personal employee record: new home address',
        'To whom it may concern, My personal details have recently changed. My personal circumstances have changed: new home address. I cannot complete my pending tasks without this. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Determined to be a personal data and status updates (new home address) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 41 hours remaining.',
        'Verify any required legal documentation (e.g., marriage certificate) and update the central HRIS database.',
        0.95
    ),
    (
        'HR003',
        'Confidential workplace grievance: inappropriate jokes',
        'To whom it may concern, I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a inappropriate jokes. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'HR',
        'high',
        'low',
        'Classification: Categorized under HR003 for workplace grievance and conflict mediation (inappropriate jokes). SLA risk is HIGH because we currently have only 97 minutes remaining before the critical SLA breach.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.98
    ),
    (
        'HR003',
        'Employee wellness inquiry: mental health day request',
        'Dear Support Team, I am looking for support from our wellness program. I am reaching out regarding corporate wellness programs, specifically a mental health day request. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires corporate wellness and health inquiries (mental health day request). SLA Breach risk is LOW; this standard request has a resolution window with 44 hours remaining on the clock.',
        'Provide the employee with the wellness program brochure and explain how to claim the relevant subsidy.',
        0.98
    ),
    (
        'HR003',
        'Clarification needed on company policy: remote work from abroad',
        'Urgent request: I have a question about the employee handbook. I read the handbook but I am still unclear about the remote work from abroad. My productivity has dropped significantly due to this. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Determined to be a company policy clarification (remote work from abroad) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 66 hours remaining.',
        'Reply with a detailed explanation of the policy application and update the internal FAQ if necessary.',
        0.98
    ),
    (
        'HR003',
        'Suggestion for company culture event: Year End Party',
        'To whom it may concern, I have an idea to improve team engagement. To boost team morale, I suggest we organize a Year End Party. My productivity has dropped significantly due to this. I have some ideas for venues and activities if HR is interested.',
        'HR',
        'low',
        'low',
        'Classification: Categorized under HR003 for culture and team-building event suggestions (Year End Party). SLA risk is LOW because we currently have 34 hours remaining before the standard SLA breach.',
        'Acknowledge the suggestion, present it at the next culture committee meeting, and assess budget feasibility.',
        0.98
    ),
    (
        'HR003',
        'Update personal employee record: changed legal name',
        'Hi Helpdesk, My personal details have recently changed. My personal circumstances have changed: changed legal name. This is severely impacting my daily work. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Determined to be a personal data and status updates (changed legal name) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 71 hours remaining.',
        'Verify any required legal documentation (e.g., marriage certificate) and update the central HRIS database.',
        0.95
    ),
    (
        'HR003',
        'Confidential workplace grievance: inappropriate jokes',
        'Hi Helpdesk, I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a inappropriate jokes. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'HR',
        'high',
        'low',
        'Forwarded to the HR003 queue because it involves workplace grievance and conflict mediation (inappropriate jokes). SLA BREACH WARNING: Urgency is HIGH with only 125 minutes of buffer time left under the emergency policy.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.95
    ),
    (
        'HR003',
        'Employee wellness inquiry: gym membership subsidy',
        'Urgent request: I am looking for support from our wellness program. I am reaching out regarding corporate wellness programs, specifically a gym membership subsidy. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Determined to be a corporate wellness and health inquiries (gym membership subsidy) case suitable for HR003. SLA risk is LOW: the applicable policy allows a standard turnaround time, leaving 40 hours remaining.',
        'Provide the employee with the wellness program brochure and explain how to claim the relevant subsidy.',
        0.94
    ),
    (
        'HR003',
        'Clarification needed on company policy: travel expense reimbursement',
        'Urgent request: I have a question about the employee handbook. I read the handbook but I am still unclear about the travel expense reimbursement. I cannot complete my pending tasks without this. I would appreciate a prompt resolution.',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires company policy clarification (travel expense reimbursement). SLA Breach risk is LOW; this standard request has a resolution window with 16 hours remaining on the clock.',
        'Reply with a detailed explanation of the policy application and update the internal FAQ if necessary.',
        0.95
    ),
    (
        'HR003',
        'Suggestion for company culture event: Charity marathon run',
        'Hello, I have an idea to improve team engagement. To boost team morale, I suggest we organize a Charity marathon run. This is a major blocker for my current sprint. Can we get this resolved by today?',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires culture and team-building event suggestions (Charity marathon run). SLA Breach risk is LOW; this standard request has a resolution window with 62 hours remaining on the clock.',
        'Acknowledge the suggestion, present it at the next culture committee meeting, and assess budget feasibility.',
        0.95
    ),
    (
        'HR003',
        'Update personal employee record: changed legal name',
        'Dear Support Team, My personal details have recently changed. My personal circumstances have changed: changed legal name. I need to ensure the company has my correct information. Please advise on the next steps.',
        'HR',
        'low',
        'low',
        'Assigned to HR003 since the user requires personal data and status updates (changed legal name). SLA Breach risk is LOW; this standard request has a resolution window with 21 hours remaining on the clock.',
        'Verify any required legal documentation (e.g., marriage certificate) and update the central HRIS database.',
        0.96
    ),
    (
        'HR003',
        'Confidential workplace grievance: inappropriate jokes',
        'Urgent request: I need HR assistance regarding a sensitive matter. I need to speak with an HR business partner confidentially regarding a inappropriate jokes. My productivity has dropped significantly due to this. Please advise on the next steps.',
        'HR',
        'high',
        'low',
        'Classification: Categorized under HR003 for workplace grievance and conflict mediation (inappropriate jokes). SLA risk is HIGH because we currently have only 36 minutes remaining before the critical SLA breach.',
        'Schedule a private, confidential meeting with the employee to document the grievance and plan mediation.',
        0.92
    );

COMMIT;

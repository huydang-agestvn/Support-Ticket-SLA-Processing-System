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
        'Database IAM read-only access request maps to IT003 for compliance auditing. SLA BREACH WARNING: SLA risk is HIGH because production hotfix validation has a tight window and only 25 minutes remain before the SLA window closes.',
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
        'Courier package dispatch via DHL is managed by FC002 mailroom logistics. SLA risk is LOW since there are 6 hours left before the cutoff (20 hours left on the request SLA).',
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
        'Scheduling bulk e-waste disposal for 20 retired desktop towers',
        'Our department completed a hardware refresh last quarter and we now have 20 retired Dell Optiplex desktops sitting in the storage room on Floor 18. They need to be wiped, decommissioned from the asset register, and picked up by the certified e-waste vendor.',
        'IT',
        'low',
        'low',
        'Asset retirement and e-waste disposal logistics fall under IT001 (Hardware Inventory). SLA risk is LOW since this is a scheduled bulk disposal with 5 business days remaining on the vendor pickup window.',
        'Coordinate with the e-waste vendor for pickup scheduling, ensure all hard drives are wiped per data destruction policy, and update the asset management database.',
        0.95
    ),
    (
        'IT001',
        'USB-C docking station not recognizing external displays on new Dell Latitude',
        'I received my new Dell Latitude 5540 last week but the USB-C docking station only outputs to one monitor instead of dual displays. The dock firmware might need an update or the dock model may be incompatible.',
        'IT',
        'medium',
        'low',
        'Docking station compatibility troubleshooting and potential hardware swap is handled by IT001. SLA risk is LOW with 24 hours remaining under the peripheral support SLA.',
        'Test with a known-good dock, update the dock firmware if applicable, or swap for a compatible model from inventory.',
        0.94
    ),
    (
        'IT001',
        'Returning loaner laptop and peripherals after completed business trip',
        'I borrowed a loaner laptop (asset tag LT-2847) along with a travel mouse and charger for my trip to the Ho Chi Minh branch last week. The trip is complete and I would like to return all items to the equipment desk.',
        'IT',
        'low',
        'low',
        'Equipment return and asset check-in after a business trip is managed by IT001. SLA risk is LOW with 72 hours remaining on the standard return SLA.',
        'Inspect the returned items for damage, update the loaner pool availability, and close the original loan ticket.',
        0.96
    ),
    (
        'IT002',
        'Corporate HTTP proxy blocking npm and pip package registries',
        'When I try to run npm install or pip install from my development machine, all requests to registry.npmjs.org and pypi.org are blocked by the corporate proxy with a 403 Forbidden error. Other websites load normally.',
        'IT',
        'medium',
        'low',
        'Proxy configuration and URL allowlisting for developer tools is managed by IT002. SLA risk is LOW with 24 hours remaining on the developer tooling SLA.',
        'Add the package registry domains to the proxy allowlist and verify connectivity from the developer VLAN.',
        0.96
    ),
    (
        'IT002',
        'Internal wiki showing SSL certificate expired warning in all browsers',
        'When accessing our internal Confluence wiki at wiki.internal.company.com, every browser shows a NET::ERR_CERT_DATE_INVALID error. The certificate expired two days ago and nobody renewed it.',
        'IT',
        'medium',
        'low',
        'SSL certificate lifecycle management for internal services falls under IT002. SLA risk is LOW with 12 hours remaining since users can bypass the warning temporarily.',
        'Renew the SSL certificate through the internal CA, install it on the wiki server, and restart the web service.',
        0.97
    ),
    (
        'IT002',
        'Print queue stuck with 47 pending jobs on Floor 19 network printer',
        'The shared HP LaserJet on Floor 19 has a jammed print queue showing 47 pending jobs. The printer itself is online and has paper, but no documents are printing. Multiple teams are affected.',
        'IT',
        'medium',
        'low',
        'Network printer queue management and spooler troubleshooting is handled by IT002. SLA risk is LOW with 8 hours remaining on the shared services SLA.',
        'Clear the print spooler service on the print server, purge the stuck queue, and run a test page to confirm resolution.',
        0.95
    ),
    (
        'IT003',
        'Quarterly rotation of service account passwords for CI/CD pipelines',
        'Per our SOC2 compliance requirements, all service accounts used by Jenkins and GitLab CI runners need their passwords rotated this quarter. There are 12 service accounts listed in the attached spreadsheet.',
        'IT',
        'medium',
        'low',
        'Service account credential rotation for compliance is managed by IT003 security operations. SLA risk is LOW with 5 business days remaining before the compliance audit deadline.',
        'Generate new passwords for each service account, update the credentials in the secret vault, and verify all CI/CD pipelines still authenticate correctly.',
        0.96
    ),
    (
        'IT003',
        'Conditional access policy blocking employee login from new branch office',
        'Our team recently relocated to the new Da Nang branch office but the Azure AD conditional access policy is blocking all logins from this location. The IP range for the new office has not been added to the trusted locations list.',
        'IT',
        'high',
        'high',
        'Conditional access policy updates for new office locations fall under IT003 identity management. SLA risk is HIGH because the entire branch team is locked out, with only 45 minutes remaining on the access restoration SLA.',
        'Add the Da Nang branch IP range to the Azure AD trusted locations policy and verify login works for affected users.',
        0.97
    ),
    (
        'IT003',
        'Renewal of mutual TLS client certificate for payment gateway API',
        'The client certificate used for mutual TLS authentication with our payment gateway partner expires in 3 days. If it lapses, all payment processing will stop. We need a new CSR generated and signed.',
        'IT',
        'high',
        'high',
        'TLS certificate lifecycle for external API integrations is managed by IT003 security. SLA risk is HIGH because payment processing will halt if the certificate expires, with 72 hours remaining.',
        'Generate a new CSR, submit it to the payment gateway partner for signing, install the renewed certificate, and verify the TLS handshake.',
        0.98
    ),
    (
        'FC001',
        'Ant infestation near the Floor 18 pantry food storage area',
        'There is a growing ant trail coming from behind the pantry counter near the sugar and snack cabinets on Floor 18. The ants are getting into opened food containers. We need pest control treatment.',
        'Facilities',
        'medium',
        'low',
        'Pest control coordination and sanitation follow-up is managed by FC001. SLA risk is LOW with 24 hours remaining on the pest management response SLA.',
        'Contact the pest control vendor to schedule baiting treatment, sanitize the affected pantry area, and seal any visible entry points.',
        0.95
    ),
    (
        'FC001',
        'Scheduled fire alarm system testing notification for next Tuesday',
        'Building management has confirmed a full fire alarm system test next Tuesday from 10 AM to 12 PM. Please send a company-wide notification so employees are not startled by the alarms.',
        'Facilities',
        'low',
        'low',
        'Fire safety system coordination and employee notification is handled by FC001. SLA risk is LOW with 5 days remaining before the scheduled test.',
        'Draft and distribute a building-wide email notification with the testing schedule and instructions to remain calm during the alarm.',
        0.97
    ),
    (
        'FC001',
        'Two employees stuck in elevator B between Floor 17 and Floor 18',
        'The elevator B stopped between floors and two employees are trapped inside. They pressed the emergency button and communicated via the intercom. The elevator display shows an E04 error code.',
        'Facilities',
        'high',
        'high',
        'Elevator emergency response and vendor coordination is handled by FC001. SLA risk is HIGH because trapped personnel require immediate rescue, with only 15 minutes remaining on the emergency response SLA.',
        'Contact the elevator maintenance vendor for emergency dispatch, keep communication open with the trapped employees via intercom, and notify building security.',
        0.99
    ),
    (
        'FC002',
        'Coordinating desk relocation for 8 employees moving from Floor 18 to Floor 19',
        'The analytics team of 8 people is being relocated from Floor 18 East to Floor 19 West next Monday. We need help moving desks, chairs, personal cabinets, and ensuring network ports are active at the new location.',
        'Facilities',
        'medium',
        'low',
        'Internal employee relocation and desk move logistics are managed by FC002. SLA risk is LOW with 4 business days remaining before the relocation date.',
        'Schedule movers for Monday morning, coordinate with IT for network port activation, and send floor maps to the relocating team.',
        0.95
    ),
    (
        'FC002',
        'After-hours building access request for weekend production deployment',
        'Our DevOps team needs building access this Saturday from 8 PM to 2 AM for a critical production database migration. There will be 4 team members needing entry. Security guard and air conditioning should be arranged.',
        'Facilities',
        'medium',
        'low',
        'After-hours access coordination and security arrangements fall under FC002. SLA risk is LOW with 3 days remaining before the weekend access date.',
        'Register the 4 employees for after-hours access, notify building security, and arrange HVAC scheduling for the engineering floor.',
        0.96
    ),
    (
        'FC002',
        'Escorting external fire safety inspector through office floors',
        'The annual fire safety inspection is scheduled for this Thursday. An external inspector from the municipal fire department will visit Floors 17 through 19. We need a facilities escort and access to all restricted areas.',
        'Facilities',
        'medium',
        'low',
        'External inspector escort and compliance inspection support is managed by FC002. SLA risk is LOW with 2 days remaining before the inspection.',
        'Assign a facilities coordinator to escort the inspector, prepare all fire equipment logs, and ensure access to locked utility rooms.',
        0.97
    ),
    (
        'FC003',
        'Placement of recycling bins in the newly renovated open-plan workspace',
        'The renovated open-plan area on Floor 19 does not have any recycling bins. Employees are putting recyclable materials in regular trash. We need paper, plastic, and general waste bins placed at key locations.',
        'Facilities',
        'low',
        'low',
        'Recycling bin procurement and placement is coordinated by FC003 office supplies. SLA risk is LOW with 5 days remaining on the facilities setup timeline.',
        'Order three-compartment recycling stations and place them at the designated spots on the floor plan.',
        0.94
    ),
    (
        'FC003',
        'Shared microwave in Floor 18 pantry emitting burning smell and sparking',
        'The communal microwave in the Floor 18 East pantry started sparking and emitting a burning plastic smell when someone tried to heat their lunch. We unplugged it immediately. It needs to be replaced or inspected.',
        'Facilities',
        'high',
        'high',
        'Kitchen appliance safety and replacement is managed by FC003. SLA risk is HIGH because the appliance poses a fire hazard and the pantry is heavily used, with only 30 minutes remaining on the safety response SLA.',
        'Remove the defective microwave from service, place an out-of-order sign, and order a replacement unit from the approved vendor.',
        0.97
    ),
    (
        'FC003',
        'Vending machine on Floor 19 dispensing incorrect snack selections',
        'The snack vending machine near the Floor 19 break area has been dispensing the wrong items for the past two days. When you select row B3 (granola bars), it dispenses row C3 (chips) instead. Several people have lost money.',
        'Facilities',
        'low',
        'low',
        'Vending machine maintenance coordination is handled by FC003. SLA risk is LOW with 48 hours remaining on the vendor service request SLA.',
        'Contact the vending machine service vendor to recalibrate the dispensing mechanism and issue refund vouchers to affected employees.',
        0.93
    ),
    (
        'HR001',
        'Employee referral bonus not reflected in this month payslip',
        'I referred a candidate (Employee ID 7723) who was successfully hired 3 months ago and passed probation last month. According to policy, I should receive the referral bonus this pay cycle, but it is not on my payslip.',
        'HR',
        'medium',
        'low',
        'Referral bonus tracking and payroll inclusion is managed by HR001 C&B. SLA risk is LOW with 48 hours remaining on the payroll inquiry SLA.',
        'Verify the referral record in the recruitment system, confirm probation completion date, and issue the bonus in the next supplementary payroll run.',
        0.95
    ),
    (
        'HR001',
        'Scheduling annual corporate health check-up for engineering department',
        'Hi HR, our engineering department of 45 people would like to schedule the annual health check-up with the company clinic partner. Could you please share available dates and the list of included tests?',
        'HR',
        'low',
        'low',
        'Corporate health check-up scheduling and clinic coordination is handled by HR001 benefits. SLA risk is LOW with 10 business days remaining on the wellness program timeline.',
        'Contact the partner clinic to reserve slots for 45 employees, share the test package details, and distribute the registration form.',
        0.96
    ),
    (
        'HR001',
        'Unable to download payslip PDF from the employee self-service portal',
        'When I click the download button for my June payslip on the HR self-service portal, I get a generic server error and the PDF does not generate. I have tried multiple browsers and cleared my cache.',
        'HR',
        'low',
        'low',
        'Payslip portal technical issues affecting individual employees are escalated through HR001. SLA risk is LOW with 72 hours remaining on the portal support SLA.',
        'Escalate the portal bug to the HRIS vendor, manually generate and email the payslip PDF to the employee as a temporary workaround.',
        0.94
    ),
    (
        'HR002',
        'Assigning a senior mentor for a newly promoted engineering team lead',
        'Our junior developer was recently promoted to team lead and would benefit from having a senior engineering mentor to guide them through the leadership transition. Can HR help match them with an experienced mentor?',
        'HR',
        'low',
        'low',
        'Mentor-mentee matching and leadership development programs are coordinated by HR002 L&D. SLA risk is LOW with 14 days remaining on the mentorship program onboarding timeline.',
        'Review the mentor pool, match based on department and seniority, and schedule an introductory meeting between the mentor and mentee.',
        0.95
    ),
    (
        'HR002',
        'Job shadow request to observe the product management team for one week',
        'I am a backend developer interested in transitioning to product management. I would like to apply for the job shadow program to observe the PM team for one week next month. My manager has approved.',
        'HR',
        'low',
        'low',
        'Job shadow program applications and cross-functional observation requests are managed by HR002. SLA risk is LOW with 3 weeks remaining before the requested shadow period.',
        'Verify manager approval, coordinate with the PM team lead for scheduling, and register the employee in the job shadow program tracker.',
        0.96
    ),
    (
        'HR002',
        'Cross-department rotation application for Q4 development cycle',
        'I would like to apply for the quarterly cross-department rotation program. I am currently in the QA team and would like to rotate into the DevOps team for Q4 to broaden my technical skills.',
        'HR',
        'low',
        'low',
        'Cross-department rotation program enrollment is processed by HR002 talent development. SLA risk is LOW with 6 weeks remaining before the Q4 rotation starts.',
        'Review the application against program criteria, confirm availability with the DevOps team manager, and update the rotation roster.',
        0.94
    ),
    (
        'HR003',
        'Setting up an anonymous feedback channel for the quarterly employee pulse survey',
        'We would like to implement an anonymous digital feedback channel where employees can share honest opinions about work culture without fear of identification. Can HR set this up before the Q3 pulse survey?',
        'HR',
        'low',
        'low',
        'Anonymous feedback tool setup and employee engagement initiatives are managed by HR003 culture team. SLA risk is LOW with 3 weeks remaining before the Q3 survey launch.',
        'Evaluate anonymous survey tools, configure the platform with appropriate question categories, and announce the feedback channel to all employees.',
        0.95
    ),
    (
        'HR003',
        'Inquiry about parental support group for new and expecting parents',
        'I recently became a new parent and I heard some companies offer support groups or resource sharing communities for employees who are new parents. Does our company have anything like this or can we start one?',
        'HR',
        'low',
        'low',
        'Employee resource group creation and parental support programs fall under HR003 employee relations. SLA risk is LOW with 14 days remaining on the community program evaluation timeline.',
        'Research existing parental support ERG models, gauge employee interest through a short survey, and propose a charter to the HR director.',
        0.93
    ),
    (
        'HR003',
        'Work anniversary recognition and milestone gift for 10-year employee',
        'Our colleague in the finance department is celebrating their 10th work anniversary next Friday. We would like HR to arrange the standard milestone recognition gift and a small celebration during the team meeting.',
        'HR',
        'low',
        'low',
        'Work anniversary recognition and milestone celebrations are coordinated by HR003 culture committee. SLA risk is LOW with 5 business days remaining before the anniversary date.',
        'Prepare the 10-year milestone certificate and gift package, coordinate with the team manager for the celebration timing, and update the recognition log.',
        0.97
    );

COMMIT;

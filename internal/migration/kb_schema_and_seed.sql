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
    ('IT001', 'monitor not working', 'keyword', 'high'),
    ('IT001', 'laptop charger broken', 'keyword', 'high'),
    ('IT001', 'damaged screen', 'keyword', 'high'),
    ('IT001', 'new laptop request', 'keyword', 'medium'),
    ('IT001', 'broken keyboard', 'keyword', 'medium'),
    ('IT001', 'broken mouse', 'keyword', 'medium'),
    ('IT001', 'headset replacement', 'keyword', 'medium'),
    ('IT001', 'temporary equipment loan', 'keyword', 'low'),
    ('IT001', 'hardware warranty', 'keyword', 'low'),
    ('IT001', 'request laptop stand', 'keyword', 'low');

-- IT002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT002', 'no internet connection', 'keyword', 'high'),
    ('IT002', 'network down', 'keyword', 'high'),
    ('IT002', 'vpn not connecting', 'keyword', 'high'),
    ('IT002', 'cannot connect to vpn', 'keyword', 'high'),
    ('IT002', 'wifi not working', 'keyword', 'high'),
    ('IT002', 'software installation error', 'keyword', 'medium'),
    ('IT002', 'os installation', 'keyword', 'medium'),
    ('IT002', 'shared drive access', 'keyword', 'medium'),
    ('IT002', 'slow internet', 'keyword', 'low'),
    ('IT002', 'software trial request', 'keyword', 'low');

-- IT003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('IT003', 'suspected phishing', 'keyword', 'high'),
    ('IT003', 'malware alert', 'keyword', 'high'),
    ('IT003', 'account locked', 'keyword', 'high'),
    ('IT003', 'reset password', 'keyword', 'high'),
    ('IT003', 'mfa issue', 'keyword', 'medium'),
    ('IT003', 'two factor authentication', 'keyword', 'medium'),
    ('IT003', 'active directory', 'keyword', 'medium'),
    ('IT003', 'suspicious email', 'keyword', 'medium'),
    ('IT003', 'forgot password', 'keyword', 'medium'),
    ('IT003', 'request guest wifi access', 'keyword', 'low');

-- FC001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC001', 'power outage', 'keyword', 'high'),
    ('FC001', 'water leak', 'keyword', 'high'),
    ('FC001', 'air conditioning broken', 'keyword', 'high'),
    ('FC001', 'fire alarm issue', 'keyword', 'high'),
    ('FC001', 'ac not cooling', 'keyword', 'medium'),
    ('FC001', 'broken desk', 'keyword', 'medium'),
    ('FC001', 'light not working', 'keyword', 'medium'),
    ('FC001', 'broken chair', 'keyword', 'medium'),
    ('FC001', 'cleaning request', 'keyword', 'low'),
    ('FC001', 'trash bin full', 'keyword', 'low');

-- FC002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC002', 'lost badge', 'keyword', 'high'),
    ('FC002', 'replace employee badge', 'keyword', 'high'),
    ('FC002', 'send courier', 'keyword', 'medium'),
    ('FC002', 'book company car', 'keyword', 'medium'),
    ('FC002', 'receive urgent package', 'keyword', 'medium'),
    ('FC002', 'book meeting room', 'keyword', 'low'),
    ('FC002', 'reserve event space', 'keyword', 'low');

-- FC003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('FC003', 'need printer paper', 'keyword', 'medium'),
    ('FC003', 'out of pens', 'keyword', 'medium'),
    ('FC003', 'printer ink request', 'keyword', 'medium'),
    ('FC003', 'request office supplies', 'keyword', 'low'),
    ('FC003', 'no coffee', 'keyword', 'low'),
    ('FC003', 'pantry restock', 'keyword', 'low'),
    ('FC003', 'request new notebook', 'keyword', 'low');

-- HR001
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR001', 'payroll error', 'keyword', 'high'),
    ('HR001', 'wrong salary', 'keyword', 'high'),
    ('HR001', 'maternity leave benefit', 'keyword', 'high'),
    ('HR001', 'social insurance', 'keyword', 'medium'),
    ('HR001', 'bhxh', 'keyword', 'medium'),
    ('HR001', 'health insurance pvi', 'keyword', 'medium'),
    ('HR001', 'bao viet insurance', 'keyword', 'medium'),
    ('HR001', 'personal income tax', 'keyword', 'medium'),
    ('HR001', 'dependent declaration', 'keyword', 'low'),
    ('HR001', 'request payslip copy', 'keyword', 'low');

-- HR002
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR002', 'prepare desk for new hire', 'keyword', 'high'),
    ('HR002', 'recruitment request', 'keyword', 'medium'),
    ('HR002', 'new employee orientation', 'keyword', 'medium'),
    ('HR002', 'register training course', 'keyword', 'low'),
    ('HR002', 'request training budget', 'keyword', 'low'),
    ('HR002', 'external course registration', 'keyword', 'low');

-- HR003
INSERT INTO rule_patterns (sub_department_code, pattern, pattern_type, priority) VALUES
    ('HR003', 'harassment report', 'keyword', 'high'),
    ('HR003', 'workplace conflict', 'keyword', 'high'),
    ('HR003', 'resignation procedure', 'keyword', 'medium'),
    ('HR003', 'offboarding process', 'keyword', 'medium'),
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
        'FC001',
        'Severe water leak coming from the ceiling in Floor 18 boardroom',
        'During the heavy rainstorm, water started gushing out from the ceiling panels in the Floor 18 boardroom. It is dripping directly onto the conference table and video equipment. We need a plumber and buckets immediately.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves severe water leak coming from the ceiling in floor 18 boardroom. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Shut off the water valve for the affected ceiling section, move all electronics, and dispatch the building maintenance technician.',
        0.98
    ),
    (
        'FC001',
        'Air conditioning system not cooling in Floor 19 open office zone',
        'The temperature in the engineering zone on Floor 19 is currently 29 degrees Celsius. The AC vents are blowing room-temperature air, and several developers are complaining about the heat. Can you check the chillers?',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves air conditioning system not cooling in floor 19 open office zone. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Check the HVAC control panel settings, inspect the air filter for blockages, and contact the AC technician if chillers are offline.',
        0.96
    ),
    (
        'FC001',
        'Broken automatic glass door sensor at Floor 19 main entrance',
        'The sensor on the automatic sliding door at the Floor 19 main entrance is not responding when someone approaches. The door remains closed, forcing employees to manually pry it open, which might damage the mechanism.',
        'Facilities',
        'medium',
        'medium',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves broken automatic glass door sensor at floor 19 main entrance. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Inspect the door sensor wiring, clean the optical lens, and reset the door controller board.',
        0.95
    ),
    (
        'FC001',
        'Exposed electric wire on Floor 18 floor outlet box',
        'The plastic cover on one of the floor power outlets in the developer row has broken off. There are exposed electrical wires coming from the socket box. Someone could step on it and get shocked. Please send an electrician.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves exposed electric wire on floor 18 floor outlet box. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Isolate the power circuit breaker for that outlet row immediately, and dispatch an electrician to repair the socket.',
        0.97
    ),
    (
        'FC001',
        'Rattling noise from ceiling AC unit in Meeting Room 3A',
        'There is a very loud, metallic rattling noise coming from the ceiling air conditioning unit in Meeting Room 3A. It is so loud that we cannot hear each other speak during calls. The AC still blows cold air, but it sounds like a loose blade.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves rattling noise from ceiling ac unit in meeting room 3a. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Open the AC casing in Room 3A, inspect the fan blower wheel and motor mounting screws, and tighten any loose parts.',
        0.94
    ),
    (
        'FC001',
        'Flickering lights in Floor 19 corridor causing eye strain',
        'Two of the fluorescent light panels in the Floor 19 corridor are flickering rapidly. It is very disorienting and is causing headaches for employees sitting nearby. They need to be replaced with new LED tubes.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves flickering lights in floor 19 corridor causing eye strain. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Replace the flickering fluorescent bulbs with new tubes, and check the light ballast if the flickering persists.',
        0.93
    ),
    (
        'FC001',
        'Blocked washbasin drain in Floor 18 male restroom',
        'The middle washbasin in the Floor 18 restroom is completely blocked. The water does not drain at all and it is starting to smell. We have put an out-of-order note on it, but we need maintenance to clear the clog.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves blocked washbasin drain in floor 18 male restroom. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Use a plunger or plumbing snake to clear the blockage in the restroom sink pipe, and inspect the P-trap.',
        0.95
    ),
    (
        'FC001',
        'Broken desk adjustment lever on height-adjustable workspace',
        'The hand crank lever on my height-adjustable desk has snapped off. The desk is currently locked in a very low position, making it impossible for me to work comfortably. I need someone to fix it or replace the mechanism.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves broken desk adjustment lever on height-adjustable workspace. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Replace the broken crank arm or adjust the desk manually to a comfortable height while waiting for parts.',
        0.91
    ),
    (
        'FC001',
        'Coffee stain cleaning request in Floor 18 hallway carpet',
        'Someone spilled a large cup of black coffee in the main corridor on Floor 18 right outside the meeting rooms. It has created a dark stain on the gray carpet. We need janitorial staff to deep clean it before it dries.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves coffee stain cleaning request in floor 18 hallway carpet. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Dispatch the janitorial team with a carpet extractor machine to clean the coffee stain.',
        0.96
    ),
    (
        'FC001',
        'Pest control coordination for fruit flies in pantry sink',
        'We are noticing a swarm of fruit flies hovering around the organic waste bins and sink drain in the Floor 18 pantry. The bins are emptied daily, but the flies seem to be breeding in the drain. We need sanitation treatment.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves pest control coordination for fruit flies in pantry sink. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Flush the pantry drain with hot water and enzymatic cleaner, and place fruit fly traps around the bins.',
        0.94
    ),
    (
        'FC001',
        'Window blind cord snapped in marketing workspace',
        'The cord used to adjust the roller blinds on the window in the marketing section has snapped. The blinds are stuck in the down position, blocking all natural light from that corner of the office. We need the cord replaced.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves window blind cord snapped in marketing workspace. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Replace the snapped blind cord or install a new roller mechanism on the window frame.',
        0.92
    ),
    (
        'FC001',
        'Emergency exit sign not illuminated on Floor 19 East wing exit',
        'The green backlight on the emergency exit sign at the Floor 19 East fire door is out. The sign is completely dark, which violates local safety regulations and would make it hard to see during an evacuation.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves emergency exit sign not illuminated on floor 19 east wing exit. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Open the exit sign casing, replace the backup battery and LED bulbs, and verify its emergency illumination status.',
        0.95
    ),
    (
        'FC001',
        'Fire extinguisher annual inspection date expired in hallway',
        'The fire extinguisher mounted next to the Floor 18 server room door shows an inspection tag that expired last month. We need facilities to verify pressure levels and sign off on a new inspection tag.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves fire extinguisher annual inspection date expired in hallway. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Check the fire extinguisher pressure gauge, sign the inspection record, or swap it for a certified unit.',
        0.94
    ),
    (
        'FC001',
        'Loose handrail on the central office stairwell between Floor 17 and 18',
        'The wooden handrail on the central stairwell is loose at the middle landing. When you hold it, the rail wobbles and feels like it might detatch from the wall bracket. This is a safety hazard for people using the stairs.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves loose handrail on the central office stairwell between floor 17 and 18. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Send a maintenance worker to tighten the wall brackets and secure the handrail anchors.',
        0.93
    ),
    (
        'FC001',
        'Pothole repair request for office parking garage entrance lane',
        'A deep pothole has formed in the asphalt right at the entrance gate of our parking garage. Cars have to swerve to avoid it, which is causing traffic backups during morning arrival. It needs to be filled with cold patch asphalt.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves pothole repair request for office parking garage entrance lane. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Fill the pothole with rapid-setting asphalt compound, compact it, and verify smooth vehicle transition.',
        0.91
    ),
    (
        'FC001',
        'Blocked drainage gutter on office rooftop terrace causing pooling',
        'During yesterday''s rain, the drainage grate on the Floor 19 rooftop terrace got blocked by leaves. There is now a large pool of standing water that is starting to seep under the terrace door frame into the hallway.',
        'Facilities',
        'medium',
        'medium',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves blocked drainage gutter on office rooftop terrace causing pooling. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Clear all leaves and debris from the terrace drainage grate, and check the downspout for internal blockages.',
        0.95
    ),
    (
        'FC001',
        'Exhaust fan not working in Floor 19 ladies restroom',
        'The ventilation exhaust fan in the Floor 19 ladies restroom is not turning on. The restroom has become very humid and stuffy, and the air is stale. We need someone to check the fan switch or fan motor.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves exhaust fan not working in floor 19 ladies restroom. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Test the electrical switch for the fan, check the ventilation fan fuse, and replace the motor unit if burnt out.',
        0.93
    ),
    (
        'FC001',
        'Server room precision AC unit triggering high temperature alarm',
        'The secondary precision AC unit in the Floor 18 server room has shut down, showing a ''High pressure limit'' alarm. The server rack temperature has reached 25 degrees and is climbing. We need emergency HVAC support.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves server room precision ac unit triggering high temperature alarm. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Deploy backup portable AC units to the server room, open server room ventilation vents, and dispatch the HVAC contractor immediately.',
        0.98
    ),
    (
        'FC001',
        'Scheduled backup generator testing notification and load check',
        'Building management has scheduled the quarterly load testing of our backup diesel generator this Saturday from 1 PM to 4 PM. We need facilities to monitor the automatic transfer switch (ATS) changeover.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves scheduled backup generator testing notification and load check. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Coordinate with building security, check diesel fuel levels, and log the ATS transfer response during the test.',
        0.95
    ),
    (
        'FC001',
        'Rattling ceiling projector mount in Boardroom A',
        'The ceiling mounting bracket for the projector in Boardroom A is loose. Every time the AC turns on, the vibration causes the projector to shake, making the projected screen blurry and dizzying. It needs to be tightened.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves rattling ceiling projector mount in boardroom a. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Access the ceiling bracket using an A-frame ladder, tighten the mounting bolts, and align the projector.',
        0.92
    ),
    (
        'FC001',
        'Requesting acoustic soundproofing panel installation in phone booth 4',
        'The phone booth room 4 has a strong echo. During calls, the acoustic reflection makes it hard for participants to hear clearly. We request installation of some foam soundproofing panels on the walls.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves requesting acoustic soundproofing panel installation in phone booth 4. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Order and install adhesive acoustic foam panels on the interior walls of the phone booth.',
        0.91
    ),
    (
        'FC001',
        'Standing desk motor jammed and won''t go down',
        'The motorized standing desk in my cubicle is stuck at its maximum height. Pressing the control panel buttons just makes a clicking sound but the desk doesn''t move. I cannot work standing up all day.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves standing desk motor jammed and won''t go down. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Reset the desk controller unit or replace the jammed lift motor in the desk leg.',
        0.93
    ),
    (
        'FC001',
        'Partition wall removal request for team collaboration layout',
        'Our product team needs to expand our layout. We request the removal of the non-load-bearing drywall partition between cubicles 184 and 185 to create a shared whiteboard collaboration zone next week.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves partition wall removal request for team collaboration layout. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Assess the partition wall wall structure for wiring, get landlord approval, and schedule drywall removal for the weekend.',
        0.9
    ),
    (
        'FC001',
        'Motion sensor light switch not triggering in Floor 18 archive closet',
        'The motion sensor light in the archive storage closet is broken. It does not trigger when you walk in, leaving the room completely dark. I have to use my phone flashlight to search for files.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves motion sensor light switch not triggering in floor 18 archive closet. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Replace the defective PIR motion sensor switch wall unit in the closet.',
        0.93
    ),
    (
        'FC001',
        'Testing emergency shower station in chemical testing lab',
        'The chemical safety shower in the testing lab is overdue for its quarterly safety inspection. We need facilities to flush the line, check water pressure, and update the compliance tag on the wall.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves testing emergency shower station in chemical testing lab. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Perform a test activation of the safety shower, log the flow rate, and update the inspection tag.',
        0.94
    ),
    (
        'FC001',
        'Loading dock roller shutter door stuck half-open',
        'The motorized rolling door at the warehouse loading dock is jammed at half-height. A delivery truck is arriving in 30 minutes, and they cannot unload large pallets through the narrow gap. The motor is unresponsive.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves loading dock roller shutter door stuck half-open. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Dispatch maintenance with the manual override chain to raise the rolling door, and call the gate repair vendor.',
        0.97
    ),
    (
        'FC001',
        'Minor flooding in basement storage room after pipe leak',
        'We noticed a puddle of water growing in the corner of basement storage room B2. It seems one of the low-pressure plumbing pipes is dripping from the joint. We need this fixed before our stored archives get wet.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves minor flooding in basement storage room after pipe leak. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Tighten the leaking pipe joint, wrap with sealing tape, and extract the water from the floor.',
        0.95
    ),
    (
        'FC001',
        'Bird nest blocking building ventilation exhaust grill',
        'There is a bird nest built inside the external exhaust grill of our office ventilation duct on the Floor 18 balcony. It is restricting air flow and causing a stale odor to recirculate in the lobby.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves bird nest blocking building ventilation exhaust grill. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Safely relocate the nest if empty, clean the exhaust grill, and install a mesh wire guard to prevent future nesting.',
        0.92
    ),
    (
        'FC001',
        'Faded paint on disabled parking spots in visitor garage',
        'The blue wheelchair markings on the visitor parking bay floor have faded completely, making it hard to identify them. Security had to ask several non-disabled drivers to relocate their cars. They need repainting.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves faded paint on disabled parking spots in visitor garage. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Schedule parking bay line repainting using high-durability floor marking paint.',
        0.88
    ),
    (
        'FC001',
        'Smoke detector low battery chirping sound in boardroom',
        'The smoke detector in the main boardroom is making a loud, intermittent chirping beep every few minutes. It is very annoying during meetings. Can you send someone with a ladder to swap the battery?',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves smoke detector low battery chirping sound in boardroom. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Use a ladder to remove the smoke detector, replace the 9V backup battery, and test the alarm button.',
        0.94
    ),
    (
        'FC001',
        'Requesting safety adjustment of office security cameras in lobby',
        'The camera near the lobby elevator has turned slightly and is now pointing at the wall rather than the elevator doors. We need maintenance to reposition it and tighten the mount.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves requesting safety adjustment of office security cameras in lobby. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Reposition the security camera bracket, verify the video feed angle, and lock the mounting nut.',
        0.93
    ),
    (
        'FC001',
        'Water fountain filter replacement overdue in corridor 18',
        'The indicator light on the water fountain near the elevator bank shows red, indicating the carbon filter needs replacement. The water flow is also very slow and has a slight metallic taste.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves water fountain filter replacement overdue in corridor 18. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Replace the carbon filter cartridge in the water fountain and flush the line for 5 minutes.',
        0.95
    ),
    (
        'FC001',
        'Damaged drywall from chair bumps in meeting room 4C',
        'The backing chairs in meeting room 4C have scraped against the drywall, creating several large dents and holes in the plaster. We need the drywall patched, sanded, and repainted to restore the room appearance.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC001 (Workplace & Utilities) floor 18, as the issue involves damaged drywall from chair bumps in meeting room 4c. The policy fit is appropriate since this team handles physical office facility issues, electricity, water, and AC (excluding office supplies, badges, or transportation).',
        'Patch the drywall dents with spackle, sand it flat, and paint with matching interior wall paint.',
        0.92
    ),
    (
        'FC002',
        'Corporate taxi booking request for late-night system deployment',
        'Our engineering team has a scheduled production deployment this Friday that will run until 2 AM. I need to book corporate taxis for 5 developers to ensure they get home safely after public transport closes.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves corporate taxi booking request for late-night system deployment. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Contact the taxi provider, book 5 rides for the specified time, and send the vouchers to the engineering lead.',
        0.96
    ),
    (
        'FC002',
        'Visitor parking reservation request for corporate client audit team',
        'A team of 4 external financial auditors will be visiting our office daily next week. I need to reserve 2 visitor parking spaces in the basement garage from Monday to Friday and register their license plates.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves visitor parking reservation request for corporate client audit team. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Reserve the 2 basement parking bays in the calendar, log the vehicle details in the security gate database, and notify the host.',
        0.94
    ),
    (
        'FC002',
        'Lost employee ID access badge replacement request',
        'I misplaced my physical employee ID badge somewhere on my commute yesterday. I need security to deactivate my old badge immediately to prevent unauthorized entry, and print a replacement badge for me.',
        'Facilities',
        'high',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves lost employee id access badge replacement request. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Deactivate the lost badge in the security control system and print a new access card for the employee.',
        0.97
    ),
    (
        'FC002',
        'Tracking missing registered mail package from tax authority',
        'The tax department sent a registered letter last Wednesday according to their portal, but we haven''t received it in the mailroom. Can the reception team check the incoming mail log to see if it was signed for?',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves tracking missing registered mail package from tax authority. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Search the mail receipt database for the tracking number, verify who signed for the letter, and locate it in the sorting room.',
        0.95
    ),
    (
        'FC002',
        'Scheduling corporate vehicle for regional branch sales visit',
        'I need to book the corporate SUV for a day trip to our regional office next Wednesday. I will be traveling with 3 sales team members and need the vehicle from 7 AM to 6 PM. My manager has approved the booking.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves scheduling corporate vehicle for regional branch sales visit. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Check corporate vehicle availability for Wednesday, assign the SUV to the salesperson, and issue the keys and logbook.',
        0.96
    ),
    (
        'FC002',
        'Access badge authorization request for temporary cleaning staff',
        'We have 3 new cleaning staff starting next Monday under our vendor contract. We need to issue temporary access badges that allow entry to the main office floors during their shift hours (6 PM to 10 PM).',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves access badge authorization request for temporary cleaning staff. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Verify contract details, print the temporary badges, and program the restricted time access profile.',
        0.95
    ),
    (
        'FC002',
        'Reserving Floor 19 main training room for multi-day workshop',
        'We need to reserve the main training room on Floor 19 for our annual engineering workshop from September 10th to 12th. We will need the chairs arranged in a classroom layout and projector access.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves reserving floor 19 main training room for multi-day workshop. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Block the training room calendar, coordinate the layout requirements with the maintenance crew, and confirm with the organizer.',
        0.93
    ),
    (
        'FC002',
        'Priority courier dispatch for signed acquisition contract documents',
        'I have the signed copy of the company acquisition agreement that needs to be delivered to our legal office across the city by 3 PM today. We need to book a priority motorbike courier immediately.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves priority courier dispatch for signed acquisition contract documents. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Contact the express courier service, dispatch a driver for pickup, and provide the tracking link to the sender.',
        0.97
    ),
    (
        'FC002',
        'Corporate stamp request for legal power of attorney form',
        'I need the official company seal stamped on this power of attorney document for our representative in court tomorrow. The document has been approved by the legal director. I need to bring it to reception.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves corporate stamp request for legal power of attorney form. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Verify legal approval signature, apply the corporate seal stamp, and log the document details.',
        0.94
    ),
    (
        'FC002',
        'Updating lobby digital directory board with new department layout',
        'Following our recent department reorganizations, several teams have moved floors. We need reception to update the layout displayed on the lobby touchscreens and digital directory board to reflect these changes.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves updating lobby digital directory board with new department layout. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Update the department registry data in the lobby display software console, and verify the changes on the screen.',
        0.92
    ),
    (
        'FC002',
        'Reception desk flower arrangement renewal request',
        'The flower bouquet on the Floor 18 main reception counter has wilted and is starting to smell. We need the florist to deliver a fresh arrangement and dispose of the old one before our client visitors arrive.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves reception desk flower arrangement renewal request. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Contact the florist vendor, request the weekly bouquet swap, and clear the reception counter.',
        0.9
    ),
    (
        'FC002',
        'Parking garage gate arm malfunctioning and blocking exit lane',
        'The automatic gate barrier arm at the parking garage exit is not opening when employee access cards are scanned. A long queue of cars is forming inside the ramp. Security needs to raise the gate manually.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves parking garage gate arm malfunctioning and blocking exit lane. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Instruct the parking guards to override and lock the gate arm open, and call the gate technician.',
        0.96
    ),
    (
        'FC002',
        'Bicycle storage area security lock code change request',
        'To improve security in the basement bicycle parking enclosure, we request the PIN code on the mechanical lock be changed. Please update the combination and notify registered bike commuters.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves bicycle storage area security lock code change request. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Reset the mechanical lock combination, and send the new code to whitelisted bicycle commuters.',
        0.93
    ),
    (
        'FC002',
        'Coordinating external vendor schedule for lobby elevator maintenance',
        'The elevator service vendor is scheduled to perform monthly inspections next Wednesday. We need reception to block off the elevator shafts in the building booking tool and coordinate lobby signage.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves coordinating external vendor schedule for lobby elevator maintenance. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Post signs in the lobby, notify tenants, and confirm the service window with the elevator vendor.',
        0.94
    ),
    (
        'FC002',
        'Visitor access registration for upcoming software training course',
        'We are hosting an external training provider next Tuesday for a database course. There will be 5 trainers attending who need visitor badges and access to Floor 19 from 8 AM to 5 PM.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves visitor access registration for upcoming software training course. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Pre-register the visitors in the security database, print the badges, and email the access instructions.',
        0.95
    ),
    (
        'FC002',
        'Incoming package delivered to lobby reception has broken contents',
        'A package addressed to our marketing team was delivered to reception this morning, but the cardboard box is crushed and we can hear shattered glass inside. We have held the package at the front desk.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves incoming package delivered to lobby reception has broken contents. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Take photos of the damaged box, log the delivery status, and contact the recipient to inspect the contents.',
        0.91
    ),
    (
        'FC002',
        'Lost and found: Wallet recovered from Floor 18 breakout area',
        'A brown leather wallet containing bank cards and cash was found on one of the sofas on Floor 18. I have brought it to the reception desk. Please help check if an employee has reported it missing.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves lost and found: wallet recovered from floor 18 breakout area. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Log the wallet details, check card names, and contact the employee if they match the corporate registry.',
        0.93
    ),
    (
        'FC002',
        'Requesting access badge logs for audit validation',
        'Our external security auditors need to verify physical access logs for the server room on Floor 18 from last month. We need reception to export the scan history for card readers SR-01 and SR-02.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves requesting access badge logs for audit validation. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Run the card reader access report in the security software console for the server room doors, and export to CSV.',
        0.94
    ),
    (
        'FC002',
        'Scheduling VIP airport pick-up for visiting regional director',
        'Our regional director is arriving next Tuesday at 4 PM at the international terminal. We need to book a corporate chauffeur driver to pick them up, hold a name board, and bring them to the main office.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves scheduling vip airport pick-up for visiting regional director. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Book the corporate chauffeur service, provide the flight number, and send the driver contact details to the director.',
        0.95
    ),
    (
        'FC002',
        'Helipad access request for corporate aerial photography session',
        'Our marketing team wants to take photos of the city skyline from the building helipad next Wednesday for our annual report. We need facilities to secure access codes and clearance from building safety.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves helipad access request for corporate aerial photography session. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Obtain safety clearance from building management, and assign a guard to escort the photo crew to the roof.',
        0.88
    ),
    (
        'FC002',
        'Office moving truck scheduling for department relocation',
        'We have scheduled our department office move for next Saturday morning. We need to book the loading dock bay and schedule elevator priority with building management for 2 moving trucks from 8 AM to noon.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves office moving truck scheduling for department relocation. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Submit the loading dock booking form, request elevator lock-out keys, and coordinate with the moving company.',
        0.94
    ),
    (
        'FC002',
        'Reception desk digital check-in iPad unresponsive',
        'The iPad used by visitors to register at the main reception counter on Floor 18 is stuck on a white screen and does not load our check-in software. Visitors are having to register manually on paper.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves reception desk digital check-in ipad unresponsive. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Perform a hard restart on the iPad, verify Wi-Fi connectivity, and restart the check-in application.',
        0.92
    ),
    (
        'FC002',
        'Mailroom sorting table organizer unit installation',
        'To handle the growing volume of packages, we request the installation of a multi-slot wooden sorting organizer table in the Floor 18 mailroom. This will help our staff sort envelopes by department.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves mailroom sorting table organizer unit installation. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Order the sorting organizer unit, and coordinate its setup in the mailroom.',
        0.91
    ),
    (
        'FC002',
        'Access badge sensor beep sound disabled on Floor 19 entrance',
        'The card scanner on the main glass doors on Floor 19 is working, but it no longer makes a beep sound when a badge is scanned. This is confusing as employees are unsure if their card has been accepted.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves access badge sensor beep sound disabled on floor 19 entrance. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Access the card reader hardware settings in the controller console and enable the buzzer feedback.',
        0.93
    ),
    (
        'FC002',
        'Mail distribution error: Package delivered to incorrect floor bin',
        'A package containing critical PCB samples was marked as delivered to the engineering bin, but it was placed in the HR department bin instead. This delayed our hardware tests. We need better mail checking.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves mail distribution error: package delivered to incorrect floor bin. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Retrieve the package from the HR bin, deliver it to the engineering team immediately, and remind sorting staff.',
        0.94
    ),
    (
        'FC002',
        'Courier package with custom documentation delayed at main seaport customs',
        'An international shipment containing raw mechanical prototypes has been flagged by customs officials at the seaport for missing import declaration documentation. We need reception to submit the commercial invoices.',
        'Facilities',
        'medium',
        'medium',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves courier package with custom documentation delayed at main seaport customs. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Compile the commercial invoice and tax clearance documents, and email them to the customs broker.',
        0.92
    ),
    (
        'FC002',
        'Company seal stamp inkpad dried out at main lobby desk',
        'I went to seal our business contract at the lobby, but the red inkpad is completely dried out. The stamped logo is faint and unreadable. We need a replacement ink bottle or a new pad.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves company seal stamp inkpad dried out at main lobby desk. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Refill the red stamp pad with fresh ink or deliver a replacement inkpad to the reception counter.',
        0.93
    ),
    (
        'FC002',
        'Access card reader offline on basement parking entrance gate',
        'The card scanner at the basement parking entrance is displaying a ''Reader Offline'' message. Vehicles are backing up onto the street because the gate won''t open. The guard is manually verifying badges.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves access card reader offline on basement parking entrance gate. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Reset the parking gate reader controller, verify network ping to the switch, and send a technician.',
        0.96
    ),
    (
        'FC002',
        'VIP guest registration for international client delegates arriving in 1 hour',
        'We have 4 executive delegates from our international partner arriving in less than an hour for board discussions. We need priority visitor badges printed and elevator lock-out pre-arranged.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves vip guest registration for international client delegates arriving in 1 hour. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Pre-print the guest badges, notify the lobby guards of the VIP arrival, and coordinate floor access.',
        0.95
    ),
    (
        'FC002',
        'Registered mail collection notification from postal office',
        'We received a slip from the local post office stating that a registered document is waiting for collection. The document is addressed to our legal department. We need someone to collect it.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves registered mail collection notification from postal office. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Assign a courier driver to collect the registered document from the local post office using the collection slip.',
        0.94
    ),
    (
        'FC002',
        'After-hours building access approval for building contractor team',
        'A contractor team needs to access the Floor 18 office tonight from 10 PM to 4 AM to install our new network cabling trunk. We need access badges authorized and building security notified.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves after-hours building access approval for building contractor team. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Register the contractors'' names with building security, and enable after-hours entry profiles on their access cards.',
        0.95
    ),
    (
        'FC002',
        'Visitor lobby signage content update request for quarterly meeting',
        'We are hosting our quarterly shareholder meeting next Monday. We need the main lobby digital screens updated with the welcome message and agenda schedule by Friday afternoon.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves visitor lobby signage content update request for quarterly meeting. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Load the new slides into the lobby digital signage controller and schedule them to run starting Monday.',
        0.93
    ),
    (
        'FC002',
        'Late-night shuttle bus route adjustment suggestion',
        'Several employees who work the late shift suggest that the corporate shuttle bus route be modified to stop at the nearby metro station. This would cut commute times in half. Can reception evaluate?',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC002 (Reception, Mail & Transportation) floor 18, as the issue involves late-night shuttle bus route adjustment suggestion. The policy fit is appropriate since this team handles front-desk services, logistics, mail, courier packages, company vehicles, and badges (excluding facility repairs or office supplies).',
        'Discuss the route adjustment suggestion with the shuttle bus contractor, and evaluate feasibility.',
        0.85
    ),
    (
        'FC003',
        'Out of A4 printer paper in Floor 18 main printer hub',
        'Both shared printers in the Floor 18 lobby are completely out of A4 paper, and there are no boxes left in the storage cabinet. We have a physical audit package to print today and need boxes restocked.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves out of a4 printer paper in floor 18 main printer hub. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Retrieve three boxes of A4 printer paper from the central warehouse and restock the Floor 18 printer cabinets.',
        0.96
    ),
    (
        'FC003',
        'Pantry coffee beans empty in Floor 19 break area',
        'The espresso machine in the Floor 19 break room is showing an ''Empty bean hopper'' indicator, and the pantry storage drawers are completely empty of whole beans. Several teams rely on this for morning meetings.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves pantry coffee beans empty in floor 19 break area. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Deliver a new batch of whole espresso beans from the pantry supplies inventory and refill the coffee machine hopper.',
        0.95
    ),
    (
        'FC003',
        'First aid kit in Floor 18 West wing is missing bandages and antiseptic',
        'I went to retrieve a bandage from the Floor 18 first aid box, but the kit is almost empty. It is missing sterile bandages, adhesive tape, antiseptic wipes, and burn gel. The kit needs a complete replenishment.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves first aid kit in floor 18 west wing is missing bandages and antiseptic. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Retrieve first aid replacement packets from stock, refill the Floor 18 West box, and update the safety check tag.',
        0.97
    ),
    (
        'FC003',
        'Vending machine on Floor 18 East pantry showing coin jam error',
        'The snack vending machine near the Floor 18 East pantry is displaying a ''Coin Return Jam'' error. It is rejecting all cash and card transactions, making it impossible to buy snacks. Several coins seem stuck.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves vending machine on floor 18 east pantry showing coin jam error. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Clear the coin jam mechanism if accessible, or call the vending machine service vendor to schedule a repair.',
        0.93
    ),
    (
        'FC003',
        'Requesting placement of compostable waste bins in office pantries',
        'To support our green office initiative, we request the placement of organic composting waste bins in the Floor 18 and Floor 19 pantries. We also need instructions on composting rules posted.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves requesting placement of compostable waste bins in office pantries. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Order 2 compost-compatible collection bins, place them in the pantries, and print the composting guidelines flyer.',
        0.94
    ),
    (
        'FC003',
        'Communal refrigerator in Floor 18 pantry leaking water from bottom',
        'There is a large pool of water growing under the double-door refrigerator in the Floor 18 pantry. The internal freezer compartment is accumulating frost, which seems to be melting and leaking. It needs inspection.',
        'Facilities',
        'medium',
        'medium',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves communal refrigerator in floor 18 pantry leaking water from bottom. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Clean the pooled water, check the refrigerator door seals, defrost the freezer, or call the appliance technician.',
        0.95
    ),
    (
        'FC003',
        'Whiteboard markers completely dried out in Meeting Room 4B',
        'All four markers in Meeting Room 4B are dried out and barely write on the board. We had to cancel our whiteboarding session. We need a fresh pack of markers and a clean whiteboard eraser.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves whiteboard markers completely dried out in meeting room 4b. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Deliver a new pack of whiteboard markers and an eraser to Meeting Room 4B, and discard the dried-out ones.',
        0.94
    ),
    (
        'FC003',
        'Requesting ergonomic keyboard wrist rest and anti-fatigue desk mat',
        'My manager suggested I request a standing desk anti-fatigue mat and a foam keyboard wrist support to improve my workstation ergonomics. Please let me know when I can collect these.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves requesting ergonomic keyboard wrist rest and anti-fatigue desk mat. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Check stock for standing desk mats and foam wrist rests, and issue them to the employee.',
        0.91
    ),
    (
        'FC003',
        'Requesting specialized color ink cartridges for marketing plotter printer',
        'Our marketing design team needs specialized color ink cartridges (model HP-72) to print large banners for the upcoming product launch. We are out of cyan and magenta and need them by tomorrow.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves requesting specialized color ink cartridges for marketing plotter printer. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Verify current ink inventory, order the HP-72 cyan and magenta cartridges from the vendor, and deliver to marketing.',
        0.94
    ),
    (
        'FC003',
        'Water cooler dispenser in Floor 19 West corridor empty',
        'The water bottle on the dispenser in the Floor 19 West wing is completely empty. People are having to walk to the main pantry to get water. We need a fresh 20L water bottle installed on the unit.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves water cooler dispenser in floor 19 west corridor empty. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Retrieve a 20L drinking water bottle from storage and replace the empty bottle on the Floor 19 dispenser.',
        0.95
    ),
    (
        'FC003',
        'Coffee machine descaling filter replacement request',
        'The main espresso machine in the executive pantry is showing a ''Descale filter replacement required'' blinking light on the status screen. We need to swap the water filter to prevent limescale buildup.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves coffee machine descaling filter replacement request. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Perform the descale cycle on the coffee machine and replace the internal water filter cartridge.',
        0.92
    ),
    (
        'FC003',
        'Pantry refrigerator stock: Expiry date check and cleanout request',
        'The communal refrigerator in the Floor 18 pantry is starting to smell because of left-over food. We request a complete cleanout of expired containers and sanitizing the shelves this Friday night.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves pantry refrigerator stock: expiry date check and cleanout request. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Announce the refrigerator cleanout schedule to employees, discard unlabeled containers on Friday evening, and wipe down shelves.',
        0.93
    ),
    (
        'FC003',
        'Out of paper coffee cups in Floor 18 pantry dispenser',
        'The paper cup holder next to the water dispenser on Floor 18 is empty. People are having to wash ceramic mugs or use plastic cups. Please restock a sleeve of paper coffee cups.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves out of paper coffee cups in floor 18 pantry dispenser. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Deliver three sleeves of paper hot cups to the Floor 18 pantry cupboard.',
        0.95
    ),
    (
        'FC003',
        'Ordering organic green tea bags for executive board meeting pantry',
        'We have a VIP board meeting next Tuesday and need to purchase a pack of organic green tea bags for the conference room pantry. The current stock only has black tea. We need this ordered by Friday.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves ordering organic green tea bags for executive board meeting pantry. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Procure a box of organic green tea bags from the grocery vendor and place it in the executive boardroom pantry.',
        0.91
    ),
    (
        'FC003',
        'Soap dispenser empty in Floor 19 male restroom',
        'The automatic liquid soap dispenser in the Floor 19 restroom has run out of soap. The sanitizing fluid level is empty and guests cannot wash their hands. We need this refilled.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves soap dispenser empty in floor 19 male restroom. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Refill the liquid soap reservoir in the restroom dispenser and test the automatic sensor.',
        0.94
    ),
    (
        'FC003',
        'Missing remote control batteries for Floor 18 projection system',
        'We are trying to start a presentation in Meeting Room 1, but the batteries in the projector remote control are dead. We need two AAA batteries to turn on the screen.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves missing remote control batteries for floor 18 projection system. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Deliver a pair of AAA batteries to the meeting room remote control and verify the projector turns on.',
        0.9
    ),
    (
        'FC003',
        'Paper shredder container full and blades jammed in finance area',
        'The paper shredder in the finance zone has a ''Bin Full'' indicator and has stopped shredding. The motor hums but the blades are jammed with thick paper. We need it emptied and the cutting head oiled.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves paper shredder container full and blades jammed in finance area. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Empty the shredded paper waste bag, clear the paper jam from the cutting blades, and apply shredder lubricant oil.',
        0.95
    ),
    (
        'FC003',
        'Ordering plastic document laminating pouches for legal team',
        'Our legal team is preparing physical training binders and has run out of plastic laminator pouches (A4 size). We need to order a box of 100 pouches to complete the document binding.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves ordering plastic document laminating pouches for legal team. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Order a pack of 100 A4 laminating pouches and deliver them to the legal department floor.',
        0.93
    ),
    (
        'FC003',
        'Pantry milk cartons expired in Floor 18 refrigerator',
        'Several cartons of fresh milk in the Floor 18 pantry fridge are expired and turning sour. We need them removed and replaced with a fresh batch for tea and coffee preparation.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves pantry milk cartons expired in floor 18 refrigerator. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Discard the expired milk cartons, clean any spills in the fridge, and restock fresh milk from the daily shipment.',
        0.95
    ),
    (
        'FC003',
        'Vending machine on Floor 19 snack selection error',
        'The snack vending machine near the Floor 19 elevator has mixed up its rows. When you select potato chips (row A4), it dispenses chocolate bars (row B4). We need the vendor to check the configuration.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves vending machine on floor 19 snack selection error. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Log the selection error and contact the vending machine vendor to request a calibration visit.',
        0.92
    ),
    (
        'FC003',
        'Requesting standing desk anti-fatigue floor mat for call center',
        'Since we switched to standing desks in the call center, several agents have complained about sore feet. We request 5 anti-fatigue floor mats for the active workstations.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves requesting standing desk anti-fatigue floor mat for call center. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Approve the request and deliver 5 anti-fatigue mats to the call center floor rows.',
        0.91
    ),
    (
        'FC003',
        'Monthly corporate office plant watering service scheduling',
        'We need to schedule the monthly watering and leaf pruning service for the decorative indoor plants on Floors 17, 18, and 19. The service team needs building access next Friday.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves monthly corporate office plant watering service scheduling. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Approve the contractor visit date, notify building security, and coordinate floor access.',
        0.93
    ),
    (
        'FC003',
        'Requesting cardboard recycling bins for Floor 19 mailroom',
        'The mailroom on Floor 19 receives many cardboard delivery boxes daily. We request two large dedicated cardboard recycling bins to prevent boxes from piling up in the corridors.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves requesting cardboard recycling bins for floor 19 mailroom. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Provide two cardboard disposal bins and place them near the mail sorting tables.',
        0.94
    ),
    (
        'FC003',
        'Specialty tea selection request for marketing client meetings',
        'Our marketing team frequently hosts VIP clients on Floor 18. We request a box of specialty earl grey and jasmine tea bags to be stocked in the meeting area cupboard.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves specialty tea selection request for marketing client meetings. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Order a pack of earl grey and jasmine tea bags and place them in the marketing meeting pantry cabinet.',
        0.91
    ),
    (
        'FC003',
        'Out of printer toner cartridges for main designer plotter',
        'The plotter printer in our design studio has run out of matte black toner (model HP-80). We have urgent floor layouts to print and need a replacement cartridge from inventory immediately.',
        'Facilities',
        'high',
        'high',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves out of printer toner cartridges for main designer plotter. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Retrieve a matte black toner cartridge from the central stock, install it in the plotter, and verify printer status.',
        0.96
    ),
    (
        'FC003',
        'Desk cable organizers and cable ties supply replenishment',
        'We are setting up the desks for the new hires next week. We have run out of plastic cable zip ties and adhesive cable organizers to tidy up the monitor cords. We need a pack of 100 ties.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves desk cable organizers and cable ties supply replenishment. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Issue a packet of cable ties and zip organizers from the utility inventory cabinet.',
        0.92
    ),
    (
        'FC003',
        'Defective microwave button panel in Floor 18 central breakroom',
        'The start button on the main microwave oven in the Floor 18 breakroom is unresponsive. We cannot start the heating cycle. The display and other buttons light up but it won''t run. We need a replacement.',
        'Facilities',
        'medium',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves defective microwave button panel in floor 18 central breakroom. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Inspect the microwave power panel, label it out-of-order, and dispatch it to the repair shop or order a swap.',
        0.94
    ),
    (
        'FC003',
        'Requesting standing desk anti-fatigue mat for reception desk staff',
        'Our front-desk reception staff stand for long hours welcoming visitors. We request a thick anti-fatigue floor mat to place behind the reception counter on Floor 18.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves requesting standing desk anti-fatigue mat for reception desk staff. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Retrieve an anti-fatigue mat from stock and deliver it to the Floor 18 reception desk team.',
        0.93
    ),
    (
        'FC003',
        'Whiteboard cleaning spray refill request for Floor 19 meeting rooms',
        'The whiteboard cleaning spray bottles in all Floor 19 meeting rooms are empty. The whiteboards are covered in ink shadows that won''t erase. We need these bottles refilled or replaced.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves whiteboard cleaning spray refill request for floor 19 meeting rooms. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Refill the spray bottles in all Floor 19 meeting rooms and check eraser conditions.',
        0.95
    ),
    (
        'FC003',
        'Label maker refill tape cartridge purchase request for IT warehouse',
        'Our IT inventory team is tagging incoming monitors and has run out of brother label tape (12mm black on white). We need two rolls ordered to finish labeling our new stock.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves label maker refill tape cartridge purchase request for it warehouse. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Order two rolls of 12mm label printer tape from our office stationery vendor.',
        0.94
    ),
    (
        'FC003',
        'Pantry water cooler sanitization service coordination',
        'The main water cooler dispenser in the Floor 19 breakroom is showing green algae buildup inside the plastic nozzle. We need a professional cleaning vendor to sanitize the internal tank and lines.',
        'Facilities',
        'medium',
        'medium',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves pantry water cooler sanitization service coordination. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Coordinate with the water supplier vendor to perform deep sanitization on the Floor 19 cooler units.',
        0.96
    ),
    (
        'FC003',
        'Laminator sheet pockets A3 size replenishment request',
        'We have run out of A3 size laminator sheet pockets in the central supply closet. We need to laminate several large workflow charts for the warehouse. Please restock a box.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves laminator sheet pockets a3 size replenishment request. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Purchase a box of A3 laminator sheet pockets and place them in the central supply cabinet.',
        0.91
    ),
    (
        'FC003',
        'Recycling bins placement request for Floor 18 open office layout',
        'We need additional paper recycling bins in the Floor 18 open area, as people are throwing documents into the general trash. We request 3 bins placed at the ends of rows A, B, and C.',
        'Facilities',
        'low',
        'low',
        'The ticket is categorized under FC003 (Office Supplies & Pantry) floor 18, as the issue involves recycling bins placement request for floor 18 open office layout. The policy fit is appropriate since this team handles distribution of office supplies and managing pantry items (excluding facility repairs, badge access, or transportation bookings).',
        'Deliver three blue paper recycling bins to the Floor 18 open workspace rows.',
        0.93
    ),
    (
        'HR001',
        'Discrepancy in monthly overtime (OT) hours payment in June payslip',
        'I reviewed my payslip for June and noticed that my approved overtime hours from the system deployment on June 15th (totaling 8 hours at double rate) were not paid. My manager approved the hours, but they seem to be missing.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves discrepancy in monthly overtime (ot) hours payment in june payslip. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Cross-reference the employee OT logs, verify manager approval, and process the adjustment in the next payroll cycle.',
        0.96
    ),
    (
        'HR001',
        'Query regarding annual leave balance correction after system migration',
        'My annual leave balance in the self-service portal is showing only 8 days remaining, but according to my records and last month payslip, I should have 12 days. I suspect the recent HRIS migration did not import my carry-over leave.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves query regarding annual leave balance correction after system migration. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Check the historical leave tracker backups, correct the balance in the database, and notify the employee.',
        0.95
    ),
    (
        'HR001',
        'Maternity leave benefit insurance process and allowance query',
        'I will be starting my maternity leave next month. I need HR to explain the process for submitting my documents to the social insurance office (BHXH) to receive my maternity allowance, and what the estimated payment timeline is.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves maternity leave benefit insurance process and allowance query. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Send the maternity benefit document checklist to the employee, and coordinate the submission to the BHXH office.',
        0.97
    ),
    (
        'HR001',
        'Question regarding Bao Viet Health Insurance coverage limits for dental',
        'I need to get a dental crown next week and want to verify if our corporate Bao Viet health insurance covers this procedure. I checked the handbook but couldn''t find the specific coverage limits for dental crowns.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves question regarding bao viet health insurance coverage limits for dental. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Retrieve the employee PVI/Bao Viet benefits booklet, check dental coverage terms, and reply to the employee.',
        0.96
    ),
    (
        'HR001',
        'Dependent tax deduction registration form submission',
        'I recently had a baby and need to register my child as a dependent for personal income tax deduction. I have filled out the registration form and attached the birth certificate. Please update my tax profile.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves dependent tax deduction registration form submission. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Review the birth certificate document, submit the dependent registry to the tax department, and update the payroll database.',
        0.95
    ),
    (
        'HR001',
        'Salary payment not received on bank account today',
        'Today is our monthly salary disbursement day and all my colleagues have received their payments, but my account has not been credited. I checked my bank details in the portal and they look correct. Please check.',
        'HR',
        'high',
        'high',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves salary payment not received on bank account today. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Check the bank transfer batch log for the employee ID, verify transaction status, and process immediate wire if failed.',
        0.98
    ),
    (
        'HR001',
        'Requesting income verification letter for bank loan application',
        'I am applying for a bank loan and need a signed income verification letter showing my job title, start date, and monthly salary for the past 3 months. The bank needs this document by next Thursday.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves requesting income verification letter for bank loan application. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Draft the verification letter using the corporate template, secure the director''s signature, and notify the employee.',
        0.94
    ),
    (
        'HR001',
        'Updating bank account details for monthly salary payroll',
        'I have closed my old bank account and opened a new one with Techcombank. I need HR to update my payroll details to the new account number for all future salary transfers. I have attached the bank confirmation letter.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves updating bank account details for monthly salary payroll. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Verify bank confirmation documents, update the account number in the payroll software, and test file export.',
        0.96
    ),
    (
        'HR001',
        'Query about company wellness allowance reimbursement limits',
        'I purchased a annual gym membership last month and want to submit the invoice for our wellness allowance reimbursement. I need to check what the annual limit is and if the invoice formatting is compliant.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves query about company wellness allowance reimbursement limits. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Confirm the wellness allowance policy limits, check invoice compliance, and process the reimbursement claim.',
        0.95
    ),
    (
        'HR001',
        'Meal allowance card not receiving monthly balance',
        'My corporate lunch card has not been topped up with the monthly allowance balance for July. I tried scanning it at the cafeteria today but it showed zero balance. Can you check my card status?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves meal allowance card not receiving monthly balance. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Check the allowance top-up registry for the card number, and contact the lunch vendor to reissue the credit.',
        0.93
    ),
    (
        'HR001',
        '13th month salary calculation policy query for mid-year hires',
        'I joined the company in April this year and want to understand how my 13th month salary will be calculated at the end of the year. Will it be prorated based on my active months or do I get the full amount?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves 13th month salary calculation policy query for mid-year hires. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Explain the prorated 13th-month salary policy to the employee based on their start date.',
        0.92
    ),
    (
        'HR001',
        'Social insurance book (So BHXH) collection query after transfer',
        'I recently transferred to this branch from our local subsidiary. I need to collect my physical social insurance book to complete my profile. Has the book been received from the subsidiary''s HR team yet?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves social insurance book (so bhxh) collection query after transfer. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Contact the subsidiary HR team to verify transfer status, and notify the employee when the book is in our storage.',
        0.95
    ),
    (
        'HR001',
        'PVI health insurance card replacement request after loss',
        'I lost my physical PVI health insurance card during my house move. I need to visit the hospital next week and require a replacement card. Can you request a duplicate card from the provider?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves pvi health insurance card replacement request after loss. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Contact the PVI insurance representative to request a card reissue, and provide the digital insurance number.',
        0.94
    ),
    (
        'HR001',
        'Retirement pension contribution discrepancy in monthly deductions',
        'I noticed in my pay slip that the pension fund contribution deduction has increased by 2% this month. I did not request any changes to my contribution rate. Can you explain why this adjustment was made?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves retirement pension contribution discrepancy in monthly deductions. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Inspect the payroll configuration, check for any statutory pension rate updates, and reply to the employee.',
        0.93
    ),
    (
        'HR001',
        'Relocation allowance reimbursement request for regional transfer',
        'Following my transfer from Hanoi to the Ho Chi Minh branch last month, I request the payout of my approved relocation allowance. I have attached all moving invoices and rent agreements.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves relocation allowance reimbursement request for regional transfer. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Review the relocation policy limits, approve the submitted invoices, and include the allowance in the next payroll run.',
        0.95
    ),
    (
        'HR001',
        'Retroactive pay adjustment missing for mid-year promotion',
        'My promotion to Senior Architect was approved on May 1st, but my June payslip still shows my old salary grade. I was told the difference would be paid retroactively. Can you verify when this will be resolved?',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves retroactive pay adjustment missing for mid-year promotion. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Update the employee salary grade in the system, compute the retroactive pay difference, and include it in next month payroll.',
        0.96
    ),
    (
        'HR001',
        'Tax code change application after marriage status change',
        'I recently registered my marriage and need to update my personal income tax code in the tax office database. I need HR to help register this change so my tax withholding is computed correctly.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves tax code change application after marriage status change. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Obtain the marriage certificate, register the status change with the tax authority, and update HRIS.',
        0.94
    ),
    (
        'HR001',
        'Corporate phone allowance not appearing in July payslip',
        'My mobile phone allowance of 500,000 VND is missing from my July payslip. I am in the sales team and this allowance is part of my contract. Please check if this was omitted by mistake.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves corporate phone allowance not appearing in july payslip. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Verify the contract allowance terms, and add the missing phone allowance item to the payroll system.',
        0.93
    ),
    (
        'HR001',
        'Emergency salary advance request for family medical emergency',
        'Due to an unexpected medical emergency in my family, I need to request an advance of 50% of my monthly salary. My manager has approved the emergency request. I need this processed as soon as possible.',
        'HR',
        'high',
        'high',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves emergency salary advance request for family medical emergency. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Obtain director approval for the emergency advance, configure the payroll deduction, and trigger the wire transfer.',
        0.97
    ),
    (
        'HR001',
        'Duplicate payslip reissuance request for past year visa application',
        'I am applying for a foreign visa and need physical signed copies of my payslips from the past 12 months. The self-service portal only allows downloading the last 3 months. Can HR print and stamp these for me?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves duplicate payslip reissuance request for past year visa application. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Retrieve the 12-month payslip files from the payroll archives, print them, apply the corporate stamp, and notify the employee.',
        0.94
    ),
    (
        'HR001',
        'Childcare subsidy application submission and policy question',
        'I want to apply for the corporate childcare subsidy for my 3-year-old child starting preschool next month. I need to know what documents are required and if there are specific approved schools.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves childcare subsidy application submission and policy question. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Send the childcare subsidy policy documents and application form link to the employee.',
        0.93
    ),
    (
        'HR001',
        'Housing allowance documentation validation for expat staff',
        'I am an expatriate developer and need to submit my monthly lease invoice to activate my tax-exempt housing allowance. Can you verify if the red invoice details match our corporate tax code?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves housing allowance documentation validation for expat staff. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Verify the lease invoice against company tax compliance guidelines, and approve the allowance mapping.',
        0.92
    ),
    (
        'HR001',
        'Fitness benefit reimbursement invoice rejection explanation',
        'My gym invoice submission for the fitness benefit was rejected with the status ''Invalid document''. I paid using my personal credit card and attached the receipt. Can you clarify what is missing?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves fitness benefit reimbursement invoice rejection explanation. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Review the rejected invoice details, explain to the user that a formal red invoice (e-invoice) is required, and invite resubmission.',
        0.94
    ),
    (
        'HR001',
        'Inquiry about overtime pay rate for working on public holidays',
        'We are planning to support our server infrastructure during the upcoming national holiday. I need HR to confirm if the overtime pay rate for working on public holidays is 300% of the base salary and how to submit the hours.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves inquiry about overtime pay rate for working on public holidays. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Provide the statutory holiday pay rate details to the employee and guide them on the OT approval flow in HRIS.',
        0.96
    ),
    (
        'HR001',
        'Retroactive shift differential allowance missing for night shift engineers',
        'Our team has been working on the night support shifts (10 PM to 6 AM) for the past two months. The contract specifies a 30% shift differential, but our payslips only show the base rate. We request a retroactive correction.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves retroactive shift differential allowance missing for night shift engineers. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Audit the night shift attendance logs, calculate the differential difference, and process the payout in next month''s payroll.',
        0.95
    ),
    (
        'HR001',
        'Requesting update to bank details for international wire transfer',
        'I need to update my bank account details in the HR system to an international Citibank account for my expat salary wire. I have attached the routing number and SWIFT code bank documentation.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves requesting update to bank details for international wire transfer. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Verify SWIFT codes with the corporate bank portal, and update the foreign transaction details in the payroll DB.',
        0.94
    ),
    (
        'HR001',
        'PIT tax deduction certificate request for personal income tax finalization',
        'I am preparing my personal tax finalization for the past calendar year and need HR to issue my official Personal Income Tax (PIT) deduction certificate (Chung tu khau tru thue TNCN). I need it by next week.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves pit tax deduction certificate request for personal income tax finalization. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Print the official tax deduction certificate, sign and stamp it, and notify the employee for physical collection.',
        0.97
    ),
    (
        'HR001',
        'Leave carry-over policy query for unused annual leave',
        'I have 5 days of unused annual leave from last year. The manager said they can be carried over, but I want to clarify if there is an expiration date for utilizing these carried-over days before they are forfeited.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves leave carry-over policy query for unused annual leave. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Explain the annual leave carry-over expiration policy (e.g., must use by March 31st) to the employee.',
        0.95
    ),
    (
        'HR001',
        'Question regarding Bao Viet health insurance card addition for dependents',
        'I want to register my parents under our corporate Bao Viet health insurance policy as dependents. I need HR to clarify the premium cost that will be deducted from my salary and how to submit the medical declaration.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves question regarding bao viet health insurance card addition for dependents. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Send the dependent insurance premium pricing list and registration form link to the employee.',
        0.94
    ),
    (
        'HR001',
        'Discrepancy in monthly travel allowance calculation',
        'My travel allowance for field audits last month was calculated as 1,200,000 VND, but based on my approved travel tickets and mileage tracker, it should be 1,800,000 VND. Please verify the calculation.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves discrepancy in monthly travel allowance calculation. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Verify the travel tickets against the expense sheets, and correct the travel allowance credit for the employee.',
        0.93
    ),
    (
        'HR001',
        'Query about stock option vesting schedule and taxation rules',
        'My first batch of ESOP stock options is vesting next month. I need HR to explain the exercise process, whether the options are sold automatically, and what PIT tax rates will apply to the capital gains.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves query about stock option vesting schedule and taxation rules. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Send the ESOP guide and the current capital gains PIT tax policy rules to the employee.',
        0.91
    ),
    (
        'HR001',
        'Relocation expenses reimbursement claim status check',
        'I submitted my moving invoices for my relocation from Da Nang to the main office three weeks ago, but the claim status in the portal is still showing ''Pending Approval''. Can someone check if additional info is needed?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves relocation expenses reimbursement claim status check. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Inspect the relocation invoice approvals, contact the finance team, and update the status in the portal.',
        0.94
    ),
    (
        'HR001',
        'Housing allowance application process for relocated domestic employees',
        'I was transferred from the Hanoi office to the HCM branch to lead the new project. Does the company offer a housing allowance for relocated domestic staff, and what is the application process?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR001 (Compensation & Benefits (C&B)) floor 12A, as the issue involves housing allowance application process for relocated domestic employees. The policy fit is appropriate since this team handles employee pay, benefits, payroll, social insurance, and personal income tax (excluding training registration or resignation procedures).',
        'Send the domestic relocation policy guidelines and housing allowance limits documentation to the employee.',
        0.93
    ),
    (
        'HR002',
        'Onboarding coordinator assignment request for new engineering batch',
        'We have 8 new software engineering interns starting on Monday. I need HR to assign an onboarding coordinator to host the orientation session, walk them through the employee handbook, and coordinate badge collections.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves onboarding coordinator assignment request for new engineering batch. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Assign an HR coordinator to manage the orientation itinerary, book the training room, and email the interns.',
        0.96
    ),
    (
        'HR002',
        'Jira server access request for corporate Learning Management System (LMS)',
        'I am trying to log in to our training portal to complete the mandatory compliance course, but I get an ''Authentication server unreachable'' error. My colleagues are also reporting this. Can you restart the LMS connector?',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves jira server access request for corporate learning management system (lms). The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Check the LMS platform connection logs, reset the SSO configuration for the learning portal, and notify the vendor.',
        0.94
    ),
    (
        'HR002',
        'Leadership training workshop registration issue for mid-level managers',
        'I tried to register for the ''Advanced Leadership Strategy'' course scheduled for next Friday, but the system shows the class is full. Since this training is a requirement for my promotion path, can we expand the capacity?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves leadership training workshop registration issue for mid-level managers. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Verify manager approval, check if the external trainer can accommodate another attendee, and register the manager.',
        0.95
    ),
    (
        'HR002',
        'Scheduling final round interview panel for Senior QA Engineer candidate',
        'The candidate has passed the technical test and we need to schedule a 90-minute panel interview with the team lead, product owner, and engineering director. The candidate is available this Thursday afternoon.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves scheduling final round interview panel for senior qa engineer candidate. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Confirm panelist availability, book a meeting room or video bridge, and send the calendar invites to the candidate and panel.',
        0.96
    ),
    (
        'HR002',
        'Requisition approval request: Hiring additional Frontend Developer',
        'To meet our Q3 project deadlines, we need to hire one additional junior frontend developer. I have created the job description and need HR to approve the requisition so we can publish the posting on LinkedIn.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves requisition approval request: hiring additional frontend developer. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Review the job requisition details, verify headcount budget clearance, and activate the posting on career portals.',
        0.95
    ),
    (
        'HR002',
        'Probation review feedback submission delay warning',
        'The 60-day probation period for our new UX designer ends next Wednesday. I need to submit their probation review form, but my manager has been out of the office. Can I request a 3-day extension to submit the evaluation?',
        'HR',
        'medium',
        'medium',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves probation review feedback submission delay warning. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Grant the temporary submission extension, notify the payroll team, and monitor the review status.',
        0.94
    ),
    (
        'HR002',
        'Requesting budget approval for external specialized Kubernetes training',
        'Our devops team wants to attend a 3-day external Kubernetes administration certification course. The total cost is $800 per person for 3 engineers. I have attached the syllabus and team lead approval.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves requesting budget approval for external specialized kubernetes training. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Verify budget availability in the departmental L&D bucket, approve the training expense, and send booking instructions.',
        0.93
    ),
    (
        'HR002',
        'Mandatory safety awareness training compliance report request',
        'For our quarterly safety audit, we need to export the list of employees who have completed the ''Office Fire Safety'' e-learning course, and flag those who are overdue. The auditor needs this report by Friday.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves mandatory safety awareness training compliance report request. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Generate the course completion report from the LMS admin dashboard and export it to the compliance auditor.',
        0.95
    ),
    (
        'HR002',
        'Assigning onboarding buddy for incoming product manager',
        'We have a new Product Manager starting in our team next month. I want to assign a senior analyst as their onboarding buddy to guide them through our product roadmaps. Please update the new hire itinerary.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves assigning onboarding buddy for incoming product manager. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Record the onboarding buddy assignment in the new hire file and send the program guidelines to the buddy.',
        0.93
    ),
    (
        'HR002',
        'Internal job transfer application verification for Q4 rotation',
        'I have submitted my application for the internal job posting in the DevOps team. I have been in my current support role for 14 months and want to verify if my eligibility check has been completed.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves internal job transfer application verification for q4 rotation. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Verify the employee tenure in their current role, confirm they have no active performance issues, and forward the profile to the hiring team.',
        0.94
    ),
    (
        'HR002',
        'LinkedIn Learning license assignment request for marketing designer',
        'I need to access the advanced Photoshop courses on LinkedIn Learning. Can HR allocate one of the available enterprise licenses to my account so I can start the course this week?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves linkedin learning license assignment request for marketing designer. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Allocate an active LinkedIn Learning seat to the employee email and monitor their onboarding status.',
        0.94
    ),
    (
        'HR002',
        'Pre-employment medical check-up coordination for candidate',
        'Our selected candidate for the database administrator role has accepted the offer. We need HR to coordinate their mandatory pre-employment medical check-up at our partner clinic this week.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves pre-employment medical check-up coordination for candidate. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Send the medical check-up invitation to the candidate, register them at the clinic, and track results.',
        0.93
    ),
    (
        'HR002',
        'Professional certification exam cost reimbursement request',
        'I recently passed my AWS Solutions Architect certification exam, which was approved under my training plan. I request the reimbursement of the $150 exam fee. I have attached my invoice and certificate.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves professional certification exam cost reimbursement request. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Verify prior certification approval, confirm the exam certificate is valid, and process the reimbursement invoice.',
        0.94
    ),
    (
        'HR002',
        'Employee referral bonus eligibility check for senior referral',
        'I referred a candidate who was hired as a Senior Accountant and completed their 3-month probation last week. I need HR to verify my eligibility for the employee referral bonus this month.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves employee referral bonus eligibility check for senior referral. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Check the candidate''s hiring file, verify they completed probation, and submit the referral payout ticket to the finance team.',
        0.95
    ),
    (
        'HR002',
        'Apprenticeship training program syllabus approval request',
        'Our engineering department is designing a new 6-month apprenticeship program for engineering graduates. We need HR''s L&D team to review our syllabus, structure, and check alignment with corporate standards.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves apprenticeship training program syllabus approval request. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Schedule a meeting with the engineering program lead to review the syllabus structure and program milestones.',
        0.91
    ),
    (
        'HR002',
        'Competency framework mapping consultation request for marketing roles',
        'Our marketing department is restructuring its roles. We request a consulting session with HR''s talent development team to map the skill competency requirements for our new digital marketing positions.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves competency framework mapping consultation request for marketing roles. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Assign a talent specialist to work with the marketing director to map competencies and grades.',
        0.92
    ),
    (
        'HR002',
        'Succession planning workshop registration and calendar booking',
        'We need to schedule the annual succession planning calibration session for our department heads. The workshop is planned for next month and we need HR to coordinate materials and invite participants.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves succession planning workshop registration and calendar booking. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Draft the workshop agenda, send calendar invitations to department heads, and compile assessment files.',
        0.93
    ),
    (
        'HR002',
        '360-degree feedback tool password reset in evaluation portal',
        'I need to submit my peer reviews for our quarterly evaluation cycle, but the 360-degree feedback portal has locked my account. I have tried using the self-reset link but haven''t received the mail. Please reset.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves 360-degree feedback tool password reset in evaluation portal. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Reset the employee password in the evaluation platform database and trigger a password reset email.',
        0.94
    ),
    (
        'HR002',
        'E-learning platform mobile app offline access issue',
        'I am trying to download the compliance training video courses on the LMS mobile app for my business trip commute, but the app throws a ''Download failed'' error. Can HR check if mobile downloads are disabled in settings?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves e-learning platform mobile app offline access issue. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Verify the mobile download settings in the LMS system admin panel, and guide the employee.',
        0.88
    ),
    (
        'HR002',
        'Technical book library procurement request for development team',
        'Our development team requests the purchase of 5 books on advanced Rust programming for our local training bookshelf. We have selected the titles and have manager approval. Please coordinate procurement.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves technical book library procurement request for development team. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Approve the book purchase, place the order with the book distributor, and catalog them in the office library.',
        0.91
    ),
    (
        'HR002',
        'Campus recruitment event booth logistics coordination',
        'We are participating in the IT university career fair next month. We need HR to coordinate our booth materials, banner prints, corporate brochures, and schedule the developers who will attend the fair.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves campus recruitment event booth logistics coordination. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Register our booth at the university fair, order the promotional brochures, and coordinate the attendance list.',
        0.92
    ),
    (
        'HR002',
        'Internship conversion proposal to permanent junior role',
        'An intern on our team has completed their 6-month internship, showing outstanding performance. I want to propose their conversion to a permanent Junior Developer role starting next month. Please review.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves internship conversion proposal to permanent junior role. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Verify intern performance reviews, prepare the junior contract offer letter, and send it to the director for approval.',
        0.95
    ),
    (
        'HR002',
        'Mandatory safety training overdue reminder list export',
        'We need to identify the team leaders whose members have not completed the mandatory annual safety training. Please provide the list of overdue users sorted by department so we can remind them.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves mandatory safety training overdue reminder list export. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Export the overdue safety training list from the LMS console, group by department manager, and email the alerts.',
        0.94
    ),
    (
        'HR002',
        'Campus recruitment campaign volunteer registration and briefing',
        'We are looking for engineers to volunteer as technical interviewers for the upcoming campus recruitment day. We request L&D to coordinate a briefing session to explain the evaluation rubrics and schedule.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves campus recruitment campaign volunteer registration and briefing. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Email the call for volunteers to the engineering team, and schedule a 30-minute briefings session for registered helpers.',
        0.94
    ),
    (
        'HR002',
        'Competency matrix review request for junior software engineer roles',
        'We need to update the competency expectations for our Junior Software Engineer roles in the LMS platform before the Q3 reviews. We request L&D to help align the technical rubrics with the updated stack.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves competency matrix review request for junior software engineer roles. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Review the proposed technical rubric revisions and map them to the corresponding role configurations in the LMS database.',
        0.93
    ),
    (
        'HR002',
        'Requesting feedback on the recent Q2 performance calibration session',
        'I would like to schedule a quick sync with the Talent team to receive feedback on our team''s Q2 performance calibration session. I want to ensure my promotion proposals complied with guidelines.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves requesting feedback on the recent q2 performance calibration session. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Schedule a short review meeting with the requesting manager and prepare the calibration notes.',
        0.92
    ),
    (
        'HR002',
        'LMS platform integration with corporate Microsoft Teams client',
        'We want to integrate our Learning Management System with Microsoft Teams so employees can receive compliance alerts directly in their chat. We need L&D to coordinate with IT to enable the app manifest.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves lms platform integration with corporate microsoft teams client. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Review LMS integration documentation, submit the integration ticket to the IT system administrator, and test alert triggers.',
        0.95
    ),
    (
        'HR002',
        'Professional development plan templates request for engineering managers',
        'To support our career progression discussions, we request L&D to share the standard templates and guidelines for drafting Professional Development Plans (PDP) for our junior developers.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves professional development plan templates request for engineering managers. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Send the PDP templates, guidelines, and career path booklets to the engineering manager''s team folder.',
        0.93
    ),
    (
        'HR002',
        'Onboarding document verification delay for newly joined QA tester',
        'A newly joined QA tester on our team reports that their profile in the HR portal is still showing as ''Pending Verification'' for their university degree, which blocks them from starting the LMS training. Please review.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves onboarding document verification delay for newly joined qa tester. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Review the uploaded degree certificate scan, mark it as verified in the HRIS, and notify the employee.',
        0.96
    ),
    (
        'HR002',
        'Requesting certification reimbursement for certified scrum master course',
        'I have successfully passed the Certified Scrum Master (CSM) certification course last week. I request the reimbursement of the course fee of $450. I have attached the invoice and certificate.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves requesting certification reimbursement for certified scrum master course. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Verify prior certification approval, confirm the certificate validity, and submit the payout request to finance.',
        0.94
    ),
    (
        'HR002',
        'Graduate trainee rotation schedule proposal for engineering department',
        'Our graduate trainees are completing their first rotation in the backend team next week. We request L&D to review our proposal for their next rotation in the mobile development team starting Q4.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves graduate trainee rotation schedule proposal for engineering department. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Review the rotation proposal against trainee study tracks, update the trainee roster, and notify the hosting team leads.',
        0.93
    ),
    (
        'HR002',
        'Talent review calibration workshop invite coordination',
        'We need to schedule the upcoming talent calibration workshop for the Product management department. We request HR to coordinate with the directors to schedule a 2-hour window next month.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves talent review calibration workshop invite coordination. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Identify director calendars, block a meeting room, and send the talent review invites with calibration instructions.',
        0.94
    ),
    (
        'HR002',
        'Succession planning framework documentation request for director roles',
        'As part of our leadership transition preparation, we request HR to share the official succession planning framework document and candidate assessment guidelines for director-level positions.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR002 (Talent Acquisition & Learning and Development (L&D)) floor 12A, as the issue involves succession planning framework documentation request for director roles. The policy fit is appropriate since this team handles new employee onboarding support, workstation preparation, and training courses (excluding payroll, benefits, resignation, or workplace conflict).',
        'Send the succession planning framework slides and assessment matrices to the requesting director.',
        0.91
    ),
    (
        'HR003',
        'Harassment report and hostile work environment incident on Floor 19',
        'I need to report a serious incident of verbal harassment and bullying by a senior colleague that occurred in our team meeting yesterday on Floor 19. This behavior has created a hostile environment and I feel unsafe.',
        'HR',
        'high',
        'high',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves harassment report and hostile work environment incident on floor 19. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Immediately schedule separate private interviews with the complainant and the accused, and document the incident logs.',
        0.99
    ),
    (
        'HR003',
        'Conflict resolution and mediation request between two developers',
        'Our backend team has two senior developers whose ongoing personal conflict is starting to block project progress and affect team meetings. I request HR to schedule a mediation session to help resolve their issues.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves conflict resolution and mediation request between two developers. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Schedule a private mediation session with both developers and a senior HR relations specialist.',
        0.96
    ),
    (
        'HR003',
        'Update emergency contact information in my employee file',
        'My primary emergency contact has changed since my marriage. I need to update my file to list my spouse''s phone number and address as my primary emergency contact. I have filled out the digital form.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves update emergency contact information in my employee file. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Verify the update form, modify the emergency contact details in the HR database, and confirm with the employee.',
        0.95
    ),
    (
        'HR003',
        'Offboarding process and resignation intake interview scheduling',
        'I am writing to submit my formal resignation letter today. My last working day will be in 30 days. I need HR to schedule my resignation intake interview to discuss my offboarding checklist and handbook return.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves offboarding process and resignation intake interview scheduling. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Acknowledge the resignation, schedule the exit interview, and send the offboarding checklist link to the employee.',
        0.97
    ),
    (
        'HR003',
        'Clarification on company policy regarding personal blog posts',
        'I plan to start a personal technical blog about programming. I need HR to clarify our social media policy and confirm if I am allowed to write about general development practices as long as I don''t mention our company.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves clarification on company policy regarding personal blog posts. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Send the social media and corporate code of conduct policy documents to the employee, and clarify the blog rules.',
        0.94
    ),
    (
        'HR003',
        'Office noise complaint and acoustic policy concern on Floor 18',
        'The noise levels in the Floor 18 open office have become very high due to some sales team members holding long calls at their open desks. This is making it hard for developers to focus. Can we establish desk rules?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves office noise complaint and acoustic policy concern on floor 18. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Remind the office floor leads about the quiet zone rules, and encourage staff to use phone booths for calls.',
        0.93
    ),
    (
        'HR003',
        'Whistleblower report: Suspicious third-party procurement payments',
        'I wish to raise a confidential report under our whistleblower policy. I have noticed suspicious invoices and payments being approved for a vendor who is related to one of our procurement team members. Please investigate.',
        'HR',
        'high',
        'high',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves whistleblower report: suspicious third-party procurement payments. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Forward the report immediately to the audit committee, secure transaction logs, and maintain whistleblower confidentiality.',
        0.98
    ),
    (
        'HR003',
        'Employee Assistance Program (EAP) referral request for stress management',
        'I have been experiencing severe personal stress recently, which is starting to affect my sleep and focus at work. I want to access our confidential Employee Assistance Program counseling sessions. How do I register?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves employee assistance program (eap) referral request for stress management. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Provide the contact details for the external EAP provider, explain the confidentiality policy, and confirm registration status.',
        0.96
    ),
    (
        'HR003',
        'Requesting workplace accommodation for temporary disability support',
        'I broke my leg in an accident and will be using crutches for the next 6 weeks. I request a temporary change in desk location close to the Floor 18 elevators and a footrest to support my recovery.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves requesting workplace accommodation for temporary disability support. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Approve the desk change, coordinate with facilities to move the workstation, and deliver the footrest.',
        0.94
    ),
    (
        'HR003',
        'Feedback on recent company Year End Party organization',
        'I would like to submit some feedback regarding the venue and catering choices at our Year End Party last week. Several employees had food poisoning issues after the seafood buffet. We need to screen vendors better.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves feedback on recent company year end party organization. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Log the catering complaint, contact the event coordinator, and review vendor quality standards.',
        0.92
    ),
    (
        'HR003',
        'Lactation room reservation schedule adjustment on Floor 18',
        'I am returning to work next week and need to access the Floor 18 lactation room. I request access permissions to be added to my badge and want to coordinate the daily reservation calendar with other mothers.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves lactation room reservation schedule adjustment on floor 18. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Program the badge access for the lactation room, and add the employee to the shared booking calendar.',
        0.95
    ),
    (
        'HR003',
        'Office environment concern: Lack of recycling bins in open plan',
        'I noticed that we only have general waste bins in our new open-plan desk rows, which leads to many recyclable plastic bottles being thrown in the trash. Can HR coordinate with facilities to place recycling bins here?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves office environment concern: lack of recycling bins in open plan. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Forward the bin suggestion to the facilities team and confirm plan back to the employee.',
        0.91
    ),
    (
        'HR003',
        'Grievance report regarding promotion decision transparency',
        'I want to submit a formal grievance regarding the recent promotion decisions in our team. I believe the evaluation process lacked transparency and some team members were passed over despite meeting all criteria.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves grievance report regarding promotion decision transparency. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Schedule a meeting with the employee to discuss their concerns, and review the promotion criteria with the department lead.',
        0.94
    ),
    (
        'HR003',
        'Personal record update: New home address and tax residency status',
        'I have recently relocated to a new apartment in District 2 and need to update my residential address in my employee file. I also need to verify if this change affects my tax registration status.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves personal record update: new home address and tax residency status. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Verify the lease agreement, update the address in the HR database, and confirm with the employee.',
        0.95
    ),
    (
        'HR003',
        'Requesting sabbatical leave policy details and application process',
        'I have been with the company for 6 years and would like to apply for a 3-month sabbatical leave next year to pursue personal research. I need to know the eligibility rules and approval steps.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves requesting sabbatical leave policy details and application process. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Send the sabbatical leave policy document to the employee, and guide them on the director approval process.',
        0.93
    ),
    (
        'HR003',
        'Bereavement leave extension request due to international travel',
        'My grandfather passed away in Australia, and I need to travel next week to attend the funeral. The standard bereavement leave is 3 days, but due to travel, I request an extension of 5 days unpaid leave.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves bereavement leave extension request due to international travel. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Approve the leave extension under compassionate grounds, and update the payroll tracking file.',
        0.94
    ),
    (
        'HR003',
        'Religious holiday observance accommodation request for Eid',
        'I request a flexible working arrangement next week to observe the Eid holiday. I would like to work from home on Friday and make up the hours during the weekend. My team lead has approved the schedule.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves religious holiday observance accommodation request for eid. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Acknowledge the religious accommodation request and record the flexible work arrangement in the HRIS.',
        0.95
    ),
    (
        'HR003',
        'Work permit renewal documentation verification for foreign developer',
        'My work permit is set to expire in two months. I need HR''s employee relations team to help compile my degree certification, police check, and medical certificate to file the renewal application.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves work permit renewal documentation verification for foreign developer. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Review the submitted documents for immigration compliance, and submit the renewal application to the labor department.',
        0.96
    ),
    (
        'HR003',
        'Mental health first aider training participation request',
        'I want to participate in the upcoming ''Mental Health First Aider'' workshop to support my colleagues. I request HR to register me for the training session and send the pre-reading materials.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves mental health first aider training participation request. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Register the employee for the wellness workshop and send the training preparation files.',
        0.92
    ),
    (
        'HR003',
        'Suggesting a company-wide step count fitness challenge',
        'To encourage healthier habits, I suggest starting a company-wide steps challenge using an app where teams can compete. The winner could receive a health coupon. Can HR help organize this?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves suggesting a company-wide step count fitness challenge. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Review the steps challenge proposal, evaluate tracking apps, and pitch the program to the HR director.',
        0.92
    ),
    (
        'HR003',
        'Pronouns and preferred name update request in corporate directory',
        'I would like to update my preferred name and add my pronouns (she/her) to the corporate directory listing. Can HR update this in the backend database so it propagates to Slack and Gmail?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves pronouns and preferred name update request in corporate directory. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Update the employee''s preferred name and pronouns in the HR database and sync the active directory.',
        0.94
    ),
    (
        'HR003',
        'Expatriate relocation housing support coordination',
        'I will be transferring to our Vietnam office next month from the UK. I need HR''s employee relations specialist to guide me on corporate housing options, lease requirements, and local bank setup.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves expatriate relocation housing support coordination. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Send the expat onboarding guide, connect the employee with the housing agency, and coordinate target dates.',
        0.95
    ),
    (
        'HR003',
        'Social media code of conduct clarification request',
        'Our team is confused about the policy on posting photos from our team building event on our personal Instagram. Can HR confirm if we need signed consent forms from all members in the photo?',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves social media code of conduct clarification request. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Explain the social media photography guidelines to the employee, confirming verbal consent is sufficient for internal events.',
        0.93
    ),
    (
        'HR003',
        'Workplace conflict resolution advice request regarding project credit dispute',
        'Our marketing project lead and a senior designer have a dispute regarding credit allocation for the recent product launch campaign. I request HR''s guidance on how to facilitate a productive discussion.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves workplace conflict resolution advice request regarding project credit dispute. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Send the conflict resolution guide to the manager and offer a shadowing session to help facilitate.',
        0.94
    ),
    (
        'HR003',
        'Requesting copy of official whistleblower policy document',
        'I want to review the exact reporting channels and protection mechanisms specified under our corporate whistleblower policy. I cannot find the full document in the HR portal folder. Please provide a copy.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves requesting copy of official whistleblower policy document. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Email the latest approved corporate Whistleblower Policy PDF to the requesting employee.',
        0.95
    ),
    (
        'HR003',
        'Employee assistance program referral check for bereavement support',
        'An employee recently lost a family member and is struggling to cope. I want to check if our EAP covers specialized grief counseling and how to register the employee for urgent sessions.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves employee assistance program referral check for bereavement support. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Provide EAP grief counselor contact information to the manager and verify the session limits.',
        0.93
    ),
    (
        'HR003',
        'Anonymous feedback on workplace diversity and inclusion initiatives',
        'I would like to submit some anonymous suggestions regarding our D&I programs. I feel that our foreign team members are excluded from local culture events, and request translation services for cultural announcements.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves anonymous feedback on workplace diversity and inclusion initiatives. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Log the suggestion in the D&I committee backlog, and propose bilingual communications for cultural events.',
        0.94
    ),
    (
        'HR003',
        'Marital status change registration for health insurance records',
        'I got married last month and need to update my marital status from Single to Married in my corporate records. I also want to check if this updates my health insurance beneficiary options.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves marital status change registration for health insurance records. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Update the employee marital status in the HR database and share the dependent health insurance application form.',
        0.94
    ),
    (
        'HR003',
        'Lactation room booking calendar guidelines clarification',
        'We have had some conflicts regarding the lactation room usage slots on Floor 18. I request HR to share the official room guidelines and clarify if there is a daily time limit per person.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves lactation room booking calendar guidelines clarification. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Re-distribute the lactation room guidelines to registered users and verify the booking slot settings.',
        0.95
    ),
    (
        'HR003',
        'Flexible work arrangement proposal for long-term health recovery plan',
        'Following my doctor''s recommendation after back surgery, I request a flexible work arrangement to work from home three days a week for the next 3 months. I have attached the medical certification.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves flexible work arrangement proposal for long-term health recovery plan. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Verify the medical certificate details, coordinate with the team manager, and log the temporary arrangement.',
        0.96
    ),
    (
        'HR003',
        'Exit interview scheduling request for departing senior sales manager',
        'Our senior sales manager''s last day is next Friday. We request employee relations to schedule a 1-hour exit interview to discuss their feedback on team structure and hand over transition notes.',
        'HR',
        'low',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves exit interview scheduling request for departing senior sales manager. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Schedule the exit interview with the departing manager and share the exit survey link.',
        0.95
    ),
    (
        'HR003',
        'Expatriate repatriation logistics support request',
        'My assignment in the Hanoi branch is concluding and I am returning to our London office. I request HR''s assistance in coordinating my container shipping vendor, flight bookings, and tax de-registration.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves expatriate repatriation logistics support request. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Approve the shipping vendor quote, book the flight tickets, and coordinate tax exit filing with the tax consultant.',
        0.96
    ),
    (
        'HR003',
        'Workplace accommodation request for ergonomic seating after back surgery',
        'I am returning to work next week after spinal disk surgery. My doctor recommends an ergonomic office chair with lumbar support. I have attached the medical recommendation form. Please assist.',
        'HR',
        'medium',
        'low',
        'The ticket is categorized under HR003 (Employee Relations & Culture) floor 12A, as the issue involves workplace accommodation request for ergonomic seating after back surgery. The policy fit is appropriate since this team handles work environment feedback, internal workplace conflicts, and resignation procedures (excluding payroll, benefits, or training registration).',
        'Approve the ergonomic seating request and coordinate with facilities to purchase and place the chair.',
        0.95
    ),
    (
        'IT001',
        'Laptop battery swelling and warping the lower chassis',
        'I noticed this morning that the underside of my corporate MacBook Pro is bulging and the trackpad is hard to click. I think the battery is swelling and starting to warp the chassis. I have unplugged it and am worried about a potential fire hazard.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves laptop battery swelling and warping the lower chassis. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Safely decommission the swollen battery laptop, place it in a fire-safe container, and issue a replacement MacBook Pro to the employee.',
        0.98
    ),
    (
        'IT001',
        'Cracked screen on Lenovo ThinkPad after accidental drop',
        'My laptop slipped off the desk in the meeting room and landed on its side. The screen is now cracked with vertical lines running down the middle, making it impossible to read. The external monitor works, but I need to travel tomorrow.',
        'IT',
        'medium',
        'medium',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves cracked screen on lenovo thinkpad after accidental drop. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Assess the screen damage, swap the LCD panel if parts are in stock, or issue a temporary loaner laptop for the employee''s travel.',
        0.96
    ),
    (
        'IT001',
        'Loud grinding noise coming from desktop workstation cooling fan',
        'Every time I boot my workstation, there is a loud grinding noise that doesn''t go away. It sounds like one of the internal cooling fans is failing or scraping against a cable. I am worried the system might overheat during my rendering tasks.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves loud grinding noise coming from desktop workstation cooling fan. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Open the workstation chassis, check the fans for obstructions or bearing failure, and replace the failing fan unit.',
        0.95
    ),
    (
        'IT001',
        'Upgrade requests for additional 16GB RAM for local Docker development',
        'My current laptop only has 16GB of RAM and it keeps running out of memory when spinning up our microservices architecture locally. I need an upgrade to 32GB RAM so I can test my code without the system freezing.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves upgrade requests for additional 16gb ram for local docker development. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Check laptop model compatibility for RAM upgrade, verify budget approval, and schedule a time for the employee to drop off the laptop for installation.',
        0.94
    ),
    (
        'IT001',
        'Replacement needed for defective webcam showing distorted green colors',
        'During my video calls, the external USB webcam shows a highly distorted image with a strong green tint. I have tried updating drivers and plugging it into different USB ports, but the color issue persists. I need a replacement webcam.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves replacement needed for defective webcam showing distorted green colors. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Verify the defect, retrieve a new external webcam from inventory, and issue it to the employee while logging the serial number change.',
        0.93
    ),
    (
        'IT001',
        'Procurement of specialized mechanical keyboard for developer accessibility',
        'Due to recurring wrist strain, my doctor recommended I switch to an ergonomic split mechanical keyboard. I have the medical recommendation form ready and need to request the specific model recommended.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves procurement of specialized mechanical keyboard for developer accessibility. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Review the medical recommendation, check if the requested keyboard model is on the approved peripheral list, and place the procurement order.',
        0.92
    ),
    (
        'IT001',
        'Failed NVMe SSD drive causing boot failure on engineering workstation',
        'My office desktop workstation failed to boot this morning, showing a ''No Boot Device Found'' error message in the BIOS. I think the primary NVMe SSD drive has failed completely. I need my data recovered if possible.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves failed nvme ssd drive causing boot failure on engineering workstation. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Remove the NVMe SSD, test it in an external enclosure, perform data recovery if readable, and install a replacement drive with a fresh OS image.',
        0.97
    ),
    (
        'IT001',
        'Wireless mouse left click button completely unresponsive',
        'The left-click button on my corporate Logitech mouse stopped clicking today. It feels mushy and does not register any clicks on the screen. The right-click and scroll wheel work fine. Can I swap this for a new one?',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves wireless mouse left click button completely unresponsive. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Collect the broken mouse, update the inventory database to mark it as scrap, and hand a new wireless mouse to the employee.',
        0.95
    ),
    (
        'IT001',
        'Frayed USB-C laptop charger cable showing exposed copper wiring',
        'The USB-C cable on my laptop charger is starting to split near the connector, and I can see the copper wiring inside. It still charges sometimes, but I am worried about sparks or short-circuiting my laptop.',
        'IT',
        'high',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves frayed usb-c laptop charger cable showing exposed copper wiring. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Instruct the user to stop using the damaged charger immediately, discard it safely, and issue a new replacement charger.',
        0.96
    ),
    (
        'IT001',
        'External monitor power adapter emitting high-pitched whistling noise',
        'The power brick for my Dell external monitor is emitting a constant, high-pitched whistling sound whenever it is plugged in. It is very distracting to work next to, and I am concerned it might be a sign of component failure.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves external monitor power adapter emitting high-pitched whistling noise. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Swap the noisy power brick with a matching replacement adapter from inventory and send the old brick for disposal.',
        0.93
    ),
    (
        'IT001',
        'Asset tag recovery and verification for unlabeled warehouse scanner',
        'We have a Honeywell barcode scanner in the warehouse that doesn''t have an asset tag sticker. I need IT to look up the serial number in our database, verify ownership, and print a new asset tag sticker for it.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves asset tag recovery and verification for unlabeled warehouse scanner. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Search the serial number in the asset database, print the corresponding barcode asset tag, and apply it to the scanner.',
        0.94
    ),
    (
        'IT001',
        'Missing HDMI adapter from Floor 18 South conference room table',
        'I am trying to run a meeting in the South conference room on Floor 18, but the USB-C to HDMI adapter that is normally attached to the cable harness is missing. I cannot connect my laptop to the projector.',
        'IT',
        'medium',
        'medium',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves missing hdmi adapter from floor 18 south conference room table. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Retrieve a USB-C to HDMI adapter from storage, secure it to the conference table cable harness, and verify the display link.',
        0.92
    ),
    (
        'IT001',
        'Requesting privacy filter screen for HR payroll coordinator laptop',
        'As the payroll coordinator, I deal with highly confidential salary data on my screen daily. Since I work in an open office layout, I request a 14-inch physical privacy filter screen to prevent visual eavesdropping.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves requesting privacy filter screen for hr payroll coordinator laptop. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Check stock for a 14-inch privacy filter and deliver it to the payroll coordinator''s desk.',
        0.94
    ),
    (
        'IT001',
        'Overheating issues causing thermal throttling during software builds',
        'My laptop gets extremely hot to the touch and the CPU speed drops dramatically whenever I compile our code base. I think dust has built up inside the vents or the thermal paste needs to be reapplied.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves overheating issues causing thermal throttling during software builds. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Clean the dust out of the laptop''s internal cooling vents and fans, and re-apply high-quality thermal paste if necessary.',
        0.93
    ),
    (
        'IT001',
        'Broken plastic hinge on corporate laptop bag strap',
        'The plastic clip on my laptop shoulder strap snapped while I was walking to the office, causing the bag to drop. Fortunately, the laptop was not damaged, but I need a replacement strap or bag to transport it safely.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves broken plastic hinge on corporate laptop bag strap. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Issue a replacement shoulder strap or laptop bag to the employee from the inventory room.',
        0.91
    ),
    (
        'IT001',
        'Laptop keyboard missing physical key caps after key popped off',
        'The ''E'' key cap on my laptop keyboard popped off this morning and I cannot find it. The underlying switch still registers the letter when pressed, but it is extremely uncomfortable and slow to type on.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves laptop keyboard missing physical key caps after key popped off. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Check if a spare matching keycap can be fitted, or arrange for a keyboard panel replacement.',
        0.94
    ),
    (
        'IT001',
        'Headset microphone picking up constant background static noise',
        'During calls, my teammates complain that my voice is drowned out by a loud static buzzing sound. I have tested it on other devices and the static is still present. I need to swap this headset for a working one.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves headset microphone picking up constant background static noise. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Collect the defective headset, mark it for audit, and hand a new headset to the employee.',
        0.95
    ),
    (
        'IT001',
        'Requesting 1TB external SSD for offline media cache backup',
        'Our marketing team is starting a major video campaign and my local laptop drive is full of raw footage. I request a high-speed 1TB external SSD to cache and back up my project files offline.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves requesting 1tb external ssd for offline media cache backup. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Verify manager approval, retrieve a 1TB external SSD from stock, register it to the employee''s asset profile, and deliver it.',
        0.96
    ),
    (
        'IT001',
        'Damaged power pin in the barrel connector of loaner laptop charger',
        'I borrowed a loaner laptop for a business trip, but when I tried to plug in the charger, I noticed the center pin inside the barrel connector is bent and crushed. The laptop won''t charge. I need a working charger before my flight.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves damaged power pin in the barrel connector of loaner laptop charger. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Verify the barrel pin damage, retrieve a matching charger from loaner stock, and hand it to the traveler immediately.',
        0.97
    ),
    (
        'IT001',
        'Wobbly monitor stand mount causing screen to tilt sideways',
        'The mounting bracket on my dual monitor stand has become loose, and one of the screens keeps tilting down and to the right. I tried tightening it with a flat screwdriver but the screw thread appears to be stripped.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves wobbly monitor stand mount causing screen to tilt sideways. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Send a technician to the employee''s desk with a replacement monitor arm bracket or mount screw to secure the screen.',
        0.92
    ),
    (
        'IT001',
        'Requesting replacement desk pad and wrist rest due to wear and tear',
        'The wrist support on my keyboard wrist rest has split open, leaking gel, and my desk pad is heavily stained and frayed at the edges. I request a replacement set to maintain a clean workspace.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves requesting replacement desk pad and wrist rest due to wear and tear. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Approve the request and issue a new desk pad and ergonomic wrist rest to the employee.',
        0.9
    ),
    (
        'IT001',
        'Defective Thunderbolt 3 cable causing frequent dock disconnects',
        'The cable connecting my laptop to the docking station is loose. Any slight movement of my laptop causes the screens to go black and network connection to drop. I need a replacement high-speed Thunderbolt cable.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves defective thunderbolt 3 cable causing frequent dock disconnects. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Replace the defective Thunderbolt cable with a new one from inventory and test the dock link stability.',
        0.94
    ),
    (
        'IT001',
        'Hardware inventory return for departing contractor''s phone and tablet',
        'A contractor on our team has completed their project and left the company. I have their corporate iPhone and test iPad here. I need to return them to IT inventory so they can be wiped and reissued.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves hardware inventory return for departing contractor''s phone and tablet. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Record the return of the iPhone and iPad in the inventory tracking sheet, wipe the devices, and store them securely.',
        0.96
    ),
    (
        'IT001',
        'Liquid spill damage on external mechanical keyboard',
        'I accidentally spilled some sparkling water onto my mechanical keyboard. I unplugged it and wiped it down, but now several keys (Q, W, E, R) do not register at all. I need a replacement keyboard.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves liquid spill damage on external mechanical keyboard. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Decommission the damaged keyboard and issue a standard replacement keyboard to the employee.',
        0.94
    ),
    (
        'IT001',
        'Corporate tablet screen protector shattered after drop in warehouse',
        'One of our inventory tablets was dropped in the warehouse loading bay. The glass screen protector is shattered, although the LCD screen underneath seems intact. We need a new tempered glass screen protector installed.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves corporate tablet screen protector shattered after drop in warehouse. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Remove the shattered screen protector, verify LCD touch functionality, and install a new screen protector.',
        0.92
    ),
    (
        'IT001',
        'Damaged pins on VGA-to-DisplayPort converter cable in training room',
        'The display adapter cable in training room 1A has bent pins inside the connector. We cannot connect the podium computer to the projector for the upcoming onboarding session starting in 15 minutes.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves damaged pins on vga-to-displayport converter cable in training room. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Send an IT support specialist to the training room with a new adapter cable immediately to restore video feed.',
        0.96
    ),
    (
        'IT001',
        'Requesting dual monitor arms for new desk installation',
        'I have been assigned to a new desk, but it only has standard desktop stands which take up a lot of space. I request a dual monitor arm setup to free up workspace and allow vertical alignment.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves requesting dual monitor arms for new desk installation. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Deliver and install a dual monitor mount on the employee''s desk.',
        0.93
    ),
    (
        'IT001',
        'Replacement battery needed for wireless presenter clicker',
        'The laser pointer and advance buttons on the Logitech presenter remote in Room 3B are completely dead. I think the AAA batteries inside have drained. Can someone replace them or provide spares?',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves replacement battery needed for wireless presenter clicker. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Replace the AAA batteries in the presenter remote and check its operation.',
        0.91
    ),
    (
        'IT001',
        'Defective smart card reader preventing login keycard scans',
        'The USB smart card reader attached to my workstation is not lighting up or reading my login card when inserted. I tried connecting it to different USB ports but it seems completely dead. I need a replacement reader.',
        'IT',
        'medium',
        'medium',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves defective smart card reader preventing login keycard scans. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Verify device failure, replace the card reader from stock, and test smart card detection.',
        0.93
    ),
    (
        'IT001',
        'Loose power jack socket on corporate laptop board',
        'The charging port on my laptop has become loose. The charger cable plug wobbles inside and only charges when held at a specific angle. I am worried the connection will fail completely very soon.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves loose power jack socket on corporate laptop board. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Schedule a hardware diagnostic, open the laptop to inspect the power socket solder joints, or replace the mainboard.',
        0.95
    ),
    (
        'IT001',
        'Damaged carrying handle on primary field diagnostic kit case',
        'The plastic latch and handle on the rugged carrying case for our network diagnostic kit broke this morning. We cannot transport the delicate network analyzers safely without a secure case.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves damaged carrying handle on primary field diagnostic kit case. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Order a replacement rugged case or swap the equipment into a spare diagnostic kit container.',
        0.85
    ),
    (
        'IT001',
        'USB hub port failure on Floor 19 workspace docking station',
        'Three out of the four USB ports on my desk docking station have stopped working. Keyboard and mouse work, but USB drives or webcams plugged into the other ports are not detected by Windows. I need a replacement dock.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves usb hub port failure on floor 19 workspace docking station. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Swap the defective docking station with a new unit and update the asset inventory records.',
        0.94
    ),
    (
        'IT001',
        'Broken plastic clip on RJ-45 ethernet patch cord in cubicle 182',
        'The locking tab on the ethernet cable in my cubicle broke off, so the cable keeps falling out of the wall port. My connection drops every time I move my laptop. I need a new 3-meter patch cable.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT001 (Hardware Inventory & Equipment Provisioning) floor 18, as the issue involves broken plastic clip on rj-45 ethernet patch cord in cubicle 182. The policy fit is appropriate since this team handles physical hardware equipment, issuing new equipment, and replacing broken hardware (excluding network configuration, operating system issues, or account access problems).',
        'Provide a new 3-meter RJ-45 patch cable to the user''s cubicle.',
        0.91
    ),
    (
        'IT002',
        'DHCP pool exhaustion preventing Wi-Fi connections on Floor 17',
        'None of the team members on Floor 17 can connect to the office Wi-Fi this morning. Laptops are stuck on ''Obtaining IP address'' before failing. I suspect the DHCP scope for this subnet has run out of available addresses.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves dhcp pool exhaustion preventing wi-fi connections on floor 17. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Check the DHCP server lease tables for Floor 17 VLAN, release expired leases, or expand the subnet IP address pool.',
        0.98
    ),
    (
        'IT002',
        'Docker Desktop container networking error after bridge update',
        'After updating Docker Desktop on my macOS machine, my containers can no longer resolve any external internet addresses or reach local database services. The default docker0 bridge interface seems misconfigured.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves docker desktop container networking error after bridge update. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Reset Docker Desktop network settings, repair the vEthernet adapter interface, or reinstall the hypervisor backend.',
        0.94
    ),
    (
        'IT002',
        'Stale local DNS cache cache causing incorrect API routing errors',
        'I updated our staging server DNS records yesterday, but my local development machine is still resolving the old IP address, resulting in database connection errors. I have tried flushing my DNS, but it still fails.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves stale local dns cache cache causing incorrect api routing errors. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Verify upstream DNS records, check the client host file settings, and perform a deep flush of the OS and browser DNS cache.',
        0.95
    ),
    (
        'IT002',
        'Application crash: Microsoft Teams freezes during screen sharing',
        'Whenever I click ''Share Screen'' during a Teams presentation, the entire application freezes immediately and then crashes. I have cleared the Teams app cache and updated my graphics drivers, but the crash still happens.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves application crash: microsoft teams freezes during screen sharing. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Disable hardware acceleration in Teams settings, verify desktop environment display manager logs, or reinstall the Teams client.',
        0.96
    ),
    (
        'IT002',
        'Corporate proxy blocking outbound connections to AWS S3 endpoints',
        'My data pipeline script is failing with a timeout error. Looking at the logs, all HTTPS requests to s3.amazonaws.com are being blocked by the security proxy with a certificate warning. I need this endpoint allowlisted.',
        'IT',
        'medium',
        'medium',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves corporate proxy blocking outbound connections to aws s3 endpoints. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Check proxy logs for blocked S3 URLs and update the network gateway policy to allow access for the developer subnet.',
        0.97
    ),
    (
        'IT002',
        'VLAN routing misconfiguration isolating engineering testing subnet',
        'We cannot ping or access our hardware test bench devices from our workstation VLAN since the router upgrade last night. It seems the route table between VLAN 20 and VLAN 30 was omitted.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves vlan routing misconfiguration isolating engineering testing subnet. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Inspect core switch routing tables, restore the missing access control lists (ACLs) and routes, and verify ping connectivity.',
        0.98
    ),
    (
        'IT002',
        'Network switch port flap causing intermittent wired drops in Room 4A',
        'The ethernet port on the wall in Room 4A keeps disconnecting every few minutes. The connection light on the wall socket blinks green, goes amber, then turns off completely before repeating. WiFi works fine.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves network switch port flap causing intermittent wired drops in room 4a. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Check the switch interface logs for port flaps, test the patch panel connection, or move the room connection to a different switch port.',
        0.94
    ),
    (
        'IT002',
        'Outlook mailbox synchronization failure on macOS client',
        'My Outlook client on macOS has stopped downloading new emails. The status bar shows ''Sync Pending'' indefinitely. I can receive emails on the web client, so the issue is localized to my desktop app.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves outlook mailbox synchronization failure on macos client. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Clear the local Outlook cache, delete and rebuild the offline ost/database file, or re-add the Exchange account.',
        0.93
    ),
    (
        'IT002',
        'Figma desktop client showing blank screen after loading web assets',
        'When I open the Figma desktop application, it only displays a blank black window. The menu bar options are visible, but the workspace canvas doesn''t render. Reinstalling the app did not fix the problem.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves figma desktop client showing blank screen after loading web assets. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Clear the Figma local app data cache directory and disable GPU acceleration in the app configuration settings.',
        0.91
    ),
    (
        'IT002',
        'Internal server SSL certificate mismatch warning for database admin tool',
        'When accessing our db-admin tool on the internal network, Chrome blocks the page with an ''Invalid Common Name'' warning. The certificate seems to be issued for localhost rather than the domain name.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves internal server ssl certificate mismatch warning for database admin tool. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Generate a new internal CA certificate containing the correct Subject Alternative Name (SAN) and install it on the web server.',
        0.95
    ),
    (
        'IT002',
        'File permission denied error on corporate shared NAS volume',
        'I am trying to upload our campaign assets to the marketing folder on the shared NAS network drive, but I keep getting a ''Permission Denied'' or ''Write Access Required'' error, even though I am in the marketing group.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves file permission denied error on corporate shared nas volume. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Verify group permissions in Active Directory for the marketing share, and reset the inherited NTFS permissions on the target directory.',
        0.96
    ),
    (
        'IT002',
        'Antivirus software quarantining legitimate Python compile artifacts',
        'Every time I compile my local Python scripts containing C-extensions, the corporate antivirus software immediately quarantines the compiled .pyd files as a ''generic malware'' threat. This blocks my local testing.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves antivirus software quarantining legitimate python compile artifacts. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Inspect the security agent logs, add the developer local build directory to the scan exclusion path, and restore the quarantined files.',
        0.94
    ),
    (
        'IT002',
        'Stuck network print job blocking marketing brochure prints on Floor 18',
        'The queue for the marketing team network printer has a PDF document stuck in the ''Deleting'' state. No other jobs can process, and a long queue is building up. Can someone purge the print spooler?',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves stuck network print job blocking marketing brochure prints on floor 18. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Log in to the print server, stop the spooler service, manually delete the stuck spl files, and restart the service.',
        0.95
    ),
    (
        'IT002',
        'IntelliJ license server connection timeout on developer subnet',
        'My IntelliJ IDE is showing an activation error because it cannot reach our internal license server at license.corp.internal. This is blocking all developers on Floor 19 from compiling code.',
        'IT',
        'medium',
        'medium',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves intellij license server connection timeout on developer subnet. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Verify license server process status, check firewall routing tables for port 27017, and restart the license server service.',
        0.96
    ),
    (
        'IT002',
        'Git SSH connection timeout when pushing to internal server',
        'When pushing commits to git.corp.internal, I get a ''Connection timed out'' error over SSH. HTTPS pushes work fine, so the issue seems specific to the SSH port 22 access on the engineering subnet.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves git ssh connection timeout when pushing to internal server. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Check the core network firewall rules for SSH port 22 to the Git server, and verify route tables for the subnet.',
        0.93
    ),
    (
        'IT002',
        'Terraform backend state lock error preventing deployment',
        'Our CI/CD pipeline failed because our state file on AWS S3 is locked by an old running process. I need someone with administrative access to force unlock the state in our DynamoDB lock table.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves terraform backend state lock error preventing deployment. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Look up the lock ID in DynamoDB, verify no active pipeline is running, and run the terraform force-unlock command.',
        0.92
    ),
    (
        'IT002',
        'Corporate proxy blocking API requests to external test sandbox',
        'Our application needs to call the Sandbox API at api-sandbox.paymentgateway.com, but the corporate gateway proxy blocks it with an SSL interception error. We need this API domain added to the bypass list.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves corporate proxy blocking api requests to external test sandbox. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Configure the proxy server bypass list to allow direct outbound connections to the payment sandbox domain.',
        0.95
    ),
    (
        'IT002',
        'Bandwidth throttling or high latency on employee Wi-Fi in canteen',
        'The employee Wi-Fi in the canteen area is extremely slow today. Ping times to internal servers are over 500ms and web pages fail to load. This makes it impossible to check mail or chats during lunch.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves bandwidth throttling or high latency on employee wi-fi in canteen. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Check client counts on the canteen APs, inspect bandwidth usage logs for hogging processes, and adjust QoS bandwidth limiters.',
        0.92
    ),
    (
        'IT002',
        'NTP synchronization drift causing authentication failures',
        'My workstation clock is drifting and is currently 6 minutes behind real-time. This drift is causing Active Directory login handshakes to fail with a Kerberos time deviation error. I need to re-sync with the NTP server.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves ntp synchronization drift causing authentication failures. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Reset the Windows Time service configuration, force a sync with time.windows.com, and check domain NTP group policy.',
        0.94
    ),
    (
        'IT002',
        'Citrix virtual desktop session frozen and unresponsive',
        'My virtual desktop session has completely locked up. The mouse cursor doesn''t move and keystrokes don''t register. Closing the Citrix receiver window and logging back in just restores the same frozen state.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves citrix virtual desktop session frozen and unresponsive. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Locate the user''s active session in the Citrix console, terminate it completely to clear the cache, and initiate a new login.',
        0.95
    ),
    (
        'IT002',
        'Log aggregation pipeline failure in Elastic logstash node',
        'Our production logs are not appearing in Kibana. The logstash daemon is running out of memory due to a flood of syslog events from the network core. We need to allocate more heap space or drop debug logs.',
        'IT',
        'high',
        'medium',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves log aggregation pipeline failure in elastic logstash node. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Increase the JVM heap allocation on the logstash cluster nodes, filter out debug events, and restart the service.',
        0.96
    ),
    (
        'IT002',
        'Grafana dashboard metrics not updating due to Prometheus timeout',
        'All panels on the database monitoring dashboard in the office display ''No Data''. The underlying Prometheus server is timing out while scraping targets on the staging network segment.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves grafana dashboard metrics not updating due to prometheus timeout. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Verify the Prometheus scrap configuration, check the network route to the targets, and restart the scraping engine.',
        0.94
    ),
    (
        'IT002',
        'Jira server response time degradation on office connection',
        'Jira is taking over 30 seconds to load individual issue pages when connected from the office LAN, but works fine over cellular network. This suggests an issue with the DNS routing or proxy cache on the office network.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves jira server response time degradation on office connection. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Inspect the office gateway proxy cache hit rate, check traceroutes to the Jira server, and flush proxy dns tables.',
        0.93
    ),
    (
        'IT002',
        'Corporate VPN client failing to establish tunnel on macOS Sonoma',
        'After upgrading my MacBook to macOS Sonoma, the GlobalProtect VPN client fails to connect, showing a ''Security policy blocking connection'' error. The system security permissions need adjustment.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves corporate vpn client failing to establish tunnel on macos sonoma. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Allow the GlobalProtect system extension in macOS System Settings under Security, and reinstall the VPN client if needed.',
        0.95
    ),
    (
        'IT002',
        'Local Postgres service failing to start due to lockfile block',
        'My local PostgreSQL installation crashed, and now it refuses to restart, showing an error about a lockfile postmaster.pid already existing. I need assistance in safely removing the lock file and verifying database integrity.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves local postgres service failing to start due to lockfile block. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Delete the postmaster.pid lockfile, verify log outputs, and start the PostgreSQL database cluster service.',
        0.88
    ),
    (
        'IT002',
        'Blue Screen of Death (BSOD) loop on HR laptop after Windows patch',
        'My corporate laptop installed updates last night and now it is stuck in a boot loop showing a Blue Screen of Death with the error code ''INACCESSIBLE_BOOT_DEVICE''. I cannot reach the desktop.',
        'IT',
        'high',
        'medium',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves blue screen of death (bsod) loop on hr laptop after windows patch. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Boot into safe mode, uninstall the latest cumulative updates, rebuild the boot sector configuration, and check disk health.',
        0.97
    ),
    (
        'IT002',
        'Linux GRUB bootloader menu missing after dual-boot installation',
        'I tried to set up dual-boot on my test laptop, but now the machine boots directly into Windows without displaying the GRUB bootloader menu. I cannot boot into Ubuntu to run my tests.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves linux grub bootloader menu missing after dual-boot installation. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Boot from an Ubuntu live USB, run boot-repair to reinstall the GRUB bootloader in EFI system partition, and update GRUB configurations.',
        0.92
    ),
    (
        'IT002',
        'Shared network drive folder disconnecting after sleep mode',
        'Whenever my laptop wakes up from sleep mode, my mapped network drives show a red cross and are inaccessible until I manually disconnect and map them again. This is very tedious.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves shared network drive folder disconnecting after sleep mode. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Update registry settings to delay network drive persistence checks, and verify NIC power management sleep settings.',
        0.94
    ),
    (
        'IT002',
        'Antivirus scanning engine causing 100% CPU spikes during meetings',
        'The corporate security agent runs full disk scans in the middle of the workday, causing my CPU utilization to spike to 100% and freezing my web camera during video calls. Can we schedule these scans for overnight?',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves antivirus scanning engine causing 100% cpu spikes during meetings. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Modify the antivirus agent scan policy group policy to trigger full system scans outside core working hours (e.g., 9 PM to 6 AM).',
        0.93
    ),
    (
        'IT002',
        'Developer subnet unable to pull node base images from Docker Hub',
        'Our CI runner is throwing a timeout error while pulling node:18-alpine from Docker Hub. Other subnets can pull normal images, so this looks like a gateway restriction specific to the developer VLAN.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves developer subnet unable to pull node base images from docker hub. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Examine firewall logs for traffic from CI runners to Docker registry domains, and verify outbound NAT configs.',
        0.96
    ),
    (
        'IT002',
        'Corporate Slack client notification delays on macOS Sonoma client',
        'I am experiencing delays of up to 10 minutes for Slack message notifications on my desktop. I receive them on my phone instantly, but the macOS desktop app notification daemon seems hung.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves corporate slack client notification delays on macos sonoma client. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Restart the macOS Notification Center agent service, check Slack notification permission settings, and clear application cache.',
        0.92
    ),
    (
        'IT002',
        'Local virtual host settings causing redirect loops in local Apache',
        'After configuring a new local Apache virtual host for our intranet development, accessing dev.intranet.local results in an infinite HTTP 301 redirect loop. I need someone to check my rewrite rules.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves local virtual host settings causing redirect loops in local apache. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Inspect the Apache virtual host config file and .htaccess rewrite rules, fix the loop condition, and restart Apache.',
        0.82
    ),
    (
        'IT002',
        'Network latency spikes during file transfers to cloud backup',
        'Our file backup scripts start transferring raw archives to the cloud at 3 PM, which completely saturates our office bandwidth. All Zoom calls drop packets. We need to schedule this for after-hours.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT002 (Network Infrastructure & System Software Support) floor 18, as the issue involves network latency spikes during file transfers to cloud backup. The policy fit is appropriate since this team handles network configuration, operating system installation, internal software errors, and Wi-Fi or VPN connectivity (excluding physical hardware, account credentials, password resets, or security incidents).',
        'Reschedule the backup cron job to run at midnight, or apply bandwidth limits to the backup tool traffic on the gateway.',
        0.94
    ),
    (
        'IT003',
        'Suspected phishing campaign targeting executive team accounts',
        'Several executives have received an email claiming to be from the CEO requesting them to sign a confidential document via a suspicious external link. The sender address is ceo@corporate-mail-update.com, which is fake. I am raising an alert.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves suspected phishing campaign targeting executive team accounts. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Block the sender domain on the email gateway, delete the email from all user mailboxes, and issue an alert to the staff.',
        0.99
    ),
    (
        'IT003',
        'Active Directory account locked after multiple failed logins',
        'My corporate Active Directory account is locked. I got locked out after mistyping my password three times this morning. I cannot log in to my laptop, Outlook, or Slack. I need my account unlocked.',
        'IT',
        'high',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves active directory account locked after multiple failed logins. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Verify employee identity, unlock the AD account, and prompt the user to trigger a self-service password reset if needed.',
        0.98
    ),
    (
        'IT003',
        'MFA reset request for Okta after changing physical phone',
        'I got a new iPhone yesterday and I cannot set up Okta Verify because my old device is registered. I am locked out of all corporate apps because MFA is prompt-blocked. Please reset my Okta MFA token.',
        'IT',
        'high',
        'medium',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves mfa reset request for okta after changing physical phone. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Verify user identity via secondary channel (e.g., manager confirmation), reset the Okta MFA status, and monitor enrollment.',
        0.97
    ),
    (
        'IT003',
        'Malware alert triggered on engineering sandbox test server',
        'Our monitoring console shows a high-severity malware detection alert on our sandbox server (IP 10.190.22.45). It seems a test script downloaded an unauthorized binary that triggered the endpoint detection signature.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves malware alert triggered on engineering sandbox test server. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Isolate the sandbox server from the network segment, collect file hashes, perform forensic scan, and clean the threat.',
        0.98
    ),
    (
        'IT003',
        'Provisioning system access permissions for incoming backend engineer',
        'We have a new backend engineer joining the team next Monday. I need to request creation of their Active Directory account, provisioning of access to GitHub, AWS developer role, and corporate Slack channels.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves provisioning system access permissions for incoming backend engineer. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Create the AD account, configure Okta dashboard tiles, invite the user to GitHub organization, and grant AWS roles.',
        0.96
    ),
    (
        'IT003',
        'Revoking access credentials for offboarded contractor immediately',
        'A contractor was terminated today and we need to immediately revoke all their corporate access permissions. Please lock their AD account, terminate Okta sessions, and revoke access to GitHub and AWS.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves revoking access credentials for offboarded contractor immediately. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Disable the AD account, invalidate all active sessions in Okta, disable the user in Google Workspace, and remove from GitHub.',
        0.99
    ),
    (
        'IT003',
        'Requesting AWS administrative console privilege elevation',
        'I need temporary administrative access to the AWS production console to apply a database schema update for the release. My manager has approved this elevation for a 4-hour window starting at 8 PM.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves requesting aws administrative console privilege elevation. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Check the manager approval log, configure a temporary IAM policy with a 4-hour automatic expiration, and audit access.',
        0.95
    ),
    (
        'IT003',
        'Requesting access to shared company mailbox for finance support team',
        'Our finance team needs access to the shared mailbox finance-inquiries@company.com to monitor invoicing questions. There are 3 staff members who need delegation permissions added in Exchange Online.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves requesting access to shared company mailbox for finance support team. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Add the 3 requested users to the Outlook shared mailbox access group in Exchange Admin Center.',
        0.94
    ),
    (
        'IT003',
        'API token rotation verification for third-party shipping gateway',
        'Our shipping integration API token is scheduled for rotation next Tuesday. I need security to coordinate the key rotation process, generate a new client secret, and verify the hashing algorithm complies with policy.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves api token rotation verification for third-party shipping gateway. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Generate the new API key, configure it in the secret vault, and audit key access logs during transition.',
        0.93
    ),
    (
        'IT003',
        'IP allowlisting request for client staging database access',
        'We need to allow connections to our staging database from the IP address of our client''s office (203.113.12.4). We need to update the network security group rules on AWS to allow this ingress.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves ip allowlisting request for client staging database access. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Add the client''s IP address to the AWS SG staging rule for database access on port 5432 and verify security approval.',
        0.94
    ),
    (
        'IT003',
        'Requesting VPN connection geobypass exception for business trip',
        'I am traveling to Singapore on a business trip next week. Our zero-trust network policies normally block logins from outside our home country. I request a temporary location exception in Okta for 5 days.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves requesting vpn connection geobypass exception for business trip. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Verify travel approval, add a temporary geo-blocking policy exception in Okta for the user''s account, and set an expiration date.',
        0.95
    ),
    (
        'IT003',
        'Encrypted corporate USB drive policy exception request',
        'I need to copy offline software installers to our air-gapped test system. Standard USB ports are blocked by our endpoint agent. I request a policy exception to authorize one encrypted corporate USB drive.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves encrypted corporate usb drive policy exception request. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Review the justification, assign a hardware-encrypted USB drive, and whitelist the device ID in the MDM security policy.',
        0.92
    ),
    (
        'IT003',
        'Registering personal smartphone in corporate BYOD MDM program',
        'I want to access my corporate emails and calendar on my personal iPhone. I need security to send me the enrollment link for the Mobile Device Management (MDM) profile so my device is compliant.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves registering personal smartphone in corporate byod mdm program. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Send the MDM enrollment invitation link to the user and monitor device compliance status in Microsoft Intune.',
        0.93
    ),
    (
        'IT003',
        'Security compliance review for third-party feedback software',
        'Our team wants to purchase a feedback collection SaaS tool called SurveyApp. I need security to perform a risk assessment on their data encryption at rest, GDPR compliance, and fill out our vendor checklist.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves security compliance review for third-party feedback software. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Obtain the SaaS vendor SOC2 report, review their data privacy policy, and complete the security risk assessment form.',
        0.94
    ),
    (
        'IT003',
        'Resetting security answers for corporate portal account',
        'I forgot my security recovery answers for the internal HR portal and cannot change my password. I need someone to reset my security questions so I can choose new ones upon my next login.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves resetting security answers for corporate portal account. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Verify identity over a voice call, clear the security question hashes in the portal user DB, and notify the employee.',
        0.89
    ),
    (
        'IT003',
        'PCI-DSS database audit log export request for annual certification',
        'For our upcoming PCI-DSS audit, we need to export the administrative access logs for the main payment database from March 1st to May 31st. The auditor requires these logs in a tamper-evident CSV format.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves pci-dss database audit log export request for annual certification. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Extract the administrative database audit logs from AWS CloudWatch, verify cryptographic signatures, and export them safely.',
        0.95
    ),
    (
        'IT003',
        'Investigating unauthorized logins from outside office hours',
        'Our audit logs detected two successful logins to our internal billing system using my account credentials last night at 3 AM. I was asleep at that time. I suspect my credentials may have been compromised.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves investigating unauthorized logins from outside office hours. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Immediately disable the compromised user account, terminate all active web sessions, and check login IP addresses in audit logs.',
        0.98
    ),
    (
        'IT003',
        'Renewing code signing certificate for desktop application release',
        'The code signing certificate used for signing our Windows desktop installer is set to expire in two weeks. We need to generate a new key pair on our hardware security module (HSM) and get it signed.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves renewing code signing certificate for desktop application release. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Generate a new key pair on the HSM, submit the CSR to the CA provider, sign the new release, and verify validity.',
        0.96
    ),
    (
        'IT003',
        'Active Directory group policy modification for desktop lock screen timeout',
        'We need to update our security policy for the office laptops. The lock screen timeout should be reduced from 15 minutes to 5 minutes to prevent unauthorized access when users step away from their desks.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves active directory group policy modification for desktop lock screen timeout. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Update the GPO configuration for screen lock timeout in Active Directory and verify propagation to test laptops.',
        0.93
    ),
    (
        'IT003',
        'Retrieving BitLocker recovery key for locked laptop after BIOS update',
        'After a bios update, my Dell laptop booted into the BitLocker recovery screen, asking for a 48-digit recovery key. I do not have this key. I cannot access Windows.',
        'IT',
        'high',
        'medium',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves retrieving bitlocker recovery key for locked laptop after bios update. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Look up the computer''s active directory object ID in Active Directory Users and Computers, retrieve the BitLocker key, and dictate it.',
        0.97
    ),
    (
        'IT003',
        'Coordination support for annual ransomware response dry-run simulation',
        'We are planning our annual crisis response exercise for October. We need security to coordinate the testing scenario, simulate a ransomware outbreak on our staging network, and test IT notification chains.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves coordination support for annual ransomware response dry-run simulation. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Draft the ransomware scenario timeline, prepare simulated communications, and coordinate roles with department leads.',
        0.92
    ),
    (
        'IT003',
        'User access review audit for Jira database compliance',
        'For the upcoming SOC2 audit, we need to verify all active user accounts in Jira and ensure there are no orphaned accounts belonging to past contractors. Please provide the monthly access review sheet.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves user access review audit for jira database compliance. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Generate a list of active users in Jira, cross-reference with active employees in HRIS, and highlight differences.',
        0.94
    ),
    (
        'IT003',
        'Unlocking corporate Google Drive folder access for external auditor',
        'Our external legal team needs access to a specific Google Drive folder containing regulatory documents. Since global sharing settings are restricted, we need security to whitelist their domain name.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves unlocking corporate google drive folder access for external auditor. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Add the external domain to the approved Google Workspace sharing list and authorize the folder share.',
        0.93
    ),
    (
        'IT003',
        'Offboarding request: Revoking corporate G Suite and Slack access',
        'An employee is leaving the company at the end of the day. Please schedule the automatic suspension of their Google Workspace account, removal from corporate Slack, and deletion of their VPN profiles.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves offboarding request: revoking corporate g suite and slack access. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Schedule the AD and Google Workspace account disabling commands to execute at 5 PM on the departure date.',
        0.96
    ),
    (
        'IT003',
        'Single Sign-On (SSO) integration request for new internal wiki platform',
        'We are launching a new team documentation site and want to integrate it with Okta so employees can log in using their standard credentials. We need an OIDC application client ID and secret generated.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves single sign-on (sso) integration request for new internal wiki platform. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Configure a new application in Okta, define access claims, and share the OIDC credentials securely with the developers.',
        0.95
    ),
    (
        'IT003',
        'Phishing simulation campaign setup request for Q3 awareness training',
        'We need to schedule the quarterly mock phishing campaign to test our employees'' security awareness. Please set up the template using the fake Microsoft password reset email and configure the tracking metrics.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves phishing simulation campaign setup request for q3 awareness training. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Select the phishing template, upload the employee distribution list, and schedule the campaign execution.',
        0.93
    ),
    (
        'IT003',
        'Investigating suspicious login locations flagged by Okta risk engine',
        'Okta triggered a high-risk security alert for an employee account showing a successful login from Warsaw, Poland, followed 10 minutes later by a login from Hanoi. This looks like a session hijacking attempt.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves investigating suspicious login locations flagged by okta risk engine. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Immediately terminate all active sessions for the flagged account, force password reset, and verify the traveler''s location.',
        0.98
    ),
    (
        'IT003',
        'Requesting access log review for shared file containing server secrets',
        'A text file containing database passwords was accidentally committed to a shared folder. We have removed the file, but we need security to check the server logs to see if anyone downloaded it.',
        'IT',
        'high',
        'medium',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves requesting access log review for shared file containing server secrets. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Inspect the file server access audit logs, list all user accounts that accessed the file, and recommend password rotations.',
        0.96
    ),
    (
        'IT003',
        'Third-party developer security assessment review request',
        'We are outsourcing database work to an external agency. Before we share access to our API documentation, we need security to verify their developers have signed the NDA and completed our background check.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves third-party developer security assessment review request. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Check the signed NDA records, verify the background check status, and approve the partner onboarding status.',
        0.94
    ),
    (
        'IT003',
        'DKIM / SPF record mismatch causing corporate emails to bounce',
        'Our marketing emails are bouncing from external client servers. The bounce-back messages report that our domain''s SPF record is missing the new SendGrid mailing IP address, causing mail checks to fail.',
        'IT',
        'medium',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves dkim / spf record mismatch causing corporate emails to bounce. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Update the TXT DNS record for corporate SPF to include SendGrid, and check DKIM selector validation.',
        0.95
    ),
    (
        'IT003',
        'Requesting user permission group change in Active Directory',
        'I have been promoted to marketing manager, and I need access to the budget planning files in the finance AD share. Please update my AD group membership from marketing-staff to marketing-leads.',
        'IT',
        'low',
        'low',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves requesting user permission group change in active directory. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Verify manager approval, add the user account to the marketing-leads security group in Active Directory.',
        0.94
    ),
    (
        'IT003',
        'SSO certificate renewal deadline warning in Okta admin console',
        'The certificate used for signing SAML requests between Okta and our billing portal is set to expire in 48 hours. If it expires, users will not be able to log in to the billing portal. We need a new certificate.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves sso certificate renewal deadline warning in okta admin console. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Generate a new SAML signing certificate in Okta, upload it to the billing portal SAML metadata settings, and test authentication.',
        0.98
    ),
    (
        'IT003',
        'DLP alert triggered by mass file download from accounting database',
        'Our Data Loss Prevention tool detected a mass download of tax invoices (over 500 documents) from the accounting database by an analyst account. This activity is outside their normal access baseline.',
        'IT',
        'high',
        'high',
        'The ticket is categorized under IT003 (Account & Cyber Security) floor 19, as the issue involves dlp alert triggered by mass file download from accounting database. The policy fit is appropriate since this team handles employee login accounts, information security, password resets, and account provisioning (excluding network connectivity problems or software installation).',
        'Temporarily suspend the analyst''s login account, verify the business reason for the download, and check file transfers.',
        0.97
    );

-- ----------------------------------------------------------------
-- AI Evaluation Cases
-- ----------------------------------------------------------------

INSERT INTO ai_evaluation_cases (
    id,
    test_title,
    input_snapshot,
    expected_category,
    expected_urgency,
    expected_sla_breach_risk,
    created_at,
    updated_at,
    created_by,
    updated_by
) VALUES
    (
        1,
        'Rule Engine - Hardware failure - IT001',
        '{"id":101,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"monitor not working in dev003 on Floor 18","description":"The external monitor not working and is completely black when plugged into the laptop. I need a replacement immediately.","priority":"high","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-25T10:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T07:30:00+07:00","events":[]}',
        'IT001',
        'high',
        'high',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        2,
        'Rule Engine - Network down - IT002',
        '{"id":102,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"no internet connection in Room dev001 on Floor 12A","description":"Suddenly there is no internet connection at my desk on Floor 12A. Both Wi-Fi and ethernet cable are disconnected.","priority":"high","status":"new","created_at":"2026-06-25T08:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-25T14:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T09:00:00+07:00","events":[]}',
        'IT002',
        'high',
        'medium',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        3,
        'Rule Engine - HR benefits - HR001',
        '{"id":103,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Request for dependent declaration support on Floor 12A","description":"I need to submit my dependent declaration for personal income tax deduction. Could someone from HR guide me on this? I am working in Room fin001 on Floor 12A.","priority":"low","status":"new","created_at":"2026-06-25T09:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-27T09:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T10:00:00+07:00","events":[]}',
        'HR001',
        'low',
        'low',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        4,
        'Rule Engine - Facilities leak - FC001',
        '{"id":104,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Urgent water leak coming from the ceiling on Floor 18","description":"There is a sudden water leak coming from the ceiling panels in the Floor 18 lounge room. Water is dripping close to electric wires.","priority":"high","status":"new","created_at":"2026-06-25T11:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-25T15:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T14:30:00+07:00","events":[]}',
        'FC001',
        'high',
        'high',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        5,
        'Rule Engine - Pantry supplies - FC003',
        '{"id":105,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Requesting pantry restock on Floor 18","description":"We need a pantry restock for Floor 18. There are no coffee cups or sugar left in the pantry lounge.","priority":"low","status":"new","created_at":"2026-06-25T12:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-27T12:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T13:00:00+07:00","events":[]}',
        'FC003',
        'low',
        'low',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        6,
        'Similarity Match - Water leak boardroom - FC001',
        '{"id":106,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Severe water leak coming from the ceiling in Floor 18 boardroom","description":"During the heavy rainstorm, water started gushing out from the ceiling panels in the Floor 18 boardroom. It is dripping directly onto the conference table and video equipment. We need a plumber and buckets immediately.","priority":"high","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-25T10:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T09:30:00+07:00","events":[]}',
        'FC001',
        'high',
        'high',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        7,
        'Similarity Match - OT payslip correction - HR001',
        '{"id":107,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Discrepancy in monthly overtime (OT) hours payment in June payslip","description":"I reviewed my payslip for June and noticed that my approved overtime hours from the system deployment on June 15th (totaling 8 hours at double rate) were not paid. My manager approved the hours, but they seem to be missing.","priority":"medium","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-26T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'HR001',
        'medium',
        'medium',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        8,
        'Similarity Match - DHCP pool Wi-Fi - IT002',
        '{"id":108,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"DHCP pool exhaustion preventing Wi-Fi connections on Floor 17","description":"None of the team members on Floor 17 can connect to the office Wi-Fi this morning. Laptops are stuck on ''Obtaining IP address'' before failing. I suspect the DHCP scope for this subnet has run out of available addresses.","priority":"high","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-25T10:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T09:30:00+07:00","events":[]}',
        'IT002',
        'high',
        'high',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        9,
        'Similarity Match - Annual leave corrects - HR001',
        '{"id":109,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Query regarding annual leave balance correction after system migration","description":"My annual leave balance in the self-service portal is showing only 8 days remaining, but according to my records and last month payslip, I should have 12 days. I suspect the recent HRIS migration did not import my carry-over leave.","priority":"low","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-28T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'HR001',
        'low',
        'low',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        10,
        'Similarity Match - Docker Desktop network - IT002',
        '{"id":110,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Docker Desktop container networking error after bridge update","description":"After updating Docker Desktop on my macOS machine, my containers can no longer resolve any external internet addresses or reach local database services. The default docker0 bridge interface seems misconfigured.","priority":"medium","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-26T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'IT002',
        'medium',
        'medium',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        11,
        'AI Fallback - Unauthorized access log - IT003',
        '{"id":111,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Suspicious logs showing unauthorized remote desktop access attempts on server","description":"While checking the daily access logs of the security jumpbox, I found several repeated connection attempts from an external IP during non-working hours. Needs security analysis. I am sitting in Room dev004 on Floor 18.","priority":"high","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-25T10:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T09:30:00+07:00","events":[]}',
        'IT003',
        'high',
        'high',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        12,
        'AI Fallback - Go learning path - HR002',
        '{"id":112,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Requesting information on standard learning path for backend engineers","description":"Our new junior backend developers need access to the company learning platform and information about available courses for Go development. We are in Room dev001 on Floor 12A.","priority":"low","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-27T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'HR002',
        'low',
        'low',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        13,
        'AI Fallback - Cabinet hinge broken - FC001',
        '{"id":113,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Cabinet door hinges are completely broken in Floor 12A pantry","description":"The main cabinet door under the sink in the Floor 12A pantry has come off its hinges and is hanging loose. It blocks the trash bin access.","priority":"medium","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-26T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'FC001',
        'medium',
        'medium',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        14,
        'AI Fallback - Exit review guidelines - HR003',
        '{"id":114,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Inquiring about offboarding guidelines and checklist details for managers","description":"I need to understand the proper steps and checklist for conducting an exit review with a departing team member. Could HR send the current manager handbook? I''m in Room fin001 on Floor 12A.","priority":"low","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-27T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'HR003',
        'low',
        'low',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        15,
        'AI Fallback - USB-C to HDMI adapter - IT001',
        '{"id":115,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Requesting standard adapter cable for connecting new display screen","description":"I received a new display monitor but my laptop only has USB-C ports while the monitor has HDMI. I need a USB-C to HDMI adapter cable. I am working at Room qa002 on Floor 18.","priority":"medium","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-26T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'IT001',
        'medium',
        'medium',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        16,
        'Flex - Overdue payroll tax - HR001',
        '{"id":116,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Salary payment query regarding tax calculation formula error","description":"My monthly salary slip shows an incorrect tax calculation. I need assistance from Compensation & Benefits to review my tax bracket. Sitting in Room fin001 on Floor 12A.","priority":"medium","status":"new","created_at":"2026-06-24T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-25T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T09:30:00+07:00","events":[]}',
        'HR001',
        'medium',
        'overdue',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        17,
        'Flex - Book corporate vehicle - FC002',
        '{"id":117,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Corporate vehicle reservation for visiting client group tomorrow","description":"We need to book a company car to pick up a group of international partners from the airport tomorrow afternoon. Requesting scheduling help from Room qa001 on Floor 12A.","priority":"medium","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-26T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'FC002',
        'medium',
        'medium',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        18,
        'Flex - Statistical software installation - IT002',
        '{"id":118,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Requesting installation of specialized statistical software package","description":"I need to install a licensed copy of RStudio/SPSS on my work machine to run statistical models. Can IT assist with software installation? I am in Room ds001 on Floor 12A.","priority":"medium","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-26T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'IT002',
        'medium',
        'medium',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        19,
        'Flex - corridor light replace - FC001',
        '{"id":119,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":null,"title":"Replacement of ceiling light tubes in Floor 19 corridor","description":"Two of the fluorescent light tubes in the main hallway of Floor 19 are flickering and turning off. It makes the hallway very dim near Room pmo001 on Floor 19.","priority":"low","status":"new","created_at":"2026-06-25T07:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-27T07:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[]}',
        'FC001',
        'low',
        'low',
        NOW(),
        NOW(),
        'system',
        'system'
    ),
    (
        20,
        'Flex - Mouse replacement - IT001',
        '{"id":120,"requestor_id":"0a5389df-ba3a-4494-a095-126d05c7c2e7","assignee_id":"9ee00625-0436-4f11-8bb1-b9e4f3f7bf88","title":"On-call mouse replacement request on Floor 18","description":"Developer mouse is broken in Room dev003 on Floor 18. Requesting a standard office supply replacement.","priority":"low","status":"assigned","created_at":"2026-06-25T09:00:00+07:00","resolved_at":null,"sla_due_at":"2026-06-26T16:00:00+07:00","cancelled_at":null,"evaluation_current_time":"2026-06-25T15:30:00+07:00","events":[{"id":1,"ticket_id":120,"from_status":"new","to_status":"assigned","requestor_id":"procurement-team","assignee_id":"9ee00625-0436-4f11-8bb1-b9e4f3f7bf88","note":"Assigned to desk logistics","created_at":"2026-06-25T09:10:00+07:00"}]}',
        'IT001',
        'low',
        'high',
        NOW(),
        NOW(),
        'system',
        'system'
    )
ON CONFLICT (id) DO UPDATE SET
    test_title = EXCLUDED.test_title,
    input_snapshot = EXCLUDED.input_snapshot,
    expected_category = EXCLUDED.expected_category,
    expected_urgency = EXCLUDED.expected_urgency,
    expected_sla_breach_risk = EXCLUDED.expected_sla_breach_risk,
    updated_at = now();

COMMIT;


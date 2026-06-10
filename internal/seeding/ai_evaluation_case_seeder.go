package seeding

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

const aiEvaluationCaseJSONData = `[
  {
    "id": 1,
    "test_title": "Category & Urgency - Core IT Infrastructure Failure",
    "input_snapshot": {
      "id": 101,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Database Connection Pool Exhausted",
      "description": "Production database is dropping connections. All backend APIs failing downstream.",
      "priority": "high",
      "status": "new",
      "created_at": "2026-06-10T08:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T10:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "IT",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "high"
  },
  {
    "id": 2,
    "test_title": "Category & Urgency - Standard HR Request",
    "input_snapshot": {
      "id": 102,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Request template for annual self-review",
      "description": "Where can I download the latest performance evaluation template for backend engineers?",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-10T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-15T17:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "HR",
    "expected_urgency": "low",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 3,
    "test_title": "Category & Urgency - Physical Facilities Maintenance",
    "input_snapshot": {
      "id": 103,
      "requestor_id": "b082136e-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
      "title": "Air conditioner leaking water in Meeting Room 2B",
      "description": "Water is dripping directly onto the conference table power outlets.",
      "priority": "medium",
      "status": "assigned",
      "created_at": "2026-06-10T09:15:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-11T12:00:00+07:00",
      "cancelled_at": null,
      "events": [
        {
          "id": 1,
          "ticket_id": 103,
          "from_status": "new",
          "to_status": "assigned",
          "requestor_id": "facilities-bot",
          "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
          "note": "Assigned to floor technician",
          "created_at": "2026-06-10T09:20:00+07:00"
        }
      ]
    },
    "expected_category": "Facilities",
    "expected_urgency": "medium",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 4,
    "test_title": "SLA Breach Risk - Imminent Deadline (2 Hours Left)",
    "input_snapshot": {
      "id": 104,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
      "title": "Onboarding credentials for incoming VP of Engineering",
      "description": "Executive arrives in 2 hours. Accounts have not been provisioned in Active Directory.",
      "priority": "high",
      "status": "assigned",
      "created_at": "2026-06-10T06:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T11:00:00+07:00",
      "cancelled_at": null,
      "events": [
        {
          "id": 1,
          "ticket_id": 104,
          "from_status": "new",
          "to_status": "assigned",
          "requestor_id": "hr-onboarding",
          "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
          "note": "Routed to sysadmin pool",
          "created_at": "2026-06-10T06:15:00+07:00"
        }
      ]
    },
    "expected_category": "IT",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "high"
  },
  {
    "id": 5,
    "test_title": "SLA Breach Risk - Already Breached & Stuck",
    "input_snapshot": {
      "id": 105,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
      "title": "Repair server room backup generator generator sensor",
      "description": "Faulty safety alerts popping up on monitoring panels. Deadline was 3 days ago.",
      "priority": "high",
      "status": "assigned",
      "created_at": "2026-06-05T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-07T09:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "Facilities",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "high"
  },
  {
    "id": 6,
    "test_title": "SLA Breach Risk - Stuck In Progress near window",
    "input_snapshot": {
      "id": 106,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": "3be00111-0436-4f11-8bb1-b9e4f3f7bf99",
      "title": "Urgent payroll data correction for backend squad",
      "description": "Discovered widespread mid-month salary calculation errors. System needs patch.",
      "priority": "high",
      "status": "in_progress",
      "created_at": "2026-06-09T12:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T14:00:00+07:00",
      "cancelled_at": null,
      "events": [
        {
          "id": 1,
          "ticket_id": 106,
          "from_status": "new",
          "to_status": "assigned",
          "requestor_id": "hr-lead",
          "assignee_id": "3be00111-0436-4f11-8bb1-b9e4f3f7bf99",
          "note": "Assigned to C&B lead",
          "created_at": "2026-06-09T12:30:00+07:00"
        },
        {
          "id": 2,
          "ticket_id": 106,
          "from_status": "assigned",
          "to_status": "in_progress",
          "requestor_id": "3be00111-0436-4f11-8bb1-b9e4f3f7bf99",
          "assignee_id": "3be00111-0436-4f11-8bb1-b9e4f3f7bf99",
          "note": "Reviewing accounting database logs",
          "created_at": "2026-06-09T13:00:00+07:00"
        }
      ]
    },
    "expected_category": "HR",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "high"
  },
  {
    "id": 7,
    "test_title": "Duplicate Events - Repeating identical assignment loops",
    "input_snapshot": {
      "id": 107,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
      "title": "VPN token renewal failure",
      "description": "Token generation script returns 500. SecOps engineer is blocked.",
      "priority": "medium",
      "status": "assigned",
      "created_at": "2026-06-10T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T15:00:00+07:00",
      "cancelled_at": null,
      "events": [
        {
          "id": 1,
          "ticket_id": 107,
          "from_status": "new",
          "to_status": "assigned",
          "requestor_id": "system",
          "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
          "note": "Auto-assigned",
          "created_at": "2026-06-10T09:01:00+07:00"
        },
        {
          "id": 2,
          "ticket_id": 107,
          "from_status": "assigned",
          "to_status": "assigned",
          "requestor_id": "system",
          "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
          "note": "Duplicate event auto-trigger - No status change",
          "created_at": "2026-06-10T09:02:00+07:00"
        }
      ]
    },
    "expected_category": "IT",
    "expected_urgency": "medium",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 8,
    "test_title": "Duplicate Events - Sudden status jumping and reversals",
    "input_snapshot": {
      "id": 108,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Replace office chair wheels",
      "description": "Standard ergonomics adjustment request.",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-08T10:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-12T17:00:00+07:00",
      "cancelled_at": null,
      "events": [
        {
          "id": 1,
          "ticket_id": 108,
          "from_status": "new",
          "to_status": "assigned",
          "requestor_id": "operator",
          "assignee_id": "5aa00111-0436-4f11-8bb1-b9e4f3f7bf22",
          "note": "Assigned",
          "created_at": "2026-06-08T10:30:00+07:00"
        },
        {
          "id": 2,
          "ticket_id": 108,
          "from_status": "assigned",
          "to_status": "new",
          "requestor_id": "operator",
          "assignee_id": null,
          "note": "Reverted back to new due to operator error",
          "created_at": "2026-06-08T11:00:00+07:00"
        }
      ]
    },
    "expected_category": "HR",
    "expected_urgency": "low",
    "expected_sla_breach_risk": "medium"
  },
  {
    "id": 9,
    "test_title": "Unclear Description - Mangled Vietnamese Teencode",
    "input_snapshot": {
      "id": 109,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "loi he thong nghiem trong",
      "description": "SAs mAn hInH dEn tHe k lOgIn dCw nUa mNg xEm gIuP vOi gAsP lAm r bLoCk cI cD r",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-10T10:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T13:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "IT",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 10,
    "test_title": "Unclear Description - Brief text with no core details",
    "input_snapshot": {
      "id": 110,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Help me ASAP",
      "description": "It doesn't work. Fix it please.",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-10T10:15:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-11T10:15:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "IT",
    "expected_urgency": "medium",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 11,
    "test_title": "Contradictory Context - Alarmist Title but Low Urgency Body",
    "input_snapshot": {
      "id": 111,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "CRITICAL EMERGENCY ERROR DISASTER!!!",
      "description": "Can someone help swap the old extension cord in meeting room 3? It works but looks ugly.",
      "priority": "high",
      "status": "new",
      "created_at": "2026-06-10T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-12T09:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "Facilities",
    "expected_urgency": "low",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 12,
    "test_title": "Contradictory Context - Low Title but Highly Dangerous Body",
    "input_snapshot": {
      "id": 112,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Minor question",
      "description": "There are exposed high-voltage spark wires right under the water leakage point in the cafeteria.",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-10T10:20:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T12:20:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "Facilities",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "high"
  },
  {
    "id": 13,
    "test_title": "System Stack Trace Dump - K8s CrashLoopBackOff",
    "input_snapshot": {
      "id": 113,
      "requestor_id": "alert-manager-bot",
      "assignee_id": null,
      "title": "K8s Pod CrashLoopBackOff - Auth Service",
      "description": "Fatal error: failed to initialize secure store connection context deadline exceeded core dump generated.",
      "priority": "high",
      "status": "new",
      "created_at": "2026-06-10T10:25:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T12:25:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "IT",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "high"
  },
  {
    "id": 14,
    "test_title": "SLA Breach Risk - Untouched 'New' status for 40+ hours",
    "input_snapshot": {
      "id": 114,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Health insurance premium renewal assistance",
      "description": "Need HR to sign dependent declaration forms before the regional cutoff tomorrow noon.",
      "priority": "medium",
      "status": "new",
      "created_at": "2026-06-08T15:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-11T15:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "HR",
    "expected_urgency": "medium",
    "expected_sla_breach_risk": "high"
  },
  {
    "id": 15,
    "test_title": "Category & Urgency - Security Access Management",
    "input_snapshot": {
      "id": 115,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Revoke permissions for offboarded contractor",
      "description": "Contractor left yesterday. Need immediate production database access termination.",
      "priority": "high",
      "status": "new",
      "created_at": "2026-06-10T10:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T12:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "IT",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 16,
    "test_title": "Unclear Description - Semi-structured mixed logging text",
    "input_snapshot": {
      "id": 116,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Log anomaly detected",
      "description": "User requested /api/v1/hr/salary [STATUS 403] repeated 400 times from IP 192.168.1.55.",
      "priority": "medium",
      "status": "new",
      "created_at": "2026-06-10T10:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T16:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "IT",
    "expected_urgency": "high",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 17,
    "test_title": "Category & Urgency - General HR Inquiry",
    "input_snapshot": {
      "id": 117,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Paternity leave policy duration query",
      "description": "How many consecutive paid weeks off does the company allocate for new fathers?",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-10T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-17T09:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "HR",
    "expected_urgency": "low",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 18,
    "test_title": "Duplicate Events - Massive identical event logs",
    "input_snapshot": {
      "id": 118,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "Water cooler empty floor 4",
      "description": "Please deliver a replacement bottle to the engineering lounge.",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-10T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-12T09:00:00+07:00",
      "cancelled_at": null,
      "events": [
        {
          "id": 1,
          "ticket_id": 118,
          "from_status": "new",
          "to_status": "new",
          "requestor_id": "user-1",
          "note": "Initial request ping",
          "created_at": "2026-06-10T09:05:00+07:00"
        },
        {
          "id": 2,
          "ticket_id": 118,
          "from_status": "new",
          "to_status": "new",
          "requestor_id": "user-1",
          "note": "Initial request ping",
          "created_at": "2026-06-10T09:05:00+07:00"
        }
      ]
    },
    "expected_category": "Facilities",
    "expected_urgency": "low",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 19,
    "test_title": "Unclear Description - Cryptic Short Title & Vague Body",
    "input_snapshot": {
      "id": 119,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": null,
      "title": "stuff",
      "description": "The paperwork we discussed during lunch is missing an official stamp. Sort it.",
      "priority": "low",
      "status": "new",
      "created_at": "2026-06-10T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-15T09:00:00+07:00",
      "cancelled_at": null,
      "events": []
    },
    "expected_category": "HR",
    "expected_urgency": "low",
    "expected_sla_breach_risk": "low"
  },
  {
    "id": 20,
    "test_title": "SLA Breach Risk - Medium urgency near threshold",
    "input_snapshot": {
      "id": 120,
      "requestor_id": "0a5389df-ba3a-4494-a095-126d05c7c2e7",
      "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
      "title": "On-call mouse replacement request",
      "description": "Developer mouse tracking broken. Standard office supply logistics item.",
      "priority": "low",
      "status": "assigned",
      "created_at": "2026-06-09T09:00:00+07:00",
      "resolved_at": null,
      "sla_due_at": "2026-06-10T12:00:00+07:00",
      "cancelled_at": null,
      "events": [
        {
          "id": 1,
          "ticket_id": 120,
          "from_status": "new",
          "to_status": "assigned",
          "requestor_id": "procurement-team",
          "assignee_id": "9ee00625-0436-4f11-8bb1-b9e4f3f7bf88",
          "note": "Assigned to desk logistics",
          "created_at": "2026-06-09T09:10:00+07:00"
        }
      ]
    },
    "expected_category": "IT",
    "expected_urgency": "low",
    "expected_sla_breach_risk": "high"
  }
]`

type aiEvaluationCaseData struct {
	ID                    uint            `json:"id"`
	TestTitle             string          `json:"test_title"`
	InputSnapshot         json.RawMessage `json:"input_snapshot"`
	ExpectedCategory      string          `json:"expected_category"`
	ExpectedUrgency       string          `json:"expected_urgency"`
	ExpectedSLABreachRisk string          `json:"expected_sla_breach_risk"`
}

// SeedAIEvaluationCases parses raw JSON data and inserts AI evaluation cases if they do not exist
func SeedAIEvaluationCases(db *gorm.DB) error {
	var data []aiEvaluationCaseData
	if err := json.Unmarshal([]byte(aiEvaluationCaseJSONData), &data); err != nil {
		return fmt.Errorf("failed to unmarshal seeding data: %w", err)
	}

	for _, d := range data {
		var count int64
		if err := db.Model(&model.AIEvaluationCase{}).Where("id = ?", d.ID).Count(&count).Error; err != nil {
			return fmt.Errorf("error checking existing case %d: %w", d.ID, err)
		}

		if count == 0 {
			caseModel := model.AIEvaluationCase{
				ID:                    d.ID,
				TestTitle:             d.TestTitle,
				InputSnapshot:         string(d.InputSnapshot),
				ExpectedCategory:      d.ExpectedCategory,
				ExpectedUrgency:       d.ExpectedUrgency,
				ExpectedSLABreachRisk: d.ExpectedSLABreachRisk,
			}
			if err := db.Create(&caseModel).Error; err != nil {
				return fmt.Errorf("failed to seed case %d: %w", d.ID, err)
			}
			slog.InfoContext(context.Background(), "seeded ai evaluation case", slog.Uint64("id", uint64(d.ID)))
		}
	}

	slog.InfoContext(context.Background(), "ai evaluation cases seeding completed")
	return nil
}

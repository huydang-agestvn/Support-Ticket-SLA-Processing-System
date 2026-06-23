package ai

const (
	RuleEnginePromptVersion = "rule_engine_v1.0"
	DefaultSLAPolicy        = "Max resolution time is determined by priority: High (4h), Medium (24h), Low (48h)."
)

// SubDeptDutiesAndAction represents the duties and actions for a sub-department
type SubDeptDutiesAndAction struct {
	Duties string
	Action string
}

// SubDeptDutiesAndActions maps a sub-department code to its duties and action guidelines
var SubDeptDutiesAndActions = map[string]SubDeptDutiesAndAction{
	"FC001": {
		Duties: "facility repairs, electricity, water, air conditioning, and office area cleaning",
		Action: "Immediately dispatch a workplace technician or cleaning staff to the designated floor to repair/resolve the facility issue.",
	},
	"FC002": {
		Duties: "corporate vehicle dispatch, mail courier services, and VIP access badge reception",
		Action: "Manually override the automated booking, assign the on-call driver, and send the VIP's name and contact number via SMS to the driver.",
	},
	"FC003": {
		Duties: "office supplies distribution and pantry restock management",
		Action: "Notify the pantry/supply coordinator to restock the missing supplies or pantry items on the requested floor.",
	},
	"IT001": {
		Duties: "physical hardware provisioning, laptop swaps, repairs, and temporary equipment loans",
		Action: "Immediately coordinate with the hardware team to prepare replacement laptops, accessories, or loaner devices, and arrange for employee collection.",
	},
	"IT002": {
		Duties: "network configurations, VPN/Wi-Fi troubleshooting, operating system updates, and software installations",
		Action: "Dispatch a network engineer or remote support specialist to resolve VPN connectivity, Wi-Fi outage, or system software installation issues.",
	},
	"IT003": {
		Duties: "account credentials management, Active Directory resets, MFA troubleshooting, and cybersecurity incident response",
		Action: "Trigger password resets, unlock Active Directory credentials, re-authenticate MFA keys, or isolate the workstation if suspected phishing or malware is flagged.",
	},
	"HR001": {
		Duties: "payroll discrepancies, leave balance adjustments, BHXH social insurance, and health insurance registration",
		Action: "Forward payroll/benefits queries to the C&B specialist to investigate timesheets, pay slips, or health insurance app updates.",
	},
	"HR002": {
		Duties: "onboarding arrangements, training budgets, and course registrations",
		Action: "Assign a learning coordinator or recruiter to process the training budget, course enrollment, or prepare the workstation onboarding package.",
	},
	"HR003": {
		Duties: "employee conflict resolution, resignation/offboarding procedures, and team building feedback",
		Action: "Schedule a mediation meeting, coordinate employee offboarding exit interviews, or route the workplace relations query to the Employee Relations manager.",
	},
}

// GetSubDeptDutiesAndAction returns the duties and recommended action for a given sub-department code.
func GetSubDeptDutiesAndAction(code string) (string, string) {
	if val, ok := SubDeptDutiesAndActions[code]; ok {
		return val.Duties, val.Action
	}
	return "general sub-department operations", "Immediate manual intervention required. Route to the responsible team."
}

// MapDeptCodeToCategory maps a department code prefix to its corresponding ticket category name.
func MapDeptCodeToCategory(code string) string {
	switch code {
	case "FC":
		return "Facilities"
	default:
		return code
	}
}

package ai

import (
	"fmt"
	"regexp"
	"strings"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
)

const (
	RuleEnginePromptVersion = "rule_engine_v1.0"
	DefaultSLAPolicy        = "Max resolution time is determined as follows: High (4h), Medium (24h), Low (48h)."
)

type SubDeptDutiesAndAction struct {
	Duties string
	Action string
}

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

func GetSubDeptDutiesAndAction(code string) (string, string) {
	if val, ok := SubDeptDutiesAndActions[code]; ok {
		return val.Duties, val.Action
	}
	return "general sub-department operations", "Immediate manual intervention required. Route to the responsible team."
}

func MapDeptCodeToCategory(code string) string {
	switch code {
	case "FC":
		return "Facilities"
	default:
		return code
	}
}

func init() {
	model.RoomFloorValidator = ValidateRoomAndFloor
}

// ValidNamedRooms maps floors to allowed named rooms (translated and categorized under the new organization system)
var ValidNamedRooms = map[string][]string{
	"12A": {
		"dev001", "dev002",
		"qa001",
		"ds001",
		"fin001", "mkt001", "sls001",
		"mt001", "mt002", "meeting room", "meeting rooms", "boardroom", "conference room",
		"rd12a", "reception", "lounge", "lobby",
		"pantry 12a", "pantry",
		"toilet 12a", "toilet", "wc", "restroom",
	},
	"18": {
		"dev003", "dev004",
		"qa002", "qa003",
		"rd18", "reception", "lounge", "lobby",
		"pantry 18", "pantry",
		"toilet 18", "toilet", "wc", "restroom",
	},
	"19": {
		"pmo001",
		"toilet 19", "toilet", "wc", "restroom",
	},
}

var (
	floorRegex = regexp.MustCompile(`(?i)(?:floor|tầng)\s*([0-9]+[a-zA-Z]?)`)
	roomRegex  = regexp.MustCompile(`(?i)(?:room|phòng|meeting\s+room|phòng\s+họp|conference\s+room|phòng\s+hội\s+nghị)\s*([0-9]+[a-zA-Z]?)`)
)

func getFirstDigitSequence(s string) string {
	var digits []rune
	for _, r := range s {
		if r >= '0' && r <= '9' {
			digits = append(digits, r)
		} else if len(digits) > 0 {
			break
		}
	}
	return string(digits)
}

var ValidFloors = map[string]bool{
	"12a": true,
	"18":  true,
	"19":  true,
}

var namedRoomKeywords = []string{
	"dev001", "dev002", "dev003", "dev004",
	"qa001", "qa002", "qa003",
	"pmo001", "ds001",
	"fin001", "mkt001", "sls001",
	"mt001", "mt002", "meeting room", "meeting rooms", "boardroom", "conference room",
	"rd12a", "rd18", "reception", "lounge", "lobby",
	"pantry 12a", "pantry 18", "pantry",
	"toilet 12a", "toilet 18", "toilet 19", "toilet", "wc", "restroom",
}

// extractFloors extracts floors from combined text and validates them against ValidFloors
func extractFloors(combined string) ([]string, error) {
	floorMatches := floorRegex.FindAllStringSubmatch(combined, -1)
	var floors []string
	for _, m := range floorMatches {
		if len(m) > 1 {
			fClean := strings.ToLower(strings.TrimSpace(m[1]))
			if !ValidFloors[fClean] {
				return nil, errmsgs.ErrInvalidFloorOrRoom
			}
			floors = append(floors, fClean)
		}
	}
	return floors, nil
}

// extractRooms extracts both numbered and named rooms from combined text
func extractRooms(combined, combinedLower string) []string {
	var rooms []string

	// Extract numbered rooms
	roomMatches := roomRegex.FindAllStringSubmatch(combined, -1)
	for _, m := range roomMatches {
		if len(m) > 1 {
			rooms = append(rooms, strings.ToLower(strings.TrimSpace(m[1])))
		}
	}

	// Extract named rooms based on order of appearance
	type foundRoom struct {
		name  string
		index int
	}
	var foundRooms []foundRoom
	for _, kw := range namedRoomKeywords {
		idx := strings.Index(combinedLower, kw)
		if idx != -1 {
			foundRooms = append(foundRooms, foundRoom{name: kw, index: idx})
		}
	}

	// Sort named rooms by index of occurrence
	for i := 0; i < len(foundRooms); i++ {
		for j := i + 1; j < len(foundRooms); j++ {
			if foundRooms[i].index > foundRooms[j].index {
				foundRooms[i], foundRooms[j] = foundRooms[j], foundRooms[i]
			}
		}
	}
	for _, fr := range foundRooms {
		rooms = append(rooms, fr.name)
	}

	// Filter out generic room names that are substrings of other specific rooms
	var specificRooms []string
	for _, r1 := range rooms {
		isSubstringOfOther := false
		for _, r2 := range rooms {
			if r1 != r2 && strings.Contains(r2, r1) {
				isSubstringOfOther = true
				break
			}
		}
		if !isSubstringOfOther {
			specificRooms = append(specificRooms, r1)
		}
	}

	return specificRooms
}

// isCompatible checks if a room is compatible with a floor
func isCompatible(room, floor string) bool {
	rClean := strings.ToLower(room)
	fClean := strings.ToLower(floor)

	// If the room name explicitly contains another floor name, it is incompatible with this floor
	for otherFloor := range ValidFloors {
		if otherFloor != fClean && strings.Contains(rClean, otherFloor) {
			return false
		}
	}

	// First, check if the room matches any of the named rooms allowed on this floor
	for fKey, allowed := range ValidNamedRooms {
		if strings.ToLower(fKey) == fClean {
			for _, allowedRoom := range allowed {
				if strings.Contains(rClean, allowedRoom) || strings.Contains(allowedRoom, rClean) {
					return true
				}
			}
		}
	}

	floorDigits := getFirstDigitSequence(fClean)
	roomDigits := getFirstDigitSequence(rClean)

	if floorDigits != "" && roomDigits != "" {
		return strings.HasPrefix(roomDigits, floorDigits)
	}

	return false
}

// ValidateRoomAndFloor validates that rooms and floors are compatible if both are present in title/description
func ValidateRoomAndFloor(title, description string) error {
	combined := title + " " + description
	combinedLower := strings.ToLower(combined)

	floors, err := extractFloors(combined)
	if err != nil {
		return err
	}

	rooms := extractRooms(combined, combinedLower)

	if len(floors) == 0 || len(rooms) == 0 {
		return nil
	}

	// Check if there is at least one compatible room-floor match among all extracted rooms/floors
	hasCompatibleMatch := false
	for _, room := range rooms {
		for _, floor := range floors {
			if isCompatible(room, floor) {
				hasCompatibleMatch = true
				break
			}
		}
		if hasCompatibleMatch {
			break
		}
	}

	if !hasCompatibleMatch {
		// Report the first mismatch for a better diagnostic error message
		return common.NewBadRequest(common.ErrCodeInvalidInput, fmt.Sprintf("room and floor mismatch: room '%s' is not compatible with floor '%s'", strings.ToLower(rooms[0]), strings.ToLower(floors[0])))
	}

	return nil
}
 
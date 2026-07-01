package ai

import (
	"fmt"
	"regexp"
	"sort"
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
		"mt001", "mt002", "meeting room 12a", "meeting room 12a", "boardroom 12a", "conference room 12a",
		"rd12a", "reception 12a", "lounge 12a", "lobby 12a",
		"pantry 12a","pantry",
		"toilet 12a", "wc 12a", "restroom 12a",
	},
	"18": {
		"dev003", "dev004",
		"qa002", "qa003",
		"rd18", "reception 18", "lounge 18", "lobby 18",
		"pantry 18","pantry",
		"toilet 18", "wc 18", "restroom 18",
	},
	"19": {
		"pmo001",
		"toilet 19", "wc 19", "restroom 19","pantry",
	},
}

var (
	floorRegex        = regexp.MustCompile(`(?i)(?:floor|tầng)\s*([0-9]+[a-zA-Z]?)`)
	roomRegex         = regexp.MustCompile(`(?i)(?:room|phòng|meeting\s+room|phòng\s+họp|conference\s+room|phòng\s+hội\s+nghị)\s*([0-9]+[a-zA-Z]?)`)
	suffixRegex       = regexp.MustCompile(`^(?:[\s-]+)?([0-9]+[a-zA-Z]?)`)
	numberedRoomRegex = regexp.MustCompile(`^[0-9]+[a-zA-Z]?$`)
	dynamicRoomRegex  = regexp.MustCompile(`(?i)\b(dev|qa|pmo|ds|fin|mkt|sls|mt|rd)[0-9]+[a-zA-Z]?\b`)
)

func isNumberedRoom(room string) bool {
	return numberedRoomRegex.MatchString(room)
}

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

var namedRoomKeywords = []string{
	"dev001", "dev002", "dev003", "dev004",
	"qa001", "qa002", "qa003",
	"pmo001", "ds001",
	"fin001", "mkt001", "sls001",
	"mt001", "mt002", "meeting room", "meeting rooms", "boardroom", "conference room",
	"rd12a", "rd18", "reception", "lounge", "lobby",
	"pantry 12a", "pantry 18",
	"toilet 12a", "toilet 18", "toilet 19", "toilet", "wc", "restroom",
}

// extractFloors extracts floors from combined text and validates them against ValidFloors
func extractFloors(combined string) ([]string, error) {
	floorMatches := floorRegex.FindAllStringSubmatch(combined, -1)
	var floors []string
	for _, m := range floorMatches {
		if len(m) > 1 {
			fClean := strings.ToLower(strings.TrimSpace(m[1]))
			if _, ok := ValidNamedRooms[strings.ToUpper(fClean)]; !ok {
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
	seen := make(map[string]bool)

	addRoom := func(r string) {
		r = strings.ToLower(strings.TrimSpace(r))
		if r != "" && !seen[r] {
			seen[r] = true
			rooms = append(rooms, r)
		}
	}

	// Extract numbered rooms
	roomMatches := roomRegex.FindAllStringSubmatch(combined, -1)
	for _, m := range roomMatches {
		if len(m) > 1 {
			addRoom(m[1])
		}
	}

	// Extract named rooms based on order of appearance, capturing any trailing floor numbers/indicators
	type foundRoom struct {
		name  string
		index int
	}
	var foundRooms []foundRoom
	for _, kw := range namedRoomKeywords {
		idx := strings.Index(combinedLower, kw)
		if idx != -1 {
			roomName := kw
			textAfter := combinedLower[idx+len(kw):]
			match := suffixRegex.FindString(textAfter)
			if match != "" {
				roomName = kw + match
			}
			foundRooms = append(foundRooms, foundRoom{name: roomName, index: idx})
		}
	}

	// Sort named rooms by index of occurrence
	sort.Slice(foundRooms, func(i, j int) bool {
		return foundRooms[i].index < foundRooms[j].index
	})
	for _, fr := range foundRooms {
		addRoom(fr.name)
	}

	// Extract dynamic named rooms matching <prefix><digits><suffix> (e.g. dev009)
	dynamicMatches := dynamicRoomRegex.FindAllString(combinedLower, -1)
	for _, dm := range dynamicMatches {
		addRoom(dm)
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

func containsWord(s, word string) bool {
	pattern := `(?i)\b` + regexp.QuoteMeta(word) + `\b`
	re, err := regexp.Compile(pattern)
	if err != nil {
		return false
	}
	return re.MatchString(s)
}

// isCompatible checks if a room is compatible with a floor
func isCompatible(room, floor string) bool {
	rClean := strings.ToLower(room)
	fClean := strings.ToLower(floor)

	// If the room name explicitly contains another floor name, it is incompatible with this floor
	for otherFloor := range ValidNamedRooms {
		otherFloorClean := strings.ToLower(otherFloor)
		if otherFloorClean != fClean && strings.Contains(rClean, otherFloorClean) {
			return false
		}
	}

	floorDigits := getFirstDigitSequence(fClean)
	roomDigits := getFirstDigitSequence(rClean)

	// If room digits do not start with '0', they represent a floor number and must be compatible with the floor digits
	if floorDigits != "" && roomDigits != "" && !strings.HasPrefix(roomDigits, "0") {
		if !strings.HasPrefix(roomDigits, floorDigits) {
			return false
		}
	}

	// First, check if the room matches any of the named rooms allowed on this floor
	if !isNumberedRoom(rClean) {
		if allowed, ok := ValidNamedRooms[strings.ToUpper(fClean)]; ok {
			for _, allowedRoom := range allowed {
				if containsWord(rClean, allowedRoom) || containsWord(allowedRoom, rClean) {
					return true
				}
			}
		}
	}

	if floorDigits != "" && roomDigits != "" {
		return strings.HasPrefix(roomDigits, floorDigits)
	}

	return false
}

// checkScopeCompatibility checks if any room is compatible with any floor in a given slice.
// If both slices are populated and no compatible pair is found, it returns an error.
func checkScopeCompatibility(floors, rooms []string) error {
	if len(floors) == 0 || len(rooms) == 0 {
		return nil
	}
	for _, r := range rooms {
		for _, f := range floors {
			if isCompatible(r, f) {
				return nil
			}
		}
	}
	return common.NewBadRequest(
		common.ErrCodeInvalidInput,
		fmt.Sprintf("room and floor mismatch: room '%s' is not compatible with floor '%s'", strings.ToLower(rooms[0]), strings.ToLower(floors[0])),
	)
}

// validateText extracts floors and rooms from text and checks compatibility
func validateText(text string) error {
	floors, err := extractFloors(text)
	if err != nil {
		return err
	}
	return checkScopeCompatibility(floors, extractRooms(text, strings.ToLower(text)))
}

// ValidateRoomAndFloor validates that rooms and floors are compatible if both are present in title/description
func ValidateRoomAndFloor(title, description string) error {
	if err := validateText(title); err != nil {
		return err
	}
	if err := validateText(description); err != nil {
		return err
	}
	return validateText(title + " " + description)
}

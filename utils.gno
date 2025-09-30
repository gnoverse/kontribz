package kontribz

import (
	"strconv"
	"strings"

	"gno.land/p/moul/md"
	"gno.land/r/demo/profile"
)

// Text formatting functions for status display
func getTaskStatusText(status TaskStatus) string {
	switch status {
	case TaskOpen:
		return "🟢 Open"
	case TaskAssigned:
		return "🟡 Assigned"
	case TaskCompleted:
		return "✅ Completed"
	default:
		return "Unknown"
	}
}

func getApplicationStatusText(status ApplicationStatus) string {
	switch status {
	case AppPending:
		return "⏳ Pending"
	case AppAccepted:
		return "✅ Accepted"
	case AppRejected:
		return "❌ Rejected"
	default:
		return "Unknown"
	}
}

func getKanbanStatusText(status KanbanStatus) string {
	switch status {
	case KanbanTodo:
		return "📝 Todo"
	case KanbanInProgress:
		return "🔄 In Progress"
	case KanbanReview:
		return "👀 Review"
	case KanbanDone:
		return "✅ Done"
	default:
		return "Unknown"
	}
}

// Utility function for max
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// Kanban rendering functions
func renderUserKanbanPreview(addr address) string {
	var out string

	// Collect user's assigned tasks
	var userTasks []*Task
	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		if task.Assignee == addr {
			userTasks = append(userTasks, task)
		}
		return false
	})

	if len(userTasks) == 0 {
		out += "No assigned tasks yet.\n\n"
		return out
	}

	out += md.Bold("Assigned Tasks:") + " " + strconv.Itoa(len(userTasks)) + "\n\n"

	// Count by status for preview
	todoCount := 0
	progressCount := 0
	reviewCount := 0
	doneCount := 0

	for _, task := range userTasks {
		switch task.KanbanStatus {
		case KanbanTodo:
			todoCount++
		case KanbanInProgress:
			progressCount++
		case KanbanReview:
			reviewCount++
		case KanbanDone:
			doneCount++
		}
	}

	out += "📝 Todo: " + strconv.Itoa(todoCount) + " | "
	out += "🔄 In Progress: " + strconv.Itoa(progressCount) + " | "
	out += "👀 Review: " + strconv.Itoa(reviewCount) + " | "
	out += "✅ Done: " + strconv.Itoa(doneCount) + "\n\n"

	return out
}

func renderUserKanban(addr address) string {
	var out string

	// Collect user's assigned tasks
	var userTasks []*Task
	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		if task.Assignee == addr {
			userTasks = append(userTasks, task)
		}
		return false
	})

	if len(userTasks) == 0 {
		out += "No assigned tasks yet.\n\n"
		return out
	}

	// Organize by kanban status
	todoTasks := []*Task{}
	inProgressTasks := []*Task{}
	reviewTasks := []*Task{}
	doneTasks := []*Task{}

	for _, task := range userTasks {
		switch task.KanbanStatus {
		case KanbanTodo:
			todoTasks = append(todoTasks, task)
		case KanbanInProgress:
			inProgressTasks = append(inProgressTasks, task)
		case KanbanReview:
			reviewTasks = append(reviewTasks, task)
		case KanbanDone:
			doneTasks = append(doneTasks, task)
		}
	}

	// Render kanban columns
	out += "| 📝 Todo (" + strconv.Itoa(len(todoTasks)) + ") | 🔄 In Progress (" + strconv.Itoa(len(inProgressTasks)) + ") | 👀 Review (" + strconv.Itoa(len(reviewTasks)) + ") | ✅ Done (" + strconv.Itoa(len(doneTasks)) + ") |\n"
	out += "|---------|------------------|----------|----------|\n"

	maxRows := max(max(len(todoTasks), len(inProgressTasks)), max(len(reviewTasks), len(doneTasks)))

	for i := 0; i < maxRows; i++ {
		out += "| "

		// Todo column
		if i < len(todoTasks) {
			task := todoTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " @ " + orgName
		}
		out += " | "

		// In Progress column
		if i < len(inProgressTasks) {
			task := inProgressTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " @ " + orgName
		}
		out += " | "

		// Review column
		if i < len(reviewTasks) {
			task := reviewTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " @ " + orgName
		}
		out += " | "

		// Done column
		if i < len(doneTasks) {
			task := doneTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " @ " + orgName
		}
		out += " |\n"
	}

	out += "\n"
	return out
}

func renderOrganizationKanbanPreview(org *Organization) string {
	var out string

	if len(org.Tasks) == 0 {
		out += "No tasks yet.\n\n"
		return out
	}

	// Count by status for preview
	openCount := 0
	assignedCount := 0
	completedCount := 0

	for _, taskID := range org.Tasks {
		task := getTask(taskID)
		if task != nil {
			switch task.Status {
			case TaskOpen:
				openCount++
			case TaskAssigned:
				assignedCount++
			case TaskCompleted:
				completedCount++
			}
		}
	}

	out += md.Bold("Total Tasks:") + " " + strconv.Itoa(len(org.Tasks)) + "\n\n"

	statusSummary := []string{
		"🟢 Open: " + strconv.Itoa(openCount),
		"🟡 Assigned: " + strconv.Itoa(assignedCount),
		"✅ Completed: " + strconv.Itoa(completedCount),
	}

	out += strings.Join(statusSummary, " | ") + "\n\n"

	return out
}

func renderOrganizationKanban(org *Organization) string {
	var out string

	if len(org.Tasks) == 0 {
		out += "No tasks yet.\n\n"
		return out
	}

	// Organize by status
	openTasks := []*Task{}
	assignedTasks := []*Task{}
	completedTasks := []*Task{}

	for _, taskID := range org.Tasks {
		task := getTask(taskID)
		if task != nil {
			switch task.Status {
			case TaskOpen:
				openTasks = append(openTasks, task)
			case TaskAssigned:
				assignedTasks = append(assignedTasks, task)
			case TaskCompleted:
				completedTasks = append(completedTasks, task)
			}
		}
	}

	// Render organization kanban
	out += "| 🟢 Open (" + strconv.Itoa(len(openTasks)) + ") | 🟡 Assigned (" + strconv.Itoa(len(assignedTasks)) + ") | ✅ Completed (" + strconv.Itoa(len(completedTasks)) + ") |\n"
	out += "|---------|------------|-------------|\n"

	maxRows := max(max(len(openTasks), len(assignedTasks)), len(completedTasks))

	for i := 0; i < maxRows; i++ {
		out += "| "

		// Open tasks column
		if i < len(openTasks) {
			task := openTasks[i]
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " (" + strconv.Itoa(len(task.Applications)) + " apps)"
		}
		out += " | "

		// Assigned tasks column
		if i < len(assignedTasks) {
			task := assignedTasks[i]
			assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
			kanbanStatus := getKanbanStatusText(task.KanbanStatus)
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " by " + md.Link(assigneeName, realmPath+":user/"+task.Assignee.String()) + " - " + kanbanStatus
		}
		out += " | "

		// Completed tasks column
		if i < len(completedTasks) {
			task := completedTasks[i]
			assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " by " + md.Link(assigneeName, realmPath+":user/"+task.Assignee.String())
		}
		out += " |\n"
	}

	out += "\n"
	return out
}

func renderTaskSummary(task *Task) string {
	org := getOrganization(task.OrganizationID)
	if org == nil {
		return ""
	}

	var out string
	out += md.HorizontalRule() + "\n\n"
	out += md.H3(md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))) + "\n\n"

	infoItems := []string{
		md.Bold("Organization:") + " " + md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)),
		md.Bold("Status:") + " " + getTaskStatusText(task.Status),
	}

	if task.Reward != "" {
		infoItems = append(infoItems, md.Bold("Reward:")+" "+task.Reward)
	}

	if task.Assignee != "" {
		assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
		infoItems = append(infoItems, md.Bold("Assignee:")+" "+assigneeName)
	}

	infoItems = append(infoItems, md.Bold("Applications:")+" "+strconv.Itoa(len(task.Applications)))

	out += md.BulletList(infoItems) + "\n"

	// Show truncated description
	description := task.Description
	if len(description) > 100 {
		description = description[:97] + "..."
	}
	out += md.Bold("Description:") + " " + description + "\n\n"

	return out
}
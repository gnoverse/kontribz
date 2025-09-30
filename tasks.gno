package kontribz

import (
	"chain/runtime"
	"strconv"
)

// CreateTask creates a new task for an organization
func CreateTask(cur realm, orgIDStr, title, description, reward string) {
	caller := runtime.OriginCaller()

	if orgIDStr == "" || title == "" || description == "" {
		panic("Organization ID, title and description are required")
	}

	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		panic("Invalid organization ID")
	}

	org := getOrganization(orgID)
	if org == nil {
		panic("Organization not found")
	}

	if org.Admin != caller {
		panic("Only organization admin can create tasks")
	}

	taskCounter++
	task := &Task{
		ID:             taskCounter,
		OrganizationID: orgID,
		Title:          title,
		Description:    description,
		Reward:         reward,
		Status:         TaskOpen,
		Assignee:       "",
		Applications:   []int{},
		CreatedAt:      runtime.ChainHeight(),
		KanbanStatus:   KanbanTodo, // Default kanban status
	}

	tasks.Set(strconv.Itoa(taskCounter), task)

	// Add task to organization
	org.Tasks = append(org.Tasks, taskCounter)
	organizations.Set(strconv.Itoa(orgID), org)
}

// CompleteTask marks a task as completed by the organization admin
func CompleteTask(cur realm, taskIDStr string) {
	caller := runtime.OriginCaller()

	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		panic("Invalid task ID")
	}

	task := getTask(taskID)
	if task == nil {
		panic("Task not found")
	}

	if task.Status != TaskAssigned {
		panic("Task is not assigned")
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		panic("Organization not found")
	}

	if org.Admin != caller {
		panic("Only organization admin can complete task")
	}

	task.Status = TaskCompleted
	task.KanbanStatus = KanbanDone
	tasks.Set(strconv.Itoa(taskID), task)
}

// updates the kanban status of an assigned task
// Assignee can update all statuses
func UpdateKanbanStatus(cur realm, taskIDStr, statusIDStr string) {
	caller := runtime.OriginCaller()

	if taskIDStr == "" || statusIDStr == "" {
		panic("Task ID and status are required")
	}

	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		panic("Invalid task ID")
	}

	statusInt, err := strconv.Atoi(statusIDStr)
	if err != nil {
		panic("Invalid status")
	}

	if statusInt < 0 || statusInt > 3 {
		panic("Invalid kanban status")
	}

	task := getTask(taskID)
	if task == nil {
		panic("Task not found")
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		panic("Organization not found")
	}

	// Check permissions based on status
	isAssignee := task.Assignee == caller
	isOrgAdmin := org.Admin == caller
	targetStatus := KanbanStatus(statusInt)


	if !isAssignee && !isOrgAdmin {
		panic("Only assignee or organization admin can update kanban status")
	}

	// Organization admin can only update Review (2) and Done (3)
	if !isAssignee && isOrgAdmin && (targetStatus != KanbanReview && targetStatus != KanbanDone) {
		panic("Organization admin can only set Review or Done status")
	}

	task.KanbanStatus = targetStatus
	tasks.Set(strconv.Itoa(taskID), task)
}

// ApplyToTask creates an application for a task
func ApplyToTask(cur realm, taskIDStr, message string) {
	caller := runtime.OriginCaller()

	if taskIDStr == "" {
		panic("Task ID is required")
	}

	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		panic("Invalid task ID")
	}

	task := getTask(taskID)
	if task == nil {
		panic("Task not found")
	}

	if task.Status != TaskOpen {
		panic("Task is not open for applications")
	}

	// Check if user already applied
	for _, appID := range task.Applications {
		app := getApplication(appID)
		if app != nil && app.Applicant == caller {
			panic("You have already applied for this task")
		}
	}

	// Create application
	appCounter++
	application := &Application{
		ID:        appCounter,
		TaskID:    taskID,
		Applicant: caller,
		Message:   message,
		Status:    AppPending,
		AppliedAt: runtime.ChainHeight(),
	}

	applications.Set(strconv.Itoa(appCounter), application)

	// Add application to task
	task.Applications = append(task.Applications, appCounter)
	tasks.Set(strconv.Itoa(taskID), task)
}

// Accepts a pending application and assigns the task
func AcceptApplication(cur realm, appIDStr string) {
	caller := runtime.OriginCaller()

	if appIDStr == "" {
		panic("Application ID is required")
	}

	appID, err := strconv.Atoi(appIDStr)
	if err != nil {
		panic("Invalid application ID")
	}

	app := getApplication(appID)
	if app == nil {
		panic("Application not found")
	}

	task := getTask(app.TaskID)
	if task == nil {
		panic("Task not found")
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		panic("Organization not found")
	}

	if org.Admin != caller {
		panic("Only organization admin can accept applications")
	}

	if app.Status != AppPending {
		panic("Application is not pending")
	}

	// Accept application
	app.Status = AppAccepted
	applications.Set(strconv.Itoa(appID), app)

	// Assign task
	task.Status = TaskAssigned
	task.Assignee = app.Applicant
	task.KanbanStatus = KanbanTodo // Reset to todo when assigned
	tasks.Set(strconv.Itoa(app.TaskID), task)

	// Reject other pending applications
	for _, otherAppID := range task.Applications {
		if otherAppID != appID {
			otherApp := getApplication(otherAppID)
			if otherApp != nil && otherApp.Status == AppPending {
				otherApp.Status = AppRejected
				applications.Set(strconv.Itoa(otherAppID), otherApp)
			}
		}
	}
}

// Rejects a pending application
func RejectApplication(cur realm, appIDStr string) {
	caller := runtime.OriginCaller()

	if appIDStr == "" {
		panic("Application ID is required")
	}

	appID, err := strconv.Atoi(appIDStr)
	if err != nil {
		panic("Invalid application ID")
	}

	app := getApplication(appID)
	if app == nil {
		panic("Application not found")
	}

	task := getTask(app.TaskID)
	if task == nil {
		panic("Task not found")
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		panic("Organization not found")
	}

	if org.Admin != caller {
		panic("Only organization admin can reject applications")
	}

	if app.Status != AppPending {
		panic("Application is not pending")
	}

	// Reject application
	app.Status = AppRejected
	applications.Set(strconv.Itoa(appID), app)
}

// getTask retrieves a task by ID
func getTask(taskID int) *Task {
	taskI, ok := tasks.Get(strconv.Itoa(taskID))
	if !ok {
		return nil
	}
	return taskI.(*Task)
}

// getApplication retrieves an application by ID
func getApplication(appID int) *Application {
	appI, ok := applications.Get(strconv.Itoa(appID))
	if !ok {
		return nil
	}
	return appI.(*Application)
}
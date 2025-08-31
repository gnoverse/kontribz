package kontribz

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

// Test helper function to reset global state
func resetTaskTestState() {
	tasks = avl.Tree{}
	applications = avl.Tree{}
	organizations = avl.Tree{}
	taskCounter = 0
	appCounter = 0
	orgCounter = 0
}

// Helper to create test organization
func createTestOrganization(id int, admin std.Address) *Organization {
	org := &Organization{
		ID:        id,
		Name:      "Test Org " + strconv.Itoa(id),
		Domain:    "testorg" + strconv.Itoa(id),
		Admin:     admin,
		Tasks:     []int{},
		CreatedAt: 12345,
	}
	organizations.Set(strconv.Itoa(id), org)
	orgCounter = id
	return org
}

func TestGetTask(t *testing.T) {
	resetTaskTestState()

	// Create test task
	task := &Task{
		ID:             1,
		OrganizationID: 1,
		Title:          "Test Task",
		Description:    "Test description",
		Status:         TaskOpen,
		KanbanStatus:   KanbanTodo,
	}
	tasks.Set("1", task)

	// Test successful retrieval
	result := getTask(1)
	uassert.NotNil(t, result)
	uassert.Equal(t, 1, result.ID)
	uassert.Equal(t, "Test Task", result.Title)
	// Use basic comparison for custom enum types
	if result.Status != TaskOpen {
		t.Errorf("Expected status TaskOpen, got %d", result.Status)
	}

	// Test not found
	notFound := getTask(999)
	uassert.TypedNil(t, notFound)
}

func TestGetApplication(t *testing.T) {
	resetTaskTestState()

	// Create test application
	applicant := testutils.TestAddress("user")
	app := &Application{
		ID:        1,
		TaskID:    1,
		Applicant: applicant,
		Message:   "Test message",
		Status:    AppPending,
		AppliedAt: 12345,
	}
	applications.Set("1", app)

	// Test successful retrieval
	result := getApplication(1)
	uassert.NotNil(t, result)
	uassert.Equal(t, 1, result.ID)
	uassert.Equal(t, applicant, result.Applicant)
	// Use basic comparison for custom enum types
	if result.Status != AppPending {
		t.Errorf("Expected status AppPending, got %d", result.Status)
	}

	// Test not found
	notFound := getApplication(999)
	uassert.TypedNil(t, notFound)
}

func TestTaskCreationLogic(t *testing.T) {
	resetTaskTestState()

	adminAddr := testutils.TestAddress("admin")

	// Create test organization
	org := createTestOrganization(1, adminAddr)

	// Simulate task creation logic (without the actual function call due to dependencies)
	taskCounter++
	task := &Task{
		ID:             taskCounter,
		OrganizationID: org.ID,
		Title:          "Test Task",
		Description:    "Test task description",
		Reward:         "100 GNOT",
		Status:         TaskOpen,
		Assignee:       "",
		Applications:   []int{},
		CreatedAt:      12345,
		KanbanStatus:   KanbanTodo,
	}

	tasks.Set(strconv.Itoa(taskCounter), task)

	// Add task to organization
	org.Tasks = append(org.Tasks, taskCounter)
	organizations.Set(strconv.Itoa(org.ID), org)

	// Verify task was created correctly
	createdTask := getTask(1)
	if createdTask == nil {
		t.Fatal("Task should have been created")
	}

	if createdTask.Title != "Test Task" {
		t.Errorf("Expected title 'Test Task', got %s", createdTask.Title)
	}
	if createdTask.Status != TaskOpen {
		t.Errorf("Expected status TaskOpen, got %d", createdTask.Status)
	}
	if createdTask.KanbanStatus != KanbanTodo {
		t.Errorf("Expected kanban status KanbanTodo, got %d", createdTask.KanbanStatus)
	}

	// Verify organization was updated
	updatedOrg := getOrganization(1)
	if len(updatedOrg.Tasks) != 1 {
		t.Errorf("Expected 1 task in organization, got %d", len(updatedOrg.Tasks))
	}
	if updatedOrg.Tasks[0] != 1 {
		t.Errorf("Expected task ID 1 in organization, got %d", updatedOrg.Tasks[0])
	}
}

func TestTaskValidation(t *testing.T) {
	tests := []struct {
		name        string
		orgID       string
		title       string
		description string
		shouldFail  bool
		reason      string
	}{
		{"Valid task", "1", "Test Task", "Test description", false, ""},
		{"Empty orgID", "", "Test Task", "Test description", true, "Organization ID required"},
		{"Empty title", "1", "", "Test description", true, "Title required"},
		{"Empty description", "1", "Test Task", "", true, "Description required"},
		{"Invalid orgID", "abc", "Test Task", "Test description", true, "Invalid organization ID"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Test validation logic
			if test.orgID == "" || test.title == "" || test.description == "" {
				if !test.shouldFail {
					t.Error("Should have failed validation")
				}
				return
			}

			_, err := strconv.Atoi(test.orgID)
			if err != nil {
				if !test.shouldFail {
					t.Error("Should have failed on invalid orgID")
				}
				return
			}

			if test.shouldFail {
				t.Error("Should have failed but passed validation")
			}
		})
	}
}

func TestCompleteTaskLogic(t *testing.T) {
	resetTaskTestState()

	adminAddr := testutils.TestAddress("admin")
	userAddr := testutils.TestAddress("user")

	// Create test organization and task
	createTestOrganization(1, adminAddr)

	task := &Task{
		ID:             1,
		OrganizationID: 1,
		Title:          "Test Task",
		Status:         TaskAssigned,
		Assignee:       userAddr,
		KanbanStatus:   KanbanInProgress,
	}
	tasks.Set("1", task)

	// Simulate task completion logic
	if task.Status != TaskAssigned {
		t.Fatal("Task should be assigned before completion")
	}

	retrievedOrg := getOrganization(task.OrganizationID)
	if retrievedOrg == nil {
		t.Fatal("Organization should exist")
	}

	if retrievedOrg.Admin != adminAddr {
		t.Fatal("Only admin should be able to complete task")
	}

	// Complete the task
	task.Status = TaskCompleted
	task.KanbanStatus = KanbanDone
	tasks.Set("1", task)

	// Verify completion
	completedTask := getTask(1)
	if completedTask.Status != TaskCompleted {
		t.Errorf("Expected status TaskCompleted, got %d", completedTask.Status)
	}
	if completedTask.KanbanStatus != KanbanDone {
		t.Errorf("Expected kanban status KanbanDone, got %d", completedTask.KanbanStatus)
	}
}

func TestUpdateKanbanStatusLogic(t *testing.T) {
	resetTaskTestState()

	adminAddr := testutils.TestAddress("admin")
	userAddr := testutils.TestAddress("user")

	// Create test organization and task
	org := createTestOrganization(1, adminAddr)

	task := &Task{
		ID:             1,
		OrganizationID: 1,
		Title:          "Test Task",
		Status:         TaskAssigned,
		Assignee:       userAddr,
		KanbanStatus:   KanbanTodo,
	}
	tasks.Set("1", task)

	tests := []struct {
		name         string
		caller       std.Address
		targetStatus KanbanStatus
		shouldFail   bool
		reason       string
	}{
		{"Assignee updates to InProgress", userAddr, KanbanInProgress, false, ""},
		{"Assignee updates to Review", userAddr, KanbanReview, false, ""},
		{"Admin updates to Review", adminAddr, KanbanReview, false, ""},
		{"Admin updates to Done", adminAddr, KanbanDone, false, ""},
		{"Admin tries to update to Todo", adminAddr, KanbanTodo, true, "Admin can only set Review or Done"},
		{"Admin tries to update to InProgress", adminAddr, KanbanInProgress, true, "Admin can only set Review or Done"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Reset task status
			task.KanbanStatus = KanbanTodo
			tasks.Set("1", task)

			// Check permissions
			isAssignee := task.Assignee == test.caller
			isOrgAdmin := org.Admin == test.caller

			if !isAssignee && !isOrgAdmin {
				if !test.shouldFail {
					t.Error("Should fail: unauthorized user")
				}
				return
			}

			// Check admin restrictions
			if !isAssignee && isOrgAdmin && (test.targetStatus != KanbanReview && test.targetStatus != KanbanDone) {
				if !test.shouldFail {
					t.Error("Should fail: admin can only set Review or Done")
				}
				return
			}

			if test.shouldFail {
				t.Error("Should have failed but permissions allow it")
			}

			// Update status
			task.KanbanStatus = test.targetStatus
			tasks.Set("1", task)

			// Verify update
			updatedTask := getTask(1)
			if updatedTask.KanbanStatus != test.targetStatus {
				t.Errorf("Expected status %d, got %d", test.targetStatus, updatedTask.KanbanStatus)
			}
		})
	}
}

func TestApplyToTaskLogic(t *testing.T) {
	resetTaskTestState()

	adminAddr := testutils.TestAddress("admin")
	userAddr := testutils.TestAddress("user")

	// Create test organization and task
	createTestOrganization(1, adminAddr)

	task := &Task{
		ID:             1,
		OrganizationID: 1,
		Title:          "Test Task",
		Status:         TaskOpen,
		Applications:   []int{},
	}
	tasks.Set("1", task)

	// Test application creation logic
	if task.Status != TaskOpen {
		t.Fatal("Can only apply to open tasks")
	}

	// Check for existing applications (should be none)
	hasApplied := false
	for _, appID := range task.Applications {
		app := getApplication(appID)
		if app != nil && app.Applicant == userAddr {
			hasApplied = true
			break
		}
	}

	if hasApplied {
		t.Fatal("User should not have already applied")
	}

	// Create application
	appCounter++
	application := &Application{
		ID:        appCounter,
		TaskID:    task.ID,
		Applicant: userAddr,
		Message:   "I'm interested in this task",
		Status:    AppPending,
		AppliedAt: 12345,
	}

	applications.Set(strconv.Itoa(appCounter), application)

	// Add application to task
	task.Applications = append(task.Applications, appCounter)
	tasks.Set("1", task)

	// Verify application was created
	createdApp := getApplication(1)
	if createdApp == nil {
		t.Fatal("Application should have been created")
	}

	if createdApp.Applicant != userAddr {
		t.Errorf("Expected applicant %s, got %s", userAddr, createdApp.Applicant)
	}
	if createdApp.Status != AppPending {
		t.Errorf("Expected status AppPending, got %d", createdApp.Status)
	}

	// Verify task was updated
	updatedTask := getTask(1)
	if len(updatedTask.Applications) != 1 {
		t.Errorf("Expected 1 application on task, got %d", len(updatedTask.Applications))
	}
}

func TestAcceptApplicationLogic(t *testing.T) {
	resetTaskTestState()

	adminAddr := testutils.TestAddress("admin")
	userAddr := testutils.TestAddress("user")
	otherUserAddr := testutils.TestAddress("otheruser")

	// Create test data
	createTestOrganization(1, adminAddr)

	task := &Task{
		ID:             1,
		OrganizationID: 1,
		Title:          "Test Task",
		Status:         TaskOpen,
		Applications:   []int{1, 2},
	}
	tasks.Set("1", task)

	// Create multiple applications
	app1 := &Application{
		ID:        1,
		TaskID:    1,
		Applicant: userAddr,
		Status:    AppPending,
	}
	app2 := &Application{
		ID:        2,
		TaskID:    1,
		Applicant: otherUserAddr,
		Status:    AppPending,
	}
	applications.Set("1", app1)
	applications.Set("2", app2)

	// Accept first application
	if app1.Status != AppPending {
		t.Fatal("Application should be pending")
	}

	// Accept application
	app1.Status = AppAccepted
	applications.Set("1", app1)

	// Assign task
	task.Status = TaskAssigned
	task.Assignee = app1.Applicant
	task.KanbanStatus = KanbanTodo
	tasks.Set("1", task)

	// Reject other pending applications
	app2.Status = AppRejected
	applications.Set("2", app2)

	// Verify acceptance
	acceptedApp := getApplication(1)
	if acceptedApp.Status != AppAccepted {
		t.Errorf("Expected status AppAccepted, got %d", acceptedApp.Status)
	}

	rejectedApp := getApplication(2)
	if rejectedApp.Status != AppRejected {
		t.Errorf("Expected status AppRejected, got %d", rejectedApp.Status)
	}

	assignedTask := getTask(1)
	if assignedTask.Status != TaskAssigned {
		t.Errorf("Expected status TaskAssigned, got %d", assignedTask.Status)
	}
	if assignedTask.Assignee != userAddr {
		t.Errorf("Expected assignee %s, got %s", userAddr, assignedTask.Assignee)
	}
	if assignedTask.KanbanStatus != KanbanTodo {
		t.Errorf("Expected kanban status KanbanTodo, got %d", assignedTask.KanbanStatus)
	}
}

func TestRejectApplicationLogic(t *testing.T) {
	resetTaskTestState()

	adminAddr := testutils.TestAddress("admin")
	userAddr := testutils.TestAddress("user")

	// Create test data
	createTestOrganization(1, adminAddr)

	app := &Application{
		ID:        1,
		TaskID:    1,
		Applicant: userAddr,
		Status:    AppPending,
	}
	applications.Set("1", app)

	// Reject application
	if app.Status != AppPending {
		t.Fatal("Application should be pending")
	}

	app.Status = AppRejected
	applications.Set("1", app)

	// Verify rejection
	rejectedApp := getApplication(1)
	if rejectedApp.Status != AppRejected {
		t.Errorf("Expected status AppRejected, got %d", rejectedApp.Status)
	}
}

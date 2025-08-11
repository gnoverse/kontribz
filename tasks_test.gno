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

	// Create test organization and admin
	admin := testutils.TestAddress("admin")
	org := createTestOrganization(1, admin)

	// Create test task
	task := &Task{
		ID:          1,
		OrgID:       1,
		Title:       "Test Task",
		Description: "Test Description",
		Status:      TaskOpen,
		CreatedBy:   admin,
		CreatedAt:   12345,
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
	admin := testutils.TestAddress("admin")
	applicant := testutils.TestAddress("applicant")

	app := &Application{
		ID:        1,
		TaskID:    1,
		Applicant: applicant,
		Message:   "Test application",
		Status:    AppPending,
		CreatedAt: 12345,
	}
	applications.Set("1", app)

	// Test successful retrieval
	result := getApplication(1)
	uassert.NotNil(t, result)
	uassert.Equal(t, 1, result.ID)
	uassert.Equal(t, 1, result.TaskID)
	uassert.Equal(t, applicant, result.Applicant)
	// Use basic comparison for custom enum types
	if result.Status != AppPending {
		t.Errorf("Expected status AppPending, got %d", result.Status)
	}

	// Test not found
	notFound := getApplication(999)
	uassert.TypedNil(t, notFound)
}

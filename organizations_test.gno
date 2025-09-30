package kontribz

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

// Test helper function to reset global state
func resetOrgTestState() {
	organizations = avl.Tree{}
	orgCounter = 0
}

func TestGetOrganization(t *testing.T) {
	resetOrgTestState()

	// Test organization retrieval
	admin := testutils.TestAddress("admin")
	org := &Organization{
		ID:    1,
		Name:  "Test Org",
		Admin: admin,
		Tasks: []int{1, 2},
	}
	organizations.Set("1", org)

	// Test successful retrieval
	result := getOrganization(1)
	uassert.NotNil(t, result)
	uassert.Equal(t, 1, result.ID)
	uassert.Equal(t, "Test Org", result.Name)
	uassert.Equal(t, admin, result.Admin)
	uassert.Equal(t, 2, len(result.Tasks))

	// Test not found
	notFound := getOrganization(999)
	uassert.TypedNil(t, notFound)
}

func TestGetUserOrganizations(t *testing.T) {
	resetOrgTestState()

	admin := testutils.TestAddress("admin")
	otherUser := testutils.TestAddress("other")

	// Create organizations for different users
	org1 := &Organization{ID: 1, Name: "User Org 1", Admin: admin}
	org2 := &Organization{ID: 2, Name: "Other Org", Admin: otherUser}
	org3 := &Organization{ID: 3, Name: "User Org 2", Admin: admin}

	organizations.Set("1", org1)
	organizations.Set("2", org2)
	organizations.Set("3", org3)

	// Test getting user's organizations
	userOrgs := getUserOrganizations(admin)
	uassert.Equal(t, 2, len(userOrgs))

	// Verify correct organizations returned
	orgNames := make(map[string]bool)
	for _, org := range userOrgs {
		orgNames[org.Name] = true
		uassert.Equal(t, admin, org.Admin)
	}

	uassert.True(t, orgNames["User Org 1"])
	uassert.True(t, orgNames["User Org 2"])
	uassert.False(t, orgNames["Other Org"])

	// Test empty case
	emptyUser := testutils.TestAddress("empty")
	emptyOrgs := getUserOrganizations(emptyUser)
	uassert.Equal(t, 0, len(emptyOrgs))
}

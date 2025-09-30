package kontribz

import (
	"chain/runtime"
	"strconv"

	"gno.land/r/demo/profile"
)


func CreateOrganization(cur realm, name, domain, bio, website, avatar string) {
	caller := runtime.OriginCaller()

	if name == "" || domain == "" {
		panic("Name and domain are required")
	}

	userName := profile.GetStringField(caller, "DisplayName", "")
	if userName == "" {
		panic("You need a profile first")
	}

	orgCounter++
	org := &Organization{
		ID:        orgCounter,
		Name:      name,
		Avatar:    avatar,
		Domain:    domain,
		Bio:       bio,
		Website:   website,
		Admin:     caller,
		Tasks:     []int{},
		CreatedAt: runtime.ChainHeight(),
	}

	organizations.Set(strconv.Itoa(orgCounter), org)
}

func getOrganization(orgID int) *Organization {
	orgI, ok := organizations.Get(strconv.Itoa(orgID))
	if !ok {
		return nil
	}
	return orgI.(*Organization)
}

func getUserOrganizations(addr address) []*Organization {
	var userOrgs []*Organization

	organizations.Iterate("", "", func(key string, value interface{}) bool {
		org := value.(*Organization)
		if org.Admin == addr {
			userOrgs = append(userOrgs, org)
		}
		return false
	})

	return userOrgs
}

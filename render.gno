package kontribz

import (
	"chain/runtime"
	"strconv"

	"gno.land/p/nt/mux"
	"gno.land/p/moul/md"
	"gno.land/p/moul/txlink"
	"gno.land/r/demo/profile"
)

func homeHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string
	out += md.H1("🎯 Kontribz - Bounty Manager") + "\n\n"

	out += md.H2("📊 Platform Statistics") + "\n\n"
	orgCount := organizations.Size()
	taskCount := tasks.Size()
	appCount := applications.Size()
	out += md.BulletList([]string{
		md.Bold("Organizations:") + " " + strconv.Itoa(orgCount),
		md.Bold("Tasks:") + " " + strconv.Itoa(taskCount),
		md.Bold("Applications:") + " " + strconv.Itoa(appCount),
	}) + "\n\n"

	out += md.H2("🚀 Quick Actions") + "\n\n"
	out += md.BulletList([]string{
		md.Link("Create Your Profile", realmPath+":profile/create") + " - Start by creating your user profile",
		md.Link("Create Organization", realmPath+":organization/create") + " - Create your organization",
		md.Link("Browse Organizations", realmPath+":organizations") + " - View all organizations",
		md.Link("Browse Tasks", realmPath+":tasks") + " - View all tasks",
		md.Link("Browse Users", realmPath+":users") + " - View all users",
	}) + "\n\n"

	res.Write(out)
}

func userHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	addrStr := req.GetVar("addr")
	addr := address(addrStr)

	// Get profile info
	name := profile.GetStringField(addr, "DisplayName", "Unknown")

	out += md.H1("👤 "+name) + "\n\n"
	out += md.Link("← Back to Users", realmPath+":users") + "\n\n"

	// Profile info
	out += md.Bold("Address:") + " `" + addrStr + "`\n\n"

	// User's organizations
	userOrgs := getUserOrganizations(addr)
	if len(userOrgs) > 0 {
		out += md.H2("🏢 Organizations ("+strconv.Itoa(len(userOrgs))+")") + "\n\n"
		for _, org := range userOrgs {
			out += md.BulletItem(md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID))+" - "+strconv.Itoa(len(org.Tasks))+" tasks") + "\n"
		}
		out += "\n"
	}

	// User's applications
	out += md.H2("📨 Applications") + "\n\n"

	pendingApps := []*Application{}
	acceptedApps := []*Application{}
	rejectedApps := []*Application{}

	applications.Iterate("", "", func(key string, value interface{}) bool {
		app := value.(*Application)
		if app.Applicant == addr {
			switch app.Status {
			case AppPending:
				pendingApps = append(pendingApps, app)
			case AppAccepted:
				acceptedApps = append(acceptedApps, app)
			case AppRejected:
				rejectedApps = append(rejectedApps, app)
			}
		}
		return false
	})

	// Pending applications
	out += md.H3("⏳ Pending ("+strconv.Itoa(len(pendingApps))+")") + "\n\n"
	if len(pendingApps) == 0 {
		out += "No pending applications.\n\n"
	} else {
		pendingItems := []string{}
		for _, app := range pendingApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					pendingItems = append(pendingItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" at "+md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)))
				}
			}
		}
		out += md.BulletList(pendingItems) + "\n\n"
	}

	// Accepted applications (assigned tasks)
	out += md.H3("✅ Accepted/Assigned ("+strconv.Itoa(len(acceptedApps))+")") + "\n\n"
	if len(acceptedApps) == 0 {
		out += "No accepted applications.\n\n"
	} else {
		acceptedItems := []string{}
		for _, app := range acceptedApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					status := getTaskStatusText(task.Status)
					acceptedItems = append(acceptedItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" at "+md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID))+" - "+status)
				}
			}
		}
		out += md.BulletList(acceptedItems) + "\n\n"
	}

	// Rejected applications
	out += md.H3("❌ Rejected ("+strconv.Itoa(len(rejectedApps))+")") + "\n\n"
	if len(rejectedApps) == 0 {
		out += "No rejected applications.\n\n"
	} else {
		rejectedItems := []string{}
		for _, app := range rejectedApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					rejectedItems = append(rejectedItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" at "+md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)))
				}
			}
		}
		out += md.BulletList(rejectedItems) + "\n\n"
	}

	// Personal Kanban Board for assigned tasks
	out += md.H2("📋 Personal Kanban Board") + "\n\n"
	out += md.Link("View Full Kanban", realmPath+":user/"+addrStr+"/kanban") + "\n\n"
	out += renderUserKanbanPreview(addr)

	res.Write(out)
}

func userKanbanHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	addrStr := req.GetVar("addr")
	addr := address(addrStr)

	// Get profile info
	name := profile.GetStringField(addr, "DisplayName", "Unknown")

	out += md.H1("📋 "+name+" - Kanban Board") + "\n\n"
	out += md.Link("← Back to Profile", realmPath+":user/"+addrStr) + "\n\n"

	// Full kanban board
	out += renderUserKanban(addr)

	// Admin actions if viewing own kanban
	caller := runtime.OriginCaller()
	if caller == addr {
		out += md.H2("⚙️ Kanban Actions") + "\n\n"
		out += md.Italic("Update kanban status for your assigned tasks:") + "\n\n"

		// List assigned tasks with update links
		tasks.Iterate("", "", func(key string, value interface{}) bool {
				task := value.(*Task)
				org := getOrganization(task.OrganizationID)
				if task.Assignee == addr && task.Status == TaskAssigned {
					out += md.H3(task.Title) + "\n\n"
					out += md.Bold("Current Status:") + " " + getKanbanStatusText(task.KanbanStatus) + "\n\n"

					// Action links for kanban status
					todoLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "0")     // KanbanTodo
					progressLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "1") // KanbanInProgress
					reviewLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "2")   // KanbanReview
					doneLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "3")     // KanbanDone

					actionItems := []string{
						md.Link("📝 Todo", todoLink),
						md.Link("🔄 In Progress", progressLink),
						md.Link("👀 Review", reviewLink),
						md.Link("✅ Done", doneLink),
				}

				if org != nil && org.Admin == caller {
					completeLink := txlink.Call("CompleteTask", strconv.Itoa(task.ID))
					actionItems = append(actionItems, md.Link("🎉 Complete Task", completeLink))
				}

				out += md.Bold("Update Status:") + "\n"
				out += md.BulletList(actionItems) + "\n\n"
			}
			return false
		})
	}

	res.Write(out)
}

func organizationsHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("🏢 All Organizations") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	orgCount := organizations.Size()
	if orgCount == 0 {
		out += md.Bold("No organizations yet.") + "\n\n"
		out += "Be the first to create one!\n\n"
		out += md.Link("Create First Organization", realmPath+":organization/create") + "\n\n"
		res.Write(out)
		return
	}

	out += md.Bold("Total Organizations:") + " " + strconv.Itoa(orgCount) + "\n\n"

	organizations.Iterate("", "", func(key string, value interface{}) bool {
		org := value.(*Organization)

		adminName := profile.GetStringField(org.Admin, "DisplayName", "Unknown")

		out += md.HorizontalRule() + "\n\n"
		out += md.H3(md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID))) + "\n\n"

		if org.Avatar != "" {
			out += "![Avatar](" + org.Avatar + ")\n\n"
		}

		orgInfoItems := []string{
			md.Bold("Domain:") + " @" + org.Domain,
			md.Bold("Admin:") + " " + adminName + " (`" + org.Admin.String() + "`)",
			md.Bold("Tasks:") + " " + strconv.Itoa(len(org.Tasks)),
		}

		if org.Bio != "" {
			orgInfoItems = append(orgInfoItems, md.Bold("Bio:")+" "+org.Bio)
		}

		if org.Website != "" {
			orgInfoItems = append(orgInfoItems, md.Bold("Website:")+" "+md.Link(org.Website, org.Website))
		}

		out += md.BulletList(orgInfoItems) + "\n\n"
		return false
	})

	res.Write(out)
}

func organizationHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	orgIDStr := req.GetVar("id")
	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Invalid organization ID: " + orgIDStr + "\n"
		res.Write(out)
		return
	}

	org := getOrganization(orgID)
	if org == nil {
		out += md.H1("❌ Not Found") + "\n\n"
		out += "Organization #" + orgIDStr + " not found.\n\n"
		out += md.Link("← Back to Organizations", realmPath+":organizations") + "\n"
		res.Write(out)
		return
	}

	out += md.H1("🏢 "+org.Name) + "\n\n"
	out += md.Link("← Back to Organizations", realmPath+":organizations") + "\n\n"

	if org.Avatar != "" {
		out += "![Avatar](" + org.Avatar + ")\n\n"
	}

	adminName := profile.GetStringField(org.Admin, "DisplayName", "Unknown")

	orgDetailsItems := []string{
		md.Bold("Domain:") + " @" + org.Domain,
		md.Bold("Admin:") + " " + adminName + " (`" + org.Admin.String() + "`)",
	}

	if org.Bio != "" {
		orgDetailsItems = append(orgDetailsItems, md.Bold("Bio:")+" "+org.Bio)
	}

	if org.Website != "" {
		orgDetailsItems = append(orgDetailsItems, md.Bold("Website:")+" "+md.Link(org.Website, org.Website))
	}

	out += md.BulletList(orgDetailsItems) + "\n\n"

	// Tasks
	out += md.H2("📋 Tasks ("+strconv.Itoa(len(org.Tasks))+")") + "\n\n"

	if len(org.Tasks) == 0 {
		out += "No tasks yet.\n\n"
	} else {
		taskItems := []string{}
		for _, taskID := range org.Tasks {
			task := getTask(taskID)
			if task != nil {
				status := getTaskStatusText(task.Status)
				taskItems = append(taskItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" - "+status)
			}
		}
		out += md.BulletList(taskItems) + "\n\n"
	}

	caller := runtime.OriginCaller()
	if caller == org.Admin {
		out += md.H2("⚙️ Admin Actions") + "\n\n"

		createTaskLink := txlink.Call("CreateTask",
			strconv.Itoa(org.ID), // orgID
			"",                   // title
			"",                   // description
			"")                   // reward

		adminActionItems := []string{
			md.Link("Create New Task", createTaskLink),
			"Edit Organization (coming soon)",
		}

		out += md.BulletList(adminActionItems) + "\n\n"

		// Show pending applications for this organization's tasks
		pendingApps := []*Application{}
		for _, taskID := range org.Tasks {
			task := getTask(taskID)
			if task != nil {
				for _, appID := range task.Applications {
					app := getApplication(appID)
					if app != nil && app.Status == AppPending {
						pendingApps = append(pendingApps, app)
					}
				}
			}
		}

		if len(pendingApps) > 0 {
			out += md.H3("📨 Pending Applications ("+strconv.Itoa(len(pendingApps))+")") + "\n\n"

			for _, app := range pendingApps {
				task := getTask(app.TaskID)
				if task != nil {
					applicantName := profile.GetStringField(app.Applicant, "DisplayName", "Unknown")

					out += md.HorizontalRule() + "\n\n"

					appInfoItems := []string{
						md.Bold("Task:") + " " + md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)),
						md.Bold("Applicant:") + " " + md.Link(applicantName, realmPath+":user/"+app.Applicant.String()),
						md.Bold("Applied:") + " Block #" + strconv.FormatInt(app.AppliedAt, 10),
					}

					if app.Message != "" {
						appInfoItems = append(appInfoItems, md.Bold("Message:")+" "+app.Message)
					}

					out += md.BulletList(appInfoItems) + "\n\n"

					acceptLink := txlink.Call("AcceptApplication", strconv.Itoa(app.ID))
					rejectLink := txlink.Call("RejectApplication", strconv.Itoa(app.ID))

					actionItems := []string{
						md.Link("✅ Accept", acceptLink),
						md.Link("❌ Reject", rejectLink),
					}

					out += md.Bold("Actions:") + "\n"
					out += md.BulletList(actionItems) + "\n\n"
				}
			}
		}
	}	
	// Organization Kanban Board
	out += md.H3("📋 Organization Kanban Board") + "\n\n"
	out += md.Link("View Full Kanban", realmPath+":organization/"+strconv.Itoa(org.ID)+"/kanban") + "\n\n"
	out += renderOrganizationKanbanPreview(org)	
	res.Write(out)
}

func organizationKanbanHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	orgIDStr := req.GetVar("id")
	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Invalid organization ID: " + orgIDStr + "\n"
		res.Write(out)
		return
	}

	org := getOrganization(orgID)
	if org == nil {
		out += md.H1("❌ Not Found") + "\n\n"
		out += "Organization #" + orgIDStr + " not found.\n\n"
		res.Write(out)
		return
	}

	out += md.H1("📋 "+org.Name+" - Kanban Board") + "\n\n"
	out += md.Link("← Back to Organization", realmPath+":organization/"+orgIDStr) + "\n\n"

	// Full kanban board for organization
	out += renderOrganizationKanban(org)

	res.Write(out)
}

func profileCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string
	out += md.H1("👤 Create Profile") + "\n\n"
	out += "Click the link below to connect and set up your profile:\n\n"

	connectionLink := "/r/demo/profile$help&func=SetStringField&field=DisplayName&value=Name"
	out += "🔗 " + md.Bold(md.Link("Connection", connectionLink)) + "\n\n"

	out += md.Italic("This will create a basic profile with the display name 'New User'.") + "\n\n"

	res.Write(out)
}

func organizationCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("🏢 Create Organization") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	out += "Create your organization to manage bounties and tasks.\n\n"

	out += md.H2("Organization Form") + "\n\n"
	out += "To create your organization, you can call the `CreateOrganization` function or use these quick templates:\n\n"

	out += md.H3("🚀 Quick Templates") + "\n\n"

	createOrgLink := txlink.Call("CreateOrganization", "name", "", "domain", "", "bio", "", "website", "", "avatar", "")
	out += md.Bold("Create your organizations:") + " " + md.Link("Create", createOrgLink) + "\n\n"

	out += md.Bold("Parameters:") + "\n"
	out += md.BulletList([]string{
		md.Bold("Name") + " (required): Organization name",
		md.Bold("Domain") + " (required): Unique domain/handle",
		md.Bold("Bio") + " (optional): Organization description",
		md.Bold("Website") + " (optional): Organization website",
		md.Bold("Avatar") + " (optional): Organization avatar URL",
	}) + "\n\n"

	res.Write(out)
}

func taskCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("📝 Create Task") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	out += "Create a new task/bounty for one of your organizations.\n\n"

	out += md.H2("Your Organizations") + "\n\n"

		createTaskLink := txlink.Call("CreateTask",
			"", // orgID
			"",                   // title
			"",                   // description
			"")                   // reward

	out += md.Bold("Create task for this organization:") + " " + md.Link("Create Task", createTaskLink) + "\n\n"

	out += md.H2("Task Parameters") + "\n\n"
	out += "When creating a task, you need to provide:\n"
	out += md.BulletList([]string{
		md.Bold("Organization ID") + " (required): ID of your organization",
		md.Bold("Title") + " (required): Task title",
		md.Bold("Description") + " (required): Task description",
		md.Bold("Reward") + " (optional): Reward for completing the task",
	}) + "\n\n"

	res.Write(out)
}

func tasksHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("📋 All Tasks") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	taskCount := tasks.Size()
	if taskCount == 0 {
		out += md.Bold("No tasks yet.") + "\n\n"
		out += "Organizations can create tasks for their bounties.\n\n"
		out += md.Link("Browse Organizations", realmPath+":organizations") + " to find an organization and create tasks.\n\n"
		res.Write(out)
		return
	}

	out += md.Bold("Total Tasks:") + " " + strconv.Itoa(taskCount) + "\n\n"

	// Collect tasks by status
	openTasks := []*Task{}
	assignedTasks := []*Task{}
	completedTasks := []*Task{}

	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		switch task.Status {
		case TaskOpen:
			openTasks = append(openTasks, task)
		case TaskAssigned:
			assignedTasks = append(assignedTasks, task)
		case TaskCompleted:
			completedTasks = append(completedTasks, task)
		}
		return false
	})

	// Display open tasks
	out += md.H2("🟢 Open Tasks ("+strconv.Itoa(len(openTasks))+")") + "\n\n"
	if len(openTasks) == 0 {
		out += "No open tasks.\n\n"
	} else {
		for _, task := range openTasks {
			out += renderTaskSummary(task)
		}
	}

	// Display assigned tasks
	out += md.H2("🟡 Assigned Tasks ("+strconv.Itoa(len(assignedTasks))+")") + "\n\n"
	if len(assignedTasks) == 0 {
		out += "No assigned tasks.\n\n"
	} else {
		for _, task := range assignedTasks {
			out += renderTaskSummary(task)
		}
	}

	// Display completed tasks
	out += md.H2("✅ Completed Tasks ("+strconv.Itoa(len(completedTasks))+")") + "\n\n"
	if len(completedTasks) == 0 {
		out += "No completed tasks.\n\n"
	} else {
		for _, task := range completedTasks {
			out += renderTaskSummary(task)
		}
	}

	res.Write(out)
}

func taskHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	taskIDStr := req.GetVar("id")
	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Invalid task ID: " + taskIDStr + "\n"
		res.Write(out)
		return
	}

	task := getTask(taskID)
	if task == nil {
		out += md.H1("❌ Not Found") + "\n\n"
		out += "Task #" + taskIDStr + " not found.\n\n"
		out += md.Link("← Back to Tasks", realmPath+":tasks") + "\n"
		res.Write(out)
		return
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Organization not found for this task.\n"
		res.Write(out)
		return
	}

	out += md.H1("📝 "+task.Title) + "\n\n"
	out += md.Link("← Back to Tasks", realmPath+":tasks") + " | "
	out += md.Link("View Organization", realmPath+":organization/"+strconv.Itoa(org.ID)) + "\n\n"

	// Task info
	taskInfoItems := []string{
		md.Bold("Organization:") + " " + md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)),
		md.Bold("Status:") + " " + getTaskStatusText(task.Status),
	}

	if task.Reward != "" {
		taskInfoItems = append(taskInfoItems, md.Bold("Reward:")+" "+task.Reward)
	}

	if task.Assignee != "" {
		assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
		taskInfoItems = append(taskInfoItems, md.Bold("Assignee:")+" "+assigneeName+" (`"+task.Assignee.String()+"`)")
		taskInfoItems = append(taskInfoItems, md.Bold("Kanban Status:")+" "+getKanbanStatusText(task.KanbanStatus))
	}

	taskInfoItems = append(taskInfoItems, md.Bold("Created:")+" Block #"+strconv.FormatInt(task.CreatedAt, 10))

	out += md.BulletList(taskInfoItems) + "\n\n"

	out += md.H2("Description") + "\n\n"
	out += task.Description + "\n\n"

	// Applications section
	out += md.H2("📨 Applications ("+strconv.Itoa(len(task.Applications))+")") + "\n\n"

	caller := runtime.OriginCaller()

	// Show apply button if task is open and user hasn't applied
	if task.Status == TaskOpen {
		hasApplied := false
		for _, appID := range task.Applications {
			app := getApplication(appID)
			if app != nil && app.Applicant == caller {
				hasApplied = true
				break
			}
		}

		if !hasApplied {
			out += md.H3("🙋 Apply for this task") + "\n\n"

			applyLink := txlink.Call("ApplyToTask",
				strconv.Itoa(task.ID), // taskID
				"")                    // message

			out += md.Bold("Apply for this task:") + " " + md.Link("Apply", applyLink) + "\n\n"
			out += md.Italic("Note: You can provide a message explaining why you're the right person for this task.") + "\n\n"
		} else {
			out += md.Bold("✅ You have already applied for this task.") + "\n\n"
		}
	}

	// Show applications
	if len(task.Applications) == 0 {
		out += "No applications yet.\n\n"
	} else {
		for _, appID := range task.Applications {
			app := getApplication(appID)
			if app != nil {
				status := getApplicationStatusText(app.Status)
				applicantName := profile.GetStringField(app.Applicant, "DisplayName", "Unknown")

				out += md.HorizontalRule() + "\n\n"

				appInfoItems := []string{
					md.Bold("Applicant:") + " " + applicantName + " (`" + app.Applicant.String() + "`)",
					md.Bold("Status:") + " " + status,
					md.Bold("Applied:") + " Block #" + strconv.FormatInt(app.AppliedAt, 10),
				}

				if app.Message != "" {
					appInfoItems = append(appInfoItems, md.Bold("Message:")+" "+app.Message)
				}

				out += md.BulletList(appInfoItems) + "\n"

				// Admin actions for pending applications
				if caller == org.Admin && app.Status == AppPending {
					out += "\n" + md.Bold("Admin Actions:") + "\n"
					out += md.Italic("Go to your "+md.Link("organization page", realmPath+":organization/"+strconv.Itoa(org.ID))+" to accept or reject applications.") + "\n"
				}

				out += "\n"
			}
		}
	}

	// Admin actions
	if caller == org.Admin {
		out += md.H2("⚙️ Admin Actions") + "\n\n"
		adminActions := []string{}
		if task.Status == TaskOpen {
			adminActions = append(adminActions, "Review applications above to assign this task")
		} else if task.Status == TaskAssigned {
			adminActions = append(adminActions, "Task is currently assigned to "+profile.GetStringField(task.Assignee, "DisplayName", "Unknown"))
		}
		adminActions = append(adminActions, "Edit Task (coming soon)")
		adminActions = append(adminActions, "Delete Task (coming soon)")

		out += md.BulletList(adminActions) + "\n\n"
	}

	res.Write(out)
}

func usersHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("👥 All Users") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	// Collect all unique users from organizations, tasks, and applications
	userSet := make(map[string]bool)

	// Collect users from organizations (admins)
	organizations.Iterate("", "", func(key string, value interface{}) bool {
		org := value.(*Organization)
		userSet[org.Admin.String()] = true
		return false
	})

	// Collect users from tasks (assignees)
	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		if task.Assignee != "" {
			userSet[task.Assignee.String()] = true
		}
		return false
	})

	// Collect users from applications (applicants)
	applications.Iterate("", "", func(key string, value interface{}) bool {
		app := value.(*Application)
		userSet[app.Applicant.String()] = true
		return false
	})

	if len(userSet) == 0 {
		out += md.Bold("No users found yet.") + "\n\n"
		out += "Users will appear here as they create organizations, apply to tasks, or get assigned to tasks.\n\n"
		res.Write(out)
		return
	}

	out += md.Bold("Total Users:") + " " + strconv.Itoa(len(userSet)) + "\n\n"

	// Display users
	for addrStr := range userSet {
		addr := address(addrStr)
		name := profile.GetStringField(addr, "DisplayName", "Unknown")

		out += md.HorizontalRule() + "\n\n"
		out += md.H3(md.Link(name, realmPath+":user/"+addrStr)) + "\n\n"

		// Count user's organizations
		userOrgs := getUserOrganizations(addr)

		// Count user's applications
		userAppCount := 0
		applications.Iterate("", "", func(key string, value interface{}) bool {
			app := value.(*Application)
			if app.Applicant == addr {
				userAppCount++
			}
			return false
		})

		// Count assigned tasks
		assignedTaskCount := 0
		tasks.Iterate("", "", func(key string, value interface{}) bool {
			task := value.(*Task)
			if task.Assignee == addr {
				assignedTaskCount++
			}
			return false
		})

		userInfoItems := []string{
			md.Bold("Address:") + " `" + addrStr + "`",
			md.Bold("Organizations:") + " " + strconv.Itoa(len(userOrgs)),
			md.Bold("Applications:") + " " + strconv.Itoa(userAppCount),
			md.Bold("Assigned Tasks:") + " " + strconv.Itoa(assignedTaskCount),
		}

		out += md.BulletList(userInfoItems) + "\n\n"
	}

	res.Write(out)
}

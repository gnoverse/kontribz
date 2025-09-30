package kontribz

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/mux"
)

var (
	router        = mux.NewRouter()
	realmPath     = "/r/kontribz"
	organizations avl.Tree // orgID -> *Organization
	tasks         avl.Tree // taskID -> *Task
	applications  avl.Tree // appID -> *Application
	orgCounter    int      // organization counter
	taskCounter   int      // task counter
	appCounter    int      // application counter
)

func init() {
	router.HandleFunc("", homeHandler)
	router.HandleFunc("profile/create", profileCreateHandler)
	router.HandleFunc("organization/create", organizationCreateHandler)
	router.HandleFunc("organization/{id}", organizationHandler)
	router.HandleFunc("organization/{id}/kanban", organizationKanbanHandler)
	router.HandleFunc("organizations", organizationsHandler)
	router.HandleFunc("task/create", taskCreateHandler)
	router.HandleFunc("task/{id}", taskHandler)
	router.HandleFunc("tasks", tasksHandler)
	router.HandleFunc("users", usersHandler)
	router.HandleFunc("user/{addr}", userHandler)
	router.HandleFunc("user/{addr}/kanban", userKanbanHandler)
}

func Render(path string) string {
	return router.Render(path)
}

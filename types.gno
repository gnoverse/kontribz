package kontribz



type Organization struct {
	ID        int
	Name      string
	Avatar    string
	Domain    string
	Bio       string
	Website   string
	Admin     address
	Tasks     []int // task IDs
	CreatedAt int64
}


type Task struct {
	ID             int
	OrganizationID int
	Title          string
	Description    string
	Reward         string
	Status         TaskStatus
	Assignee       address
	Applications   []int // application IDs
	CreatedAt      int64
	KanbanStatus   KanbanStatus // for kanban tracking
}


type Application struct {
	ID        int
	TaskID    int
	Applicant address
	Message   string
	Status    ApplicationStatus
	AppliedAt int64
}


type TaskStatus int

const (
	TaskOpen TaskStatus = iota
	TaskAssigned
	TaskCompleted
)


type ApplicationStatus int

const (
	AppPending ApplicationStatus = iota
	AppAccepted
	AppRejected
)


type KanbanStatus int

const (
	KanbanTodo KanbanStatus = iota
	KanbanInProgress
	KanbanReview
	KanbanDone
)
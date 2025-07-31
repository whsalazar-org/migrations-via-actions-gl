package github

type GraphQLResponse struct {
	Data   interface{} `json:"data"`
	Errors []struct {
		Message string `json:"message"`
	} `json:"errors,omitempty"`
}

type QueryVariables struct {
	Login string `json:"login"`
}

type OrgResponse struct {
	Organization struct {
		Login      string `json:"login"`
		ID         string `json:"id"`
		Name       string `json:"name"`
		DatabaseID int    `json:"databaseId"`
	} `json:"organization"`
}

type MigrationSourceInput struct {
	Name    string `json:"name"`
	URL     string `json:"url"`
	OwnerID string `json:"ownerId"`
	Type    string `json:"type"`
}

type MigrationSourceResponse struct {
	CreateMigrationSource struct {
		MigrationSource struct {
			ID   string `json:"id"`
			Name string `json:"name"`
			URL  string `json:"url"`
			Type string `json:"type"`
		} `json:"migrationSource"`
	} `json:"createMigrationSource"`
}

type MigrationInput struct {
	SourceID             string `json:"sourceId"`
	OwnerID              string `json:"ownerId"`
	SourceRepositoryURL  string `json:"sourceRepositoryUrl"`
	RepositoryName       string `json:"repositoryName"`
	ContinueOnError      bool   `json:"continueOnError"`
	SkipReleases         bool   `json:"skipReleases"`
	GitArchiveURL        string `json:"gitArchiveUrl"`
	MetadataArchiveURL   string `json:"metadataArchiveUrl"`
	AccessToken          string `json:"accessToken"`
	GithubPat            string `json:"githubPat"`
	TargetRepoVisibility string `json:"targetRepoVisibility"`
	LockSource           bool   `json:"lockSource"`
}

type MigrationState struct {
	Node struct {
		ID              string `json:"id"`
		SourceURL       string `json:"sourceUrl"`
		DatabaseID      string `json:"databaseId"`
		MigrationSource struct {
			Name string `json:"name"`
			URL  string `json:"url"`
		} `json:"migrationSource"`
		State          string `json:"state"`
		FailureReason  string `json:"failureReason"`
		RepositoryName string `json:"repositoryName"`
	} `json:"node"`
}

type MigrationResponse struct {
	StartRepositoryMigration struct {
		RepositoryMigration struct {
			ID              string `json:"id"`
			DatabaseID      string `json:"databaseId"`
			MigrationSource struct {
				ID   string `json:"id"`
				Name string `json:"name"`
				Type string `json:"type"`
			} `json:"migrationSource"`
			SourceURL string `json:"sourceUrl"`
		} `json:"repositoryMigration"`
	} `json:"startRepositoryMigration"`
}

type GHECExportInput struct {
	Repositories    []string `json:"repositories"`
	LockRepos       bool     `json:"lock_repositories"`
	ExcludeGitData  bool     `json:"exclude_git_data"`
	ExcludeReleases bool     `json:"exclude_releases"`
	ExcludeMetadata bool     `json:"exclude_metadata"`
	OutputPath      string   `json:"output_path"`
}

type GHECExportResponse struct {
	ID        int64  `json:"id"`
	GUID      string `json:"guid"`
	State     string `json:"state"`
	LockRepos bool   `json:"lock_repositories"`
	StartedAt string `json:"started_at"`
	URL       string `json:"url"`
}

type GHEMigratorOptions struct {
	SSHUser         string   // e.g. "admin"
	SourceUsername  string   // e.g. "gheadmin"
	SourceHost      string   // e.g. "github.example.com"
	SourceToken     string   // your personal access token to avoid prompts
	Repositories    []string // in "org/repo" format; optional
	Organizations   []string // optional: if you want all source repositories for an organization
	ExcludeMetadata []string // metadata types to exclude (e.g., "wikis", "projects")
	ExcludeGitData  bool     // flag to exclude Git data
	OutputDir       string   // local directory to save the migration archive
}
type UploadArchiveInput struct {
	ArchiveFilePath string
	OrganizationId  string
}

type UploadArchiveResponse struct {
	GUID      string `json:"guid"`
	NodeID    string `json:"node_id"`
	Name      string `json:"name"`
	Size      int    `json:"size"`
	URI       string `json:"uri"`
	CreatedAt string `json:"created_at"`
}

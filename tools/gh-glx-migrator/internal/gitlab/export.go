package gitlab

import (
  "fmt"
  "os"
  "os/exec"
  "path/filepath"
)

// GLExporterOptions holds configuration to run the gl-exporter.
type GLExporterOptions struct {
  CsvFile           string
  OutputFile        string
  GitLabAPIEndpoint string
  GitLabUsername    string
  GitLabAPIToken    string
  DockerImage       string
  GitLabNamespace   string
  GitLabProject     string
}

// ExportFromGitLab runs the gl-exporter Docker image to export repositories from GitLab.
func ExportFromGitLab(opts *GLExporterOptions) error {
  // Validate parameters.
  if opts.OutputFile == "" {
    return fmt.Errorf("output file is required")
  }
  if opts.GitLabAPIEndpoint == "" || opts.GitLabUsername == "" || opts.GitLabAPIToken == "" {
    return fmt.Errorf("GitLab API endpoint, username, and API token are required")
  }
  if opts.DockerImage == "" {
    opts.DockerImage = "github/gl-exporter"
  }

  // Get absolute path of the output directory and output file name
  outputDir := filepath.Dir(opts.OutputFile)
  outputFileName := filepath.Base(opts.OutputFile)
  outputDirAbs, err := filepath.Abs(outputDir)
  if err != nil {
    return fmt.Errorf("failed to get absolute path of output directory: %w", err)
  }

  // Prepare docker arguments common to both commands.
  commonDockerArgs := []string{
    "run", "--rm",
    "-v", fmt.Sprintf("%s:/workspace", outputDirAbs),
    "-e", fmt.Sprintf("GITLAB_API_ENDPOINT=%s", opts.GitLabAPIEndpoint),
    "-e", fmt.Sprintf("GITLAB_USERNAME=%s", opts.GitLabUsername),
    "-e", fmt.Sprintf("GITLAB_API_PRIVATE_TOKEN=%s", opts.GitLabAPIToken),
    opts.DockerImage,
  }
  var dockerArgs []string

  // Check if CSV file exists.
  if _, err := os.Stat(opts.CsvFile); os.IsNotExist(err) {
    dockerArgs = append(commonDockerArgs,
      "gl_exporter",
      "--namespace", opts.GitLabNamespace,
      "--project", opts.GitLabProject,
      "-o", outputFileName,
    )
    fmt.Printf("CSV file not found, using namespace '%s' and project '%s' for export\n", opts.GitLabNamespace, opts.GitLabProject)
  } else {
    csvAbs, err := filepath.Abs(opts.CsvFile)
    if err != nil {
      return fmt.Errorf("failed to get absolute path of CSV file: %w", err)
    }
    dockerArgs = append([]string{
      "run", "--rm",
      "-v", fmt.Sprintf("%s:/workspace/export.csv", csvAbs),
      "-v", fmt.Sprintf("%s:/workspace", outputDirAbs),
      "-e", fmt.Sprintf("GITLAB_API_ENDPOINT=%s", opts.GitLabAPIEndpoint),
      "-e", fmt.Sprintf("GITLAB_USERNAME=%s", opts.GitLabUsername),
      "-e", fmt.Sprintf("GITLAB_API_PRIVATE_TOKEN=%s", opts.GitLabAPIToken),
      opts.DockerImage,
      "gl_exporter", "-f", "export.csv", "-o", outputFileName,
    }, []string{}...)
  }

  cmd := exec.Command("docker", dockerArgs...)
  cmd.Stdout = os.Stdout
  cmd.Stderr = os.Stderr

  fmt.Printf("Executing docker command: docker %v\n", dockerArgs)
  if err := cmd.Run(); err != nil {
    return fmt.Errorf("gl-exporter docker command failed: %w", err)
  }

  return nil
}

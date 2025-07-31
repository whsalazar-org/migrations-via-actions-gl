package main

import (
	"fmt"
	"os"

	"github.com/ps-resources/gh-glx-migrator/cmd"
	"github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/spf13/cobra"
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "gh-glx",
		Short: "GitHub GitLab Migration Tool",
	}

	// Add commands
	rootCmd.AddCommand(
		cmd.HelpCmd(),
		cmd.VerifyCmd(),
		cmd.ExportArchiveCmd(),
		cmd.UploadToS3BucketCmd(),
		cmd.GeneratePresignedURLCmd(),
		cmd.GetOrgInfoCmd(),
		cmd.CreateMigrationSourceCmd(),
		cmd.StartMigrationCmd(),
		cmd.ExportGHECCmd(),
		cmd.UploadToAzureCmd(),
		cmd.ImportArchiveCmd(),
	)

	if err := rootCmd.Execute(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
}

// Improve performance
func init() {
	logger.InitLogger()
	defer logger.SyncLogger()
}

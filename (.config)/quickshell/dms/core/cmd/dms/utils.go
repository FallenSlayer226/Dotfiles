package main

import (
	"fmt"
	"os/exec"
)

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

// findCommandPath returns the absolute path to a command in PATH
func findCommandPath(cmd string) (string, error) {
	path, err := exec.LookPath(cmd)
	if err != nil {
		return "", fmt.Errorf("command '%s' not found in PATH", cmd)
	}
	return path, nil
}

func isArchPackageInstalled(packageName string) bool {
	cmd := exec.Command("pacman", "-Q", packageName)
	err := cmd.Run()
	return err == nil
}

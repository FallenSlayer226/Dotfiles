package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds/providers"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/spf13/cobra"
)

var keybindsCmd = &cobra.Command{
	Use:     "keybinds",
	Aliases: []string{"cheatsheet", "chsht"},
	Short:   "Manage keybinds and cheatsheets",
	Long:    "Display and manage keybinds and cheatsheets for various applications",
}

var keybindsListCmd = &cobra.Command{
	Use:   "list",
	Short: "List available providers",
	Long:  "List all available keybind/cheatsheet providers",
	Run:   runKeybindsList,
}

var keybindsShowCmd = &cobra.Command{
	Use:   "show <provider>",
	Short: "Show keybinds for a provider",
	Long:  "Display keybinds/cheatsheet for the specified provider",
	Args:  cobra.ExactArgs(1),
	Run:   runKeybindsShow,
}

func init() {
	keybindsShowCmd.Flags().String("hyprland-path", "$HOME/.config/hypr", "Path to Hyprland config directory")
	keybindsShowCmd.Flags().String("mangowc-path", "$HOME/.config/mango", "Path to MangoWC config directory")
	keybindsShowCmd.Flags().String("sway-path", "$HOME/.config/sway", "Path to Sway config directory")

	keybindsCmd.AddCommand(keybindsListCmd)
	keybindsCmd.AddCommand(keybindsShowCmd)

	keybinds.SetJSONProviderFactory(func(filePath string) (keybinds.Provider, error) {
		return providers.NewJSONFileProvider(filePath)
	})

	initializeProviders()
}

func initializeProviders() {
	registry := keybinds.GetDefaultRegistry()

	hyprlandProvider := providers.NewHyprlandProvider("$HOME/.config/hypr")
	if err := registry.Register(hyprlandProvider); err != nil {
		log.Warnf("Failed to register Hyprland provider: %v", err)
	}

	mangowcProvider := providers.NewMangoWCProvider("$HOME/.config/mango")
	if err := registry.Register(mangowcProvider); err != nil {
		log.Warnf("Failed to register MangoWC provider: %v", err)
	}

	swayProvider := providers.NewSwayProvider("$HOME/.config/sway")
	if err := registry.Register(swayProvider); err != nil {
		log.Warnf("Failed to register Sway provider: %v", err)
	}

	config := keybinds.DefaultDiscoveryConfig()
	if err := keybinds.AutoDiscoverProviders(registry, config); err != nil {
		log.Warnf("Failed to auto-discover providers: %v", err)
	}
}

func runKeybindsList(cmd *cobra.Command, args []string) {
	registry := keybinds.GetDefaultRegistry()
	providers := registry.List()

	if len(providers) == 0 {
		fmt.Fprintln(os.Stdout, "No providers available")
		return
	}

	fmt.Fprintln(os.Stdout, "Available providers:")
	for _, name := range providers {
		fmt.Fprintf(os.Stdout, "  - %s\n", name)
	}
}

func runKeybindsShow(cmd *cobra.Command, args []string) {
	providerName := args[0]

	registry := keybinds.GetDefaultRegistry()

	if providerName == "hyprland" {
		hyprlandPath, _ := cmd.Flags().GetString("hyprland-path")
		hyprlandProvider := providers.NewHyprlandProvider(hyprlandPath)
		registry.Register(hyprlandProvider)
	}

	if providerName == "mangowc" {
		mangowcPath, _ := cmd.Flags().GetString("mangowc-path")
		mangowcProvider := providers.NewMangoWCProvider(mangowcPath)
		registry.Register(mangowcProvider)
	}

	if providerName == "sway" {
		swayPath, _ := cmd.Flags().GetString("sway-path")
		swayProvider := providers.NewSwayProvider(swayPath)
		registry.Register(swayProvider)
	}

	provider, err := registry.Get(providerName)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}

	sheet, err := provider.GetCheatSheet()
	if err != nil {
		log.Fatalf("Error getting cheatsheet: %v", err)
	}

	output, err := json.MarshalIndent(sheet, "", "  ")
	if err != nil {
		log.Fatalf("Error generating JSON: %v", err)
	}

	fmt.Fprintln(os.Stdout, string(output))
}

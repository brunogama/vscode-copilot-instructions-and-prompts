
# VSCode Copilot Instructions & Prompts

This repository provides a structured set of instructions, prompts, and custom agent commands for enhancing the behavior of GitHub Copilot and Copilot Chat within Visual Studio Code. It is designed to help you:

- Define and enforce clean code guidelines
- Create custom agent commands for automation
- Maintain consistent coding standards across your projects
- Extend Copilot's capabilities with project-specific rules

## Features

- **Clean Code Guidelines:**
  - Enforce best practices such as meaningful names, single responsibility, DRY, encapsulation, and more (see `.github/instructions/clean.instructions.md`).
- **Custom Agent Commands:**
  - Define and trigger custom commands (e.g., `Command.ls`) to automate tasks directly from Copilot Chat (see `.github/instructions/custom-agent-commands.instructions.md`).
- **Contextual Prompts:**
  - Add project-specific instructions and context to guide Copilot's suggestions.
- **Extensible Structure:**
  - Easily add new rules, commands, or prompt files for your team's needs.

## Repository Structure

- `.github/instructions/` — Main instruction and prompt files for Copilot and agents
- `scripts/` — Example shell scripts referenced by custom commands
- `README.md` — This documentation
- `LICENSE` — License information

## Usage

1. **Clone this repository** into your project or reference its structure for your own Copilot customization.
2. **Edit or extend** the instruction files in `.github/instructions/` to match your team's coding standards and automation needs.
3. **Restart VS Code** or reload Copilot Chat to apply changes.

## References & Further Reading

- [GitHub Copilot Custom Instructions Documentation](https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot)
- [VS Code Copilot Customization & Prompt Files](https://code.visualstudio.com/docs/copilot/copilot-customization)

---
Feel free to contribute improvements or new instruction sets via pull requests!

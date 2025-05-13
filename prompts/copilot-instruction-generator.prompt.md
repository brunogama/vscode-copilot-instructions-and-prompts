---
mode: "agent"
tools: []
description: "This template will guide you through creating instructions that effectively control Copilot's behavior and ensure it follows your project's standards and conventions."
---

# GitHub Copilot Instruction Generator

## Overview

This template will guide you through creating instructions that effectively control Copilot's behavior and ensure it follows your project's standards and conventions.

## Instructions

Answer the following questions to generate custom instructions for GitHub Copilot. The template will use your responses to create a main `.github/copilot-instructions.md` file and suggest additional domain-specific instruction files as needed.

## Project Information

**Project Name:**
[Provide your project name]

**Primary Programming Languages:**
[List all programming languages used in the project, e.g., TypeScript, Python, etc.]

**Frameworks and Libraries:**
[List key frameworks and libraries used in the project, e.g., React, Express, Django, etc.]

**Project Type:**
[Describe the type of project: Web application, Mobile app, API, CLI tool, etc.]

**Version Control:**
[Git conventions for your project, e.g., branch naming, commit message format]

## Coding Standards

### Naming Conventions

[Describe your naming conventions for different code elements:

- Variables (camelCase, snake_case, etc.)
- Functions/Methods
- Classes
- Constants
- Files
- Components
- Database entities
- API endpoints]

### Code Formatting

[Describe your code formatting standards:

- Indentation (spaces/tabs, amount)
- Line length
- Bracket style
- Comment style
- Import organization]

### Architecture Standards

[Describe your architectural patterns and principles:

- Project structure
- Design patterns to use/avoid
- Layer separation
- State management
- Error handling approach
- Security principles]

### Testing Standards

[Describe your testing requirements:

- Test frameworks
- Coverage requirements
- Naming conventions for tests
- Mocking practices
- Test organization]

### Documentation Standards

[Describe your documentation requirements:

- Comment style for functions/classes
- README standards
- API documentation
- Required documentation sections]

## Domain-Specific Standards

### Frontend Standards

[If applicable, describe standards specific to frontend development:

- Component structure
- State management
- Styling approach
- Accessibility requirements]

### Backend Standards

[If applicable, describe standards specific to backend development:

- API design principles
- Database access patterns
- Authentication/Authorization approach
- Error response format]

### Mobile Standards

[If applicable, describe standards specific to mobile development:

- UI component structure
- Navigation patterns
- State management
- Platform-specific considerations]

### Data Standards

[If applicable, describe standards for data handling:

- Data models
- Validation approaches
- Data access patterns
- Privacy considerations]

## Examples

### Good Code Examples

[Provide 2-3 examples of code that follows your project's standards]

### Bad Code Examples

[Provide 2-3 examples of code that violates your project's standards]

## Additional Instructions

[Include any additional instructions or context that would help Copilot understand your project better]

---

## Output Format

After filling out the sections above, the template will generate:

1. A main `.github/copilot-instructions.md` file containing project-wide instructions
2. Additional `.github/instructions/*.instructions.md` files for domain-specific instructions
3. Guidance on how to ensure these instructions are properly loaded by Copilot

---

_When you've completed this template, save it as `.github/copilot-instruction-generator.md` in your project, and ask GitHub Copilot to generate instructions based on your responses._

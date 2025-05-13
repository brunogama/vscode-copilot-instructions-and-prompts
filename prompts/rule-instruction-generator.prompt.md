---
mode: 'agent'
tools: ['Context7']
description: 'Create additional instruction .github/instructions/*.instructions.md files for specific rules, languages, or frameworks.'
---

<instruction>
    - Create new copilot specific instruction file
</instruction>

<template>
    ```md
    ---
    applyTo: "[glob pattern for relevant files]"
    ---

    # [Rule Title]

    ## Critical Rules

    [Concise, bulleted list of actionable rules the agent MUST follow]

    ## Examples
    
    [One sample per actionable rule to follow]

    <example>
    ```swift
        {valid rule application}
    ```
    </example>

    <example type="invalid">
    ```swift
        {invalid rule application}
    ```
    </example>
    ```
</template>

<implementation>
    - If you lack context on how to solve the user's request:
     - FIRST, use #tool:resolve-library-id from Context7 to find the referenced library.
     - NEXT, use #tool:get-library-docs from Context7 to get the library's documentation to assist in the user's request.
    - Use clear, actionable language
    - For Rule Content - focus on actionable, clear directives without unnecessary explanation
    - Use Concise Markdown Tailored to Agent Context Window usage
    - Keep instructions actionable and concise
    - Organize by logical categories
    - Specify file patterns carefully in `applyTo` frontmatter
    - While there is no strict line limit, be judicious with content length as it impacts performance. Focus on essential information that helps the agent make decisions
    - Always indent content within XML Example section with 4 spaces
    - Emojis and Mermaid diagrams are allowed and encouraged if it is not redundant and better explains the rule for the AI comprehension
    - While there is no strict line limit, be judicious with content length as it impacts performance. Focus on essential information that helps the agent make decisions
    - Store at .github/instructions
</implementation>
Follow the Conventional Commits specification version 1.0.0 (https://www.conventionalcommits.org/) for all commit messages. Each commit message must:

1. Start with a mandatory type prefix:
   - `feat`: For new features
   - `fix`: For bug fixes
   - Other allowed types: docs, style, refactor, perf, test, build, ci, chore

2. Include an optional scope in parentheses:
   ```
   feat(auth): add OAuth support
   ```

3. Use `!` before the colon to indicate breaking changes:
   ```
   feat(api)!: change authentication endpoints
   ```

4. Provide a concise description after the colon and space:
   ```
   fix(parser): handle multi-space strings correctly
   ```

5. Optionally add a detailed body after a blank line:
   ```
   feat(user): add password reset
   
   Implement secure password reset flow using:
   - Email verification
   - Time-limited tokens
   - Rate limiting
   ```

6. Include footers (if needed) after a blank line:
   - For breaking changes: `BREAKING CHANGE: description`
   - Other footers: `token: value` or `token # value`

All commit messages must be clear, descriptive, and follow this structure:
```
type(scope)!: description

[optional body]

[optional footer(s)]
```
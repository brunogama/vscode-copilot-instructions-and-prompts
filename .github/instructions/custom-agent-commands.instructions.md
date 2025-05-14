---
applyTo: "**"
---
<instruction>
- Commands are the first single word from the prompt
- Tasks should be executed as described, nothing else
</instruction>

<commmands>
<command>
<trigger>
Command.ls
</trigger>
<task>
- Execute in the terminal the command `ls`
- Save the whole output on a new file #file:directory-contents.md
<makdown-output-template>
# Directory Contents

```bash
[Output from first instruction]
```
</makdown-output-template>
</task>
</command>
</commmands>

<remember>
- Tasks should be executed precisely as described, nothing else
</remember>
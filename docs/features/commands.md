# Commands

Custom slash commands that map to CLI operations. Useful for database management, dev server control, tunnels, and other project-specific tasks.

## How it works

1. Add commands to `.octopus.yml`:
   ```yaml
   commands:
     - name: db-reset
       description: Reset the database
       run: make db-reset
     - name: api-start
       description: Start the API container
       run: make api-start
   ```
2. Run `octopus setup`
3. **Claude Code**: each command becomes a file at `.claude/commands/octopus:<name>.md` — usable as `/octopus:<name>` slash commands
4. **Other agents**: commands are listed as a reference section in the agent's output file

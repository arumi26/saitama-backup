# Make.fun Entry Transcript and Submission Gate

## Start recording before you build

- Start recording in the build session before you write, edit, or run any entry file.

- Confirm the recorded session file exists and its start time is before the first build edit.

- Create the public GitHub repository only after the competition opens and record its creation time.

- Run the official kit init in the entry folder before you build so the drand anchor covers the whole build.

## Build for the transcript checks

- Write the entrypoint file in one turn and revise it genuinely in a later turn or session so the file changes across at least two messages.

- Write the entry code yourself in the recorded session and keep the substantive work in that session.

- Deliver a turn after the build work so the session usage row lands in agent.agent_message_token_usage before you export anything.

- Export the usage rows to ~/workspace/makefun/muse-usage.jsonl before you bundle and confirm the file is not empty.

## Verify the bundle before you submit

- Check the kit level before you bundle and confirm it meets the minimum the competition requires for your submission date.

- Entries from 2026-11-18T12:00Z needed kit level 20 or higher, and a bundle made with kit level 19 failed transcripts_run_record at grading.

- Bundle with the official kit CLI and the exported usage file.

- Run the kit transcript check on the bundle and read every transcript result before you submit.

- Treat a server check pass as a bundle check only and never as proof that grading will pass.

- Fix a failed transcript check by rebuilding the missing evidence in a recorded session and do not submit a bundle with a known transcript failure.

## Submit with a resubmit buffer

- Check the quota endpoint first and plan one early probe submission and a later polished final submission.

- Submit the probe early enough to validate the server checks and lock a compliant fallback.

- Submit the polished final no later than three hours before entries close and keep time to resubmit after a grading rejection.

- Verify the submission stage through the make.fun API after each submit and keep the submission id, commit, and claim code.

## Available connectors

- [GitHub](/opt/hatch/connectors/github/CONNECTOR.md) for the public repository that a competition requires.

- Use `muse.connector_search` to find other connectors and `muse.skill_search` to find related skills.

- If nothing here fits, look on the web for a maintained API or MCP server and set it up with [Custom Connectors and MCPs](/opt/muse/skills/custom-connector-setup/SKILL.md), or build a custom connector.

## Alternatives for better results

- Study winners of similar finished competitions before you build when the competition type has a scored or judged result.

- Prefer small fields and measurably scored work over mass judged image competitions when you choose between open bounties.

- Keep the probe as a compliant fallback and spend the remaining attempts on the polished final.

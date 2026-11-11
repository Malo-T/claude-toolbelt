import type { Register } from 'claude-code'

// A file the main loop writes under .../handoffs/<project>/ becomes the pending handoff.
// "<name>.later.md" is for a later day: it never triggers anything.
const HANDOFF = /\/handoffs\/[^/]+\/[^/]+\.md$/
const LATER = /\.later\.md$/

const resumePrompt = (file: string) =>
  `Resume from the handoff ${file}: read it, say in three lines where things stand, check that ` +
  `the state it describes is still true (git status, the files it names), and propose the next ` +
  `step. Run nothing before I agree.`

// Module state: a reload drops it, which is fine, a handoff is consumed within one turn.
let pending: string | undefined

export const register: Register = on => {
  on('tool.call', { tool: 'Write' }, async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny === undefined && ran.isError !== true && HANDOFF.test(e.file_path) && !LATER.test(e.file_path)) {
      pending = e.file_path
    }
    return ran
  }).catch(($, e, next) => next(e))

  // /clear and the resume wait for the end of the turn that wrote the handoff, and run from a timer:
  // $.command.run is refused inside a hook the turn waits on.
  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (e.agentId !== undefined || pending === undefined) return done
    if (e.reason !== 'answer') {
      pending = undefined
      return done
    }

    const file = pending
    pending = undefined
    $.clock.after(300, async () => {
      try {
        await $.command.run({ command: 'clear', args: '' })
        await $.prompt.submit({ text: resumePrompt(file) })
      } catch {
        $.ui.toast(`handoff written, but /clear failed: type /clear, then ask to resume from ${file}`)
      }
    })
    return done
  })
}

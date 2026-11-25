export const meta = {
  name: 'two-steps',
  description: 'Ask one helper, then one that takes its time',
  phases: [{ title: 'First' }, { title: 'Second' }],
}
phase('First')
const a = await agent('Reply with one word: alpha.', { label: 'first', phase: 'First' })
phase('Second')
const again = typeof args === 'object' && args !== null && args.again === true
const b = await agent(again ? 'Reply with one word: go.' : 'Reply with one word: wait.', { label: 'second', phase: 'Second' })
return { a, b }

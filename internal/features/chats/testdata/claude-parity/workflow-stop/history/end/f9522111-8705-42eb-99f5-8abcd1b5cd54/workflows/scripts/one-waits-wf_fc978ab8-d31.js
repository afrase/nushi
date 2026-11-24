export const meta = {
  name: 'one-waits',
  description: 'Ask one helper that takes its time',
  phases: [{ title: 'Wait' }],
}
phase('Wait')
return await agent('Reply with one word: wait.', { label: 'wait', phase: 'Wait' })

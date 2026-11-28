export const meta = {
  name: 'handmade',
  description: 'A helper that makes a worktree itself',
  phases: [{ title: 'Work', detail: 'one helper' }],
}
phase('Work')
return await agent('Make a worktree yourself.', { label: 'handmade', phase: 'Work' })

export const meta = {
  name: 'isolated',
  description: 'Three helpers, each in a worktree',
  phases: [{ title: 'Work', detail: 'three helpers, one after another' }],
}
phase('Work')
const a = await agent('Commit in your worktree.', { label: 'commit', phase: 'Work', isolation: 'worktree' })
const b = await agent('Change nothing in your worktree.', { label: 'nothing', phase: 'Work', isolation: 'worktree' })
const c = await agent('Leave a file in your worktree.', { label: 'file', phase: 'Work', isolation: 'worktree' })
return { a, b, c }

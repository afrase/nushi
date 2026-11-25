export const meta = {
  name: 'two-phases',
  description: 'Ask four helpers in two phases',
  phases: [
    { title: 'Map', detail: 'two helpers' },
    { title: 'Review', detail: 'two more' },
  ],
}
phase('Map')
const a = await parallel([
  () => agent('Reply with one word: alpha.', { label: 'map:alpha', phase: 'Map' }),
  () => agent('Reply with one word: beta.', { label: 'map:beta', phase: 'Map' }),
])
phase('Review')
const b = await parallel([
  () => agent('Reply with one word: gamma.', { label: 'review:gamma', phase: 'Review' }),
  () => agent('Reply with one word: delta.', { label: 'review:delta', phase: 'Review', schema: { type: 'object', properties: { word: { type: 'string' } }, required: ['word'] } }),
])
return { a, b }

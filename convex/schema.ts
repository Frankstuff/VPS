import { defineSchema } from 'convex/server';

// Start with public read-only endpoints. No personal data or SMS consent is
// stored yet. Add private tables together with authenticated access controls.
export default defineSchema({});

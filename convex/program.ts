import { v } from 'convex/values';
import { query } from './_generated/server';

// This is public information only. Returning a status does not enroll anyone.
export const getPublicStatus = query({
  args: {},
  returns: v.object({
    name: v.string(),
    stage: v.literal('preview'),
    smsEnrollmentOpen: v.literal(false),
    smsRecipient: v.literal('accountability_partner'),
    advanceWarning: v.literal('optional_notification'),
  }),
  handler: () => ({
    name: 'Pester AI',
    stage: 'preview' as const,
    smsEnrollmentOpen: false as const,
    smsRecipient: 'accountability_partner' as const,
    advanceWarning: 'optional_notification' as const,
  }),
});

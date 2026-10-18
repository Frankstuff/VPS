# Turning the preview into a real program

## Product behavior represented by this frontend

- Pester AI sends automated SMS alerts to the consenting accountability partner.
- The person focusing receives no program SMS. They can choose an advance notification or no advance notification before the agreed partner alert.
- Both participants agree to the same focus triggers, shared information, sending window, time zone, and daily SMS limit for the partner. Any warning period is also part of the agreement.
- The SMS recipient independently verifies and consents for their own number. The person focusing separately accepts sharing their focus status; notification permission is another independent choice.
- A participant personally shares an invitation link. Do not send unsolicited SMS invitations to a friend's number.
- Changing an agreement requires fresh acceptance by both people.
- Either participant withdrawing ends that shared agreement for both.
- This initial program is free; carrier message/data rates can apply.

The role choices, sample missed-check-in trigger, frequency choices, and warning preference in the UI are illustrative proposals. They are not implemented product settings or evidence of actual consent. Confirm the trigger mechanism and limits before opening enrollment. Nothing in the preview detects Instagram use, observes browser activity, requests device permission, or sends notifications.

## Suggested backend responsibilities

Use Better Auth for accounts and managed Convex Cloud for application functions and data. Self-hosting is postponed. Bird keys stay in backend configuration.

The initial backend code provides a public program-status query and `/health`; see [convex.md](convex.md) for connecting a cloud deployment and testing those endpoints. There are no personal-data tables or consent-writing functions yet. The responsibilities below describe the next implementation stage.

Store versioned agreements, authenticated participant identities and roles, the SMS recipient's verified number, and each participant's agreement acceptance. Store SMS consent separately from focus-information sharing permission and notification preferences/subscriptions. Keep evidence of the precise disclosure, source, server timestamp, purpose, and agreement version consented to. If applicable, retain IP/source evidence according to the disclosed retention policy. A boolean named `consented` on its own is not sufficient evidence.

Activation should be transactional: both authenticated participants have accepted the same current version and the SMS recipient has verified their number and opted in. One participant cannot accept for another, and no invite, notification permission, or login automatically creates SMS consent.

For optional advance warnings, a visible in-app notice only works while the app is running. Web push can reach a supported subscribed browser without an open page; it needs permission, a service worker, a push subscription, and a backend sender. Keep push subscription credentials private and remove expired subscriptions. The preview implements none of these.

Keep warning deadlines and scheduled partner alerts in durable backend state, not a browser timer. Recheck whether the focus event is still actionable after any agreed grace period. Decide and disclose what happens if notification permission is denied or delivery fails; don't promise that a warning was seen just because it was sent. Never fall back to SMS to the person focusing without separate SMS consent. Turning off device notifications is distinct from explicitly leaving the agreement.

Scheduling a text and sending it are different moments. Immediately before every send, check current agreement status, recipient consent, applicable Bird preferences/suppressions, time window, and frequency budget. Cancel queued work when either participant leaves. Deduplicate logical messages so job retries don't intentionally send the same alert twice.

Use a scoped topic/program for the correct consent scope. Follow Bird's documented preference APIs and verify whether writes applied. A Bird sender-level suppression alone does not cancel your application's agreement or stop scheduled messages to its other participant; your backend must do that too.

Authenticate and deduplicate incoming Bird webhooks, handle failures, and synchronize opt-outs. A STOP should revoke the relevant recipient's program permission, end affected agreements, and prevent future automatic sends. Do not treat START as automatically restoring an ended two-person agreement.

Configure consistent branded confirmation, HELP, and STOP replies. Avoid sending duplicate auto-replies if Bird already handles the keyword. The public website lists support email only; the contact mobile number supplied for brand registration is not an allocated Bird sender.

## Before live signup and registration

The website is reviewable as a **proposed** flow. It must not be represented as live enrollment until enrollment works. No brand or campaign has been submitted by this frontend work.

The website was consolidated and reviewed locally on October 18, 2026. This work does not check or change the Bird account, submit a brand or campaign, allocate a number, or send SMS. Before any future submission, verify the account's current requirements and use the final published product description and opt-in flow. A website preview is not proof of working enrollment or a guarantee of registration approval.

Decisions still needed for a working product:

1. The actual focus signal and how the user grants any necessary device permissions.
2. How people invite one another and verify their own numbers.
3. The final frequency limits, windows, treatment of service confirmations, optional warning period, and behavior when a notification is unavailable or undelivered.
4. Sender number, branded keyword replies, Bird registration, and operational testing.
5. Hosting-log, consent, message, account, focus-event, and backup retention policies.
6. Which data any AI provider receives and for what purpose.

Only after those are implemented should the preview notices and draft-policy language be replaced with the actual live behavior. Do not simply remove the notices to imply that the backend exists.

## References

- [Bird consent and evidence](https://bird.com/explained/sms/how-do-i-collect-sms-opt-ins)
- [Bird 10DLC registration](https://bird.com/docs/guides/sms/10dlc)
- [Bird keyword handling](https://bird.com/docs/guides/sms/opt-outs-and-keywords)
- [Browser push notifications](https://developer.mozilla.org/en-US/docs/Web/API/Push_API)
- [Convex + Better Auth React integration](https://labs.convex.dev/better-auth/framework-guides/react)
- [Convex Cloud setup](https://docs.convex.dev/cli/overview)

import './main';

// This is deliberately a browser-only demonstration. It does not collect a
// phone number, save consent, send invitations, or call Bird. A real enrollment
// will need both people's acceptance plus the SMS recipient's verified consent.
const form = document.querySelector<HTMLFormElement>('#signup-preview')!;
const controls = document.querySelector<HTMLFieldSetElement>('#preview-controls')!;
const role = document.querySelector<HTMLSelectElement>('#role')!;
const maximum = document.querySelector<HTMLSelectElement>('#maximum')!;
const windowChoice = document.querySelector<HTMLSelectElement>('#window')!;
const timezone = document.querySelector<HTMLSelectElement>('#timezone')!;
const warningMode = document.querySelector<HTMLSelectElement>('#warning-mode')!;
const consent = document.querySelector<HTMLInputElement>('#sms-consent')!;
const sharing = document.querySelector<HTMLInputElement>('#sharing-consent')!;
const submit = document.querySelector<HTMLButtonElement>('#review-button')!;
const result = document.querySelector<HTMLElement>('#preview-result')!;
const reviewDetails = document.querySelector<HTMLDListElement>('#review-details')!;

const updatePreview = () => {
  const isPartner = role.value === 'partner';
  const wantsWarning = warningMode.value === 'notify';
  document.querySelector<HTMLElement>('#summary-role')!.textContent = role.selectedOptions[0].textContent;
  document.querySelector<HTMLElement>('#summary-frequency')!.textContent = `Up to ${maximum.value} program texts per day to the partner`;
  document.querySelector<HTMLElement>('#summary-window')!.textContent = `${windowChoice.selectedOptions[0].textContent} (${timezone.selectedOptions[0].textContent})`;
  document.querySelector<HTMLElement>('#summary-warning')!.textContent = wantsWarning
    ? 'An advance notification to the person focusing'
    : 'No advance notification to the person focusing';
  document.querySelector<HTMLElement>('#phone-fields')!.hidden = !isPartner;
  document.querySelector<HTMLElement>('#sms-consent-fields')!.hidden = !isPartner;
  document.querySelector<HTMLElement>('#focus-channel-note')!.hidden = isPartner;
  consent.required = isPartner;
  consent.disabled = !isPartner;
  document.querySelector<HTMLElement>('#sharing-text')!.textContent = isPartner
    ? 'In the planned service, I would accept this agreement and the agreed focus-status updates from my chosen friend. My acceptance would not enroll anyone else. This preview shares nothing.'
    : 'In the planned service, I would accept this agreement and allow Pester AI to share the agreed focus-status updates with my chosen partner after they opt in. This does not sign me up for SMS. This preview shares nothing.';
  document.querySelector<HTMLElement>('#consent-frequency')!.textContent = maximum.value;
  document.querySelector<HTMLElement>('#sample-label')!.textContent = isPartner
    ? 'EXAMPLE SMS TO THE PARTNER'
    : wantsWarning ? 'EXAMPLE NOTIFICATION TO THE PERSON FOCUSING' : 'NO ADVANCE NOTIFICATION';
  document.querySelector<HTMLElement>('#sample-message')!.textContent = isPartner
    ? 'Pester AI: Alex missed the focus check-in you both agreed on. A little encouragement might help. Automated accountability alert. Reply STOP to opt out; HELP for help.'
    : wantsWarning
      ? 'Pester AI: Your agreed alert to Jamie is coming up. Time to lock in and return to your focus session.'
      : 'The agreed SMS alert would go to your consenting partner without an advance notification to you. You would not receive an SMS yourself.';
  consent.checked = false;
  sharing.checked = false;
  result.hidden = true;
  submit.textContent = 'Review this example';
};

// Register handlers BEFORE enabling the controls: the form must never submit
// personal information to the static host, even when JavaScript is unavailable.
form.addEventListener('submit', (event) => {
  event.preventDefault();
  if (!form.reportValidity()) return;
  const items = [
    ['Your example role', role.selectedOptions[0].textContent ?? ''],
    ['Partner messages', `Up to ${maximum.value} program texts per day, plus enrollment confirmations and STOP/HELP replies`],
    ['Message window', `${windowChoice.value} (${timezone.value})`],
    ['Advance notification', warningMode.value === 'notify' ? 'Requested by the person focusing' : 'None'],
    ['SMS consent', role.value === 'partner' ? 'Reviewed for the fictional number +1 (202) 555-0142. Not recorded.' : 'Not applicable to your role. Your partner must opt in separately.'],
  ];
  reviewDetails.replaceChildren(...items.map(([label, value]) => {
    const row = document.createElement('div');
    const term = document.createElement('dt');
    const description = document.createElement('dd');
    term.textContent = label;
    description.textContent = value;
    row.append(term, description);
    return row;
  }));
  result.hidden = false;
  result.focus();
  submit.textContent = 'Review this example again';
});

for (const input of [role, maximum, windowChoice, timezone, warningMode]) {
  input.addEventListener('change', updatePreview);
}
for (const checkbox of [consent, sharing]) {
  checkbox.addEventListener('change', () => {
    result.hidden = true;
    submit.textContent = 'Review this example';
  });
}

updatePreview();
controls.disabled = false;

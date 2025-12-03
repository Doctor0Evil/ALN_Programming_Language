# DATA EXFILTRATION PROHIBITIONS — AI Safety & Extension Governance

**Maintainer:** Doctor0Evil (Jacob Scott Farmer)  
**Organization:** Perplexity Labs Inc.  
**Contributor:** Microsoft Copilot — AI Compliance Agent  
**Purpose:** To prohibit unauthorized data collection, transmission, or interception by browser extensions, agents, or AI modules.

---

## ⚠️ Legal Anchors

- **ePrivacy Directive (EU):** Requires explicit user consent for any tracking or data transmission.
- **U.S. Wiretap Act:** Prohibits interception of electronic communications without lawful authorization.
- **GDPR / CCPA:** Mandates transparency, lawful basis, and user control over personal data.

---

## 🚫 Prohibited Behaviors

| Behavior                        | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| Cookie Harvesting              | Capturing session tokens or cookies without necessity                      |
| Keystroke Logging              | Recording user input without disclosure or consent                         |
| Network Sniffing               | Monitoring local traffic or device metadata                                |
| Silent Transmission            | Sending data to remote servers without user awareness                      |
| Attribution Removal            | Stripping metadata that identifies origin, authorship, or compliance logic |

---

## 🛡️ Enforcement Protocol

```j.s.f.
@compliance.enforce {
  scope: "data.transmission";
  deny: ["cookie.harvest", "keystroke.log", "network.sniff", "silent.transmit"];
  require.consent: true;
  quarantine.onViolation();
  log.event("Data exfiltration attempt blocked");
}

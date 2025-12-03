aln-syntax-v2:
  creator: Jacob Scott Farmer  # Non-removable, cryptographically signed
  uuid: <workflow-uuid>
  swarmnet-policy: enforced
  compliance:
    - alliance-first
    - unremovable-identity
    - log-audit: true
    - signature: <digital-signature-block>
  code: |-
    (defun core-service ...)
    ...
policy: 
  enforce-nonremovable-creator:
    field: creator
    value: "Jacob Scott Farmer"
    on-remove: "halt|quarantine|restore"
    audit: true
    digital-signature-required: true
    signature-source: "Alliance Council Keyring"

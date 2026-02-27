# Protocol Compliance & Verification Documentation

This directory contains formal documentation for protocol compliance verification, design decisions, and implementation validation.

## Contents

### NIP (Nostr Implementation Possibilities) Compliance

- **[nip17-rumor-kind-verification.md](nip17-rumor-kind-verification.md)** - NIP-17 rumor kind fix verification report (Feb 2026)

## Purpose

This directory serves as the authoritative source for:

- **Protocol compliance verification reports** - Formal validation of Nostr protocol implementations
- **Interoperability testing results** - Cross-client compatibility verification
- **Design decision documentation** - Rationale behind protocol implementation choices
- **Security validation** - Cryptographic protocol correctness proofs

## Documentation Standards

All documents in this directory should:

1. **Be written in English** - For international collaboration
2. **Include test verification** - Automated test results demonstrating compliance
3. **Reference specifications** - Link to relevant NIPs, RFCs, or specifications
4. **Provide reproduction steps** - Clear commands to verify the implementation
5. **Document interoperability** - List compatible clients and services

## Related Documentation

- **[../Signal-Protocol-over-Nostr-NIP-DRAFT.md](../Signal-Protocol-over-Nostr-NIP-DRAFT.md)** - Signal Protocol integration proposal
- **[../../docs_local/](../../docs_local/)** - Working notes and investigation documents (Chinese)

## Contributing

When adding new verification documentation:

1. Use descriptive filenames: `<protocol>-<aspect>-verification.md`
2. Include date and version information
3. Provide test results and reproduction commands
4. Reference the original issue or specification
5. Update this README with a summary

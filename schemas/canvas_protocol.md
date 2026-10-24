# Sovereign Canvas Protocol (SCM-002)

## Record Format

Line-oriented, bounded records. Maximum line length: 512 bytes.
Maximum record size: 4096 bytes.

### Header

```
SCM-CANVAS/1.0
INTENT <uuid>
WORKSPACE <BRAID|QUANTUM|RECURRENCE>
STATUS UNVERIFIED
```

### BRAID Workspace Fields

```
TARGET <generator>*
CANDIDATE <generator>*
COST <positive-integer>
TRANSFORMATIONS <count>
PROOF_OBLIGATIONS <id>*
RESOURCE_ESTIMATE <cycles> <memory>
END
```

Generators: s1, s2, s1_inv, s2_inv

### Validation Rules

- Intent ID must be a valid UUID or SCM-prefixed identifier.
- Workspace must be one of the three supported types.
- STATUS must be UNVERIFIED for model proposals.
- All fields required for the workspace type.
- No shell metacharacters, no absolute paths, no executable content.

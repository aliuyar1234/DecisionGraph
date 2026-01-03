# API Contract: Canonical JSON Serialization

**SSOT Reference**: Section 6.1.5

## Function Signature

```python
def canonicalize_json(obj: Any) -> str:
    """
    Serialize object to canonical JSON string.

    Args:
        obj: Python object (dict, list, str, int, bool, None)

    Returns:
        Canonical JSON string (UTF-8, sorted keys, no whitespace)

    Raises:
        DecisionGraphError: DG_ERR_SCHEMA_VIOLATION if float detected
    """
```

## Serialization Rules

### 1. Key Ordering

Object keys MUST be sorted lexicographically by Unicode code points.

```python
# Input
{"z": 1, "a": 2, "m": 3}

# Output
'{"a":2,"m":3,"z":1}'
```

### 2. No Whitespace

No spaces or newlines between tokens.

```python
# Correct
'{"a":1,"b":2}'

# Wrong
'{"a": 1, "b": 2}'
'{\n  "a": 1\n}'
```

### 3. No Floats

Floats are rejected at any nesting depth.

```python
# These all raise DG_ERR_SCHEMA_VIOLATION
canonicalize_json({"price": 19.99})
canonicalize_json({"nested": {"value": 1.5}})
canonicalize_json([1.0, 2.0, 3.0])
```

Use string representation for decimals:
```python
# Correct
{"price": "19.99"}
```

### 4. String Escaping

Only escape required characters:
- `"` → `\"`
- `\` → `\\`
- Control characters (U+0000 to U+001F) → `\uXXXX`

### 5. Booleans

Lowercase `true` and `false`.

### 6. Null

Represented as `null`.

### 7. Integers

No leading zeros, no decimal point.

```python
# Correct
42
-17
0

# Wrong
42.0
007
```

### 8. Nested Objects

Rules apply recursively.

```python
# Input
{"outer": {"z": 1, "a": 2}}

# Output
'{"outer":{"a":2,"z":1}}'
```

## Hashing

After canonicalization, hash with SHA-256:

```python
def sha256_prefixed(data: bytes) -> str:
    """Return sha256:<hex> hash."""
    import hashlib
    digest = hashlib.sha256(data).hexdigest()
    return f"sha256:{digest}"

# Usage
canonical = canonicalize_json(payload)
payload_hash = sha256_prefixed(canonical.encode("utf-8"))
```

## Verification

To verify a payload hash:

```python
def verify_payload_hash(payload: dict, expected_hash: str) -> bool:
    canonical = canonicalize_json(payload)
    computed = sha256_prefixed(canonical.encode("utf-8"))
    return computed == expected_hash
```

## Test Vectors

| Input | Canonical Output |
|-------|------------------|
| `{}` | `'{}'` |
| `{"a": 1}` | `'{"a":1}'` |
| `{"b": 2, "a": 1}` | `'{"a":1,"b":2}'` |
| `{"a": "hello"}` | `'{"a":"hello"}'` |
| `{"a": true}` | `'{"a":true}'` |
| `{"a": null}` | `'{"a":null}'` |
| `[1, 2, 3]` | `'[1,2,3]'` |
| `{"a": {"c": 3, "b": 2}}` | `'{"a":{"b":2,"c":3}}'` |

## Hash Test Vectors

| Canonical JSON | SHA-256 Hash |
|----------------|--------------|
| `'{}'` | `sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a` |

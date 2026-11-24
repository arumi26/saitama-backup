# crypto

Most CTF crypto is a parameter mistake, not a broken primitive. Read the parameters first.

## RSA

Given `n, e, c`:

| Condition | Attack |
| --- | --- |
| small `e` (3), `m^e < n` | integer `e`-th root |
| same `m`, several `(n_i, e)` | Hastad / CRT broadcast |
| same `n`, two coprime `e` | common modulus, Bézout |
| `p`, `q` close | Fermat factorisation |
| `d` small | Wiener, then Boneh-Durfee if needed |
| `n` shares a factor with another `n` | GCD across a batch |
| `p = getPrime(512); q = next_prime(p)` | difference is small, brute the gap |

```python
from gmpy2 import iroot
m, exact = iroot(c, 3)          # small-e, no padding
from sympy import factorint, gcd
```

Partial key exposure, `d` recovery from `e*d ≡ 1 (mod φ)`, and Coppersmith for small roots are all
lattice work: `fpylll`, `sage -python`. Wiener:

```python
from sage.all import continued_fraction
for conv in continued_fraction(e / n).convergents():
    k, d = conv.numerator(), conv.denominator()
    if k and (e * d - 1) % k == 0:
        phi = (e * d - 1) // k
```

## Block ciphers

- ECB: identical plaintext blocks → identical ciphertext. Cut-and-paste with `openssl enc -aes-128-ecb -nopad`.
- CBC bit-flipping: flip bit `i` of block `n-1` to flip bit `i` of the decrypted block `n`. Corrupts
  the whole previous block — put padding there.
- Padding oracle: iterate the last byte, look for a padding error vs a MAC error. `padbuster` or a
  hand-rolled loop.
- IV reuse in CTR: `C1 ^ C2 = P1 ^ P2`; crib-drag with English frequencies.

## Stream / XOR

Known-plaintext XOR → recover the keystream. Repeating-key XOR → Hamming distance for the key size,
then per-column frequency. Single-byte: score by `etaoin shrdlu`.

## PRNG

Python `random`: 624 consecutive 32-bit outputs → clone the Mersenne state (`randcrack`). LCG:
solve for the modulus from three outputs, then predict.

## Hashes

Length extension on `H(secret || msg)` with MD5/SHA-1/SHA-256 (`hashpumpy`, `hash_extender`).
Collision on MD5 pairs where the app compares hashes. `hashcat -m <mode>` for anything with a
recoverable preimage.

## Encoding, not crypto

`base64 -d`, `xxd -r -p`, `zsteg`, `cyberchef` for chains. A "cipher" that decodes to readable text
with a trivially wrong key was never a cipher.

## Deliverable

The plaintext plus the exact solve script. Parameter recovery goes into `notes.md` with the arithmetic.

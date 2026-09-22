/// A `known_hosts` file with everything the format allows, for the parser
/// and import tests.
///
/// The keys are throwaway public keys generated with `ssh-keygen` for this
/// fixture (their private halves were deleted on the spot), and the
/// fingerprints and hashed lines below are exactly what OpenSSH printed for
/// them — `ssh-keygen -lf` and `ssh-keygen -H` — so the tests check this
/// app against OpenSSH itself, not against its own idea of the format.
library;

const kEd25519Key =
    'AAAAC3NzaC1lZDI1NTE5AAAAIAQSRVOK4Nsa1msvV6eO4JsyHYeh0EQgW6GFGnV1+Mwr';
const kEd25519Fingerprint =
    'SHA256:O6utq9BX1U2QwtkMho8NlVwaqRId+gMIl+0omB5W6iY';

const kRsaKey =
    'AAAAB3NzaC1yc2EAAAADAQABAAABAQC2LYndFo++G0EG6VNcDfcKtDPH81G7HWMzWeOa8OnBg8H'
    'RjsWe0zcuNfxwZS/Q0Zz2Lqbcx0uGyzf1sgDckWbSs4oOQiE8AxBrZ37WBQ5qXlcjEk4BWFDBBx'
    'fBu96OfBpBDVj0lQx2k4AFrNthH6ZkLGaCxlydCup7dl3GA2g8d7dEsYoEMkF2TJmYj6roQR1w4'
    'MzH0CKPisQBE2J8cM5ZIF6US6jUhb+BwTj0vNV7Kbc59RP9MmQp48RTlKDbn35lFOBEzZdxIA6S'
    'cGLRSP/hmjQ/FO7myzdgBzvwCOf5tgCJbUIHcruFv2ZGqkgCmlqr6KSA2ZaObmxxf2Rr8pc9';
const kRsaFingerprint = 'SHA256:vhPj5EwHUSPHFc1uHNbyz+OlfloTvAlpVSHIDbsiDMY';

const kEcdsaKey =
    'AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCIyfN91np2I4m4FAEAERDL'
    'w25+PbPQM0/Vv50EoENUGBsIn/QcuuxJQjVRecj0lyttYre/dC7qywDEm9FwjSSY=';
const kEcdsaFingerprint = 'SHA256:7etX3TBhsr5z5eRWWAgjfvVoPziE7DE7k7d4y0Jejao';

/// `ssh-keygen -H` of `example.com` (the Ed25519 key).
const kHashedExampleCom =
    '|1|WrhIv44iZt1cxf3WKo+020t/8lE=|fJXdAEmvfb/J9OV/stlXRNRW7iI=';

/// `ssh-keygen -H` of `[example.org]:2222` (the RSA key).
const kHashedExampleOrg2222 =
    '|1|Dz4O+OM00eEV/tnk+D8Ue1fteJU=|o/zczUTNPn51E64H5Mp3ut5z4dE=';

/// Line numbers are part of the assertions — keep additions at the end.
const kKnownHostsFixture =
    '''
# Comments and blank lines are ignored.

plain.example.com ssh-ed25519 $kEd25519Key
Multi.Example.com,10.0.0.5,[multi.example.com]:2200 ecdsa-sha2-nistp256 $kEcdsaKey a comment
[bastion.example.net]:2222 ssh-rsa $kRsaKey
$kHashedExampleCom ssh-ed25519 $kEd25519Key
$kHashedExampleOrg2222 ssh-rsa $kRsaKey
*.wild.example.com,!neg.example.com,exact.example.com ssh-ed25519 $kEd25519Key
@revoked revoked.example.com ssh-ed25519 $kEd25519Key
@cert-authority *.corp.example.com ssh-ed25519 $kEd25519Key
old.example.com ssh-dss AAAAB3NzaC1kc3MAAACBAP
broken line
typo.example.com ssh-ed25519 !!!not-base64!!!
liar.example.com ssh-rsa $kEd25519Key
[unclosed.example.com:22 ssh-ed25519 $kEd25519Key
plain.example.com ssh-rsa $kRsaKey
@weird host ssh-ed25519 $kEd25519Key
''';

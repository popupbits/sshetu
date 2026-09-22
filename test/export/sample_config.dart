import 'package:sshetu/core/ssh/host_key.dart';
import 'package:sshetu/core/ssh/openssh_import.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/features/export/domain/portable_export.dart';
import 'package:sshetu/features/hosts/domain/host_group.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';

// A configuration that sets every field the export carries, to a value
// other than its default — so a field dropped anywhere on the way out or
// back in shows up as a difference.

const kPublicKey =
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP1kR7QhQxPPFdMbCfvhLDNyIYAmYaLPnJTMkQGDtxNu me@laptop';

final t0 = DateTime.utc(2026, 1, 2, 3, 4, 5, 678);
final t1 = DateTime.utc(2026, 2, 3, 4, 5, 6, 789);
final t2 = DateTime.utc(2026, 3, 4, 5, 6, 7, 890);

final sampleGroup = HostGroup(
  id: 'g-work',
  name: 'Work',
  sortOrder: 3,
  createdAt: t0,
  updatedAt: t1,
);

final identity = SshIdentity(
  id: 'k-laptop',
  label: 'laptop',
  keyType: 'ssh-ed25519',
  publicKey: kPublicKey,
  fingerprint: OpenSshScanner.fingerprintOf(kPublicKey),
  hasPassphrase: true,
  origin: IdentityOrigin.generated,
  createdAt: t0,
  updatedAt: t1,
);

final bastion = SshHost(
  id: 'h-bastion',
  label: 'bastion',
  hostname: 'bastion.example.com',
  port: 2222,
  username: 'jump',
  authMethod: SshAuthMethod.password,
  keepaliveSeconds: 15,
  createdAt: t0,
  updatedAt: t1,
);

final web = SshHost(
  id: 'h-web',
  label: 'web-1',
  hostname: 'web1.internal',
  port: 22,
  username: 'deploy',
  groupId: 'g-work',
  identityId: 'k-laptop',
  jumpHostId: 'h-bastion',
  allowLegacyAlgorithms: true,
  forwardAgent: true,
  tmuxMode: HostTmuxMode.never,
  keepaliveSeconds: 0,
  startupCommand: 'tmux new -A -s main',
  terminalTheme: 'dracula',
  fontSize: 15.5,
  notes: 'Primary web node.\nRestart with care.',
  tags: const ['prod', 'web'],
  envVars: const {'EDITOR': 'vim', 'LANG': 'en_US.UTF-8'},
  lastConnectedAt: t2,
  createdAt: t0,
  updatedAt: t1,
);

final forward = Tunnel(
  id: 't-db',
  hostId: 'h-web',
  label: 'Postgres',
  kind: TunnelKind.local,
  listenHost: '127.0.0.1',
  listenPort: 15432,
  targetHost: 'db.internal',
  targetPort: 5432,
  autoStart: true,
  createdAt: t0,
  updatedAt: t1,
);

final socks = Tunnel(
  id: 't-socks',
  hostId: 'h-bastion',
  label: 'SOCKS',
  kind: TunnelKind.socks,
  listenPort: 1080,
  createdAt: t0,
  updatedAt: t1,
);

final snippet = Snippet(
  id: 's-disk',
  label: 'Disk usage',
  body: 'df -h {{path}}\ndu -sh *',
  description: 'Where did the space go',
  tags: const ['ops'],
  sortOrder: 2,
  createdAt: t0,
  updatedAt: t1,
);

final pin = KnownHostKey(
  hostname: 'web1.internal',
  port: 22,
  keyType: 'ssh-ed25519',
  fingerprint: 'SHA256:abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
  trustedAt: t1,
);

PortableExport sampleExport({DateTime? at}) => PortableExport(
  exportedAt: at ?? DateTime.utc(2026, 9, 22, 10),
  app: '1.0.0+1',
  groups: [sampleGroup],
  identities: [identity],
  hosts: [web, bastion],
  tunnels: [socks, forward],
  snippets: [snippet],
  knownHosts: [pin],
);

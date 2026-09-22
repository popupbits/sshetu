/// Extensions (lowercased, no dot) that are text often enough that a
/// double-click opens the editor rather than doing nothing. The editor
/// still refuses a file that turns out to be binary, so a wrong guess costs
/// one message, not a corrupted file.
const _textExtensions = {
  'txt',
  'md',
  'log',
  'csv',
  'tsv',
  'conf',
  'cfg',
  'cnf',
  'ini',
  'env',
  'properties',
  'toml',
  'yaml',
  'yml',
  'json',
  'xml',
  'plist',
  'service',
  'timer',
  'socket',
  'rules',
  'list',
  'sh',
  'bash',
  'zsh',
  'fish',
  'py',
  'rb',
  'pl',
  'php',
  'lua',
  'go',
  'rs',
  'c',
  'h',
  'cc',
  'cpp',
  'hpp',
  'java',
  'kt',
  'swift',
  'dart',
  'cs',
  'js',
  'mjs',
  'cjs',
  'ts',
  'jsx',
  'tsx',
  'vue',
  'svelte',
  'html',
  'htm',
  'css',
  'scss',
  'sql',
  'tf',
  'hcl',
  'nginx',
  'vim',
  'gitignore',
  'dockerignore',
  'editorconfig',
  'pub',
  'pem',
  'crt',
};

/// Whole names with no telling extension that are nearly always text.
const _textNames = {
  'dockerfile',
  'makefile',
  'vagrantfile',
  'gemfile',
  'procfile',
  'readme',
  'license',
  'changelog',
  'authorized_keys',
  'known_hosts',
  'config',
  'hosts',
  'fstab',
  'crontab',
  'sudoers',
  'passwd',
  'group',
  'hostname',
  'resolv.conf',
};

/// Whether [name] is a file the editor should open on a double-click.
///
/// Dotfiles (`.bashrc`, `.profile`, `.gitconfig`) count: almost every one
/// is configuration text, and they are exactly what people SSH in to edit.
bool isLikelyTextFile(String name) {
  final lower = name.toLowerCase();
  if (_textNames.contains(lower)) return true;
  final dot = lower.lastIndexOf('.');
  if (dot == 0) return true;
  if (dot < 0 || dot == lower.length - 1) return false;
  return _textExtensions.contains(lower.substring(dot + 1));
}

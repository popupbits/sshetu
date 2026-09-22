import 'dart:typed_data';

/// A `.reg` export of PuTTY's sessions, written the way `reg export` writes
/// it (CRLF line ends), covering what the importer has to cope with. Made up
/// for the test — never read from a real registry.
const String kPuttyReg =
    'Windows Registry Editor Version 5.00\r\n'
    '\r\n'
    r'[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions]'
    '\r\n'
    '\r\n'
    r'[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\Default%20Settings]'
    '\r\n'
    '"HostName"=""\r\n'
    '"PortNumber"=dword:00000016\r\n'
    '\r\n'
    r'[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\My%20Server]'
    '\r\n'
    '"Present"=dword:00000001\r\n'
    '"HostName"="myserver.example.com"\r\n'
    '"PortNumber"=dword:00000016\r\n'
    '"UserName"="admin"\r\n'
    '"Protocol"="ssh"\r\n'
    r'"PublicKeyFile"="C:\\Users\\me\\keys\\work.ppk"'
    '\r\n'
    r'"WinTitle"="say \"hi\""'
    '\r\n'
    '"ProxyMethod"=dword:00000002\r\n'
    '"ProxyHost"="proxy.corp"\r\n'
    '"ProxyPort"=dword:00000438\r\n'
    '"PortForwardings"="L8080=localhost:80,R2222=127.0.0.1:22,D1080,Xbogus,L127.0.0.1:5433=[::1]:5432"\r\n'
    r'"Colour0"=hex:bb,bb,bb,\'
    '\r\n'
    '  00,00,00\r\n'
    '"TerminalType"="xterm"\r\n'
    '\r\n'
    r'[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\bastion]'
    '\r\n'
    '"HostName"="jump@bastion.example.com"\r\n'
    '"PortNumber"=dword:000008ae\r\n'
    '"Protocol"="ssh"\r\n'
    '"ProxyMethod"=dword:00000000\r\n'
    '"PortForwardings"=""\r\n'
    '\r\n'
    r'[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\router%20telnet]'
    '\r\n'
    '"HostName"="192.168.1.1"\r\n'
    '"PortNumber"=dword:00000017\r\n'
    '"Protocol"="telnet"\r\n'
    '\r\n'
    r'[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\Caf%C3%A9%20box]'
    '\r\n'
    '"HostName"="10.0.0.9"\r\n'
    '\r\n'
    r'[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\empty]'
    '\r\n'
    '"HostName"=""\r\n'
    '"Protocol"="ssh"\r\n'
    '\r\n';

/// [text] as UTF-16LE with a byte-order mark — what `reg export` produces.
Uint8List utf16leWithBom(String text) {
  final bytes = <int>[0xFF, 0xFE];
  for (final unit in text.codeUnits) {
    bytes
      ..add(unit & 0xFF)
      ..add(unit >> 8);
  }
  return Uint8List.fromList(bytes);
}

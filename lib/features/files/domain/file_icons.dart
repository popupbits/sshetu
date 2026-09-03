import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

/// Extension (lowercased, no dot) to icon. A table rather than a chain of
/// `if`/`switch` branches on purpose — adding a type is adding one entry,
/// not tracing where in a decision tree it has to slot in, and the table is
/// also what a test can iterate over to prove every entry actually resolves.
const _extensionIcons = <String, IconData>{
  // Archives
  'zip': PiconsRegular.fileZip,
  'tar': PiconsRegular.fileArchive,
  'gz': PiconsRegular.fileArchive,
  'tgz': PiconsRegular.fileArchive,
  'bz2': PiconsRegular.fileArchive,
  '7z': PiconsRegular.fileArchive,
  'rar': PiconsRegular.fileArchive,
  // Images
  'png': PiconsRegular.fileImage,
  'jpg': PiconsRegular.fileImage,
  'jpeg': PiconsRegular.fileImage,
  'gif': PiconsRegular.fileImage,
  'webp': PiconsRegular.fileImage,
  'bmp': PiconsRegular.fileImage,
  'svg': PiconsRegular.fileImage,
  // Code and scripts
  'sh': PiconsRegular.fileCode,
  'bash': PiconsRegular.fileCode,
  'zsh': PiconsRegular.fileCode,
  'py': PiconsRegular.fileCode,
  'rb': PiconsRegular.fileCode,
  'go': PiconsRegular.fileCode,
  'rs': PiconsRegular.fileCode,
  'c': PiconsRegular.fileCode,
  'h': PiconsRegular.fileCode,
  'java': PiconsRegular.fileCode,
  'kt': PiconsRegular.fileCode,
  'swift': PiconsRegular.fileCode,
  'dart': PiconsRegular.fileCode,
  'js': PiconsRegular.fileJs,
  'ts': PiconsRegular.fileTs,
  'jsx': PiconsRegular.fileJsx,
  'tsx': PiconsRegular.fileTsx,
  'vue': PiconsRegular.fileVue,
  'cpp': PiconsRegular.fileCpp,
  'cc': PiconsRegular.fileCpp,
  'cs': PiconsRegular.fileCSharp,
  'html': PiconsRegular.fileHtml,
  'htm': PiconsRegular.fileHtml,
  'css': PiconsRegular.fileCss,
  'sql': PiconsRegular.fileSql,
  'yaml': PiconsRegular.fileCode,
  'yml': PiconsRegular.fileCode,
  'json': PiconsRegular.fileCode,
  'xml': PiconsRegular.fileCode,
  'toml': PiconsRegular.fileCode,
  'ini': PiconsRegular.fileIni,
  'conf': PiconsRegular.fileIni,
  'csv': PiconsRegular.fileCsv,
  // Text and docs
  'txt': PiconsRegular.fileText,
  'md': PiconsRegular.fileMd,
  'log': PiconsRegular.fileText,
  'pdf': PiconsRegular.filePdf,
  'doc': PiconsRegular.fileDoc,
  'docx': PiconsRegular.fileDoc,
  'ppt': PiconsRegular.filePpt,
  'pptx': PiconsRegular.filePpt,
  'xls': PiconsRegular.fileXls,
  'xlsx': PiconsRegular.fileXls,
  // Audio and video
  'mp3': PiconsRegular.fileAudio,
  'wav': PiconsRegular.fileAudio,
  'flac': PiconsRegular.fileAudio,
  'ogg': PiconsRegular.fileAudio,
  'm4a': PiconsRegular.fileAudio,
  'mp4': PiconsRegular.fileVideo,
  'mkv': PiconsRegular.fileVideo,
  'mov': PiconsRegular.fileVideo,
  'avi': PiconsRegular.fileVideo,
  'webm': PiconsRegular.fileVideo,
};

/// The icon for one row: a folder for a directory, else looked up by
/// extension, else the generic file glyph. Never a guess dressed up as one —
/// an unrecognised extension gets the plain file icon rather than the
/// closest-looking match, because a wrong icon is worse than no icon.
IconData fileIcon({required bool isDirectory, required String name}) {
  if (isDirectory) return PiconsRegular.folder;
  final dot = name.lastIndexOf('.');
  // No extension, or a dotfile like ".bashrc" where the dot is the whole
  // name up to that point — `lastIndexOf` returning 0 there is not "the
  // extension is everything", it is "there is no extension".
  if (dot <= 0 || dot == name.length - 1) return PiconsRegular.file;
  final extension = name.substring(dot + 1).toLowerCase();
  return _extensionIcons[extension] ?? PiconsRegular.file;
}

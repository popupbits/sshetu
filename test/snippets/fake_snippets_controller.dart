import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';

/// Records writes instead of making them.
///
/// Widget tests cannot touch sqflite — real I/O never completes under the
/// fake clock a widget test runs on — so the screens are given this and the
/// repository is tested against a real database on its own.
class FakeSnippetsController implements SnippetsController {
  final saved = <Snippet>[];
  final deleted = <Snippet>[];

  @override
  Future<void> save(Snippet snippet) async => saved.add(snippet);

  @override
  Future<void> delete(Snippet snippet) async => deleted.add(snippet);
}

import 'dart:async';
import 'dart:io';

import 'package:bazel_worker/bazel_worker.dart';

typedef Future<ProcessResult> ProcessRunner(List<String> args);

main(List<String> args) async {
  if (args.isEmpty) throw 'First arg must be the binary to run as a worker';

  args = await _expandArgFiles(args);

  await runWithWorkerSupport(
      (args) => Process.run(args.first, args.skip(1).toList()), args);
}

Future runWithWorkerSupport(ProcessRunner runner, List<String> args) async {
  if (args.contains('--persistent_worker')) {
    await new _Loop(runner, args.toList()..remove('--persistent_worker')).run();
  } else {
    final result = await runner(await _expandArgFiles(args));
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
}

class _Loop extends AsyncWorkerLoop {
  final ProcessRunner _runner;
  final List<String> _startupArgs;

  _Loop(this._runner, this._startupArgs);

  Future<WorkResponse> performRequest(WorkRequest request) async {
    final args = <String>[]
      ..addAll(_startupArgs)
      ..addAll(await _expandArgFiles(request.arguments));
    try {
      final result = await _runner(args);
      return new WorkResponse()
        ..exitCode = result.exitCode
        ..output = (result.stdout + result.stderr);
    } catch (e, s) {
      return new WorkResponse()
        ..exitCode = EXIT_CODE_ERROR
        ..output = "Worker failed (args: $args):\n$e\n$s";
    }
  }
}

Future<List<String>> _expandArgFiles(List<String> args) async {
  return (await Future.wait(args.map((arg) {
    if (arg.startsWith('@@')) {
      return new File(arg.substring('@@'.length)).readAsLines();
    } else {
      return new Future.value(<String>[arg]);
    }
  })))
      .expand((l) => l)
      .toList();
}

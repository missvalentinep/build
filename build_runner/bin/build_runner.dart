// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:io/io.dart';
import 'package:logging/logging.dart';

import 'package:build_runner/src/build_script_generate/build_script_generate.dart';
import 'package:build_runner/src/entrypoint/options.dart';
import 'package:build_runner/src/logging/std_io_logging.dart';

Future<Null> main(List<String> args) async {
  var logListener = Logger.root.onRecord.listen(stdIOLogListener);

  // Use the actual command runner to parse the args and immediately print the
  // usage information if there is no command provided or the help command was
  // explicitly invoked.
  var commandRunner = new BuildCommandRunner([]);
  var parsedArgs = commandRunner.parse(args);
  var commandName = parsedArgs.command?.name;
  if (commandName == null || commandName == 'help') {
    commandRunner.printUsage();
    return;
  }

  await ensureBuildScript();
  var dart = Platform.resolvedExecutable;

  // The actual args we will pass to the generated entrypoint script.
  final innerArgs = [scriptLocation]..addAll(args);

  // For commands that support the `assume-tty` flag, we want to force the right
  // setting unless it was explicitly provided.
  var command = commandRunner.commands[commandName];
  var commandParser = command.argParser;
  if (stdioType(stdin) == StdioType.TERMINAL &&
      commandParser.options.containsKey('assume-tty') &&
      !args.any((a) => a.contains('assume-tty'))) {
    // We want to insert this as the first arg after the command, trailing args
    // might get forwarded elsewhere (such as package:test).
    innerArgs.insert(innerArgs.indexOf(commandName) + 1, '--assume-tty');
  }

  var buildRun = await new ProcessManager().spawn(dart, innerArgs);
  await buildRun.exitCode;
  await ProcessManager.terminateStdIn();
  await logListener.cancel();
}
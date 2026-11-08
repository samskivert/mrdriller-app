import 'package:flutter/foundation.dart';

/// Whether to offer the tools for working on the app (the debug menu, saving recordings): in debug
/// builds and in profile builds, which run on a phone without a debugger attached (as a debug build
/// on iOS can't), so can be tried with a drum pad plugged into the phone's only port. Never in
/// release builds.
const bool debugTools = !kReleaseMode;

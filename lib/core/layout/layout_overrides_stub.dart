import 'package:flutter/services.dart';

import 'layout_catalog.dart';

/// Web: sin disco, sin overrides locales de layouts.
EditableLayoutOverrides? createLocalLayoutOverrides([String? dir]) => null;

/// Web: sin repo en disco.
AssetBundle? repoAssetBundle(String repo) => null;

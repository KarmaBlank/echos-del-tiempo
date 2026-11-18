import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../data/account_repository.dart';
import '../data/account_store.dart';

/// La cuenta (personajes + alijo). En la app la registra el composition
/// root (`registerSharedDependencies`); sin registro (tests que no la
/// pisan) es una cuenta en memoria.
final accountRepositoryProvider = Provider<AccountRepository>((ref) =>
    sl.isRegistered<AccountRepository>()
        ? sl<AccountRepository>()
        : AccountRepository(InMemoryAccountStore()));

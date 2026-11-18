import 'package:material_ui/material_ui.dart';

import 'admin_controller.dart';
import 'balance_page.dart';
import 'changes_page.dart';
import 'monitoring_page.dart';
import 'patch_page.dart';

/// App de admin: balance, cambios, parche y monitoreo
/// (docs/specs/balance_admin.md § 5). Tema Material oscuro (no el retro:
/// es una herramienta).
class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.controller, this.initialTab = 0});
  final AdminController controller;
  final int initialTab;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ecos del Tiempo — Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7C5CFF),
          useMaterial3: true,
          visualDensity: VisualDensity.compact,
        ),
        home: AdminShell(controller: controller, initialTab: initialTab),
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.controller, this.initialTab = 0});
  final AdminController controller;
  final int initialTab;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late int tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final pending = c.pendingChanges.length;
        final pages = [
          BalancePage(c: c),
          ChangesPage(c: c),
          PatchPage(c: c),
          MonitoringPage(c: c),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ecos del Tiempo · Admin de balance'),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'balance ${c.validDraft.hash}'
                    '${pending > 0 ? ' · $pending sin guardar' : ''}'
                    '${c.currentVersion == null ? '' : ' · juego v${c.currentVersion}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  onPressed: c.canSave && pending > 0 ? c.save : null,
                ),
              ),
            ],
          ),
          body: Row(children: [
            NavigationRail(
              selectedIndex: tab,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: [
                const NavigationRailDestination(icon: Icon(Icons.tune), label: Text('Balance')),
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: pending > 0,
                    label: Text('$pending'),
                    child: const Icon(Icons.difference_outlined),
                  ),
                  label: const Text('Cambios'),
                ),
                const NavigationRailDestination(icon: Icon(Icons.new_releases_outlined), label: Text('Parche')),
                const NavigationRailDestination(icon: Icon(Icons.monitor_heart_outlined), label: Text('Monitoreo')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[tab]),
          ]),
        );
      },
    );
  }
}

const shellAdminOnlyMenuPaths = <String>{
  '/app/birthdays',
  '/app/team-builder',
  '/app/settings',
  '/app/conquistas',
  '/app/retrospectiva',
};

int shellNavigationIndexForPath(String location) {
  const mainPaths = <String>[
    '/app',
    '/app/matches',
    '/app/groups',
    '/app/history',
  ];

  if (location == mainPaths.first) return 0;

  for (var index = 1; index < mainPaths.length; index++) {
    final path = mainPaths[index];
    if (location == path || location.startsWith('$path/')) return index;
  }

  return 4;
}

bool isShellMenuItemVisible({
  required String path,
  required bool isAdmin,
  required bool canSeeStats,
  bool requiresStatsPermission = false,
  String? groupId,
  bool canSeeReplays = false,
}) {
  if (shellAdminOnlyMenuPaths.contains(path) && !isAdmin) return false;
  if (path == '/app/replays' && !canSeeReplays) return false;
  if (requiresStatsPermission && !canSeeStats) return false;
  return true;
}

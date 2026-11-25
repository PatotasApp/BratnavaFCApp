const shellAdminOnlyMenuPaths = <String>{
  '/app/birthdays',
  '/app/team-builder',
  '/app/settings',
  '/app/conquistas',
  '/app/retrospectiva',
  '/app/applicants',
};

int shellNavigationIndexForPath(String location) {
  const mainPaths = <String>[
    '/app',
    '/app/matches',
    '/app/search',
    '/app/history',
  ];

  if (location == mainPaths.first) return 0;

  for (var index = 1; index < mainPaths.length; index++) {
    final path = mainPaths[index];
    if (location == path || location.startsWith('$path/')) return index;
  }

  return 4;
}

String? guestOnlyRedirect({
  required String location,
  required bool isGuestOnly,
}) {
  if (!isGuestOnly) return null;

  const allowedPaths = <String>{
    '/app/match-invitations',
    '/app/account',
    '/app/theme',
  };
  if (allowedPaths.contains(location) ||
      location.startsWith('/app/guest-match/')) {
    return null;
  }

  return '/app/match-invitations';
}

bool isShellMenuItemVisible({
  required String path,
  required bool isAdmin,
  required bool canSeeStats,
  bool requiresStatsPermission = false,
  String? groupId,
  bool canSeeReplays = false,
  bool canSeeApplicants = true,
}) {
  if (shellAdminOnlyMenuPaths.contains(path) && !isAdmin) return false;
  if (path == '/app/applicants' && !canSeeApplicants) return false;
  if (path == '/app/replays' && !canSeeReplays) return false;
  if (requiresStatsPermission && !canSeeStats) return false;
  return true;
}

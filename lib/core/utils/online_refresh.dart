Future<bool> refreshWhenOnline({
  required Future<bool> Function() hasInternet,
  required Future<void> Function() refresh,
}) async {
  if (!await hasInternet()) return false;
  await refresh();
  return true;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  group('dashboardTeamOperationalStatus', () {
    test('running work has highest priority', () {
      expect(
        app.dashboardTeamOperationalStatus(
          hasRunningRecord: true,
          waitingForAccess: true,
          schedulePaused: true,
          schedulePostponed: true,
          scheduleStarted: false,
          insideWorkWindow: false,
        ),
        app.DashboardOperationalStatus.running,
      );
    });

    test('waiting for access precedes pause and postponement', () {
      expect(
        app.dashboardTeamOperationalStatus(
          hasRunningRecord: false,
          waitingForAccess: true,
          schedulePaused: true,
          schedulePostponed: true,
          scheduleStarted: true,
          insideWorkWindow: true,
        ),
        app.DashboardOperationalStatus.waitingAccess,
      );
    });

    test('pause precedes postponement', () {
      expect(
        app.dashboardTeamOperationalStatus(
          hasRunningRecord: false,
          waitingForAccess: false,
          schedulePaused: true,
          schedulePostponed: true,
          scheduleStarted: true,
          insideWorkWindow: true,
        ),
        app.DashboardOperationalStatus.paused,
      );
    });

    test('postponement precedes an active work window', () {
      expect(
        app.dashboardTeamOperationalStatus(
          hasRunningRecord: false,
          waitingForAccess: false,
          schedulePaused: false,
          schedulePostponed: true,
          scheduleStarted: true,
          insideWorkWindow: true,
        ),
        app.DashboardOperationalStatus.postponed,
      );
    });

    test('started schedule inside work window is active', () {
      expect(
        app.dashboardTeamOperationalStatus(
          hasRunningRecord: false,
          waitingForAccess: false,
          schedulePaused: false,
          schedulePostponed: false,
          scheduleStarted: true,
          insideWorkWindow: true,
        ),
        app.DashboardOperationalStatus.duringWorkWindow,
      );
    });

    test('started schedule outside work window keeps outside status', () {
      expect(
        app.dashboardTeamOperationalStatus(
          hasRunningRecord: false,
          waitingForAccess: false,
          schedulePaused: false,
          schedulePostponed: false,
          scheduleStarted: true,
          insideWorkWindow: false,
        ),
        app.DashboardOperationalStatus.outsideWorkWindow,
      );
    });

    test('no started schedule is outside the work window', () {
      expect(
        app.dashboardTeamOperationalStatus(
          hasRunningRecord: false,
          waitingForAccess: false,
          schedulePaused: false,
          schedulePostponed: false,
          scheduleStarted: false,
          insideWorkWindow: true,
        ),
        app.DashboardOperationalStatus.outsideWorkWindow,
      );
    });
  });
}

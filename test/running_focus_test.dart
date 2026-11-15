import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runnery_new/home/running/running_start_page.dart';

void main() {
  test('집중 화면: 시속 8km 이상이면 켜지고, 느려진 채 5초가 지나야 꺼져요', () {
    var clock = DateTime(2026, 11, 15, 8);
    final session = RunningSession(weightKg: 65, now: () => clock);
    var north = 0.0;
    Position at() => Position(
      latitude: 37.5 + north / 111000,
      longitude: 127,
      timestamp: clock,
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: -1,
      speedAccuracy: 0,
    );
    // 0.5초마다 [metersPerSecond]로 움직이며 판정합니다.
    void move(double metersPerSecond, Duration duration) {
      for (var t = 0; t < duration.inMilliseconds; t += 500) {
        clock = clock.add(const Duration(milliseconds: 500));
        north += metersPerSecond / 2;
        session.addPosition(at());
        session.checkRunningFast();
      }
    }

    session.startWithoutGps();
    session.addPosition(at());

    // 걷기(시속 5.4km)는 원래 화면 그대로예요.
    move(1.5, const Duration(seconds: 15));
    expect(session.runningFast, isFalse);

    // 시속 10.8km로 10초 넘게 달리면 집중 화면이에요.
    move(3, const Duration(seconds: 12));
    expect(session.runningFast, isTrue);

    // 멈춰도 5초 동안은 그대로(깜빡임 방지)...
    move(0, const Duration(seconds: 7));
    expect(session.runningFast, isTrue);
    // ...느린 채로 5초가 넘으면 원래 화면으로 돌아가요.
    move(0, const Duration(seconds: 6));
    expect(session.runningFast, isFalse);

    // 다시 달리면 집중 화면, 일시정지하면 바로 원래 화면이에요.
    move(3, const Duration(seconds: 12));
    expect(session.runningFast, isTrue);
    session.pause();
    expect(session.runningFast, isFalse);
  });
}

import MapKit
import SwiftUI

/// 달리는 중: 기본 화면에서 오른쪽으로 밀면 조작, 위아래로 넘기면 기본 → 페이스 → 지도.
struct RunningPager: View {
  let scale: CGFloat
  @State private var tab = 1

  var body: some View {
    TabView(selection: $tab) {
      ControlsPage(scale: scale).tag(0)
      TabView {
        BasicPage(scale: scale)
        PacePage(scale: scale)
        MapPage(scale: scale)
      }
      .tabViewStyle(.verticalPage)
      .tag(1)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
  }
}

// MARK: 1 · 기본

/// 거리 · 시간 · 페이스 · 심박을 한 화면에.
struct BasicPage: View {
  @ObservedObject var model = WatchModel.shared
  let scale: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StatusTitle(text: "러닝", scale: scale)
      TimelineView(.periodic(from: .now, by: 1)) { context in
        Text(WatchFormat.clock(model.elapsed(at: context.date)))
          .font(WatchTheme.number(28 * scale))
      }
      NumberWithUnit(
        value: WatchFormat.km(model.meters), unit: "km", size: 64 * scale, unitSize: 14 * scale)
      Rectangle().fill(WatchTheme.divider).frame(height: 1).padding(.vertical, 6 * scale)
      HStack(alignment: .top, spacing: 0) {
        VStack(alignment: .leading, spacing: 2) {
          Label12(text: "페이스", scale: scale)
          NumberWithUnit(
            value: WatchFormat.pace(model.pace), unit: "/km", size: 26 * scale,
            unitSize: 11 * scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Rectangle().fill(WatchTheme.divider).frame(width: 1, height: 40 * scale)
          .padding(.trailing, 10 * scale)
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 3) {
            Image(systemName: "heart.fill")
              .font(.system(size: 10 * scale))
              .foregroundStyle(WatchTheme.label)
            Label12(text: "심박", scale: scale)
          }
          // 심박은 다음 단계에서 워치 센서로 붙여요.
          NumberWithUnit(value: "--", unit: "bpm", size: 26 * scale, unitSize: 11 * scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

// MARK: 3 · 페이스

/// 지금 · 평균 페이스, 속도, 1km 구간.
struct PacePage: View {
  @ObservedObject var model = WatchModel.shared
  let scale: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("페이스").font(WatchTheme.title(14 * scale)).foregroundStyle(WatchTheme.orange)
      Label12(text: "지금 페이스", scale: scale).padding(.top, 4 * scale)
      NumberWithUnit(
        value: WatchFormat.pace(model.pace), unit: "/km", size: 56 * scale, unitSize: 14 * scale)
      Rectangle().fill(WatchTheme.divider).frame(height: 1).padding(.vertical, 5 * scale)
      HStack(alignment: .top, spacing: 0) {
        VStack(alignment: .leading, spacing: 1) {
          Label12(text: "평균 페이스", scale: scale)
          NumberWithUnit(
            value: WatchFormat.pace(model.averagePace), unit: "/km", size: 22 * scale,
            unitSize: 11 * scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .leading, spacing: 1) {
          Label12(text: "속도", scale: scale)
          NumberWithUnit(
            value: String(format: "%.1f", model.speedKmh), unit: "km/h", size: 22 * scale,
            unitSize: 11 * scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      SplitBars(splits: model.splits, scale: scale).padding(.top, 6 * scale)
    }
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// 최근 5개 1km 구간. 빠를수록 높고, 마지막 구간은 주황.
struct SplitBars: View {
  let splits: [Int]
  let scale: CGFloat

  var body: some View {
    let recent = Array(splits.enumerated().suffix(5))
    VStack(alignment: .leading, spacing: 4 * scale) {
      HStack {
        Label12(text: "1 km 구간", scale: scale)
        Spacer()
        if let last = recent.last {
          Text("\(last.offset + 1) km \(WatchFormat.pace(Double(last.element)))")
            .font(WatchTheme.label(12 * scale))
            .foregroundStyle(WatchTheme.orange)
        }
      }
      if recent.isEmpty {
        Text("1km를 달리면 구간이 보여요")
          .font(WatchTheme.label(11 * scale))
          .foregroundStyle(WatchTheme.label)
      } else {
        let fastest = Double(recent.map(\.element).min() ?? 1)
        HStack(alignment: .bottom, spacing: 6 * scale) {
          ForEach(recent, id: \.offset) { item in
            let isLast = item.offset == recent.last?.offset
            VStack(spacing: 2) {
              RoundedRectangle(cornerRadius: 3 * scale)
                .fill(isLast ? WatchTheme.orange : Color(white: 0.3))
                // 가장 빠른 구간이 가장 높아요. 느린 구간도 바닥에 붙지 않게 40%는 남겨요.
                .frame(height: 36 * scale * max(0.4, fastest / Double(max(item.element, 1))))
              Text("\(item.offset + 1)")
                .font(WatchTheme.label(10 * scale))
                .foregroundStyle(WatchTheme.label)
            }
            .frame(maxWidth: .infinity)
          }
        }
      }
    }
  }
}

// MARK: 4 · 지도

/// 지금까지 달린 길과 현재 위치.
struct MapPage: View {
  @ObservedObject var model = WatchModel.shared
  let scale: CGFloat

  var body: some View {
    ZStack {
      Map(position: .constant(camera), interactionModes: []) {
        if model.route.count > 1 {
          MapPolyline(coordinates: model.route)
            .stroke(WatchTheme.orange, style: .init(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        if let here = model.route.last {
          Annotation("", coordinate: here) {
            Circle()
              .fill(WatchTheme.orange)
              .frame(width: 14, height: 14)
              .overlay(Circle().stroke(.white, lineWidth: 3))
          }
        }
      }
      .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
      .environment(\.colorScheme, .dark)
      .ignoresSafeArea()

      VStack {
        HStack {
          Text("지도").font(WatchTheme.title(14 * scale)).foregroundStyle(WatchTheme.orange)
          Spacer()
        }
        Spacer()
        HStack(spacing: 8 * scale) {
          NumberWithUnit(
            value: WatchFormat.km(model.meters), unit: "km", size: 18 * scale, unitSize: 11 * scale)
          Rectangle().fill(WatchTheme.divider).frame(width: 1, height: 14 * scale)
          NumberWithUnit(
            value: WatchFormat.pace(model.pace), unit: "/km", size: 18 * scale,
            unitSize: 11 * scale)
        }
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 6 * scale)
        .background(Capsule().fill(Color.black.opacity(0.8)))
      }
      .padding(.horizontal, 4)
    }
  }

  /// 현재 위치를 가운데에 두고 약 400m 범위를 보여 줘요.
  private var camera: MapCameraPosition {
    guard let here = model.route.last else { return .automatic }
    return .camera(MapCamera(centerCoordinate: here, distance: 800))
  }
}

// MARK: 조작

/// 종료 · 일시정지 · 화면 잠금 · 음성 안내.
struct ControlsPage: View {
  @ObservedObject var model = WatchModel.shared
  let scale: CGFloat
  @State private var confirmEnd = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8 * scale) {
      Text("조작").font(WatchTheme.title(14 * scale))
      Grid(horizontalSpacing: 14 * scale, verticalSpacing: 8 * scale) {
        GridRow {
          ControlButton(
            icon: "stop.fill", title: "종료", fill: WatchTheme.button, iconColor: .white,
            scale: scale
          ) { confirmEnd = true }
          ControlButton(
            icon: "pause.fill", title: "일시정지", fill: .white, iconColor: .black, scale: scale
          ) { model.send("pause") }
        }
        GridRow {
          ControlButton(
            icon: "lock.fill", title: "화면 잠금", fill: WatchTheme.button, iconColor: .white,
            scale: scale
          ) {
            // 화면을 물에 닿아도 눌리지 않게 잠가요. 크라운을 돌리면 풀려요.
            WorkoutManager.shared.lockScreen()
          }
          ControlButton(
            icon: model.voice ? "speaker.wave.2.fill" : "speaker.slash.fill",
            title: model.voice ? "음성 안내" : "음성 꺼짐", fill: WatchTheme.button,
            iconColor: .white, scale: scale
          ) { model.send("voice") }
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .confirmationDialog("러닝을 끝낼까요?", isPresented: $confirmEnd) {
      Button("끝내기", role: .destructive) { model.send("end") }
      Button("계속 달리기", role: .cancel) {}
    } message: {
      Text("저장은 폰에서 해요")
    }
  }
}

// MARK: 일시정지

/// 일시정지 중: 시간 · 거리와 종료 · 다시 시작.
struct PausedView: View {
  @ObservedObject var model = WatchModel.shared
  let scale: CGFloat
  @State private var confirmEnd = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Image(systemName: "pause.fill").font(.system(size: 10 * scale))
        Text(model.autoPaused ? "자동 일시정지" : "일시정지").font(WatchTheme.title(14 * scale))
      }
      .foregroundStyle(WatchTheme.label)
      Text(WatchFormat.clock(model.elapsed(at: Date())))
        .font(WatchTheme.number(48 * scale))
        .padding(.top, 4 * scale)
      NumberWithUnit(
        value: WatchFormat.km(model.meters), unit: "km", size: 20 * scale, unitSize: 11 * scale)
      Spacer(minLength: 4)
      if model.ending {
        Text("폰에서 저장을 마쳐 주세요")
          .font(WatchTheme.label(13 * scale))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 8 * scale)
      } else {
        HStack {
          ControlButton(
            icon: "stop.fill", title: "종료", fill: WatchTheme.button, iconColor: .white,
            scale: scale
          ) { confirmEnd = true }
          Spacer()
          ControlButton(
            icon: "play.fill", title: "다시 시작", fill: WatchTheme.orange, iconColor: .black,
            scale: scale
          ) { model.send("resume") }
        }
        .padding(.horizontal, 10 * scale)
      }
    }
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .confirmationDialog("러닝을 끝낼까요?", isPresented: $confirmEnd) {
      Button("끝내기", role: .destructive) { model.send("end") }
      Button("취소", role: .cancel) {}
    } message: {
      Text("저장은 폰에서 해요")
    }
  }
}

// MARK: 공통

/// 주황 점 + 상태 제목(예: ● 러닝).
struct StatusTitle: View {
  let text: String
  let scale: CGFloat

  var body: some View {
    HStack(spacing: 5 * scale) {
      Circle().fill(WatchTheme.orange).frame(width: 7 * scale, height: 7 * scale)
      Text(text).font(WatchTheme.title(14 * scale)).foregroundStyle(WatchTheme.orange)
    }
  }
}

/// 회색 라벨(Pretendard SemiBold 12).
struct Label12: View {
  let text: String
  let scale: CGFloat

  var body: some View {
    Text(text).font(WatchTheme.label(12 * scale)).foregroundStyle(WatchTheme.label)
  }
}

/// 큰 숫자 + 회색 단위(예: 5.24 km).
struct NumberWithUnit: View {
  let value: String
  let unit: String
  let size: CGFloat
  let unitSize: CGFloat

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      Text(value).font(WatchTheme.number(size)).foregroundStyle(.white)
      Text(unit).font(WatchTheme.label(unitSize)).foregroundStyle(WatchTheme.label)
    }
    .lineLimit(1)
    .minimumScaleFactor(0.6)
  }
}

/// 둥근 조작 버튼 + 아래 이름.
struct ControlButton: View {
  let icon: String
  let title: String
  let fill: Color
  let iconColor: Color
  let scale: CGFloat
  let action: () -> Void

  var body: some View {
    VStack(spacing: 4 * scale) {
      Button(action: action) {
        Image(systemName: icon)
          .font(.system(size: 20 * scale, weight: .semibold))
          .foregroundStyle(iconColor)
          .frame(width: 52 * scale, height: 52 * scale)
          .background(Circle().fill(fill))
      }
      .buttonStyle(.plain)
      Text(title).font(WatchTheme.label(11 * scale)).foregroundStyle(WatchTheme.label)
    }
  }
}

---
layout: base.njk
title: 빌어먹게 쉬운 Swift 동시성
description: Swift 동시성에 대한 솔직한 가이드. 간단한 멘탈 모델로 async/await, actors, Sendable, MainActor를 배우세요. 전문 용어 없이, 명확한 설명만.
lang: ko
dir: ltr
nav:
  isolation: 격리
  domains: 도메인
  patterns: 패턴
  errors: 에러
footer:
  madeWith: 좌절과 사랑으로 만들었습니다. Swift 동시성이 혼란스러울 필요는 없으니까요.
  viewOnGitHub: GitHub에서 보기
---

<section class="hero">
  <div class="container">
    <h1>빌어먹게 쉬운<br><span class="accent">Swift 동시성</span></h1>
    <p class="subtitle">async/await, actors, Sendable을 드디어 이해하세요. 명확한 멘탈 모델, 전문 용어 없이.</p>
    <p class="credit"><a href="https://www.massicotte.org/">Matt Massicotte</a>에게 큰 감사를 드립니다. Swift 동시성을 이해할 수 있게 만들어주셨습니다. <a href="https://pepicrft.me">Pedro Piñera</a>가 정리했습니다. 오류를 발견하셨나요? <a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute"><a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a>과 <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a>의 전통을 따릅니다</p>
    <p class="cta-tuist"><a href="https://tuist.dev">Tuist</a>로 개발을 확장하세요</p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## 솔직한 진실

Swift 동시성을 위한 치트 시트는 없습니다. 모든 "그냥 X를 하세요" 같은 답변은 어떤 상황에서는 틀립니다.

**하지만 좋은 소식이 있습니다:** 일단 [격리](#basics) (5분 읽기)를 이해하면, 모든 것이 이해됩니다. 컴파일러 에러가 이해가 되기 시작합니다. 시스템과 싸우는 것을 멈추고 함께 작업하기 시작합니다.

*이 가이드는 Swift 6+를 대상으로 합니다. 대부분의 개념은 Swift 5.5+에도 적용되지만, Swift 6는 더 엄격한 동시성 검사를 강제합니다.*

<a href="#basics" class="read-more">멘탈 모델부터 시작하기 &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## 이해해야 할 단 하나의 것

**[격리(Isolation)](https://www.massicotte.org/intro-to-isolation/)**가 모든 것의 핵심입니다. 이것은 Swift가 다음 질문에 대한 답입니다: *지금 이 데이터를 누가 만질 수 있나?*

<div class="analogy">
<h4>사무실 빌딩</h4>

여러분의 앱을 **사무실 빌딩**으로 생각해보세요. 각 사무실은 **격리 도메인** - 한 번에 한 사람만 작업할 수 있는 프라이빗 공간입니다. 다른 사람의 사무실에 그냥 난입해서 책상을 재배치할 수는 없습니다.

이 비유를 가이드 전반에 걸쳐 계속 사용하겠습니다.
</div>

### 왜 스레드만으로는 안 되나요?

수십 년 동안 우리는 스레드를 생각하면서 동시성 코드를 작성했습니다. 문제는? **스레드는 여러분이 자기 발등을 찍는 것을 막아주지 않습니다.** 두 개의 스레드가 동시에 같은 데이터에 접근할 수 있어서, 데이터 레이스(data race)를 일으킵니다 - 무작위로 크래시되고 재현이 거의 불가능한 버그입니다.

휴대폰에서는 괜찮을 수도 있습니다. 하지만 수천 개의 동시 요청을 처리하는 서버에서는 데이터 레이스가 확실하게 발생합니다 - 보통 프로덕션에서, 금요일에요. Swift가 서버나 다른 고도로 동시적인 환경으로 확장되면서, "최선을 바라는 것"은 통하지 않습니다.

예전 방식은 방어적이었습니다: 락을 사용하고, 디스패치 큐를 사용하고, 빠뜨린 곳이 없기를 바라는 것이었습니다.

Swift의 접근 방식은 다릅니다: **컴파일 타임에 데이터 레이스를 불가능하게 만듭니다.** "이것이 어느 스레드에 있나?"를 묻는 대신, Swift는 "지금 누가 이 데이터를 만질 수 있나?"를 묻습니다. 그것이 격리입니다.

### 다른 언어들은 어떻게 처리하나요?

| 언어 | 접근 방식 | 버그를 언제 발견하나요 |
|----------|----------|------------------------------|
| **Swift** | 격리 + Sendable | 컴파일 타임 |
| **Rust** | 소유권 + 빌림 검사기 | 컴파일 타임 |
| **Kotlin** | 코루틴 + 구조적 동시성 | 부분적으로 컴파일 타임 |
| **Go** | 채널 + 레이스 탐지기 | 런타임 (도구 사용 시) |
| **Java** | `synchronized`, 락 | 런타임 (크래시) |
| **JavaScript** | 단일 스레드 이벤트 루프 | 완전히 회피 |
| **C/C++** | 수동 락 | 런타임 (정의되지 않은 동작) |

Swift와 Rust는 데이터 레이스에 대해 가장 강력한 컴파일 타임 보장을 제공합니다. Kotlin 코루틴은 Swift의 async/await와 유사한 구조적 동시성을 제공하지만, 스레드 안전성에 대한 타입 시스템 수준의 강제력은 동일하지 않습니다. 트레이드오프는? 처음에는 학습 곡선이 가파릅니다. 하지만 모델을 이해하고 나면, 컴파일러가 여러분을 지원합니다.

`Sendable`과 액터 격리에 대한 성가신 에러들? 그것들은 이전에는 조용한 크래시였을 버그들을 잡아내고 있습니다.

  </div>
</section>

<section id="domains">
  <div class="container">

## 격리 도메인

이제 격리(프라이빗 사무실)를 이해했으니, Swift 빌딩의 다양한 유형의 사무실을 살펴보겠습니다.

<div class="analogy">
<h4>사무실 빌딩</h4>

- **안내 데스크** (`MainActor`) - 모든 고객 상호작용이 일어나는 곳입니다. 하나뿐이고, 사용자가 보는 모든 것을 처리합니다.
- **부서 사무실** (`actor`) - 회계, 법무, 인사. 각 부서는 자체 민감 데이터를 보호하는 자체 사무실이 있습니다.
- **복도와 공용 공간** (`nonisolated`) - 누구나 걸어 다닐 수 있는 공유 공간입니다. 여기에는 프라이빗 데이터가 없습니다.
</div>

### MainActor: 안내 데스크

`MainActor`는 메인 스레드에서 실행되는 특별한 격리 도메인입니다. 모든 UI 작업이 여기서 일어납니다.

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // UI 상태가 여기 있습니다

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // 안전합니다 - MainActor에 있습니다
    }
}
```

<div class="tip">
<h4>확실하지 않으면 MainActor를 사용하세요</h4>

대부분의 앱에서, ViewModel과 UI 관련 클래스를 `@MainActor`로 마킹하는 것이 올바른 선택입니다. 성능 문제는 보통 과장되어 있습니다 - 여기서 시작하고, 실제 문제를 측정한 경우에만 최적화하세요.
</div>

### Actors: 부서 사무실

`actor`는 부서 사무실과 같습니다 - 자체 데이터를 보호하고 한 번에 한 방문자만 허용합니다.

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // 안전합니다! 한 번에 한 호출자만
    }
}
```

액터가 없으면, 두 스레드가 balance = 100을 읽고, 둘 다 50을 더하고, 둘 다 150을 씁니다 - $50를 잃었습니다. 액터를 사용하면, Swift가 자동으로 접근을 큐에 넣고 두 입금이 모두 올바르게 완료됩니다.

<div class="warning">
<h4>액터를 과용하지 마세요</h4>

커스텀 액터가 필요한 경우는 **네 가지 조건**이 **모두** 참인 경우뿐입니다:
1. Sendable이 아닌 (스레드 안전하지 않은) 변경 가능한 상태가 있습니다
2. 여러 곳에서 접근해야 합니다
3. 그 상태에 대한 작업이 원자적이어야 합니다
4. MainActor에 있을 수 없습니다

조건 중 하나라도 거짓이면, 아마 액터가 필요하지 않습니다. 대부분의 UI 상태는 `@MainActor`에 있을 수 있습니다. [액터를 사용할 때에 대해 더 읽어보기](https://www.massicotte.org/actors/).
</div>

### Nonisolated: 복도

`nonisolated`로 마킹된 코드는 복도와 같습니다 - 어떤 사무실에도 속하지 않고 어디서나 접근할 수 있습니다.

```swift
actor UserSession {
    let userId: String          // 불변 - 어디서나 읽기 안전
    var lastActivity: Date      // 가변 - 액터 보호 필요

    nonisolated var displayId: String {
        "User: \(userId)"       // 불변 데이터만 읽습니다
    }
}

// 사용법 - nonisolated에는 await가 필요 없습니다
let session = UserSession(userId: "123")
print(session.displayId)  // 동기적으로 작동합니다!
```

불변 데이터만 읽는 계산 속성에 `nonisolated`를 사용하세요.

  </div>
</section>

<section id="propagation">
  <div class="container">

## 격리가 전파되는 방법

타입을 액터 격리로 마킹하면, 그 메서드에는 무슨 일이 일어날까요? 클로저는요? 격리가 어떻게 퍼지는지 이해하는 것이 놀라움을 피하는 열쇠입니다.

<div class="analogy">
<h4>사무실 빌딩</h4>

부서에 고용되면, 기본적으로 그 부서의 사무실에서 일합니다. 마케팅 부서에 고용되면, 회계 부서에 무작위로 나타나지 않습니다.

마찬가지로, `@MainActor` 클래스 안에 정의된 함수는 그 격리를 상속합니다. 부모와 "같은 사무실에서 일"합니다.
</div>

### 클래스는 격리를 상속합니다

```swift
@MainActor
class ViewModel {
    var count = 0           // MainActor 격리

    func increment() {      // 역시 MainActor 격리
        count += 1
    }
}
```

클래스 안의 모든 것이 `@MainActor`를 상속합니다. 각 메서드를 마킹할 필요가 없습니다.

### Task는 컨텍스트를 상속합니다 (보통)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // 이것은 MainActor를 상속합니다!
            self.updateUI()  // 안전합니다, await가 필요 없습니다
        }
    }
}
```

`@MainActor` 컨텍스트에서 생성된 `Task { }`는 `MainActor`에 머뭅니다. 이것이 보통 원하는 것입니다.

### Task.detached는 상속을 끊습니다

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // 더 이상 MainActor에 있지 않습니다!
            await self.updateUI()  // 이제 await가 필요합니다
        }
    }
}
```

<div class="analogy">
<h4>사무실 빌딩</h4>

`Task.detached`는 외부 계약자를 고용하는 것과 같습니다. 그들은 여러분의 사무실 출입증이 없습니다 - 자신의 공간에서 일하며 여러분의 것에 접근하려면 적절한 채널을 거쳐야 합니다.
</div>

<div class="warning">
<h4>Task.detached는 보통 틀렸습니다</h4>

대부분의 경우, 일반 `Task`를 원합니다. 분리된 태스크는 우선순위, task-local 값, 또는 액터 컨텍스트를 상속하지 않습니다. 명시적으로 그 분리가 필요한 경우에만 사용하세요.
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## 경계를 넘을 수 있는 것

이제 격리 도메인(사무실)과 그것들이 어떻게 전파되는지 알았으니, 다음 질문은: **무엇을 그것들 사이에서 전달할 수 있나요?**

<div class="analogy">
<h4>사무실 빌딩</h4>

모든 것이 사무실을 떠날 수 있는 것은 아닙니다:

- **사본**은 공유하기 안전합니다 - 법무팀이 문서 사본을 만들어 회계에 보내면, 둘 다 자신의 사본을 가집니다. 충돌이 없습니다.
- **원본 서명된 계약서**는 그 자리에 있어야 합니다 - 두 부서가 모두 원본을 수정할 수 있다면, 혼란이 발생합니다.

Swift 용어로: **Sendable** 타입은 사본입니다 (공유하기 안전), **non-Sendable** 타입은 원본입니다 (한 사무실에 머물러야 합니다).
</div>

### Sendable: 공유하기 안전

이러한 타입들은 격리 경계를 안전하게 넘을 수 있습니다:

```swift
// 불변 데이터를 가진 구조체 - 사본처럼
struct User: Sendable {
    let id: Int
    let name: String
}

// 액터는 스스로를 보호합니다 - 자체 방문자를 처리합니다
actor BankAccount { }  // 자동으로 Sendable
```

**자동으로 Sendable:**
- Sendable 속성을 가진 값 타입 (struct, enum)
- 액터 (스스로를 보호합니다)
- 불변 클래스 (`let` 속성만 있는 `final class`)

### Non-Sendable: 그 자리에 머물러야 함

이러한 타입들은 안전하게 경계를 넘을 수 없습니다:

```swift
// 가변 상태를 가진 클래스 - 원본 문서처럼
class Counter {
    var count = 0  // 두 사무실이 이것을 수정하면 = 재앙
}
```

**이것이 핵심 구분인 이유는?** 여러분이 마주칠 모든 컴파일러 에러는 다음으로 귀결되기 때문입니다: *"Sendable이 아닌 타입을 격리 경계를 넘어 보내려고 합니다."*

### 컴파일러가 불평할 때

Swift가 무언가가 Sendable이 아니라고 말하면, 선택지가 있습니다:

1. **값 타입으로 만들기** - `class` 대신 `struct` 사용
2. **격리하기** - `@MainActor`에 두어서 넘을 필요가 없게 하기
3. **non-Sendable로 유지** - 사무실 간에 전달하지 않기
4. **최후의 수단:** `@unchecked Sendable` - 안전하다고 약속하기 (조심하세요)

<div class="tip">
<h4>non-Sendable로 시작하세요</h4>

[Matt Massicotte는 주장합니다](https://www.massicotte.org/non-sendable/) 일반적인, non-Sendable 타입으로 시작하라고. 경계를 넘어야 할 때만 `Sendable`을 추가하세요. non-Sendable 타입은 단순하게 유지되고 준수성 골칫거리를 피합니다.
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## 경계를 넘는 방법

격리 도메인을 이해했고, 무엇이 그것들을 넘을 수 있는지 알았습니다. 이제: **실제로 사무실 간에 어떻게 소통하나요?**

<div class="analogy">
<h4>사무실 빌딩</h4>

다른 사무실에 그냥 난입할 수 없습니다. 요청을 보내고 응답을 기다립니다. 기다리는 동안 다른 일을 할 수도 있지만, 계속하려면 그 응답이 필요합니다.

그것이 `async/await`입니다 - 다른 격리 도메인에 요청을 보내고 답을 얻을 때까지 일시 중지하는 것입니다.
</div>

### await 키워드

다른 액터의 함수를 호출할 때, `await`가 필요합니다:

```swift
actor DataStore {
    var items: [Item] = []

    func add(_ item: Item) {
        items.append(item)
    }
}

@MainActor
class ViewModel {
    let store = DataStore()

    func addItem(_ item: Item) async {
        await store.add(item)  // 다른 사무실로 요청
        updateUI()             // 우리 사무실로 돌아옴
    }
}
```

`await`는 의미합니다: "이 요청을 보내고 완료될 때까지 일시 중지합니다. 기다리는 동안 다른 작업을 할 수도 있습니다."

### 정지, 차단이 아님

<div class="warning">
<h4>흔한 오해</h4>

많은 개발자들이 `async`를 추가하면 코드가 백그라운드에서 실행된다고 가정합니다. 그렇지 않습니다. `async` 키워드는 그저 함수가 *일시 중지될 수 있다*는 것을 의미합니다. *어디서* 실행되는지에 대해서는 아무 말도 하지 않습니다.
</div>

핵심 통찰은 **차단(blocking)**과 **정지(suspension)**의 차이입니다:

- **차단**: 대기실에 앉아서 벽을 바라봅니다. 다른 일은 일어나지 않습니다.
- **정지**: 전화번호를 남기고 심부름을 합니다. 준비되면 전화할 것입니다.

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">차단</button>
<button>정지</button>
</div>
<div class="code-tab-content active">

```swift
// 스레드가 유휴 상태로, 5초 동안 아무것도 하지 않습니다
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// 스레드가 해제되어 기다리는 동안 다른 작업을 합니다
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### 동기 코드에서 비동기 작업 시작하기

때때로 동기 코드에 있는데 비동기를 호출해야 합니다. `Task`를 사용하세요:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // 동기 함수
        Task {
            await loadData()  // 이제 await를 사용할 수 있습니다
        }
    }
}
```

<div class="analogy">
<h4>사무실 빌딩</h4>

`Task`는 직원에게 작업을 할당하는 것과 같습니다. 직원이 요청을 처리하고 (다른 사무실을 기다리는 것 포함) 여러분은 즉각적인 작업을 계속합니다.
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## 작동하는 패턴

### 네트워크 요청 패턴

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (네트워크 호출)</span>
</div>
<div class="code-isolation">
<div class="isolation-sidebar">
  <div class="segment main" style="flex-grow: 8"></div>
  <div class="segment nonisolated" style="flex-grow: 2"></div>
  <div class="segment main" style="flex-grow: 6"></div>
</div>
<div class="isolation-overlay">
  <div class="segment" style="flex-grow: 8"></div>
  <div class="segment nonisolated-highlight" style="flex-grow: 2"></div>
  <div class="segment" style="flex-grow: 6"></div>
</div>

```swift
@MainActor
@Observable
class ViewModel {
    var users: [User] = []
    var isLoading = false

    func fetchUsers() async {
        isLoading = true

        // 이것은 정지됩니다 - 스레드가 다른 작업을 자유롭게 할 수 있습니다
        let users = await networkService.getUsers()

        // 자동으로 MainActor로 돌아옵니다
        self.users = users
        isLoading = false
    }
}
```

</div>

`DispatchQueue.main.async`가 없습니다. `@MainActor` 속성이 처리합니다.

### async let으로 병렬 작업

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // 세 가지 모두 병렬로 실행됩니다!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### 더블탭 방지

이 패턴은 [상태가 있는 시스템](https://www.massicotte.org/step-by-step-stateful-systems)에 대한 Matt Massicotte의 가이드에서 나온 것입니다:

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // 모든 비동기 작업 전에 동기적으로 가드합니다
        guard !isLoading else { return }
        isLoading = true

        Task {
            await doExpensiveWork()
            isLoading = false
        }
    }
}
```

<div class="warning">
<h4>중요: guard는 동기여야 합니다</h4>

guard를 await 이후 Task 안에 넣으면, 두 버튼 탭이 모두 작업을 시작할 수 있는 창이 있습니다. [순서와 동시성에 대해 더 알아보기](https://www.massicotte.org/ordering-and-concurrency).
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## 피해야 할 흔한 실수

이것들은 경험 많은 개발자들도 하는 [흔한 실수들](https://www.massicotte.org/mistakes-with-concurrency/)입니다:

### async = 백그라운드라고 생각하기

<div class="analogy">
<h4>사무실 빌딩</h4>

`async`를 추가한다고 다른 사무실로 옮기는 것이 아닙니다. 여전히 안내 데스크에 있습니다 - 이제 제자리에서 얼지 않고 배송을 기다릴 수 있을 뿐입니다.
</div>

```swift
// 이것은 여전히 메인 스레드를 차단합니다!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // 동기 = 차단
    data = result
}
```

다른 사무실에서 작업이 완료되어야 한다면, 명시적으로 거기로 보내세요:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // 이제 다른 사무실에서
    }.value
    await MainActor.run { data = result }
}
```

### 너무 많은 액터 만들기

<div class="analogy">
<h4>사무실 빌딩</h4>

모든 데이터 조각마다 새 사무실을 만들면 그것들 사이에 소통하기 위해 끝없는 서류 작업이 발생합니다. 대부분의 작업은 안내 데스크에서 일어날 수 있습니다.
</div>

```swift
// 과도하게 엔지니어링됨 - 모든 호출이 사무실 간 이동을 요구합니다
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// 더 나음 - 대부분은 안내 데스크에 있을 수 있습니다
@MainActor
class AppState { }
```

### 어디서나 MainActor.run 사용하기

<div class="analogy">
<h4>사무실 빌딩</h4>

매번 작은 일마다 안내 데스크로 걸어간다면, 거기서 일하세요. 계속된 심부름이 아니라 직무 설명의 일부로 만드세요.
</div>

```swift
// 이렇게 하지 마세요 - 계속 안내 데스크로 걸어감
await MainActor.run { doMainActorStuff() }

// 이렇게 하세요 - 안내 데스크에서 일하세요
@MainActor func doMainActorStuff() { }
```

### 모든 것을 Sendable로 만들기

모든 것이 `Sendable`일 필요는 없습니다. 어디서나 `@unchecked Sendable`을 추가하고 있다면, 사무실을 떠날 필요가 없는 것들의 사본을 만들고 있는 것입니다.

### 컴파일러 경고 무시하기

`Sendable`에 대한 모든 컴파일러 경고는 보안 요원이 무언가가 사무실 간에 운반하기에 안전하지 않다고 말하는 것입니다. 무시하지 마세요 - [이해하세요](https://www.massicotte.org/complete-checking/).

  </div>
</section>

<section id="errors">
  <div class="container">

## 흔한 컴파일러 에러

이것들은 여러분이 볼 실제 에러 메시지입니다. 각각은 컴파일러가 데이터 레이스로부터 여러분을 보호하고 있는 것입니다.

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>사무실 빌딩</h4>

원본 문서를 다른 사무실로 가져가려고 합니다. 사본(Sendable)을 만들거나 한 곳에 두세요.
</div>

**수정 1:** `class` 대신 `struct` 사용

**수정 2:** 하나의 액터에 두기:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // 안내 데스크에 머뭅니다
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>사무실 빌딩</h4>

원본을 사무실 간에 옮기려고 합니다. 보안 요원이 막았습니다.
</div>

**수정 1:** struct로 만들기:

```swift
// 이전: class (non-Sendable)
class User { var name: String }

// 이후: struct (Sendable)
struct User: Sendable { let name: String }
```

**수정 2:** 하나의 액터에 격리하기:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>사무실 빌딩</h4>

적절한 채널을 거치지 않고 다른 사무실의 서류함에 손을 뻗고 있습니다.
</div>

**수정:** `await` 사용:

```swift
// 틀림 - 직접 손을 뻗음
let value = myActor.balance

// 맞음 - 적절한 요청
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>사무실 빌딩</h4>

줄을 서지 않고 안내 데스크를 사용하려고 합니다.
</div>

**수정 1:** 호출자를 `@MainActor`로 만들기:

```swift
@MainActor
func doSomething() {
    updateUI()  // 같은 격리, await 필요 없음
}
```

**수정 2:** `await` 사용:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## Swift 동시성의 세 단계

모든 것을 한 번에 배울 필요는 없습니다. 이 단계들을 진행하세요:

<div class="analogy">
<h4>사무실 빌딩</h4>

회사를 키우는 것처럼 생각하세요. 50층 본사로 시작하지 않습니다 - 책상으로 시작합니다.
</div>

이 단계들은 엄격한 경계가 아닙니다 - 앱의 다른 부분들은 다른 단계가 필요할 수 있습니다. 대부분 레벨 1인 앱이 레벨 2 패턴이 필요한 하나의 기능을 가질 수 있습니다. 괜찮습니다. 각 부분에 적합한 가장 간단한 접근 방식을 사용하세요.

### 레벨 1: 스타트업

모두가 안내 데스크에서 일합니다. 간단하고, 직접적이고, 관료주의가 없습니다.

- 네트워크 호출에 `async/await` 사용
- UI 클래스를 `@MainActor`로 마킹
- SwiftUI의 `.task` 모디파이어 사용

이것이 앱의 80%를 처리합니다. [Things](https://culturedcode.com/things/), [Bear](https://bear.app/), [Flighty](https://flighty.com/), 또는 [Day One](https://dayoneapp.com/)과 같은 앱들이 이 범주에 속할 것입니다 - 주로 데이터를 가져와서 표시하는 앱들입니다.

### 레벨 2: 성장하는 회사

한 번에 여러 가지를 처리해야 합니다. 병렬 프로젝트와 팀 조정의 시간입니다.

- 병렬 작업에 `async let` 사용
- 동적 병렬성에 `TaskGroup` 사용
- 태스크 취소 이해하기

[Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp) (여러 타임라인과 스트리밍 업데이트를 관리하는 마스토돈 클라이언트), [Overcast](https://overcast.fm/) (다운로드, 재생, 백그라운드 동기화 조정), 또는 [Slack](https://slack.com/) (여러 채널에 걸친 실시간 메시징)과 같은 앱들이 특정 기능에 이러한 패턴을 사용할 수 있습니다.

### 레벨 3: 기업

자체 정책을 가진 전용 부서들. 복잡한 사무실 간 소통.

- 공유 상태를 위한 커스텀 액터 생성
- Sendable에 대한 깊은 이해
- 커스텀 익스큐터

[Xcode](https://developer.apple.com/xcode/), [Final Cut Pro](https://www.apple.com/final-cut-pro/), 또는 [Vapor](https://vapor.codes/)와 [Hummingbird](https://hummingbird.codes/)같은 서버 사이드 Swift 프레임워크가 이러한 패턴을 필요로 할 것입니다 - 복잡한 공유 상태, 수천 개의 동시 연결, 또는 다른 사람들이 위에 구축하는 프레임워크 수준 코드입니다.

<div class="tip">
<h4>간단하게 시작하세요</h4>

대부분의 앱은 레벨 3가 필요하지 않습니다. 스타트업으로 충분할 때 기업을 만들지 마세요.
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## 용어집: 만나게 될 더 많은 키워드

핵심 개념을 넘어서, 실제로 볼 다른 Swift 동시성 키워드들이 있습니다:

| 키워드 | 의미 |
|---------|---------------|
| `nonisolated` | 액터의 격리를 옵트아웃 - 보호 없이 실행됩니다 |
| `isolated` | 매개변수가 액터의 컨텍스트에서 실행된다고 명시적으로 선언합니다 |
| `@Sendable` | 클로저를 격리 경계를 넘어 전달하기에 안전하다고 마킹합니다 |
| `Task.detached` | 현재 컨텍스트와 완전히 분리된 태스크를 생성합니다 |
| `AsyncSequence` | `for await`로 반복할 수 있는 시퀀스입니다 |
| `AsyncStream` | 콜백 기반 코드를 비동기 시퀀스로 연결하는 방법입니다 |
| `withCheckedContinuation` | 완료 핸들러를 async/await로 연결합니다 |
| `Task.isCancelled` | 현재 태스크가 취소되었는지 확인합니다 |
| `@preconcurrency` | 레거시 코드에 대한 동시성 경고를 억제합니다 |
| `GlobalActor` | MainActor처럼 자신만의 커스텀 액터를 생성하기 위한 프로토콜입니다 |

### 각각을 사용할 때

#### nonisolated - 계산 속성 읽기

<div class="analogy">
사무실 문에 있는 명패처럼 - 지나가는 사람이 누구나 안으로 들어와서 여러분을 기다릴 필요 없이 읽을 수 있습니다.
</div>

기본적으로, 액터 안의 모든 것은 격리되어 있습니다 - 접근하려면 `await`가 필요합니다. 하지만 때때로 본질적으로 읽기 안전한 속성이 있습니다: 불변 `let` 상수, 또는 다른 안전한 데이터에서만 값을 도출하는 계산 속성. 이것들을 `nonisolated`로 마킹하면 호출자가 동기적으로 접근할 수 있어, 불필요한 비동기 오버헤드를 피합니다.

<div class="isolation-legend">
  <span class="isolation-legend-item actor">액터 격리됨</span>
  <span class="isolation-legend-item nonisolated">Nonisolated</span>
</div>
<div class="code-isolation">
<div class="isolation-sidebar">
  <div class="segment actor" style="flex-grow: 4"></div>
  <div class="segment nonisolated" style="flex-grow: 4"></div>
  <div class="segment actor" style="flex-grow: 1"></div>
</div>
<div class="isolation-overlay">
  <div class="segment" style="flex-grow: 4"></div>
  <div class="segment nonisolated-highlight" style="flex-grow: 4"></div>
  <div class="segment" style="flex-grow: 1"></div>
</div>

```swift
actor UserSession {
    let userId: String  // 불변, 읽기 안전
    var lastActivity: Date  // 가변, 보호 필요

    // 이것은 await 없이 호출될 수 있습니다
    nonisolated var displayId: String {
        "User: \(userId)"  // 불변 데이터만 읽습니다
    }
}
```

</div>

```swift
// 사용법
let session = UserSession(userId: "123")
print(session.displayId)  // await 필요 없습니다!
```

#### @Sendable - 경계를 넘는 클로저

<div class="analogy">
안에 지시사항이 있는 봉인된 봉투처럼 - 봉투는 사무실 간을 이동할 수 있고, 누구든 열어서 안전하게 지시사항을 따를 수 있습니다.
</div>

클로저가 나중에 또는 다른 격리 도메인에서 실행되기 위해 이스케이프할 때, Swift는 데이터 레이스를 일으키지 않는다는 것을 보장해야 합니다. `@Sendable` 속성은 경계를 넘어 전달하기에 안전한 클로저를 마킹합니다 - 안전하지 않게 가변 상태를 캡처할 수 없습니다. Swift는 종종 이것을 자동으로 추론합니다 (`Task.detached`처럼), 하지만 때때로 클로저를 받는 API를 설계할 때 명시적으로 선언해야 합니다.

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // 이 클로저는 분리된 태스크에서 MainActor로 넘어갑니다
            // @Sendable이어야 합니다 (Swift가 이것을 추론합니다)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// 필요할 때 명시적인 @Sendable
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - 오래된 API 연결하기

<div class="analogy">
오래된 종이 메모 시스템과 현대적인 이메일 사이의 번역가처럼. 오래된 시스템이 응답을 전달할 때까지 우편실 옆에서 기다린 다음, 새 시스템을 통해 전달합니다.
</div>

많은 오래된 API들은 async/await 대신 완료 핸들러를 사용합니다. 완전히 다시 작성하는 대신, `withCheckedContinuation`을 사용해서 감쌀 수 있습니다. 이 함수는 현재 태스크를 일시 중지하고, continuation 객체를 제공하고, `continuation.resume()`을 호출할 때 재개합니다. "checked" 변형은 두 번 재개하거나 전혀 재개하지 않는 것과 같은 프로그래밍 에러를 잡아냅니다.

<div class="isolation-legend">
  <span class="isolation-legend-item main">비동기 컨텍스트</span>
  <span class="isolation-legend-item nonisolated">콜백 컨텍스트</span>
</div>
<div class="code-isolation">
<div class="isolation-sidebar">
  <div class="segment nonisolated" style="flex-grow: 5"></div>
  <div class="segment main" style="flex-grow: 3"></div>
  <div class="segment nonisolated" style="flex-grow: 3"></div>
  <div class="segment main" style="flex-grow: 2"></div>
</div>
<div class="isolation-overlay">
  <div class="segment" style="flex-grow: 5"></div>
  <div class="segment main-highlight" style="flex-grow: 3"></div>
  <div class="segment nonisolated-highlight" style="flex-grow: 3"></div>
  <div class="segment main-highlight" style="flex-grow: 2"></div>
</div>

```swift
// 오래된 콜백 기반 API
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... 콜백이 있는 네트워크 호출
}

// async로 감싸기
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // 다시 연결합니다!
        }
    }
}
```

</div>

던지는 함수의 경우, `withCheckedThrowingContinuation`을 사용하세요:

```swift
func fetchUserThrowing(id: String) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        fetchUser(id: id) { result in
            switch result {
            case .success(let user):
                continuation.resume(returning: user)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
```

#### AsyncStream - 이벤트 소스 연결하기

<div class="analogy">
우편 전달 서비스를 설정하는 것처럼 - 오래된 주소로 편지가 도착할 때마다, 자동으로 새 받은편지함으로 라우팅됩니다. 우편이 계속 오는 한 스트림은 계속 흐릅니다.
</div>

`withCheckedContinuation`은 한 번의 콜백을 처리하는 반면, 많은 API들은 시간이 지남에 따라 여러 값을 전달합니다 - delegate 메서드, NotificationCenter, 또는 커스텀 이벤트 시스템. `AsyncStream`은 이것들을 Swift의 `AsyncSequence`로 연결하여, `for await` 루프를 사용할 수 있게 합니다. 스트림을 생성하고, continuation을 저장하고, 새 값이 도착할 때마다 `yield()`를 호출합니다.

```swift
class LocationTracker: NSObject, CLLocationManagerDelegate {
    private var continuation: AsyncStream<CLLocation>.Continuation?

    var locations: AsyncStream<CLLocation> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func locationManager(_ manager: CLLocationManager,
                        didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            continuation?.yield(location)
        }
    }
}

// 사용법
let tracker = LocationTracker()
for await location in tracker.locations {
    print("새 위치: \(location)")
}
```

#### Task.isCancelled - 협력적 취소

<div class="analogy">
큰 프로젝트의 각 단계를 시작하기 전에 "이 작업을 중단하세요" 메모가 있는지 받은편지함을 확인하는 것처럼. 강제로 중단되지 않습니다 - 확인하고 정중하게 응답하도록 선택합니다.
</div>

Swift는 협력적 취소를 사용합니다 - 태스크가 취소될 때, 즉시 중단되지 않습니다. 대신, 플래그가 설정되고, 주기적으로 확인하는 것이 여러분의 책임입니다. 이것은 정리와 부분 결과에 대한 제어를 제공합니다. `Task.checkCancellation()`을 사용하여 즉시 던지거나, 취소를 우아하게 처리하고 싶을 때 (부분 결과 반환과 같이) `Task.isCancelled`를 확인하세요.

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // 각 비용이 많이 드는 작업 전에 확인합니다
        try Task.checkCancellation()  // 취소되면 던집니다

        // 또는 던지지 않고 확인합니다
        if Task.isCancelled {
            return results  // 부분 결과를 반환합니다
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - 현재 컨텍스트 벗어나기

<div class="analogy">
여러분의 부서에 보고하지 않는 외부 계약자를 고용하는 것처럼. 그들은 독립적으로 일하고, 사무실의 규칙을 따르지 않으며, 결과를 다시 받아야 할 때 명시적으로 조정해야 합니다.
</div>

일반 `Task { }`는 현재 액터 컨텍스트를 상속합니다 - `@MainActor`에 있으면, 태스크는 `@MainActor`에서 실행됩니다. 때때로 그것이 원하는 것이 아닙니다, 특히 UI를 차단할 CPU 집약적인 작업에서요. `Task.detached`는 상속된 컨텍스트가 없는 태스크를 생성하여, 백그라운드 익스큐터에서 실행됩니다. 하지만 드물게 사용하세요 - 대부분의 경우, 적절한 `await` 포인트를 가진 일반 `Task`가 충분하고 추론하기 더 쉽습니다.

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item detached">분리됨</span>
</div>
<div class="code-isolation">
<div class="isolation-sidebar">
  <div class="segment main" style="flex-grow: 10"></div>
  <div class="segment detached" style="flex-grow: 2"></div>
  <div class="segment main" style="flex-grow: 1"></div>
  <div class="segment detached" style="flex-grow: 1"></div>
  <div class="segment main" style="flex-grow: 3"></div>
</div>
<div class="isolation-overlay">
  <div class="segment" style="flex-grow: 10"></div>
  <div class="segment detached-highlight" style="flex-grow: 2"></div>
  <div class="segment" style="flex-grow: 1"></div>
  <div class="segment detached-highlight" style="flex-grow: 1"></div>
  <div class="segment" style="flex-grow: 3"></div>
</div>

```swift
@MainActor
class ImageProcessor {
    func processImage(_ image: UIImage) {
        // 하지 마세요: 여전히 MainActor 컨텍스트를 상속합니다
        Task {
            let filtered = applyFilters(image)  // 메인을 차단합니다!
        }

        // 하세요: 분리된 태스크는 독립적으로 실행됩니다
        Task.detached(priority: .userInitiated) {
            let filtered = await self.applyFilters(image)
            await MainActor.run {
                self.displayImage(filtered)
            }
        }
    }
}
```

</div>

<div class="warning">
<h4>Task.detached는 보통 틀렸습니다</h4>

대부분의 경우, 일반 `Task`를 원합니다. 분리된 태스크는 우선순위, task-local 값, 또는 액터 컨텍스트를 상속하지 않습니다. 명시적으로 그 분리가 필요한 경우에만 사용하세요.
</div>

#### @preconcurrency - 레거시 코드와 함께 살기

아직 동시성을 위해 업데이트되지 않은 모듈을 임포트할 때 경고를 억제합니다:

```swift
// 이 임포트에서 경고 억제
@preconcurrency import OldFramework

// 또는 프로토콜 준수에서
class MyDelegate: @preconcurrency SomeOldDelegate {
    // non-Sendable 요구사항에 대해 경고하지 않습니다
}
```

<div class="tip">
<h4>@preconcurrency는 임시적입니다</h4>

코드를 업데이트하는 동안 브리지로 사용하세요. 목표는 결국 이것을 제거하고 적절한 Sendable 준수를 갖는 것입니다.
</div>

## 더 읽을 거리

이 가이드는 Swift 동시성에 대한 최고의 리소스를 정리합니다.

<div class="resources">
<h4>Matt Massicotte의 블로그 (강력 추천)</h4>

- [A Swift Concurrency Glossary](https://www.massicotte.org/concurrency-glossary) - 필수 용어
- [An Introduction to Isolation](https://www.massicotte.org/intro-to-isolation/) - 핵심 개념
- [When should you use an actor?](https://www.massicotte.org/actors/) - 실용적인 가이드
- [Non-Sendable types are cool too](https://www.massicotte.org/non-sendable/) - 왜 더 간단한 것이 더 나은가
- [Crossing the Boundary](https://www.massicotte.org/crossing-the-boundary/) - non-Sendable 타입과 작업하기
- [Problematic Swift Concurrency Patterns](https://www.massicotte.org/problematic-patterns/) - 피해야 할 것
- [Making Mistakes with Swift Concurrency](https://www.massicotte.org/mistakes-with-concurrency/) - 에러에서 배우기
</div>

<div class="resources">
<h4>공식 Apple 리소스</h4>

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: Meet async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Protect mutable state with actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>튜토리얼</h4>

- [Swift Concurrency by Example - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Async await in Swift - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

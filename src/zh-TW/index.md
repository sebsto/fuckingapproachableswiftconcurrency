---
layout: base.njk
title: 該死的易懂 Swift 並發
description: Swift 並發的直白指南。用簡單的心智模型學習 async/await、actors、Sendable 和 MainActor。沒有術語,只有清晰的解釋。
lang: zh-TW
dir: ltr
nav:
  isolation: 隔離
  domains: 域
  patterns: 模式
  errors: 錯誤
footer:
  madeWith: 用挫折和愛製作。因為 Swift 並發不必令人困惑。
  viewOnGitHub: 在 GitHub 上查看
---

<section class="hero">
  <div class="container">
    <h1>該死的易懂<br><span class="accent">Swift 並發</span></h1>
    <p class="subtitle">終於能理解 async/await、actors 和 Sendable。清晰的心智模型,沒有術語。</p>
    <p class="credit">非常感謝 <a href="https://www.massicotte.org/">Matt Massicotte</a> 讓 Swift 並發變得易懂。由 <a href="https://pepicrft.me">Pedro Piñera</a> 整理。發現問題?<a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute">承襲 <a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a> 和 <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a> 的傳統</p>
    <p class="cta-tuist">用 <a href="https://tuist.dev">Tuist</a> 擴展你的開發</p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## 老實說

Swift 並發沒有速查表。每一個「只要做 X」的答案在某些情境下都是錯的。

**但好消息是:**一旦你理解了[隔離](#basics)(5 分鐘閱讀),一切就通了。編譯器錯誤開始變得合理。你不再對抗系統,而是與它協作。

*本指南針對 Swift 6+。大部分概念適用於 Swift 5.5+,但 Swift 6 強制執行更嚴格的並發檢查。*

<a href="#basics" class="read-more">從心智模型開始 &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## 你需要理解的唯一一件事

**[隔離](https://www.massicotte.org/intro-to-isolation/)**是一切的關鍵。這是 Swift 對這個問題的答案:*現在誰被允許接觸這個資料?*

<div class="analogy">
<h4>辦公大樓</h4>

把你的應用程式想像成一棟**辦公大樓**。每個辦公室都是一個**隔離域** - 一個一次只有一個人可以工作的私人空間。你不能就這樣闖入別人的辦公室開始重新排列他們的桌子。

我們將在整個指南中建立在這個比喻上。
</div>

### 為什麼不只是執行緒?

幾十年來,我們通過思考執行緒來編寫並發程式碼。問題是?**執行緒無法阻止你搬石頭砸自己的腳。**兩個執行緒可以同時存取相同的資料,導致資料競爭 - 這種 bug 會隨機崩潰,幾乎不可能重現。

在手機上,你可能僥倖過關。在處理數千個並發請求的伺服器上,資料競爭變成必然 - 通常在生產環境中出現,在星期五。隨著 Swift 擴展到伺服器和其他高度並發的環境,「祈求最好的結果」是行不通的。

舊方法是防禦性的:使用鎖、派遣佇列,希望你沒有漏掉任何地方。

Swift 的方法不同:**在編譯時讓資料競爭變得不可能。**與其問「這在哪個執行緒上?」,Swift 問「現在誰被允許接觸這個資料?」這就是隔離。

### 其他語言如何處理這個問題

| 語言 | 方法 | 何時發現 bug |
|----------|----------|------------------------------|
| **Swift** | 隔離 + Sendable | 編譯時 |
| **Rust** | 所有權 + 借用檢查器 | 編譯時 |
| **Kotlin** | 協程 + 結構化並行 | 部分編譯時 |
| **Go** | 通道 + 競爭檢測器 | 執行時(透過工具) |
| **Java** | `synchronized`、鎖 | 執行時(崩潰) |
| **JavaScript** | 單執行緒事件迴圈 | 完全避免 |
| **C/C++** | 手動鎖 | 執行時(未定義行為) |

Swift 和 Rust 提供了最強的編譯時資料競爭保證。Kotlin 協程提供了類似於 Swift async/await 的結構化並行,但在型別系統層面對執行緒安全的強制力不如 Swift。代價是?前期學習曲線更陡。但一旦你理解了這個模型,編譯器會支持你。

那些關於 `Sendable` 和 actor 隔離的惱人錯誤?它們正在捕獲以前會是靜默崩潰的 bug。

  </div>
</section>

<section id="domains">
  <div class="container">

## 隔離域

現在你理解了隔離(私人辦公室),讓我們看看 Swift 大樓中不同類型的辦公室。

<div class="analogy">
<h4>辦公大樓</h4>

- **前台** (`MainActor`) - 所有客戶互動發生的地方。只有一個,它處理使用者看到的一切。
- **部門辦公室** (`actor`) - 會計、法務、人資。每個部門都有自己的辦公室,保護自己的敏感資料。
- **走廊和公共區域** (`nonisolated`) - 任何人都可以走過的共享空間。這裡沒有私人資料。
</div>

### MainActor:前台

`MainActor` 是一個在主執行緒上執行的特殊隔離域。這是所有 UI 工作發生的地方。

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // UI 狀態存在這裡

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // 安全 - 我們在 MainActor 上
    }
}
```

<div class="tip">
<h4>有疑問時,使用 MainActor</h4>

對於大多數應用程式,用 `@MainActor` 標記你的 ViewModels 和 UI 相關類別是正確的選擇。效能問題通常被誇大了 - 從這裡開始,只有在你測量到實際問題時才優化。
</div>

### Actors:部門辦公室

`actor` 就像一個部門辦公室 - 它保護自己的資料,一次只允許一個訪客。

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // 安全!一次只有一個呼叫者
    }
}
```

沒有 actors,兩個執行緒讀取 balance = 100,都加 50,都寫入 150 - 你損失了 $50。有了 actors,Swift 自動將存取排隊,兩次存款都正確完成。

<div class="warning">
<h4>不要過度使用 actors</h4>

你只有在**所有四個**條件都為真時才需要自訂 actor:
1. 你有非 Sendable(執行緒不安全的)可變狀態
2. 多個地方需要存取它
3. 對該狀態的操作必須是原子的
4. 它不能只是存在於 MainActor 上

如果任何條件為假,你可能不需要 actor。大多數 UI 狀態可以存在於 `@MainActor` 上。[閱讀更多關於何時使用 actors](https://www.massicotte.org/actors/)。
</div>

### Nonisolated:走廊

標記為 `nonisolated` 的程式碼就像走廊 - 它不屬於任何辦公室,可以從任何地方存取。

```swift
actor UserSession {
    let userId: String          // 不可變 - 可以從任何地方安全讀取
    var lastActivity: Date      // 可變 - 需要 actor 保護

    nonisolated var displayId: String {
        "User: \(userId)"       // 只讀取不可變資料
    }
}

// 用法 - nonisolated 不需要 await
let session = UserSession(userId: "123")
print(session.displayId)  // 同步工作!
```

對於只讀取不可變資料的計算屬性,使用 `nonisolated`。

  </div>
</section>

<section id="propagation">
  <div class="container">

## 隔離如何傳播

當你用 actor 隔離標記一個型別時,它的方法會發生什麼?閉包呢?理解隔離如何擴散是避免意外的關鍵。

<div class="analogy">
<h4>辦公大樓</h4>

當你被聘用到一個部門時,你預設在那個部門的辦公室工作。如果行銷部門聘用你,你不會隨機出現在會計部門。

同樣地,當一個函式在 `@MainActor` 類別內定義時,它會繼承該隔離。它「在與其父級相同的辦公室工作」。
</div>

### 類別繼承它們的隔離

```swift
@MainActor
class ViewModel {
    var count = 0           // MainActor 隔離

    func increment() {      // 也是 MainActor 隔離
        count += 1
    }
}
```

類別內的所有東西都繼承 `@MainActor`。你不需要標記每個方法。

### Tasks 繼承上下文(通常)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // 這繼承了 MainActor!
            self.updateUI()  // 安全,不需要 await
        }
    }
}
```

從 `@MainActor` 上下文建立的 `Task { }` 保持在 `MainActor` 上。這通常是你想要的。

### Task.detached 中斷繼承

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // 不再在 MainActor 上!
            await self.updateUI()  // 現在需要 await
        }
    }
}
```

<div class="analogy">
<h4>辦公大樓</h4>

`Task.detached` 就像聘用外部承包商。他們沒有你辦公室的門禁卡 - 他們在自己的空間工作,必須通過正當管道存取你的東西。
</div>

<div class="warning">
<h4>Task.detached 通常是錯的</h4>

大多數時候,你想要一個常規的 `Task`。分離的 tasks 不繼承優先級、task-local 值或 actor 上下文。只有在你明確需要這種分離時才使用它們。
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## 什麼可以跨越邊界

現在你知道了隔離域(辦公室)以及它們如何傳播,下一個問題是:**你可以在它們之間傳遞什麼?**

<div class="analogy">
<h4>辦公大樓</h4>

不是所有東西都可以離開辦公室:

- **影印本**可以安全共享 - 如果法務部影印一份文件並發送給會計部,兩者都有自己的副本。沒有衝突。
- **原始簽署的合約**必須留在原地 - 如果兩個部門都可以修改原件,就會陷入混亂。

在 Swift 術語中:**Sendable** 型別是影印本(可以安全共享),**非 Sendable** 型別是原件(必須留在一個辦公室)。
</div>

### Sendable:可以安全共享

這些型別可以安全地跨越隔離邊界:

```swift
// 具有不可變資料的結構 - 像影印本
struct User: Sendable {
    let id: Int
    let name: String
}

// Actors 保護自己 - 它們處理自己的訪客
actor BankAccount { }  // 自動 Sendable
```

**自動 Sendable:**
- 具有 Sendable 屬性的值型別(structs、enums)
- Actors(它們保護自己)
- 不可變類別(`final class` 只有 `let` 屬性)

### 非 Sendable:必須留在原地

這些型別無法安全地跨越邊界:

```swift
// 具有可變狀態的類別 - 像原始文件
class Counter {
    var count = 0  // 兩個辦公室修改這個 = 災難
}
```

**為什麼這是關鍵區別?**因為你會遇到的每個編譯器錯誤都歸結為:*「你正在嘗試跨越隔離邊界發送非 Sendable 型別。」*

### 當編譯器抱怨時

如果 Swift 說某樣東西不是 Sendable,你有幾個選擇:

1. **讓它成為值型別** - 使用 `struct` 而不是 `class`
2. **隔離它** - 將它保持在 `@MainActor` 上,這樣它就不需要跨越
3. **保持它為非 Sendable** - 只是不要在辦公室之間傳遞它
4. **最後手段:**`@unchecked Sendable` - 你承諾它是安全的(小心)

<div class="tip">
<h4>從非 Sendable 開始</h4>

[Matt Massicotte 主張](https://www.massicotte.org/non-sendable/)從常規的非 Sendable 型別開始。只有在需要跨越邊界時才添加 `Sendable`。非 Sendable 型別保持簡單,避免一致性的麻煩。
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## 如何跨越邊界

你理解了隔離域,你知道什麼可以跨越它們。現在:**你實際上如何在辦公室之間溝通?**

<div class="analogy">
<h4>辦公大樓</h4>

你不能就這樣闖入另一個辦公室。你發送一個請求並等待回應。在等待時你可能會處理其他事情,但在繼續之前你需要那個回應。

這就是 `async/await` - 向另一個隔離域發送請求並暫停,直到你得到答案。
</div>

### await 關鍵字

當你在另一個 actor 上呼叫函式時,你需要 `await`:

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
        await store.add(item)  // 對另一個辦公室的請求
        updateUI()             // 回到我們的辦公室
    }
}
```

`await` 意味著:「發送這個請求並暫停,直到它完成。我可能在等待時做其他工作。」

### 掛起,而非阻塞

<div class="warning">
<h4>常見誤解</h4>

許多開發者假設添加 `async` 會讓程式碼在背景執行。並不會。`async` 關鍵字只是意味著函式*可以暫停*。它並不說明它*在哪裡*執行。
</div>

關鍵見解是**阻塞**和**掛起**之間的區別:

- **阻塞**:你坐在等候室盯著牆壁。什麼都不會發生。
- **掛起**:你留下你的電話號碼去跑腿。準備好時他們會打給你。

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">阻塞</button>
<button>掛起</button>
</div>
<div class="code-tab-content active">

```swift
// 執行緒閒置,5 秒內什麼都不做
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// 執行緒在等待時被釋放去做其他工作
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### 從同步程式碼啟動非同步工作

有時你在同步程式碼中需要呼叫非同步的東西。使用 `Task`:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // 同步函式
        Task {
            await loadData()  // 現在我們可以使用 await
        }
    }
}
```

<div class="analogy">
<h4>辦公大樓</h4>

`Task` 就像將工作分配給員工。員工處理請求(包括等待其他辦公室),而你繼續你的直接工作。
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## 有效的模式

### 網路請求模式

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (網路呼叫)</span>
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

        // 這會掛起 - 執行緒可以自由地做其他工作
        let users = await networkService.getUsers()

        // 自動回到 MainActor
        self.users = users
        isLoading = false
    }
}
```

</div>

不需要 `DispatchQueue.main.async`。`@MainActor` 屬性處理它。

### 使用 async let 進行並行工作

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // 三個都並行執行!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### 防止雙擊

這個模式來自 Matt Massicotte 關於[有狀態系統](https://www.massicotte.org/step-by-step-stateful-systems)的指南:

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // 在任何非同步工作之前同步守衛
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
<h4>關鍵:守衛必須是同步的</h4>

如果你在 Task 內的 await 之後放置守衛,會有一個視窗讓兩次按鈕點擊都可以開始工作。[了解更多關於順序和並發](https://www.massicotte.org/ordering-and-concurrency)。
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## 要避免的常見錯誤

這些是即使有經驗的開發者也會犯的[常見錯誤](https://www.massicotte.org/mistakes-with-concurrency/):

### 認為 async = 背景

<div class="analogy">
<h4>辦公大樓</h4>

添加 `async` 不會將你移到不同的辦公室。你仍然在前台 - 你現在只是可以等待交付而不會凍結在原地。
</div>

```swift
// 這仍然會阻塞主執行緒!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // 同步 = 阻塞
    data = result
}
```

如果你需要在另一個辦公室完成工作,明確地發送到那裡:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // 現在在不同的辦公室
    }.value
    await MainActor.run { data = result }
}
```

### 建立太多 actors

<div class="analogy">
<h4>辦公大樓</h4>

為每一塊資料建立新辦公室意味著它們之間的溝通需要無盡的文書工作。你的大部分工作可以在前台進行。
</div>

```swift
// 過度工程化 - 每次呼叫都需要在辦公室之間走動
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// 更好 - 大多數東西可以存在於前台
@MainActor
class AppState { }
```

### 到處使用 MainActor.run

<div class="analogy">
<h4>辦公大樓</h4>

如果你不斷為每件小事走到前台,就直接在那裡工作。讓它成為你工作描述的一部分,而不是持續的差事。
</div>

```swift
// 不要這樣做 - 不斷走到前台
await MainActor.run { doMainActorStuff() }

// 這樣做 - 就在前台工作
@MainActor func doMainActorStuff() { }
```

### 讓所有東西都 Sendable

不是所有東西都需要是 `Sendable`。如果你到處添加 `@unchecked Sendable`,你正在為不需要離開辦公室的東西製作影印本。

### 忽略編譯器警告

每個關於 `Sendable` 的編譯器警告都是保全人員告訴你某樣東西在辦公室之間攜帶不安全。不要忽略它們 - [理解它們](https://www.massicotte.org/complete-checking/)。

  </div>
</section>

<section id="errors">
  <div class="container">

## 常見編譯器錯誤

這些是你會看到的實際錯誤訊息。每一個都是編譯器在保護你免受資料競爭的影響。

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>辦公大樓</h4>

你正在嘗試將原始文件攜帶到另一個辦公室。要麼製作影印本(Sendable),要麼將它保留在一個地方。
</div>

**修復 1:**使用 `struct` 而不是 `class`

**修復 2:**將它保留在一個 actor 上:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // 留在前台
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>辦公大樓</h4>

你正在嘗試在辦公室之間攜帶原件。保全人員攔住了你。
</div>

**修復 1:**讓它成為 struct:

```swift
// 之前:class(非 Sendable)
class User { var name: String }

// 之後:struct(Sendable)
struct User: Sendable { let name: String }
```

**修復 2:**將它隔離到一個 actor:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>辦公大樓</h4>

你正在不通過正當管道就伸手去拿另一個辦公室的檔案櫃。
</div>

**修復:**使用 `await`:

```swift
// 錯誤 - 直接伸手去拿
let value = myActor.balance

// 正確 - 正當請求
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>辦公大樓</h4>

你正在嘗試不排隊就使用前台。
</div>

**修復 1:**讓呼叫者成為 `@MainActor`:

```swift
@MainActor
func doSomething() {
    updateUI()  // 相同的隔離,不需要 await
}
```

**修復 2:**使用 `await`:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## Swift 並發的三個層級

你不需要一次學習所有東西。通過這些層級進步:

<div class="analogy">
<h4>辦公大樓</h4>

把它想像成發展一家公司。你不會從一棟 50 層的總部開始 - 你從一張桌子開始。
</div>

這些層級不是嚴格的界限 - 你的應用程式的不同部分可能需要不同的層級。一個主要是層級 1 的應用程式可能有一個需要層級 2 模式的功能。這沒問題。對每個部分使用最簡單有效的方法。

### 層級 1:新創公司

每個人都在前台工作。簡單、直接,沒有官僚主義。

- 使用 `async/await` 進行網路呼叫
- 用 `@MainActor` 標記 UI 類別
- 使用 SwiftUI 的 `.task` 修飾器

這處理了 80% 的應用程式。像 [Things](https://culturedcode.com/things/)、[Bear](https://bear.app/)、[Flighty](https://flighty.com/) 或 [Day One](https://dayoneapp.com/) 這樣的應用程式可能屬於這個類別 - 主要取得資料並顯示它的應用程式。

### 層級 2:成長中的公司

你需要同時處理多件事。是時候進行並行專案和協調團隊了。

- 使用 `async let` 進行並行工作
- 使用 `TaskGroup` 進行動態並行
- 理解 task 取消

像 [Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp)(管理多個時間線和串流更新的 Mastodon 客戶端)、[Overcast](https://overcast.fm/)(協調下載、播放和背景同步)或 [Slack](https://slack.com/)(跨多個頻道的即時訊息)這樣的應用程式可能為某些功能使用這些模式。

### 層級 3:企業

具有自己政策的專門部門。複雜的辦公室間溝通。

- 為共享狀態建立自訂 actors
- 深入理解 Sendable
- 自訂執行器

像 [Xcode](https://developer.apple.com/xcode/)、[Final Cut Pro](https://www.apple.com/final-cut-pro/) 或像 [Vapor](https://vapor.codes/) 和 [Hummingbird](https://hummingbird.codes/) 這樣的伺服器端 Swift 框架可能需要這些模式 - 複雜的共享狀態、數千個並發連接,或其他人建構的框架級程式碼。

<div class="tip">
<h4>從簡單開始</h4>

大多數應用程式永遠不需要層級 3。當新創公司就足夠時,不要建立企業。
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## 詞彙表:你會遇到的更多關鍵字

除了核心概念之外,這裡還有你會在實際中看到的其他 Swift 並發關鍵字:

| 關鍵字 | 含義 |
|---------|---------------|
| `nonisolated` | 選擇退出 actor 的隔離 - 在沒有保護的情況下執行 |
| `isolated` | 明確宣告參數在 actor 的上下文中執行 |
| `@Sendable` | 標記閉包可以安全地跨越隔離邊界傳遞 |
| `Task.detached` | 建立與當前上下文完全分離的 task |
| `AsyncSequence` | 你可以用 `for await` 迭代的序列 |
| `AsyncStream` | 將基於回呼的程式碼橋接到非同步序列的方式 |
| `withCheckedContinuation` | 將完成處理器橋接到 async/await |
| `Task.isCancelled` | 檢查當前 task 是否已取消 |
| `@preconcurrency` | 抑制舊版程式碼的並發警告 |
| `GlobalActor` | 用於建立你自己的自訂 actors(如 MainActor)的協定 |

### 何時使用每個

#### nonisolated - 讀取計算屬性

<div class="analogy">
就像你辦公室門上的名牌 - 任何路過的人都可以讀它,而不需要進來等你。
</div>

預設情況下,actor 內的所有東西都是隔離的 - 你需要 `await` 來存取它。但有時你有本質上可以安全讀取的屬性:不可變的 `let` 常數,或只從其他安全資料派生值的計算屬性。將這些標記為 `nonisolated` 讓呼叫者可以同步存取它們,避免不必要的非同步開銷。

<div class="isolation-legend">
  <span class="isolation-legend-item actor">Actor 隔離</span>
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
    let userId: String  // 不可變,可以安全讀取
    var lastActivity: Date  // 可變,需要保護

    // 這可以在不使用 await 的情況下呼叫
    nonisolated var displayId: String {
        "User: \(userId)"  // 只讀取不可變資料
    }
}
```

</div>

```swift
// 用法
let session = UserSession(userId: "123")
print(session.displayId)  // 不需要 await!
```

#### @Sendable - 跨越邊界的閉包

<div class="analogy">
就像一個裡面有指令的密封信封 - 信封可以在辦公室之間傳遞,打開它的人可以安全地遵循指令。
</div>

當閉包跳脫以便稍後或在不同的隔離域上執行時,Swift 需要保證它不會導致資料競爭。`@Sendable` 屬性標記可以安全跨越邊界傳遞的閉包 - 它們不能不安全地捕獲可變狀態。Swift 通常會自動推斷這個(像 `Task.detached`),但有時在設計接受閉包的 API 時,你需要明確宣告它。

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // 這個閉包從分離的 task 跨越到 MainActor
            // 它必須是 @Sendable(Swift 推斷這個)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// 在需要時明確的 @Sendable
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - 橋接舊 API

<div class="analogy">
就像舊的紙質備忘錄系統和現代電子郵件之間的翻譯員。你在郵件室等待,直到舊系統交付回應,然後通過新系統轉發它。
</div>

許多較舊的 API 使用完成處理器而不是 async/await。與其完全重寫它們,你可以使用 `withCheckedContinuation` 包裝它們。這個函式掛起當前 task,給你一個 continuation 物件,並在你呼叫 `continuation.resume()` 時恢復。"checked" 變體會捕獲程式錯誤,如恢復兩次或從不恢復。

<div class="isolation-legend">
  <span class="isolation-legend-item main">非同步上下文</span>
  <span class="isolation-legend-item nonisolated">回呼上下文</span>
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
// 舊的基於回呼的 API
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... 帶有回呼的網路呼叫
}

// 包裝為 async
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // 橋接回去!
        }
    }
}
```

</div>

對於拋出函式,使用 `withCheckedThrowingContinuation`:

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

#### AsyncStream - 橋接事件來源

<div class="analogy">
就像設置郵件轉發 - 每次有信件到達舊地址時,它會自動路由到你的新收件箱。只要郵件持續來,串流就會持續流動。
</div>

雖然 `withCheckedContinuation` 處理一次性回呼,但許多 API 隨時間傳遞多個值 - 委派方法、NotificationCenter 或自訂事件系統。`AsyncStream` 將這些橋接到 Swift 的 `AsyncSequence`,讓你使用 `for await` 迴圈。你建立一個串流,儲存它的 continuation,並在每次新值到達時呼叫 `yield()`。

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

// 用法
let tracker = LocationTracker()
for await location in tracker.locations {
    print("新位置: \(location)")
}
```

#### Task.isCancelled - 協作取消

<div class="analogy">
就像在開始大專案的每個步驟之前檢查你的收件箱是否有「停止處理這個」的備忘錄。你不被強制停止 - 你選擇檢查並禮貌地回應。
</div>

Swift 使用協作取消 - 當 task 被取消時,它不會立即停止。相反,會設置一個標誌,你有責任定期檢查它。這讓你可以控制清理和部分結果。使用 `Task.checkCancellation()` 立即拋出,或在你想要優雅地處理取消時檢查 `Task.isCancelled`(如返回部分結果)。

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // 在每個昂貴的操作之前檢查
        try Task.checkCancellation()  // 如果取消則拋出

        // 或不拋出地檢查
        if Task.isCancelled {
            return results  // 返回部分結果
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - 跳脫當前上下文

<div class="analogy">
就像聘用一個不向你的部門報告的外部承包商。他們獨立工作,不遵循你辦公室的規則,當你需要結果時,你必須明確協調。
</div>

常規的 `Task { }` 繼承當前的 actor 上下文 - 如果你在 `@MainActor` 上,task 就在 `@MainActor` 上執行。有時這不是你想要的,特別是對於會阻塞 UI 的 CPU 密集型工作。`Task.detached` 建立一個沒有繼承上下文的 task,在背景執行器上執行。但要謹慎使用 - 大多數時候,帶有適當 `await` 點的常規 `Task` 就足夠了,而且更容易推理。

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item detached">Detached</span>
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
        // 不要:這仍然繼承 MainActor 上下文
        Task {
            let filtered = applyFilters(image)  // 阻塞主執行緒!
        }

        // 要:分離的 task 獨立執行
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
<h4>Task.detached 通常是錯的</h4>

大多數時候,你想要一個常規的 `Task`。分離的 tasks 不繼承優先級、task-local 值或 actor 上下文。只有在你明確需要這種分離時才使用它們。
</div>

#### @preconcurrency - 與舊版程式碼共存

在匯入尚未更新為並發的模組時抑制警告:

```swift
// 抑制此匯入的警告
@preconcurrency import OldFramework

// 或在協定一致性上
class MyDelegate: @preconcurrency SomeOldDelegate {
    // 不會警告非 Sendable 要求
}
```

<div class="tip">
<h4>@preconcurrency 是暫時的</h4>

在更新程式碼時將其用作橋接。目標是最終移除它並擁有適當的 Sendable 一致性。
</div>

## 延伸閱讀

本指南提煉了關於 Swift 並發的最佳資源。

<div class="resources">
<h4>Matt Massicotte 的部落格(強烈推薦)</h4>

- [A Swift Concurrency Glossary](https://www.massicotte.org/concurrency-glossary) - 必要術語
- [An Introduction to Isolation](https://www.massicotte.org/intro-to-isolation/) - 核心概念
- [When should you use an actor?](https://www.massicotte.org/actors/) - 實用指南
- [Non-Sendable types are cool too](https://www.massicotte.org/non-sendable/) - 為什麼更簡單更好
- [Crossing the Boundary](https://www.massicotte.org/crossing-the-boundary/) - 處理非 Sendable 型別
- [Problematic Swift Concurrency Patterns](https://www.massicotte.org/problematic-patterns/) - 要避免的事項
- [Making Mistakes with Swift Concurrency](https://www.massicotte.org/mistakes-with-concurrency/) - 從錯誤中學習
</div>

<div class="resources">
<h4>Apple 官方資源</h4>

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: Meet async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Protect mutable state with actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>教學</h4>

- [Swift Concurrency by Example - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Async await in Swift - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

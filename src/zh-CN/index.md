---
layout: base.njk
title: 该死的易懂 Swift 并发
description: Swift 并发的直白指南。用简单的心智模型学习 async/await、actors、Sendable 和 MainActor。没有术语,只有清晰的解释。
lang: zh-CN
dir: ltr
nav:
  isolation: 隔离
  domains: 域
  patterns: 模式
  errors: 错误
footer:
  madeWith: 用挫折和爱制作。因为 Swift 并发不必令人困惑。
  viewOnGitHub: 在 GitHub 上查看
---

<section class="hero">
  <div class="container">
    <h1>该死的易懂<br><span class="accent">Swift 并发</span></h1>
    <p class="subtitle">终于能理解 async/await、actors 和 Sendable 了。清晰的心智模型,没有术语。</p>
    <p class="credit">特别感谢 <a href="https://www.massicotte.org/">Matt Massicotte</a> 让 Swift 并发变得易于理解。由 <a href="https://pepicrft.me">Pedro Piñera</a> 整理。发现问题?<a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute">延续 <a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a> 和 <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a> 的传统</p>
    <p class="cta-tuist">用 <a href="https://tuist.dev">Tuist</a> 扩展你的开发</p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## 真相

Swift 并发没有速查表。任何"只需这样做"的答案在某些情况下都是错的。

**但好消息是:**一旦你理解了[隔离](#basics)(5 分钟阅读),一切就都通了。编译器错误开始变得有意义。你不再与系统对抗,而是与它协作。

*本指南面向 Swift 6+。大多数概念适用于 Swift 5.5+,但 Swift 6 强制执行更严格的并发检查。*

<a href="#basics" class="read-more">从心智模型开始 &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## 你需要理解的一件事

**[隔离](https://www.massicotte.org/intro-to-isolation/)**是一切的关键。这是 Swift 对这个问题的答案:*现在谁被允许接触这个数据?*

<div class="analogy">
<h4>办公楼</h4>

把你的应用想象成一座**办公楼**。每个办公室都是一个**隔离域** - 一个私密空间,一次只有一个人可以工作。你不能直接闯入别人的办公室并开始重新整理他们的桌子。

我们将在整个指南中继续使用这个类比。
</div>

### 为什么不直接用线程?

几十年来,我们通过考虑线程来编写并发代码。问题是什么?**线程不能阻止你搬起石头砸自己的脚。**两个线程可以同时访问相同的数据,导致数据竞争 - 这种 bug 会随机崩溃,几乎无法复现。

在手机上,你可能侥幸过关。但在处理数千个并发请求的服务器上,数据竞争就成了必然 - 通常在生产环境中出现,在周五。随着 Swift 扩展到服务器和其他高度并发的环境,"希望最好的结果"是不够的。

旧的方法是防御性的:使用锁、调度队列,希望你没有漏掉任何地方。

Swift 的方法不同:**在编译时让数据竞争变得不可能。**Swift 不问"这在哪个线程上?",而是问"现在谁被允许接触这个数据?"这就是隔离。

### 其他语言如何处理这个问题

| 语言 | 方法 | 何时发现 bug |
|----------|----------|------------------------------|
| **Swift** | 隔离 + Sendable | 编译时 |
| **Rust** | 所有权 + 借用检查器 | 编译时 |
| **Kotlin** | 协程 + 结构化并发 | 部分编译时 |
| **Go** | 通道 + 竞争检测器 | 运行时(使用工具) |
| **Java** | `synchronized`、锁 | 运行时(崩溃) |
| **JavaScript** | 单线程事件循环 | 完全避免 |
| **C/C++** | 手动锁 | 运行时(未定义行为) |

Swift 和 Rust 提供了最强的编译时数据竞争保证。Kotlin 协程提供了类似于 Swift async/await 的结构化并发,但在类型系统层面对线程安全的强制力不如 Swift。代价是什么?前期学习曲线更陡峭。但一旦你理解了模型,编译器就会支持你。

那些关于 `Sendable` 和 actor 隔离的烦人错误?它们正在捕获以前会是静默崩溃的 bug。

  </div>
</section>

<section id="domains">
  <div class="container">

## 隔离域

现在你理解了隔离(私人办公室),让我们看看 Swift 办公楼中不同类型的办公室。

<div class="analogy">
<h4>办公楼</h4>

- **前台**(`MainActor`) - 所有客户互动发生的地方。只有一个,它处理用户看到的一切。
- **部门办公室**(`actor`) - 会计、法务、人力资源。每个部门都有自己的办公室保护自己的敏感数据。
- **走廊和公共区域**(`nonisolated`) - 任何人都可以走过的共享空间。这里没有私人数据。
</div>

### MainActor:前台

`MainActor` 是一个特殊的隔离域,运行在主线程上。这是所有 UI 工作发生的地方。

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // UI 状态存在这里

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // 安全 - 我们在 MainActor 上
    }
}
```

<div class="tip">
<h4>拿不准时,就用 MainActor</h4>

对于大多数应用,用 `@MainActor` 标记你的 ViewModel 和 UI 相关的类是正确的选择。性能问题通常被夸大了 - 从这里开始,只有在你测量到实际问题时才优化。
</div>

### Actors:部门办公室

`actor` 就像一个部门办公室 - 它保护自己的数据,一次只允许一个访客。

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // 安全!一次只有一个调用者
    }
}
```

没有 actor,两个线程读取 balance = 100,都加上 50,都写入 150 - 你损失了 50 美元。有了 actor,Swift 自动排队访问,两次存款都正确完成。

<div class="warning">
<h4>不要过度使用 actor</h4>

只有当**所有四个**条件都为真时,你才需要自定义 actor:
1. 你有非 Sendable(线程不安全)的可变状态
2. 多个地方需要访问它
3. 对该状态的操作必须是原子的
4. 它不能只存在于 MainActor 上

如果任何条件为假,你可能不需要 actor。大多数 UI 状态可以存在于 `@MainActor` 上。[阅读更多关于何时使用 actor](https://www.massicotte.org/actors/)。
</div>

### Nonisolated:走廊

标记为 `nonisolated` 的代码就像走廊 - 它不属于任何办公室,可以从任何地方访问。

```swift
actor UserSession {
    let userId: String          // 不可变 - 可以从任何地方安全读取
    var lastActivity: Date      // 可变 - 需要 actor 保护

    nonisolated var displayId: String {
        "User: \(userId)"       // 只读取不可变数据
    }
}

// 用法 - nonisolated 不需要 await
let session = UserSession(userId: "123")
print(session.displayId)  // 同步工作!
```

对只读取不可变数据的计算属性使用 `nonisolated`。

  </div>
</section>

<section id="propagation">
  <div class="container">

## 隔离如何传播

当你用 actor 隔离标记一个类型时,它的方法会发生什么?闭包呢?理解隔离如何传播是避免意外的关键。

<div class="analogy">
<h4>办公楼</h4>

当你被雇用到一个部门时,你默认在那个部门的办公室工作。如果市场部雇用你,你不会随机出现在会计部门。

类似地,当一个函数在 `@MainActor` 类内部定义时,它继承该隔离。它与其父级"在同一个办公室工作"。
</div>

### 类继承它们的隔离

```swift
@MainActor
class ViewModel {
    var count = 0           // MainActor 隔离

    func increment() {      // 也是 MainActor 隔离
        count += 1
    }
}
```

类内部的所有内容都继承 `@MainActor`。你不需要标记每个方法。

### Task 继承上下文(通常)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // 这继承了 MainActor!
            self.updateUI()  // 安全,不需要 await
        }
    }
}
```

从 `@MainActor` 上下文创建的 `Task { }` 保持在 `MainActor` 上。这通常是你想要的。

### Task.detached 打破继承

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // 不再在 MainActor 上了!
            await self.updateUI()  // 现在需要 await
        }
    }
}
```

<div class="analogy">
<h4>办公楼</h4>

`Task.detached` 就像雇用外部承包商。他们没有进入你办公室的通行证 - 他们在自己的空间工作,必须通过适当的渠道访问你的东西。
</div>

<div class="warning">
<h4>Task.detached 通常是错误的</h4>

大多数时候,你想要常规的 `Task`。分离的任务不继承优先级、任务本地值或 actor 上下文。只在你明确需要这种分离时使用它们。
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## 什么可以跨越边界

现在你知道了隔离域(办公室)以及它们如何传播,下一个问题是:**你可以在它们之间传递什么?**

<div class="analogy">
<h4>办公楼</h4>

不是所有东西都可以离开办公室:

- **复印件**可以安全共享 - 如果法务部复印一份文件并发送给会计部,双方都有自己的副本。没有冲突。
- **原始签名合同**必须留在原地 - 如果两个部门都能修改原件,就会一团糟。

用 Swift 术语:**Sendable** 类型是复印件(可以安全共享),**non-Sendable** 类型是原件(必须留在一个办公室)。
</div>

### Sendable:可以安全共享

这些类型可以安全地跨越隔离边界:

```swift
// 带有不可变数据的结构体 - 像复印件
struct User: Sendable {
    let id: Int
    let name: String
}

// Actor 保护自己 - 它们处理自己的访客
actor BankAccount { }  // 自动 Sendable
```

**自动 Sendable:**
- 具有 Sendable 属性的值类型(结构体、枚举)
- Actor(它们保护自己)
- 不可变类(`final class` 只有 `let` 属性)

### Non-Sendable:必须留在原地

这些类型不能安全地跨越边界:

```swift
// 带有可变状态的类 - 像原始文档
class Counter {
    var count = 0  // 两个办公室修改这个 = 灾难
}
```

**为什么这是关键区别?**因为你将遇到的每个编译器错误都归结为:*"你试图跨隔离边界发送一个 non-Sendable 类型。"*

### 当编译器抱怨时

如果 Swift 说某些东西不是 Sendable,你有选项:

1. **把它变成值类型** - 使用 `struct` 而不是 `class`
2. **隔离它** - 将它保持在 `@MainActor` 上,这样它就不需要跨越
3. **保持它 non-Sendable** - 只是不在办公室之间传递它
4. **最后手段:** `@unchecked Sendable` - 你承诺它是安全的(要小心)

<div class="tip">
<h4>从 non-Sendable 开始</h4>

[Matt Massicotte 主张](https://www.massicotte.org/non-sendable/)从常规的 non-Sendable 类型开始。只在你需要跨越边界时添加 `Sendable`。non-Sendable 类型保持简单,避免遵从性麻烦。
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## 如何跨越边界

你理解了隔离域,你知道什么可以跨越它们。现在:**你如何实际在办公室之间通信?**

<div class="analogy">
<h4>办公楼</h4>

你不能直接闯入另一个办公室。你发送请求并等待响应。你可能在等待时做其他事情,但你需要那个响应才能继续。

这就是 `async/await` - 向另一个隔离域发送请求并暂停直到你得到答案。
</div>

### await 关键字

当你在另一个 actor 上调用函数时,你需要 `await`:

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
        await store.add(item)  // 向另一个办公室的请求
        updateUI()             // 回到我们的办公室
    }
}
```

`await` 意味着:"发送这个请求并暂停直到它完成。我可能在等待时做其他工作。"

### 挂起,而非阻塞

<div class="warning">
<h4>常见误解</h4>

许多开发者认为添加 `async` 会让代码在后台运行。不会。`async` 关键字只是意味着函数*可以暂停*。它对代码*在哪里*运行没有任何说明。
</div>

关键见解是**阻塞**和**挂起**之间的区别:

- **阻塞**:你坐在候诊室盯着墙。什么都不会发生。
- **挂起**:你留下你的电话号码并去办其他事。他们准备好时会打电话给你。

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">阻塞</button>
<button>挂起</button>
</div>
<div class="code-tab-content active">

```swift
// 线程闲置,5 秒什么都不做
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// 线程在等待时被释放去做其他工作
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### 从同步代码启动异步工作

有时你在同步代码中需要调用异步的东西。使用 `Task`:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // 同步函数
        Task {
            await loadData()  // 现在我们可以使用 await
        }
    }
}
```

<div class="analogy">
<h4>办公楼</h4>

`Task` 就像给员工分配工作。员工处理请求(包括等待其他办公室),而你继续你的即时工作。
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## 有效的模式

### 网络请求模式

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (网络调用)</span>
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

        // 这会挂起 - 线程可以自由地做其他工作
        let users = await networkService.getUsers()

        // 自动回到 MainActor
        self.users = users
        isLoading = false
    }
}
```

</div>

没有 `DispatchQueue.main.async`。`@MainActor` 属性处理它。

### 用 async let 并行工作

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // 三个全部并行运行!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### 防止双击

这个模式来自 Matt Massicotte 关于[有状态系统](https://www.massicotte.org/step-by-step-stateful-systems)的指南:

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // 在任何异步工作之前同步守卫
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
<h4>关键:守卫必须是同步的</h4>

如果你把守卫放在 Task 内部的 await 之后,会有一个窗口期,两次按钮点击都可以开始工作。[了解更多关于顺序和并发](https://www.massicotte.org/ordering-and-concurrency)。
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## 要避免的常见错误

这些是[常见错误](https://www.massicotte.org/mistakes-with-concurrency/),即使是有经验的开发者也会犯:

### 认为 async = 后台

<div class="analogy">
<h4>办公楼</h4>

添加 `async` 不会把你移到不同的办公室。你仍然在前台 - 你现在只是可以等待交付而不会原地冻结。
</div>

```swift
// 这仍然阻塞主线程!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // 同步 = 阻塞
    data = result
}
```

如果你需要在另一个办公室完成工作,明确地把它发送到那里:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // 现在在不同的办公室
    }.value
    await MainActor.run { data = result }
}
```

### 创建太多 actor

<div class="analogy">
<h4>办公楼</h4>

为每个数据创建一个新办公室意味着在它们之间通信需要无休止的文书工作。你的大部分工作可以在前台完成。
</div>

```swift
// 过度设计 - 每次调用都需要在办公室之间走动
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// 更好 - 大多数东西可以在前台存在
@MainActor
class AppState { }
```

### 到处使用 MainActor.run

<div class="analogy">
<h4>办公楼</h4>

如果你为每件小事都不断走到前台,就直接在那里工作。让它成为你工作描述的一部分,而不是不断的差事。
</div>

```swift
// 不要这样做 - 不断走到前台
await MainActor.run { doMainActorStuff() }

// 这样做 - 就在前台工作
@MainActor func doMainActorStuff() { }
```

### 让所有东西都 Sendable

不是所有东西都需要是 `Sendable`。如果你到处添加 `@unchecked Sendable`,你正在复印不需要离开办公室的东西。

### 忽略编译器警告

每个关于 `Sendable` 的编译器警告都是保安告诉你某些东西在办公室之间携带不安全。不要忽略它们 - [理解它们](https://www.massicotte.org/complete-checking/)。

  </div>
</section>

<section id="errors">
  <div class="container">

## 常见编译器错误

这些是你会看到的实际错误消息。每一个都是编译器保护你免受数据竞争。

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>办公楼</h4>

你试图把原始文档带到另一个办公室。要么复印一份(Sendable),要么把它保留在一个地方。
</div>

**修复 1:** 使用 `struct` 而不是 `class`

**修复 2:** 将它保留在一个 actor 上:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // 保留在前台
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>办公楼</h4>

你试图在办公室之间携带原件。保安拦住了你。
</div>

**修复 1:** 把它变成结构体:

```swift
// 之前: class (non-Sendable)
class User { var name: String }

// 之后: struct (Sendable)
struct User: Sendable { let name: String }
```

**修复 2:** 将它隔离到一个 actor:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>办公楼</h4>

你正在伸手进入另一个办公室的文件柜,而没有通过适当的渠道。
</div>

**修复:** 使用 `await`:

```swift
// 错误 - 直接伸手
let value = myActor.balance

// 正确 - 适当的请求
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>办公楼</h4>

你试图使用前台而不排队等待。
</div>

**修复 1:** 让调用者成为 `@MainActor`:

```swift
@MainActor
func doSomething() {
    updateUI()  // 相同的隔离,不需要 await
}
```

**修复 2:** 使用 `await`:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## Swift 并发的三个级别

你不需要一次学习所有东西。通过这些级别逐步进步:

<div class="analogy">
<h4>办公楼</h4>

想象一下成长一家公司。你不会从 50 层的总部开始 - 你从一张桌子开始。
</div>

这些级别不是严格的界限 - 你的应用的不同部分可能需要不同的级别。一个主要是一级的应用可能有一个需要二级模式的功能。这没问题。对每个部分使用最简单的有效方法。

### 一级:创业公司

每个人都在前台工作。简单、直接、没有官僚作风。

- 对网络调用使用 `async/await`
- 用 `@MainActor` 标记 UI 类
- 使用 SwiftUI 的 `.task` 修饰符

这处理了 80% 的应用。像 [Things](https://culturedcode.com/things/)、[Bear](https://bear.app/)、[Flighty](https://flighty.com/) 或 [Day One](https://dayoneapp.com/) 这样的应用可能属于这个类别 - 主要获取数据并显示它的应用。

### 二级:成长中的公司

你需要同时处理多件事。是时候进行并行项目和协调团队了。

- 对并行工作使用 `async let`
- 对动态并行使用 `TaskGroup`
- 理解任务取消

像 [Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp)(Mastodon 客户端管理多个时间线和流式更新)、[Overcast](https://overcast.fm/)(协调下载、播放和后台同步)或 [Slack](https://slack.com/)(跨多个频道的实时消息)这样的应用可能对某些功能使用这些模式。

### 三级:企业

拥有自己政策的专门部门。复杂的办公室间通信。

- 为共享状态创建自定义 actor
- 深入理解 Sendable
- 自定义执行器

像 [Xcode](https://developer.apple.com/xcode/)、[Final Cut Pro](https://www.apple.com/final-cut-pro/) 或服务器端 Swift 框架如 [Vapor](https://vapor.codes/) 和 [Hummingbird](https://hummingbird.codes/) 这样的应用可能需要这些模式 - 复杂的共享状态、数千个并发连接,或其他人构建的框架级代码。

<div class="tip">
<h4>从简单开始</h4>

大多数应用永远不需要三级。当创业公司就够用时,不要建造企业。
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## 术语表:你会遇到的更多关键字

除了核心概念,这里是你会在实践中看到的其他 Swift 并发关键字:

| 关键字 | 它的意思 |
|---------|---------------|
| `nonisolated` | 选择退出 actor 的隔离 - 在没有保护的情况下运行 |
| `isolated` | 明确声明参数在 actor 的上下文中运行 |
| `@Sendable` | 标记闭包可以安全地跨隔离边界传递 |
| `Task.detached` | 创建一个完全独立于当前上下文的任务 |
| `AsyncSequence` | 你可以用 `for await` 迭代的序列 |
| `AsyncStream` | 将基于回调的代码桥接到异步序列的方法 |
| `withCheckedContinuation` | 将完成处理程序桥接到 async/await |
| `Task.isCancelled` | 检查当前任务是否被取消 |
| `@preconcurrency` | 为遗留代码抑制并发警告 |
| `GlobalActor` | 用于创建自己的自定义 actor(如 MainActor)的协议 |

### 何时使用每个

#### nonisolated - 读取计算属性

<div class="analogy">
就像你办公室门上的名牌 - 任何路过的人都可以阅读它,而不需要进来等你。
</div>

默认情况下,actor 内部的所有东西都是隔离的 - 你需要 `await` 来访问它。但有时你有本质上安全读取的属性:不可变的 `let` 常量,或只从其他安全数据派生值的计算属性。标记这些为 `nonisolated` 让调用者同步访问它们,避免不必要的异步开销。

<div class="isolation-legend">
  <span class="isolation-legend-item actor">Actor 隔离</span>
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
    let userId: String  // 不可变,安全读取
    var lastActivity: Date  // 可变,需要保护

    // 这可以在没有 await 的情况下调用
    nonisolated var displayId: String {
        "User: \(userId)"  // 只读取不可变数据
    }
}
```

</div>

```swift
// 用法
let session = UserSession(userId: "123")
print(session.displayId)  // 不需要 await!
```

#### @Sendable - 跨边界的闭包

<div class="analogy">
就像一个密封的信封,里面有指令 - 信封可以在办公室之间传递,打开它的人可以安全地遵循指令。
</div>

当闭包逃逸以便稍后运行或在不同的隔离域上运行时,Swift 需要保证它不会导致数据竞争。`@Sendable` 属性标记可以安全地跨边界传递的闭包 - 它们不能不安全地捕获可变状态。Swift 经常自动推断这一点(如 `Task.detached`),但有时在设计接受闭包的 API 时你需要明确声明它。

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // 这个闭包从分离的任务跨越到 MainActor
            // 它必须是 @Sendable(Swift 推断这个)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// 需要时的显式 @Sendable
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - 桥接旧 API

<div class="analogy">
就像旧纸质备忘录系统和现代电子邮件之间的翻译器。你在收发室等待,直到旧系统发送响应,然后通过新系统转发它。
</div>

许多旧 API 使用完成处理程序而不是 async/await。你可以使用 `withCheckedContinuation` 包装它们,而不是完全重写它们。这个函数挂起当前任务,给你一个 continuation 对象,并在你调用 `continuation.resume()` 时恢复。"checked" 变体捕获编程错误,如恢复两次或从不恢复。

<div class="isolation-legend">
  <span class="isolation-legend-item main">异步上下文</span>
  <span class="isolation-legend-item nonisolated">回调上下文</span>
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
// 旧的基于回调的 API
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... 带回调的网络调用
}

// 包装为 async
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // 桥接回来!
        }
    }
}
```

</div>

对于抛出函数,使用 `withCheckedThrowingContinuation`:

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

#### AsyncStream - 桥接事件源

<div class="analogy">
就像设置邮件转发 - 每次有信件到达旧地址,它就会自动路由到你的新收件箱。只要邮件不断到来,流就会继续流动。
</div>

虽然 `withCheckedContinuation` 处理一次性回调,许多 API 随时间传递多个值 - 委托方法、NotificationCenter 或自定义事件系统。`AsyncStream` 将这些桥接到 Swift 的 `AsyncSequence`,让你使用 `for await` 循环。你创建一个流,存储它的 continuation,并在每次新值到达时调用 `yield()`。

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

#### Task.isCancelled - 协作取消

<div class="analogy">
就像在开始大项目的每个步骤之前检查收件箱是否有"停止处理这个"的备忘录。你不会被强制停止 - 你选择检查并礼貌地响应。
</div>

Swift 使用协作取消 - 当任务被取消时,它不会立即停止。相反,设置一个标志,你有责任定期检查它。这让你可以控制清理和部分结果。使用 `Task.checkCancellation()` 立即抛出,或在你想优雅地处理取消时检查 `Task.isCancelled`(如返回部分结果)。

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // 在每个昂贵的操作之前检查
        try Task.checkCancellation()  // 如果被取消则抛出

        // 或者不抛出地检查
        if Task.isCancelled {
            return results  // 返回部分结果
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - 逃离当前上下文

<div class="analogy">
就像雇用一个不向你的部门汇报的外部承包商。他们独立工作,不遵循你办公室的规则,当你需要结果时你必须明确协调。
</div>

常规的 `Task { }` 继承当前的 actor 上下文 - 如果你在 `@MainActor` 上,任务在 `@MainActor` 上运行。有时这不是你想要的,特别是对于会阻塞 UI 的 CPU 密集型工作。`Task.detached` 创建一个没有继承上下文的任务,在后台执行器上运行。谨慎使用 - 大多数时候,具有适当 `await` 点的常规 `Task` 就足够了,也更容易推理。

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
        // 不要:这仍然继承 MainActor 上下文
        Task {
            let filtered = applyFilters(image)  // 阻塞主线程!
        }

        // 要:分离的任务独立运行
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
<h4>Task.detached 通常是错误的</h4>

大多数时候,你想要常规的 `Task`。分离的任务不继承优先级、任务本地值或 actor 上下文。只在你明确需要这种分离时使用它们。
</div>

#### @preconcurrency - 与遗留代码共存

抑制导入尚未更新并发的模块时的警告:

```swift
// 抑制此导入的警告
@preconcurrency import OldFramework

// 或在协议遵从上
class MyDelegate: @preconcurrency SomeOldDelegate {
    // 不会警告 non-Sendable 要求
}
```

<div class="tip">
<h4>@preconcurrency 是临时的</h4>

在更新代码时将其用作桥梁。目标是最终删除它并具有适当的 Sendable 遵从性。
</div>

## 进一步阅读

本指南提炼了关于 Swift 并发的最佳资源。

<div class="resources">
<h4>Matt Massicotte 的博客(强烈推荐)</h4>

- [Swift 并发术语表](https://www.massicotte.org/concurrency-glossary) - 基本术语
- [隔离简介](https://www.massicotte.org/intro-to-isolation/) - 核心概念
- [何时应该使用 actor?](https://www.massicotte.org/actors/) - 实用指导
- [Non-Sendable 类型也很酷](https://www.massicotte.org/non-sendable/) - 为什么更简单更好
- [跨越边界](https://www.massicotte.org/crossing-the-boundary/) - 使用 non-Sendable 类型
- [有问题的 Swift 并发模式](https://www.massicotte.org/problematic-patterns/) - 要避免什么
- [Swift 并发的错误](https://www.massicotte.org/mistakes-with-concurrency/) - 从错误中学习
</div>

<div class="resources">
<h4>官方 Apple 资源</h4>

- [Swift 并发文档](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: 认识 async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: 用 actor 保护可变状态](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: 消除数据竞争](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>教程</h4>

- [Swift 并发实例 - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Swift 中的 Async await - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

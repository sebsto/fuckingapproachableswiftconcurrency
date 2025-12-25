---
layout: base.njk
title: クソ分かりやすい Swift 並行処理
description: Swift 並行処理の嘘偽りないガイド。シンプルなメンタルモデルで async/await、actors、Sendable、MainActor を学ぼう。専門用語なし、明確な説明だけ。
lang: ja
dir: ltr
nav:
  isolation: 分離
  domains: ドメイン
  patterns: パターン
  errors: エラー
footer:
  madeWith: フラストレーションと愛を込めて作りました。Swift の並行処理が難しい必要はないから。
  viewOnGitHub: GitHub で見る
---

<section class="hero">
  <div class="container">
    <h1>クソ分かりやすい<br><span class="accent">Swift 並行処理</span></h1>
    <p class="subtitle">async/await、actors、Sendable を遂に理解しよう。明確なメンタルモデル、専門用語なし。</p>
    <p class="credit"><a href="https://www.massicotte.org/">Matt Massicotte</a> 氏に多大な感謝を。Swift 並行処理を理解可能にしてくれました。<a href="https://pepicrft.me">Pedro Piñera</a> がまとめました。問題を発見しましたか? <a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute"><a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a> と <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a> の伝統を受け継いで</p>
    <p class="cta-tuist"><a href="https://tuist.dev">Tuist</a> で開発をスケールアップ</p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## 正直な真実

Swift 並行処理にチートシートはありません。「こうすればいい」という答えは、どんな文脈でも間違っています。

**でも良いニュースがあります:**[分離](#basics)を理解すれば(5分で読めます)、すべてが理解できます。コンパイラエラーが意味を成し始めます。システムと戦うのをやめ、システムと協力できるようになります。

*このガイドは Swift 6+ を対象としています。ほとんどの概念は Swift 5.5+ にも適用されますが、Swift 6 はより厳格な並行処理チェックを強制します。*

<a href="#basics" class="read-more">メンタルモデルから始める &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## 理解すべきただ一つのこと

**[分離](https://www.massicotte.org/intro-to-isolation/)** がすべての鍵です。これは Swift の「今、誰がこのデータに触れることを許可されているか?」という質問への答えです。

<div class="analogy">
<h4>オフィスビル</h4>

あなたのアプリを**オフィスビル**だと考えてください。各オフィスは**分離ドメイン** - 一度に一人しか作業できないプライベート空間です。他人のオフィスに勝手に入って机を動かすことはできません。

このガイド全体を通じて、この比喩を使って説明していきます。
</div>

### なぜスレッドだけではダメなのか?

何十年もの間、私たちはスレッドについて考えることで並行処理コードを書いてきました。問題は?**スレッドは自分で自分の足を撃つことを防げません。**二つのスレッドが同じデータに同時にアクセスでき、データレース - ランダムにクラッシュし、ほぼ再現不可能なバグ - を引き起こします。

スマホでは、なんとかなるかもしれません。しかし、何千もの並行リクエストを処理するサーバーでは、データレースは確実に発生します - 通常は本番環境で、金曜日に。Swift がサーバーやその他の高度に並行処理が必要な環境に拡大するにつれて、「うまくいくことを願う」だけでは通用しません。

従来のアプローチは防御的でした: ロックを使い、ディスパッチキューを使い、見落としがないことを願う。

Swift のアプローチは異なります:**コンパイル時にデータレースを不可能にする。**「これはどのスレッド上にあるか?」ではなく、Swift は「今、誰がこのデータに触れることを許可されているか?」と尋ねます。それが分離です。

### 他の言語はこれをどう扱うか

| 言語 | アプローチ | バグに気づくタイミング |
|----------|----------|------------------------------|
| **Swift** | 分離 + Sendable | コンパイル時 |
| **Rust** | 所有権 + borrow checker | コンパイル時 |
| **Kotlin** | コルーチン + 構造化並行性 | 部分的にコンパイル時 |
| **Go** | チャネル + race detector | 実行時 (ツールあり) |
| **Java** | `synchronized`、ロック | 実行時 (クラッシュ) |
| **JavaScript** | シングルスレッドイベントループ | 完全に回避 |
| **C/C++** | 手動ロック | 実行時 (未定義動作) |

Swift と Rust は、データレースに対して最も強力なコンパイル時保証を提供します。Kotlin コルーチンは Swift の async/await に似た構造化並行性を提供しますが、スレッドセーフティに対する型システムレベルの強制力は同等ではありません。トレードオフは?最初の学習曲線が急です。しかし、モデルを理解すれば、コンパイラがサポートしてくれます。

`Sendable` やアクター分離についてのあの煩わしいエラー? それらは、以前はサイレントクラッシュになっていたバグを捕まえています。

  </div>
</section>

<section id="domains">
  <div class="container">

## 分離ドメイン

分離(プライベートオフィス)を理解したので、Swift のビルにある異なるタイプのオフィスを見てみましょう。

<div class="analogy">
<h4>オフィスビル</h4>

- **受付** (`MainActor`) - すべての顧客とのやり取りが行われる場所。一つしかなく、ユーザーが見るすべてを処理します。
- **部署オフィス** (`actor`) - 経理、法務、人事。各部署には独自のオフィスがあり、独自の機密データを保護しています。
- **廊下と共有スペース** (`nonisolated`) - 誰でも通れる共有スペース。ここにはプライベートデータはありません。
</div>

### MainActor: 受付

`MainActor` はメインスレッド上で実行される特別な分離ドメインです。すべての UI 作業はここで行われます。

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // UI の状態はここに置く

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // 安全 - MainActor 上にいる
    }
}
```

<div class="tip">
<h4>迷ったら MainActor を使う</h4>

ほとんどのアプリでは、ViewModel や UI 関連のクラスに `@MainActor` をマークするのが正しい選択です。パフォーマンスの懸念は通常大げさです - ここから始めて、実際に問題を測定した場合のみ最適化してください。
</div>

### Actors: 部署オフィス

`actor` は部署オフィスのようなものです - 独自のデータを保護し、一度に一人の訪問者しか許可しません。

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // 安全! 一度に一人の呼び出し者のみ
    }
}
```

アクターなしでは、二つのスレッドが balance = 100 を読み取り、両方が 50 を追加し、両方が 150 を書き込みます - 50ドル失いました。アクターがあれば、Swift は自動的にアクセスをキューイングし、両方の預金が正しく完了します。

<div class="warning">
<h4>アクターを使いすぎない</h4>

カスタムアクターが必要なのは、**以下の4つすべて**が真の場合のみです:
1. Sendable でない(スレッドセーフでない)可変状態がある
2. 複数の場所がアクセスする必要がある
3. その状態の操作はアトミックでなければならない
4. MainActor 上に置けない

どれか一つでも偽なら、おそらくアクターは必要ありません。ほとんどの UI 状態は `@MainActor` 上に置けます。[アクターをいつ使うかについて詳しく読む](https://www.massicotte.org/actors/)。
</div>

### Nonisolated: 廊下

`nonisolated` とマークされたコードは廊下のようなものです - どのオフィスにも属さず、どこからでもアクセスできます。

```swift
actor UserSession {
    let userId: String          // 不変 - どこからでも安全に読める
    var lastActivity: Date      // 可変 - アクター保護が必要

    nonisolated var displayId: String {
        "User: \(userId)"       // 不変データのみ読み取る
    }
}

// 使い方 - nonisolated には await 不要
let session = UserSession(userId: "123")
print(session.displayId)  // 同期的に動作!
```

不変データのみを読み取る計算プロパティには `nonisolated` を使います。

  </div>
</section>

<section id="propagation">
  <div class="container">

## 分離の伝播方法

型をアクター分離でマークすると、そのメソッドはどうなるでしょうか? クロージャは? 分離がどのように広がるかを理解することが、驚きを避ける鍵です。

<div class="analogy">
<h4>オフィスビル</h4>

ある部署に雇われると、デフォルトでその部署のオフィスで働きます。マーケティング部門に雇われたら、会計部門にランダムに現れることはありません。

同様に、関数が `@MainActor` クラス内で定義されると、その分離を継承します。親と「同じオフィスで働く」のです。
</div>

### クラスは分離を継承する

```swift
@MainActor
class ViewModel {
    var count = 0           // MainActor に分離

    func increment() {      // これも MainActor に分離
        count += 1
    }
}
```

クラス内のすべてが `@MainActor` を継承します。各メソッドをマークする必要はありません。

### タスクはコンテキストを継承する(通常は)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // これは MainActor を継承!
            self.updateUI()  // 安全、await 不要
        }
    }
}
```

`@MainActor` コンテキストから作成された `Task { }` は MainActor 上にとどまります。これは通常望ましい動作です。

### Task.detached は継承を断ち切る

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // もう MainActor 上ではない!
            await self.updateUI()  // 今は await が必要
        }
    }
}
```

<div class="analogy">
<h4>オフィスビル</h4>

`Task.detached` は外部の請負業者を雇うようなものです。彼らはあなたのオフィスへのバッジを持っていません - 自分のスペースで働き、あなたのものにアクセスするには適切なチャネルを通さなければなりません。
</div>

<div class="warning">
<h4>Task.detached は通常間違い</h4>

ほとんどの場合、通常の `Task` が必要です。デタッチされたタスクは優先度、タスクローカル値、アクターコンテキストを継承しません。明示的にその分離が必要な場合のみ使用してください。
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## 境界を越えられるもの

分離ドメイン(オフィス)とその伝播方法を知ったので、次の質問は:**それらの間で何を渡せるか?**

<div class="analogy">
<h4>オフィスビル</h4>

すべてがオフィスを出られるわけではありません:

- **コピー**は共有しても安全 - 法務部門が文書のコピーを作って会計部門に送れば、両方が独自のコピーを持ちます。衝突はありません。
- **署名入りの原本契約**はその場にとどまる必要があります - 二つの部署が両方とも原本を変更できたら、混乱が生じます。

Swift の用語では:**Sendable** 型はコピー(共有しても安全)、**非 Sendable** 型は原本(一つのオフィスにとどまる必要がある)です。
</div>

### Sendable: 共有しても安全

これらの型は分離境界を安全に越えられます:

```swift
// 不変データを持つ構造体 - コピーのようなもの
struct User: Sendable {
    let id: Int
    let name: String
}

// アクターは自分自身を保護する - 自分の訪問者を処理する
actor BankAccount { }  // 自動的に Sendable
```

**自動的に Sendable:**
- Sendable プロパティを持つ値型(構造体、列挙型)
- アクター(自分自身を保護する)
- 不変クラス(`final class` で `let` プロパティのみ)

### 非 Sendable: その場にとどまる必要がある

これらの型は境界を安全に越えられません:

```swift
// 可変状態を持つクラス - 原本文書のようなもの
class Counter {
    var count = 0  // 二つのオフィスがこれを変更 = 災難
}
```

**なぜこれが重要な区別か?** なぜなら、遭遇するすべてのコンパイラエラーは、*「非 Sendable 型を分離境界を越えて送ろうとしています」*ということに帰着するからです。

### コンパイラが文句を言うとき

Swift が何かが Sendable でないと言う場合、オプションがあります:

1. **値型にする** - `class` の代わりに `struct` を使う
2. **分離する** - `@MainActor` 上に保持して越える必要をなくす
3. **非 Sendable のままにする** - オフィス間で渡さないだけ
4. **最後の手段:** `@unchecked Sendable` - 安全だと約束する(注意して)

<div class="tip">
<h4>非 Sendable から始める</h4>

[Matt Massicotte は提唱しています](https://www.massicotte.org/non-sendable/)通常の非 Sendable 型から始めることを。境界を越える必要がある場合のみ `Sendable` を追加します。非 Sendable 型はシンプルで、準拠の頭痛を避けられます。
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## 境界を越える方法

分離ドメインを理解し、何がそれらを越えられるかを知っています。では:**オフィス間で実際にどうやって通信するか?**

<div class="analogy">
<h4>オフィスビル</h4>

他のオフィスに勝手に入ることはできません。リクエストを送って応答を待ちます。待っている間に他のことをするかもしれませんが、続けるにはその応答が必要です。

それが `async/await` です - 別の分離ドメインにリクエストを送り、答えを得るまで一時停止します。
</div>

### await キーワード

別のアクター上の関数を呼び出すとき、`await` が必要です:

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
        await store.add(item)  // 別のオフィスへのリクエスト
        updateUI()             // 自分のオフィスに戻る
    }
}
```

`await` は:「このリクエストを送って完了まで一時停止。待っている間に他の仕事をするかもしれません。」という意味です。

### 中断、ブロックではない

<div class="warning">
<h4>よくある誤解</h4>

多くの開発者は `async` を追加すればコードがバックグラウンドで実行されると思い込んでいます。そうではありません。`async` キーワードは単に関数が*一時停止できる*ことを意味します。*どこで*実行されるかについては何も言っていません。
</div>

重要な洞察は**ブロック**と**中断**の違いです:

- **ブロック**: 待合室で壁を見つめて座っています。他には何も起こりません。
- **中断**: 電話番号を残して用事を済ませます。準備ができたら電話をくれます。

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">ブロック</button>
<button>中断</button>
</div>
<div class="code-tab-content active">

```swift
// スレッドは何もせずに5秒間待機
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// スレッドは待っている間に他の仕事をするために解放される
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### 同期コードから非同期作業を開始する

時々、同期コードにいて非同期を呼び出す必要があります。`Task` を使います:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // 同期関数
        Task {
            await loadData()  // 今は await を使える
        }
    }
}
```

<div class="analogy">
<h4>オフィスビル</h4>

`Task` は従業員に仕事を割り当てるようなものです。従業員がリクエストを処理し(他のオフィスを待つことを含む)、あなたは目の前の仕事を続けます。
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## うまくいくパターン

### ネットワークリクエストパターン

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (ネットワーク呼び出し)</span>
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

        // これは中断 - スレッドは他の仕事をするために解放される
        let users = await networkService.getUsers()

        // 自動的に MainActor に戻る
        self.users = users
        isLoading = false
    }
}
```

</div>

`DispatchQueue.main.async` は不要です。`@MainActor` 属性が処理します。

### async let による並列作業

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // 3つすべてが並列で実行!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### ダブルタップを防ぐ

このパターンは Matt Massicotte の[ステートフルシステム](https://www.massicotte.org/step-by-step-stateful-systems)ガイドからのものです:

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // 非同期作業の前に同期的にガード
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
<h4>重要: ガードは同期的でなければならない</h4>

ガードを await の後の Task 内に置くと、二つのボタンタップが両方とも作業を開始できるウィンドウがあります。[順序と並行処理について詳しく学ぶ](https://www.massicotte.org/ordering-and-concurrency)。
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## 避けるべき一般的な間違い

これらは経験豊富な開発者でも犯す[一般的な間違い](https://www.massicotte.org/mistakes-with-concurrency/)です:

### async = バックグラウンドと考える

<div class="analogy">
<h4>オフィスビル</h4>

`async` を追加しても別のオフィスに移動しません。まだ受付にいます - 今は凍結せずに配達を待てるだけです。
</div>

```swift
// これはまだメインスレッドをブロック!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // 同期 = ブロック
    data = result
}
```

別のオフィスで作業が必要な場合は、明示的にそこに送ります:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // 今は別のオフィスにいる
    }.value
    await MainActor.run { data = result }
}
```

### アクターを作りすぎる

<div class="analogy">
<h4>オフィスビル</h4>

すべてのデータに新しいオフィスを作ると、それらの間で通信するために終わりのない事務作業が発生します。ほとんどの仕事は受付で行えます。
</div>

```swift
// 過剰設計 - すべての呼び出しがオフィス間を歩く必要がある
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// より良い - ほとんどのものは受付に置ける
@MainActor
class AppState { }
```

### MainActor.run をどこでも使う

<div class="analogy">
<h4>オフィスビル</h4>

すべての小さなことのために受付に歩いているなら、そこで働きましょう。常に用事を繰り返すのではなく、職務記述書の一部にしてください。
</div>

```swift
// これをしない - 常に受付に歩く
await MainActor.run { doMainActorStuff() }

// これをする - 受付で働く
@MainActor func doMainActorStuff() { }
```

### すべてを Sendable にする

すべてが `Sendable` である必要はありません。どこでも `@unchecked Sendable` を追加しているなら、オフィスを出る必要のないもののコピーを作っています。

### コンパイラ警告を無視する

`Sendable` についてのすべてのコンパイラ警告は、セキュリティガードが何かをオフィス間で運ぶのが安全でないと伝えているのです。無視せず - [理解しましょう](https://www.massicotte.org/complete-checking/)。

  </div>
</section>

<section id="errors">
  <div class="container">

## 一般的なコンパイラエラー

これらは実際に見るエラーメッセージです。それぞれがコンパイラがデータレースからあなたを守っています。

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>オフィスビル</h4>

原本文書を別のオフィスに運ぼうとしています。コピーを作る(Sendable)か、一か所に保持してください。
</div>

**修正 1:** `class` の代わりに `struct` を使う

**修正 2:** 一つのアクターに保持する:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // 受付にとどまる
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>オフィスビル</h4>

オフィス間で原本を運ぼうとしています。セキュリティガードが止めました。
</div>

**修正 1:** 構造体にする:

```swift
// 前: class (非 Sendable)
class User { var name: String }

// 後: struct (Sendable)
struct User: Sendable { let name: String }
```

**修正 2:** 一つのアクターに分離する:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>オフィスビル</h4>

適切なチャネルを通さずに、別のオフィスのファイルキャビネットに手を伸ばしています。
</div>

**修正:** `await` を使う:

```swift
// 間違い - 直接手を伸ばす
let value = myActor.balance

// 正しい - 適切なリクエスト
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>オフィスビル</h4>

列に並ばずに受付を使おうとしています。
</div>

**修正 1:** 呼び出し元を `@MainActor` にする:

```swift
@MainActor
func doSomething() {
    updateUI()  // 同じ分離、await 不要
}
```

**修正 2:** `await` を使う:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## Swift 並行処理の3つのレベル

すべてを一度に学ぶ必要はありません。これらのレベルを進んでください:

<div class="analogy">
<h4>オフィスビル</h4>

会社を成長させることと考えてください。50階建ての本社から始めません - 机から始めます。
</div>

これらのレベルは厳密な境界ではありません - アプリの異なる部分が異なるレベルを必要とするかもしれません。ほぼレベル1のアプリが、レベル2のパターンが必要な1つの機能を持つかもしれません。それで構いません。各部分に最もシンプルなアプローチを使ってください。

### レベル 1: スタートアップ

全員が受付で働きます。シンプル、直接的、官僚主義なし。

- ネットワーク呼び出しに `async/await` を使う
- UI クラスに `@MainActor` をマークする
- SwiftUI の `.task` モディファイアを使う

これは 80% のアプリを扱います。[Things](https://culturedcode.com/things/)、[Bear](https://bear.app/)、[Flighty](https://flighty.com/)、[Day One](https://dayoneapp.com/) のようなアプリはおそらくこのカテゴリーに入ります - 主にデータを取得して表示するアプリです。

### レベル 2: 成長する会社

複数のことを同時に処理する必要があります。並列プロジェクトとチームの調整が必要です。

- 並列作業に `async let` を使う
- 動的並列処理に `TaskGroup` を使う
- タスクキャンセルを理解する

[Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp)(複数のタイムラインとストリーミング更新を管理する Mastodon クライアント)、[Overcast](https://overcast.fm/)(ダウンロード、再生、バックグラウンド同期を調整)、[Slack](https://slack.com/)(複数チャネルでのリアルタイムメッセージング)のようなアプリは、特定の機能でこれらのパターンを使うかもしれません。

### レベル 3: エンタープライズ

独自のポリシーを持つ専門部署。複雑なオフィス間通信。

- 共有状態のためのカスタムアクターを作成
- Sendable の深い理解
- カスタムエグゼキュータ

[Xcode](https://developer.apple.com/xcode/)、[Final Cut Pro](https://www.apple.com/final-cut-pro/)、[Vapor](https://vapor.codes/) や [Hummingbird](https://hummingbird.codes/) のようなサーバーサイド Swift フレームワークはおそらくこれらのパターンが必要です - 複雑な共有状態、何千もの並行接続、他の人が構築するフレームワークレベルのコードです。

<div class="tip">
<h4>シンプルに始める</h4>

ほとんどのアプリはレベル3を必要としません。スタートアップで済むときにエンタープライズを構築しないでください。
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## 用語集: 遭遇するその他のキーワード

コアコンセプトの他に、野生で見る Swift 並行処理のキーワードがあります:

| キーワード | 意味 |
|---------|---------------|
| `nonisolated` | アクターの分離をオプトアウト - 保護なしで実行 |
| `isolated` | パラメータがアクターのコンテキストで実行することを明示的に宣言 |
| `@Sendable` | クロージャが分離境界を越えて渡しても安全であることをマーク |
| `Task.detached` | 現在のコンテキストから完全に分離したタスクを作成 |
| `AsyncSequence` | `for await` で反復できるシーケンス |
| `AsyncStream` | コールバックベースのコードを async シーケンスにブリッジする方法 |
| `withCheckedContinuation` | 完了ハンドラを async/await にブリッジ |
| `Task.isCancelled` | 現在のタスクがキャンセルされたかチェック |
| `@preconcurrency` | レガシーコードの並行処理警告を抑制 |
| `GlobalActor` | MainActor のような独自のカスタムアクターを作成するプロトコル |

### それぞれをいつ使うか

#### nonisolated - 計算プロパティの読み取り

<div class="analogy">
オフィスのドアにある名札のようなもの - 通りがかりの人は誰でも、中に入ってあなたを待つ必要なく読めます。
</div>

デフォルトでは、アクター内のすべてが分離されています - アクセスするには `await` が必要です。しかし、本質的に読み取りが安全なプロパティがあることがあります: 不変の `let` 定数、または他の安全なデータから値を導出するだけの計算プロパティ。これらを `nonisolated` でマークすると、呼び出し元が同期的にアクセスでき、不要な非同期オーバーヘッドを避けられます。

<div class="isolation-legend">
  <span class="isolation-legend-item actor">アクターに分離</span>
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
    let userId: String  // 不変、読み取りが安全
    var lastActivity: Date  // 可変、保護が必要

    // これは await なしで呼び出せる
    nonisolated var displayId: String {
        "User: \(userId)"  // 不変データのみを読み取る
    }
}
```

</div>

```swift
// 使い方
let session = UserSession(userId: "123")
print(session.displayId)  // await 不要!
```

#### @Sendable - 境界を越えるクロージャ

<div class="analogy">
内部に指示が入った封印された封筒のようなもの - 封筒はオフィス間を移動でき、誰でも開いて安全に指示に従えます。
</div>

クロージャが後で実行されるためにエスケープするか、異なる分離ドメインで実行される場合、Swift はデータレースを引き起こさないことを保証する必要があります。`@Sendable` 属性は境界を越えて渡しても安全なクロージャをマークします - 可変状態を安全でない方法でキャプチャできません。Swift はこれを自動的に推論することが多いですが(`Task.detached` のように)、クロージャを受け入れる API を設計するときに明示的に宣言する必要があることがあります。

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // このクロージャはデタッチされたタスクから MainActor に越える
            // @Sendable でなければならない (Swift はこれを推論)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// 必要に応じて明示的な @Sendable
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - 古い API のブリッジ

<div class="analogy">
古い紙のメモシステムと現代の電子メールの間の翻訳者のようなもの。古いシステムが応答を配信するまで郵便室で待ち、新しいシステムを通じて転送します。
</div>

多くの古い API は async/await の代わりに完了ハンドラを使います。完全に書き直すのではなく、`withCheckedContinuation` を使ってラップできます。この関数は現在のタスクを中断し、continuation オブジェクトを渡し、`continuation.resume()` を呼び出したときに再開します。「checked」バリアントは、2回再開したり、決して再開しないなどのプログラミングエラーを捕まえます。

<div class="isolation-legend">
  <span class="isolation-legend-item main">Async コンテキスト</span>
  <span class="isolation-legend-item nonisolated">コールバックコンテキスト</span>
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
// 古いコールバックベース API
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... コールバック付きネットワーク呼び出し
}

// async としてラップ
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // ブリッジバック!
        }
    }
}
```

</div>

スロー関数には `withCheckedThrowingContinuation` を使います:

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

#### AsyncStream - イベントソースのブリッジ

<div class="analogy">
メール転送を設定するようなもの - 古い住所に手紙が届くたびに、自動的に新しい受信箱にルーティングされます。メールが来続ける限りストリームは流れ続けます。
</div>

`withCheckedContinuation` がワンショットコールバックを処理する一方、多くの API は時間をかけて複数の値を配信します - デリゲートメソッド、NotificationCenter、カスタムイベントシステム。`AsyncStream` はこれらを Swift の `AsyncSequence` にブリッジし、`for await` ループを使えるようにします。ストリームを作成し、その continuation を保存し、新しい値が到着するたびに `yield()` を呼び出します。

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

// 使い方
let tracker = LocationTracker()
for await location in tracker.locations {
    print("新しい位置: \(location)")
}
```

#### Task.isCancelled - 協調的キャンセル

<div class="analogy">
大きなプロジェクトの各ステップを開始する前に、「これに取り組むのをやめて」というメモがないか受信箱をチェックするようなもの。強制的に停止させられるのではなく - チェックして礼儀正しく応答することを選びます。
</div>

Swift は協調的キャンセルを使います - タスクがキャンセルされても、すぐには停止しません。代わりに、フラグが設定され、定期的にチェックする責任があります。これにより、クリーンアップと部分的な結果の制御が可能になります。すぐにスローするには `Task.checkCancellation()` を使い、キャンセルを優雅に処理したい(部分的な結果を返すなど)場合は `Task.isCancelled` をチェックします。

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // 各高コスト操作の前にチェック
        try Task.checkCancellation()  // キャンセルされていればスロー

        // またはスローせずにチェック
        if Task.isCancelled {
            return results  // 部分的な結果を返す
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - 現在のコンテキストからのエスケープ

<div class="analogy">
あなたの部署に報告しない外部請負業者を雇うようなもの。彼らは独立して働き、あなたのオフィスのルールに従わず、結果が必要なときに明示的に調整する必要があります。
</div>

通常の `Task { }` は現在のアクターコンテキストを継承します - `@MainActor` 上にいる場合、タスクは `@MainActor` 上で実行されます。時々それは望ましくありません、特に UI をブロックする CPU 集約的な作業の場合。`Task.detached` は継承されたコンテキストなしでタスクを作成し、バックグラウンドエグゼキュータで実行します。ただし、控えめに使用してください - ほとんどの場合、適切な `await` ポイントを持つ通常の `Task` で十分で、推論しやすいです。

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
        // ダメ: これはまだ MainActor コンテキストを継承
        Task {
            let filtered = applyFilters(image)  // メインをブロック!
        }

        // 良い: デタッチされたタスクは独立して実行
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
<h4>Task.detached は通常間違い</h4>

ほとんどの場合、通常の `Task` が必要です。デタッチされたタスクは優先度、タスクローカル値、アクターコンテキストを継承しません。明示的にその分離が必要な場合のみ使用してください。
</div>

#### @preconcurrency - レガシーコードとの共存

並行処理のために更新されていないモジュールをインポートするときに警告を抑制します:

```swift
// このインポートからの警告を抑制
@preconcurrency import OldFramework

// またはプロトコル準拠で
class MyDelegate: @preconcurrency SomeOldDelegate {
    // 非 Sendable 要件について警告しない
}
```

<div class="tip">
<h4>@preconcurrency は一時的なもの</h4>

コードを更新している間のブリッジとして使用してください。目標は最終的にそれを削除し、適切な Sendable 準拠を持つことです。
</div>

## さらなる読み物

このガイドは Swift 並行処理に関する最高のリソースを凝縮しています。

<div class="resources">
<h4>Matt Massicotte のブログ(強く推奨)</h4>

- [A Swift Concurrency Glossary](https://www.massicotte.org/concurrency-glossary) - 必須の用語集
- [An Introduction to Isolation](https://www.massicotte.org/intro-to-isolation/) - コアコンセプト
- [When should you use an actor?](https://www.massicotte.org/actors/) - 実用的なガイダンス
- [Non-Sendable types are cool too](https://www.massicotte.org/non-sendable/) - なぜシンプルが良いか
- [Crossing the Boundary](https://www.massicotte.org/crossing-the-boundary/) - 非 Sendable 型との作業
- [Problematic Swift Concurrency Patterns](https://www.massicotte.org/problematic-patterns/) - 避けるべきこと
- [Making Mistakes with Swift Concurrency](https://www.massicotte.org/mistakes-with-concurrency/) - エラーから学ぶ
</div>

<div class="resources">
<h4>公式 Apple リソース</h4>

- [Swift 並行処理ドキュメント](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: Meet async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Protect mutable state with actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>チュートリアル</h4>

- [Swift Concurrency by Example - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Async await in Swift - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

---
layout: base.njk
title: Чертовски понятный Swift Concurrency
description: Честное руководство по конкурентности в Swift. Изучите async/await, actors, Sendable и MainActor с простыми ментальными моделями. Без жаргона, только понятные объяснения.
lang: ru
dir: ltr
nav:
  isolation: Изоляция
  domains: Домены
  patterns: Паттерны
  errors: Ошибки
footer:
  madeWith: Сделано с разочарованием и любовью. Потому что конкурентность Swift не должна быть запутанной.
  viewOnGitHub: Смотреть на GitHub
---

<section class="hero">
  <div class="container">
    <h1>Чертовски понятный<br><span class="accent">Swift Concurrency</span></h1>
    <p class="subtitle">Наконец-то поймите async/await, actors и Sendable. Ясные ментальные модели, никакого жаргона.</p>
    <p class="credit">Огромная благодарность <a href="https://www.massicotte.org/">Matt Massicotte</a> за то, что сделал конкурентность Swift понятной. Составлено <a href="https://pepicrft.me">Pedro Piñera</a>. Нашли ошибку? <a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute">В традициях <a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a> и <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a></p>
    <p class="cta-tuist">Масштабируйте разработку с <a href="https://tuist.dev">Tuist</a></p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## Честная правда

Шпаргалки для конкурентности Swift не существует. Каждый ответ "просто сделай X" неверен в каком-то контексте.

**Но вот хорошая новость:** Как только вы поймёте [изоляцию](#basics) (5 минут чтения), всё встанет на свои места. Ошибки компилятора начнут иметь смысл. Вы перестанете бороться с системой и начнёте работать с ней.

*Это руководство рассчитано на Swift 6+. Большинство концепций применимы к Swift 5.5+, но Swift 6 обеспечивает более строгую проверку конкурентности.*

<a href="#basics" class="read-more">Начните с ментальной модели &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## Единственное, что вам нужно понять

**[Изоляция](https://www.massicotte.org/intro-to-isolation/)** - ключ ко всему. Это ответ Swift на вопрос: *Кому разрешено трогать эти данные прямо сейчас?*

<div class="analogy">
<h4>Офисное здание</h4>

Представьте ваше приложение как **офисное здание**. Каждый офис - это **домен изоляции** - приватное пространство, где одновременно может работать только один человек. Вы не можете просто ворваться в чужой офис и начать переставлять вещи на его столе.

Мы будем развивать эту аналогию на протяжении всего руководства.
</div>

### Почему недостаточно просто потоков?

Десятилетиями мы писали конкурентный код, думая о потоках. Проблема? **Потоки не защищают вас от выстрела себе в ногу.** Два потока могут одновременно обращаться к одним и тем же данным, вызывая гонки данных - баги, которые падают случайным образом и почти невозможно воспроизвести.

На телефоне вам может повезти. На сервере, обрабатывающем тысячи одновременных запросов, гонки данных становятся неизбежностью - обычно проявляясь в продакшене, в пятницу. По мере расширения Swift на серверы и другие высококонкурентные среды, "надеемся на лучшее" уже не работает.

Старый подход был оборонительным: используй блокировки, очереди dispatch, надейся, что ничего не упустил.

Подход Swift другой: **сделать гонки данных невозможными на этапе компиляции.** Вместо того чтобы спрашивать "на каком это потоке?", Swift спрашивает "кому разрешено трогать эти данные прямо сейчас?" Это и есть изоляция.

### Как другие языки решают эту проблему

| Язык | Подход | Когда вы узнаёте о багах |
|------|--------|--------------------------|
| **Swift** | Изоляция + Sendable | Время компиляции |
| **Rust** | Владение + borrow checker | Время компиляции |
| **Kotlin** | Корутины + структурированный параллелизм | Частично во время компиляции |
| **Go** | Каналы + детектор гонок | Время выполнения (с инструментами) |
| **Java** | `synchronized`, блокировки | Время выполнения (падения) |
| **JavaScript** | Однопоточный event loop | Проблема избегается полностью |
| **C/C++** | Ручные блокировки | Время выполнения (неопределённое поведение) |

Swift и Rust предоставляют самые строгие гарантии на этапе компиляции против гонок данных. Kotlin Coroutines предлагает структурированный параллелизм, похожий на async/await в Swift, но без такого же уровня контроля типов для потокобезопасности. Компромисс? Более крутая кривая обучения вначале. Но как только вы поймёте модель, компилятор на вашей стороне.

Те надоедливые ошибки о `Sendable` и изоляции акторов? Они ловят баги, которые раньше были бы тихими падениями.

  </div>
</section>

<section id="domains">
  <div class="container">

## Домены изоляции

Теперь, когда вы понимаете изоляцию (приватные офисы), давайте рассмотрим различные типы офисов в здании Swift.

<div class="analogy">
<h4>Офисное здание</h4>

- **Ресепшен** (`MainActor`) - где происходит всё взаимодействие с клиентами. Он один, и он обрабатывает всё, что видит пользователь.
- **Офисы отделов** (`actor`) - бухгалтерия, юридический, HR. У каждого отдела свой офис, защищающий собственные конфиденциальные данные.
- **Коридоры и общие зоны** (`nonisolated`) - общие пространства, через которые может пройти любой. Приватных данных здесь нет.
</div>

### MainActor: Ресепшен

`MainActor` - это специальный домен изоляции, который работает на главном потоке. Это место, где происходит вся работа с UI.

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // Состояние UI живёт здесь

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // Безопасно - мы на MainActor
    }
}
```

<div class="tip">
<h4>Если сомневаетесь - используйте MainActor</h4>

Для большинства приложений пометить ваши ViewModel и классы, связанные с UI, атрибутом `@MainActor` - правильный выбор. Беспокойства о производительности обычно преувеличены - начните здесь, оптимизируйте только если измерите реальные проблемы.
</div>

### Actors: Офисы отделов

`actor` - это как офис отдела - он защищает собственные данные и допускает только одного посетителя за раз.

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // Безопасно! Только один вызов за раз
    }
}
```

Без акторов два потока читают balance = 100, оба добавляют 50, оба записывают 150 - вы потеряли 50$. С акторами Swift автоматически выстраивает очередь доступа, и оба депозита завершаются корректно.

<div class="warning">
<h4>Не злоупотребляйте акторами</h4>

Вам нужен собственный актор только когда **все четыре** условия верны:
1. У вас есть не-Sendable (потоконебезопасное) изменяемое состояние
2. Несколько мест должны к нему обращаться
3. Операции над этим состоянием должны быть атомарными
4. Оно не может просто жить на MainActor

Если любое условие ложно, вам, вероятно, не нужен актор. Большая часть состояния UI может жить на `@MainActor`. [Подробнее о том, когда использовать акторы](https://www.massicotte.org/actors/).
</div>

### Nonisolated: Коридоры

Код, помеченный `nonisolated`, похож на коридоры - он не принадлежит ни одному офису и доступен откуда угодно.

```swift
actor UserSession {
    let userId: String          // Неизменяемый - безопасно читать откуда угодно
    var lastActivity: Date      // Изменяемый - нуждается в защите актора

    nonisolated var displayId: String {
        "User: \(userId)"       // Читает только неизменяемые данные
    }
}

// Использование - await не нужен для nonisolated
let session = UserSession(userId: "123")
print(session.displayId)  // Работает синхронно!
```

Используйте `nonisolated` для вычисляемых свойств, которые читают только неизменяемые данные.

  </div>
</section>

<section id="propagation">
  <div class="container">

## Как распространяется изоляция

Когда вы помечаете тип изоляцией актора, что происходит с его методами? А с замыканиями? Понимание того, как распространяется изоляция, - ключ к избежанию сюрпризов.

<div class="analogy">
<h4>Офисное здание</h4>

Когда вас нанимают в отдел, вы по умолчанию работаете в офисе этого отдела. Если отдел маркетинга нанимает вас, вы не появляетесь случайно в бухгалтерии.

Аналогично, когда функция определена внутри класса `@MainActor`, она наследует эту изоляцию. Она "работает в том же офисе", что и её родитель.
</div>

### Классы наследуют изоляцию

```swift
@MainActor
class ViewModel {
    var count = 0           // MainActor-изолирован

    func increment() {      // Тоже MainActor-изолирован
        count += 1
    }
}
```

Всё внутри класса наследует `@MainActor`. Вам не нужно помечать каждый метод.

### Tasks наследуют контекст (обычно)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // Это наследует MainActor!
            self.updateUI()  // Безопасно, await не нужен
        }
    }
}
```

`Task { }`, созданный из контекста `@MainActor`, остаётся на `MainActor`. Обычно это то, что вам нужно.

### Task.detached разрывает наследование

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // Больше НЕ на MainActor!
            await self.updateUI()  // Теперь нужен await
        }
    }
}
```

<div class="analogy">
<h4>Офисное здание</h4>

`Task.detached` - это как найм внешнего подрядчика. У него нет пропуска в ваш офис - он работает из своего пространства и должен проходить через формальные каналы для доступа к вашим вещам.
</div>

<div class="warning">
<h4>Task.detached обычно неправильный выбор</h4>

В большинстве случаев вам нужен обычный `Task`. Detached tasks не наследуют приоритет, task-local значения или контекст актора. Используйте их только когда вам явно нужно это разделение.
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## Что может пересекать границы

Теперь вы знаете о доменах изоляции (офисах) и о том, как они распространяются. Следующий вопрос: **что вы можете передавать между ними?**

<div class="analogy">
<h4>Офисное здание</h4>

Не всё может покинуть офис:

- **Копии** безопасно передавать - если юридический отдел делает копию документа и отправляет её в бухгалтерию, у обоих своя копия. Никакого конфликта.
- **Оригиналы подписанных контрактов** должны оставаться на месте - если два отдела могут одновременно изменять оригинал, наступает хаос.

На языке Swift: **Sendable** типы - это копии (безопасно передавать), **не-Sendable** типы - это оригиналы (должны оставаться в одном офисе).
</div>

### Sendable: Безопасно передавать

Эти типы могут безопасно пересекать границы изоляции:

```swift
// Структуры с неизменяемыми данными - как копии
struct User: Sendable {
    let id: Int
    let name: String
}

// Акторы защищают себя сами - они сами обрабатывают своих посетителей
actor BankAccount { }  // Автоматически Sendable
```

**Автоматически Sendable:**
- Типы значений (структуры, перечисления) с Sendable свойствами
- Акторы (они защищают себя сами)
- Неизменяемые классы (`final class` только с `let` свойствами)

### Не-Sendable: Должны оставаться на месте

Эти типы не могут безопасно пересекать границы:

```swift
// Классы с изменяемым состоянием - как оригиналы документов
class Counter {
    var count = 0  // Два офиса изменяют это = катастрофа
}
```

**Почему это ключевое различие?** Потому что каждая ошибка компилятора, с которой вы столкнётесь, сводится к: *"Вы пытаетесь отправить не-Sendable тип через границу изоляции."*

### Когда компилятор жалуется

Если Swift говорит, что что-то не Sendable, у вас есть варианты:

1. **Сделайте его типом значения** - используйте `struct` вместо `class`
2. **Изолируйте его** - держите на `@MainActor`, чтобы не нужно было пересекать границы
3. **Оставьте не-Sendable** - просто не передавайте его между офисами
4. **В крайнем случае:** `@unchecked Sendable` - вы обещаете, что это безопасно (будьте осторожны)

<div class="tip">
<h4>Начните с не-Sendable</h4>

[Matt Massicotte рекомендует](https://www.massicotte.org/non-sendable/) начинать с обычных, не-Sendable типов. Добавляйте `Sendable` только когда вам нужно пересекать границы. Не-Sendable тип остаётся простым и избегает головной боли с соответствием протоколу.
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## Как пересекать границы

Вы понимаете домены изоляции, вы знаете, что может их пересекать. Теперь: **как на самом деле происходит коммуникация между офисами?**

<div class="analogy">
<h4>Офисное здание</h4>

Вы не можете просто ворваться в другой офис. Вы отправляете запрос и ждёте ответа. Вы можете заниматься другими делами пока ждёте, но вам нужен этот ответ, прежде чем вы сможете продолжить.

Это и есть `async/await` - отправка запроса в другой домен изоляции и приостановка до получения ответа.
</div>

### Ключевое слово await

Когда вы вызываете функцию на другом акторе, вам нужен `await`:

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
        await store.add(item)  // Запрос в другой офис
        updateUI()             // Обратно в наш офис
    }
}
```

`await` означает: "Отправь этот запрос и приостановись до завершения. Я могу делать другую работу пока жду."

### Приостановка, не блокировка

<div class="warning">
<h4>Распространённое заблуждение</h4>

Многие разработчики полагают, что добавление `async` заставляет код выполняться в фоне. Это не так. Ключевое слово `async` просто означает, что функция *может приостановиться*. Оно ничего не говорит о том, *где* она выполняется.
</div>

Ключевое понимание - разница между **блокировкой** и **приостановкой**:

- **Блокировка**: Вы сидите в комнате ожидания, уставившись в стену. Ничего больше не происходит.
- **Приостановка**: Вы оставляете номер телефона и идёте по делам. Вам позвонят, когда будет готово.

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">Блокировка</button>
<button>Приостановка</button>
</div>
<div class="code-tab-content active">

```swift
// Поток простаивает, ничего не делает 5 секунд
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// Поток освобождён для другой работы пока ждёт
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### Запуск async работы из синхронного кода

Иногда вы находитесь в синхронном коде и вам нужно вызвать что-то асинхронное. Используйте `Task`:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // Синхронная функция
        Task {
            await loadData()  // Теперь можем использовать await
        }
    }
}
```

<div class="analogy">
<h4>Офисное здание</h4>

`Task` - это как поручение работы сотруднику. Сотрудник обрабатывает запрос (включая ожидание других офисов) пока вы продолжаете свою непосредственную работу.
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## Паттерны, которые работают

### Паттерн сетевого запроса

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (сетевой вызов)</span>
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

        // Это приостанавливается - поток свободен для другой работы
        let users = await networkService.getUsers()

        // Автоматически обратно на MainActor
        self.users = users
        isLoading = false
    }
}
```

</div>

Никакого `DispatchQueue.main.async`. Атрибут `@MainActor` обрабатывает это.

### Параллельная работа с async let

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // Все три выполняются параллельно!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### Предотвращение двойных нажатий

Этот паттерн взят из руководства Matt Massicotte по [stateful системам](https://www.massicotte.org/step-by-step-stateful-systems):

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // Guard СИНХРОННО перед любой async работой
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
<h4>Критически важно: guard должен быть синхронным</h4>

Если вы поместите guard внутрь Task после await, будет окно, в котором два нажатия кнопки могут оба начать работу. [Подробнее об упорядочивании и конкурентности](https://www.massicotte.org/ordering-and-concurrency).
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## Распространённые ошибки, которых следует избегать

Это [распространённые ошибки](https://www.massicotte.org/mistakes-with-concurrency/), которые совершают даже опытные разработчики:

### Думать, что async = фон

<div class="analogy">
<h4>Офисное здание</h4>

Добавление `async` не перемещает вас в другой офис. Вы всё ещё на ресепшене - просто теперь можете ждать доставки, не замирая на месте.
</div>

```swift
// Это ВСЁ ЕЩЁ блокирует главный поток!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // Синхронно = блокирует
    data = result
}
```

Если вам нужна работа в другом офисе, явно отправьте её туда:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // Теперь в другом офисе
    }.value
    await MainActor.run { data = result }
}
```

### Создание слишком многих акторов

<div class="analogy">
<h4>Офисное здание</h4>

Создание нового офиса для каждого куска данных означает бесконечную бюрократию для коммуникации между ними. Большая часть вашей работы может происходить на ресепшене.
</div>

```swift
// Переусложнённо - каждый вызов требует хождения между офисами
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// Лучше - большинство вещей могут жить на ресепшене
@MainActor
class AppState { }
```

### Использование MainActor.run везде

<div class="analogy">
<h4>Офисное здание</h4>

Если вы постоянно ходите на ресепшен за каждой мелочью, просто работайте там. Сделайте это частью своих обязанностей, а не постоянными поручениями.
</div>

```swift
// Не делайте так - постоянное хождение на ресепшен
await MainActor.run { doMainActorStuff() }

// Делайте так - просто работайте на ресепшене
@MainActor func doMainActorStuff() { }
```

### Делать всё Sendable

Не всё должно быть `Sendable`. Если вы добавляете `@unchecked Sendable` везде, вы делаете копии вещей, которым не нужно покидать офис.

### Игнорирование предупреждений компилятора

Каждое предупреждение компилятора о `Sendable` - это охранник, говорящий вам, что что-то небезопасно нести между офисами. Не игнорируйте их - [поймите их](https://www.massicotte.org/complete-checking/).

  </div>
</section>

<section id="errors">
  <div class="container">

## Распространённые ошибки компилятора

Это реальные сообщения об ошибках, которые вы увидите. Каждое из них - это компилятор, защищающий вас от гонки данных.

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>Офисное здание</h4>

Вы пытаетесь отнести оригинал документа в другой офис. Либо сделайте копию (Sendable), либо держите его в одном месте.
</div>

**Решение 1:** Используйте `struct` вместо `class`

**Решение 2:** Держите на одном акторе:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // Остаётся на ресепшене
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>Офисное здание</h4>

Вы пытаетесь нести оригинал между офисами. Охранник вас остановил.
</div>

**Решение 1:** Сделайте структурой:

```swift
// До: class (не-Sendable)
class User { var name: String }

// После: struct (Sendable)
struct User: Sendable { let name: String }
```

**Решение 2:** Изолируйте на одном акторе:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>Офисное здание</h4>

Вы лезете в картотеку другого офиса, не проходя через формальные каналы.
</div>

**Решение:** Используйте `await`:

```swift
// Неправильно - лезете напрямую
let value = myActor.balance

// Правильно - формальный запрос
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>Офисное здание</h4>

Вы пытаетесь использовать ресепшен, не выстояв очередь.
</div>

**Решение 1:** Сделайте вызывающий код `@MainActor`:

```swift
@MainActor
func doSomething() {
    updateUI()  // Та же изоляция, await не нужен
}
```

**Решение 2:** Используйте `await`:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## Три уровня Swift Concurrency

Вам не нужно учить всё сразу. Продвигайтесь через эти уровни:

<div class="analogy">
<h4>Офисное здание</h4>

Думайте об этом как о росте компании. Вы не начинаете с 50-этажной штаб-квартиры - вы начинаете со стола.
</div>

Эти уровни - не строгие границы - разные части вашего приложения могут нуждаться в разных уровнях. Приложение преимущественно Level-1 может иметь одну фичу, которой нужны паттерны Level 2. Это нормально. Используйте простейший подход, который работает для каждой части.

### Level 1: Стартап

Все работают на ресепшене. Просто, прямо, никакой бюрократии.

- Используйте `async/await` для сетевых вызовов
- Помечайте UI классы `@MainActor`
- Используйте модификатор `.task` в SwiftUI

Это покрывает 80% приложений. Такие приложения как [Things](https://culturedcode.com/things/), [Bear](https://bear.app/), [Flighty](https://flighty.com/) или [Day One](https://dayoneapp.com/), вероятно, попадают в эту категорию - приложения, которые в основном получают данные и отображают их.

### Level 2: Растущая компания

Вам нужно обрабатывать несколько вещей одновременно. Время для параллельных проектов и координации команд.

- Используйте `async let` для параллельной работы
- Используйте `TaskGroup` для динамического параллелизма
- Понимайте отмену задач

Такие приложения как [Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp) (Mastodon клиенты, управляющие множеством лент и стриминговыми обновлениями), [Overcast](https://overcast.fm/) (координация загрузок, воспроизведения и фоновой синхронизации), или [Slack](https://slack.com/) (real-time сообщения через множество каналов) могут использовать эти паттерны для определённых фич.

### Level 3: Корпорация

Выделенные отделы со своими политиками. Сложная межофисная коммуникация.

- Создавайте собственные акторы для общего состояния
- Глубокое понимание Sendable
- Кастомные executors

Такие приложения как [Xcode](https://developer.apple.com/xcode/), [Final Cut Pro](https://www.apple.com/final-cut-pro/), или серверные Swift фреймворки вроде [Vapor](https://vapor.codes/) и [Hummingbird](https://hummingbird.codes/), вероятно, нуждаются в этих паттернах - сложное общее состояние, тысячи одновременных соединений, или код на уровне фреймворка, на котором строят другие.

<div class="tip">
<h4>Начните просто</h4>

Большинству приложений никогда не нужен Level 3. Не стройте корпорацию, когда стартапа достаточно.
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## Глоссарий: Другие ключевые слова, с которыми вы столкнётесь

Помимо основных концепций, вот другие ключевые слова Swift concurrency, которые вы встретите:

| Ключевое слово | Что оно означает |
|----------------|------------------|
| `nonisolated` | Отказ от изоляции актора - работает без защиты |
| `isolated` | Явно объявляет, что параметр работает в контексте актора |
| `@Sendable` | Помечает замыкание как безопасное для передачи через границы изоляции |
| `Task.detached` | Создаёт задачу, полностью отделённую от текущего контекста |
| `AsyncSequence` | Последовательность, которую можно итерировать с `for await` |
| `AsyncStream` | Способ связать код на callback'ах с async последовательностями |
| `withCheckedContinuation` | Связывает completion handlers с async/await |
| `Task.isCancelled` | Проверка, была ли текущая задача отменена |
| `@preconcurrency` | Подавляет предупреждения конкурентности для legacy кода |
| `GlobalActor` | Протокол для создания собственных акторов вроде MainActor |

### Когда использовать каждое

#### nonisolated - Чтение вычисляемых свойств

<div class="analogy">
Как табличка с именем на двери вашего офиса - любой проходящий мимо может прочитать её, не заходя внутрь и не ожидая вас.
</div>

По умолчанию всё внутри актора изолировано - вам нужен `await` для доступа к нему. Но иногда у вас есть свойства, которые по своей природе безопасны для чтения: неизменяемые `let` константы, или вычисляемые свойства, которые только получают значения из других безопасных данных. Пометив их `nonisolated`, вы позволяете вызывающим обращаться к ним синхронно, избегая ненужных async накладных расходов.

<div class="isolation-legend">
  <span class="isolation-legend-item actor">Актор-изолированный</span>
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
    let userId: String  // Неизменяемый, безопасно читать
    var lastActivity: Date  // Изменяемый, нуждается в защите

    // Это можно вызвать без await
    nonisolated var displayId: String {
        "User: \(userId)"  // Читает только неизменяемые данные
    }
}
```

</div>

```swift
// Использование
let session = UserSession(userId: "123")
print(session.displayId)  // Await не нужен!
```

#### @Sendable - Замыкания, пересекающие границы

<div class="analogy">
Как запечатанный конверт с инструкциями внутри - конверт может путешествовать между офисами, и кто бы его ни открыл, может безопасно следовать инструкциям.
</div>

Когда замыкание убегает, чтобы выполниться позже или в другом домене изоляции, Swift должен гарантировать, что оно не вызовет гонок данных. Атрибут `@Sendable` помечает замыкания, которые безопасно передавать через границы - они не могут небезопасно захватывать изменяемое состояние. Swift часто выводит это автоматически (как с `Task.detached`), но иногда вам нужно объявить это явно при проектировании API, принимающих замыкания.

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // Это замыкание пересекает от detached task к MainActor
            // Оно должно быть @Sendable (Swift выводит это)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// Явный @Sendable когда нужно
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - Связывание старых API

<div class="analogy">
Как переводчик между старой системой бумажных служебных записок и современной почтой. Вы ждёте у почтового отделения, пока старая система доставит ответ, затем пересылаете его через новую систему.
</div>

Многие старые API используют completion handlers вместо async/await. Вместо полного переписывания их вы можете обернуть их с помощью `withCheckedContinuation`. Эта функция приостанавливает текущую задачу, даёт вам объект continuation и возобновляется, когда вы вызываете `continuation.resume()`. "Checked" вариант ловит ошибки программирования вроде двойного возобновления или невозобновления вообще.

<div class="isolation-legend">
  <span class="isolation-legend-item main">Async контекст</span>
  <span class="isolation-legend-item nonisolated">Callback контекст</span>
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
// Старое API на callback'ах
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... сетевой вызов с callback
}

// Обёрнутое как async
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // Мост обратно!
        }
    }
}
```

</div>

Для бросающих функций используйте `withCheckedThrowingContinuation`:

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

#### AsyncStream - Связывание источников событий

<div class="analogy">
Как настройка переадресации почты - каждый раз, когда письмо приходит на старый адрес, оно автоматически направляется в ваш новый ящик. Поток продолжается, пока приходит почта.
</div>

В то время как `withCheckedContinuation` обрабатывает одноразовые callback'и, многие API доставляют множество значений со временем - методы делегатов, NotificationCenter или кастомные системы событий. `AsyncStream` связывает их с `AsyncSequence` Swift, позволяя использовать циклы `for await`. Вы создаёте stream, сохраняете его continuation и вызываете `yield()` каждый раз, когда приходит новое значение.

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

// Использование
let tracker = LocationTracker()
for await location in tracker.locations {
    print("Новая локация: \(location)")
}
```

#### Task.isCancelled - Кооперативная отмена

<div class="analogy">
Как проверка входящих на предмет записки "прекратить работу над этим" перед началом каждого шага большого проекта. Вас не заставляют остановиться - вы выбираете проверить и вежливо отреагировать.
</div>

Swift использует кооперативную отмену - когда задача отменяется, она не останавливается немедленно. Вместо этого устанавливается флаг, и ваша ответственность - периодически проверять его. Это даёт вам контроль над очисткой и частичными результатами. Используйте `Task.checkCancellation()` чтобы немедленно бросить исключение, или проверяйте `Task.isCancelled` когда хотите обработать отмену изящно (например, вернув частичные результаты).

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // Проверка перед каждой дорогой операцией
        try Task.checkCancellation()  // Бросает если отменено

        // Или проверка без броска
        if Task.isCancelled {
            return results  // Вернуть частичные результаты
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - Выход из текущего контекста

<div class="analogy">
Как найм внешнего подрядчика, который не отчитывается вашему отделу. Он работает независимо, не следует правилам вашего офиса, и вам нужно явно координироваться, когда нужны результаты обратно.
</div>

Обычный `Task { }` наследует текущий контекст актора - если вы на `@MainActor`, задача выполняется на `@MainActor`. Иногда это не то, что вам нужно, особенно для CPU-интенсивной работы, которая заблокирует UI. `Task.detached` создаёт задачу без унаследованного контекста, выполняющуюся на фоновом executor'е. Используйте его экономно - в большинстве случаев обычный `Task` с правильными точками `await` достаточен и проще для понимания.

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
        // НЕ ДЕЛАЙТЕ ТАК: Это всё ещё наследует контекст MainActor
        Task {
            let filtered = applyFilters(image)  // Блокирует main!
        }

        // ДЕЛАЙТЕ ТАК: Detached task работает независимо
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
<h4>Task.detached обычно неправильный выбор</h4>

В большинстве случаев вам нужен обычный `Task`. Detached tasks не наследуют приоритет, task-local значения или контекст актора. Используйте их только когда вам явно нужно это разделение.
</div>

#### @preconcurrency - Жизнь с legacy кодом

Подавляет предупреждения при импорте модулей, ещё не обновлённых для конкурентности:

```swift
// Подавить предупреждения от этого импорта
@preconcurrency import OldFramework

// Или на соответствии протоколу
class MyDelegate: @preconcurrency SomeOldDelegate {
    // Не будет предупреждать о не-Sendable требованиях
}
```

<div class="tip">
<h4>@preconcurrency временный</h4>

Используйте его как мост при обновлении кода. Цель - в итоге удалить его и иметь правильное соответствие Sendable.
</div>

## Дополнительное чтение

Это руководство выжимает лучшие ресурсы по конкурентности Swift.

<div class="resources">
<h4>Блог Matt Massicotte (Очень рекомендуется)</h4>

- [A Swift Concurrency Glossary](https://www.massicotte.org/concurrency-glossary) - Основная терминология
- [An Introduction to Isolation](https://www.massicotte.org/intro-to-isolation/) - Ключевая концепция
- [When should you use an actor?](https://www.massicotte.org/actors/) - Практическое руководство
- [Non-Sendable types are cool too](https://www.massicotte.org/non-sendable/) - Почему проще лучше
- [Crossing the Boundary](https://www.massicotte.org/crossing-the-boundary/) - Работа с не-Sendable типами
- [Problematic Swift Concurrency Patterns](https://www.massicotte.org/problematic-patterns/) - Чего избегать
- [Making Mistakes with Swift Concurrency](https://www.massicotte.org/mistakes-with-concurrency/) - Учимся на ошибках
</div>

<div class="resources">
<h4>Официальные ресурсы Apple</h4>

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: Meet async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Protect mutable state with actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>Туториалы</h4>

- [Swift Concurrency by Example - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Async await in Swift - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

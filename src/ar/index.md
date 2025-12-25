---
layout: base.njk
title: دليل Swift للتزامن بطريقة سهلة جداً
description: دليل صادق للتزامن في Swift. تعلم async/await و actors و Sendable و MainActor بنماذج ذهنية بسيطة. بدون مصطلحات، فقط شروحات واضحة.
lang: ar
dir: rtl
nav:
  isolation: العزل
  domains: النطاقات
  patterns: الأنماط
  errors: الأخطاء
footer:
  madeWith: صُنع بالإحباط والحب. لأن التزامن في Swift لا يجب أن يكون مربكاً.
  viewOnGitHub: عرض على GitHub
---

<section class="hero">
  <div class="container">
    <h1>دليل Swift للتزامن<br><span class="accent">بطريقة سهلة جداً</span></h1>
    <p class="subtitle">افهم أخيراً async/await و actors و Sendable. نماذج ذهنية واضحة، بدون مصطلحات معقدة.</p>
    <p class="credit">شكر كبير لـ <a href="https://www.massicotte.org/">Matt Massicotte</a> لجعل التزامن في Swift مفهوماً. من إعداد <a href="https://pepicrft.me">Pedro Piñera</a>. وجدت مشكلة؟ <a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute">في تقليد <a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a> و <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a></p>
    <p class="cta-tuist">وسّع تطويرك مع <a href="https://tuist.dev">Tuist</a></p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## الحقيقة الصريحة

لا توجد ورقة غش للتزامن في Swift. كل إجابة "فقط افعل X" خاطئة في بعض السياقات.

**لكن هذه هي الأخبار الجيدة:** بمجرد أن تفهم [العزل](#basics) (قراءة 5 دقائق)، كل شيء يصبح واضحاً. أخطاء المترجم تبدأ في أن تكون منطقية. تتوقف عن محاربة النظام وتبدأ في العمل معه.

*يستهدف هذا الدليل Swift 6+. معظم المفاهيم تنطبق على Swift 5.5+، لكن Swift 6 يفرض فحصاً أكثر صرامة للتزامن.*

<a href="#basics" class="read-more">ابدأ بالنموذج الذهني &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## الشيء الوحيد الذي تحتاج إلى فهمه

**[العزل](https://www.massicotte.org/intro-to-isolation/)** هو المفتاح لكل شيء. إنه إجابة Swift على السؤال: *من يُسمح له بلمس هذه البيانات الآن؟*

<div class="analogy">
<h4>مبنى المكاتب</h4>

فكر في تطبيقك كـ **مبنى مكاتب**. كل مكتب هو **نطاق عزل** - مساحة خاصة حيث يمكن لشخص واحد فقط العمل في وقت واحد. لا يمكنك فقط الدخول إلى مكتب شخص آخر والبدء في إعادة ترتيب مكتبه.

سنبني على هذه الاستعارة طوال الدليل.
</div>

### لماذا ليس فقط الخيوط؟

لعقود، كتبنا الكود المتزامن بالتفكير في الخيوط. المشكلة؟ **الخيوط لا تمنعك من إطلاق النار على قدمك.** يمكن لخيطين الوصول إلى نفس البيانات في نفس الوقت، مما يتسبب في سباقات البيانات - أخطاء تتعطل بشكل عشوائي ويكاد يكون من المستحيل إعادة إنتاجها.

على الهاتف، قد تفلت من ذلك. على الخادم الذي يتعامل مع آلاف الطلبات المتزامنة، تصبح سباقات البيانات أمراً مؤكداً - عادة ما تظهر في الإنتاج، يوم الجمعة. مع توسع Swift إلى الخوادم وبيئات أخرى عالية التزامن، "الأمل في الأفضل" لا يكفي.

النهج القديم كان دفاعياً: استخدام الأقفال، طوابير الإرسال، الأمل في أنك لم تفوت نقطة.

نهج Swift مختلف: **اجعل سباقات البيانات مستحيلة في وقت الترجمة.** بدلاً من السؤال "على أي خيط هذا؟"، يسأل Swift "من يُسمح له بلمس هذه البيانات الآن؟" هذا هو العزل.

### كيف تتعامل اللغات الأخرى مع هذا

| اللغة | النهج | متى تكتشف الأخطاء |
|----------|----------|------------------------------|
| **Swift** | العزل + Sendable | وقت الترجمة |
| **Rust** | الملكية + مدقق الاستعارة | وقت الترجمة |
| **Kotlin** | الكوروتينات + التزامن المهيكل | جزئياً وقت الترجمة |
| **Go** | القنوات + كاشف السباق | وقت التشغيل (مع الأدوات) |
| **Java** | `synchronized`، الأقفال | وقت التشغيل (التعطل) |
| **JavaScript** | حلقة أحداث أحادية الخيط | يتم تجنبه تماماً |
| **C/C++** | أقفال يدوية | وقت التشغيل (سلوك غير محدد) |

Swift و Rust توفران أقوى ضمانات وقت الترجمة ضد سباقات البيانات. Kotlin Coroutines توفر تزامناً مهيكلاً مشابهاً لـ async/await في Swift، لكن بدون نفس مستوى الإنفاذ في نظام الأنواع لأمان الخيوط. المقايضة؟ منحنى تعليمي أكثر انحداراً في البداية. لكن بمجرد أن تفهم النموذج، المترجم يدعمك.

تلك الأخطاء المزعجة حول `Sendable` وعزل الـ actor؟ إنها تكتشف الأخطاء التي كانت ستكون تعطلات صامتة من قبل.

  </div>
</section>

<section id="domains">
  <div class="container">

## نطاقات العزل

الآن بعد أن فهمت العزل (المكاتب الخاصة)، لنلقِ نظرة على الأنواع المختلفة من المكاتب في مبنى Swift.

<div class="analogy">
<h4>مبنى المكاتب</h4>

- **مكتب الاستقبال** (`MainActor`) - حيث تحدث جميع تفاعلات العملاء. يوجد واحد فقط، ويتعامل مع كل ما يراه المستخدم.
- **مكاتب الأقسام** (`actor`) - المحاسبة، القانونية، الموارد البشرية. كل قسم له مكتبه الخاص الذي يحمي بياناته الحساسة الخاصة.
- **الممرات والمناطق المشتركة** (`nonisolated`) - مساحات مشتركة يمكن لأي شخص المشي من خلالها. لا توجد بيانات خاصة هنا.
</div>

### MainActor: مكتب الاستقبال

`MainActor` هو نطاق عزل خاص يعمل على الخيط الرئيسي. إنه المكان الذي يحدث فيه كل عمل واجهة المستخدم.

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // حالة واجهة المستخدم تعيش هنا

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // آمن - نحن على MainActor
    }
}
```

<div class="tip">
<h4>عند الشك، استخدم MainActor</h4>

بالنسبة لمعظم التطبيقات، وضع علامة على ViewModels والفئات المتعلقة بواجهة المستخدم بـ `@MainActor` هو الاختيار الصحيح. المخاوف المتعلقة بالأداء عادة ما تكون مبالغ فيها - ابدأ هنا، قم بالتحسين فقط إذا قست مشاكل فعلية.
</div>

### Actors: مكاتب الأقسام

`actor` يشبه مكتب القسم - يحمي بياناته الخاصة ويسمح فقط بزائر واحد في كل مرة.

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // آمن! متصل واحد فقط في كل مرة
    }
}
```

بدون actors، يقرأ خيطان الرصيد = 100، كلاهما يضيف 50، كلاهما يكتب 150 - فقدت 50 دولاراً. مع actors، يقوم Swift تلقائياً بوضع الوصول في قائمة الانتظار وكلا الإيداعين يكتملان بشكل صحيح.

<div class="warning">
<h4>لا تفرط في استخدام actors</h4>

تحتاج إلى actor مخصص فقط عندما تكون **جميع** هذه الشروط الأربعة صحيحة:
1. لديك حالة قابلة للتغيير غير Sendable (غير آمنة للخيوط)
2. أماكن متعددة تحتاج إلى الوصول إليها
3. يجب أن تكون العمليات على تلك الحالة ذرية
4. لا يمكنها العيش فقط على MainActor

إذا كان أي شرط خاطئاً، فمن المحتمل أنك لا تحتاج إلى actor. يمكن لمعظم حالات واجهة المستخدم العيش على `@MainActor`. [اقرأ المزيد عن متى تستخدم actors](https://www.massicotte.org/actors/).
</div>

### Nonisolated: الممرات

الكود الموسوم بـ `nonisolated` يشبه الممرات - لا ينتمي إلى أي مكتب ويمكن الوصول إليه من أي مكان.

```swift
actor UserSession {
    let userId: String          // غير قابل للتغيير - آمن للقراءة من أي مكان
    var lastActivity: Date      // قابل للتغيير - يحتاج إلى حماية actor

    nonisolated var displayId: String {
        "User: \(userId)"       // يقرأ فقط البيانات غير القابلة للتغيير
    }
}

// الاستخدام - لا حاجة لـ await لـ nonisolated
let session = UserSession(userId: "123")
print(session.displayId)  // يعمل بشكل متزامن!
```

استخدم `nonisolated` للخصائص المحسوبة التي تقرأ فقط البيانات غير القابلة للتغيير.

  </div>
</section>

<section id="propagation">
  <div class="container">

## كيف ينتشر العزل

عندما تضع علامة على نوع بعزل actor، ماذا يحدث لأساليبه؟ ماذا عن الإغلاقات؟ فهم كيفية انتشار العزل هو مفتاح تجنب المفاجآت.

<div class="analogy">
<h4>مبنى المكاتب</h4>

عندما يتم توظيفك في قسم، تعمل في مكتب ذلك القسم افتراضياً. إذا قام قسم التسويق بتوظيفك، فأنت لا تظهر بشكل عشوائي في المحاسبة.

وبالمثل، عندما يتم تعريف دالة داخل فئة `@MainActor`، فإنها ترث ذلك العزل. إنها "تعمل في نفس المكتب" مثل والدها.
</div>

### الفئات ترث عزلها

```swift
@MainActor
class ViewModel {
    var count = 0           // معزول بـ MainActor

    func increment() {      // أيضاً معزول بـ MainActor
        count += 1
    }
}
```

كل شيء داخل الفئة يرث `@MainActor`. لا تحتاج إلى وضع علامة على كل أسلوب.

### المهام ترث السياق (عادةً)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // هذا يرث MainActor!
            self.updateUI()  // آمن، لا حاجة لـ await
        }
    }
}
```

`Task { }` الذي تم إنشاؤه من سياق `@MainActor` يبقى على `MainActor`. هذا عادة ما تريده.

### Task.detached يكسر الميراث

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // لم يعد على MainActor!
            await self.updateUI()  // تحتاج await الآن
        }
    }
}
```

<div class="analogy">
<h4>مبنى المكاتب</h4>

`Task.detached` يشبه توظيف مقاول خارجي. ليس لديهم بطاقة لمكتبك - يعملون من مساحتهم الخاصة ويجب أن يمروا عبر القنوات المناسبة للوصول إلى أشيائك.
</div>

<div class="warning">
<h4>Task.detached عادة ما يكون خاطئاً</h4>

في معظم الأحيان، تريد `Task` عادياً. المهام المنفصلة لا ترث الأولوية، أو القيم المحلية للمهمة، أو سياق actor. استخدمها فقط عندما تحتاج صراحةً إلى ذلك الفصل.
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## ما الذي يمكن أن يعبر الحدود

الآن بعد أن عرفت نطاقات العزل (المكاتب) وكيف تنتشر، السؤال التالي هو: **ماذا يمكنك تمرير بينها؟**

<div class="analogy">
<h4>مبنى المكاتب</h4>

ليس كل شيء يمكن أن يغادر المكتب:

- **النسخ** آمنة للمشاركة - إذا قام القسم القانوني بعمل نسخة من مستند وإرساله إلى المحاسبة، فكلاهما لديه نسخته الخاصة. لا يوجد تضارب.
- **العقود الأصلية الموقعة** يجب أن تبقى في مكانها - إذا كان بإمكان قسمين كليهما تعديل الأصل، ينتج الفوضى.

بمصطلحات Swift: أنواع **Sendable** هي نسخ (آمنة للمشاركة)، أنواع **non-Sendable** هي الأصول (يجب أن تبقى في مكتب واحد).
</div>

### Sendable: آمن للمشاركة

هذه الأنواع يمكن أن تعبر حدود العزل بأمان:

```swift
// الهياكل مع بيانات غير قابلة للتغيير - مثل النسخ
struct User: Sendable {
    let id: Int
    let name: String
}

// Actors تحمي نفسها - يتعاملون مع زوارهم الخاصين
actor BankAccount { }  // تلقائياً Sendable
```

**تلقائياً Sendable:**
- أنواع القيمة (structs، enums) مع خصائص Sendable
- Actors (يحمون أنفسهم)
- فئات غير قابلة للتغيير (`final class` مع خصائص `let` فقط)

### Non-Sendable: يجب أن يبقى في مكانه

هذه الأنواع لا يمكن أن تعبر الحدود بأمان:

```swift
// فئات ذات حالة قابلة للتغيير - مثل المستندات الأصلية
class Counter {
    var count = 0  // مكتبان يعدلان هذا = كارثة
}
```

**لماذا هذا هو التمييز الرئيسي؟** لأن كل خطأ مترجم ستواجهه يتلخص في: *"أنت تحاول إرسال نوع non-Sendable عبر حدود العزل."*

### عندما يشتكي المترجم

إذا قال Swift أن شيئاً ما ليس Sendable، لديك خيارات:

1. **اجعله نوع قيمة** - استخدم `struct` بدلاً من `class`
2. **اعزله** - أبقه على `@MainActor` حتى لا يحتاج إلى العبور
3. **أبقه non-Sendable** - فقط لا تمرره بين المكاتب
4. **الملاذ الأخير:** `@unchecked Sendable` - أنت تعد أنه آمن (كن حذراً)

<div class="tip">
<h4>ابدأ بـ non-Sendable</h4>

[يدافع Matt Massicotte](https://www.massicotte.org/non-sendable/) عن البدء بأنواع عادية، non-Sendable. أضف `Sendable` فقط عندما تحتاج إلى عبور الحدود. يبقى نوع non-Sendable بسيطاً ويتجنب صداع المطابقة.
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## كيفية عبور الحدود

تفهم نطاقات العزل، تعرف ما يمكن أن يعبرها. الآن: **كيف تتواصل فعلياً بين المكاتب؟**

<div class="analogy">
<h4>مبنى المكاتب</h4>

لا يمكنك فقط الدخول إلى مكتب آخر. ترسل طلباً وتنتظر استجابة. قد تعمل على أشياء أخرى أثناء الانتظار، لكنك تحتاج إلى تلك الاستجابة قبل أن تتمكن من المتابعة.

هذا هو `async/await` - إرسال طلب إلى نطاق عزل آخر والتوقف مؤقتاً حتى تحصل على إجابة.
</div>

### كلمة await

عندما تستدعي دالة على actor آخر، تحتاج إلى `await`:

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
        await store.add(item)  // طلب إلى مكتب آخر
        updateUI()             // عودة إلى مكتبنا
    }
}
```

`await` تعني: "أرسل هذا الطلب وتوقف مؤقتاً حتى ينتهي. قد أقوم بعمل آخر أثناء الانتظار."

### التعليق، وليس الحظر

<div class="warning">
<h4>مفهوم خاطئ شائع</h4>

يفترض العديد من المطورين أن إضافة `async` تجعل الكود يعمل في الخلفية. إنها لا تفعل. الكلمة الرئيسية `async` تعني فقط أن الدالة *يمكن أن تتوقف مؤقتاً*. لا تقول شيئاً عن *أين* يعمل.
</div>

الفكرة الرئيسية هي الفرق بين **الحظر** و **التعليق**:

- **الحظر**: تجلس في غرفة الانتظار تحدق في الجدار. لا شيء آخر يحدث.
- **التعليق**: تترك رقم هاتفك وتقوم بالمهام. سيتصلون عندما يكونون جاهزين.

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">الحظر</button>
<button>التعليق</button>
</div>
<div class="code-tab-content active">

```swift
// الخيط يجلس خاملاً، لا يفعل شيئاً لمدة 5 ثوانٍ
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// يتم تحرير الخيط للقيام بعمل آخر أثناء الانتظار
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### بدء العمل غير المتزامن من الكود المتزامن

في بعض الأحيان تكون في كود متزامن وتحتاج إلى استدعاء شيء غير متزامن. استخدم `Task`:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // دالة متزامنة
        Task {
            await loadData()  // الآن يمكننا استخدام await
        }
    }
}
```

<div class="analogy">
<h4>مبنى المكاتب</h4>

`Task` يشبه تعيين العمل لموظف. يتعامل الموظف مع الطلب (بما في ذلك الانتظار للمكاتب الأخرى) بينما تواصل عملك الفوري.
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## الأنماط التي تعمل

### نمط طلب الشبكة

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (استدعاء الشبكة)</span>
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

        // هذا يتوقف مؤقتاً - الخيط حر للقيام بعمل آخر
        let users = await networkService.getUsers()

        // عودة على MainActor تلقائياً
        self.users = users
        isLoading = false
    }
}
```

</div>

لا `DispatchQueue.main.async`. سمة `@MainActor` تتعامل معها.

### العمل المتوازي مع async let

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // الثلاثة جميعاً يعملون بالتوازي!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### منع النقر المزدوج

هذا النمط يأتي من دليل Matt Massicotte حول [الأنظمة ذات الحالة](https://www.massicotte.org/step-by-step-stateful-systems):

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // احمِ بشكل متزامن قبل أي عمل غير متزامن
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
<h4>حرج: يجب أن يكون الحارس متزامناً</h4>

إذا وضعت الحارس داخل Task بعد await، هناك نافذة حيث يمكن لنقرتين على الزر أن يبدآ العمل كلاهما. [تعلم المزيد عن الترتيب والتزامن](https://www.massicotte.org/ordering-and-concurrency).
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## الأخطاء الشائعة التي يجب تجنبها

هذه هي [الأخطاء الشائعة](https://www.massicotte.org/mistakes-with-concurrency/) التي يرتكبها حتى المطورون المتمرسون:

### التفكير في أن async = الخلفية

<div class="analogy">
<h4>مبنى المكاتب</h4>

إضافة `async` لا تنقلك إلى مكتب مختلف. أنت لا تزال في مكتب الاستقبال - يمكنك فقط الانتظار للتسليمات الآن دون التجمد في مكانك.
</div>

```swift
// هذا لا يزال يحظر الخيط الرئيسي!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // متزامن = حظر
    data = result
}
```

إذا كنت بحاجة إلى عمل في مكتب آخر، أرسله هناك صراحةً:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // الآن في مكتب مختلف
    }.value
    await MainActor.run { data = result }
}
```

### إنشاء actors كثيرة جداً

<div class="analogy">
<h4>مبنى المكاتب</h4>

إنشاء مكتب جديد لكل قطعة من البيانات يعني أعمال ورقية لا نهاية لها للتواصل بينها. يمكن أن يحدث معظم عملك في مكتب الاستقبال.
</div>

```swift
// مفرط الهندسة - كل استدعاء يتطلب المشي بين المكاتب
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// أفضل - معظم الأشياء يمكن أن تعيش في مكتب الاستقبال
@MainActor
class AppState { }
```

### استخدام MainActor.run في كل مكان

<div class="analogy">
<h4>مبنى المكاتب</h4>

إذا كنت تستمر في المشي إلى مكتب الاستقبال لكل شيء صغير، فقط اعمل هناك. اجعله جزءاً من وصفك الوظيفي، وليس مهمة مستمرة.
</div>

```swift
// لا تفعل هذا - تمشي باستمرار إلى مكتب الاستقبال
await MainActor.run { doMainActorStuff() }

// افعل هذا - فقط اعمل في مكتب الاستقبال
@MainActor func doMainActorStuff() { }
```

### جعل كل شيء Sendable

ليس كل شيء يحتاج إلى أن يكون `Sendable`. إذا كنت تضيف `@unchecked Sendable` في كل مكان، فأنت تصنع نسخاً من الأشياء التي لا تحتاج إلى مغادرة المكتب.

### تجاهل تحذيرات المترجم

كل تحذير من المترجم حول `Sendable` هو الحارس الأمني يخبرك أن شيئاً ما ليس آمناً للحمل بين المكاتب. لا تتجاهلها - [افهمها](https://www.massicotte.org/complete-checking/).

  </div>
</section>

<section id="errors">
  <div class="container">

## أخطاء المترجم الشائعة

هذه هي رسائل الخطأ الفعلية التي سترى. كل واحد هو المترجم يحميك من سباق البيانات.

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>مبنى المكاتب</h4>

أنت تحاول حمل مستند أصلي إلى مكتب آخر. إما اصنع نسخة (Sendable) أو أبقه في مكان واحد.
</div>

**الإصلاح 1:** استخدم `struct` بدلاً من `class`

**الإصلاح 2:** أبقه على actor واحد:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // يبقى في مكتب الاستقبال
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>مبنى المكاتب</h4>

أنت تحاول حمل أصل بين المكاتب. الحارس الأمني أوقفك.
</div>

**الإصلاح 1:** اجعله struct:

```swift
// قبل: class (non-Sendable)
class User { var name: String }

// بعد: struct (Sendable)
struct User: Sendable { let name: String }
```

**الإصلاح 2:** اعزله إلى actor واحد:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>مبنى المكاتب</h4>

أنت تحاول الوصول إلى خزانة ملفات مكتب آخر دون المرور عبر القنوات المناسبة.
</div>

**الإصلاح:** استخدم `await`:

```swift
// خطأ - الوصول مباشرة
let value = myActor.balance

// صحيح - طلب مناسب
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>مبنى المكاتب</h4>

أنت تحاول استخدام مكتب الاستقبال دون الانتظار في الطابور.
</div>

**الإصلاح 1:** اجعل المتصل `@MainActor`:

```swift
@MainActor
func doSomething() {
    updateUI()  // نفس العزل، لا حاجة لـ await
}
```

**الإصلاح 2:** استخدم `await`:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## ثلاثة مستويات من التزامن في Swift

لا تحتاج إلى تعلم كل شيء دفعة واحدة. تقدم عبر هذه المستويات:

<div class="analogy">
<h4>مبنى المكاتب</h4>

فكر في الأمر كنمو شركة. لا تبدأ بمقر من 50 طابقاً - تبدأ بمكتب.
</div>

هذه المستويات ليست حدوداً صارمة - أجزاء مختلفة من تطبيقك قد تحتاج مستويات مختلفة. تطبيق في الغالب من المستوى 1 قد يحتوي على ميزة واحدة تحتاج إلى أنماط المستوى 2. هذا جيد. استخدم النهج الأبسط الذي يعمل لكل قطعة.

### المستوى 1: الشركة الناشئة

الجميع يعمل في مكتب الاستقبال. بسيط، مباشر، بدون بيروقراطية.

- استخدم `async/await` لاستدعاءات الشبكة
- ضع علامة على فئات واجهة المستخدم بـ `@MainActor`
- استخدم معدّل `.task` في SwiftUI

هذا يتعامل مع 80٪ من التطبيقات. التطبيقات مثل [Things](https://culturedcode.com/things/)، [Bear](https://bear.app/)، [Flighty](https://flighty.com/)، أو [Day One](https://dayoneapp.com/) تقع على الأرجح في هذه الفئة - تطبيقات تجلب البيانات وتعرضها في المقام الأول.

### المستوى 2: الشركة المتنامية

تحتاج إلى التعامل مع أشياء متعددة في وقت واحد. حان الوقت للمشاريع المتوازية وتنسيق الفرق.

- استخدم `async let` للعمل المتوازي
- استخدم `TaskGroup` للتوازي الديناميكي
- افهم إلغاء المهام

التطبيقات مثل [Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp) (عملاء Mastodon يديرون خطوطاً زمنية متعددة وتحديثات مباشرة)، [Overcast](https://overcast.fm/) (تنسيق التنزيلات والتشغيل والمزامنة في الخلفية)، أو [Slack](https://slack.com/) (المراسلة في الوقت الفعلي عبر قنوات متعددة) قد تستخدم هذه الأنماط لميزات معينة.

### المستوى 3: المؤسسة

أقسام مخصصة بسياساتها الخاصة. اتصال معقد بين المكاتب.

- إنشاء actors مخصصة للحالة المشتركة
- فهم عميق لـ Sendable
- منفذون مخصصون

التطبيقات مثل [Xcode](https://developer.apple.com/xcode/)، [Final Cut Pro](https://www.apple.com/final-cut-pro/)، أو أطر Swift من جانب الخادم مثل [Vapor](https://vapor.codes/) و [Hummingbird](https://hummingbird.codes/) تحتاج على الأرجح إلى هذه الأنماط - حالة مشتركة معقدة، آلاف الاتصالات المتزامنة، أو كود على مستوى الإطار يبني عليه الآخرون.

<div class="tip">
<h4>ابدأ بسيطاً</h4>

معظم التطبيقات لا تحتاج أبداً إلى المستوى 3. لا تبني مؤسسة عندما تكفي شركة ناشئة.
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## المسرد: المزيد من الكلمات الرئيسية التي ستواجهها

بالإضافة إلى المفاهيم الأساسية، إليك الكلمات الرئيسية الأخرى لتزامن Swift التي سترى في البرية:

| الكلمة الرئيسية | ما تعنيه |
|---------|---------------|
| `nonisolated` | يلغي عزل actor - يعمل بدون حماية |
| `isolated` | يعلن صراحةً أن معلمة تعمل في سياق actor |
| `@Sendable` | يضع علامة على إغلاق كآمن للتمرير عبر حدود العزل |
| `Task.detached` | ينشئ مهمة منفصلة تماماً عن السياق الحالي |
| `AsyncSequence` | تسلسل يمكنك التكرار عليه باستخدام `for await` |
| `AsyncStream` | طريقة لربط الكود المعتمد على callback بـ async sequences |
| `withCheckedContinuation` | يربط معالجات الإكمال بـ async/await |
| `Task.isCancelled` | تحقق مما إذا تم إلغاء المهمة الحالية |
| `@preconcurrency` | يكتم تحذيرات التزامن للكود القديم |
| `GlobalActor` | بروتوكول لإنشاء actors مخصصة مثل MainActor |

### متى تستخدم كل واحد

#### nonisolated - قراءة الخصائص المحسوبة

<div class="analogy">
مثل لوحة الاسم على باب مكتبك - يمكن لأي شخص يمر بها قراءتها دون الحاجة إلى الدخول والانتظار لك.
</div>

افتراضياً، كل شيء داخل actor معزول - تحتاج إلى `await` للوصول إليه. لكن في بعض الأحيان لديك خصائص آمنة بطبيعتها للقراءة: ثوابت `let` غير قابلة للتغيير، أو خصائص محسوبة تستمد فقط القيم من بيانات آمنة أخرى. وضع علامة على هذه بـ `nonisolated` يسمح للمتصلين بالوصول إليها بشكل متزامن، مما يتجنب النفقات غير الضرورية للـ async.

<div class="isolation-legend">
  <span class="isolation-legend-item actor">معزول بـ Actor</span>
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
    let userId: String  // غير قابل للتغيير، آمن للقراءة
    var lastActivity: Date  // قابل للتغيير، يحتاج حماية

    // يمكن استدعاء هذا بدون await
    nonisolated var displayId: String {
        "User: \(userId)"  // يقرأ فقط البيانات غير القابلة للتغيير
    }
}
```

</div>

```swift
// الاستخدام
let session = UserSession(userId: "123")
print(session.displayId)  // لا حاجة لـ await!
```

#### @Sendable - الإغلاقات التي تعبر الحدود

<div class="analogy">
مثل مغلف مختوم بتعليمات بداخله - يمكن للمغلف السفر بين المكاتب، وكل من يفتحه يمكنه اتباع التعليمات بأمان.
</div>

عندما يهرب إغلاق ليعمل لاحقاً أو على نطاق عزل مختلف، يحتاج Swift إلى ضمان أنه لن يسبب سباقات البيانات. سمة `@Sendable` تضع علامة على الإغلاقات الآمنة للتمرير عبر الحدود - لا يمكنها التقاط حالة قابلة للتغيير بشكل غير آمن. Swift غالباً ما يستنتج هذا تلقائياً (مثل مع `Task.detached`)، لكن في بعض الأحيان تحتاج إلى إعلانها صراحةً عند تصميم APIs تقبل الإغلاقات.

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // هذا الإغلاق يعبر من مهمة منفصلة إلى MainActor
            // يجب أن يكون @Sendable (Swift يستنتج هذا)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// @Sendable صريح عند الحاجة
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - ربط APIs القديمة

<div class="analogy">
مثل مترجم بين نظام المذكرات الورقية القديم والبريد الإلكتروني الحديث. تنتظر بجانب غرفة البريد حتى يقدم النظام القديم استجابة، ثم تعيد إرسالها عبر النظام الجديد.
</div>

العديد من APIs الأقدم تستخدم معالجات الإكمال بدلاً من async/await. بدلاً من إعادة كتابتها بالكامل، يمكنك لفها باستخدام `withCheckedContinuation`. هذه الدالة تعلق المهمة الحالية، تعطيك كائن استمرارية، وتستأنف عندما تستدعي `continuation.resume()`. البديل "checked" يلتقط أخطاء البرمجة مثل الاستئناف مرتين أو عدم الاستئناف على الإطلاق.

<div class="isolation-legend">
  <span class="isolation-legend-item main">سياق Async</span>
  <span class="isolation-legend-item nonisolated">سياق Callback</span>
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
// API قديمة معتمدة على callback
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... استدعاء الشبكة مع callback
}

// ملفوفة كـ async
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // يربط مرة أخرى!
        }
    }
}
```

</div>

للدوال التي ترمي، استخدم `withCheckedThrowingContinuation`:

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

#### AsyncStream - ربط مصادر الأحداث

<div class="analogy">
مثل إعداد إعادة توجيه البريد - في كل مرة تصل رسالة إلى العنوان القديم، يتم توجيهها تلقائياً إلى صندوق بريدك الجديد. يستمر التدفق في التدفق طالما استمر البريد في القدوم.
</div>

بينما تتعامل `withCheckedContinuation` مع callbacks لمرة واحدة، تقدم العديد من APIs قيماً متعددة بمرور الوقت - أساليب delegate، NotificationCenter، أو أنظمة أحداث مخصصة. `AsyncStream` يربط هذه بـ `AsyncSequence` في Swift، مما يتيح لك استخدام حلقات `for await`. تنشئ تياراً، تخزن استمراريته، وتستدعي `yield()` في كل مرة تصل قيمة جديدة.

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

// الاستخدام
let tracker = LocationTracker()
for await location in tracker.locations {
    print("موقع جديد: \(location)")
}
```

#### Task.isCancelled - الإلغاء التعاوني

<div class="analogy">
مثل التحقق من صندوق بريدك الوارد بحثاً عن مذكرة "توقف عن العمل على هذا" قبل بدء كل خطوة من مشروع كبير. لا يُجبر عليك التوقف - تختار التحقق والاستجابة بأدب.
</div>

يستخدم Swift الإلغاء التعاوني - عندما يتم إلغاء مهمة، لا تتوقف على الفور. بدلاً من ذلك، يتم تعيين علامة، ومسؤوليتك التحقق منها بشكل دوري. هذا يمنحك السيطرة على التنظيف والنتائج الجزئية. استخدم `Task.checkCancellation()` لرمي على الفور، أو تحقق من `Task.isCancelled` عندما تريد التعامل مع الإلغاء بلطف (مثل إرجاع نتائج جزئية).

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // تحقق قبل كل عملية مكلفة
        try Task.checkCancellation()  // يرمي إذا تم الإلغاء

        // أو تحقق بدون رمي
        if Task.isCancelled {
            return results  // إرجاع النتائج الجزئية
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - الهروب من السياق الحالي

<div class="analogy">
مثل توظيف مقاول خارجي لا يتبع قسمك. يعملون بشكل مستقل، لا يتبعون قواعد مكتبك، وعليك التنسيق صراحةً عندما تحتاج إلى النتائج.
</div>

`Task { }` عادي يرث سياق actor الحالي - إذا كنت على `@MainActor`، تعمل المهمة على `@MainActor`. في بعض الأحيان هذا ليس ما تريده، خاصة للعمل المكثف على المعالج الذي سيحظر واجهة المستخدم. `Task.detached` ينشئ مهمة بدون سياق موروث، تعمل على منفذ في الخلفية. استخدمها بشكل متحفظ رغم ذلك - في معظم الأحيان، `Task` عادي مع نقاط `await` مناسبة كافٍ وأسهل للتفكير فيه.

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item detached">منفصل</span>
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
        // لا تفعل: هذا لا يزال يرث سياق MainActor
        Task {
            let filtered = applyFilters(image)  // يحظر main!
        }

        // افعل: مهمة منفصلة تعمل بشكل مستقل
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
<h4>Task.detached عادة ما يكون خاطئاً</h4>

في معظم الأحيان، تريد `Task` عادياً. المهام المنفصلة لا ترث الأولوية، أو القيم المحلية للمهمة، أو سياق actor. استخدمها فقط عندما تحتاج صراحةً إلى ذلك الفصل.
</div>

#### @preconcurrency - التعايش مع الكود القديم

اكتم التحذيرات عند استيراد الوحدات التي لم يتم تحديثها بعد للتزامن:

```swift
// كتم التحذيرات من هذا الاستيراد
@preconcurrency import OldFramework

// أو على مطابقة بروتوكول
class MyDelegate: @preconcurrency SomeOldDelegate {
    // لن يحذر بشأن متطلبات non-Sendable
}
```

<div class="tip">
<h4>@preconcurrency مؤقت</h4>

استخدمه كجسر أثناء تحديث الكود. الهدف هو إزالته في النهاية والحصول على مطابقة Sendable مناسبة.
</div>

## قراءة إضافية

يقطر هذا الدليل أفضل الموارد حول تزامن Swift.

<div class="resources">
<h4>مدونة Matt Massicotte (موصى به بشدة)</h4>

- [مسرد التزامن في Swift](https://www.massicotte.org/concurrency-glossary) - المصطلحات الأساسية
- [مقدمة للعزل](https://www.massicotte.org/intro-to-isolation/) - المفهوم الأساسي
- [متى يجب عليك استخدام actor؟](https://www.massicotte.org/actors/) - إرشادات عملية
- [أنواع Non-Sendable رائعة أيضاً](https://www.massicotte.org/non-sendable/) - لماذا الأبسط أفضل
- [عبور الحدود](https://www.massicotte.org/crossing-the-boundary/) - العمل مع أنواع non-Sendable
- [أنماط التزامن في Swift المشكلة](https://www.massicotte.org/problematic-patterns/) - ما يجب تجنبه
- [ارتكاب الأخطاء مع التزامن في Swift](https://www.massicotte.org/mistakes-with-concurrency/) - التعلم من الأخطاء
</div>

<div class="resources">
<h4>موارد Apple الرسمية</h4>

- [توثيق التزامن في Swift](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: تعرف على async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: احمِ الحالة القابلة للتغيير مع actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: قضِ على سباقات البيانات](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>دروس تعليمية</h4>

- [التزامن في Swift بالأمثلة - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Async await في Swift - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

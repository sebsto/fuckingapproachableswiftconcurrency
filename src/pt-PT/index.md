---
layout: base.njk
title: Swift Concurrency Estupidamente Acessível
description: Um guia sem rodeios sobre concorrência em Swift. Aprenda async/await, actors, Sendable e MainActor com modelos mentais claros. Sem jargão, apenas explicações compreensíveis.
lang: pt-PT
dir: ltr
nav:
  isolation: Isolamento
  domains: Domínios
  patterns: Padrões
  errors: Erros
footer:
  madeWith: Feito com frustração e amor. Porque concorrência em Swift não tem de ser confusa.
  viewOnGitHub: Ver no GitHub
---

<section class="hero">
  <div class="container">
    <h1>Estupidamente Acessível<br><span class="accent">Swift Concurrency</span></h1>
    <p class="subtitle">Finalmente perceba async/await, actors e Sendable. Modelos mentais claros, sem jargão.</p>
    <p class="credit">Enorme agradecimento a <a href="https://www.massicotte.org/">Matt Massicotte</a> por tornar a concorrência em Swift compreensível. Compilado por <a href="https://pepicrft.me">Pedro Piñera</a>. Encontrou um erro? <a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute">Na tradição de <a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a> e <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a></p>
    <p class="cta-tuist">Expanda o seu desenvolvimento com <a href="https://tuist.dev">Tuist</a></p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## A Verdade Nua e Crua

Não existe receita mágica para concorrência em Swift. Cada resposta "basta fazer X" está errada em algum contexto.

**Mas aqui está a boa notícia:** Assim que compreenda o [isolamento](#basics) (5 min de leitura), tudo faz sentido. Os erros do compilador começam a fazer sentido. Deixa de lutar contra o sistema e começa a trabalhar com ele.

*Este guia é direcionado para Swift 6+. A maioria dos conceitos aplica-se ao Swift 5.5+, mas o Swift 6 aplica verificação de concorrência mais rigorosa.*

<a href="#basics" class="read-more">Comece com o modelo mental &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## A Única Coisa Que Precisa de Compreender

**[Isolamento](https://www.massicotte.org/intro-to-isolation/)** é a chave para tudo. É a resposta do Swift à pergunta: *Quem tem permissão para mexer nestes dados agora?*

<div class="analogy">
<h4>O Edifício de Escritórios</h4>

Pense na sua app como um **edifício de escritórios**. Cada escritório é um **domínio de isolamento** - um espaço privado onde apenas uma pessoa pode trabalhar de cada vez. Não pode simplesmente invadir o escritório de outra pessoa e começar a reorganizar a secretária dela.

Vamos construir sobre esta analogia ao longo do guia.
</div>

### Porquê Não Apenas Threads?

Durante décadas, escrevemos código concorrente a pensar em threads. O problema? **Threads não nos impedem de dar um tiro no pé.** Duas threads podem aceder aos mesmos dados simultaneamente, causando data races - bugs que crasham aleatoriamente e são quase impossíveis de reproduzir.

Num telemóvel, pode safar-se. Num servidor a lidar com milhares de pedidos concorrentes, data races tornam-se uma certeza - geralmente a aparecer em produção, numa sexta-feira. À medida que o Swift se expande para servidores e outros ambientes altamente concorrentes, "esperar o melhor" não funciona.

A abordagem antiga era defensiva: usar locks, dispatch queues, esperar não ter esquecido nada.

A abordagem do Swift é diferente: **tornar data races impossíveis em tempo de compilação.** Em vez de perguntar "em que thread está isto?", o Swift pergunta "quem tem permissão para mexer nestes dados agora?" Isto é isolamento.

### Como Outras Linguagens Lidam Com Isso

| Linguagem | Abordagem | Quando descobre os bugs |
|-----------|-----------|------------------------------|
| **Swift** | Isolamento + Sendable | Tempo de compilação |
| **Rust** | Ownership + borrow checker | Tempo de compilação |
| **Kotlin** | Coroutines + concorrência estruturada | Parcialmente em compilação |
| **Go** | Channels + detector de races | Runtime (com ferramentas) |
| **Java** | `synchronized`, locks | Runtime (crashes) |
| **JavaScript** | Event loop single-threaded | Evitado completamente |
| **C/C++** | Locks manuais | Runtime (comportamento indefinido) |

Swift e Rust oferecem as garantias mais fortes em tempo de compilação contra data races. Kotlin Coroutines oferece concorrência estruturada semelhante ao async/await do Swift, mas sem o mesmo nível de enforcement no sistema de tipos para thread safety. O trade-off? Uma curva de aprendizagem mais íngreme no início. Mas assim que compreende o modelo, o compilador protege-o.

Aqueles erros chatos sobre `Sendable` e isolamento de actor? Estão a detetar bugs que antes seriam crashes silenciosos.

  </div>
</section>

<section id="domains">
  <div class="container">

## Os Domínios de Isolamento

Agora que compreende isolamento (escritórios privados), vamos olhar para os diferentes tipos de escritórios no edifício do Swift.

<div class="analogy">
<h4>O Edifício de Escritórios</h4>

- **A receção** (`MainActor`) - onde todas as interações com clientes acontecem. Só existe uma, e ela lida com tudo o que o utilizador vê.
- **Escritórios de departamento** (`actor`) - contabilidade, jurídico, RH. Cada departamento tem o seu próprio escritório a proteger os seus dados sensíveis.
- **Corredores e áreas comuns** (`nonisolated`) - espaços partilhados por onde qualquer um pode passar. Sem dados privados aqui.
</div>

### MainActor: A Receção

O `MainActor` é um domínio de isolamento especial que corre na thread principal. É onde todo o trabalho de UI acontece.

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // Estado da UI vive aqui

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // Seguro - estamos no MainActor
    }
}
```

<div class="tip">
<h4>Na dúvida, use MainActor</h4>

Para a maioria das apps, marcar os seus ViewModels e classes relacionadas com UI com `@MainActor` é a escolha certa. Preocupações com performance geralmente são exageradas - comece aqui, otimize apenas se medir problemas reais.
</div>

### Actors: Escritórios de Departamento

Um `actor` é como um escritório de departamento - protege os seus próprios dados e permite apenas um visitante de cada vez.

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // Seguro! Apenas um chamador por vez
    }
}
```

Sem actors, duas threads leem balance = 100, ambas somam 50, ambas escrevem 150 - você perdeu $50. Com actors, o Swift automaticamente enfileira o acesso e ambos os depósitos completam corretamente.

<div class="warning">
<h4>Não abuse dos actors</h4>

Você precisa de um actor personalizado apenas quando **todas as quatro** condições são verdadeiras:
1. Você tem estado mutável não-Sendable (não thread-safe)
2. Múltiplos lugares precisam acessar
3. Operações nesse estado devem ser atômicas
4. Não pode simplesmente viver no MainActor

Se alguma condição for falsa, você provavelmente não precisa de um actor. A maioria do estado de UI pode viver no `@MainActor`. [Leia mais sobre quando usar actors](https://www.massicotte.org/actors/).
</div>

### Nonisolated: Os Corredores

Código marcado como `nonisolated` é como os corredores - não pertence a nenhum escritório e pode ser acessado de qualquer lugar.

```swift
actor UserSession {
    let userId: String          // Imutável - seguro ler de qualquer lugar
    var lastActivity: Date      // Mutável - precisa proteção do actor

    nonisolated var displayId: String {
        "User: \(userId)"       // Só lê dados imutáveis
    }
}

// Uso - não precisa de await para nonisolated
let session = UserSession(userId: "123")
print(session.displayId)  // Funciona sincronamente!
```

Use `nonisolated` para propriedades computadas que só leem dados imutáveis.

  </div>
</section>

<section id="propagation">
  <div class="container">

## Como o Isolamento Se Propaga

Quando você marca um tipo com um isolamento de actor, o que acontece com seus métodos? E os closures? Entender como o isolamento se propaga é a chave para evitar surpresas.

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Quando você é contratado em um departamento, você trabalha no escritório desse departamento por padrão. Se o departamento de Marketing te contrata, você não aparece aleatoriamente na Contabilidade.

Da mesma forma, quando uma função é definida dentro de uma classe `@MainActor`, ela herda esse isolamento. Ela "trabalha no mesmo escritório" que seu pai.
</div>

### Classes Herdam Seu Isolamento

```swift
@MainActor
class ViewModel {
    var count = 0           // Isolado no MainActor

    func increment() {      // Também isolado no MainActor
        count += 1
    }
}
```

Tudo dentro da classe herda `@MainActor`. Você não precisa marcar cada método.

### Tasks Herdam o Contexto (Geralmente)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // Isso herda MainActor!
            self.updateUI()  // Seguro, nao precisa de await
        }
    }
}
```

Um `Task { }` criado de um contexto `@MainActor` fica no `MainActor`. Isso geralmente é o que você quer.

### Task.detached Quebra a Herança

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // NAO esta mais no MainActor!
            await self.updateUI()  // Agora precisa de await
        }
    }
}
```

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

`Task.detached` é como contratar um freelancer externo. Ele não tem crachá para seu escritório - ele trabalha do próprio espaço e precisa passar pelos canais apropriados para acessar suas coisas.
</div>

<div class="warning">
<h4>Task.detached geralmente está errado</h4>

Na maioria das vezes, você quer um `Task` regular. Tasks detached não herdam prioridade, valores task-local, ou contexto de actor. Use-os apenas quando você explicitamente precisar dessa separação.
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## O Que Pode Cruzar Fronteiras

Agora que você sabe sobre domínios de isolamento (escritórios) e como eles se propagam, a próxima pergunta é: **o que você pode passar entre eles?**

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Nem tudo pode sair de um escritório:

- **Fotocópias** são seguras de compartilhar - se o Jurídico faz uma cópia de um documento e envia para a Contabilidade, ambos têm sua própria cópia. Sem conflito.
- **Contratos originais assinados** devem ficar no lugar - se dois departamentos pudessem modificar o original, o caos acontece.

Em termos de Swift: tipos **Sendable** são fotocópias (seguras de compartilhar), tipos **não-Sendable** são originais (devem ficar em um escritório).
</div>

### Sendable: Seguro para Compartilhar

Esses tipos podem cruzar fronteiras de isolamento com segurança:

```swift
// Structs com dados imutáveis - como fotocópias
struct User: Sendable {
    let id: Int
    let name: String
}

// Actors se protegem - eles lidam com seus próprios visitantes
actor BankAccount { }  // Automaticamente Sendable
```

**Automaticamente Sendable:**
- Tipos de valor (structs, enums) com propriedades Sendable
- Actors (eles se protegem)
- Classes imutáveis (`final class` com apenas propriedades `let`)

### Não-Sendable: Devem Ficar

Esses tipos não podem cruzar fronteiras com segurança:

```swift
// Classes com estado mutável - como documentos originais
class Counter {
    var count = 0  // Dois escritórios modificando isso = desastre
}
```

**Por que essa é a distinção chave?** Porque todo erro de compilador que você encontrar se resume a: *"Você está tentando enviar um tipo não-Sendable através de uma fronteira de isolamento."*

### Quando o Compilador Reclama

Se o Swift diz que algo não é Sendable, você tem opções:

1. **Faça um tipo de valor** - use `struct` em vez de `class`
2. **Isole** - mantenha no `@MainActor` para que não precise cruzar
3. **Mantenha não-Sendable** - apenas não passe entre escritórios
4. **Último recurso:** `@unchecked Sendable` - você promete que é seguro (cuidado)

<div class="tip">
<h4>Comece não-Sendable</h4>

[Matt Massicotte defende](https://www.massicotte.org/non-sendable/) começar com tipos regulares, não-Sendable. Adicione `Sendable` apenas quando precisar cruzar fronteiras. Um tipo não-Sendable permanece simples e evita dores de cabeça de conformance.
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## Como Cruzar Fronteiras

Você entende domínios de isolamento, você sabe o que pode cruzá-los. Agora: **como você realmente se comunica entre escritórios?**

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Você não pode simplesmente invadir outro escritório. Você envia uma requisição e espera uma resposta. Você pode trabalhar em outras coisas enquanto espera, mas você precisa dessa resposta antes de poder continuar.

Isso é `async/await` - enviar uma requisição para outro domínio de isolamento e pausar até obter uma resposta.
</div>

### A Palavra-Chave await

Quando você chama uma função em outro actor, você precisa de `await`:

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
        await store.add(item)  // Requisição para outro escritório
        updateUI()             // De volta ao nosso escritório
    }
}
```

O `await` significa: "Envie essa requisição e pause até terminar. Posso fazer outro trabalho enquanto espero."

### Suspensão, Não Bloqueio

<div class="warning">
<h4>Conceito Errôneo Comum</h4>

Muitos desenvolvedores assumem que adicionar `async` faz o código rodar em segundo plano. Não faz. A palavra-chave `async` apenas significa que a função *pode pausar*. Não diz nada sobre *onde* ela roda.
</div>

A chave é a diferença entre **bloqueio** e **suspensão**:

- **Bloqueio**: Você senta na sala de espera olhando para a parede. Nada mais acontece.
- **Suspensão**: Você deixa seu telefone e faz outras coisas. Eles ligam quando estiver pronto.

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">Bloqueio</button>
<button>Suspensão</button>
</div>
<div class="code-tab-content active">

```swift
// Thread fica ociosa, sem fazer nada por 5 segundos
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// Thread está livre para fazer outro trabalho enquanto espera
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### Iniciando Trabalho Async de Código Síncrono

Às vezes você está em código síncrono e precisa chamar algo async. Use `Task`:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // Função síncrona
        Task {
            await loadData()  // Agora podemos usar await
        }
    }
}
```

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

`Task` é como atribuir trabalho a um funcionário. O funcionário lida com a requisição (incluindo esperar outros escritórios) enquanto você continua com seu trabalho imediato.
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## Padrões Que Funcionam

### O Padrão de Requisição de Rede

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (chamada de rede)</span>
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

        // Isso suspende - thread está livre para fazer outro trabalho
        let users = await networkService.getUsers()

        // De volta no MainActor automaticamente
        self.users = users
        isLoading = false
    }
}
```

</div>

Sem `DispatchQueue.main.async`. O atributo `@MainActor` cuida disso.

### Trabalho Paralelo com async let

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // Os tres rodam em paralelo!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### Prevenindo Toques Duplos

Esse padrão vem do guia de Matt Massicotte sobre [sistemas com estado](https://www.massicotte.org/step-by-step-stateful-systems):

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // Guard SINCRONAMENTE antes de qualquer trabalho async
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
<h4>Crítico: O guard deve ser síncrono</h4>

Se você colocar o guard dentro do Task depois de um await, há uma janela onde dois toques de botão podem ambos iniciar trabalho. [Aprenda mais sobre ordenação e concorrência](https://www.massicotte.org/ordering-and-concurrency).
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## Erros Comuns a Evitar

Esses são [erros comuns](https://www.massicotte.org/mistakes-with-concurrency/) que até desenvolvedores experientes cometem:

### Pensar que async = segundo plano

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Adicionar `async` não te move para um escritório diferente. Você ainda está na recepção - você só pode esperar entregas agora sem congelar no lugar.
</div>

```swift
// Isso AINDA bloqueia a thread principal!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // Síncrono = bloqueante
    data = result
}
```

Se você precisa de trabalho feito em outro escritório, envie explicitamente para lá:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // Agora em um escritório diferente
    }.value
    await MainActor.run { data = result }
}
```

### Criar muitos actors

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Criar um novo escritório para cada pedaço de dados significa papelada interminável para comunicar entre eles. A maioria do seu trabalho pode acontecer na recepção.
</div>

```swift
// Sobre-engenheirado - cada chamada requer caminhar entre escritórios
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// Melhor - a maioria das coisas pode viver na recepção
@MainActor
class AppState { }
```

### Usar MainActor.run em todo lugar

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Se você continua caminhando até a recepção para cada coisinha, apenas trabalhe lá. Faça parte da sua descrição de trabalho, não uma tarefa constante.
</div>

```swift
// Não faça isso - caminhando constantemente até a recepção
await MainActor.run { doMainActorStuff() }

// Faça isso - apenas trabalhe na recepção
@MainActor func doMainActorStuff() { }
```

### Fazer tudo Sendable

Nem tudo precisa ser `Sendable`. Se você está adicionando `@unchecked Sendable` em todo lugar, você está fazendo fotocópias de coisas que não precisam sair do escritório.

### Ignorar warnings do compilador

Cada warning do compilador sobre `Sendable` é o guarda de segurança te dizendo que algo não é seguro para carregar entre escritórios. Não ignore - [entenda](https://www.massicotte.org/complete-checking/).

  </div>
</section>

<section id="errors">
  <div class="container">

## Erros Comuns do Compilador

Essas são as mensagens de erro reais que você verá. Cada uma é o compilador te protegendo de um data race.

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Você está tentando carregar um documento original para outro escritório. Ou faça uma fotocópia (Sendable) ou mantenha em um lugar.
</div>

**Solução 1:** Use uma `struct` em vez de uma `class`

**Solução 2:** Mantenha em um actor:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // Fica na recepção
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Você está tentando carregar um original entre escritórios. O guarda de segurança te parou.
</div>

**Solução 1:** Faça uma struct:

```swift
// Antes: class (não-Sendable)
class User { var name: String }

// Depois: struct (Sendable)
struct User: Sendable { let name: String }
```

**Solução 2:** Isole em um actor:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Você está metendo a mão no arquivo de outro escritório sem passar pelos canais apropriados.
</div>

**Solução:** Use `await`:

```swift
// Errado - metendo a mão diretamente
let value = myActor.balance

// Certo - requisição apropriada
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Você está tentando usar a recepção sem esperar na fila.
</div>

**Solução 1:** Faça o chamador `@MainActor`:

```swift
@MainActor
func doSomething() {
    updateUI()  // Mesmo isolamento, não precisa de await
}
```

**Solução 2:** Use `await`:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## Três Níveis de Swift Concurrency

Você não precisa aprender tudo de uma vez. Progrida através desses níveis:

<div class="analogy">
<h4>O Prédio de Escritórios</h4>

Pense nisso como crescer uma empresa. Você não começa com uma sede de 50 andares - você começa com uma mesa.
</div>

Esses níveis não são limites rígidos - diferentes partes do seu app podem precisar de níveis diferentes. Um app principalmente-Nível-1 pode ter uma feature que precisa de padrões de Nível 2. Tudo bem. Use a abordagem mais simples que funcione para cada parte.

### Nível 1: A Startup

Todos trabalham na recepção. Simples, direto, sem burocracia.

- Use `async/await` para chamadas de rede
- Marque classes de UI com `@MainActor`
- Use o modificador `.task` do SwiftUI

Isso cobre 80% dos apps. Apps como [Things](https://culturedcode.com/things/), [Bear](https://bear.app/), [Flighty](https://flighty.com/), ou [Day One](https://dayoneapp.com/) provavelmente caem nessa categoria - apps que principalmente buscam dados e os exibem.

### Nível 2: A Empresa em Crescimento

Você precisa lidar com múltiplas coisas de uma vez. Hora de projetos paralelos e coordenar equipes.

- Use `async let` para trabalho paralelo
- Use `TaskGroup` para paralelismo dinâmico
- Entenda cancelamento de tasks

Apps como [Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp) (clientes Mastodon gerenciando múltiplas timelines e atualizações em streaming), [Overcast](https://overcast.fm/) (coordenando downloads, reprodução e sincronização em segundo plano), ou [Slack](https://slack.com/) (mensagens em tempo real através de múltiplos canais) podem usar esses padrões para certas features.

### Nível 3: A Corporação

Departamentos dedicados com suas próprias políticas. Comunicação inter-escritório complexa.

- Crie actors personalizados para estado compartilhado
- Entendimento profundo de Sendable
- Executors personalizados

Apps como [Xcode](https://developer.apple.com/xcode/), [Final Cut Pro](https://www.apple.com/final-cut-pro/), ou frameworks Swift server-side como [Vapor](https://vapor.codes/) e [Hummingbird](https://hummingbird.codes/) provavelmente precisam desses padrões - estado compartilhado complexo, milhares de conexões concorrentes, ou código nível-framework sobre o qual outros constroem.

<div class="tip">
<h4>Comece simples</h4>

A maioria dos apps nunca precisa do Nível 3. Não construa uma corporação quando uma startup é suficiente.
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## Glossário: Mais Palavras-Chave Que Você Encontrará

Além dos conceitos básicos, aqui estão outras palavras-chave de concorrência do Swift que você verá no mundo real:

| Palavra-chave | O que significa |
|---------------|-----------------|
| `nonisolated` | Opta por sair do isolamento de um actor - roda sem proteção |
| `isolated` | Declara explicitamente que um parâmetro roda no contexto de um actor |
| `@Sendable` | Marca um closure como seguro para passar através de fronteiras de isolamento |
| `Task.detached` | Cria um task completamente separado do contexto atual |
| `AsyncSequence` | Uma sequência que você pode iterar com `for await` |
| `AsyncStream` | Uma forma de conectar código baseado em callbacks com sequências async |
| `withCheckedContinuation` | Conecta completion handlers com async/await |
| `Task.isCancelled` | Verifica se o task atual foi cancelado |
| `@preconcurrency` | Suprime warnings de concorrência para código legado |
| `GlobalActor` | Protocolo para criar seus próprios actors personalizados como MainActor |

### Quando Usar Cada Um

#### nonisolated - Ler propriedades computadas

<div class="analogy">
Como uma placa de nome na porta do seu escritório - qualquer um passando pode lê-la sem precisar entrar e esperar por você.
</div>

Por padrão, tudo dentro de um actor está isolado - você precisa de `await` para acessar. Mas às vezes você tem propriedades que são inerentemente seguras de ler: constantes `let` imutáveis, ou propriedades computadas que só derivam valores de outros dados seguros. Marcar essas como `nonisolated` permite que chamadores as acessem sincronamente, evitando overhead async desnecessário.

<div class="isolation-legend">
  <span class="isolation-legend-item actor">Actor-isolated</span>
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
    let userId: String  // Imutável, seguro de ler
    var lastActivity: Date  // Mutável, precisa proteção

    // Isso pode ser chamado sem await
    nonisolated var displayId: String {
        "User: \(userId)"  // Só lê dados imutáveis
    }
}
```

</div>

```swift
// Uso
let session = UserSession(userId: "123")
print(session.displayId)  // Não precisa de await!
```

#### @Sendable - Closures que cruzam fronteiras

<div class="analogy">
Como um envelope selado com instruções dentro - o envelope pode viajar entre escritórios, e quem abrir pode seguir as instruções com segurança.
</div>

Quando um closure escapa para rodar mais tarde ou em um domínio de isolamento diferente, o Swift precisa garantir que não causará data races. O atributo `@Sendable` marca closures que são seguros de passar através de fronteiras - eles não podem capturar estado mutável de forma insegura. O Swift frequentemente infere isso automaticamente (como com `Task.detached`), mas às vezes você precisa declarar explicitamente ao projetar APIs que aceitam closures.

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // Esse closure cruza do task detached para o MainActor
            // Deve ser @Sendable (Swift infere isso)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// @Sendable explícito quando necessário
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - Conectando APIs antigas

<div class="analogy">
Como um tradutor entre o sistema antigo de memorandos em papel e email moderno. Você espera no correio até o sistema antigo entregar uma resposta, então encaminha pelo novo sistema.
</div>

Muitas APIs antigas usam completion handlers em vez de async/await. Em vez de reescrevê-las completamente, você pode envolvê-las usando `withCheckedContinuation`. Essa função suspende o task atual, te dá um objeto continuation, e retoma quando você chama `continuation.resume()`. A variante "checked" detecta erros de programação como resumir duas vezes ou nunca resumir.

<div class="isolation-legend">
  <span class="isolation-legend-item main">Contexto async</span>
  <span class="isolation-legend-item nonisolated">Contexto callback</span>
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
// API antiga baseada em callbacks
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... chamada de rede com callback
}

// Envolvida como async
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // Conecta de volta!
        }
    }
}
```

</div>

Para funções que lançam, use `withCheckedThrowingContinuation`:

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

#### AsyncStream - Conectando fontes de eventos

<div class="analogy">
Como configurar redirecionamento de correio - cada vez que uma carta chega no endereço antigo, automaticamente é roteada para sua nova caixa. O stream continua fluindo enquanto o correio continua chegando.
</div>

Enquanto `withCheckedContinuation` lida com callbacks únicos, muitas APIs entregam múltiplos valores ao longo do tempo - métodos delegate, NotificationCenter, ou sistemas de eventos personalizados. `AsyncStream` conecta esses ao `AsyncSequence` do Swift, permitindo que você use loops `for await`. Você cria um stream, guarda sua continuation, e chama `yield()` cada vez que um novo valor chega.

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

// Uso
let tracker = LocationTracker()
for await location in tracker.locations {
    print("Nova localização: \(location)")
}
```

#### Task.isCancelled - Cancelamento cooperativo

<div class="analogy">
Como verificar sua caixa de entrada por um memo de "pare de trabalhar nisso" antes de começar cada passo de um projeto grande. Você não é forçado a parar - você escolhe verificar e responder educadamente.
</div>

Swift usa cancelamento cooperativo - quando um task é cancelado, ele não para imediatamente. Em vez disso, uma flag é definida, e é sua responsabilidade verificá-la periodicamente. Isso te dá controle sobre limpeza e resultados parciais. Use `Task.checkCancellation()` para lançar imediatamente, ou verifique `Task.isCancelled` quando quiser lidar com cancelamento graciosamente (como retornando resultados parciais).

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // Verifica antes de cada operação cara
        try Task.checkCancellation()  // Lança se cancelado

        // Ou verifica sem lançar
        if Task.isCancelled {
            return results  // Retorna resultados parciais
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - Escapando do contexto atual

<div class="analogy">
Como contratar um freelancer externo que não reporta ao seu departamento. Ele trabalha independentemente, não segue as regras do seu escritório, e você precisa coordenar explicitamente quando precisa de resultados de volta.
</div>

Um `Task { }` regular herda o contexto atual do actor - se você está no `@MainActor`, o task roda no `@MainActor`. Às vezes isso não é o que você quer, especialmente para trabalho intensivo de CPU que bloquearia a UI. `Task.detached` cria um task sem contexto herdado, rodando em um executor de fundo. Use com moderação - na maioria das vezes, `Task` regular com pontos `await` apropriados é suficiente e mais fácil de raciocinar.

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
        // NÃO FAÇA: Isso ainda herda o contexto do MainActor
        Task {
            let filtered = applyFilters(image)  // Bloqueia main!
        }

        // FAÇA: Task detached roda independentemente
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
<h4>Task.detached geralmente está errado</h4>

Na maioria das vezes, você quer um `Task` regular. Tasks detached não herdam prioridade, valores task-local, ou contexto de actor. Use-os apenas quando você explicitamente precisar dessa separação.
</div>

#### @preconcurrency - Vivendo com código legado

Silencia warnings ao importar módulos ainda não atualizados para concorrência:

```swift
// Suprime warnings desse import
@preconcurrency import OldFramework

// Ou em uma conformance de protocolo
class MyDelegate: @preconcurrency SomeOldDelegate {
    // Não avisa sobre requisitos não-Sendable
}
```

<div class="tip">
<h4>@preconcurrency é temporário</h4>

Use como uma ponte enquanto atualiza código. O objetivo é eventualmente removê-lo e ter conformance Sendable apropriada.
</div>

## Leitura Adicional

Este guia destila os melhores recursos sobre concorrência em Swift.

<div class="resources">
<h4>Blog de Matt Massicotte (Altamente Recomendado)</h4>

- [A Swift Concurrency Glossary](https://www.massicotte.org/concurrency-glossary) - Terminologia essencial
- [An Introduction to Isolation](https://www.massicotte.org/intro-to-isolation/) - O conceito central
- [When should you use an actor?](https://www.massicotte.org/actors/) - Guia prático
- [Non-Sendable types are cool too](https://www.massicotte.org/non-sendable/) - Por que mais simples é melhor
- [Crossing the Boundary](https://www.massicotte.org/crossing-the-boundary/) - Trabalhando com tipos não-Sendable
- [Problematic Swift Concurrency Patterns](https://www.massicotte.org/problematic-patterns/) - O que evitar
- [Making Mistakes with Swift Concurrency](https://www.massicotte.org/mistakes-with-concurrency/) - Aprendendo com erros
</div>

<div class="resources">
<h4>Recursos Oficiais da Apple</h4>

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: Meet async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Protect mutable state with actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>Tutoriais</h4>

- [Swift Concurrency by Example - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Async await in Swift - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

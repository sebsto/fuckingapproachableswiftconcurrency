---
layout: base.njk
title: Swift Concurrency Jodidamente Accesible
description: Una guía sin rodeos sobre la concurrencia en Swift. Aprende async/await, actors, Sendable y MainActor con modelos mentales claros. Sin jerga, solo explicaciones comprensibles.
lang: es
dir: ltr
nav:
  isolation: Aislamiento
  domains: Dominios
  patterns: Patrones
  errors: Errores
footer:
  madeWith: Hecho con frustración y amor. Porque la concurrencia en Swift no tiene que ser confusa.
  viewOnGitHub: Ver en GitHub
---

<section class="hero">
  <div class="container">
    <h1>Jodidamente Accesible<br><span class="accent">Swift Concurrency</span></h1>
    <p class="subtitle">Por fin comprende async/await, actors y Sendable. Modelos mentales claros, sin jerga.</p>
    <p class="credit">Enorme agradecimiento a <a href="https://www.massicotte.org/">Matt Massicotte</a> por hacer comprensible la concurrencia en Swift. Recopilado por <a href="https://pepicrft.me">Pedro Piñera</a>. ¿Encontraste un error? <a href="mailto:pedro@tuist.dev">pedro@tuist.dev</a></p>
    <p class="tribute">En la tradición de <a href="https://fuckingblocksyntax.com/">fuckingblocksyntax.com</a> y <a href="https://fuckingifcaseletsyntax.com/">fuckingifcaseletsyntax.com</a></p>
    <p class="cta-tuist">Escala tu desarrollo con <a href="https://tuist.dev">Tuist</a></p>
  </div>
</section>

<section class="tldr">
  <div class="container">

## La Verdad Honesta

No existe una chuleta para la concurrencia en Swift. Cada respuesta de "simplemente haz X" está mal en algún contexto.

**Pero aquí está la buena noticia:** Una vez que entiendas el [aislamiento](#basics) (5 min de lectura), todo encaja. Los errores del compilador empiezan a tener sentido. Dejas de luchar contra el sistema y empiezas a trabajar con él.

*Esta guía está orientada a Swift 6+. La mayoría de conceptos aplican a Swift 5.5+, pero Swift 6 aplica una verificación de concurrencia más estricta.*

<a href="#basics" class="read-more">Empieza con el modelo mental &darr;</a>

  </div>
</section>

<section id="basics">
  <div class="container">

## Lo Único Que Necesitas Entender

**[El aislamiento](https://www.massicotte.org/intro-to-isolation/)** es la clave de todo. Es la respuesta de Swift a la pregunta: *¿Quién tiene permiso para tocar estos datos ahora mismo?*

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Piensa en tu app como un **edificio de oficinas**. Cada oficina es un **dominio de aislamiento** - un espacio privado donde solo una persona puede trabajar a la vez. No puedes simplemente irrumpir en la oficina de otra persona y empezar a reorganizar su escritorio.

Construiremos sobre esta analogía a lo largo de la guía.
</div>

### ¿Por Qué No Solo Hilos?

Durante décadas, escribimos código concurrente pensando en hilos. ¿El problema? **Los hilos no te impiden dispararte en el pie.** Dos hilos pueden acceder a los mismos datos simultáneamente, causando data races - bugs que crashean aleatoriamente y son casi imposibles de reproducir.

En un teléfono, quizás te salgas con la tuya. En un servidor manejando miles de peticiones concurrentes, los data races se vuelven una certeza - usualmente apareciendo en producción, un viernes. A medida que Swift se expande a servidores y otros entornos altamente concurrentes, "esperar lo mejor" no es suficiente.

El enfoque antiguo era defensivo: usar locks, dispatch queues, esperar no haber olvidado nada.

El enfoque de Swift es diferente: **hacer imposibles los data races en tiempo de compilación.** En lugar de preguntar "¿en qué hilo está esto?", Swift pregunta "¿quién tiene permiso para tocar estos datos ahora mismo?" Eso es el aislamiento.

### Cómo Otros Lenguajes Manejan Esto

| Lenguaje | Enfoque | Cuándo descubres los bugs |
|----------|---------|---------------------------|
| **Swift** | Aislamiento + Sendable | Tiempo de compilación |
| **Rust** | Ownership + borrow checker | Tiempo de compilación |
| **Kotlin** | Coroutines + concurrencia estructurada | Parcialmente en compilación |
| **Go** | Channels + detector de races | Runtime (con herramientas) |
| **Java** | `synchronized`, locks | Runtime (crashes) |
| **JavaScript** | Event loop single-threaded | Evitado completamente |
| **C/C++** | Locks manuales | Runtime (comportamiento indefinido) |

Swift y Rust ofrecen las garantías más fuertes en tiempo de compilación contra data races. Kotlin Coroutines ofrece concurrencia estructurada similar al async/await de Swift, pero sin el mismo nivel de enforcement en el sistema de tipos para thread safety. ¿El trade-off? Una curva de aprendizaje más empinada al principio. Pero una vez que entiendes el modelo, el compilador te respalda.

¿Esos molestos errores sobre `Sendable` y aislamiento de actor? Están detectando bugs que antes habrían sido crashes silenciosos.

  </div>
</section>

<section id="domains">
  <div class="container">

## Los Dominios de Aislamiento

Ahora que entiendes el aislamiento (oficinas privadas), veamos los diferentes tipos de oficinas en el edificio de Swift.

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

- **La recepción** (`MainActor`) - donde ocurren todas las interacciones con clientes. Solo hay una, y maneja todo lo que el usuario ve.
- **Oficinas de departamento** (`actor`) - contabilidad, legal, RRHH. Cada departamento tiene su propia oficina protegiendo sus propios datos sensibles.
- **Pasillos y áreas comunes** (`nonisolated`) - espacios compartidos por donde cualquiera puede caminar. Sin datos privados aquí.
</div>

### MainActor: La Recepción

El `MainActor` es un dominio de aislamiento especial que se ejecuta en el hilo principal. Es donde ocurre todo el trabajo de UI.

```swift
@MainActor
@Observable
class ViewModel {
    var items: [Item] = []  // El estado de UI vive aquí

    func refresh() async {
        let newItems = await fetchItems()
        self.items = newItems  // Seguro - estamos en MainActor
    }
}
```

<div class="tip">
<h4>En caso de duda, usa MainActor</h4>

Para la mayoría de apps, marcar tus ViewModels y clases relacionadas con UI con `@MainActor` es la elección correcta. Las preocupaciones de rendimiento suelen estar exageradas - empieza aquí, optimiza solo si mides problemas reales.
</div>

### Actors: Oficinas de Departamento

Un `actor` es como una oficina de departamento - protege sus propios datos y solo permite un visitante a la vez.

```swift
actor BankAccount {
    var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount  // ¡Seguro! Solo un llamador a la vez
    }
}
```

Sin actors, dos hilos leen balance = 100, ambos suman 50, ambos escriben 150 - perdiste $50. Con actors, Swift automáticamente encola el acceso y ambos depósitos se completan correctamente.

<div class="warning">
<h4>No abuses de los actors</h4>

Necesitas un actor personalizado solo cuando **las cuatro** condiciones son verdaderas:
1. Tienes estado mutable no-Sendable (no thread-safe)
2. Múltiples lugares necesitan acceder a él
3. Las operaciones sobre ese estado deben ser atómicas
4. No puede simplemente vivir en MainActor

Si alguna condición es falsa, probablemente no necesitas un actor. La mayoría del estado de UI puede vivir en `@MainActor`. [Lee más sobre cuándo usar actors](https://www.massicotte.org/actors/).
</div>

### Nonisolated: Los Pasillos

El código marcado como `nonisolated` es como los pasillos - no pertenece a ninguna oficina y puede ser accedido desde cualquier lugar.

```swift
actor UserSession {
    let userId: String          // Inmutable - seguro de leer desde cualquier lugar
    var lastActivity: Date      // Mutable - necesita protección del actor

    nonisolated var displayId: String {
        "User: \(userId)"       // Solo lee datos inmutables
    }
}

// Uso - no se necesita await para nonisolated
let session = UserSession(userId: "123")
print(session.displayId)  // ¡Funciona síncronamente!
```

Usa `nonisolated` para propiedades computadas que solo leen datos inmutables.

  </div>
</section>

<section id="propagation">
  <div class="container">

## Cómo Se Propaga el Aislamiento

Cuando marcas un tipo con un aislamiento de actor, ¿qué pasa con sus métodos? ¿Y con los closures? Entender cómo se propaga el aislamiento es clave para evitar sorpresas.

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Cuando te contratan en un departamento, trabajas en la oficina de ese departamento por defecto. Si el departamento de Marketing te contrata, no apareces aleatoriamente en Contabilidad.

De manera similar, cuando una función se define dentro de una clase `@MainActor`, hereda ese aislamiento. "Trabaja en la misma oficina" que su padre.
</div>

### Las Clases Heredan Su Aislamiento

```swift
@MainActor
class ViewModel {
    var count = 0           // Aislado en MainActor

    func increment() {      // También aislado en MainActor
        count += 1
    }
}
```

Todo dentro de la clase hereda `@MainActor`. No necesitas marcar cada método.

### Los Tasks Heredan el Contexto (Usualmente)

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task {
            // ¡Esto hereda MainActor!
            self.updateUI()  // Seguro, no se necesita await
        }
    }
}
```

Un `Task { }` creado desde un contexto `@MainActor` se queda en `MainActor`. Esto es usualmente lo que quieres.

### Task.detached Rompe la Herencia

```swift
@MainActor
class ViewModel {
    func doWork() {
        Task.detached {
            // ¡YA NO está en MainActor!
            await self.updateUI()  // Ahora necesita await
        }
    }
}
```

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

`Task.detached` es como contratar a un contratista externo. No tienen credencial para tu oficina - trabajan desde su propio espacio y deben pasar por canales apropiados para acceder a tus cosas.
</div>

<div class="warning">
<h4>Task.detached usualmente está mal</h4>

La mayoría del tiempo, quieres un `Task` regular. Los tasks detached no heredan prioridad, valores task-local, o contexto de actor. Úsalos solo cuando explícitamente necesites esa separación.
</div>

  </div>
</section>

<section id="sendable">
  <div class="container">

## Qué Puede Cruzar Fronteras

Ahora que sabes sobre dominios de aislamiento (oficinas) y cómo se propagan, la siguiente pregunta es: **¿qué puedes pasar entre ellos?**

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

No todo puede salir de una oficina:

- **Las fotocopias** son seguras de compartir - si Legal hace una copia de un documento y la envía a Contabilidad, ambos tienen su propia copia. Sin conflicto.
- **Los contratos originales firmados** deben quedarse donde están - si dos departamentos pudieran modificar el original, se produce el caos.

En términos de Swift: los tipos **Sendable** son fotocopias (seguras de compartir), los tipos **no-Sendable** son originales (deben quedarse en una oficina).
</div>

### Sendable: Seguro para Compartir

Estos tipos pueden cruzar fronteras de aislamiento de forma segura:

```swift
// Structs con datos inmutables - como fotocopias
struct User: Sendable {
    let id: Int
    let name: String
}

// Los actors se protegen a sí mismos - manejan sus propios visitantes
actor BankAccount { }  // Automáticamente Sendable
```

**Automáticamente Sendable:**
- Tipos de valor (structs, enums) con propiedades Sendable
- Actors (se protegen a sí mismos)
- Clases inmutables (`final class` con solo propiedades `let`)

### No-Sendable: Deben Quedarse

Estos tipos no pueden cruzar fronteras de forma segura:

```swift
// Clases con estado mutable - como documentos originales
class Counter {
    var count = 0  // Dos oficinas modificando esto = desastre
}
```

**¿Por qué es esta la distinción clave?** Porque cada error del compilador que encontrarás se reduce a: *"Estás intentando enviar un tipo no-Sendable a través de una frontera de aislamiento."*

### Cuando el Compilador Se Queja

Si Swift dice que algo no es Sendable, tienes opciones:

1. **Hazlo un tipo de valor** - usa `struct` en lugar de `class`
2. **Aíslalo** - mantenlo en `@MainActor` para que no necesite cruzar
3. **Mantenlo no-Sendable** - simplemente no lo pases entre oficinas
4. **Último recurso:** `@unchecked Sendable` - prometes que es seguro (ten cuidado)

<div class="tip">
<h4>Empieza no-Sendable</h4>

[Matt Massicotte recomienda](https://www.massicotte.org/non-sendable/) empezar con tipos regulares, no-Sendable. Añade `Sendable` solo cuando necesites cruzar fronteras. Un tipo no-Sendable se mantiene simple y evita dolores de cabeza de conformance.
</div>

  </div>
</section>

<section id="async-await">
  <div class="container">

## Cómo Cruzar Fronteras

Entiendes los dominios de aislamiento, sabes qué puede cruzarlos. Ahora: **¿cómo te comunicas realmente entre oficinas?**

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

No puedes simplemente irrumpir en otra oficina. Envías una solicitud y esperas una respuesta. Podrías trabajar en otras cosas mientras esperas, pero necesitas esa respuesta antes de poder continuar.

Eso es `async/await` - enviar una solicitud a otro dominio de aislamiento y pausar hasta obtener una respuesta.
</div>

### La Palabra Clave await

Cuando llamas a una función en otro actor, necesitas `await`:

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
        await store.add(item)  // Solicitud a otra oficina
        updateUI()             // De vuelta en nuestra oficina
    }
}
```

El `await` significa: "Envía esta solicitud y pausa hasta que termine. Podría hacer otro trabajo mientras espero."

### Suspensión, No Bloqueo

<div class="warning">
<h4>Concepto Erróneo Común</h4>

Muchos desarrolladores asumen que añadir `async` hace que el código se ejecute en segundo plano. No es así. La palabra clave `async` solo significa que la función *puede pausar*. No dice nada sobre *dónde* se ejecuta.
</div>

La clave es la diferencia entre **bloqueo** y **suspensión**:

- **Bloqueo**: Te sientas en la sala de espera mirando la pared. Nada más pasa.
- **Suspensión**: Dejas tu número de teléfono y haces recados. Te llamarán cuando esté listo.

<div class="code-tabs">
<div class="code-tabs-nav">
<button class="active">Bloqueo</button>
<button>Suspensión</button>
</div>
<div class="code-tab-content active">

```swift
// El hilo está inactivo, sin hacer nada por 5 segundos
Thread.sleep(forTimeInterval: 5)
```

</div>
<div class="code-tab-content">

```swift
// El hilo está libre para hacer otro trabajo mientras espera
try await Task.sleep(for: .seconds(5))
```

</div>
</div>

### Iniciar Trabajo Async desde Código Síncrono

A veces estás en código síncrono y necesitas llamar algo async. Usa `Task`:

```swift
@MainActor
class ViewModel {
    func buttonTapped() {  // Función síncrona
        Task {
            await loadData()  // Ahora podemos usar await
        }
    }
}
```

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

`Task` es como asignar trabajo a un empleado. El empleado maneja la solicitud (incluyendo esperar a otras oficinas) mientras tú continúas con tu trabajo inmediato.
</div>

  </div>
</section>

<section id="patterns">
  <div class="container">

## Patrones Que Funcionan

### El Patrón de Petición de Red

<div class="isolation-legend">
  <span class="isolation-legend-item main">MainActor</span>
  <span class="isolation-legend-item nonisolated">Nonisolated (llamada de red)</span>
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

        // Esto suspende - el hilo está libre para hacer otro trabajo
        let users = await networkService.getUsers()

        // De vuelta en MainActor automáticamente
        self.users = users
        isLoading = false
    }
}
```

</div>

Sin `DispatchQueue.main.async`. El atributo `@MainActor` lo maneja.

### Trabajo Paralelo con async let

```swift
func loadProfile() async -> Profile {
    async let avatar = loadImage("avatar.jpg")
    async let banner = loadImage("banner.jpg")
    async let details = loadUserDetails()

    // ¡Los tres se ejecutan en paralelo!
    return Profile(
        avatar: await avatar,
        banner: await banner,
        details: await details
    )
}
```

### Prevenir Doble-Taps

Este patrón viene de la guía de Matt Massicotte sobre [sistemas con estado](https://www.massicotte.org/step-by-step-stateful-systems):

```swift
@MainActor
class ButtonViewModel {
    private var isLoading = false

    func buttonTapped() {
        // Guard SÍNCRONAMENTE antes de cualquier trabajo async
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
<h4>Crítico: El guard debe ser síncrono</h4>

Si pones el guard dentro del Task después de un await, hay una ventana donde dos taps de botón pueden ambos iniciar trabajo. [Aprende más sobre ordenamiento y concurrencia](https://www.massicotte.org/ordering-and-concurrency).
</div>

  </div>
</section>

<section id="mistakes">
  <div class="container">

## Errores Comunes a Evitar

Estos son [errores comunes](https://www.massicotte.org/mistakes-with-concurrency/) que incluso desarrolladores experimentados cometen:

### Pensar que async = segundo plano

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Añadir `async` no te mueve a una oficina diferente. Sigues en la recepción - solo que ahora puedes esperar entregas sin congelarte en el sitio.
</div>

```swift
// ¡Esto TODAVÍA bloquea el hilo principal!
@MainActor
func slowFunction() async {
    let result = expensiveCalculation()  // Síncrono = bloqueante
    data = result
}
```

Si necesitas trabajo hecho en otra oficina, envíalo explícitamente allí:

```swift
func slowFunction() async {
    let result = await Task.detached {
        expensiveCalculation()  // Ahora en una oficina diferente
    }.value
    await MainActor.run { data = result }
}
```

### Crear demasiados actors

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Crear una nueva oficina para cada pieza de datos significa papeleo interminable para comunicarse entre ellas. La mayoría de tu trabajo puede ocurrir en la recepción.
</div>

```swift
// Sobre-ingenierizado - cada llamada requiere caminar entre oficinas
actor NetworkManager { }
actor CacheManager { }
actor DataManager { }

// Mejor - la mayoría de cosas pueden vivir en la recepción
@MainActor
class AppState { }
```

### Usar MainActor.run en todas partes

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Si sigues caminando a la recepción para cada cosa pequeña, simplemente trabaja allí. Hazlo parte de tu descripción de trabajo, no un recado constante.
</div>

```swift
// No hagas esto - caminando constantemente a la recepción
await MainActor.run { doMainActorStuff() }

// Haz esto - simplemente trabaja en la recepción
@MainActor func doMainActorStuff() { }
```

### Hacer todo Sendable

No todo necesita ser `Sendable`. Si estás añadiendo `@unchecked Sendable` en todas partes, estás haciendo fotocopias de cosas que no necesitan salir de la oficina.

### Ignorar warnings del compilador

Cada warning del compilador sobre `Sendable` es el guardia de seguridad diciéndote que algo no es seguro de llevar entre oficinas. No los ignores - [entiéndelos](https://www.massicotte.org/complete-checking/).

  </div>
</section>

<section id="errors">
  <div class="container">

## Errores Comunes del Compilador

Estos son los mensajes de error reales que verás. Cada uno es el compilador protegiéndote de un data race.

### "Sending 'self.foo' risks causing data races"

<div class="compiler-error">
Sending 'self.foo' risks causing data races
</div>

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Estás intentando llevar un documento original a otra oficina. O haz una fotocopia (Sendable) o mantenlo en un lugar.
</div>

**Solución 1:** Usa un `struct` en lugar de una `class`

**Solución 2:** Mantenlo en un actor:

```swift
@MainActor
class MyClass {
    var foo: SomeType  // Se queda en la recepción
}
```

### "Non-sendable type cannot cross actor boundary"

<div class="compiler-error">
Non-sendable type 'MyClass' cannot cross actor boundary
</div>

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Estás intentando llevar un original entre oficinas. El guardia de seguridad te detuvo.
</div>

**Solución 1:** Hazlo una struct:

```swift
// Antes: class (no-Sendable)
class User { var name: String }

// Después: struct (Sendable)
struct User: Sendable { let name: String }
```

**Solución 2:** Aíslalo en un actor:

```swift
@MainActor
class User { var name: String }
```

### "Actor-isolated property cannot be referenced"

<div class="compiler-error">
Actor-isolated property 'balance' cannot be referenced from the main actor
</div>

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Estás metiendo la mano en el archivador de otra oficina sin pasar por los canales apropiados.
</div>

**Solución:** Usa `await`:

```swift
// Mal - metiendo la mano directamente
let value = myActor.balance

// Bien - solicitud apropiada
let value = await myActor.balance
```

### "Call to main actor-isolated method in synchronous context"

<div class="compiler-error">
Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context
</div>

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Estás intentando usar la recepción sin esperar en la fila.
</div>

**Solución 1:** Haz que el llamador sea `@MainActor`:

```swift
@MainActor
func doSomething() {
    updateUI()  // Mismo aislamiento, no se necesita await
}
```

**Solución 2:** Usa `await`:

```swift
func doSomething() async {
    await updateUI()
}
```

  </div>
</section>

<section>
  <div class="container">

## Tres Niveles de Swift Concurrency

No necesitas aprender todo de una vez. Progresa a través de estos niveles:

<div class="analogy">
<h4>El Edificio de Oficinas</h4>

Piénsalo como hacer crecer una empresa. No empiezas con una sede de 50 pisos - empiezas con un escritorio.
</div>

Estos niveles no son límites estrictos - diferentes partes de tu app podrían necesitar diferentes niveles. Una app mayormente-Nivel-1 podría tener una característica que necesita patrones de Nivel 2. Está bien. Usa el enfoque más simple que funcione para cada parte.

### Nivel 1: La Startup

Todos trabajan en la recepción. Simple, directo, sin burocracia.

- Usa `async/await` para llamadas de red
- Marca clases de UI con `@MainActor`
- Usa el modificador `.task` de SwiftUI

Esto cubre el 80% de las apps. Apps como [Things](https://culturedcode.com/things/), [Bear](https://bear.app/), [Flighty](https://flighty.com/), o [Day One](https://dayoneapp.com/) probablemente caen en esta categoría - apps que principalmente obtienen datos y los muestran.

### Nivel 2: La Empresa en Crecimiento

Necesitas manejar múltiples cosas a la vez. Es hora de proyectos paralelos y coordinar equipos.

- Usa `async let` para trabajo paralelo
- Usa `TaskGroup` para paralelismo dinámico
- Entiende la cancelación de tasks

Apps como [Ivory](https://tapbots.com/ivory/)/[Ice Cubes](https://github.com/Dimillian/IceCubesApp) (clientes de Mastodon manejando múltiples timelines y actualizaciones en streaming), [Overcast](https://overcast.fm/) (coordinando descargas, reproducción y sincronización en segundo plano), o [Slack](https://slack.com/) (mensajería en tiempo real a través de múltiples canales) podrían usar estos patrones para ciertas características.

### Nivel 3: La Corporación

Departamentos dedicados con sus propias políticas. Comunicación inter-oficina compleja.

- Crea actors personalizados para estado compartido
- Entendimiento profundo de Sendable
- Executors personalizados

Apps como [Xcode](https://developer.apple.com/xcode/), [Final Cut Pro](https://www.apple.com/final-cut-pro/), o frameworks Swift del lado del servidor como [Vapor](https://vapor.codes/) y [Hummingbird](https://hummingbird.codes/) probablemente necesitan estos patrones - estado compartido complejo, miles de conexiones concurrentes, o código a nivel de framework sobre el que otros construyen.

<div class="tip">
<h4>Empieza simple</h4>

La mayoría de apps nunca necesitan Nivel 3. No construyas una corporación cuando una startup es suficiente.
</div>

  </div>
</section>

<section id="glossary">
  <div class="container">

## Glosario: Más Palabras Clave Que Encontrarás

Más allá de los conceptos básicos, aquí hay otras palabras clave de concurrencia de Swift que verás en el mundo real:

| Palabra clave | Qué significa |
|---------------|---------------|
| `nonisolated` | Opta por salir del aislamiento de un actor - se ejecuta sin protección |
| `isolated` | Declara explícitamente que un parámetro se ejecuta en el contexto de un actor |
| `@Sendable` | Marca un closure como seguro para pasar a través de fronteras de aislamiento |
| `Task.detached` | Crea un task completamente separado del contexto actual |
| `AsyncSequence` | Una secuencia que puedes iterar con `for await` |
| `AsyncStream` | Una forma de conectar código basado en callbacks con secuencias async |
| `withCheckedContinuation` | Conecta completion handlers con async/await |
| `Task.isCancelled` | Verifica si el task actual fue cancelado |
| `@preconcurrency` | Suprime warnings de concurrencia para código legacy |
| `GlobalActor` | Protocolo para crear tus propios actors personalizados como MainActor |

### Cuándo Usar Cada Uno

#### nonisolated - Leer propiedades computadas

<div class="analogy">
Como una placa con tu nombre en la puerta de tu oficina - cualquiera que pase puede leerla sin necesidad de entrar y esperarte.
</div>

Por defecto, todo dentro de un actor está aislado - necesitas `await` para accederlo. Pero a veces tienes propiedades que son inherentemente seguras de leer: constantes `let` inmutables, o propiedades computadas que solo derivan valores de otros datos seguros. Marcar estas como `nonisolated` permite a los llamadores accederlas síncronamente, evitando overhead async innecesario.

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
    let userId: String  // Inmutable, seguro de leer
    var lastActivity: Date  // Mutable, necesita protección

    // Esto puede llamarse sin await
    nonisolated var displayId: String {
        "User: \(userId)"  // Solo lee datos inmutables
    }
}
```

</div>

```swift
// Uso
let session = UserSession(userId: "123")
print(session.displayId)  // ¡No se necesita await!
```

#### @Sendable - Closures que cruzan fronteras

<div class="analogy">
Como un sobre sellado con instrucciones dentro - el sobre puede viajar entre oficinas, y quien lo abra puede seguir las instrucciones de forma segura.
</div>

Cuando un closure escapa para ejecutarse más tarde o en un dominio de aislamiento diferente, Swift necesita garantizar que no causará data races. El atributo `@Sendable` marca closures que son seguros de pasar a través de fronteras - no pueden capturar estado mutable de forma insegura. Swift a menudo infiere esto automáticamente (como con `Task.detached`), pero a veces necesitas declararlo explícitamente al diseñar APIs que aceptan closures.

```swift
@MainActor
class ViewModel {
    var items: [Item] = []

    func processInBackground() {
        Task.detached {
            // Este closure cruza desde el task detached al MainActor
            // Debe ser @Sendable (Swift lo infiere)
            let processed = await self.heavyProcessing()
            await MainActor.run {
                self.items = processed
            }
        }
    }
}

// @Sendable explícito cuando se necesita
func runLater(_ work: @Sendable @escaping () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        work()
    }
}
```

#### withCheckedContinuation - Conectando APIs antiguos

<div class="analogy">
Como un traductor entre el viejo sistema de memorándums de papel y el email moderno. Esperas en el correo hasta que el sistema viejo entrega una respuesta, luego la reenvías a través del nuevo sistema.
</div>

Muchas APIs antiguas usan completion handlers en lugar de async/await. En lugar de reescribirlas completamente, puedes envolverlas usando `withCheckedContinuation`. Esta función suspende el task actual, te da un objeto continuation, y reanuda cuando llamas a `continuation.resume()`. La variante "checked" detecta errores de programación como resumir dos veces o nunca resumir.

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
// API vieja basada en callbacks
func fetchUser(id: String, completion: @escaping (User?) -> Void) {
    // ... llamada de red con callback
}

// Envuelta como async
func fetchUser(id: String) async -> User? {
    await withCheckedContinuation { continuation in
        fetchUser(id: id) { user in
            continuation.resume(returning: user)  // ¡Conecta de vuelta!
        }
    }
}
```

</div>

Para funciones que lanzan, usa `withCheckedThrowingContinuation`:

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

#### AsyncStream - Conectando fuentes de eventos

<div class="analogy">
Como configurar reenvío de correo - cada vez que llega una carta a la dirección antigua, automáticamente se redirige a tu nuevo buzón. El stream sigue fluyendo mientras siga llegando correo.
</div>

Mientras que `withCheckedContinuation` maneja callbacks de una sola vez, muchas APIs entregan múltiples valores a lo largo del tiempo - métodos de delegado, NotificationCenter, o sistemas de eventos personalizados. `AsyncStream` conecta estos con `AsyncSequence` de Swift, permitiéndote usar bucles `for await`. Creas un stream, guardas su continuation, y llamas a `yield()` cada vez que llega un nuevo valor.

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
    print("Nueva ubicación: \(location)")
}
```

#### Task.isCancelled - Cancelación cooperativa

<div class="analogy">
Como revisar tu bandeja de entrada por un memo de "deja de trabajar en esto" antes de empezar cada paso de un proyecto grande. No te obligan a parar - eliges revisar y responder educadamente.
</div>

Swift usa cancelación cooperativa - cuando un task se cancela, no se detiene inmediatamente. En su lugar, se establece una bandera, y es tu responsabilidad verificarla periódicamente. Esto te da control sobre la limpieza y resultados parciales. Usa `Task.checkCancellation()` para lanzar inmediatamente, o verifica `Task.isCancelled` cuando quieras manejar la cancelación de forma elegante (como retornando resultados parciales).

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []

    for item in items {
        // Verifica antes de cada operación costosa
        try Task.checkCancellation()  // Lanza si está cancelado

        // O verifica sin lanzar
        if Task.isCancelled {
            return results  // Retorna resultados parciales
        }

        let result = await process(item)
        results.append(result)
    }

    return results
}
```

#### Task.detached - Escapar del contexto actual

<div class="analogy">
Como contratar a un contratista externo que no reporta a tu departamento. Trabajan independientemente, no siguen las reglas de tu oficina, y tienes que coordinarte explícitamente cuando necesitas resultados de vuelta.
</div>

Un `Task { }` regular hereda el contexto actual del actor - si estás en `@MainActor`, el task se ejecuta en `@MainActor`. A veces eso no es lo que quieres, especialmente para trabajo intensivo de CPU que bloquearía la UI. `Task.detached` crea un task sin contexto heredado, ejecutándose en un executor de fondo. Úsalo con moderación - la mayoría del tiempo, `Task` regular con puntos `await` apropiados es suficiente y más fácil de razonar.

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
        // NO HAGAS: Esto todavía hereda el contexto de MainActor
        Task {
            let filtered = applyFilters(image)  // ¡Bloquea main!
        }

        // HAZ: Task detached se ejecuta independientemente
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
<h4>Task.detached usualmente está mal</h4>

La mayoría del tiempo, quieres un `Task` regular. Los tasks detached no heredan prioridad, valores task-local, o contexto de actor. Úsalos solo cuando explícitamente necesites esa separación.
</div>

#### @preconcurrency - Vivir con código legacy

Silencia warnings al importar módulos que aún no están actualizados para concurrencia:

```swift
// Suprime warnings de este import
@preconcurrency import OldFramework

// O en una conformance de protocolo
class MyDelegate: @preconcurrency SomeOldDelegate {
    // No advertirá sobre requisitos no-Sendable
}
```

<div class="tip">
<h4>@preconcurrency es temporal</h4>

Úsalo como puente mientras actualizas código. El objetivo es eventualmente eliminarlo y tener conformance Sendable apropiada.
</div>

## Lectura Adicional

Esta guía destila los mejores recursos sobre concurrencia en Swift.

<div class="resources">
<h4>Blog de Matt Massicotte (Muy Recomendado)</h4>

- [A Swift Concurrency Glossary](https://www.massicotte.org/concurrency-glossary) - Terminología esencial
- [An Introduction to Isolation](https://www.massicotte.org/intro-to-isolation/) - El concepto central
- [When should you use an actor?](https://www.massicotte.org/actors/) - Guía práctica
- [Non-Sendable types are cool too](https://www.massicotte.org/non-sendable/) - Por qué más simple es mejor
- [Crossing the Boundary](https://www.massicotte.org/crossing-the-boundary/) - Trabajando con tipos no-Sendable
- [Problematic Swift Concurrency Patterns](https://www.massicotte.org/problematic-patterns/) - Qué evitar
- [Making Mistakes with Swift Concurrency](https://www.massicotte.org/mistakes-with-concurrency/) - Aprendiendo de errores
</div>

<div class="resources">
<h4>Recursos Oficiales de Apple</h4>

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC21: Meet async/await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Protect mutable state with actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races](https://developer.apple.com/videos/play/wwdc2022/110351/)
</div>

<div class="resources">
<h4>Tutoriales</h4>

- [Swift Concurrency by Example - Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency)
- [Async await in Swift - SwiftLee](https://www.avanderlee.com/swift/async-await/)
</div>

  </div>
</section>

> Quand vous êtes sur la piste de danse, il n'y a rien à faire sauf danser.
>
> <cite>Umberto Eco, <em>La Mystérieuse Flamme de la reine Loana</em></cite>

Il est temps pour notre machine virtuelle d'amener ses objets naissants à la vie avec du comportement. Cela signifie des méthodes et des appels de méthode. Et, puisqu'ils sont une sorte spéciale de méthode, des initialisateurs aussi.

Tout cela est un territoire familier de notre précédent interpréteur jlox. Ce qui est nouveau dans ce second voyage est une optimisation importante que nous implémenterons pour rendre les appels de méthode plus de sept fois plus rapides que notre performance de base. Mais avant que nous arrivions à ce plaisir, nous devons faire fonctionner les trucs de base.

## Déclarations de Méthode

Nous ne pouvons pas optimiser les appels de méthode avant que nous ayons des appels de méthode, et nous ne pouvons pas appeler des méthodes sans avoir de méthodes à appeler, donc nous commencerons avec les déclarations.

### Représenter les méthodes

Nous commençons habituellement dans le compilateur, mais sortons le modèle objet d'abord cette fois. La représentation runtime pour les méthodes dans clox est similaire à celle de jlox. Chaque classe stocke une table de hachage de méthodes. Les clés sont les noms de méthode, et chaque valeur est une ObjClosure pour le corps de la méthode.

^code class-methods (3 before, 1 after)

Une toute nouvelle classe commence avec une table de méthode vide.

^code init-methods (1 before, 1 after)

La structure ObjClass possède la mémoire pour cette table, donc quand le gestionnaire de mémoire désalloue une classe, la table devrait être libérée aussi.

^code free-methods (1 before, 1 after)

En parlant de gestionnaires de mémoire, le GC a besoin de tracer à travers les classes dans la table de méthode. Si une classe est encore atteignable (probablement à travers quelque instance), alors toutes ses méthodes ont certainement besoin de rester dans les parages aussi.

^code mark-methods (1 before, 1 after)

Nous utilisons la fonction `markTable()` existante, qui trace à travers la chaîne clé et la valeur dans chaque entrée de table.

Stocker les méthodes d'une classe est assez familier venant de jlox. La partie différente est comment cette table devient peuplée. Notre interpréteur précédent avait accès au nœud AST entier pour la déclaration de classe et toutes les méthodes qu'elle contenait. À l'exécution, l'interpréteur parcourait simplement cette liste de déclarations.

Maintenant chaque pièce d'information que le compilateur veut expédier vers le runtime doit se faufiler à travers l'interface d'une série plate d'instructions bytecode. Comment prenons-nous une déclaration de classe, qui peut contenir un ensemble arbitrairement grand de méthodes, et la représentons-nous comme du bytecode ? Sautons vers le compilateur et découvrons-le.

### Compiler les déclarations de méthode

Le dernier chapitre nous a laissés avec un compilateur qui analyse les classes mais permet seulement un corps vide. Maintenant nous insérons un peu de code pour compiler une série de déclarations de méthode entre les accolades.

^code class-body (1 before, 1 after)

Lox n'a pas de déclarations de champ, donc tout ce qui est avant l'accolade fermante à la fin du corps de classe doit être une méthode. Nous arrêtons de compiler les méthodes quand nous frappons cette accolade finale ou si nous atteignons la fin du fichier. Cette dernière vérification assure que notre compilateur ne reste pas coincé dans une boucle infinie si l'utilisateur oublie accidentellement l'accolade fermante.

La partie délicate avec la compilation d'une déclaration de classe est qu'une classe peut déclarer n'importe quel nombre de méthodes. D'une manière ou d'une autre le runtime a besoin de rechercher et lier toutes celles-ci. Ce serait beaucoup à empaqueter dans une seule instruction `OP_CLASS`. Au lieu de cela, le bytecode que nous générons pour une déclaration de classe divisera le processus en une <span name="series">_série_</span> d'instructions. Le compilateur émet déjà une instruction `OP_CLASS` qui crée un nouvel objet ObjClass vide. Ensuite il émet des instructions pour stocker la classe dans une variable avec son nom.

<aside name="series">

Nous avons fait quelque chose de similaire pour les fermetures. L'instruction `OP_CLOSURE` a besoin de connaître le type et l'index pour chaque upvalue capturée. Nous avons encodé cela utilisant une série de pseudo-instructions suivant l'instruction `OP_CLOSURE` principale -- fondamentalement un nombre variable d'opérandes. La VM traite tous ces octets supplémentaires immédiatement lors de l'interprétation de l'instruction `OP_CLOSURE`.

Ici notre approche est un peu différente parce que de la perspective de la VM, chaque instruction pour définir une méthode est une opération autonome séparée. L'une ou l'autre approche fonctionnerait. Une pseudo-instruction de taille variable est possiblement marginalement plus rapide, mais les déclarations de classe sont rarement dans des boucles chaudes, donc cela n'importe pas beaucoup.

</aside>

Maintenant, pour chaque déclaration de méthode, nous émettons une nouvelle instruction `OP_METHOD` qui ajoute une méthode unique à cette classe. Quand toutes les instructions `OP_METHOD` ont exécuté, nous sommes laissés avec une classe pleinement formée. Alors que l'utilisateur voit une déclaration de classe comme une opération atomique unique, la VM l'implémente comme une série de mutations.

Pour définir une nouvelle méthode, la VM a besoin de trois choses :

1.  Le nom de la méthode.

2.  La fermeture pour le corps de la méthode.

3.  La classe à laquelle lier la méthode.

Nous écrirons incrémentalement le code du compilateur pour voir comment tout cela passe au runtime, commençant ici :

^code method

Comme `OP_GET_PROPERTY` et d'autres instructions qui ont besoin de noms à l'exécution, le compilateur ajoute le lexème du jeton nom de méthode à la table des constantes, récupérant un index de table. Ensuite nous émettons une instruction `OP_METHOD` avec cet index comme l'opérande. C'est le nom. Ensuite est le corps de la méthode :

^code method-body (1 before, 1 after)

Nous utilisons le même assistant `function()` que nous avons écrit pour compiler les déclarations de fonction. Cette fonction utilitaire compile la liste de paramètres subséquente et le corps de la fonction. Ensuite elle émet le code pour créer une ObjClosure et la laisser sur le sommet de la pile. À l'exécution, la VM trouvera la fermeture là.

Dernier est la classe à laquelle lier la méthode. Où la VM peut-elle trouver cela ? Malheureusement, au moment où nous atteignons l'instruction `OP_METHOD`, nous ne savons pas où elle est. Elle <span name="global">pourrait</span> être sur la pile, si l'utilisateur a déclaré la classe dans une portée locale. Mais une déclaration de classe de niveau supérieur finit avec l'ObjClass dans la table des variables globales.

<aside name="global">

Si Lox supportait de déclarer les classes seulement au niveau supérieur, la VM pourrait supposer que toute classe pourrait être trouvée en la cherchant directement depuis la table des variables globales. Hélas, parce que nous supportons les classes locales, nous avons besoin de gérer ce cas aussi.

</aside>

Ne craignez rien. Le compilateur connaît le _nom_ de la classe. Nous pouvons le capturer juste après avoir consommé son jeton.

^code class-name (1 before, 1 after)

Et nous savons qu'aucune autre déclaration avec ce nom ne pourrait possiblement masquer la classe. Donc nous faisons la réparation facile. Avant que nous commencions à lier les méthodes, nous émettons tout code qui est nécessaire pour charger la classe de retour sur le sommet de la pile.

^code load-class (2 before, 1 after)

Juste avant de compiler le corps de classe, nous <span name="load">appelons</span> `namedVariable()`. Cette fonction aide génère du code pour charger une variable avec le nom donné sur la pile. Ensuite nous compilons les méthodes.

<aside name="load">

L'appel précédent à `defineVariable()` dépile la classe, donc cela semble idiot d'appeler `namedVariable()` pour la charger juste de retour sur la pile. Pourquoi ne pas simplement la laisser sur la pile en premier lieu ? Nous pourrions, mais dans le [prochain chapitre][super] nous insérerons du code entre ces deux appels pour supporter l'héritage. À ce point, il sera plus simple si la classe ne traîne pas sur la pile.

[super]: superclasses.html

</aside>

Cela signifie que quand nous exécutons chaque instruction `OP_METHOD`, la pile a la fermeture de la méthode sur le sommet avec la classe juste sous elle. Une fois que nous avons atteint la fin des méthodes, nous n'avons plus besoin de la classe et disons à la VM de la dépiler de la pile.

^code pop-class (1 before, 1 after)

Mettant tout cela ensemble, voici une déclaration de classe exemple à jeter au compilateur :

```lox
class Brunch {
  bacon() {}
  eggs() {}
}
```

Donné cela, voici ce que le compilateur génère et comment ces instructions affectent la pile à l'exécution :

<img src="image/methods-and-initializers/method-instructions.png" alt="La série d'instructions bytecode pour une déclaration de classe avec deux méthodes." />

Tout ce qui reste pour nous est d'implémenter le runtime pour cette nouvelle instruction `OP_METHOD`.

### Exécuter les déclarations de méthode

D'abord nous définissons l'opcode.

^code method-op (1 before, 1 after)

Nous le désassemblons comme d'autres instructions qui ont des opérandes constants chaîne.

^code disassemble-method (2 before, 1 after)

Et là-bas dans l'interpréteur, nous ajoutons un nouveau cas aussi.

^code interpret-method (1 before, 1 after)

Là, nous lisons le nom de la méthode depuis la table des constantes et le passons ici :

^code define-method

La fermeture de méthode est au sommet de la pile, au-dessus de la classe à laquelle elle sera liée. Nous lisons ces deux emplacements de pile et stockons la fermeture dans la table de méthode de la classe. Ensuite nous dépilons la fermeture puisque nous en avons fini avec elle.

Notez que nous ne faisons aucune vérification de type à l'exécution sur la fermeture ou l'objet classe. Cet appel `AS_CLASS()` est sûr parce que le compilateur lui-même a généré le code qui cause la classe d'être dans cet emplacement de pile. La VM <span name="verify">fait confiance</span> à son propre compilateur.

<aside name="verify">

La VM fait confiance que les instructions qu'elle exécute sont valides parce que le _seul_ moyen d'amener du code à l'interpréteur bytecode est en passant par le propre compilateur de clox. Beaucoup de VMs bytecode, comme la JVM et CPython, supportent l'exécution de bytecode qui a été compilé séparément. Cela mène à une histoire de sécurité différente. Du bytecode fabriqué malicieusement pourrait faire planter la VM ou pire.

Pour empêcher cela, la JVM fait une passe de vérification de bytecode avant qu'elle n'exécute tout code chargé. CPython dit que c'est à l'utilisateur de s'assurer que tout bytecode qu'il exécute est sûr.

</aside>

Après que la série d'instructions `OP_METHOD` est finie et que le `OP_POP` a dépilé la classe, nous aurons une classe avec une table de méthode joliment peuplée, prête à commencer à faire des choses. L'étape suivante est de tirer ces méthodes de retour en dehors et de les utiliser.

## Références de Méthode

La plupart du temps, les méthodes sont accédées et immédiatement appelées, menant à cette syntaxe familière :

```lox
instance.method(argument);
```

Mais rappelez-vous, dans Lox et quelques autres langages, ces deux étapes sont distinctes et peuvent être séparées.

```lox
var closure = instance.method;
closure(argument);
```

Puisque les utilisateurs _peuvent_ séparer les opérations, nous devons les implémenter séparément. La première étape est d'utiliser notre syntaxe de propriété pointée existante pour accéder à une méthode définie sur la classe de l'instance. Cela devrait renvoyer quelque sorte d'objet que l'utilisateur peut alors appeler comme une fonction.

L'approche évidente est de chercher la méthode dans la table de méthode de la classe et de retourner l'ObjClosure associée avec ce nom. Mais nous devons aussi nous souvenir que quand vous accédez à une méthode, `this` devient lié à l'instance depuis laquelle la méthode a été accédée. Voici l'exemple de [quand nous avons ajouté les méthodes à jlox][jlox] :

[jlox]: classes.html#methods-on-classes

```lox
class Person {
  sayName() {
    print this.name;
  }
}

var jane = Person();
jane.name = "Jane";

var method = jane.sayName;
method(); // ?
```

Ceci devrait afficher "Jane", donc l'objet retourné par `.sayName` a besoin de se souvenir d'une manière ou d'une autre de l'instance depuis laquelle il a été accédé quand il sera plus tard appelé. Dans jlox, nous avions implémenté cette "mémoire" en utilisant la classe Environment allouée sur le tas existante de l'interpréteur, qui gérait tout le stockage de variable.

Notre VM à bytecode a une architecture plus complexe pour stocker l'état. [Les variables locales et les temporaires][locals] sont sur la pile, [les globales][globals] sont dans une table de hachage, et les variables dans les fermetures utilisent des [upvalues][]. Cela nécessite une solution quelque peu plus complexe pour suivre le receveur d'une méthode dans clox, et un nouveau type runtime.

[locals]: variables-locales.html#représenter-les-variables-locales
[globals]: variables-globales.html#déclarations-de-variable
[upvalues]: closures.html#upvalues

### Méthodes liées

Quand l'utilisateur exécute un accès méthode, nous trouverons la fermeture pour cette méthode et l'envelopperons dans un nouvel objet <span name="bound">"méthode liée"</span> (bound method) qui suit l'instance depuis laquelle la méthode a été accédée. Cet objet lié peut être appelé plus tard comme une fonction. Quand invoqué, la VM fera quelques manigances pour câbler `this` pour pointer vers le receveur à l'intérieur du corps de la méthode.

<aside name="bound">

J'ai pris le nom "méthode liée" de CPython. Python se comporte similairement à Lox ici, et j'ai utilisé son implémentation pour l'inspiration.

</aside>

Voici le nouveau type d'objet :

^code obj-bound-method (2 before, 1 after)

Il enveloppe le receveur et la fermeture de méthode ensemble. Le type du receveur est Value même si les méthodes peuvent être appelées seulement sur des ObjInstances. Puisque la VM ne se soucie pas de quel genre de receveur elle a de toute façon, utiliser Value signifie que nous n'avons pas à continuer de convertir le pointeur en arrière vers une Value quand il est passé à des fonctions plus générales.

La nouvelle structure implique le code standard habituel auquel vous êtes habitué maintenant. Un nouveau cas dans l'énumération de type objet :

^code obj-type-bound-method (1 before, 1 after)

Une macro pour vérifier le type d'une valeur :

^code is-bound-method (2 before, 1 after)

Une autre macro pour caster la valeur vers un pointeur ObjBoundMethod :

^code as-bound-method (2 before, 1 after)

Une fonction pour créer une nouvelle ObjBoundMethod :

^code new-bound-method-h (2 before, 1 after)

Et une implémentation de cette fonction ici :

^code new-bound-method

La fonction de type constructeur stocke simplement la fermeture et le receveur donnés. Quand la méthode liée n'est plus nécessaire, nous la libérons.

^code free-bound-method (1 before, 1 after)

La méthode liée a une couple de références, mais elle ne les _possède_ pas, donc elle ne libère rien sauf elle-même. Cependant, ces références sont bien tracées par le ramasse-miettes.

^code blacken-bound-method (1 before, 1 after)

Ceci <span name="trace">assure</span> qu'une poignée vers une méthode garde le receveur dans les parages en mémoire pour que `this` puisse encore trouver l'objet quand vous invoquez la poignée plus tard. Nous traçons aussi la fermeture de méthode.

<aside name="trace">

Tracer la fermeture de méthode n'est pas vraiment nécessaire. Le receveur est une ObjInstance, qui a un pointeur vers son ObjClass, qui a une table pour toutes les méthodes. Mais cela semble douteux pour moi d'une certaine manière vague d'avoir ObjBoundMethod qui compte sur cela.

</aside>

La dernière opération que tous les objets supportent est l'affichage.

^code print-bound-method (1 before, 1 after)

Une méthode liée s'affiche exactement de la même façon qu'une fonction. De la perspective de l'utilisateur, une méthode liée _est_ une fonction. C'est un objet qu'ils peuvent appeler. Nous n'exposons pas que la VM implémente les méthodes liées utilisant un type d'objet différent.

<aside name="party">

<img src="image/methods-and-initializers/party-hat.png" alt="Un chapeau de fête." />

</aside>

Mettez votre chapeau de <span name="party">fête</span> parce que nous venons d'atteindre une petite étape importante. ObjBoundMethod est le tout dernier type runtime à ajouter à clox. Vous avez écrit vos dernières macros `IS_` et `AS_`. Nous sommes seulement à quelques chapitres de la fin du livre, et nous nous approchons d'une VM complète.

### Accéder aux méthodes

Faisons faire quelque chose à notre nouveau type d'objet. Les méthodes sont accédées utilisant la même syntaxe de propriété "point" que nous avons implémentée dans le dernier chapitre. Le compilateur analyse déjà les bonnes expressions et émet des instructions `OP_GET_PROPERTY` pour elles. Les seuls changements que nous avons besoin de faire sont dans le runtime.

Quand une instruction d'accès propriété s'exécute, l'instance est au sommet de la pile. Le travail de l'instruction est de trouver un champ ou une méthode avec le nom donné et remplacer le sommet de la pile avec la propriété accédée.

L'interpréteur gère déjà les champs, donc nous étendons simplement le cas `OP_GET_PROPERTY` avec une autre section.

^code get-method (5 before, 1 after)

Nous insérons ceci après le code pour chercher un champ sur l'instance receveur. Les champs prennent la priorité sur et masquent les méthodes, donc nous cherchons un champ d'abord. Si l'instance n'a pas de champ avec le nom de propriété donné, alors le nom peut faire référence à une méthode.

Nous prenons la classe de l'instance et la passons à un nouvel assistant `bindMethod()`. Si cette fonction trouve une méthode, elle place la méthode sur la pile et renvoie `true`. Sinon elle renvoie `false` pour indiquer qu'une méthode avec ce nom n'a pas pu être trouvée. Puisque le nom n'était pas aussi un champ, cela signifie que nous avons une erreur d'exécution, qui avorte l'interpréteur.

Voici la bonne marchandise :

^code bind-method

D'abord nous cherchons une méthode avec le nom donné dans la table de méthode de la classe. Si nous n'en trouvons pas une, nous rapportons une erreur d'exécution et évacuons. Sinon, nous prenons la méthode et l'enveloppons dans une nouvelle ObjBoundMethod. Nous attrapons le receveur depuis sa maison au sommet de la pile. Finalement, nous dépilons l'instance et remplaçons le sommet de la pile avec la méthode liée.

Par exemple :

```lox
class Brunch {
  eggs() {}
}

var brunch = Brunch();
var eggs = brunch.eggs;
```

Voici ce qui arrive quand la VM exécute l'appel `bindMethod()` pour l'expression `brunch.eggs` :

<img src="image/methods-and-initializers/bind-method.png" alt="Les changements de pile causés par bindMethod()." />

C'est beaucoup de machinerie sous le capot, mais de la perspective de l'utilisateur, ils obtiennent simplement une fonction qu'ils peuvent appeler.

### Appeler les méthodes

Les utilisateurs peuvent déclarer des méthodes sur des classes, les accéder sur des instances, et obtenir des méthodes liées sur la pile. Ils ne peuvent juste rien <span name="do">_faire_</span> d'utile avec ces objets méthode liée. L'opération que nous manquons est de les appeler. Les appels sont implémentés dans `callValue()`, donc nous ajoutons un cas là pour le nouveau type d'objet.

<aside name="do">

Une méthode liée _est_ une valeur de première classe, donc ils peuvent la stocker dans des variables, la passer à des fonctions, et faire autrement des trucs de "valeur" avec elle.

</aside>

^code call-bound-method (1 before, 1 after)

Nous tirons la fermeture brute de retour hors de l'ObjBoundMethod et utilisons l'assistant `call()` existant pour commencer une invocation de cette fermeture en empilant une CallFrame pour elle sur la pile d'appels. C'est tout ce qu'il faut pour être capable d'exécuter ce programme Lox :

```lox
class Scone {
  topping(first, second) {
    print "scone with " + first + " and " + second;
  }
}

var scone = Scone();
scone.topping("berries", "cream");
```

C'est trois grandes étapes. Nous pouvons déclarer, accéder, et invoquer des méthodes. Mais quelque chose manque. Nous sommes allés à tout ce problème pour envelopper la fermeture de méthode dans un objet qui lie le receveur, mais quand nous invoquons la méthode, nous n'utilisons pas ce receveur du tout.
## This

La raison pour laquelle les méthodes liées ont besoin de garder une prise sur le receveur est pour qu'il puisse être accédé à l'intérieur du corps de la méthode. Lox expose le receveur d'une méthode à travers des expressions `this`. Il est temps pour un peu de nouvelle syntaxe. Le lexer traite déjà `this` comme un type de jeton spécial, donc la première étape est de câbler ce jeton dans la table d'analyse.

^code table-this (1 before, 1 after)

<aside name="this">

Le souligné à la fin du nom de la fonction d'analyseur est parce que `this` est un mot réservé en C++ et nous supportons de compiler clox comme C++.

</aside>

Quand l'analyseur rencontre un `this` en position préfixe, il répartit vers une nouvelle fonction d'analyseur.

^code this

Nous appliquerons la même technique d'implémentation pour `this` dans clox que nous avons utilisée dans jlox. Nous traitons `this` comme une variable locale de portée lexicale dont la valeur devient magiquement initialisée. Le compiler comme une variable locale signifie que nous obtenons beaucoup de comportement gratuitement. En particulier, les fermetures à l'intérieur d'une méthode qui référencent `this` feront la bonne chose et captureront le receveur dans une upvalue.

Quand la fonction d'analyseur est appelée, le jeton `this` a juste été consommé et est stocké comme le jeton précédent. Nous appelons notre fonction `variable()` existante qui compile les expressions d'identifiant comme des accès de variable. Elle prend un seul paramètre Booléen pour si le compilateur devrait chercher un opérateur `=` suivant et analyser un setter. Vous ne pouvez pas assigner à `this`, donc nous passons `false` pour interdire cela.

La fonction `variable()` ne se soucie pas que `this` a son propre type de jeton et n'est pas un identifiant. Elle est contente de traiter le lexème "this" comme s'il était un nom de variable et ensuite le chercher utilisant la machinerie de résolution de portée existante. En ce moment, cette recherche échouera parce que nous n'avons jamais déclaré une variable dont le nom est "this". Il est temps de penser à où le receveur devrait vivre en mémoire.

Au moins jusqu'à ce qu'ils soient capturés par des fermetures, clox stocke chaque variable locale sur la pile de la VM. Le compilateur garde la trace de quels slots dans la fenêtre de pile de la fonction sont possédés par quelles variables locales. Si vous vous souvenez, le compilateur met de côté l'emplacement de pile zéro en déclarant une variable locale dont le nom est une chaîne vide.

Pour les appels de fonction, cet emplacement finit par contenir la fonction étant appelée. Puisque l'emplacement n'a aucun nom, le corps de fonction ne l'accède jamais. Vous pouvez deviner où cela va. Pour les appels de _méthode_, nous pouvons réutiliser cet emplacement pour stocker le receveur. L'emplacement zéro stockera l'instance à laquelle `this` est lié. Afin de compiler les expressions `this`, le compilateur a simplement besoin de donner le bon nom à cette variable locale.

^code slot-zero (1 before, 1 after)

Nous voulons faire ceci seulement pour les méthodes. Les déclarations de fonction n'ont pas de `this`. Et, en fait, elles _ne doivent pas_ déclarer une variable nommée "this", pour que si vous écrivez une expression `this` à l'intérieur d'une déclaration de fonction qui est elle-même à l'intérieur d'une méthode, le `this` se résout correctement vers le receveur de la méthode extérieure.

```lox
class Nested {
  method() {
    fun function() {
      print this;
    }

    function();
  }
}

Nested().method();
```

Ce programme devrait afficher "Nested instance". Pour décider quel nom donner à l'emplacement local zéro, le compilateur a besoin de savoir s'il compile une déclaration de fonction ou de méthode, donc nous ajoutons un nouveau cas à notre énumération FunctionType pour distinguer les méthodes.

^code method-type-enum (1 before, 1 after)

Quand nous compilons une méthode, nous utilisons ce type.

^code method-type (2 before, 1 after)

Maintenant nous pouvons correctement compiler les références à la variable spéciale "this", et le compilateur émettra les bonnes instructions `OP_GET_LOCAL` pour l'accéder. Les fermetures peuvent même capturer `this` et stocker le receveur dans des upvalues. Plutôt cool.

Sauf qu'à l'exécution, le receveur n'est pas réellement _dans_ l'emplacement zéro. L'interpréteur ne tient pas sa part du marché encore. Voici la réparation :

^code store-receiver (2 before, 2 after)

Quand une méthode est appelée, le sommet de la pile contient tous les arguments, et ensuite juste sous ceux-ci est la fermeture de la méthode appelée. C'est là que l'emplacement zéro dans la nouvelle CallFrame sera. Cette ligne de code insère le receveur dans cet emplacement. Par exemple, donné un appel de méthode comme ceci :

```lox
scone.topping("berries", "cream");
```

Nous calculons l'emplacement pour stocker le receveur comme ceci :

<img src="image/methods-and-initializers/closure-slot.png" alt="Sautant par-dessus les emplacements de pile argument pour trouver l'emplacement contenant la fermeture." />

Le `-argCount` saute passé les arguments et le `- 1` ajuste pour le fait que `stackTop` pointe juste _après_ le dernier emplacement de pile utilisé.

### Mauvais usage de this

Notre VM supporte maintenant que les utilisateurs utilisent _correctement_ `this`, mais nous devons aussi nous assurer qu'elle gère proprement les utilisateurs utilisant _mal_ `this`. Lox dit que c'est une erreur de compilation pour une expression `this` d'apparaître en dehors du corps d'une méthode. Ces deux mauvais usages devraient être attrapés par le compilateur :

```lox
print this; // Au niveau supérieur.

fun notMethod() {
  print this; // Dans une fonction.
}
```

Donc comment le compilateur sait-il s'il est à l'intérieur d'une méthode ? La réponse évidente est de regarder le FunctionType du Compiler courant. Nous avons juste ajouté un cas d'énumération là pour traiter les méthodes spécialement. Cependant, cela ne gérerait pas correctement le code comme l'exemple plus tôt où vous êtes à l'intérieur d'une fonction qui est, elle-même, imbriquée à l'intérieur d'une méthode.

Nous pourrions essayer de résoudre "this" et ensuite rapporter une erreur s'il n'a été trouvé dans aucune des portées lexicales environnantes. Cela fonctionnerait, mais nécessiterait de remanier un tas de code, puisque pour l'instant le code pour résoudre une variable la considère implicitement comme un accès global si aucune déclaration n'est trouvée.

Dans le prochain chapitre, nous aurons besoin d'information sur la classe englobante la plus proche. Si nous avions cela, nous pourrions l'utiliser ici pour déterminer si nous sommes à l'intérieur d'une méthode. Donc nous pouvons aussi bien rendre la vie de nos futurs nous-mêmes un peu plus facile et mettre cette machinerie en place maintenant.

^code current-class (1 before, 2 after)

Cette variable de module pointe vers une structure représentant la classe courante, la plus intérieure, étant compilée. Le nouveau type ressemble à ceci :

^code class-compiler-struct (1 before, 2 after)

Pour l'instant nous stockons seulement un pointeur vers le ClassCompiler pour la classe englobante, s'il y en a une. Imbriquer une déclaration de classe à l'intérieur d'une méthode dans quelque autre classe est une chose peu commune à faire, mais Lox le supporte. Juste comme la structure Compiler, cela signifie que ClassCompiler forme une liste liée depuis la classe la plus intérieure courante étant compilée vers l'extérieur à travers toutes les classes englobantes.

Si nous ne sommes pas à l'intérieur d'une déclaration de classe du tout, la variable de module `currentClass` est `NULL`. Quand le compilateur commence à compiler une classe, il empile un nouveau ClassCompiler sur cette pile liée implicite.

^code create-class-compiler (2 before, 1 after)

La mémoire pour la structure ClassCompiler vit juste sur la pile C, une capacité pratique que nous obtenons en écrivant notre compilateur utilisant la descente récursive. À la fin du corps de classe, nous dépilons ce compilateur de la pile et restaurons celui englobant.

^code pop-enclosing (1 before, 1 after)

Quand un corps de classe le plus extérieur finit, `enclosing` sera `NULL`, donc ceci réinitialise `currentClass` à `NULL`. Ainsi, pour voir si nous sommes à l'intérieur d'une classe -- et par conséquent à l'intérieur d'une méthode -- nous vérifions simplement cette variable de module.

^code this-outside-class (1 before, 1 after)

Avec cela, `this` en dehors d'une classe est correctement interdit. Maintenant nos méthodes se sentent vraiment comme des _méthodes_ dans le sens orienté objet. Accéder au receveur leur permet d'affecter l'instance sur laquelle vous avez appelé la méthode. Nous y arrivons !

## Initialisateurs d'Instance

La raison pour laquelle les langages orientés objet lient l'état et le comportement ensemble -- un des principes fondamentaux du paradigme -- est pour s'assurer que les objets sont toujours dans un état valide, significatif. Quand le seul moyen de toucher à l'état d'un objet est <span name="through">à travers</span> ses méthodes, les méthodes peuvent s'assurer que rien ne tourne mal. Mais cela présume que l'objet est _déjà_ dans un état propre. Qu'en est-il quand il est d'abord créé ?

<aside name="through">

Bien sûr, Lox laisse bien le code extérieur accéder directement et modifier les champs d'une instance sans passer par ses méthodes. C'est différent de Ruby et Smalltalk, qui encapsulent complètement l'état à l'intérieur des objets. Notre langage de script jouet, hélas, n'est pas si principiel.

</aside>

Les langages orientés objet assurent que les tout nouveaux objets sont proprement configurés à travers des constructeurs, qui produisent à la fois une nouvelle instance et initialisent son état. Dans Lox, le runtime alloue les nouvelles instances brutes, et une classe peut déclarer un initialisateur pour configurer tous champs. Les initialisateurs fonctionnent surtout comme des méthodes normales, avec quelques ajustements :

1.  Le runtime invoque automatiquement la méthode initialisateur chaque fois qu'une instance d'une classe est créée.

2.  L'appelant qui construit une instance obtient toujours l'instance de <span name="return">retour</span> après que l'initialisateur finit, indépendamment de ce que la fonction initialisateur elle-même renvoie. La méthode initialisateur n'a pas besoin de retourner explicitement `this`.

3.  En fait, il est _interdit_ à un initialisateur de retourner toute valeur puisque la valeur ne serait jamais vue de toute façon.

<aside name="return">

C'est comme si l'initialisateur était implicitement enveloppé dans un paquet de code comme ceci :

```lox
fun create(klass) {
  var obj = newInstance(klass);
  obj.init();
  return obj;
}
```

Notez comment la valeur renvoyée par `init()` est jetée.

</aside>

Maintenant que nous supportons les méthodes, pour ajouter les initialisateurs, nous avons simplement besoin d'implémenter ces trois règles spéciales. Nous irons dans l'ordre.

### Invoquer les initialisateurs

D'abord, appeler automatiquement `init()` sur les nouvelles instances :

^code call-init (1 before, 1 after)

Après que le runtime alloue la nouvelle instance, nous cherchons une méthode `init()` sur la classe. Si nous en trouvons une, nous initions un appel vers elle. Cela empile une nouvelle CallFrame pour la fermeture de l'initialisateur. Disons que nous exécutons ce programme :

```lox
class Brunch {
  init(food, drink) {}
}

Brunch("eggs", "coffee");
```

Quand la VM exécute l'appel à `Brunch()`, cela va comme ceci :

<img src="image/methods-and-initializers/init-call-frame.png" alt="Les fenêtres de pile alignées pour l'appel Brunch() et la méthode init() correspondante vers laquelle il transfère." />

Tous arguments passés à la classe quand nous l'avons appelée sont encore assis sur la pile au-dessus de l'instance. La nouvelle CallFrame pour la méthode `init()` partage cette fenêtre de pile, donc ces arguments sont implicitement transférés à l'initialisateur.

Lox n'exige pas qu'une classe définisse un initialisateur. Si omis, le runtime renvoie simplement la nouvelle instance non initialisée. Cependant, s'il n'y a pas de méthode `init()`, alors cela n'a aucun sens de passer des arguments à la classe lors de la création de l'instance. Nous faisons de cela une erreur.

^code no-init-arity-error (1 before, 1 after)

Quand la classe _fournit_ bien un initialisateur, nous avons aussi besoin de nous assurer que le nombre d'arguments passés correspond à l'arité de l'initialisateur. Heureusement, l'assistant `call()` fait cela pour nous déjà.

Pour appeler l'initialisateur, le runtime cherche la méthode `init()` par nom. Nous voulons que cela soit rapide puisque cela arrive chaque fois qu'une instance est construite. Cela signifie qu'il serait bon de prendre avantage de l'internement de chaînes que nous avons déjà implémenté. Pour faire cela, la VM crée une ObjString pour "init" et la réutilise. La chaîne vit juste dans la structure VM.

^code vm-init-string (1 before, 1 after)

Nous créons et internons la chaîne quand la VM démarre.

^code init-init-string (1 before, 2 after)

Nous voulons qu'elle reste dans les parages, donc le GC la considère comme une racine.

^code mark-init-string (1 before, 1 after)

Regardez attentivement. Voyez-vous un bug attendant d'arriver ? Non ? C'est un subtil. Le ramasse-miettes lit maintenant `vm.initString`. Ce champ est initialisé à partir du résultat de l'appel `copyString()`. Mais copier une chaîne alloue de la mémoire, ce qui peut déclencher un GC. Si le collecteur courrait juste au mauvais moment, il lirait `vm.initString` avant qu'il ait été initialisé. Donc, d'abord nous mettons le champ à zéro.

^code null-init-string (2 before, 2 after)

Nous effaçons le pointeur quand la VM s'éteint puisque la ligne suivante la libérera.

^code clear-init-string (1 before, 1 after)

OK, cela nous laisse appeler les initialisateurs.

### Valeurs de retour d'initialisateur

L'étape suivante est de s'assurer que construire une instance d'une classe avec un initialisateur renvoie toujours la nouvelle instance, et non `nil` ou quoi que ce soit que le corps de l'initialisateur renvoie. En ce moment, si une classe définit un initialisateur, alors quand une instance est construite, la VM empile un appel à cet initialisateur sur la pile CallFrame. Ensuite elle continue juste sa route.

L'invocation de l'utilisateur sur la classe pour créer l'instance se complétera quand cette méthode initialisateur retournera, et laissera sur la pile quelle que soit la valeur que l'initialisateur y met. Cela signifie que sauf si l'utilisateur prend soin de mettre `return this;` à la fin de l'initialisateur, aucune instance ne sortira. Pas très utile.

Pour réparer cela, chaque fois que le front end compile une méthode initialisateur, il émettra du bytecode différent à la fin du corps pour retourner `this` depuis la méthode au lieu de l'implicite `nil` habituel que la plupart des fonctions retournent. Afin de faire _cela_, le compilateur a besoin de savoir réellement quand il compile un initialisateur. Nous détectons cela en vérifiant si le nom de la méthode que nous compilons est "init".

^code initializer-name (1 before, 1 after)

Nous définissons un nouveau type de fonction pour distinguer les initialisateurs des autres méthodes.

^code initializer-type-enum (1 before, 1 after)

Chaque fois que le compilateur émet le retour implicite à la fin d'un corps, nous vérifions le type pour décider si insérer le comportement spécifique à l'initialisateur.

^code return-this (1 before, 1 after)

Dans un initialisateur, au lieu d'empiler `nil` sur la pile avant de retourner, nous chargeons l'emplacement zéro, qui contient l'instance. Cette fonction `emitReturn()` est aussi appelée lors de la compilation d'une instruction `return` sans valeur, donc ceci gère aussi correctement les cas où l'utilisateur fait un retour précoce à l'intérieur de l'initialisateur.

### Retours incorrects dans les initialisateurs

La dernière étape, le dernier élément dans notre liste de fonctionnalités spéciales des initialisateurs, est de faire une erreur d'essayer de retourner quoi que ce soit d'_autre_ depuis un initialisateur. Maintenant que le compilateur suit le type de méthode, c'est direct.

^code return-from-init (3 before, 1 after)

Nous rapportons une erreur si une instruction `return` dans un initialisateur a une valeur. Nous allons quand même de l'avant et compilons la valeur après pour que le compilateur ne soit pas confus par l'expression traînante et rapporte un tas d'erreurs en cascade.

À part l'héritage, auquel nous arriverons [bientôt][super], nous avons maintenant un système de classe assez complet fonctionnant dans clox.

```lox
class CoffeeMaker {
  init(coffee) {
    this.coffee = coffee;
  }

  brew() {
    print "Enjoy your cup of " + this.coffee;

    // No reusing the grounds!
    this.coffee = nil;
  }
}

var maker = CoffeeMaker("coffee and chicory");
maker.brew();
```

Plutôt fantaisiste pour un programme C qui tiendrait sur une vieille disquette <span name="floppy">souple</span>.

<aside name="floppy">

Je reconnais que "disquette souple" peut ne plus être une référence de taille utile pour les générations actuelles de programmeurs. Peut-être aurais-je dû dire "quelques tweets" ou quelque chose.

</aside>

## Invocations Optimisées
Notre VM implémente correctement la sémantique du langage pour les appels de méthodes et les initialisateurs. Nous pourrions arrêter ici. Mais la raison principale pour laquelle nous construisons une entière seconde implémentation de Lox à partir de zéro est pour exécuter plus vite que notre vieil interpréteur Java. En ce moment, les appels de méthode même dans clox sont lents.

La sémantique de Lox définit une invocation de méthode comme deux opérations -- accéder à la méthode et ensuite appeler le résultat. Notre VM doit supporter celles-ci comme des opérations séparées parce que l'utilisateur _peut_ les séparer. Vous pouvez accéder une méthode sans l'appeler et ensuite invoquer la méthode liée plus tard. Rien de ce que nous avons implémenté jusqu'ici n'est inutile.

Mais _toujours_ exécuter celles-ci comme des opérations séparées a un coût significatif. Chaque fois qu'un programme Lox accède et invoque une méthode, le runtime alloue sur le tas une nouvelle ObjBoundMethod, initialise ses champs, ensuite les tire juste de retour en dehors. Plus tard, le GC doit passer du temps à libérer toutes ces méthodes liées éphémères.

La plupart du temps, un programme Lox accède une méthode et ensuite l'appelle immédiatement. La méthode liée est créée par une instruction bytecode et ensuite consommée par la toute suivante. En fait, c'est si immédiat que le compilateur peut même textuellement _voir_ que cela arrive -- un accès de propriété pointé suivi par une parenthèse ouvrante est très probablement un appel de méthode.

Puisque nous pouvons reconnaître cette paire d'opérations au moment de la compilation, nous avons l'opportunité d'émettre une <span name="super">nouvelle, instruction spéciale</span> qui performe un appel de méthode optimisé.

Nous commençons dans la fonction qui compile les expressions de propriété pointées.

<aside name="super" class="bottom">

Si vous passez assez de temps à regarder votre VM à bytecode courir, vous remarquerez qu'elle exécute souvent la même série d'instructions bytecode l'une après l'autre. Une technique d'optimisation classique est de définir une nouvelle instruction unique appelée une **superinstruction** qui fusionne celles-ci en une seule instruction avec le même comportement que la séquence entière.

Une des plus grandes pertes de performance dans un interpréteur bytecode est le surcoût de décoder et répartir chaque instruction. Fusionner plusieurs instructions en une élimine un peu de cela.

Le défi est de déterminer _quelles_ séquences d'instruction sont assez communes pour bénéficier de cette optimisation. Chaque nouvelle superinstruction réclame un opcode pour son propre usage et il y en a seulement tant à distribuer. Ajoutez-en trop, et vous aurez besoin d'un encodage plus large pour les opcodes, ce qui augmente alors la taille du code et rend le décodage de _toutes_ les instructions plus lent.

</aside>

^code parse-call (3 before, 1 after)

Après que le compilateur a analysé le nom de propriété, nous cherchons une parenthèse gauche. Si nous en matchons une, nous basculons vers un nouveau chemin de code. Là, nous compilons la liste d'arguments exactement comme nous le faisons lors de la compilation d'une expression d'appel. Ensuite nous émettons une nouvelle instruction unique `OP_INVOKE`. Elle prend deux opérandes :

1.  L'index du nom de propriété dans la table des constantes.

2.  Le nombre d'arguments passés à la méthode.

En d'autres termes, cette instruction unique combine les opérandes des instructions `OP_GET_PROPERTY` et `OP_CALL` qu'elle remplace, dans cet ordre. C'est vraiment une fusion de ces deux instructions. Définissons-la.

^code invoke-op (1 before, 1 after)

Et ajoutons-la au désassembleur :

^code disassemble-invoke (2 before, 1 after)

C'est un nouveau format d'instruction spécial, donc elle a besoin d'un peu de logique de désassemblage personnalisée.

^code invoke-instruction

Nous lisons les deux opérandes et ensuite affichons à la fois le nom de la méthode et le compte d'arguments. Là-bas dans la boucle de répartition bytecode de l'interpréteur est où la vraie action commence.

^code interpret-invoke (1 before, 1 after)

La plupart du travail arrive dans `invoke()`, auquel nous arriverons. Ici, nous cherchons le nom de la méthode depuis le premier opérande et ensuite lisons l'opérande compte d'arguments. Ensuite nous passons la main à `invoke()` pour faire le gros du travail. Cette fonction renvoie `true` si l'invocation réussit. Comme d'habitude, un retour `false` signifie qu'une erreur d'exécution s'est produite. Nous vérifions cela ici et avortons l'interpréteur si le désastre a frappé.

Finalement, supposant que l'invocation a réussi, alors il y a une nouvelle CallFrame sur la pile, donc nous rafraîchissons notre copie mise en cache du cadre courant dans `frame`.

Le travail intéressant arrive ici :

^code invoke

D'abord nous attrapons le receveur hors de la pile. Les arguments passés à la méthode sont au-dessus de lui sur la pile, donc nous regardons ce nombre d'emplacements plus bas. Ensuite c'est une simple affaire de caster l'objet vers une instance et invoquer la méthode sur lui.

Cela suppose bien que l'objet _est_ une instance. Comme avec les instructions `OP_GET_PROPERTY`, nous avons aussi besoin de gérer le cas où un utilisateur essaie incorrectement d'appeler une méthode sur une valeur du mauvais type.

^code invoke-check-type (1 before, 1 after)

<span name="helper">C'est</span> une erreur d'exécution, donc nous rapportons cela et évacuons. Sinon, nous obtenons la classe de l'instance et sautons vers cette autre nouvelle fonction utilitaire :

<aside name="helper">

Comme vous pouvez le deviner maintenant, nous divisons ce code en une fonction séparée parce que nous allons le réutiliser plus tard -- dans ce cas pour les appels `super`.

</aside>

^code invoke-from-class

Cette fonction combine la logique de comment la VM implémente les instructions `OP_GET_PROPERTY` et `OP_CALL`, dans cet ordre. D'abord nous cherchons la méthode par nom dans la table de méthode de la classe. Si nous n'en trouvons pas une, nous rapportons cette erreur d'exécution et sortons.

Sinon, nous prenons la fermeture de la méthode et empilons un appel à elle sur la pile CallFrame. Nous n'avons pas besoin d'allouer sur le tas et initialiser une ObjBoundMethod. En fait, nous n'avons même pas besoin de <span name="juggle">jongler</span> quoi que ce soit sur la pile. Le receveur et les arguments de méthode sont déjà juste où ils ont besoin d'être.

<aside name="juggle">

C'est une raison clé _pourquoi_ nous utilisons l'emplacement de pile zéro pour stocker le receveur -- c'est comment l'appelant organise déjà la pile pour un appel de méthode. Une convention d'appel efficace est une partie importante de l'histoire de performance d'une VM à bytecode.

</aside>

Si vous démarrez la VM et exécutez un petit programme qui appelle des méthodes maintenant, vous devriez voir le comportement exactement identique comme avant. Mais, si nous avons fait notre travail correctement, la _performance_ devrait être beaucoup améliorée. J'ai écrit un petit microbenchmark qui fait un lot de 10 000 appels de méthode. Ensuite il teste combien de ces lots il peut exécuter en 10 secondes. Sur mon ordinateur, sans la nouvelle instruction `OP_INVOKE`, il est passé à travers 1 089 lots. Avec cette nouvelle optimisation, il a fini 8 324 lots dans le même temps. C'est _7,6 fois plus rapide_, ce qui est une énorme amélioration quand il s'agit d'optimisation de langage de programmation.

<span name="pat"></span>

<aside name="pat">

Nous ne devrions pas nous taper dans le dos _trop_ fermement. Cette amélioration de performance est relative à notre propre implémentation d'appel de méthode non optimisée qui était assez lente. Faire une allocation tas pour chaque appel de méthode unique ne va gagner aucune course.

</aside>

<img src="image/methods-and-initializers/benchmark.png" alt="Graphique à barres comparant les deux résultats de benchmark." />

### Invoquer les champs

Le crédo fondamental de l'optimisation est : "Tu ne briseras pas la correction." Les <span name="monte">utilisateurs</span> aiment quand une implémentation de langage leur donne une réponse plus vite, mais seulement si c'est la _bonne_ réponse. Hélas, notre implémentation d'invocations de méthode plus rapides échoue à soutenir ce principe :

```lox
class Oops {
  init() {
    fun f() {
      print "not a method";
    }

    this.field = f;
  }
}

var oops = Oops();
oops.field();
```

La dernière ligne ressemble à un appel de méthode. Le compilateur pense qu'elle l'est et émet consciencieusement une instruction `OP_INVOKE` pour elle. Cependant, elle ne l'est pas. Ce qui arrive réellement est un accès de _champ_ qui renvoie une fonction qui est ensuite appelée. En ce moment, au lieu d'exécuter cela correctement, notre VM rapporte une erreur d'exécution quand elle ne peut pas trouver une méthode nommée "field".

<aside name="monte">

Il y a des cas où les utilisateurs peuvent être satisfaits quand un programme renvoie parfois la mauvaise réponse en retour pour tourner significativement plus vite ou avec une meilleure borne sur la performance. Ceux-ci sont le champ des [**algorithmes de Monte Carlo**][monte]. Pour certains cas d'utilisation, c'est un bon compromis.

[monte]: https://fr.wikipedia.org/wiki/M%C3%A9thode_de_Monte-Carlo

La partie importante, cependant, est que l'utilisateur _choisit_ d'appliquer un de ces algorithmes. Nous implémenteurs de langage ne pouvons pas unilatéralement décider de sacrifier la correction de leur programme.

</aside>

Plus tôt, quand nous avons implémenté `OP_GET_PROPERTY`, nous gérions à la fois les accès de champ et de méthode. Pour écraser ce nouveau bug, nous avons besoin de faire la même chose pour `OP_INVOKE`.

^code invoke-field (1 before, 1 after)

Réparation assez simple. Avant de chercher une méthode sur la classe de l'instance, nous cherchons un champ avec le même nom. Si nous trouvons un champ, alors nous le stockons sur la pile à la place du receveur, _sous_ la liste d'arguments. C'est comme ça que `OP_GET_PROPERTY` se comporte puisque cette dernière instruction exécute avant qu'une liste parenthesée subséquente d'arguments ait été évaluée.

Ensuite nous essayons d'appeler la valeur de ce champ comme l'appelable qu'elle est avec espoir. L'assistant `callValue()` vérifiera le type de la valeur et l'appellera comme approprié ou rapportera une erreur d'exécution si la valeur du champ n'est pas un type appelable comme une fermeture.

C'est tout ce qu'il faut pour rendre notre optimisation pleinement sûre. Nous sacrifions un peu de performance, malheureusement. Mais c'est le prix que vous avez à payer parfois. Vous devenez occasionnellement frustré par des optimisations que vous _pourriez_ faire si seulement le langage ne permettait pas quelque cas limite ennuyeux. Mais, en tant qu'<span name="designer">implémenteurs</span> de langage, nous devons jouer le jeu qu'on nous donne.

<aside name="designer">

En tant que _designers_ de langage, notre rôle est très différent. Si nous contrôlons le langage lui-même, nous pouvons parfois choisir de restreindre ou changer le langage de façons qui permettent des optimisations. Les utilisateurs veulent des langages expressifs, mais ils veulent aussi des implémentations rapides. Parfois c'est une bonne conception de langage de sacrifier un peu de puissance si vous pouvez leur donner de la perf en retour.

</aside>

Le code que nous avons écrit ici suit un motif typique en optimisation :

1.  Reconnaître une opération commune ou une séquence d'opérations qui est critique pour la performance. Dans ce cas, c'est un accès méthode suivi par un appel.

2.  Ajouter une implémentation optimisée de ce motif. C'est notre instruction `OP_INVOKE`.

3.  Garder le code optimisé avec quelque logique conditionnelle qui valide que le motif s'applique réellement. S'il le fait, rester sur le chemin rapide. Sinon, se replier sur un comportement non optimisé plus lent mais plus robuste. Ici, cela signifie vérifier que nous appelons réellement une méthode et n'accédons pas à un champ.

Comme votre travail de langage bouge de faire fonctionner l'implémentation _du tout_ à la faire fonctionner _plus vite_, vous vous trouverez dépensant de plus en plus de temps à chercher des motifs comme celui-ci et ajoutant des optimisations gardées pour eux. Les ingénieurs VM à plein temps passent beaucoup de leur carrière dans cette boucle.

Mais nous pouvons arrêter ici pour l'instant. Avec cela, clox supporte maintenant la plupart des fonctionnalités d'un langage de programmation orienté objet, et avec une performance respectable.

<div class="challenges">

## Défis

1.  La recherche dans la table de hachage pour trouver la méthode `init()` d'une classe est à temps constant, mais encore passablement lente. Implémentez quelque chose de plus rapide. Écrivez un benchmark et mesurez la différence de performance.

2.  Dans un langage typé dynamiquement comme Lox, un site d'appel unique peut invoquer une variété de méthodes sur un nombre de classes à travers l'exécution d'un programme. Même ainsi, en pratique, la plupart du temps un site d'appel finit par appeler la méthode exactement identique sur la classe exactement identique pour la durée de l'exécution. La plupart des appels ne sont pas réellement polymorphes même si le langage dit qu'ils peuvent l'être.

    Comment les implémentations de langage avancées optimisent basées sur cette observation ?

3.  Lors de l'interprétation d'une instruction `OP_INVOKE`, la VM doit faire deux recherches dans la table de hachage. D'abord, elle cherche un champ qui pourrait masquer une méthode, et seulement si cela échoue cherche-t-elle une méthode. La première vérification est rarement utile -- la plupart des champs ne contiennent pas de fonctions. Mais elle est _nécessaire_ parce que le langage dit que les champs et les méthodes sont accédés utilisant la même syntaxe, et les champs masquent les méthodes.

    C'est un _choix_ de langage qui affecte la performance de notre implémentation. Était-ce le bon choix ? Si Lox était votre langage, que feriez-vous ?

</div>

<div class="design-note">

## Note de Conception : Budget de Nouveauté

Je me souviens encore de la première fois que j'ai écrit un minuscule programme BASIC sur un TRS-80 et fait faire à un ordinateur quelque chose qu'il n'avait pas fait avant. Cela se sentait comme un super-pouvoir. La première fois que j'ai bricolé juste assez d'un analyseur et interpréteur pour me laisser écrire un minuscule programme dans _mon propre langage_ qui faisait faire une chose à un ordinateur était comme une sorte de méta-super-pouvoir d'ordre supérieur. C'était et reste un sentiment merveilleux.

J'ai réalisé que je pouvais concevoir un langage qui ressemblait et se comportait comme je choisissais. C'était comme si j'étais allé à une école privée qui exigeait des uniformes toute ma vie et ensuite un jour transféré à une école publique où je pouvais porter ce que je voulais. Je n'ai pas besoin d'utiliser des accolades pour les blocs ? Je peux utiliser quelque chose d'autre qu'un signe égal pour l'assignation ? Je peux faire des objets sans classes ? Héritage multiple _et_ multi-méthodes ? Un langage dynamique qui surcharge statiquement, par arité ?

Naturellement, j'ai pris cette liberté et couru avec. J'ai pris les décisions de conception de langage les plus bizarres, les plus arbitraires. Des apostrophes pour les génériques. Pas de virgules entre les arguments. Résolution de surcharge qui peut échouer à l'exécution. J'ai fait les choses différemment juste pour l'amour de la différence.

C'est une expérience très amusante que je recommande hautement. Nous avons besoin de plus de langages de programmation bizarres, d'avant-garde. Je veux voir plus de langages d'art. Je fais encore des langages jouets excentriques pour le plaisir parfois.

_Cependant_, si votre but est le succès où "succès" est défini comme un grand nombre d'utilisateurs, alors vos priorités doivent être différentes. Dans ce cas, votre but primaire est d'avoir votre langage chargé dans les cerveaux d'autant de gens que possible. C'est _vraiment dur_. Cela prend beaucoup d'effort humain de bouger la syntaxe et la sémantique d'un langage d'un ordinateur dans des trillions de neurones.

Les programmeurs sont naturellement conservateurs avec leur temps et prudents sur quels langages valent la peine d'être uploadés dans leur matière grise. Ils ne veulent pas perdre leur temps sur un langage qui finit par ne pas leur être utile. En tant que designer de langage, votre but est ainsi de leur donner autant de puissance de langage que vous pouvez avec aussi peu d'apprentissage requis que possible.

Une approche naturelle est la _simplicité_. Moins votre langage a de concepts et fonctionnalités, moins il y a de volume total de trucs à apprendre. C'est une des raisons pour lesquelles les langages de <span name="dynamic">script</span> minimaux trouvent souvent le succès même s'ils ne sont pas aussi puissants que les gros langages industriels -- ils sont plus faciles pour démarrer avec, et une fois qu'ils sont dans le cerveau de quelqu'un, l'utilisateur veut continuer de les utiliser.

<aside name="dynamic">

En particulier, c'est un gros avantage des langages typés dynamiquement. Un langage statique exige que vous appreniez _deux_ langages -- la sémantique d'exécution et le système de type statique -- avant que vous puissiez arriver au point où vous faites faire des trucs à l'ordinateur. Les langages dynamiques exigent que vous appreniez seulement la première.

Éventuellement, les programmes deviennent assez gros pour que la valeur de l'analyse statique paie pour l'effort d'apprendre ce second langage statique, mais la proposition de valeur n'est pas aussi évidente au départ.

</aside>

Le problème avec la simplicité est que couper simplement des fonctionnalités sacrifie souvent la puissance et l'expressivité. Il y a un art de trouver des fonctionnalités qui frappent au-dessus de leur poids, mais souvent les langages minimaux font simplement moins.

Il y a un autre chemin qui évite beaucoup de ce problème. Le truc est de réaliser qu'un utilisateur n'a pas à charger votre langage entier dans sa tête, _juste la partie qu'il n'a pas déjà dedans_. Comme j'ai mentionné dans une [note de conception plus tôt][note], apprendre est à propos de transférer le _delta_ entre ce qu'ils savent déjà et ce qu'ils ont besoin de savoir.

[note]: parsing-expressions.html#design-note

Beaucoup d'utilisateurs potentiels de votre langage connaissent déjà quelque autre langage de programmation. Toutes fonctionnalités que votre langage partage avec ce langage sont essentiellement "gratuites" quand il s'agit d'apprendre. C'est déjà dans leur tête, ils ont juste à reconnaître que votre langage fait la même chose.

En d'autres termes, la _familiarité_ est un autre outil clé pour abaisser le coût d'adoption de votre langage. Bien sûr, si vous maximisez pleinement cet attribut, le résultat final est un langage qui est complètement identique à un existant. Ce n'est pas une recette pour le succès, parce qu'à ce point il n'y a aucune incitation pour les utilisateurs de passer à votre langage du tout.

Donc vous devez bien fournir quelques différences irrésistibles. Quelques choses que votre langage peut faire que d'autres langages ne peuvent pas, ou au moins ne peuvent pas faire aussi bien. Je crois que c'est un des actes d'équilibre fondamentaux de la conception de langage : la similarité aux autres langages abaisse le coût d'apprentissage, tandis que la divergence élève les avantages irrésistibles.

Je pense à cet acte d'équilibre en termes d'un <span name="idiosyncracy">**budget de nouveauté**</span>, ou comme Steve Klabnik l'appelle, un "[budget d'étrangeté][]". Les utilisateurs ont un seuil bas pour la quantité totale de nouveaux trucs qu'ils sont prêts à accepter pour apprendre un nouveau langage. Excédez cela, et ils ne se montreront pas.

[strangeness budget]: https://words.steveklabnik.com/the-language-strangeness-budget

<aside name="idiosyncracy">

Un concept lié en psychologie est le [**crédit d'idiosyncrasie**][idiosyncracy], l'idée que d'autres gens en société vous accordent une quantité finie de déviations des normes sociales. Vous gagnez du crédit en vous intégrant et en faisant des choses de l'intra-groupe, que vous pouvez ensuite dépenser sur des activités excentriques qui feraient autrement lever les sourcils. En d'autres termes, démontrer que vous êtes "un des bons" vous donne une licence pour lever votre drapeau de monstre, mais seulement jusqu'à un certain point.

[idiosyncracy]: https://en.wikipedia.org/wiki/Idiosyncrasy_credit

</aside>

Chaque fois que vous ajoutez quelque chose de nouveau à votre langage que d'autres langages n'ont pas, ou chaque fois que votre langage fait quelque chose que d'autres langages font d'une manière différente, vous dépensez un peu de ce budget. C'est OK -- vous _devez_ le dépenser pour rendre votre langage irrésistible. Mais votre but est de le dépenser _sagement_. Pour chaque fonctionnalité ou différence, demandez-vous combien de puissance irrésistible elle ajoute à votre langage et ensuite évaluez critiquement si elle paie son chemin. Le changement est-il si précieux qu'il vaut la peine de brûler un peu de votre budget de nouveauté ?

En pratique, je trouve que cela signifie que vous finissez par être assez conservateur avec la syntaxe et plus aventureux avec la sémantique. Aussi amusant que ce soit de mettre un nouveau changement de vêtements, échanger les accolades avec quelque autre délimiteur de bloc est très peu probable d'ajouter beaucoup de vraie puissance au langage, mais cela dépense bien un peu de nouveauté. Il est dur pour les différences de syntaxe de porter leur poids.

D'un autre côté, de nouvelles sémantiques peuvent significativement augmenter la puissance du langage. Multi-méthodes, mixins, traits, réflexion, types dépendants, métaprogrammation à l'exécution, etc. peuvent radicalement augmenter le niveau de ce qu'un utilisateur peut faire avec le langage.

Hélas, être conservateur comme ça n'est pas aussi amusant que de juste tout changer. Mais c'est à vous de décider si vous voulez chasser le succès grand public ou non en premier lieu. Nous n'avons pas tous besoin d'être des groupes pop radio-amicaux. Si vous voulez que votre langage soit comme du free jazz ou du drone metal et êtes heureux avec la taille d'audience proportionnellement plus petite (mais probablement plus dévouée), allez-y.

</div>

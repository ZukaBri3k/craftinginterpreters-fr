> On n'a le droit ni d'aimer ni de haïr quoi que ce soit si l'on n'a pas acquis une connaissance
> approfondie de sa nature. Le grand amour naît de la grande connaissance de l'objet
> aimé, et si vous ne le connaissez que peu vous serez capable de l'aimer seulement
> un peu ou pas du tout.
>
> <cite>Léonard de Vinci</cite>

Nous sommes à onze chapitres, et l'interpréteur assis sur votre machine est presque un langage de script complet. Il pourrait utiliser quelques structures de données intégrées comme des listes et des maps, et il a certainement besoin d'une bibliothèque centrale pour les E/S de fichier, l'entrée utilisateur, etc. Mais le langage lui-même est suffisant. Nous avons un petit langage procédural dans la même veine que BASIC, Tcl, Scheme (moins les macros), et les premières versions de Python et Lua.

Si nous étions dans les années 80, nous nous arrêterions là. Mais aujourd'hui, beaucoup de langages populaires supportent la "programmation orientée objet". Ajouter cela à Lox donnera aux utilisateurs un ensemble familier d'outils pour écrire des programmes plus grands. Même si vous personnellement n'aimez <span name="hate">pas</span> la POO, ce chapitre et [le suivant][inheritance] vous aideront à comprendre comment d'autres conçoivent et construisent des systèmes d'objets.

[inheritance]: inheritance.html

<aside name="hate">

Si vous détestez _vraiment_ les classes, cependant, vous pouvez sauter ces deux chapitres. Ils sont assez isolés du reste du livre. Personnellement, je trouve qu'il est bon d'en apprendre plus sur les choses que je n'aime pas. Les choses semblent simples à distance, mais à mesure que je me rapproche, les détails émergent et je gagne une perspective plus nuancée.

</aside>

## POO et Classes

Il y a trois grandes voies vers la programmation orientée objet : les classes, les [prototypes][], et les <span name="multimethods">[multiméthodes][]</span>. Les classes sont venues en premier et sont le style le plus populaire. Avec la montée de JavaScript (et dans une moindre mesure [Lua][]), les prototypes sont plus largement connus qu'ils ne l'étaient. Je parlerai plus de ceux-ci [plus tard][later]. Pour Lox, nous prenons l'approche, ahem, classique.

[prototypes]: http://gameprogrammingpatterns.com/prototype.html
[multiméthodes]: https://en.wikipedia.org/wiki/Multiple_dispatch
[lua]: https://www.lua.org/pil/13.4.1.html
[later]: #design-note

<aside name="multimethods">

Les multiméthodes sont l'approche avec laquelle vous êtes le moins susceptible d'être familier. J'adorerais parler plus d'elles -- j'ai conçu [un langage hobby][magpie] autour d'elles une fois et elles sont _super cool_ -- mais il n'y a qu'un nombre limité de pages que je peux caser. Si vous aimeriez en apprendre plus, jetez un œil à [CLOS][] (le système d'objet en Common Lisp), [Dylan][], [Julia][], ou [Raku][].

[clos]: https://en.wikipedia.org/wiki/Common_Lisp_Object_System
[magpie]: http://magpie-lang.org/
[dylan]: https://opendylan.org/
[julia]: https://julialang.org/
[raku]: https://docs.raku.org/language/functions#Multi-dispatch

</aside>

Puisque vous avez écrit environ mille lignes de code Java avec moi déjà, je suppose que vous n'avez pas besoin d'une introduction détaillée à l'orientation objet. Le but principal est d'empaqueter des données avec le code qui agit dessus. Les utilisateurs font cela en déclarant une _classe_ qui :

<span name="circle"></span>

1. Expose un _constructeur_ pour créer et initialiser de nouvelles _instances_ de la classe

1. Fournit un moyen de stocker et d'accéder à des _champs_ sur les instances

1. Définit un ensemble de _méthodes_ partagées par toutes les instances de la classe qui opèrent sur l'état de chaque instance.

C'est à peu près aussi minimal que possible. La plupart des langages orientés objet, tout le chemin en arrière jusqu'à Simula, font aussi de l'héritage pour réutiliser le comportement à travers les classes. Nous ajouterons cela dans le [prochain chapitre][inheritance]. Même en virant cela, nous avons encore beaucoup à traverser. C'est un gros chapitre et tout ne s'assemble pas tout à fait jusqu'à ce que nous ayons toutes les pièces ci-dessus, donc rassemblez votre endurance.

<aside name="circle">

<img src="image/classes/circle.png" alt="Les relations entre classes, méthodes, instances, constructeurs, et champs." />

C'est comme le cycle de la vie, _sans_ Sir Elton John.

</aside>

## Déclarations de Classe

Comme nous faisons, nous allons commencer avec la syntaxe. Une instruction `class` introduit un nouveau nom, donc elle vit dans la règle de grammaire `declaration`.

```ebnf
declaration    → classDecl
               | funDecl
               | varDecl
               | statement ;

classDecl      → "class" IDENTIFIER "{" function* "}" ;
```

La nouvelle règle `classDecl` repose sur la règle `function` que nous avons définie [plus tôt][function rule]. Pour rafraîchir votre mémoire :

[function rule]: functions.html#function-declarations

```ebnf
function       → IDENTIFIER "(" parameters? ")" block ;
parameters     → IDENTIFIER ( "," IDENTIFIER )* ;
```

En français clair, une déclaration de classe est le mot-clé `class`, suivi par le nom de la classe, puis un corps entre accolades. À l'intérieur de ce corps est une liste de déclarations de méthode. Contrairement aux déclarations de fonction, les méthodes n'ont pas de mot-clé <span name="fun">`fun`</span> en tête. Chaque méthode est un nom, une liste de paramètres, et un corps. Voici un exemple :

<aside name="fun">

Pas que j'essaie de dire que les méthodes ne sont pas fun ou quoi que ce soit.

</aside>

```lox
class Breakfast {
  cook() {
    print "Eggs a-fryin'!";
  }

  serve(who) {
    print "Enjoy your breakfast, " + who + ".";
  }
}
```

Comme la plupart des langages typés dynamiquement, les champs ne sont pas explicitement listés dans la déclaration de classe. Les instances sont des sacs lâches de données et vous pouvez librement leur ajouter des champs comme bon vous semble en utilisant du code impératif normal.

Là-bas dans notre générateur AST, la règle de grammaire `classDecl` obtient son propre <span name="class-ast">nœud</span> d'instruction.

^code class-ast (1 before, 1 after)

<aside name="class-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-class].

[appendix-class]: appendix-ii.html#class-statement

</aside>

Il stocke le nom de la classe et les méthodes à l'intérieur de son corps. Les méthodes sont représentées par la classe Stmt.Function existante que nous utilisons pour les nœuds AST de déclaration de fonction. Cela nous donne tous les bouts d'état dont nous avons besoin pour une méthode : nom, liste de paramètres, et corps.

Une classe peut apparaître n'importe où une déclaration nommée est autorisée, déclenchée par le mot-clé `class` en tête.

^code match-class (1 before, 1 after)

Cela appelle vers :

^code parse-class-declaration

Il y a plus de viande ici que dans la plupart des autres méthodes de parsing, mais cela suit grossièrement la grammaire. Nous avons déjà consommé le mot-clé `class`, donc nous cherchons le nom de classe attendu ensuite, suivi par l'accolade ouvrante. Une fois à l'intérieur du corps, nous continuons à parser des déclarations de méthode jusqu'à ce que nous frappions l'accolade fermante. Chaque déclaration de méthode est parsée par un appel à `function()`, que nous avons défini là-bas dans le [chapitre où les fonctions ont été introduites][functions].

[functions]: functions.html

Comme nous le faisons dans toute boucle ouverte dans le parseur, nous vérifions aussi si nous frappons la fin du fichier. Cela n'arrivera pas dans le code correct puisqu'une classe devrait avoir une accolade fermante à la fin, mais cela assure que le parseur ne reste pas coincé dans une boucle infinie si l'utilisateur a une erreur de syntaxe et oublie de finir correctement le corps de la classe.

Nous enveloppons le nom et la liste de méthodes dans un nœud Stmt.Class et nous avons fini. Précédemment, nous aurions sauté directement dans l'interpréteur, mais maintenant nous devons d'abord passer le nœud à travers le résolveur.

^code resolver-visit-class

Nous n'allons pas nous inquiéter de résoudre les méthodes elles-mêmes encore, donc pour l'instant tout ce que nous avons besoin de faire est de déclarer la classe en utilisant son nom. Ce n'est pas courant de déclarer une classe comme une variable locale, mais Lox le permet, donc nous devons le gérer correctement.

Maintenant nous interprétons la déclaration de classe.

^code interpreter-visit-class

Cela ressemble à comment nous exécutons les déclarations de fonction. Nous déclarons le nom de la classe dans l'environnement courant. Ensuite nous transformons le _nœud de syntaxe_ de classe en une LoxClass, la représentation à l'_exécution_ d'une classe. Nous revenons en arrière et stockons l'objet classe dans la variable que nous avons précédemment déclarée. Ce processus de liaison de variable en deux étapes permet des références à la classe à l'intérieur de ses propres méthodes.

Nous allons la raffiner tout au long du chapitre, mais le premier brouillon de LoxClass ressemble à ceci :

^code lox-class

Littéralement une enveloppe autour d'un nom. Nous ne stockons même pas les méthodes encore. Pas super utile, mais elle a une méthode `toString()` pour que nous puissions écrire un script trivial et tester que les objets classe sont réellement parsés et exécutés.

```lox
class DevonshireCream {
  serveOn() {
    return "Scones";
  }
}

print DevonshireCream; // Imprime "DevonshireCream".
```

## Créer des Instances

Nous avons des classes, mais elles ne font rien encore. Lox n'a pas de méthodes "statiques" que vous pouvez appeler directement sur la classe elle-même, donc sans instances réelles, les classes sont inutiles. Ainsi les instances sont la prochaine étape.

Bien que certaines syntaxes et sémantiques soient assez standard à travers les langages POO, la façon dont vous créez de nouvelles instances ne l'est pas. Ruby, suivant Smalltalk, crée des instances en appelant une méthode sur l'objet classe lui-même, une approche <span name="turtles">récursivement</span> gracieuse. Certains, comme C++ et Java, ont un mot-clé `new` dédié à donner naissance à un nouvel objet. Python vous fait "appeler" la classe elle-même comme une fonction. (JavaScript, toujours bizarre, fait en quelque sorte les deux.)

<aside name="turtles">

En Smalltalk, même les _classes_ sont créées en appelant des méthodes sur un objet existant, habituellement la superclasse désirée. C'est en quelque sorte une chose où il y a des tortues tout le long vers le bas. Cela touche finalement le fond sur quelques classes magiques comme Object et Metaclass que le runtime conjure dans l'être _ex nihilo_.

</aside>

J'ai pris une approche minimale avec Lox. Nous avons déjà des objets classe, et nous avons déjà des appels de fonction, donc nous utiliserons des expressions d'appel sur des objets classe pour créer de nouvelles instances. C'est comme si une classe était une fonction usine qui génère des instances d'elle-même. Cela semble élégant pour moi, et nous épargne aussi le besoin d'introduire une syntaxe comme `new`. Par conséquent, nous pouvons passer outre le front end directement dans le runtime.

Tout de suite, si vous essayez ceci :

```lox
class Bagel {}
Bagel();
```

Vous obtenez une erreur d'exécution. `visitCallExpr()` vérifie pour voir si l'objet appelé implémente `LoxCallable` et rapporte une erreur puisque LoxClass ne le fait pas. Pas _encore_, c'est-à-dire.

^code lox-class-callable (2 before, 1 after)

Implémenter cette interface exige deux méthodes.

^code lox-class-call-arity

Celle intéressante est `call()`. Quand vous "appelez" une classe, elle instancie une nouvelle LoxInstance pour la classe appelée et la renvoie. La méthode `arity()` est comment l'interpréteur valide que vous avez passé le bon nombre d'arguments à un appelable. Pour l'instant, nous dirons que vous ne pouvez en passer aucun. Quand nous arriverons aux constructeurs définis par l'utilisateur, nous revisiterons cela.

Cela nous mène à LoxInstance, la représentation exécution d'une instance d'une classe Lox. Encore une fois, notre première implémentation commence petit.

^code lox-instance

Comme LoxClass, c'est assez squelettique, mais nous ne faisons que commencer. Si vous voulez lui donner un essai, voici un script à lancer :

```lox
class Bagel {}
var bagel = Bagel();
print bagel; // Imprime "Bagel instance".
```

Ce programme ne fait pas grand-chose, mais il commence à faire _quelque chose_.

## Propriétés sur les Instances

Nous avons des instances, donc nous devrions les rendre utiles. Nous sommes à un embranchement sur la route. Nous pourrions ajouter du comportement d'abord -- des méthodes -- ou nous pourrions commencer avec l'état -- des propriétés. Nous allons prendre ce dernier car, comme nous le verrons, les deux deviennent intriqués d'une façon intéressante et il sera plus facile de leur donner du sens si nous faisons fonctionner les propriétés d'abord.

Lox suit JavaScript et Python dans comment il gère l'état. Chaque instance est une collection ouverte de valeurs nommées. Les méthodes sur la classe de l'instance peuvent accéder et modifier les propriétés, mais le code <span name="outside">externe</span> le peut aussi. Les propriétés sont accédées en utilisant une syntaxe `.`.

<aside name="outside">

Permettre au code en dehors de la classe de modifier directement les champs d'un objet va à l'encontre du credo orienté objet qu'une classe _encapsule_ l'état. Certains langages prennent une position plus fondée sur des principes. En Smalltalk, les champs sont accédés en utilisant des identifieurs simples -- essentiellement, des variables qui sont seulement dans la portée à l'intérieur des méthodes d'une classe. Ruby utilise `@` suivi par un nom pour accéder à un champ dans un objet. Cette syntaxe est seulement significative à l'intérieur d'une méthode et accède toujours à l'état sur l'objet courant.

Lox, pour le meilleur ou pour le pire, n'est pas tout à fait si pieux à propos de sa foi POO.

</aside>

```lox
objet.propriete
```

Une expression suivie par `.` et un identifieur lit la propriété avec ce nom depuis l'objet en lequel l'expression s'évalue. Ce point a la même précédence que les parenthèses dans une expression d'appel de fonction, donc nous le glissons dans la grammaire en remplaçant la règle `call` existante par :

```ebnf
call           → primary ( "(" arguments? ")" | "." IDENTIFIER )* ;
```

Après une expression primaire, nous permettons une série de n'importe quel mélange d'appels parenthésés et d'accès aux propriétés avec point. "Accès aux propriétés" est une bouchée, donc d'ici là, nous appellerons ceux-ci des "expressions d'accès" (get expressions).

### Expressions d'accès

Le <span name="get-ast">nœud d'arbre syntaxique</span> est :

^code get-ast (1 before, 1 after)

<aside name="get-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-get].

[appendix-get]: appendix-ii.html#get-expression

</aside>

Suivant la grammaire, le nouveau code de parsing va dans notre méthode `call()` existante.

^code parse-property (3 before, 4 after)

La boucle `while` externe là correspond au `*` dans la règle de grammaire. Nous zippons le long des tokens construisant une chaîne d'appels et d'accès alors que nous trouvons des parenthèses et des points, comme ceci :

<img src="image/classes/zip.png" alt="Parser une série d'expressions '.' et '()' en un AST." />

Les instances du nouveau nœud Expr.Get alimentent le résolveur.

^code resolver-visit-get

OK, pas grand chose à cela. Puisque les propriétés sont cherchées <span name="dispatch">dynamiquement</span>, elles ne sont pas résolues. Pendant la résolution, nous récursons seulement dans l'expression à la gauche du point. L'accès réel à la propriété se produit dans l'interpréteur.

<aside name="dispatch">

Vous pouvez littéralement voir que le dispatch de propriété dans Lox est dynamique puisque nous ne traitons pas le nom de propriété pendant la passe de résolution statique.

</aside>

^code interpreter-visit-get

D'abord, nous évaluons l'expression dont la propriété est accédée. Dans Lox, seules les instances de classes ont des propriétés. Si l'objet est un autre type comme un nombre, invoquer un getter dessus est une erreur d'exécution.

Si l'objet est une LoxInstance, alors nous lui demandons de chercher la propriété. Il doit être temps de donner à LoxInstance un état réel. Une map fera l'affaire.

^code lox-instance-fields (1 before, 2 after)

Chaque clé dans la map est un nom de propriété et la valeur correspondante est la valeur de la propriété. Pour chercher une propriété sur une instance :

^code lox-instance-get-property

<aside name="hidden">

Faire une recherche dans une table de hachage pour chaque accès de champ est assez rapide pour beaucoup d'implémentations de langage, mais pas idéal. Les VMs haute performance pour des langages comme JavaScript utilisent des optimisations sophistiquées comme les "[classes cachées][]" pour éviter cette surcharge.

Paradoxalement, beaucoup des optimisations inventées pour rendre les langages dynamiques rapides reposent sur l'observation que -- même dans ces langages -- la plupart du code est assez statique en termes des types d'objets avec lesquels il travaille et de leurs champs.

[classes cachées]: http://richardartoul.github.io/jekyll/update/2015/04/26/hidden-classes.html

</aside>

Un cas limite intéressant que nous devons gérer est ce qui arrive si l'instance n'a _pas_ une propriété avec le nom donné. Nous pourrions silencieusement renvoyer une certaine valeur factice comme `nil`, mais mon expérience avec des langages comme JavaScript est que ce comportement masque des bugs plus souvent qu'il ne fait quoi que ce soit d'utile. Au lieu de cela, nous en ferons une erreur d'exécution.

Donc la première chose que nous faisons est de voir si l'instance a réellement un champ avec le nom donné. Seulement alors nous le renvoyons. Sinon, nous levons une erreur.

Notez comment j'ai changé de parler de "propriétés" à "champs". Il y a une différence subtile entre les deux. Les champs sont des bits d'état nommés stockés directement dans une instance. Les propriétés sont les _choses_ nommées, uh, qu'une expression d'accès peut renvoyer. Chaque champ est une propriété, mais comme nous le verrons <span name="foreshadowing">plus tard</span>, pas chaque propriété est un champ.

<aside name="foreshadowing">

Ooh, préfiguration. Effrayant !

</aside>

En théorie, nous pouvons maintenant lire des propriétés sur des objets. Mais puisqu'il n'y a aucun moyen de bourrer réellement un état dans une instance, il n'y a pas de champs auxquels accéder. Avant que nous puissions tester la lecture, nous devons supporter l'écriture.

### Expressions d'affectation

Les setters utilisent la même syntaxe que les getters, sauf qu'ils apparaissent du côté gauche d'une assignation.

```lox
objet.propriete = valeur;
```

Au pays de la grammaire, nous étendons la règle pour l'assignation pour permettre des identifieurs pointés sur le côté gauche.

```ebnf
assignment     → ( call "." )? IDENTIFIER "=" assignment
               | logic_or ;
```

Contrairement aux getters, les setters ne s'enchaînent pas. Cependant, la référence à `call` permet n'importe quelle expression à haute précédence avant le dernier point, incluant n'importe quel nombre de _getters_, comme dans :

<img src="image/classes/setter.png" alt="breakfast.omelette.filling.meat = ham" />

Notez ici que seulement la _dernière_ partie, le `.meat` est le _setter_. Les parties `.omelette` et `.filling` sont tous les deux des expressions _get_.

Tout comme nous avons deux nœuds AST séparés pour l'accès de variable et l'assignation de variable, nous avons besoin d'un <span name="set-ast">second nœud setter</span> pour compléter notre nœud getter.

^code set-ast (1 before, 1 after)

<aside name="set-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-set].

[appendix-set]: appendix-ii.html#set-expression

</aside>

Au cas où vous ne vous souvenez pas, la façon dont nous gérons l'assignation dans le parseur est un peu drôle. Nous ne pouvons pas facilement dire qu'une série de tokens est le côté gauche d'une assignation jusqu'à ce que nous atteignions le `=`. Maintenant que notre règle de grammaire d'assignation a `call` sur le côté gauche, qui peut s'étendre en expressions arbitrairement grandes, ce `=` final peut être à beaucoup de tokens de distance du point où nous avons besoin de savoir que nous parsons une assignation.

Au lieu de cela, l'astuce que nous faisons est de parser le côté gauche comme une expression normale. Ensuite, quand nous trébuchons sur le signe égal après, nous prenons l'expression que nous avons déjà parsée et la transformons en le nœud d'arbre syntaxique correct pour l'assignation.

Nous ajoutons une autre clause à cette transformation pour gérer la transformation d'une expression Expr.Get sur la gauche en l'Expr.Set correspondante.

^code assign-set (1 before, 1 after)

C'est le parsing de notre syntaxe. Nous poussons ce nœud à travers le résolveur.

^code resolver-visit-set

Encore une fois, comme Expr.Get, la propriété elle-même est évaluée dynamiquement, donc il n'y a rien à résoudre là. Tout ce que nous avons besoin de faire est de récurser dans les deux sous-expressions d'Expr.Set, l'objet dont la propriété est définie, et la valeur à laquelle elle est définie.

Cela nous mène à l'interpréteur.

^code interpreter-visit-set

Nous évaluons l'objet dont la propriété est définie et vérifions pour voir s'il est une LoxInstance. Sinon, c'est une erreur d'exécution. Autrement, nous évaluons la valeur étant définie et la stockons sur l'instance. Cela repose sur une nouvelle méthode dans LoxInstance.

<aside name="order">

Ceci est un autre cas limite sémantique. Il y a trois opérations distinctes :

1. Évaluer l'objet.

2. Lever une erreur d'exécution s'il n'est pas une instance d'une classe.

3. Évaluer la valeur.

L'ordre dans lequel celles-ci sont effectuées pourrait être visible par l'utilisateur, ce qui signifie que nous avons besoin de le spécifier soigneusement et de nous assurer que nos implémentations font celles-ci dans le même ordre.

</aside>

^code lox-instance-set-property

Pas de vraie magie ici. Nous bourrons les valeurs directement dans la map Java où les champs vivent. Puisque Lox permet de créer librement de nouveaux champs sur les instances, il n'y a pas besoin de voir si la clé est déjà présente.

## Méthodes sur les Classes

Vous pouvez créer des instances de classes et bourrer des données dedans, mais la classe elle-même ne _fait_ pas vraiment quelque chose. Les instances sont juste des maps et toutes les instances sont plus ou moins les mêmes. Pour les faire se sentir comme des instances _de classes_, nous avons besoin de comportement -- des méthodes.

Notre parseur serviable parse déjà les déclarations de méthode, donc nous sommes bons là. Nous n'avons aussi pas besoin d'ajouter de support parseur pour les _appels_ de méthode. Nous avons déjà `.` (getters) et `()` (appels de fonction). Un "appel de méthode" enchaîne simplement ceux-ci ensemble.

<img src="image/classes/method.png" alt="L'arbre syntaxique pour 'objet.methode(argument)" />

Cela soulève une question intéressante. Qu'arrive-t-il quand ces deux expressions sont séparées ? En supposant que `methode` dans cet exemple est une méthode sur la classe de `objet` et pas un champ sur l'instance, que devrait faire le morceau de code suivant ?

```lox
var m = objet.methode;
m(argument);
```

Ce programme "cherche" la méthode et stocke le résultat -- quel qu'il soit -- dans une variable et ensuite appelle cet objet plus tard. Est-ce autorisé ? Pouvez-vous traiter une méthode comme si c'était une fonction sur l'instance ?

Qu'en est-il de l'autre direction ?

```lox
class Box {}

fun notMethod(argument) {
  print "called function with " + argument;
}

var box = Box();
box.function = notMethod;
box.function("argument");
```

Ce programme crée une instance et ensuite stocke une fonction dans un champ dessus. Ensuite il appelle cette fonction en utilisant la même syntaxe qu'un appel de méthode. Est-ce que ça marche ?

Différents langages ont différentes réponses à ces questions. On pourrit écrire un traité là-dessus. Pour Lox, nous dirons que la réponse à ces deux-là est oui, ça marche. Nous avons quelques raisons pour justifier cela. Pour le second exemple -- appeler une fonction stockée dans un champ -- nous voulons supporter cela parce que les fonctions de première classe sont utiles et les stocker dans des champs est une chose parfaitement normale à faire.

Le premier exemple est plus obscur. Une motivation est que les utilisateurs s'attendent généralement à être capables de hisser une sous-expression hors dans une variable locale sans changer le sens du programme. Vous pouvez prendre ceci :

```lox
breakfast(omelette.filledWith(cheese), sausage);
```

Et le transformer en ceci :

```lox
var eggs = omelette.filledWith(cheese);
breakfast(eggs, sausage);
```

Et cela fait la même chose. De même, puisque le `.` et les `()` dans un appel de méthode _sont_ deux expressions séparées, il semble que vous devriez être capable de hisser la partie _recherche_ dans une variable et ensuite l'appeler <span name="callback">plus tard</span>. Nous devons penser soigneusement à ce qu'est la _chose_ que vous obtenez quand vous cherchez une méthode, et comment elle se comporte, même dans des cas bizarres comme :

<aside name="callback">

Un usage motivant pour cela est les callbacks. Souvent, vous voulez passer un callback dont le corps invoque simplement une méthode sur un certain objet. Être capable de chercher la méthode et de la passer directement vous épargne la corvée de déclarer manuellement une fonction pour l'envelopper. Comparez ceci :

```lox
fun callback(a, b, c) {
  objet.methode(a, b, c);
}

takeCallback(callback);
```

Avec ceci :

```lox
takeCallback(objet.methode);
```

</aside>

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

Si vous attrapez une poignée vers une méthode sur une certaine instance et l'appelez plus tard, est-ce qu'elle "se souvient" de l'instance d'où elle a été tirée ? Est-ce que `this` à l'intérieur de la méthode fait toujours référence à cet objet original ?

Voici un exemple plus pathologique pour tordre votre cerveau :

```lox
 class Person {
  sayName() {
    print this.name;
  }
}

var jane = Person();
jane.name = "Jane";

var bill = Person();
bill.name = "Bill";

bill.sayName = jane.sayName;
bill.sayName(); // ?
```

Est-ce que cette dernière ligne imprime "Bill" parce que c'est l'instance à travers laquelle nous avons _appelé_ la méthode, ou "Jane" parce que c'est l'instance où nous avons d'abord attrapé la méthode ?

Du code équivalent en Lua et JavaScript imprimerait "Bill". Ces langages n'ont pas vraiment une notion de "méthodes". Tout est en quelque sorte fonctions-dans-champs, donc il n'est pas clair que `jane` "possède" `sayName` plus que `bill` ne le fait.

Lox, cependant, a une vraie syntaxe de classe donc nous savons quelles choses appelables sont des méthodes et lesquelles sont des fonctions. Ainsi, comme Python, C#, et autres, nous ferons en sorte que les méthodes "lient" `this` à l'instance originale quand la méthode est d'abord attrapée. Python appelle <span name="bound">ceux-ci</span> des **méthodes liées**.

<aside name="bound">

Je sais, nom imaginatif, pas vrai ?

</aside>

En pratique, c'est habituellement ce que vous voulez. Si vous prenez une référence vers une méthode sur un certain objet pour pouvoir l'utiliser comme un callback plus tard, vous voulez vous souvenir de l'instance à laquelle elle appartenait, même si ce callback se trouve être stocké dans un champ sur un autre objet.

OK, c'est beaucoup de sémantique à charger dans votre tête. Oubliez les cas limites pour un peu. Nous y reviendrons. Pour l'instant, faisons fonctionner les appels de méthode basiques. Nous parsons déjà les déclarations de méthode à l'intérieur du corps de la classe, donc la prochaine étape est de les résoudre.

^code resolve-methods (1 before, 1 after)

<aside name="local">

Stocker le type de fonction dans une variable locale est inutile pour l'instant, mais nous étendrons ce code d'ici peu et cela aura plus de sens.

</aside>

Nous itérons à travers les méthodes dans le corps de la classe et appelons la méthode `resolveFunction()` que nous avons écrite pour gérer les déclarations de fonction précédemment. La seule différence est que nous passons une nouvelle valeur d'enum FunctionType.

^code function-type-method (1 before, 1 after)

Cela va être important quand nous résoudrons les expressions `this`. Pour l'instant, ne vous inquiétez pas pour ça. Le truc intéressant est dans l'interpréteur.

^code interpret-methods (1 before, 1 after)

Quand nous interprétons une instruction de déclaration de classe, nous transformons la représentation syntaxique de la classe -- son nœud AST -- en sa représentation à l'exécution. Maintenant, nous devons faire cela pour les méthodes contenues dans la classe aussi. Chaque déclaration de méthode éclot en un objet LoxFunction.

Nous prenons tous ceux-là et les enveloppons dans une map, indexée par les noms de méthode. Cela est stocké dans LoxClass.

^code lox-class-methods (1 before, 3 after)

Là où une instance stocke l'état, la classe stocke le comportement. LoxInstance a sa map de champs, et LoxClass obtient une map de méthodes. Même si les méthodes sont possédées par la classe, elles sont toujours accédées à travers des instances de cette classe.

^code lox-instance-get-method (5 before, 2 after)

Quand nous cherchons une propriété sur une instance, si nous ne <span name="shadow">trouvons</span> pas un champ correspondant, nous cherchons une méthode avec ce nom sur la classe de l'instance. Si trouvée, nous renvoyons cela. C'est là que la distinction entre "champ" et "propriété" devient significative. Quand vous accédez à une propriété, vous pourriez obtenir un champ -- un peu d'état stocké sur l'instance -- ou vous pourriez frapper une méthode définie sur la classe de l'instance.

La méthode est cherchée en utilisant ceci :

<aside name="shadow">

Chercher un champ d'abord implique que les champs masquent les méthodes, un point sémantique subtil mais important.

</aside>

^code lox-class-find-method

Vous pouvez probablement deviner que cette méthode va devenir plus intéressante plus tard. Pour l'instant, une simple recherche de map sur la table de méthodes de la classe est suffisante pour nous démarrer. Donnez-lui un essai :

<span name="crunch"></span>

```lox
class Bacon {
  eat() {
    print "Crunch crunch crunch!";
  }
}

Bacon().eat(); // Imprime "Crunch crunch crunch!".
```

<aside name="crunch">

Excuses si vous préférez le bacon caoutchouteux plutôt que croustillant. Sentez-vous libre d'ajuster le script à votre goût.

</aside>

## This

Nous pouvons définir à la fois le comportement et l'état sur les objets, mais ils ne sont pas encore liés ensemble. À l'intérieur d'une méthode, nous n'avons aucun moyen d'accéder aux champs de l'objet "courant" -- l'instance sur laquelle la méthode a été appelée -- ni ne pouvons appeler d'autres méthodes sur ce même objet.

Pour atteindre cette instance, elle a besoin d'un <span name="i">nom</span>. Smalltalk, Ruby, et Swift utilisent "self". Simula, C++, Java, et d'autres utilisent "this". Python utilise "self" par convention, mais vous pouvez techniquement l'appeler comme vous voulez.

<aside name="i">

"I" (Je) aurait été un super choix, mais utiliser "i" pour les variables de boucle précède la POO et remonte tout le chemin jusqu'à Fortran. Nous sommes victimes des choix accidentels de nos ancêtres.

</aside>

Pour Lox, puisque nous nous tenons généralement au style Java-esque, nous irons avec "this". À l'intérieur d'un corps de méthode, une expression `this` s'évalue à l'instance sur laquelle la méthode a été appelée. Ou, plus spécifiquement, puisque les méthodes sont accédées et ensuite invoquées comme deux étapes, elle fera référence à l'objet depuis lequel la méthode a été _accédée_.

Cela rend notre travail plus difficile. Regardez :

```lox
class Egotist {
  speak() {
    print this;
  }
}

var method = Egotist().speak;
method();
```

Sur l'avant-dernière ligne, nous attrapons une référence à la méthode `speak()` depuis une instance de la classe. Cela renvoie une fonction, et cette fonction a besoin de se souvenir de l'instance d'où elle a été tirée pour que _plus tard_, sur la dernière ligne, elle puisse encore la trouver quand la fonction est appelée.

Nous avons besoin de prendre `this` au point où la méthode est accédée et de l'attacher à la fonction d'une manière ou d'une autre pour qu'il reste dans les parages aussi longtemps que nous en avons besoin. Hmm... un moyen de stocker quelques données supplémentaires qui traînent autour d'une fonction, hein ? Cela sonne terriblement comme une _fermeture_, n'est-ce pas ?

Si nous définissions `this` comme une sorte de variable cachée dans un environnement qui entoure la fonction renvoyée lors de la recherche d'une méthode, alors les utilisations de `this` dans le corps seraient capables de la trouver plus tard. LoxFunction a déjà la capacité de s'accrocher à un environnement environnant, donc nous avons la machinerie dont nous avons besoin.

Parcourons un exemple pour voir comment ça marche :

```lox
class Cake {
  taste() {
    var adjective = "delicious";
    print "The " + this.flavor + " cake is " + adjective + "!";
  }
}

var cake = Cake();
cake.flavor = "German chocolate";
cake.taste(); // Imprime "The German chocolate cake is delicious!".
```

Quand nous évaluons d'abord la définition de classe, nous créons une LoxFunction pour `taste()`. Sa fermeture est l'environnement entourant la classe, dans ce cas le global. Donc la LoxFunction que nous stockons dans la map de méthodes de la classe ressemble à ceci :

<img src="image/classes/closure.png" alt="La fermeture initiale pour la méthode." />

Quand nous évaluons l'expression d'accès `cake.taste`, nous créons un nouvel environnement qui lie `this` à l'objet depuis lequel la méthode est accédée (ici, `cake`). Ensuite nous faisons une _nouvelle_ LoxFunction avec le même code que l'originale mais utilisant ce nouvel environnement comme sa fermeture.

<img src="image/classes/bound-method.png" alt="La nouvelle fermeture qui lie 'this'." />

C'est la LoxFunction qui est renvoyée lors de l'évaluation de l'expression d'accès pour le nom de méthode. Quand cette fonction est plus tard appelée par une expression `()`, nous créons un environnement pour le corps de méthode comme d'habitude.

<img src="image/classes/call.png" alt="Appeler la méthode liée et créer un nouvel environnement pour le corps de la méthode." />

Le parent de l'environnement du corps est l'environnement que nous avons créé plus tôt pour lier `this` à l'objet courant. Ainsi tout usage de `this` à l'intérieur du corps se résout avec succès à cette instance.

Réutiliser notre code d'environnement pour implémenter `this` s'occupe aussi des cas intéressants où méthodes et fonctions interagissent, comme :

```lox
class Thing {
  getCallback() {
    fun localFunction() {
      print this;
    }

    return localFunction;
  }
}

var callback = Thing().getCallback();
callback();
```

En, disons, JavaScript, il est courant de renvoyer un callback depuis l'intérieur d'une méthode. Ce callback peut vouloir s'accrocher et retenir l'accès à l'objet original -- la valeur `this` -- auquel la méthode était associée. Notre support existant pour les fermetures et les chaînes d'environnement devrait faire tout cela correctement.

Codons-le. La première étape est d'ajouter une <span name="this-ast">nouvelle syntaxe</span> pour `this`.

^code this-ast (1 before, 1 after)

<aside name="this-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-this].

[appendix-this]: appendix-ii.html#this-expression

</aside>

Le parsing est simple puisque c'est un seul token que notre lexer reconnaît déjà comme un mot réservé.

^code parse-this (2 before, 2 after)

Vous pouvez commencer à voir comment `this` fonctionne comme une variable quand nous arrivons au résolveur.

^code resolver-visit-this

Nous le résolvons exactement comme n'importe quelle autre variable locale en utilisant "this" comme le nom pour la "variable". Bien sûr, ça ne va pas marcher maintenant, parce que "this" n'_est pas_ déclaré dans une quelconque portée. Fixons cela là-bas dans `visitClassStmt()`.

^code resolver-begin-this-scope (2 before, 1 after)

Avant que nous entrions et commencions à résoudre les corps des méthodes, nous poussons une nouvelle portée et définissons "this" dedans comme si c'était une variable. Ensuite, quand nous avons fini, nous jetons cette portée environnante.

^code resolver-end-this-scope (2 before, 1 after)

Maintenant, chaque fois qu'une expression `this` est rencontrée (au moins à l'intérieur d'une méthode) elle se résoudra à une "variable locale" définie dans une portée implicite juste en dehors du bloc pour le corps de la méthode.

Le résolveur a une nouvelle _portée_ pour `this`, donc l'interpréteur a besoin de créer un _environnement_ correspondant pour lui. Rappelez-vous, nous devons toujours garder les chaînes de portée du résolveur et les environnements chaînés de l'interpréteur synchronisés l'un avec l'autre. À l'exécution, nous créons l'environnement après que nous ayons trouvé la méthode sur l'instance. Nous remplaçons la ligne de code précédente qui renvoyait simplement la LoxFunction de la méthode par ceci :

^code lox-instance-bind-method (1 before, 3 after)

Notez le nouvel appel à `bind()`. Cela ressemble à ceci :

^code bind-instance

Il n'y a pas grand chose à cela. Nous créons un nouvel environnement niché à l'intérieur de la fermeture originale de la méthode. Sorte d'une fermeture-dans-une-fermeture. Quand la méthode est appelée, cela deviendra le parent de l'environnement du corps de la méthode.

Nous déclarons "this" comme une variable dans cet environnement et la lions à l'instance donnée, l'instance depuis laquelle la méthode est accédée. _Et voilà_, la LoxFunction renvoyée transporte maintenant son propre petit monde persistant où "this" est lié à l'objet.

La tâche restante est d'interpréter ces expressions `this`. Similaire au résolveur, c'est la même chose qu'interpréter une expression de variable.

^code interpreter-visit-this

Allez-y et donnez-lui un essai en utilisant cet exemple de gâteau de tout à l'heure. Avec moins de vingt lignes de code, notre interpréteur gère `this` à l'intérieur des méthodes même dans toutes les façons bizarres dont il peut interagir avec les classes imbriquées, les fonctions à l'intérieur de méthodes, les poignées vers des méthodes, etc.

### Usages invalides de this

Attendez une minute. Qu'arrive-t-il si vous essayez d'utiliser `this` _en dehors_ d'une méthode ? Qu'en est-il de :

```lox
print this;
```

Ou :

```lox
fun notAMethod() {
  print this;
}
```

Il n'y a pas d'instance vers laquelle `this` peut pointer si vous n'êtes pas dans une méthode. Nous pourrions lui donner une certaine valeur par défaut comme `nil` ou en faire une erreur d'exécution, mais l'utilisateur a clairement fait une erreur. Le plus tôt ils trouvent et corrigent cette erreur, le plus heureux ils seront.

Notre passe de résolution est un bon endroit pour détecter cette erreur statiquement. Elle détecte déjà les instructions `return` en dehors des fonctions. Nous ferons quelque chose de similaire pour `this`. Dans la veine de notre enum FunctionType existant, nous définissons un nouveau ClassType.

^code class-type (1 before, 1 after)

Oui, cela pourrait être un Booléen. Quand nous arriverons à l'héritage, cela obtiendra une troisième valeur, d'où l'enum maintenant. Nous ajoutons aussi un champ correspondant, `currentClass`. Sa valeur nous dit si nous sommes actuellement à l'intérieur d'une déclaration de classe pendant que nous traversons l'arbre syntaxique. Il commence à `NONE` ce qui signifie que nous ne sommes pas dans une.

Quand nous commençons à résoudre une déclaration de classe, nous changeons cela.

^code set-current-class (1 before, 1 after)

Comme avec `currentFunction`, nous stockons la valeur précédente du champ dans une variable locale. Cela nous permet de faire du ferroutage sur la JVM pour garder une pile de valeurs `currentClass`. De cette façon nous ne perdons pas la trace de la valeur précédente si une classe s'imbrique à l'intérieur d'une autre.

Une fois que les méthodes ont été résolues, nous "dépilons" cette pile en restaurant l'ancienne valeur.

^code restore-current-class (2 before, 1 after)

Quand nous résolvons une expression `this`, le champ `currentClass` nous donne le bout de donnée dont nous avons besoin pour rapporter une erreur si l'expression ne se produit pas nichée à l'intérieur d'un corps de méthode.

^code this-outside-of-class (1 before, 1 after)

Cela devrait aider les utilisateurs à utiliser `this` correctement, et cela nous épargne d'avoir à gérer la mauvaise utilisation à l'exécution dans l'interpréteur.

## Constructeurs et Initialiseurs

Nous pouvons faire presque tout avec les classes maintenant, et alors que nous approchons de la fin du chapitre nous nous trouvons étrangement concentrés sur un début. Les méthodes et les champs nous permettent d'encapsuler l'état et le comportement ensemble pour qu'un objet _reste_ toujours dans une configuration valide. Mais comment nous assurons-nous qu'un tout nouvel objet _commence_ dans un bon état ?

Pour cela, nous avons besoin de constructeurs. Je trouve qu'ils sont l'une des parties les plus délicates d'un langage à concevoir, et si vous regardez de près la plupart des autres langages, vous verrez des <span name="cracks">fissures</span> autour de la construction d'objet où les coutures du design ne s'ajustent pas tout à fait parfaitement ensemble. Peut-être qu'il y a quelque chose d'intrinsèquement désordonné à propos du moment de la naissance.

<aside name="cracks">

Quelques exemples : En Java, même si les champs finaux doivent être initialisés, il est toujours possible d'en lire un _avant_ qu'il ne l'ait été. Les exceptions -- une fonctionnalité énorme, complexe -- ont été ajoutées à C++ principalement comme un moyen d'émettre des erreurs depuis des constructeurs.

</aside>

"Construire" un objet est en fait une paire d'opérations :

1.  Le runtime <span name="allocate">_alloue_</span> la mémoire requise pour une instance fraîche. Dans la plupart des langages, cette opération est à un niveau fondamental en dessous de ce à quoi le code utilisateur est capable d'accéder.

    <aside name="allocate">

    Le "[placement new][]" de C++ est un exemple rare où les entrailles de l'allocation sont mises à nu pour que le programmeur puisse les piquer.

    </aside>

2.  Ensuite, un morceau de code fourni par l'utilisateur est appelé qui _initialise_ l'objet non formé.

[placement new]: https://en.wikipedia.org/wiki/Placement_syntax

Ce dernier est ce à quoi nous avons tendance à penser quand nous entendons "constructeur", mais le langage lui-même a habituellement fait un peu de travail préparatoire pour nous avant que nous arrivions à ce point. En fait, notre interpréteur Lox a déjà cela couvert quand il crée un nouvel objet LoxInstance.

Nous ferons la partie restante -- l'initialisation définie par l'utilisateur -- maintenant. Les langages ont une variété de notations pour le morceau de code qui met en place un nouvel objet pour une classe. C++, Java, et C# utilisent une méthode dont le nom correspond au nom de la classe. Ruby et Python l'appellent `init()`. Ce dernier est sympa et court, donc nous ferons ça.

Dans l'implémentation de LoxClass de LoxCallable, nous ajoutons quelques lignes de plus.

^code lox-class-call-initializer (2 before, 1 after)

Quand une classe est appelée, après que la LoxInstance soit créée, nous cherchons une méthode "init". Si nous en trouvons une, nous la lions immédiatement et l'invoquons juste comme un appel de méthode normal. La liste d'arguments est transférée au passage.

Cette liste d'arguments signifie que nous avons aussi besoin d'ajuster comment une classe déclare son arité.

^code lox-initializer-arity (1 before, 1 after)

S'il y a un initialiseur, l'arité de cette méthode détermine combien d'arguments vous devez passer quand vous appelez la classe elle-même. Nous n'_exigeons_ pas d'une classe de définir un initialiseur, cependant, comme commodité. Si vous n'avez pas d'initialiseur, l'arité est toujours zéro.

C'est fondamentalement ça. Puisque nous lions la méthode `init()` avant de l'appeler, elle a accès à `this` à l'intérieur de son corps. Cela, avec les arguments passés à la classe, est tout ce dont vous avez besoin pour être capable de mettre en place la nouvelle instance comme vous le désirez.

### Invoquer init() directement

Comme d'habitude, explorer ce nouveau territoire sémantique fait bruisser quelques créatures bizarres. Considérez :

```lox
class Foo {
  init() {
    print this;
  }
}

var foo = Foo();
print foo.init();
```

Pouvez-vous "ré-initialiser" un objet en appelant directement sa méthode `init()` ? Si vous le faites, que renvoie-t-elle ? Une réponse <span name="compromise">raisonnable</span> serait `nil` puisque c'est ce que le corps semble renvoyer.

Cependant -- et je déteste généralement faire des compromis pour satisfaire l'implémentation -- cela rendra l'implémentation des constructeurs de clox beaucoup plus facile si nous disons que les méthodes `init()` renvoient toujours `this`, même quand appelées directement. Afin de garder jlox compatible avec cela, nous ajoutons un petit code de cas spécial dans LoxFunction.

<aside name="compromise">

Peut-être que "déteste" est une affirmation trop forte. Il est raisonnable d'avoir les contraintes et ressources de votre implémentation affecter le design du langage. Il n'y a qu'un nombre limité d'heures dans la journée, et si un coin coupé ici ou là vous permet d'obtenir plus de fonctionnalités pour les utilisateurs en moins de temps, cela peut très bien être une victoire nette pour leur bonheur et productivité. L'astuce est de deviner _quels_ coins couper qui ne causeront pas à vos utilisateurs et votre futur moi de maudire votre myopie.

</aside>

^code return-this (2 before, 1 after)

Si la fonction est un initialiseur, nous surchargeons la valeur de retour réelle et renvoyons de force `this`. Cela repose sur un nouveau champ `isInitializer`.

^code is-initializer-field (2 before, 2 after)

Nous ne pouvons pas simplement voir si le nom de le LoxFunction est "init" parce que l'utilisateur pourrait avoir défini une _fonction_ avec ce nom. Dans ce cas, il n'y a _pas_ de `this` à renvoyer. Pour éviter _ce_ cas limite bizarre, nous stockerons directement si la LoxFunction représente une méthode initialiseur. Cela signifie que nous avons besoin de revenir en arrière et corriger les quelques endroits où nous créons des LoxFunctions.

^code construct-function (1 before, 1 after)

Pour les déclarations de fonction réelles, `isInitializer` est toujours faux. Pour les méthodes, nous vérifions le nom.

^code interpreter-method-initializer (1 before, 1 after)

Et ensuite dans `bind()` où nous créons la fermeture qui lie `this` à une méthode, nous passons la valeur de la méthode originale.

^code lox-function-bind-with-initializer (1 before, 1 after)

### Revenir depuis init()

Nous ne sommes pas encore sortis du bois. Nous avons supposé qu'un initialiseur écrit par l'utilisateur ne renvoie pas explicitement une valeur parce que la plupart des constructeurs ne le font pas. Que devrait-il arriver si un utilisateur essaie :

```lox
class Foo {
  init() {
    return "something else";
  }
}
```

Cela ne va définitivement pas faire ce qu'ils veulent, donc autant en faire une erreur statique. De retour dans le résolveur, nous ajoutons un autre cas à FunctionType.

^code function-type-initializer (1 before, 1 after)

Nous utilisons le nom de la méthode visitée pour déterminer si nous résolvons un initialiseur ou pas.

^code resolver-initializer-type (1 before, 1 after)

Quand nous traversons plus tard dans une instruction `return`, nous vérifions ce champ et en faisons une erreur de renvoyer une valeur depuis l'intérieur d'une méthode `init()`.

^code return-in-initializer (1 before, 1 after)

Nous n'avons _toujours_ pas fini. Nous interdisons statiquement de renvoyer une _valeur_ depuis un initialiseur, mais vous pouvez toujours utiliser un `return` vide anticipé.

```lox
class Foo {
  init() {
    return;
  }
}
```

C'est en fait assez utile parfois, donc nous ne voulons pas l'interdire entièrement. Au lieu de cela, cela devrait renvoyer `this` au lieu de `nil`. C'est une correction facile là-bas dans LoxFunction.

^code early-return-this (1 before, 1 after)

Si nous sommes dans un initialiseur et exécutons une instruction `return`, au lieu de renvoyer la valeur (qui sera toujours `nil`), nous renvoyons encore `this`.

Ouf ! C'était toute une liste de tâches mais notre récompense est que notre petit interpréteur a gagné un paradigme de programmation entier. Classes, méthodes, champs, `this`, et constructeurs. Notre langage bébé a l'air terriblement adulte.

<div class="challenges">

## Défis

1.  Nous avons des méthodes sur les instances, mais il n'y a pas de moyen de définir des méthodes "statiques" qui peuvent être appelées directement sur l'objet classe lui-même. Ajoutez le support pour elles. Utilisez un mot-clé `class` précédant la méthode pour indiquer une méthode statique qui s'accroche à l'objet classe.

    ```lox
    class Math {
      class square(n) {
        return n * n;
      }
    }

    print Math.square(3); // Imprime "9".
    ```

    Vous pouvez résoudre ceci comme vous voulez, mais les "[métaclasses][]" utilisées par Smalltalk et Ruby sont une approche particulièrement élégante. _Indice : Faites en sorte que LoxClass étende LoxInstance et partez de là._

2.  La plupart des langages modernes supportent des "getters" et "setters" -- des membres sur une classe qui ressemblent à des lectures et écritures de champ mais qui exécutent en fait du code défini par l'utilisateur. Étendez Lox pour supporter les méthodes getter. Celles-ci sont déclarées sans liste de paramètres. Le corps du getter est exécuté quand une propriété avec ce nom est accédée.

    ```lox
    class Circle {
      init(radius) {
        this.radius = radius;
      }

      area {
        return 3.141592653 * this.radius * this.radius;
      }
    }

    var circle = Circle(4);
    print circle.area; // Imprime grossièrement "50.2655".
    ```

3.  Python et JavaScript vous permettent d'accéder librement aux champs d'un objet depuis l'extérieur de ses propres méthodes. Ruby et Smalltalk encapsulent l'état de l'instance. Seules les méthodes sur la classe peuvent accéder aux champs bruts, et c'est à la classe de décider quel état est exposé. La plupart des langages typés statiquement offrent des modificateurs comme `private` et `public` pour contrôler quelles parties d'une classe sont accessibles de l'extérieur sur une base par-membre.

    Quels sont les compromis entre ces approches et pourquoi un langage pourrait-il préférer l'une ou l'autre ?

[métaclasses]: https://en.wikipedia.org/wiki/Metaclass

</div>

<div class="design-note">

## Note de Conception : Prototypes et Puissance

Dans ce chapitre, nous avons introduit deux nouvelles entités d'exécution, LoxClass et LoxInstance. La première est où le comportement pour les objets vit, et la dernière est pour l'état. Et si vous pouviez définir des méthodes juste sur un seul objet, à l'intérieur de LoxInstance ? Dans ce cas, nous n'aurions pas besoin de LoxClass du tout. LoxInstance serait un paquet complet pour définir le comportement et l'état d'un objet.

Nous voudrions toujours un moyen, sans classes, de réutiliser le comportement à travers plusieurs instances. Nous pourrions laisser une LoxInstance [_déléguer_][delegate] directement à une autre LoxInstance pour réutiliser ses champs et méthodes, en quelque sorte comme l'héritage.

Les utilisateurs modéliseraient leur programme comme une constellation d'objets, dont certains délèguent les uns aux autres pour refléter la communalité. Les objets utilisés comme délégués représentent des objets "canoniques" ou "prototypiques" que d'autres raffinent. Le résultat est un runtime plus simple avec seulement une seule construction interne, LoxInstance.

C'est de là que le nom **[prototypes][proto]** vient pour ce paradigme. Il a été inventé par David Ungar et Randall Smith dans un langage appelé [Self][]. Ils sont arrivés avec en commençant avec Smalltalk et en suivant l'exercice mental ci-dessus pour voir combien ils pouvaient le réduire.

Les prototypes ont été une curiosité académique pendant longtemps, une fascinante qui a généré de la recherche intéressante mais n'a pas fait une bosse dans le monde plus large de la programmation. C'est-à-dire, jusqu'à ce que Brendan Eich bourre les prototypes dans JavaScript, qui a alors promptement pris le contrôle du monde. Beaucoup (beaucoup) de <span name="words">mots</span> ont été écrits à propos des prototypes dans JavaScript. Si cela montre que les prototypes sont brillants ou confus -- ou les deux ! -- est une question ouverte.

<aside name="words">

Incluant [plus qu'une poignée][prototypes] par votre serviteur.

</aside>

Je n'entrerai pas dans si je pense ou non que les prototypes sont une bonne idée pour un langage. J'ai fait des langages qui sont [prototypaux][finch] et [basés sur des classes][wren], et mes opinions des deux sont complexes. Ce que je veux discuter est le rôle de la _simplicité_ dans un langage.

Les prototypes sont plus simples que les classes -- moins de code pour l'implémenteur du langage à écrire, et moins de concepts pour l'utilisateur à apprendre et comprendre. Est-ce que ça les rend meilleurs ? Nous les nerds des langages avons une tendance à fétichiser le minimalisme. Personnellement, je pense que la simplicité est seulement une partie de l'équation. Ce que nous voulons vraiment donner à l'utilisateur est de la _puissance_, que je définis comme :

```text
puissance = étendue × facilité ÷ complexité
```

Aucune de celles-ci ne sont des mesures numériques précises. J'utilise les maths comme analogie ici, pas une quantification réelle.

- **L'étendue** est la gamme de choses différentes que le langage vous laisse exprimer. C a beaucoup d'étendue -- il a été utilisé pour tout, des systèmes d'exploitation aux applications utilisateur aux jeux. Les langages spécifiques au domaine comme AppleScript et Matlab ont moins d'étendue.

- **La facilité** est le peu d'effort que cela prend pour faire faire au langage ce que vous voulez. "Utilisabilité" pourrait être un autre terme, bien qu'il porte plus de bagages que je ne veux en apporter. Les langages de "plus haut niveau" ont tendance à avoir plus de facilité que ceux de "plus bas niveau". La plupart des langages ont un "grain" à eux où certaines choses semblent plus faciles à exprimer que d'autres.

- **La complexité** est combien le langage (incluant son runtime, bibliothèques centrales, outils, écosystème, etc.) est gros. Les gens parlent de combien de pages sont dans la spec d'un langage, ou combien de mots-clés il a. C'est combien l'utilisateur doit charger dans son cerveau (wetware) avant qu'il puisse être productif dans le système. C'est l'antonyme de la simplicité.

[proto]: https://en.wikipedia.org/wiki/Prototype-based_programming

Réduire la complexité augmente _bien_ la puissance. Plus le dénominateur est petit, plus la valeur résultante est grande, donc notre intuition que la simplicité est bonne est valide. Cependant, quand nous réduisons la complexité, nous devons faire attention de ne pas sacrifier l'étendue ou la facilité dans le processus, ou la puissance totale peut baisser. Java serait un langage strictement _plus simple_ s'il supprimait les chaînes de caractères, mais il ne gérerait probablement pas bien les tâches de manipulation de texte, ni ne serait-il aussi facile de faire avancer les choses.

L'art, alors, est de trouver la complexité _accidentelle_ qui peut être omise -- les fonctionnalités de langage et interactions qui ne portent pas leur poids en augmentant l'étendue ou la facilité d'utilisation du langage.

Si les utilisateurs veulent exprimer leur programme en termes de catégories d'objets, alors cuire les classes dans le langage augmente la facilité de faire cela, avec un peu de chance par une marge assez grande pour payer pour la complexité ajoutée. Mais si ce n'est pas comment les utilisateurs utilisent votre langage, alors par tous les moyens laissez les classes de côté.

</div>

[delegate]: https://en.wikipedia.org/wiki/Prototype-based_programming#Delegation
[prototypes]: http://gameprogrammingpatterns.com/prototype.html
[self]: http://www.selflanguage.org/
[finch]: http://finch.stuffwithstuff.com/
[wren]: http://wren.io/

> Et c'est aussi ainsi que l'esprit humain fonctionne -- par la composition de vieilles
> idées en de nouvelles structures qui deviennent de nouvelles idées qui peuvent elles-mêmes être utilisées dans
> des composés, et en rond et encore en rond sans fin, grandissant toujours plus loin de
> l'imagerie terrestre de base qui est le sol de chaque langage.
>
> <cite>Douglas R. Hofstadter, <em>Je suis une boucle étrange</em></cite>

Ce chapitre marque l'aboutissement de beaucoup de travail difficile. Les chapitres précédents ajoutent des fonctionnalités utiles de leur propre droit, mais chacun fournit aussi une pièce d'un <span name="lambda">puzzle</span>. Nous prendrons ces pièces -- expressions, instructions, variables, contrôle de flux, et portée lexicale -- ajouterons une paire de plus, et assemblerons tout cela pour le support de de vraies fonctions définies par l'utilisateur et des appels de fonctions.

<aside name="lambda">

<img src="image/functions/lambda.png" alt="Un puzzle lambda." />

</aside>

## Appels de Fonctions

Vous êtes certainement familier avec la syntaxe d'appel de fonction de style C, mais la grammaire est plus subtile que vous pouvez le réaliser. Les appels sont typiquement vers des fonctions nommées comme :

```lox
average(1, 2);
```

Mais le <span name="pascal">nom</span> de la fonction appelée ne fait pas en fait partie de la syntaxe d'appel. La chose appelée -- l'**appelé** -- peut être n'importe quelle expression qui s'évalue en une fonction. (Bon, elle doit être une expression à _haute précédence_, mais les parenthèses s'occupent de ça.) Par exemple :

<aside name="pascal">

Le nom _fait_ partie de la syntaxe d'appel en Pascal. Vous ne pouvez appeler que des fonctions nommées ou des fonctions stockées directement dans des variables.

</aside>

```lox
getCallback()();
```

Il y a deux expressions d'appel ici. La première paire de parenthèses a `getCallback` comme son appelé. Mais le second appel a l'expression entière `getCallback()` comme son appelé. Ce sont les parenthèses suivant une expression qui indiquent un appel de fonction. Vous pouvez penser à un appel comme une sorte d'opérateur postfixe qui commence par `(`.

Cet "opérateur" a une plus haute précédence que n'importe quel autre opérateur, même les unaires. Donc nous le glissons dans la grammaire en faisant remonter la règle `unary` vers une nouvelle règle `call`.

<span name="curry"></span>

```ebnf
unary          → ( "!" | "-" ) unary | call ;
call           → primary ( "(" arguments? ")" )* ;
```

Cette règle matche une expression primaire suivie par zéro ou plusieurs appels de fonctions. S'il n'y a pas de parenthèses, cela parse une expression primaire nue. Sinon, chaque appel est reconnu par une paire de parenthèses avec une liste optionnelle d'arguments à l'intérieur. La grammaire de la liste d'arguments est :

<aside name="curry">

La règle utilise `*` pour permettre de matcher une série d'appels comme `fn(1)(2)(3)`. Le code comme ça n'est pas courant dans les langages de style C, mais il l'est dans la famille des langages dérivés de ML. Là, la façon normale de définir une fonction qui prend plusieurs arguments est comme une série de fonctions imbriquées. Chaque fonction prend un argument et renvoie une nouvelle fonction. Cette fonction consomme l'argument suivant, renvoie encore une autre fonction, et ainsi de suite. Finalement, une fois tous les arguments consommés, la dernière fonction complète l'opération.

Ce style, appelé **currying** (curryfication), d'après Haskell Curry (le même gars dont le prénom orne cet _autre_ langage fonctionnel bien connu), est cuit directement dans la syntaxe du langage donc ce n'est pas aussi bizarre à regarder que ce le serait ici.

</aside>

```ebnf
arguments      → expression ( "," expression )* ;
```

Cette règle exige au moins une expression d'argument, suivie par zéro ou plusieurs autres expressions, chacune précédée par une virgule. Pour gérer les appels à zéro argument, la règle `call` elle-même considère la production `arguments` entière comme optionnelle.

J'admets, cela semble plus grammaticalement maladroit que vous ne l'attendriez pour le motif incroyablement courant "zéro ou plusieurs choses séparées par des virgules". Il y a des métasyntaxes sophistiquées qui gèrent cela mieux, mais dans notre BNF et dans beaucoup de spécifications de langages que j'ai vues, c'est aussi encombrant.

Là-bas dans notre générateur d'arbre syntaxique, nous ajoutons un <span name="call-ast">nouveau nœud</span>.

^code call-expr (1 before, 1 after)

<aside name="call-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-call].

[appendix-call]: appendix-ii.html#call-expression

</aside>

Il stocke l'expression de l'appelé et une liste d'expressions pour les arguments. Il stocke aussi le token pour la parenthèse fermante. Nous utiliserons l'emplacement de ce token quand nous rapporterons une erreur d'exécution causée par un appel de fonction.

Ouvrez le parseur. Là où `unary()` avait l'habitude de sauter directement à `primary()`, changez-le pour appeler, eh bien, `call()`.

^code unary-call (3 before, 1 after)

Sa définition est :

^code call

Le code ici ne s'aligne pas tout à fait avec les règles de grammaire. J'ai déplacé quelques choses pour rendre le code plus propre -- l'un des luxes que nous avons avec un parseur écrit à la main. Mais c'est grossièrement similaire à comment nous parsons les opérateurs infixes. D'abord, nous parsons une expression primaire, l'"opérande gauche" de l'appel. Ensuite, chaque fois que nous voyons une `(`, nous appelons `finishCall()` pour parser l'expression d'appel en utilisant l'expression analysée précédemment comme l'appelé. L'expression renvoyée devient la nouvelle `expr` et nous bouclons pour voir si le résultat est lui-même appelé.

<aside name="while-true">

Ce code serait plus simple comme `while (match(LEFT_PAREN))` au lieu du stupide `while (true)` et `break`. Ne vous inquiétez pas, cela aura du sens quand nous étendrons le parseur plus tard pour gérer les propriétés sur les objets.

</aside>

Le code pour parser la liste d'arguments est dans cet assistant :

^code finish-call

C'est plus ou moins la règle de grammaire `arguments` traduite en code, sauf que nous gérons aussi le cas zéro-argument. Nous vérifions ce cas d'abord en voyant si le prochain token est `)`. Si c'est le cas, nous n'essayons de parser aucun argument.

Sinon, nous parsons une expression, puis cherchons une virgule indiquant qu'il y a un autre argument après cela. Nous continuons à faire cela tant que nous trouvons des virgules après chaque expression. Quand nous ne trouvons pas de virgule, alors la liste d'arguments doit être finie et nous consommons la parenthèse fermante attendue. Finalement, nous enveloppons l'appelé et ces arguments dans un nœud AST d'appel.

### Comptes d'arguments maximum

Pour l'instant, la boucle où nous parsons les arguments n'a pas de borne. Si vous voulez appeler une fonction et lui passer un million d'arguments, le parseur n'aurait aucun problème avec ça. Voulons-nous limiter cela ?

D'autres langages ont diverses approches. Le standard C dit qu'une implémentation conforme doit supporter _au moins_ 127 arguments à une fonction, mais ne dit pas qu'il y a une limite supérieure. La spécification Java dit qu'une méthode ne peut accepter _pas plus de_ <span name="254">255</span> arguments.

<aside name="254">

La limite est 25*4* arguments si la méthode est une méthode d'instance. C'est parce que `this` -- le receveur de la méthode -- fonctionne comme un argument qui est implicitement passé à la méthode, donc il réclame l'un des emplacements.

</aside>

Notre interpréteur Java pour Lox n'a pas vraiment besoin d'une limite, mais avoir un nombre maximum d'arguments simplifiera notre interpréteur bytecode dans la [Partie III][]. Nous voulons que nos deux interpréteurs soient compatibles l'un avec l'autre, même dans des cas limites bizarres comme celui-ci, donc nous ajouterons la même limite à jlox.

[part iii]: a-bytecode-virtual-machine.html

^code check-max-arity (1 before, 1 after)

Notez que le code ici _rapporte_ une erreur s'il rencontre trop d'arguments, mais il ne _lance_ pas l'erreur. Lancer est comment nous passons en mode panique qui est ce que nous voulons si le parseur est dans un état confus et ne sait plus où il est dans la grammaire. Mais ici, le parseur est encore dans un état parfaitement valide -- il a juste trouvé trop d'arguments. Donc il rapporte l'erreur et continue son bonhomme de chemin.

### Interpréter des appels de fonction

Nous n'avons aucune fonction que nous pouvons appeler, donc cela semble bizarre de commencer à implémenter les appels d'abord, mais nous nous inquiéterons de cela quand nous y arriverons. D'abord, notre interpréteur a besoin d'un nouvel import.

^code import-array-list (1 after)

Comme toujours, l'interprétation commence avec une nouvelle méthode visit pour notre nœud d'expression d'appel.

^code visit-call

D'abord, nous évaluons l'expression pour l'appelé. Typiquement, cette expression est juste un identifieur qui cherche la fonction par son nom, mais ça pourrait être n'importe quoi. Ensuite nous évaluons chacune des expressions d'argument dans l'ordre et stockons les valeurs résultantes dans une liste.

<aside name="in-order">

Ceci est un autre de ces choix sémantiques subtils. Puisque les expressions d'argument peuvent avoir des effets de bord, l'ordre dans lequel elles sont évaluées pourrait être visible par l'utilisateur. Même ainsi, certains langages comme Scheme et C ne spécifient pas un ordre. Cela donne aux compilateurs la liberté de les réordonner pour l'efficacité, mais signifie que les utilisateurs peuvent être désagréablement surpris si les arguments ne sont pas évalués dans l'ordre qu'ils attendent.

</aside>

Une fois que nous avons l'appelé et les arguments prêts, tout ce qui reste est d'effectuer l'appel. Nous faisons cela en castant l'appelé vers un <span name="callable">LoxCallable</span> et ensuite en invoquant une méthode `call()` dessus. La représentation Java de n'importe quel objet Lox qui peut être appelé comme une fonction implémentera cette interface. Cela inclut les fonctions définies par l'utilisateur, naturellement, mais aussi les objets classe puisque les classes sont "appelées" pour construire de nouvelles instances. Nous l'utiliserons aussi pour un autre but bientôt.

<aside name="callable">

J'ai collé "Lox" devant le nom pour le distinguer de l'interface Callable propre à la bibliothèque standard Java. Hélas, tous les bons noms simples sont déjà pris.

</aside>

Il n'y a pas grand-chose dans cette nouvelle interface.

^code callable

Nous passons l'interpréteur au cas où la classe implémentant `call()` en a besoin. Nous lui donnons aussi la liste des valeurs d'argument évaluées. Le travail de l'implémenteur est alors de renvoyer la valeur que l'expression d'appel produit.

### Erreurs de type d'appel

Avant que nous arrivions à implémenter LoxCallable, nous avons besoin de rendre la méthode visit un peu plus robuste. Elle ignore actuellement une paire de modes d'échec dont nous ne pouvons pas prétendre qu'ils ne se produiront pas. D'abord, qu'arrive-t-il si l'appelé n'est pas réellement quelque chose que vous pouvez appeler ? Et si vous essayez de faire ceci :

```lox
"totalement pas une fonction"();
```

Les chaînes ne sont pas appelables dans Lox. La représentation à l'exécution d'une chaîne Lox est une chaîne Java, donc quand nous castons cela vers LoxCallable, la JVM lancera une ClassCastException. Nous ne voulons pas que notre interpréteur vomisse une méchante trace de pile Java et meure. Au lieu de cela, nous avons besoin de vérifier le type nous-mêmes d'abord.

^code check-is-callable (2 before, 1 after)

Nous lançons toujours une exception, mais maintenant nous lançons notre propre type d'exception, un que l'interpréteur sait attraper et rapporter gracieusement.

### Vérifier l'arité

L'autre problème se rapporte à l'**arité** de la fonction. Arité est le terme fantaisie pour le nombre d'arguments qu'une fonction ou opération attend. Les opérateurs unaires ont une arité de un, les opérateurs binaires deux, etc. Avec les fonctions, l'arité est déterminée par le nombre de paramètres qu'elle déclare.

```lox
fun add(a, b, c) {
  print a + b + c;
}
```

Cette fonction définit trois paramètres, `a`, `b`, et `c`, donc son arité est trois et elle attend trois arguments. Donc et si vous essayez de l'appeler comme ceci :

```lox
add(1, 2, 3, 4); // Trop.
add(1, 2);       // Trop peu.
```

Différents langages prennent différentes approches à ce problème. Bien sûr, la plupart des langages typés statiquement vérifient cela au temps de compilation et refusent de compiler le code si le compte d'arguments ne correspond pas à l'arité de la fonction. JavaScript rejette tous les arguments supplémentaires que vous passez. Si vous n'en passez pas assez, il remplit les paramètres manquants avec la valeur magique `undefined` sorte-de-comme-null-mais-pas-vraiment. Python est plus strict. Il lève une erreur d'exécution si la liste d'arguments est trop courte ou trop longue.

Je pense que cette dernière est une meilleure approche. Passer le mauvais nombre d'arguments est presque toujours un bug, et c'est une erreur que je fais en pratique. Étant donné cela, le plus tôt l'implémentation atire mon attention dessus, le mieux. Donc pour Lox, nous prendrons l'approche de Python. Avant d'invoquer l'appelable, nous vérifions pour voir si la longueur de la liste d'arguments correspond à l'arité de l'appelable.

^code check-arity (1 before, 1 after)

Cela exige une nouvelle méthode sur l'interface LoxCallable pour lui demander son arité.

^code callable-arity (1 before, 1 after)

Nous _pourrions_ pousser la vérification d'arité dans l'implémentation concrète de `call()`. Mais, puisque nous aurons plusieurs classes implémentant LoxCallable, cela finirait avec une validation redondante étalée à travers quelques classes. Le hisser dans la méthode visit nous laisse le faire à un seul endroit.

## Fonctions Natives

Nous pouvons théoriquement appeler des fonctions, mais nous n'avons aucune fonction à appeler encore. Avant que nous arrivions aux fonctions définies par l'utilisateur, maintenant est un bon moment pour introduire une facette vitale mais souvent négligée des implémentations de langage -- les <span name="native">**fonctions natives**</span>. Ce sont des fonctions que l'interpréteur expose au code utilisateur mais qui sont implémentées dans le langage hôte (dans notre cas Java), pas le langage étant implémenté (Lox).

Parfois celles-ci sont appelées **primitives**, **fonctions externes**, ou **foreign functions** (fonctions étrangères). Puisque ces fonctions peuvent être appelées pendant que le programme de l'utilisateur tourne, elles font partie de l'exécution de l'implémentation. Beaucoup de livres de langages de programmation glissent sur celles-ci parce qu'elles ne sont pas conceptuellement intéressantes. C'est surtout du gros œuvre.

<aside name="native">

Curieusement, deux noms pour ces fonctions -- "native" et "foreign" -- sont des antonymes. Peut-être que cela dépend de la perspective de la personne choisissant le terme. Si vous pensez à vous-même comme "vivant" à l'intérieur de l'implémentation de l'exécution (dans notre cas, Java) alors les fonctions écrites là-dedans sont "natives". Mais si vous avez l'état d'esprit d'un _utilisateur_ de votre langage, alors l'exécution est implémentée dans un certain autre langage "étranger".

Ou il se peut que "native" fasse référence au langage code machine du matériel sous-jacent. En Java, les méthodes "natives" sont celles implémentées en C ou C++ et compilées en code machine natif.

<img src="image/functions/foreign.png" class="above" alt="Tout est une question de perspective." />

</aside>

Mais quand il s'agit de rendre votre langage réellement bon à faire des trucs utiles, les fonctions natives que votre implémentation fournit sont clés. Elles fournissent l'accès aux services fondamentaux en termes desquels tous les programmes sont définis. Si vous ne fournissez pas de fonctions natives pour accéder au système de fichiers, un utilisateur va avoir un mal de chien à écrire un programme qui lit et <span name="print">affiche</span> un fichier.

<aside name="print">

Une fonction native classique que presque chaque langage fournit est une pour imprimer du texte vers stdout. Dans Lox, j'ai fait de `print` une instruction intégrée pour que nous puissions obtenir des trucs à l'écran dans les chapitres avant celui-ci.

Une fois que nous avons des fonctions, nous pourrions simplifier le langage en arrachant la vieille syntaxe print et en la remplaçant par une fonction native. Mais cela signifierait que les exemples tôt dans le livre ne tourneraient pas sur l'interpréteur de plus tard et vice versa. Donc, pour le livre, je vais laisser ça tranquille.

Si vous construisez un interpréteur pour votre _propre_ langage, cependant, vous pourriez vouloir le considérer.

</aside>

Beaucoup de langages permettent aussi aux utilisateurs de fournir leurs propres fonctions natives. Le mécanisme pour faire cela est appelé une **interface de fonction étrangère** (**FFI**), **extension native**, **interface native**, ou quelque chose dans ces lignes. Celles-ci sont sympas parce qu'elles libèrent l'implémenteur du langage de fournir l'accès à chaque capacité unique que la plateforme sous-jacente supporte. Nous ne définirons pas une FFI pour jlox, mais nous ajouterons une fonction native pour vous donner une idée de quoi cela a l'air.

### Dire l'heure

Quand nous arriverons à la [Partie III][] et commencerons à travailler sur une implémentation beaucoup plus efficace de Lox, nous allons nous soucier profondément de la performance. Le travail de performance exige de la mesure, et cela à son tour signifie des **benchmarks**. Ce sont des programmes qui mesurent le temps que cela prend pour exercer un certain coin de l'interpréteur.

Nous pourrions mesurer le temps que cela prend pour démarrer l'interpréteur, exécuter le benchmark, et sortir, mais cela ajoute beaucoup de surcharge -- temps de démarrage de la JVM, manigances de l'OS, etc. Ce truc compte, bien sûr, mais si vous essayez juste de valider une optimisation sur une certaine pièce de l'interpréteur, vous ne voulez pas que cette surcharge obscurcisse vos résultats.

Une solution plus jolie est d'avoir le script de benchmark lui-même mesurer le temps écoulé entre deux points dans le code. Pour faire cela, un programme Lox a besoin d'être capable de dire l'heure. Il n'y a aucun moyen de faire cela maintenant -- vous ne pouvez pas implémenter une horloge utile "from scratch" sans accès à l'horloge sous-jacente sur l'ordinateur.

Donc nous ajouterons `clock()`, une fonction native qui renvoie le nombre de secondes qui sont passées depuis un certain point fixe dans le temps. La différence entre deux invocations successives vous dit combien de temps s'est écoulé entre les deux appels. Cette fonction est définie dans la portée globale, donc assurons-nous que l'interpréteur a accès à cela.

^code global-environment (2 before, 2 after)

Le champ `environment` dans l'interpréteur change quand nous entrons et sortons des portées locales. Il suit l'environnement _courant_. Ce nouveau champ `globals` détient une référence fixe vers l'environnement global le plus externe.

Quand nous instancions un Interpreter, nous bourrons la fonction native dans cette portée globale.

^code interpreter-constructor (2 before, 1 after)

Ceci définit une <span name="lisp-1">variable</span> nommée "clock". Sa valeur est une classe anonyme Java qui implémente LoxCallable. La fonction `clock()` ne prend pas d'arguments, donc son arité est zéro. L'implémentation de `call()` appelle la fonction Java correspondante et convertit le résultat en une valeur double en secondes.

<aside name="lisp-1">

Dans Lox, les fonctions et variables occupent le même espace de noms. En Common Lisp, les deux vivent dans leurs propres mondes. Une fonction et une variable avec le même nom n'entrent pas en collision. Si vous appelez le nom, il cherche la fonction. Si vous y faites référence, il cherche la variable. Cela exige effectivement de sauter à travers quelques cerceaux quand vous voulez faire référence à une fonction comme une valeur de première classe.

Richard P. Gabriel et Kent Pitman ont inventé les termes "Lisp-1" par référence aux langages comme Scheme qui mettent fonctions et variables dans le même espace de noms, et "Lisp-2" pour les langages comme Common Lisp qui les partitionnent. Bien qu'étant totalement opaques, ces noms sont restés depuis. Lox est un Lisp-1.

</aside>

Si nous voulions ajouter d'autres fonctions natives -- lire l'entrée de l'utilisateur, travailler avec des fichiers, etc. -- nous pourrions les ajouter chacune comme leur propre classe anonyme qui implémente LoxCallable. Mais pour le livre, celle-ci est vraiment tout ce dont nous avons besoin.

Sortons-nous du business de définir des fonctions et laissons nos utilisateurs prendre le relais...

## Déclarations de Fonction

Nous arrivons enfin à ajouter une nouvelle production à la règle `declaration` que nous avons introduite au moment où nous avons ajouté les variables. Les déclarations de fonction, comme les variables, lient un nouveau <span name="name">nom</span>. Cela signifie qu'elles sont autorisées uniquement aux endroits où une déclaration est permise.

<aside name="name">

Une déclaration de fonction nommée n'est pas vraiment une opération primitive unique. C'est du sucre syntaxique pour deux étapes distinctes : (1) créer un nouvel objet fonction, et (2) lier une nouvelle variable à celui-ci. Si Lox avait une syntaxe pour les fonctions anonymes, nous n'aurions pas besoin d'instructions de déclaration de fonction. Vous pourriez juste faire :

```lox
var add = fun (a, b) {
  print a + b;
};
```

Cependant, puisque les fonctions nommées sont le cas courant, je suis allé de l'avant et ai donné à Lox une syntaxe agréable pour elles.

</aside>

```ebnf
declaration    → funDecl
               | varDecl
               | statement ;
```

La règle `declaration` mise à jour fait référence à cette nouvelle règle :

```ebnf
funDecl        → "fun" function ;
function       → IDENTIFIER "(" parameters? ")" block ;
```

La règle principale `funDecl` utilise une règle assistante séparée `function`. Une _instruction de déclaration_ de fonction est le mot-clé `fun` suivi par le truc fonction-nesque réel. Quand nous arriverons aux classes, nous réutiliserons cette règle `function` pour déclarer des méthodes. Celles-ci ressemblent aux déclarations de fonction, mais ne sont pas précédées par <span name="fun">`fun`</span>.

<aside name="fun">

Les méthodes sont trop classes pour avoir du fun/s'amuser.

</aside>

La fonction elle-même est un nom suivi par la liste de paramètres parenthésée et le corps. Le corps est toujours un bloc entre accolades, utilisant la même règle de grammaire que les instructions de bloc utilisent. La liste de paramètres utilise cette règle :

```ebnf
parameters     → IDENTIFIER ( "," IDENTIFIER )* ;
```

C'est comme la règle `arguments` antérieure, sauf que chaque paramètre est un identifieur, pas une expression. C'est beaucoup de nouvelle syntaxe à mâcher pour le parseur, mais le <span name="fun-ast">nœud</span> AST résultant n'est pas trop mauvais.

^code function-ast (1 before, 1 after)

<aside name="fun-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-fun].

[appendix-fun]: appendix-ii.html#function-statement

</aside>

Un nœud de fonction a un nom, une liste de paramètres (leurs noms), et ensuite le corps. Nous stockons le corps comme la liste d'instructions contenues à l'intérieur des accolades.

Là-bas dans le parseur, nous tissons la nouvelle déclaration.

^code match-fun (1 before, 1 after)

Comme d'autres instructions, une fonction est reconnue par le mot-clé de tête. Quand nous rencontrons `fun`, nous appelons `function`. Cela correspond à la règle de grammaire `function` puisque nous avons déjà matché et consommé le mot-clé `fun`. Nous construirons la méthode un morceau à la fois, en commençant par ceci :

^code parse-function

Pour l'instant, cela consomme uniquement le token identifieur pour le nom de la fonction. Vous pourriez vous demander à propos de ce petit paramètre drôle `kind`. Tout comme nous réutilisons la règle de grammaire, nous réutiliserons la méthode `function()` plus tard pour parser les méthodes à l'intérieur des classes. Quand nous ferons cela, nous passerons "method" pour `kind` pour que les messages d'erreur soient spécifiques au type de déclaration étant parsée.

Ensuite, nous parsons la liste de paramètres et la paire de parenthèses enveloppée autour.

^code parse-parameters (1 before, 1 after)

C'est comme le code pour gérer les arguments dans un appel, sauf non séparé dans une méthode assistante. L'instruction `if` externe gère le cas zéro paramètre, et la boucle `while` interne parse les paramètres tant que nous trouvons des virgules pour les séparer. Le résultat est la liste de tokens pour le nom de chaque paramètre.

Tout comme nous faisons avec les arguments aux appels de fonction, nous validons au moment du parsing que vous n'excédez pas le nombre maximum de paramètres qu'une fonction est autorisée à avoir.

Finalement, nous parsons le corps et enveloppons tout cela dans un nœud de fonction.

^code parse-body (1 before, 1 after)

Notez que nous consommons le `{` au début du corps ici avant d'appeler `block()`. C'est parce que `block()` suppose que le token accolade a déjà été matché. Le consommer ici nous laisse rapporter un message d'erreur plus précis si le `{` n'est pas trouvé puisque nous savons que c'est dans le contexte d'une déclaration de fonction.

## Objets Fonction

Nous avons une certaine syntaxe parsée donc nous sommes habituellement prêts à interpréter, mais d'abord nous avons besoin de penser à comment représenter une fonction Lox en Java. Nous avons besoin de garder une trace des paramètres pour que nous puissions les lier aux valeurs d'argument quand la fonction est appelée. Et, bien sûr, nous avons besoin de garder le code pour le corps de la fonction pour que nous puissions l'exécuter.

C'est fondamentalement ce qu'est la classe Stmt.Function. Pourrions-nous juste utiliser celle-là ? Presque, mais pas tout à fait. Nous avons aussi besoin d'une classe qui implémente LoxCallable pour que nous puissions l'appeler. Nous ne voulons pas que la phase d'exécution de l'interpréteur saigne dans les classes de syntaxe du front end donc nous ne voulons pas que Stmt.Function elle-même implémente cela. Au lieu de cela, nous l'enveloppons dans une nouvelle classe.

^code lox-function

Nous implémentons le `call()` de LoxCallable comme ceci :

^code function-call

Cette poignée de lignes de code est une des pièces les plus fondamentales, puissantes de notre interpréteur. Comme nous avons vu dans [le chapitre sur les instructions et l'<span name="env">état</span>][statements], gérer les environnements de noms est une partie centrale d'une implémentation de langage. Les fonctions sont profondément liées à cela.

[statements]: statements-and-state.html

<aside name="env">

Nous creuserons encore plus profond dans les environnements dans le [prochain chapitre][].

[next chapter]: resolving-and-binding.html

</aside>

Les paramètres sont centraux aux fonctions, particulièrement le fait qu'une fonction _encapsule_ ses paramètres -- aucun autre code en dehors de la fonction ne peut les voir. Cela signifie que chaque fonction obtient son propre environnement où elle stocke ces variables.

De plus, cet environnement doit être créé dynamiquement. Chaque _appel_ de fonction obtient son propre environnement. Sinon, la récursion casserait. S'il y a plusieurs appels à la même fonction en jeu en même temps, chacun a besoin de son _propre_ environnement, même s'ils sont tous des appels à la même fonction.

Par exemple, voici une façon alambiquée de compter jusqu'à trois :

```lox
fun count(n) {
  if (n > 1) count(n - 1);
  print n;
}

count(3);
```

Imaginez que nous mettons en pause l'interpréteur juste au point main où il est sur le point d'imprimer 1 dans l'appel imbriqué le plus interne. Les appels externes pour imprimer 2 et 3 n'ont pas encore imprimé leurs valeurs, donc il doit y avoir des environnements quelque part en mémoire qui stockent encore le fait que `n` est lié à 3 dans un contexte, 2 dans un autre, et 1 dans le plus interne, comme :

<img src="image/functions/recursion.png" alt="Un environnement séparé pour chaque appel récursif." />

C'est pourquoi nous créons un nouvel environnement à chaque _appel_, pas à la _déclaration_ de fonction. La méthode `call()` que nous avons vue plus tôt fait cela. Au début de l'appel, elle crée un nouvel environnement. Ensuite elle parcourt les listes de paramètre et d'argument au pas. Pour chaque paire, elle crée une nouvelle variable avec le nom du paramètre et la lie à la valeur de l'argument.

Donc, pour un programme comme celui-ci :

```lox
fun add(a, b, c) {
  print a + b + c;
}

add(1, 2, 3);
```

Au point de l'appel à `add()`, l'interpréteur crée quelque chose comme ceci :

<img src="image/functions/binding.png" alt="Lier des arguments à leurs paramètres." />

Ensuite `call()` dit à l'interpréteur d'exécuter le corps de la fonction dans ce nouvel environnement local à la fonction. Jusqu'à maintenant, l'environnement courant était l'environnement où la fonction était appelée. Maintenant, nous nous téléportons de là à l'intérieur du nouvel espace de paramètre que nous avons créé pour la fonction.

C'est tout ce qui est requis pour passer des données dans la fonction. En utilisant différents environnements quand nous exécutons le corps, les appels à la même fonction avec le même code peuvent produire différents résultats.

Une fois que le corps de la fonction a fini d'exécuter, `executeBlock()` jette cet environnement local à la fonction et restaure le précédent qui était actif à l'appel. Finalement, `call()` renvoie `null`, ce qui renvoie `nil` à l'appelant. (Nous ajouterons les valeurs de retour plus tard.)

Mécaniquement, le code est assez simple. Parcourir une paire de listes. Lier quelques nouvelles variables. Appeler une méthode. Mais c'est là où le _code_ cristallin de la déclaration de fonction devient une _invocation_ vivante, qui respire. C'est l'un de mes snippets favoris dans ce livre entier. Sentez-vous libre de prendre un moment pour méditer dessus si vous êtes ainsi incliné.

Fini ? OK. Notez quand nous lions les paramètres, nous supposons que les listes de paramètre et d'argument ont la même longueur. C'est sûr parce que `visitCallExpr()` vérifie l'arité avant d'appeler `call()`. Il compte sur la fonction rapportant son arité pour faire cela.

^code function-arity

C'est la majeure partie de notre représentation objet. Pendant que nous sommes ici, nous pourrions aussi bien implémenter `toString()`.

^code function-to-string

Cela donne une sortie plus jolie si un utilisateur décide d'imprimer une valeur de fonction.

```lox
fun add(a, b) {
  print a + b;
}

print add; // "<fn add>".
```

### Interpréter des déclarations de fonction

Nous reviendrons et raffinerons LoxFunction bientôt, mais c'est assez pour commencer. Maintenant nous pouvons visiter une déclaration de fonction.

^code visit-function

C'est similaire à comment nous interprétons d'autres expressions littérales. Nous prenons un _nœud de syntaxe_ de fonction -- une représentation compilation-time de la fonction -- et le convertissons en sa représentation exécution. Ici, c'est une LoxFunction qui enveloppe le nœud de syntaxe.

Les déclarations de fonction sont différentes des autres nœuds littéraux en cela que la déclaration lie _aussi_ l'objet résultant à une nouvelle variable. Donc, après avoir créé la LoxFunction, nous créons une nouvelle liaison dans l'environnement courant et stockons une référence à celui-ci là.

Avec cela, nous pouvons définir et appeler nos propres fonctions tout à l'intérieur de Lox. Essayez :

```lox
fun sayHi(first, last) {
  print "Salut, " + first + " " + last + " !";
}

sayHi("Cher", "Lecteur");
```

Je ne sais pas pour vous, mais cela ressemble à un langage de programmation honnête pour moi.

## Instructions Return

Nous pouvons obtenir des données dans les fonctions en passant des paramètres, mais nous n'avons aucun moyen d'obtenir des résultats en <span name="hotel">_sortie_</span>. Si Lox était un langage orienté expression comme Ruby ou Scheme, le corps serait une expression dont la valeur est implicitement le résultat de la fonction. Mais dans Lox, le corps d'une fonction est une liste d'instructions qui ne produisent pas de valeurs, donc nous avons besoin d'une syntaxe dédiée pour émettre un résultat. En d'autres termes, des instructions `return`. Je suis sûr que vous pouvez deviner la grammaire déjà.

<aside name="hotel">

L'Hôtel California des données.

</aside>

```ebnf
statement      → exprStmt
               | forStmt
               | ifStmt
               | printStmt
               | returnStmt
               | whileStmt
               | block ;

returnStmt     → "return" expression? ";" ;
```

Nous en avons une de plus -- la finale, en fait -- production sous la vénérable règle `statement`. Une instruction `return` est le mot-clé `return` suivi par une expression optionnelle et terminé avec un point-virgule.

La valeur de retour est optionnelle pour supporter de sortir tôt d'une fonction qui ne renvoie pas une valeur utile. Dans les langages typés statiquement, les fonctions "void" ne renvoient pas une valeur et les non-void le font. Puisque Lox est typé dynamiquement, il n'y a pas de vraies fonctions void. Le compilateur n'a aucun moyen de vous empêcher de prendre la valeur résultat d'un appel à une fonction qui ne contient pas d'instruction `return`.

```lox
fun procedure() {
  print "ne renvoie rien";
}

var result = procedure();
print result; // ?
```

Cela signifie que chaque fonction Lox doit renvoyer _quelque chose_, même si elle ne contient aucune instruction `return` du tout. Nous utilisons `nil` pour cela, ce qui est pourquoi l'implémentation de `call()` de LoxFunction renvoie `null` à la fin. Dans la même veine, si vous omettez la valeur dans une instruction `return`, nous la traitons simplement comme équivalente à :

```lox
return nil;
```

Là-bas dans notre générateur AST, nous ajoutons un <span name="return-ast">nouveau nœud</span>.

^code return-ast (1 before, 1 after)

<aside name="return-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-return].

[appendix-return]: appendix-ii.html#return-statement

</aside>

Il garde le token de mot-clé `return` pour que nous puissions utiliser son emplacement pour le rapport d'erreur, et la valeur étant renvoyée, s'il y en a. Nous le parsons comme d'autres instructions, d'abord en reconnaissant le mot-clé initial.

^code match-return (1 before, 1 after)

Cela branche vers :

^code parse-return-statement

Après avoir attrapé le mot-clé `return` consommé précédemment, nous cherchons une expression de valeur. Puisque beaucoup de tokens différents peuvent potentiellement commencer une expression, il est difficile de dire si une valeur de retour est _présente_. Au lieu de cela, nous vérifions si elle est _absente_. Puisqu'un point-virgule ne peut pas commencer une expression, si le prochain token est celui-là, nous savons qu'il ne doit pas y avoir une valeur.

### Revenir des appels

Interpréter une instruction `return` est délicat. Vous pouvez retourner de n'importe où à l'intérieur du corps d'une fonction, même profondément imbriqué à l'intérieur d'autres instructions. Quand le return est exécuté, l'interpréteur a besoin de sauter tout le chemin hors de n'importe quel contexte dans lequel il est actuellement et causer la complétion de l'appel de fonction, comme une sorte de construction de contrôle de flux dopée.

Par exemple, disons que nous exécutons ce programme et nous sommes sur le point d'exécuter l'instruction `return` :

```lox
fun count(n) {
  while (n < 100) {
    if (n == 3) return n; // <--
    print n;
    n = n + 1;
  }
}

count(1);
```

La pile d'appels Java ressemble actuellement grossièrement à ceci :

```text
Interpreter.visitReturnStmt()
Interpreter.visitIfStmt()
Interpreter.executeBlock()
Interpreter.visitBlockStmt()
Interpreter.visitWhileStmt()
Interpreter.executeBlock()
LoxFunction.call()
Interpreter.visitCallExpr()
```

Nous avons besoin d'aller du haut de la pile tout le chemin en arrière à `call()`. Je ne sais pas pour vous, mais pour moi ça sonne comme des exceptions. Quand nous exécutons une instruction `return`, nous utiliserons une exception pour dérouler l'interpréteur au-delà des méthodes visit de toutes les instructions contenantes jusqu'au code qui a commencé à exécuter le corps.

La méthode visit pour notre nouveau nœud AST ressemble à ceci :

^code visit-return

Si nous avons une valeur de retour, nous l'évaluons, sinon, nous utilisons `nil`. Ensuite nous prenons cette valeur et l'enveloppons dans une classe d'exception personnalisée et la lançons.

^code return-exception

Cette classe enveloppe la valeur de retour avec les accessoires que Java exige pour une classe d'exception runtime. L'appel bizarre au constructeur super avec ces arguments `null` et `false` désactive une certaine machinerie JVM dont nous n'avons pas besoin. Puisque nous utilisons notre classe d'exception pour le <span name="exception">contrôle de flux</span> et pas la gestion d'erreur réelle, nous n'avons pas besoin de surcharge comme les traces de pile.

<aside name="exception">

Pour mémoire, je ne suis généralement pas un fan d'utiliser des exceptions pour le contrôle de flux. Mais à l'intérieur d'un interpréteur à parcours d'arbre lourdement récursif, c'est la voie à suivre. Puisque notre propre évaluation d'arbre syntaxique est si lourdement liée à la pile d'appels Java, nous sommes pressés de faire une certaine manipulation de pile d'appels poids lourd occasionnellement, et les exceptions sont un outil pratique pour cela.

</aside>

Nous voulons que cela déroule tout le chemin jusqu'à où l'appel de fonction a commencé, la méthode `call()` dans LoxFunction.

^code catch-return (3 before, 1 after)

Nous enveloppons l'appel à `executeBlock()` dans un bloc try-catch. Quand il attrape une exception de retour, il sort la valeur et en fait la valeur de retour de `call()`. S'il n'attrape jamais une de ces exceptions, cela signifie que la fonction a atteint la fin de son corps sans frapper une instruction `return`. Dans ce cas, elle renvoie implicitement `nil`.

Essayons-le. Nous avons enfin assez de puissance pour supporter cet exemple classique -- une fonction récursive pour calculer les nombres de Fibonacci :

<span name="slow"></span>

```lox
fun fib(n) {
  if (n <= 1) return n;
  return fib(n - 2) + fib(n - 1);
}

for (var i = 0; i < 20; i = i + 1) {
  print fib(i);
}
```

Ce programme minuscule exerce presque chaque fonctionnalité de langage que nous avons passé les nombreux derniers chapitres à implémenter -- expressions, arithmétique, branchement, bouclage, variables, fonctions, appels de fonction, liaison de paramètre, et retours.

<aside name="slow">

Vous pourriez remarquer que c'est assez lent. Évidemment, la récursion n'est pas le moyen le plus efficace de calculer les nombres de Fibonacci, mais comme microbenchmark, cela fait un bon travail de stress test de combien vite notre interpréteur implémente les appels de fonction.

Comme vous pouvez le voir, la réponse est "pas très vite". C'est OK. Notre interpréteur C sera plus rapide.

</aside>

## Fonctions Locales et Fermetures

Nos fonctions sont assez complètes en fonctionnalités, mais il y a un trou à combler. En fait, c'est un écart assez grand pour que nous passions la plupart du [prochain chapitre][] à le sceller, mais nous pouvons commencer ici.

L'implémentation de `call()` de LoxFunction crée un nouvel environnement où elle lie les paramètres de la fonction. Quand je vous ai montré ce code, j'ai glissé sur un point important : Quel est le _parent_ de cet environnement ?

Pour l'instant, c'est toujours `globals`, l'environnement global de niveau supérieur. De cette façon, si un identifieur n'est pas défini à l'intérieur du corps de la fonction lui-même, l'interpréteur peut regarder à l'extérieur de la fonction dans la portée globale pour le trouver. Dans l'exemple Fibonacci, c'est comment l'interpréteur est capable de chercher l'appel récursif à `fib` à l'intérieur du propre corps de la fonction -- `fib` est une variable globale.

Mais rappelez-vous que dans Lox, les déclarations de fonction sont autorisées _n'importe où_ un nom peut être lié. Cela inclut le niveau supérieur d'un script Lox, mais aussi l'intérieur de blocs ou d'autres fonctions. Lox supporte les **fonctions locales** qui sont définies à l'intérieur d'une autre fonction, ou imbriquées à l'intérieur d'un bloc.

Considérez cet exemple classique :

```lox
fun makeCounter() {
  var i = 0;
  fun count() {
    i = i + 1;
    print i;
  }

  return count;
}

var counter = makeCounter();
counter(); // "1".
counter(); // "2".
```

Ici, `count()` utilise `i`, qui est déclaré à l'extérieur d'elle-même dans la fonction contenante `makeCounter()`. `makeCounter()` renvoie une référence à la fonction `count()` et ensuite son propre corps finit d'exécuter complètement.

Pendant ce temps, le code de niveau supérieur invoque la fonction `count()` renvoyée. Cela exécute le corps de `count()`, qui assigne à et lit `i`, même si la fonction où `i` était définie est déjà sortie.

Si vous n'avez jamais rencontré un langage avec des fonctions imbriquées avant, cela pourrait sembler fou, mais les utilisateurs s'attendent bien à ce que ça marche. Hélas, si vous le lancez maintenant, vous obtenez une erreur de variable indéfinie dans l'appel à `counter()` quand le corps de `count()` essaie de chercher `i`. C'est parce que la chaîne d'environnement en effet ressemble à ceci :

<img src="image/functions/global.png" alt="La chaîne d'environnement du corps de count() à la portée globale." />

Quand nous appelons `count()` (à travers la référence à celle-ci stockée dans `counter`), nous créons un nouvel environnement vide pour le corps de la fonction. Le parent de celui-ci est l'environnement global. Nous avons perdu l'environnement pour `makeCounter()` où `i` est lié.

Retournons en arrière dans le temps un peu. Voici à quoi ressemblait la chaîne d'environnement juste au moment où nous déclarions `count()` à l'intérieur du corps de `makeCounter()` :

<img src="image/functions/body.png" alt="La chaîne d'environnement à l'intérieur du corps de makeCounter()." />

Donc au point où la fonction est déclarée, nous pouvons voir `i`. Mais quand nous revenons de `makeCounter()` et sortons de son corps, l'interpréteur jette cet environnement. Puisque l'interpréteur ne garde pas l'environnement entourant `count()` dans les parages, c'est à l'objet fonction lui-même de s'y accrocher.

Cette structure de données est appelée une <span name="closure">**fermeture**</span> (closure) parce qu'elle "ferme sur" et s'accroche aux variables environnantes où la fonction est déclarée. Les fermetures existent depuis les premiers jours de Lisp, et les hackers de langage sont arrivés avec toutes sortes de façons de les implémenter. Pour jlox, nous ferons la chose la plus simple qui marche. Dans LoxFunction, nous ajoutons un champ pour stocker un environnement.

<aside name="closure">

"Closure" est encore un autre terme inventé par Peter J. Landin. Je suppose qu'avant qu'il n'arrive les informaticiens communiquaient les uns avec les autres en utilisant seulement des grognements primitifs et des gestes de la main.

</aside>

^code closure-field (1 before, 1 after)

Nous initialisons cela dans le constructeur.

^code closure-constructor (1 after)

Quand nous créons une LoxFunction, nous capturons l'environnement courant.

^code visit-closure (1 before, 1 after)

C'est l'environnement qui est actif quand la fonction est _déclarée_ pas quand elle est _appelée_, qui est ce que nous voulons. Il représente la portée lexicale entourant la déclaration de fonction. Finalement, quand nous appelons la fonction, nous utilisons cet environnement comme parent de l'appel au lieu d'aller directement à `globals`.

^code call-closure (1 before, 1 after)

Cela crée une chaîne d'environnement qui va du corps de la fonction vers l'extérieur à travers les environnements où la fonction est déclarée, tout le chemin vers l'extérieur jusqu'à la portée globale. La chaîne d'environnement d'exécution correspond à l'imbrication textuelle du code source comme nous voulons. Le résultat final quand nous appelons cette fonction ressemble à ceci :

<img src="image/functions/closure.png" alt="La chaîne d'environnement avec la fermeture." />

Maintenant, comme vous pouvez le voir, l'interpréteur peut encore trouver `i` quand il en a besoin parce qu'il est au milieu de la chaîne d'environnement. Essayez de lancer cet exemple `makeCounter()` maintenant. Ça marche !

Les fonctions nous permettent d'abstraire, réutiliser, et composer du code. Lox est beaucoup plus puissant que la calculatrice arithmétique rudimentaire qu'il était. Hélas, dans notre hâte de bourrer les fermetures dedans, nous avons laissé un tout petit peu de portée dynamique fuiter dans l'interpréteur. Dans le [prochain chapitre][], nous explorerons plus profondément dans la portée lexicale et fermerons ce trou.

[next chapter]: resolving-and-binding.html

<div class="challenges">

## Défis

1.  Notre interpréteur vérifie soigneusement que le nombre d'arguments passés à une fonction correspond au nombre de paramètres qu'elle attend. Puisque cette vérification est faite à l'exécution sur chaque appel, elle a un coût de performance. Les implémentations Smalltalk n'ont pas ce problème. Pourquoi pas ?

2.  La syntaxe de déclaration de fonction de Lox effectue deux opérations indépendantes. Elle crée une fonction et la lie aussi à un nom. Cela améliore l'utilisabilité pour le cas courant où vous voulez associer un nom à la fonction. Mais dans le code de style fonctionnel, vous voulez souvent créer une fonction pour la passer immédiatement à une autre fonction ou la renvoyer. Dans ce cas, elle n'a pas besoin d'un nom.

    Les langages qui encouragent un style fonctionnel supportent habituellement les **fonctions anonymes** ou **lambdas** -- une syntaxe d'expression qui crée une fonction sans la lier à un nom. Ajoutez la syntaxe de fonction anonyme à Lox pour que cela marche :

    ```lox
    fun thrice(fn) {
      for (var i = 1; i <= 3; i = i + 1) {
        fn(i);
      }
    }

    thrice(fun (a) {
      print a;
    });
    // "1".
    // "2".
    // "3".
    ```

    Comment gérez-vous le cas délicat d'une expression de fonction anonyme se produisant dans une instruction d'expression :

    ```lox
    fun () {};
    ```

3.  Est-ce que ce programme est valide ?

    ```lox
    fun scope(a) {
      var a = "local";
    }
    ```

    En d'autres termes, est-ce que les paramètres d'une fonction sont dans la _même_ portée que ses variables locales, ou dans une portée externe ? Que fait Lox ? Et à propos d'autres langages avec lesquels vous êtes familier ? Que pensez-vous qu'un langage _devrait_ faire ?

</div>

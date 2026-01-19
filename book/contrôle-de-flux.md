> La logique, comme le whisky, perd son effet bénéfique quand prise en trop larges
> quantités.
>
> <cite>Edward John Moreton Drax Plunkett, Lord Dunsany</cite>

Comparé au marathon épuisant du [dernier chapitre][statements], aujourd'hui est une gambade légère à travers une prairie de marguerites. Mais alors que le travail est facile, la récompense est étonnamment grande.

[statements]: statements-and-state.html

Pour l'instant, notre interpréteur est un peu plus qu'une calculatrice. Un programme Lox peut seulement faire une quantité fixe de travail avant de se terminer. Pour le faire tourner deux fois plus longtemps, vous devez rendre le code source deux fois plus long. Nous sommes sur le point de corriger cela. Dans ce chapitre, notre interpréteur fait un grand pas vers les ligues majeures des langages de programmation : la _Turing-complétude_.

## Machines de Turing (Brièvement)

Au début du siècle dernier, les mathématiciens ont trébuché sur une série de <span name="paradox">paradoxes</span> confus qui les ont menés à douter de la stabilité de la fondation sur laquelle ils avaient construit leur travail. Pour adresser cette [crise][crisis], ils sont retournés à la case départ. En partant d'une poignée d'axiomes, de logique, et de théorie des ensembles, ils espéraient reconstruire les mathématiques au-dessus d'une fondation imperméable.

[crisis]: https://en.wikipedia.org/wiki/Foundations_of_mathematics#Foundational_crisis

<aside name="paradox">

Le plus célèbre est le [**paradoxe de Russell**][russell]. Initialement, la théorie des ensembles vous permettait de définir n'importe quelle sorte d'ensemble. Si vous pouviez le décrire en anglais, c'était valide. Naturellement, étant donné la prédilection des mathématiciens pour l'auto-référence, les ensembles peuvent contenir d'autres ensembles. Donc Russell, coquin qu'il était, est arrivé avec :

_R est l'ensemble de tous les ensembles qui ne se contiennent pas eux-mêmes._

Est-ce que R se contient lui-même ? S'il ne le fait pas, alors selon la seconde moitié de la définition il le devrait. Mais s'il le fait, alors il ne respecte plus la définition. Cerveau qui explose.

[russell]: https://fr.wikipedia.org/wiki/Paradoxe_de_Russell

</aside>

Ils voulaient répondre rigoureusement à des questions comme, "Toutes les instructions vraies peuvent-elles être prouvées ?", "Pouvons-nous [calculer][compute] toutes les fonctions que nous pouvons définir ?", ou même la question plus générale, "Que voulons-nous dire quand nous prétendons qu'une fonction est 'calculable' ?"

[compute]: https://en.wikipedia.org/wiki/Computable_function

Ils présumaient que la réponse aux deux premières questions serait "oui". Tout ce qui restait était de le prouver. Il s'avère que la réponse aux deux est "non", et étonnamment, les deux questions sont profondément entrelacées. C'est un coin fascinant des mathématiques qui touche aux questions fondamentales sur ce que les cerveaux sont capables de faire et comment l'univers fonctionne. Je ne peux pas lui rendre justice ici.

Ce que je veux noter est que dans le processus de prouver que la réponse aux deux premières questions est "non", Alan Turing et Alonzo Church ont conçu une réponse précise à la dernière question -- une définition de quels types de fonctions sont <span name="uncomputable">calculables</span>. Ils ont chacun fabriqué un système minuscule avec un ensemble minimum de machinerie qui est encore assez puissant pour calculer n'importe laquelle d'une (très) grande classe de fonctions.

<aside name="uncomputable">

Ils ont prouvé que la réponse à la première question est "non" en montrant que la fonction qui renvoie la valeur de vérité d'une instruction donnée n'est _pas_ calculable.

</aside>

Celles-ci sont maintenant considérées comme les "fonctions calculables". Le système de Turing est appelé une <span name="turing">**machine de Turing**</span>. Celui de Church est le **lambda-calcul**. Les deux sont encore largement utilisés comme base pour les modèles de calcul et, en fait, beaucoup de langages de programmation fonctionnels modernes utilisent le lambda-calcul à leur cœur.

<aside name="turing">

Turing appelait ses inventions "a-machines" pour "automatique". Il n'était pas auto-glorifiant au point de mettre son _propre_ nom dessus. Plus tard les mathématiciens ont fait ça pour lui. C'est comme ça qu'on devient célèbre tout en gardant un peu de modestie.

</aside>

<img src="image/control-flow/turing-machine.png" alt="Une machine de Turing." />

Les machines de Turing ont une meilleure reconnaissance de nom -- il n'y a pas encore de film hollywoodien sur Alonzo Church -- mais les deux formalismes sont [équivalents en puissance][thesis]. En fait, n'importe quel langage de programmation avec un certain niveau minimal d'expressivité est assez puissant pour calculer _n'importe quelle_ fonction calculable.

[thesis]: https://en.wikipedia.org/wiki/Church%E2%80%93Turing_thesis

Vous pouvez prouver cela en écrivant un simulateur pour une machine de Turing dans votre langage. Puisque Turing a prouvé que sa machine peut calculer n'importe quelle fonction calculable, par extension, cela signifie que votre langage le peut aussi. Tout ce que vous avez besoin de faire est de traduire la fonction en une machine de Turing, et ensuite d'exécuter cela sur votre simulateur.

Si votre langage est assez expressif pour faire cela, il est considéré **Turing-complet**. Les machines de Turing sont assez simples, donc ça ne prend pas beaucoup de puissance pour faire cela. Vous avez fondamentalement besoin d'arithmétique, d'un peu de contrôle de flux, et de la capacité d'allouer et d'utiliser (théoriquement) des quantités arbitraires de mémoire. Nous avons la première. À la fin de ce chapitre, nous aurons la <span name="memory">seconde</span>.

<aside name="memory">

Nous avons _presque_ la troisième aussi. Vous pouvez créer et concaténer des chaînes de taille arbitraire, donc vous pouvez _stocker_ une mémoire illimitée. Mais nous n'avons aucun moyen d'accéder aux parties d'une chaîne.

</aside>

## Exécution Conditionnelle

Assez d'histoire, allons jazzer notre langage. Nous pouvons diviser le contrôle de flux grossièrement en deux types :

- Le **contrôle de flux conditionnel** ou **de branchement** est utilisé pour _ne pas_ exécuter un certain morceau de code. Impérativement, vous pouvez penser à cela comme sauter _par-dessus_ une région de code.

- Le **contrôle de flux de boucle** exécute un morceau de code plus d'une fois. Il saute en _arrière_ pour que vous puissiez faire quelque chose à nouveau. Puisque vous ne voulez généralement pas de boucles _infinies_, il a typiquement une certaine logique conditionnelle pour savoir quand arrêter de boucler aussi.

Le branchement est plus simple, donc nous commencerons là. Les langages dérivés de C ont deux fonctionnalités principales d'exécution conditionnelle, l'instruction `if` et l'<span name="ternary">opérateur</span> "conditionnel" nommé avec perspicacité (`?:`). Une instruction `if` vous laisse exécuter conditionnellement des instructions et l'opérateur conditionnel vous laisse exécuter conditionnellement des expressions.

<aside name="ternary">

L'opérateur conditionnel est aussi appelé l'opérateur "ternaire" parce que c'est le seul opérateur en C qui prend trois opérandes.

</aside>

Pour la simplicité, Lox n'a pas d'opérateur conditionnel, donc allons-y avec notre instruction `if`. Notre grammaire d'instructions obtient une nouvelle production.

<span name="semicolon"></span>

```ebnf
statement      → exprStmt
               | ifStmt
               | printStmt
               | block ;

ifStmt         → "if" "(" expression ")" statement
               ( "else" statement )? ;
```

<aside name="semicolon">

Les points-virgules dans les règles ne sont pas cités, ce qui signifie qu'ils font partie de la métasyntaxe de grammaire, pas de la syntaxe de Lox. Un bloc n'a pas de `;` à la fin et une instruction `if` non plus, à moins que l'instruction then ou else se trouve être une qui finit par un point-virgule.

</aside>

Une instruction `if` a une expression pour la condition, puis une instruction à exécuter si la condition est truthy ("vraie"). Optionnellement, elle peut aussi avoir un mot-clé `else` et une instruction à exécuter si la condition est falsey ("fausse"). Le <span name="if-ast">nœud d'arbre syntaxique</span> a des champs pour chacune de ces trois pièces.

^code if-ast (1 before, 1 after)

<aside name="if-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-if].

[appendix-if]: appendix-ii.html#if-statement

</aside>

Comme les autres instructions, le parseur reconnaît une instruction `if` par le mot-clé `if` de tête.

^code match-if (1 before, 1 after)

Quand il en trouve un, il appelle cette nouvelle méthode pour parser le reste :

^code if-statement

<aside name="parens">

Les parenthèses autour de la condition sont seulement à moitié utiles. Vous avez besoin d'une sorte de délimiteur _entre_ la condition et l'instruction then, sinon le parseur ne peut pas dire quand il a atteint la fin de l'expression de condition. Mais la parenthèse _ouvrante_ après `if` ne fait rien d'utile. Dennis Ritchie l'a mise là pour qu'il puisse utiliser `)` comme délimiteur de fin sans avoir de parenthèses non balancées.

D'autres langages comme Lua et certains BASICs utilisent un mot-clé comme `then` comme délimiteur de fin et n'ont rien avant la condition. Go et Swift exigent à la place que l'instruction soit un bloc entre accolades. Cela leur permet d'utiliser le `{` au début de l'instruction pour dire quand la condition est finie.

</aside>

Comme d'habitude, le code de parsing colle de près à la grammaire. Il détecte une clause else en cherchant le mot-clé `else` précédent. S'il n'y en a pas, le champ `elseBranch` dans l'arbre syntaxique est `null`.

Ce else optionnel apparemment inoffensif a, en fait, ouvert une ambiguïté dans notre grammaire. Considérez :

```lox
if (first) if (second) whenTrue(); else whenFalse();
```

Voici l'énigme : À quelle instruction `if` cette clause else appartient-elle ? Ce n'est pas juste une question théorique sur la façon dont nous notons notre grammaire. Cela affecte réellement comment le code s'exécute :

- Si nous attachons le else à la première instruction `if`, alors `whenFalse()` est appelée si `first` est falsey, peu importe quelle valeur `second` a.

- Si nous l'attachons à la seconde instruction `if`, alors `whenFalse()` est seulement appelée si `first` est truthy et `second` est falsey.

Puisque les clauses else sont optionnelles, et qu'il n'y a pas de délimiteur explicite marquant la fin de l'instruction `if`, la grammaire est ambiguë quand vous imbriquez des `if`s de cette façon. Ce piège classique de syntaxe est appelé le problème du **[dangling else][dangling else]** (else pendant).

[dangling else]: https://en.wikipedia.org/wiki/Dangling_else

<span name="else"></span>

<img class="above" src="image/control-flow/dangling-else.png" alt="Deux façons dont le else peut être interprété." />

<aside name="else">

Ici, le formatage souligne les deux façons dont le else pourrait être parsé. Mais notez que puisque les caractères d'espacement sont ignorés par le parseur, c'est seulement un guide pour le lecteur humain.

</aside>

Il _est_ possible de définir une grammaire hors-contexte qui évite l'ambiguïté directement, mais elle exige de diviser la plupart des règles d'instruction en paires, une qui permet un `if` avec un `else` et une qui ne le permet pas. C'est ennuyeux.

Au lieu de cela, la plupart des langages et parseurs évitent le problème d'une manière ad hoc. Peu importe quel hack ils utilisent pour se sortir du pétrin, ils choisissent toujours la même interprétation -- le `else` est lié au `if` le plus proche qui le précède.

Notre parseur fait commodément cela déjà. Puisque `ifStatement()` cherche avidement un `else` avant de retourner, l'appel le plus interne à une série imbriquée réclamera la clause else pour lui-même avant de retourner aux instructions `if` externes.

Syntaxe en main, nous sommes prêts à interpréter.

^code visit-if

L'implémentation de l'interpréteur est une fine enveloppe autour du code Java lui-même. Elle évalue la condition. Si truthy, elle exécute la branche then. Sinon, s'il y a une branche else, elle exécute celle-là.

Si vous comparez ce code à la façon dont l'interpréteur gère d'autres syntaxes que nous avons implémentées, la partie qui rend le contrôle de flux spécial est cette instruction `if` Java. La plupart des autres arbres syntaxiques évaluent toujours leurs sous-arbres. Ici, nous pouvons ne pas évaluer l'instruction then ou else. Si l'une ou l'autre a un effet de bord, le choix de ne pas l'évaluer devient visible par l'utilisateur.

## Opérateurs Logiques

Puisque nous n'avons pas l'opérateur conditionnel, vous pourriez penser que nous en avons fini avec le branchement, mais non. Même sans l'opérateur ternaire, il y a deux autres opérateurs qui sont techniquement des constructions de contrôle de flux -- les opérateurs logiques `and` et `or`.

Ceux-ci ne sont pas comme les autres opérateurs binaires parce qu'ils **court-circuitent**. Si, après avoir évalué l'opérande gauche, nous savons quel doit être le résultat de l'expression logique, nous n'évaluons pas l'opérande droit. Par exemple :

```lox
false and sideEffect();
```

Pour qu'une expression `and` s'évalue en quelque chose de truthy, les deux opérandes doivent être truthy. Nous pouvons voir dès que nous évaluons l'opérande gauche `false` que ça ne va pas être le cas, donc il n'y a pas besoin d'évaluer `sideEffect()` et il est sauté.

C'est pourquoi nous n'avons pas implémenté les opérateurs logiques avec les autres opérateurs binaires. Maintenant nous sommes prêts. Les deux nouveaux opérateurs sont bas dans la table de précédence. Similaire à `||` et `&&` en C, ils ont chacun leur <span name="logical">propre</span> précédence avec `or` plus bas que `and`. Nous les glissons juste entre `assignment` et `equality`.

<aside name="logical">

Je me suis toujours demandé pourquoi ils n'ont pas la même précédence, comme le font les divers opérateurs de comparaison ou d'égalité.

</aside>

```ebnf
expression     → assignment ;
assignment     → IDENTIFIER "=" assignment
               | logic_or ;
logic_or       → logic_and ( "or" logic_and )* ;
logic_and      → equality ( "and" equality )* ;
```

Au lieu de se replier sur `equality`, `assignment` cascade maintenant vers `logic_or`. Les deux nouvelles règles, `logic_or` et `logic_and`, sont <span name="same">similaires</span> aux autres opérateurs binaires. Puis `logic_and` appelle `equality` pour ses opérandes, et nous rechaînons vers le reste des règles d'expression.

<aside name="same">

La _syntaxe_ se fiche qu'ils court-circuitent. C'est une préoccupation sémantique.

</aside>

Nous pourrions réutiliser la classe Expr.Binary existante pour ces deux nouvelles expressions puisqu'elles ont les mêmes champs. Mais alors `visitBinaryExpr()` devrait vérifier pour voir si l'opérateur est l'un des opérateurs logiques et utiliser un chemin de code différent pour gérer le court-circuitage. Je pense que c'est plus propre de définir une <span name="logical-ast">nouvelle classe</span> pour ces opérateurs pour qu'ils obtiennent leur propre méthode visit.

^code logical-ast (1 before, 1 after)

<aside name="logical-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-logical].

[appendix-logical]: appendix-ii.html#logical-expression

</aside>

Pour tisser les nouvelles expressions dans le parseur, nous changeons d'abord le code de parsing pour l'affectation pour appeler `or()`.

^code or-in-assignment (1 before, 2 after)

Le code pour parser une série d'expressions `or` reflète les autres opérateurs binaires.

^code or

Ses opérandes sont le niveau de précédence immédiatement supérieur, la nouvelle expression `and`.

^code and

Cela appelle `equality()` pour ses opérandes, et avec cela, le parseur d'expression est tout relié ensemble à nouveau. Nous sommes prêts à interpréter.

^code visit-logical

Si vous comparez cela à la méthode `visitBinaryExpr()` du [chapitre précédent][evaluating], vous pouvez voir la différence. Ici, nous évaluons l'opérande gauche d'abord. Nous regardons sa valeur pour voir si nous pouvons cour-circuiter. Si non, et seulement alors, nous évaluons l'opérande droit.

[evaluating]: evaluating-expressions.html

L'autre morceau intéressant ici est de décider quelle valeur réelle renvoyer. Puisque Lox est typé dynamiquement, nous autorisons des opérandes de n'importe quel type et utilisons la véracité (truthiness) pour déterminer ce que chaque opérande représente. Nous appliquons un raisonnement similaire au résultat. Au lieu de promettre de renvoyer littéralement `true` ou `false`, un opérateur logique garantit simplement qu'il renverra une valeur avec la véracité appropriée.

Heureusement, nous avons des valeurs avec la bonne véracité juste sous la main -- les résultats des opérandes eux-mêmes. Donc nous utilisons ceux-là. Par exemple :

```lox
print "salut" or 2; // "salut".
print nil or "oui"; // "oui".
```

Sur la première ligne, `"salut"` est truthy, donc le `or` court-circuite et renvoie ça. Sur la seconde ligne, `nil` est falsey, donc il évalue et renvoie le second opérande, `"oui"`.

Cela couvre toutes les primitives de branchement dans Lox. Nous sommes prêts à sauter en avant vers les boucles. Vous voyez ce que j'ai fait là ? _Sauter. En avant._ Vous avez compris ? Voyez, c'est comme une référence à... oh, oubliez ça.

## Boucles While

Lox propose deux instructions de contrôle de flux de boucle, `while` et `for`. La boucle `while` est la plus simple, donc nous commencerons là. Sa grammaire est la même qu'en C.

```ebnf
statement      → exprStmt
               | ifStmt
               | printStmt
               | whileStmt
               | block ;

whileStmt      → "while" "(" expression ")" statement ;
```

Nous ajoutons une autre clause à la règle statement qui pointe vers la nouvelle règle pour while. Elle prend un mot-clé `while`, suivi par une expression de condition parenthésée, puis une instruction pour le corps. Cette nouvelle règle de grammaire obtient un <span name="while-ast">nœud d'arbre syntaxique</span>.

^code while-ast (1 before, 1 after)

<aside name="while-ast">

Le code généré pour le nouveau nœud est dans l'[Annexe II][appendix-while].

[appendix-while]: appendix-ii.html#while-statement

</aside>

Le nœud stocke la condition et le corps. Ici vous pouvez voir pourquoi c'est agréable d'avoir des classes de base séparées pour les expressions et les instructions. Les déclarations de champ rendent clair que la condition est une expression et le corps est une instruction.

Là-bas dans le parseur, nous suivons le même processus que nous avons utilisé pour les instructions `if`. D'abord, nous ajoutons un autre cas dans `statement()` pour détecter et matcher le mot-clé de tête.

^code match-while (1 before, 1 after)

Cela délègue le vrai travail à cette méthode :

^code while-statement

La grammaire est simple à mourir et c'est une traduction directe de celle-ci vers Java. En parlant de traduire directement vers Java, voici comment nous exécutons la nouvelle syntaxe :

^code visit-while

Comme la méthode visit pour `if`, ce visiteur utilise la fonctionnalité Java correspondante. Cette méthode n'est pas complexe, mais elle rend Lox beaucoup plus puissant. Nous pouvons enfin écrire un programme dont le temps d'exécution n'est pas strictement lié par la longueur du code source.

## Boucles For

Nous sommes enfin à la dernière construction de contrôle de flux, <span name="for">Ye Olde</span> boucle `for` de style C. Je n'ai probablement pas besoin de vous rappeler, mais ça ressemble à ça :

```lox
for (var i = 0; i < 10; i = i + 1) print i;
```

En grammairien, c'est :

```ebnf
statement      → exprStmt
               | forStmt
               | ifStmt
               | printStmt
               | whileStmt
               | block ;

forStmt        → "for" "(" ( varDecl | exprStmt | ";" )
                 expression? ";"
                 expression? ")" statement ;
```

<aside name="for">

La plupart des langages modernes ont une instruction de boucle de plus haut niveau pour itérer sur des séquences arbitraires définies par l'utilisateur. C# a `foreach`, Java a le "enhanced for", même C++ a des instructions `for` basées sur l'intervalle maintenant. Celles-là offrent une syntaxe plus propre que l'instruction `for` du C en appelant implicitement un protocole d'itération que l'objet sur lequel on boucle supporte.

Je les adore. Pour Lox, cependant, nous sommes limités par la construction de l'interpréteur un chapitre à la fois. Nous n'avons pas encore d'objets et de méthodes, donc nous n'avons aucun moyen de définir un protocole d'itération que la boucle `for` pourrait utiliser. Donc nous allons rester avec la boucle `for` C vieille école. Pensez-y comme "vintage". Le fixie des instructions de contrôle de flux.

</aside>

À l'intérieur des parenthèses, vous avez trois clauses séparées par des points-virgules :

1.  La première clause est l'_initialiseur_. Elle est exécutée exactement une fois, avant tout le reste. C'est habituellement une expression, mais pour la commodité, nous autorisons aussi une déclaration de variable. Dans ce cas, la variable est portée au reste de la boucle `for` -- les deux autres clauses et le corps.

2.  Ensuite est la _condition_. Comme dans une boucle `while`, cette expression contrôle quand sortir de la boucle. Elle est évaluée une fois au début de chaque itération, incluant la première. Si le résultat est truthy, elle exécute le corps de la boucle. Sinon, elle se tire.

3.  La dernière clause est l'_incrément_. C'est une expression arbitraire qui fait un peu de travail à la fin de chaque itération de boucle. Le résultat de l'expression est rejeté, donc elle doit avoir un effet de bord pour être utile. En pratique, elle incrémente habituellement une variable.

N'importe laquelle de ces clauses peut être omise. Suivant la parenthèse fermante est une instruction pour le corps, qui est typiquement un bloc.

### Désucrage

C'est beaucoup de machinerie, mais notez qu'aucune partie ne fait quelque chose que vous ne pourriez pas faire avec les instructions que nous avons déjà. Si les boucles `for` ne supportaient pas de clauses d'initialiseur, vous pourriez juste mettre l'expression d'initialiseur avant l'instruction `for`. Sans une clause d'incrément, vous pourriez simplement mettre l'expression d'incrément à la fin du corps vous-même.

En d'autres termes, Lox n'a pas _besoin_ de boucles `for`, elles rendent juste certains motifs de code courants plus plaisants à écrire. Ces types de fonctionnalités sont appelés du <span name="sugar">**sucre syntaxique**</span>. Par exemple, la boucle `for` précédente pourrait être réécrite comme ceci :

<aside name="sugar">

Cette délicieuse tournure de phrase a été inventée par Peter J. Landin en 1964 pour décrire comment certaines des jolies formes d'expression supportées par des langages comme ALGOL étaient un édulcorant saupoudré sur le lambda-calcul plus fondamental -- mais présumément moins agréable au goût -- en dessous.

<img class="above" src="image/control-flow/sugar.png" alt="Légèrement plus qu'une cuillère de sucre." />

</aside>

```lox
{
  var i = 0;
  while (i < 10) {
    print i;
    i = i + 1;
  }
}
```

Ce script a exactement la même sémantique que le précédent, bien qu'il ne soit pas aussi facile pour les yeux. Les fonctionnalités de sucre syntaxique comme la boucle `for` de Lox rendent un langage plus plaisant et productif pour y travailler. Mais, spécialement dans les implémentations de langage sophistiquées, chaque fonctionnalité de langage qui nécessite du support en back-end et de l'optimisation est coûteuse.

Nous pouvons avoir le beurre et l'argent du beurre en <span name="caramel">**désucrant**</span>. Ce mot drôle décrit un processus où le front end prend du code utilisant du sucre syntaxique et le traduit vers une forme plus primitive que le back end sait déjà comment exécuter.

<aside name="caramel">

Oh, combien je souhaite que le terme accepté pour cela fût "caramélisation". Pourquoi introduire une métaphore si vous n'allez pas rester avec ?

</aside>

Nous allons désucrer les boucles `for` vers les boucles `while` et d'autres instructions que l'interpréteur gère déjà. Dans notre interpréteur simple, le désucrage ne nous économise vraiment pas beaucoup de travail, mais il me donne une excuse pour vous introduire à la technique. Donc, contrairement aux instructions précédentes, nous n'ajouterons _pas_ un nouveau nœud d'arbre syntaxique. Au lieu de cela, nous allons directement au parsing. D'abord, ajoutez un import dont nous aurons besoin bientôt.

^code import-arrays (1 before, 1 after)

Comme chaque instruction, nous commençons à parser une boucle `for` en matchant son mot-clé.

^code match-for (1 before, 1 after)

C'est ici que ça devient intéressant. Le désucrage va se passer ici, donc nous construirons cette méthode un morceau à la fois, en commençant avec la parenthèse ouvrante avant les clauses.

^code for-statement

La première clause suivant cela est l'initialiseur.

^code for-initializer (2 before, 1 after)

Si le token suivant la `(` est un point-virgule alors l'initialiseur a été omis. Sinon, nous vérifions un mot-clé `var` pour voir si c'est une déclaration de <span name="variable">variable</span>. Si aucun de ceux-ci n'a matché, ce doit être une expression. Nous parsons cela et l'enveloppons dans une instruction d'expression pour que l'initialiseur soit toujours de type Stmt.

<aside name="variable">

Dans un chapitre précédent, j'ai dit que nous pouvons diviser les arbres syntaxiques d'expression et d'instruction en deux hiérarchies de classe séparées parce qu'il n'y a pas un seul endroit dans la grammaire qui autorise à la fois une expression et une instruction. Ce n'était pas _entièrement_ vrai, je suppose.

</aside>

La suivante est la condition.

^code for-condition (2 before, 1 after)

Encore une fois, nous cherchons un point-virgule pour voir si la clause a été omise. La dernière clause est l'incrément.

^code for-increment (1 before, 1 after)

C'est similaire à la clause de condition sauf que celle-ci est terminée par la parenthèse fermante. Tout ce qui reste est le <span name="body">corps</span>.

<aside name="body">

Est-ce juste moi ou est-ce que ça sonne morbide ? "Tout ce qui restait... était le _corps_".

</aside>

^code for-body (1 before, 1 after)

Nous avons parsé toutes les pièces variées de la boucle `for` et les nœuds AST résultants sont assis dans une poignée de variables locales Java. C'est là que le désucrage arrive. Nous prenons ceux-là et les utilisons pour synthétiser des nœuds d'arbre syntaxique qui expriment la sémantique de la boucle `for`, comme l'exemple désucré à la main que je vous ai montré plus tôt.

Le code est un peu plus simple si nous travaillons à l'envers, donc nous commençons avec la clause d'incrément.

^code for-desugar-increment (2 before, 1 after)

L'incrément, s'il y en a un, s'exécute après le corps à chaque itération de la boucle. Nous faisons cela en remplaçant le corps par un petit bloc qui contient le corps original suivi par une instruction d'expression qui évalue l'incrément.

^code for-desugar-condition (2 before, 1 after)

Ensuite, nous prenons la condition et le corps et construisons la boucle en utilisant une boucle primitive `while`. Si la condition est omise, nous bourrons `true` dedans pour faire une boucle infinie.

^code for-desugar-initializer (2 before, 1 after)

Finalement, s'il y a un initialiseur, il tourne une fois avant la boucle entière. Nous faisons cela en, encore une fois, remplaçant l'instruction entière par un bloc qui exécute l'initialiseur et ensuite exécute la boucle.

C'est tout. Notre interpréteur supporte maintenant les boucles `for` de style C et nous n'avons pas eu à toucher la classe Interpreter du tout. Puisque nous avons désucré vers des nœuds que l'interpréteur sait déjà comment visiter, il n'y a plus de travail à faire.

Finalement, Lox est assez puissant pour nous divertir, au moins pour quelques minutes. Voici un programme minuscule pour imprimer les 21 premiers éléments dans la suite de Fibonacci :

```lox
var a = 0;
var temp;

for (var b = 1; a < 10000; b = temp + b) {
  print a;
  temp = a;
  a = b;
}
```

<div class="challenges">

## Défis

1.  Quelques chapitres plus loin, quand Lox supportera les fonctions de première classe et le dispatch dynamique, nous n'aurons techniquement pas _besoin_ d'instructions de branchement intégrées dans le langage. Montrez comment l'exécution conditionnelle peut être implémentée en termes de celles-ci. Nommez un langage qui utilise cette technique pour son contrôle de flux.

2.  De même, le bouclage peut être implémenté en utilisant ces mêmes outils, pourvu que notre interpréteur supporte une optimisation importante. Quelle est-elle, et pourquoi est-elle nécessaire ? Nommez un langage qui utilise cette technique pour l'itération.

3.  Contrairement à Lox, la plupart des autres langages de style C supportent aussi les instructions `break` et `continue` à l'intérieur des boucles. Ajoutez le support pour les instructions `break`.

    La syntaxe est un mot-clé `break` suivi par un point-virgule. Ce devrait être une erreur de syntaxe d'avoir une instruction `break` apparaissant en dehors de toute boucle englobante. À l'exécution, une instruction `break` fait sauter l'exécution à la fin de la boucle englobante la plus proche et procède à partir de là. Notez que le `break` peut être imbriqué à l'intérieur d'autres blocs et instructions `if` qui ont aussi besoin d'être sortis.

</div>

<div class="design-note">

## Note de Conception : Cuillerées de Sucre Syntaxique

Quand vous concevez votre propre langage, vous choisissez combien de sucre syntaxique verser dans la grammaire. Faites-vous une nourriture saine non sucrée où chaque opération sémantique mappe vers une seule unité syntaxique, ou quelque dessert décadent où chaque bit de comportement peut être exprimé de dix façons différentes ? Les langages à succès habitent tous les points le long de ce continuum.

À l'extrémité acre extrême sont ceux avec une syntaxe impitoyablement minimale comme Lisp, Forth, et Smalltalk. Les Lisperiens prétendent fameusement que leur langage "n'a pas de syntaxe", alors que les Smalltalkers montrent fièrement que vous pouvez faire tenir la grammaire entière sur une fiche cartonnée. Cette tribu a la philosophie que le _langage_ n'a pas besoin de sucre syntaxique. Au lieu de cela, la syntaxe minimale et la sémantique qu'il fournit sont assez puissantes pour laisser le code de bibliothèque être aussi expressif que s'il faisait partie du langage lui-même.

Près de ceux-ci sont des langages comme C, Lua, et Go. Ils visent la simplicité et la clarté par-dessus le minimalisme. Certains, comme Go, évitent délibérément à la fois le sucre syntaxique et le genre d'extensibilité syntaxique de la catégorie précédente. Ils veulent que la syntaxe s'écarte du chemin de la sémantique, donc ils se concentrent sur garder à la fois la grammaire et les bibliothèques simples. Le code devrait être évident plus que beau.

Quelque part au milieu vous avez des langages comme Java, C#, et Python. Finalement vous atteignez Ruby, C++, Perl, et D -- des langages qui ont bourré tellement de syntaxe dans leur grammaire, qu'ils manquent de caractères de ponctuation sur le clavier.

À un certain degré, l'emplacement sur le spectre corrèle avec l'âge. C'est relativement facile d'ajouter des morceaux de sucre syntaxique dans des versions ultérieures. La nouvelle syntaxe plaît à la foule, et c'est moins susceptible de casser les programmes existants que de tripatouiller la sémantique. Une fois ajouté, vous ne pouvez jamais l'enlever, donc les langages tendent à s'adoucir avec le temps. L'un des bénéfices principaux de créer un nouveau langage depuis zéro est que cela vous donne une opportunité de racler ces couches accumulées de glaçage et de recommencer.

Le sucre syntaxique a mauvaise réputation parmi l'intelligentsia des langages de programmation. Il y a un vrai fétichisme pour le minimalisme dans cette foule. Il y a une certaine justification à cela. Une syntaxe mal conçue, inutile, élève la charge cognitive sans ajouter assez d'expressivité pour porter son poids. Puisqu'il y a toujours une pression pour entasser de nouvelles fonctionnalités dans le langage, cela prend de la discipline et une focalisation sur la simplicité pour éviter le ballonnement. Une fois que vous ajoutez une certaine syntaxe, vous êtes coincé avec, donc c'est intelligent d'être parcimonieux.

En même temps, la plupart des langages à succès ont des grammaires passablement complexes, au moins au moment où ils sont largement utilisés. Les programmeurs passent une tonne de temps dans leur langage de choix, et quelques gentillesses ici et là peuvent vraiment améliorer le confort et l'efficacité de leur travail.

Frapper le bon équilibre -- choisir le bon niveau de douceur pour votre langage -- repose sur votre propre sens du goût.

</div>

> La grammaire, qui sait régenter jusqu'aux rois.
> <cite>Molière</cite>

<span name="parse">Ce</span> chapitre marque la première étape majeure du livre. Beaucoup d'entre nous ont bricolé un mélange d'expressions régulières et d'opérations sur les sous-chaînes pour extraire un peu de sens d'un tas de texte. Le code était probablement criblé de bugs et une bête à maintenir. Écrire un _vrai_ parseur -- un avec une gestion d'erreurs décente, une structure interne cohérente, et la capacité de mâcher robustement une syntaxe sophistiquée -- est considéré comme une compétence rare et impressionnante. Dans ce chapitre, vous l'<span name="attain">atteindrez</span>.

<aside name="parse">

"Parse" (parser/analyser) vient en anglais du vieux français "pars" pour "partie du discours". Cela signifie prendre un texte et mapper chaque mot à la grammaire du langage. Nous l'utilisons ici dans le même sens, sauf que notre langage est un peu plus moderne que le vieux français.

</aside>

<aside name="attain">

Comme beaucoup de rites de passage, vous trouverez probablement que cela semble un peu plus petit, un peu moins intimidant quand c'est derrière vous que quand cela se dressait devant.

</aside>

C'est plus facile que vous ne le pensez, en partie parce que nous avons fait une grande partie du travail difficile en amont dans le [dernier chapitre][last chapter]. Vous connaissez déjà le chemin autour d'une grammaire formelle. Vous êtes familier avec les arbres syntaxiques, et nous avons quelques classes Java pour les représenter. La seule pièce restante est le parsing -- la transmogrification d'une séquence de tokens en l'un de ces arbres syntaxiques.

[last chapter]: representing-code.html

Certains manuels d'informatique font tout un plat des parseurs. Dans les années 60, les informaticiens -- compréhensiblement fatigués de programmer en langage assembleur -- ont commencé à concevoir des langages plus sophistiqués, conviviaux pour les <span name="human">humains</span> comme Fortran et ALGOL. Hélas, ils n'étaient pas très conviviaux pour la _machine_ pour les ordinateurs primitifs de l'époque.

<aside name="human">

Imaginez à quel point la programmation en assembleur sur ces vieilles machines devait être pénible pour qu'ils considèrent _Fortran_ comme une amélioration.

</aside>

Ces pionniers ont conçu des langages pour lesquels ils n'étaient honnêtement même pas sûrs de savoir comment écrire des compilateurs, et ont ensuite fait un travail révolutionnaire en inventant des techniques de parsing et de compilation qui pouvaient gérer ces nouveaux gros langages sur ces vieilles minuscules machines.

Les livres de compilation classiques se lisent comme des hagiographies flagorneuses de ces héros et de leurs outils. La couverture de _Compilers: Principles, Techniques, and Tools_ a littéralement un dragon étiqueté "complexité de la conception de compilateur" étant occis par un chevalier portant une épée et un bouclier marqués "générateur de parseur LALR" et "traduction dirigée par la syntaxe". Ils en ont rajouté une couche.

Un peu d'auto-félicitation est bien mérité, mais la vérité est que vous n'avez pas besoin de savoir la plupart de ces trucs pour sortir un parseur de haute qualité pour une machine moderne. Comme toujours, je vous encourage à élargir votre éducation et à l'assimiler plus tard, mais ce livre omet la vitrine de trophées.

## L'Ambiguïté et le Jeu du Parsing

Dans le dernier chapitre, j'ai dit que vous pouvez "jouer" une grammaire non contextuelle comme un jeu afin de _générer_ des chaînes. Les parseurs jouent à ce jeu à l'envers. Étant donné une chaîne -- une série de tokens -- nous mappons ces tokens aux terminaux dans la grammaire pour comprendre quelles règles auraient pu générer cette chaîne.

La partie "auraient pu" est intéressante. Il est tout à fait possible de créer une grammaire qui est _ambiguë_, où différents choix de productions peuvent mener à la même chaîne. Quand vous utilisez la grammaire pour _générer_ des chaînes, cela n'importe pas beaucoup. Une fois que vous avez la chaîne, qui se soucie de comment vous y êtes arrivé ?

Lors du parsing, l'ambiguïté signifie que le parseur peut mal comprendre le code de l'utilisateur. En parsant, nous ne déterminons pas seulement si la chaîne est du code Lox valide, nous suivons aussi quelles règles matchent quelles parties de celui-ci afin de savoir à quelle partie du langage chaque token appartient. Voici la grammaire d'expression Lox que nous avons assemblée dans le dernier chapitre :

```ebnf
expression     → literal
               | unary
               | binary
               | grouping ;

literal        → NUMBER | STRING | "true" | "false" | "nil" ;
grouping       → "(" expression ")" ;
unary          → ( "-" | "!" ) expression ;
binary         → expression operator expression ;
operator       → "==" | "!=" | "<" | "<=" | ">" | ">="
               | "+"  | "-"  | "*" | "/" ;
```

Ceci est une chaîne valide dans cette grammaire :

<img src="image/parsing-expressions/tokens.png" alt="6 / 3 - 1" />

Mais il y a deux façons dont nous aurions pu la générer. Une façon est :

1. En commençant à `expression`, choisissez `binary`.
2. Pour l'`expression` de gauche, choisissez `NUMBER`, et utilisez `6`.
3. Pour l'opérateur, choisissez `"/"`.
4. Pour l'`expression` de droite, choisissez `binary` à nouveau.
5. Dans cette expression `binary` imbriquée, choisissez `3 - 1`.

Une autre est :

1. En commençant à `expression`, choisissez `binary`.
2. Pour l'`expression` de gauche, choisissez `binary` à nouveau.
3. Dans cette expression `binary` imbriquée, choisissez `6 / 3`.
4. De retour au `binary` extérieur, pour l'opérateur, choisissez `"-"`.
5. Pour l'`expression` de droite, choisissez `NUMBER`, et utilisez `1`.

Celles-ci produisent les mêmes _chaînes_, mais pas les mêmes _arbres syntaxiques_ :

<img src="image/parsing-expressions/syntax-trees.png" alt="Deux arbres syntaxiques valides : (6 / 3) - 1 et 6 / (3 - 1)" />

En d'autres termes, la grammaire permet de voir l'expression comme `(6 / 3) - 1` ou `6 / (3 - 1)`. La règle `binary` laisse les opérandes s'imbriquer n'importe comment. Cela affecte à son tour le résultat de l'évaluation de l'arbre parsé. La façon dont les mathématiciens ont adressé cette ambiguïté depuis que les tableaux noirs ont été inventés est en définissant des règles pour la précédence et l'associativité.

- La <span name="nonassociative">**précédence**</span> détermine quel opérateur est évalué en premier dans une expression contenant un mélange de différents opérateurs. Les règles de précédence nous disent que nous évaluons le `/` avant le `-` dans l'exemple ci-dessus. Les opérateurs avec une plus haute précédence sont évalués avant les opérateurs avec une plus basse précédence. De manière équivalente, les opérateurs à plus haute précédence sont dits "liant plus fort".

- L'**associativité** détermine quel opérateur est évalué en premier dans une série du _même_ opérateur. Quand un opérateur est **associatif à gauche** (pensez "de gauche à droite"), les opérateurs sur la gauche s'évaluent avant ceux sur la droite. Puisque `-` est associatif à gauche, cette expression :

    ```lox
    5 - 3 - 1
    ```

    est équivalente à :

    ```lox
    (5 - 3) - 1
    ```

    L'affectation, d'autre part, est **associative à droite**. Ceci :

    ```lox
    a = b = c
    ```

    est équivalent à :

    ```lox
    a = (b = c)
    ```

<aside name="nonassociative">

Bien que peu courants de nos jours, certains langages spécifient que certaines paires d'opérateurs n'ont _aucune_ précédence relative. Cela rend une erreur de syntaxe le fait de mélanger ces opérateurs dans une expression sans utiliser de groupement explicite.

De même, certains opérateurs sont **non-associatifs**. Cela signifie que c'est une erreur d'utiliser cet opérateur plus d'une fois dans une séquence. Par exemple, l'opérateur de plage de Perl n'est pas associatif, donc `a .. b` est OK, mais `a .. b .. c` est une erreur.

</aside>

Sans précédence et associativité bien définies, une expression qui utilise plusieurs opérateurs est ambiguë -- elle peut être parsée en différents arbres syntaxiques, qui pourraient à leur tour s'évaluer en différents résultats. Nous corrigerons cela dans Lox en appliquant les mêmes règles de précédence que le C, en allant du plus bas au plus haut.

<table>
<thead>
<tr>
  <td>Nom</td>
  <td>Opérateurs</td>
  <td>Associe</td>
</tr>
</thead>
<tbody>
<tr>
  <td>Égalité</td>
  <td><code>==</code> <code>!=</code></td>
  <td>Gauche</td>
</tr>
<tr>
  <td>Comparaison</td>
  <td><code>&gt;</code> <code>&gt;=</code>
      <code>&lt;</code> <code>&lt;=</code></td>
  <td>Gauche</td>
</tr>
<tr>
  <td>Terme</td>
  <td><code>-</code> <code>+</code></td>
  <td>Gauche</td>
</tr>
<tr>
  <td>Facteur</td>
  <td><code>/</code> <code>*</code></td>
  <td>Gauche</td>
</tr>
<tr>
  <td>Unaire</td>
  <td><code>!</code> <code>-</code></td>
  <td>Droite</td>
</tr>
</tbody>
</table>

Pour l'instant, la grammaire fourre tous les types d'expression dans une seule règle `expression`. Cette même règle est utilisée comme non-terminal pour les opérandes, ce qui laisse la grammaire accepter n'importe quel type d'expression comme sous-expression, peu importe si les règles de précédence l'autorisent.

Nous corrigeons cela en <span name="massage">stratifiant</span> la grammaire. Nous définissons une règle séparée pour chaque niveau de précédence.

```ebnf
expression     → ...
equality       → ...
comparison     → ...
term           → ...
factor         → ...
unary          → ...
primary        → ...
```

<aside name="massage">

Au lieu de cuire la précédence directement dans les règles de grammaire, certains générateurs de parseurs vous laissent garder la même grammaire ambiguë-mais-simple et ajouter ensuite un peu de métadonnées de précédence d'opérateur explicite sur le côté afin de désambiguïser.

</aside>

Chaque règle ici matche seulement les expressions à son niveau de précédence ou plus haut. Par exemple, `unary` matche une expression unaire comme `!negated` ou une expression primaire comme `1234`. Et `term` peut matcher `1 + 2` mais aussi `3 * 4 / 5`. La règle `primary` finale couvre les formes de plus haute précédence -- les littéraux et les expressions parenthésées.

Nous avons juste besoin de remplir les productions pour chacune de ces règles. Nous ferons les faciles en premier. La règle `expression` du haut matche n'importe quelle expression à n'importe quel niveau de précédence. Puisque <span name="equality">`equality`</span> a la précédence la plus basse, si nous matchons cela, alors cela couvre tout.

<aside name="equality">

Nous pourrions éliminer `expression` et utiliser simplement `equality` dans les autres règles qui contiennent des expressions, mais utiliser `expression` rend ces autres règles un peu plus lisibles.

Aussi, dans les chapitres ultérieurs quand nous étendrons la grammaire pour inclure l'affectation et les opérateurs logiques, nous aurons seulement besoin de changer la production pour `expression` au lieu de toucher chaque règle qui contient une expression.

</aside>

```ebnf
expression     → equality
```

Tout à l'autre bout de la table de précédence, une expression primaire contient tous les littéraux et expressions de groupement.

```ebnf
primary        → NUMBER | STRING | "true" | "false" | "nil"
               | "(" expression ")" ;
```

Une expression unaire commence par un opérateur unaire suivi par l'opérande. Puisque les opérateurs unaires peuvent s'imbriquer -- `!!true` est une expression valide bien que bizarre -- l'opérande peut lui-même être un opérateur unaire. Une règle récursive gère cela joliment.

```ebnf
unary          → ( "!" | "-" ) unary ;
```

Mais cette règle a un problème. Elle ne termine jamais.

Rappelez-vous, chaque règle doit matcher les expressions à ce niveau de précédence _ou plus haut_, donc nous devons aussi laisser ceci matcher une expression primaire.

```ebnf
unary          → ( "!" | "-" ) unary
               | primary ;
```

Ça marche.

Les règles restantes sont toutes des opérateurs binaires. Nous commencerons avec la règle pour la multiplication et la division. Voici un premier essai :

```ebnf
factor         → factor ( "/" | "*" ) unary
               | unary ;
```

La règle récurse pour matcher l'opérande gauche. Cela permet à la règle de matcher une série d'expressions de multiplication et de division comme `1 * 2 / 3`. Mettre la production récursive sur le côté gauche et `unary` sur la droite rend la règle <span name="mult">associative à gauche</span> et non ambiguë.

<aside name="mult">

En principe, peu importe que vous traitiez la multiplication comme associative à gauche ou à droite -- vous obtenez le même résultat de toute façon. Hélas, dans le monde réel avec une précision limitée, l'arrondi et le dépassement signifient que l'associativité peut affecter le résultat d'une séquence de multiplications. Considérez :

```lox
print 0.1 * (0.2 * 0.3);
print (0.1 * 0.2) * 0.3;
```

Dans les langages comme Lox qui utilisent des nombres à virgule flottante double précision [IEEE 754][754], le premier s'évalue à `0.006`, tandis que le second donne `0.006000000000000001`. Parfois cette minuscule différence compte. [Ceci][float] est un bon endroit pour en apprendre plus.

[754]: https://en.wikipedia.org/wiki/Double-precision_floating-point_format
[float]: https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html

</aside>

Tout ceci est correct, mais le fait que le premier symbole dans le corps de la règle est le même que la tête de la règle signifie que cette production est **récursive à gauche**. Certaines techniques de parsing, y compris celle que nous allons utiliser, ont du mal avec la récursion gauche. (La récursion ailleurs, comme nous l'avons dans `unary` et la récursion indirecte pour le groupement dans `primary` n'est pas un problème.)

Il y a beaucoup de grammaires que vous pouvez définir qui matchent le même langage. Le choix de comment modéliser un langage particulier est partiellement une question de goût et partiellement une question pragmatique. Cette règle est correcte, mais pas optimale pour la façon dont nous avons l'intention de la parser. Au lieu d'une règle récursive à gauche, nous en utiliserons une différente.

```ebnf
factor         → unary ( ( "/" | "*" ) unary )* ;
```

Nous définissons une expression facteur comme une _séquence_ plate de multiplications et de divisions. Cela matche la même syntaxe que la règle précédente, mais reflète mieux le code que nous écrirons pour parser Lox. Nous utilisons la même structure pour tous les autres niveaux de précédence d'opérateur binaire, nous donnant cette grammaire d'expression complète :

```ebnf
expression     → equality ;
equality       → comparison ( ( "!=" | "==" ) comparison )* ;
comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
term           → factor ( ( "-" | "+" ) factor )* ;
factor         → unary ( ( "/" | "*" ) unary )* ;
unary          → ( "!" | "-" ) unary
               | primary ;
primary        → NUMBER | STRING | "true" | "false" | "nil"
               | "(" expression ")" ;
```

Cette grammaire est plus complexe que celle que nous avions avant, mais en retour nous avons éliminé l'ambiguïté de la précédente. C'est juste ce dont nous avons besoin pour faire un parseur.

## Analyse Récursive Descendante

Il y a tout un paquet de techniques de parsing dont les noms sont principalement des combinaisons de "L" et de "R" -- [LL(k)][], [LR(1)][lr], [LALR][] -- avec des bêtes plus exotiques comme les [combinateurs de parseur][parser combinators], les [parseurs Earley][earley parsers], l'[algorithme shunting-yard][yard], et le [parsing packrat][packrat parsing]. Pour notre premier interpréteur, une technique est plus que suffisante : **l'analyse récursive descendante** (recursive descent).

[ll(k)]: https://en.wikipedia.org/wiki/LL_parser
[lr]: https://en.wikipedia.org/wiki/LR_parser
[lalr]: https://en.wikipedia.org/wiki/LALR_parser
[parser combinators]: https://en.wikipedia.org/wiki/Parser_combinator
[earley parsers]: https://en.wikipedia.org/wiki/Earley_parser
[yard]: https://en.wikipedia.org/wiki/Shunting-yard_algorithm
[packrat parsing]: https://en.wikipedia.org/wiki/Parsing_expression_grammar

L'analyse récursive descendante est la façon la plus simple de construire un parseur, et ne nécessite pas l'utilisation d'outils générateurs de parseur complexes comme Yacc, Bison ou ANTLR. Tout ce dont vous avez besoin est du code écrit à la main simple. Ne soyez pas dupé par sa simplicité, cependant. Les parseurs récursifs descendants sont rapides, robustes, et peuvent supporter une gestion d'erreurs sophistiquée. En fait, GCC, V8 (la VM JavaScript dans Chrome), Roslyn (le compilateur C# écrit en C#) et beaucoup d'autres implémentations de langage de production poids lourds utilisent la descente récursive. Ça déchire.

L'analyse récursive descendante est considérée comme un **parseur top-down** (descendant) parce qu'elle commence par la règle de grammaire la plus haute ou la plus externe (ici `expression`) et fait son chemin en <span name="descent">descendant</span> dans les sous-expressions imbriquées avant d'atteindre finalement les feuilles de l'arbre syntaxique. C'est en contraste avec les parseurs bottom-up (ascendants) comme LR qui commencent avec les expressions primaires et les composent en morceaux de syntaxe de plus en plus grands.

<aside name="descent">

C'est appelé "_descente_ récursive" parce que ça marche _vers le bas_ de la grammaire. De manière confuse, nous utilisons aussi la direction métaphoriquement quand nous parlons de "haute" et "basse" précédence, mais l'orientation est inversée. Dans un parseur top-down, vous atteignez les expressions de plus basse précédence en premier parce qu'elles peuvent à leur tour contenir des sous-expressions de plus haute précédence.

<img src="image/parsing-expressions/direction.png" alt="Règles de grammaire top-down par ordre de précédence croissante." />

Les gens de l'informatique ont vraiment besoin de se réunir et de mettre leurs métaphores au clair. Ne me lancez même pas sur dans quelle direction une pile grandit ou pourquoi les arbres ont leurs racines en haut.

</aside>

Un parseur récursif descendant est une traduction littérale des règles de la grammaire directement en code impératif. Chaque règle devient une fonction. Le corps de la règle se traduit en code à peu près comme :

<table>
<thead>
<tr>
  <td>Notation de grammaire</td>
  <td>Représentation en code</td>
</tr>
</thead>
<tbody>
<tr><td>Terminal</td><td>Code pour matcher et consommer un token</td></tr>
<tr><td>Non-terminal</td><td>Appel à la fonction de cette règle</td></tr>
<tr><td><code>|</code></td><td>Instruction <code>if</code> ou <code>switch</code></td></tr>
<tr><td><code>*</code> ou <code>+</code></td><td>Boucle <code>while</code> ou <code>for</code></td></tr>
<tr><td><code>?</code></td><td>Instruction <code>if</code></td></tr>
</tbody>
</table>

La descente est décrite comme "récursive" parce que quand une règle de grammaire se réfère à elle-même -- directement ou indirectement -- cela se traduit par un appel de fonction récursif.

### La classe parseur

Chaque règle de grammaire devient une méthode à l'intérieur de cette nouvelle classe :

^code parser

Comme le scanner, le parseur consomme une séquence d'entrée plate, seulement maintenant nous lisons des tokens au lieu de caractères. Nous stockons la liste des tokens et utilisons `current` pour pointer vers le prochain token attendant avidement d'être parsé.

Nous allons parcourir tout droit la grammaire d'expression maintenant et traduire chaque règle en code Java. La première règle, `expression`, s'étend simplement en la règle `equality`, donc c'est direct.

^code expression

Chaque méthode pour parser une règle de grammaire produit un arbre syntaxique pour cette règle et le renvoie à l'appelant. Quand le corps de la règle contient un non-terminal -- une référence à une autre règle -- nous <span name="left">appelons</span> la méthode de cette autre règle.

<aside name="left">

C'est pourquoi la récursion gauche est problématique pour la descente récursive. La fonction pour une règle récursive à gauche s'appelle immédiatement elle-même, qui s'appelle elle-même à nouveau, et ainsi de suite, jusqu'à ce que le parseur frappe un débordement de pile (stack overflow) et meure.

</aside>

La règle pour l'égalité est un peu plus complexe.

```ebnf
equality       → comparison ( ( "!=" | "==" ) comparison )* ;
```

En Java, cela devient :

^code equality

Parcourons-le. Le premier non-terminal `comparison` dans le corps se traduit par le premier appel à `comparison()` dans la méthode. Nous prenons ce résultat et le stockons dans une variable locale.

Ensuite, la boucle `( ... )*` dans la règle mappe vers une boucle `while`. Nous avons besoin de savoir quand sortir de cette boucle. Nous pouvons voir qu'à l'intérieur de la règle, nous devons d'abord trouver un token soit `!=` soit `==`. Donc, si nous _ne voyons pas_ l'un de ceux-là, nous devons avoir fini avec la séquence d'opérateurs d'égalité. Nous exprimons cette vérification en utilisant une méthode pratique `match()`.

^code match

Ceci vérifie pour voir si le token courant a l'un des types donnés. Si oui, il consomme le token et renvoie `true`. Sinon, il renvoie `false` et laisse le token courant tranquille. La méthode `match()` est définie en termes de deux opérations plus fondamentales.

La méthode `check()` renvoie `true` si le token courant est du type donné. Contrairement à `match()`, elle ne consomme jamais le token, elle le regarde seulement.

^code check

La méthode `advance()` consomme le token courant et le renvoie, similaire à la façon dont la méthode correspondante de notre scanner parcourait les caractères.

^code advance

Ces méthodes reposent sur la dernière poignée d'opérations primitives.

^code utils

`isAtEnd()` vérifie si nous sommes à court de tokens à parser. `peek()` renvoie le token courant que nous avons encore à consommer, et `previous()` renvoie le token le plus récemment consommé. Ce dernier rend plus facile l'utilisation de `match()` et ensuite l'accès au token juste matché.

C'est la majeure partie de l'infrastructure de parsing dont nous avons besoin. Où en étions-nous ? Ah oui, donc si nous sommes à l'intérieur de la boucle `while` dans `equality()`, alors nous savons que nous avons trouvé un opérateur `!=` ou `==` et devons être en train de parser une expression d'égalité.

Nous saisissons le token opérateur matché pour pouvoir suivre quel genre d'expression d'égalité nous avons. Puis nous appelons `comparison()` à nouveau pour parser l'opérande de droite. Nous combinons l'opérateur et ses deux opérandes dans un nouveau nœud d'arbre syntaxique `Expr.Binary`, et puis nous bouclons. Pour chaque itération, nous stockons l'expression résultante de nouveau dans la même variable locale `expr`. Alors que nous zippons à travers une séquence d'expressions d'égalité, cela crée un arbre imbriqué associatif à gauche de nœuds opérateurs binaires.

<span name="sequence"></span>

<img src="image/parsing-expressions/sequence.png" alt="L'arbre syntaxique créé en parsant 'a == b == c == d == e'" />

<aside name="sequence">

Parsage de `a == b == c == d == e`. Pour chaque itération, nous créons une nouvelle expression binaire utilisant la précédente comme opérande gauche.

</aside>

Le parseur tombe hors de la boucle une fois qu'il frappe un token qui n'est pas un opérateur d'égalité. Finalement, il renvoie l'expression. Notez que si le parseur ne rencontre jamais un opérateur d'égalité, alors il n'entre jamais dans la boucle. Dans ce cas, la méthode `equality()` appelle et renvoie effectivement `comparison()`. De cette façon, cette méthode matche un opérateur d'égalité _ou quoi que ce soit de plus haute précédence_.

Passons à la règle suivante...

```ebnf
comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
```

Traduit en Java :

^code comparison

La règle de grammaire est virtuellement <span name="handle">identique</span> à `equality` et le code correspondant l'est aussi. Les seules différences sont les types de token pour les opérateurs que nous matchons, et la méthode que nous appelons pour les opérandes -- maintenant `term()` au lieu de `comparison()`. Les deux règles d'opérateur binaire restantes suivent le même patron.

Par ordre de précédence, d'abord l'addition et la soustraction :

<aside name="handle">

Si vous vouliez faire du Java 8 intelligent, vous pourriez créer une méthode d'aide pour parser une série associative à gauche d'opérateurs binaires étant donné une liste de types de token, et un handle de méthode d'opérande pour simplifier ce code redondant.

</aside>

^code term

Et enfin, multiplication et division :

^code factor

C'est tous les opérateurs binaires, parsés avec la précédence et l'associativité correctes. Nous grimpons la hiérarchie de précédence et maintenant nous avons atteint les opérateurs unaires.

```ebnf
unary          → ( "!" | "-" ) unary
               | primary ;
```

Le code pour ceci est un peu différent.

^code unary

Encore une fois, nous regardons le token <span name="current">courant</span> pour voir comment parser. Si c'est un `!` ou `-`, nous devons avoir une expression unaire. Dans ce cas, nous saisissons le token et ensuite appelons récursivement `unary()` à nouveau pour parser l'opérande. Enveloppez tout cela dans un arbre syntaxique d'expression unaire et nous avons fini.

<aside name="current">

Le fait que le parseur regarde en avant les tokens à venir pour décider comment parser met la descente récursive dans la catégorie des **parseurs prédictifs**.

</aside>

Sinon, nous devons avoir atteint le plus haut niveau de précédence, les expressions primaires.

```ebnf
primary        → NUMBER | STRING | "true" | "false" | "nil"
               | "(" expression ")" ;
```

La plupart des cas pour la règle sont des terminaux uniques, donc le parsing est direct.

^code primary

La branche intéressante est celle pour gérer les parenthèses. Après avoir matché un `(` ouvrant et parsé l'expression à l'intérieur, nous _devons_ trouver un token `)`. Si nous ne le trouvons pas, c'est une erreur.

## Erreurs de Syntaxe

Un parseur a vraiment deux boulots :

1.  Étant donné une séquence valide de tokens, produire un arbre syntaxique correspondant.

2.  Étant donné une séquence _invalide_ de tokens, détecter toute erreur et dire à l'utilisateur ses erreurs.

Ne sous-estimez pas à quel point le second boulot est important ! Dans les IDE et éditeurs modernes, le parseur re-parse constamment le code -- souvent pendant que l'utilisateur est encore en train de l'éditer -- afin de faire la coloration syntaxique et de supporter des choses comme l'auto-complétion. Cela signifie qu'il rencontrera du code dans des états incomplets et à moitié faux _tout le temps_.

Quand l'utilisateur ne réalise pas que la syntaxe est fausse, c'est au parseur de l'aider à le guider de retour sur le droit chemin. La façon dont il rapporte les erreurs est une grande partie de l'interface utilisateur de votre langage. Une bonne gestion d'erreur de syntaxe est difficile. Par définition, le code n'est pas dans un état bien défini, donc il n'y a pas de moyen infaillible de savoir ce que l'utilisateur _voulait_ écrire. Le parseur ne peut pas lire dans vos <span name="telepathy">pensées</span>.

<aside name="telepathy">

Pas encore du moins. Avec la tournure que prennent les choses en apprentissage automatique ces jours-ci, qui sait ce que l'avenir apportera ?

</aside>

Il y a quelques exigences dures pour quand le parseur tombe sur une erreur de syntaxe. Un parseur doit :

- **Détecter et rapporter l'erreur.** S'il ne détecte pas l'<span name="error">erreur</span> et passe l'arbre syntaxique malformé résultant à l'interpréteur, toute sorte d'horreurs peuvent être invoquées.

      <aside name="error">

    Philosophiquement parlant, si une erreur n'est pas détectée et que l'interpréteur exécute le code, est-ce _vraiment_ une erreur ?

      </aside>

- **Éviter de planter ou de geler.** Les erreurs de syntaxe sont une réalité de la vie, et les outils de langage doivent être robustes face à elles. Faire un Segfault ou rester coincé dans une boucle infinie n'est pas autorisé. Bien que la source ne soit peut-être pas du _code_ valide, c'est toujours une _entrée valide pour le parseur_ parce que les utilisateurs utilisent le parseur pour apprendre quelle syntaxe est autorisée.

Ce sont les mises de départ si vous voulez entrer dans le jeu du parseur tout court, mais vous voulez vraiment monter la mise au-delà de ça. Un parseur décent devrait :

- **Être rapide.** Les ordinateurs sont des milliers de fois plus rapides qu'ils ne l'étaient quand la technologie de parseur a été inventée. Les jours où il fallait optimiser votre parseur pour qu'il puisse traverser un fichier source entier pendant une pause café sont finis. Mais les attentes des programmeurs ont augmenté aussi vite, sinon plus vite. Ils attendent de leurs éditeurs qu'ils re-parsent les fichiers en millisecondes après chaque frappe.

- **Rapporter autant d'erreurs distinctes qu'il y en a.** Avorter après la première erreur est facile à implémenter, mais c'est ennuyeux pour les utilisateurs si chaque fois qu'ils corrigent ce qu'ils pensent être la seule erreur dans un fichier, une nouvelle apparaît. Ils veulent toutes les voir.

- **Minimiser les erreurs _en cascade_.** Une fois qu'une seule erreur est trouvée, le parseur ne sait plus vraiment ce qui se passe. Il essaie de se remettre sur les rails et de continuer, mais s'il est confus, il peut rapporter une flopée d'erreurs fantômes qui n'indiquent pas d'autres vrais problèmes dans le code. Quand la première erreur est corrigée, ces fantômes disparaissent, parce qu'ils reflètent seulement la propre confusion du parseur. Les erreurs en cascade sont ennuyeuses parce qu'elles peuvent effrayer l'utilisateur en lui faisant penser que son code est dans un pire état qu'il ne l'est.

Les deux derniers points sont en tension. Nous voulons rapporter autant d'erreurs séparées que nous pouvons, mais nous ne voulons pas rapporter celles qui sont simplement des effets secondaires d'une précédente.

La façon dont un parseur répond à une erreur et continue pour chercher des erreurs ultérieures s'appelle la **récupération d'erreur**. C'était un sujet de recherche chaud dans les années 60. À l'époque, vous donniez une pile de cartes perforées à la secrétaire et reveniez le jour suivant pour voir si le compilateur avait réussi. Avec une boucle d'itération aussi lente, vous vouliez _vraiment_ trouver chaque erreur dans votre code en une seule passe.

Aujourd'hui, quand les parseurs terminent avant même que vous ayez fini de taper, c'est moins un problème. Une récupération d'erreur simple et rapide est très bien.

### Récupération d'erreur en mode panique

<aside name="panic">

Vous savez que vous voulez appuyer dessus.

<img src="image/parsing-expressions/panic.png" alt="Un gros bouton brillant 'PANIC'." />

</aside>

De toutes les techniques de récupération imaginées autrefois, celle qui a le mieux résisté à l'épreuve du temps est appelée -- de manière quelque peu alarmante -- <span name="panic">**mode panique**</span>. Dès que le parseur détecte une erreur, il entre en mode panique. Il sait qu'au moins un token n'a pas de sens étant donné son état actuel au milieu d'une pile de productions de grammaire.

Avant de pouvoir retourner au parsing, il a besoin d'aligner son état et la séquence de tokens à venir de telle sorte que le prochain token matche la règle en cours de parsing. Ce processus est appelé **synchronisation**.

Pour faire cela, nous sélectionnons une règle dans la grammaire qui marquera le point de synchronisation. Le parseur corrige son état de parsing en sautant hors de toutes les productions imbriquées jusqu'à ce qu'il revienne à cette règle. Ensuite, il synchronise le flux de tokens en rejetant des tokens jusqu'à ce qu'il en atteigne un qui peut apparaître à ce point dans la règle.

Toutes les erreurs de syntaxe réelles supplémentaires se cachant dans ces tokens rejetés ne sont pas rapportées, mais cela signifie aussi que toutes les erreurs en cascade erronées qui sont des effets secondaires de l'erreur initiale ne sont pas non plus _faussement_ rapportées, ce qui est un compromis décent.

L'endroit traditionnel dans la grammaire pour synchroniser est entre les instructions. Nous n'en avons pas encore, donc nous ne synchroniserons pas réellement dans ce chapitre, mais nous mettrons la machinerie en place pour plus tard.

### Entrer en mode panique

Avant de partir pour cette petite excursion autour de la récupération d'erreur, nous écrivions le code pour parser une expression parenthésée. Après avoir parsé l'expression, le parseur cherche le `)` fermant en appelant `consume()`. Voici, enfin, cette méthode :

^code consume

C'est similaire à `match()` en ce qu'elle vérifie pour voir si le prochain token est du type attendu. Si oui, elle consomme le token et tout baigne. Si un autre token est là, alors nous avons frappé une erreur. Nous la rapportons en appelant ceci :

^code error

D'abord, cela montre l'erreur à l'utilisateur en appelant :

^code token-error

Ceci rapporte une erreur à un token donné. Cela montre l'emplacement du token et le token lui-même. Cela sera utile plus tard puisque nous utilisons des tokens tout au long de l'interpréteur pour suivre les emplacements dans le code.

Après avoir rapporté l'erreur, l'utilisateur est au courant de son erreur, mais que fait le _parseur_ ensuite ? De retour dans `error()`, nous créons et renvoyons une ParseError, une instance de cette nouvelle classe :

^code parse-error (1 before, 1 after)

C'est une simple classe sentinelle que nous utilisons pour dérouler le parseur. La méthode `error()` _renvoie_ l'erreur au lieu de la _lancer_ parce que nous voulons laisser la méthode appelante à l'intérieur du parseur décider si elle doit dérouler ou non. Certaines erreurs de parsing se produisent dans des endroits où le parseur n'est pas susceptible d'entrer dans un état bizarre et nous n'avons pas besoin de <span name="production">synchroniser</span>. Dans ces endroits, nous rapportons simplement l'erreur et continuons notre route.

Par exemple, Lox limite le nombre d'arguments que vous pouvez passer à une fonction. Si vous en passez trop, le parseur doit rapporter cette erreur, mais il peut et devrait simplement continuer à parser les arguments supplémentaires au lieu de paniquer et d'entrer en mode panique.

<aside name="production">

Une autre façon de gérer les erreurs de syntaxe courantes est avec des **productions d'erreur**. Vous augmentez la grammaire avec une règle qui matche _avec succès_ la syntaxe _erronée_. Le parseur la parse en toute sécurité mais la rapporte ensuite comme une erreur au lieu de produire un arbre syntaxique.

Par exemple, certains langages ont un opérateur `+` unaire, comme `+123`, mais Lox n'en a pas. Au lieu d'être confus quand le parseur trébuche sur un `+` au début d'une expression, nous pourrions étendre la règle unaire pour l'autoriser.

```ebnf
unary → ( "!" | "-" | "+" ) unary
      | primary ;
```

Cela laisse le parseur consommer `+` sans entrer en mode panique ou laisser le parseur dans un état bizarre.

Les productions d'erreur fonctionnent bien parce que vous, l'auteur du parseur, savez _comment_ le code est faux et ce que l'utilisateur essayait probablement de faire. Cela signifie que vous pouvez donner un message plus utile pour remettre l'utilisateur sur la bonne voie, comme, "Les expressions '+' unaires ne sont pas supportées." Les parseurs matures ont tendance à accumuler des productions d'erreur comme des bernacles puisqu'elles aident les utilisateurs à corriger des erreurs courantes.

</aside>

Dans notre cas, cependant, l'erreur de syntaxe est assez méchante pour que nous voulions paniquer et synchroniser. Rejeter des tokens est assez facile, mais comment synchronisons-nous le propre état du parseur ?

### Synchroniser un parseur récursif descendant

Avec la descente récursive, l'état du parseur -- quelles règles il est au milieu de reconnaître -- n'est pas stocké explicitement dans des champs. Au lieu de cela, nous utilisons la propre pile d'appels de Java pour suivre ce que le parseur fait. Chaque règle au milieu d'être parsée est un cadre d'appel sur la pile. Pour réinitialiser cet état, nous devons vider ces cadres d'appel.

La façon naturelle de faire cela en Java est les exceptions. Quand nous voulons synchroniser, nous _lançons_ cet objet ParseError. Plus haut dans la méthode pour la règle de grammaire sur laquelle nous synchronisons, nous l'attraperons. Puisque nous synchronisons sur les limites d'instruction, nous attraperons l'exception là. Après que l'exception soit attrapée, le parseur est dans le bon état. Tout ce qui reste est de synchroniser les tokens.

Nous voulons rejeter des tokens jusqu'à ce que nous soyons juste au début de l'instruction suivante. Cette frontière est assez facile à repérer -- c'est l'une des raisons principales pour lesquelles nous l'avons choisie. _Après_ un point-virgule, nous avons <span name="semicolon">probablement</span> fini avec une instruction. La plupart des instructions commencent par un mot-clé -- `for`, `if`, `return`, `var`, etc. Quand le _prochain_ token est n'importe lequel de ceux-là, nous sommes probablement sur le point de commencer une instruction.

<aside name="semicolon">

Je dis "probablement" parce que nous pourrions frapper un point-virgule séparant des clauses dans une boucle `for`. Notre synchronisation n'est pas parfaite, mais c'est OK. Nous avons déjà rapporté la première erreur précisément, donc tout après ça est une sorte de "meilleur effort".

</aside>

Cette méthode encapsule cette logique :

^code synchronize

Elle rejette des tokens jusqu'à ce qu'elle pense avoir trouvé une limite d'instruction. Après avoir attrapé une ParseError, nous appellerons ceci et ensuite nous sommes, espérons-le, de retour synchro. Quand cela fonctionne bien, nous avons rejeté des tokens qui auraient probablement causé des erreurs en cascade de toute façon, et maintenant nous pouvons parser le reste du fichier en commençant à l'instruction suivante.

Hélas, nous ne voyons pas cette méthode en action, puisque nous n'avons pas encore d'instructions. Nous y arriverons [dans quelques chapitres][statements]. Pour l'instant, si une erreur se produit, nous paniquerons et déroulerons tout le chemin jusqu'en haut et arrêterons de parser. Puisque nous ne pouvons parser qu'une seule expression de toute façon, ce n'est pas une grosse perte.

[statements]: statements-and-state.html

## Brancher le Parseur

Nous avons presque fini de parser les expressions maintenant. Il y a un autre endroit où nous avons besoin d'ajouter un peu de gestion d'erreur. Alors que le parseur descend à travers les méthodes de parsing pour chaque règle de grammaire, il finit par frapper `primary()`. Si aucun des cas là-dedans ne matche, cela signifie que nous sommes assis sur un token qui ne peut pas commencer une expression. Nous devons gérer cette erreur aussi.

^code primary-error (5 before, 1 after)

Avec cela, tout ce qu'il reste dans le parseur est de définir une méthode initiale pour le lancer. Cette méthode est appelée, assez naturellement, `parse()`.

^code parse

Nous revisiterons cette méthode plus tard quand nous ajouterons des instructions au langage. Pour l'instant, elle parse une seule expression et la renvoie. Nous avons aussi du code temporaire pour sortir du mode panique. La récupération d'erreur de syntaxe est le boulot du parseur, donc nous ne voulons pas que l'exception ParseError s'échappe dans le reste de l'interpréteur.

Quand une erreur de syntaxe se produit, cette méthode renvoie `null`. C'est OK. Le parseur promet de ne pas planter ou geler sur une syntaxe invalide, mais il ne promet pas de renvoyer un _arbre syntaxique utilisable_ si une erreur est trouvée. Dès que le parseur rapporte une erreur, `hadError` est défini, et les phases suivantes sont sautées.

Finalement, nous pouvons connecter notre tout nouveau parseur à la classe Lox principale et l'essayer. Nous n'avons toujours pas d'interpréteur, donc pour l'instant, nous parserons vers un arbre syntaxique et utiliserons ensuite la classe AstPrinter du [dernier chapitre][ast-printer] pour l'afficher.

[ast-printer]: representing-code.html#a-not-very-pretty-printer

Supprimez l'ancien code pour afficher les tokens scannés et remplacez-le par ceci :

^code print-ast (1 before, 1 after)

Félicitations, vous avez franchi le <span name="harder">seuil</span> ! C'est vraiment tout ce qu'il y a à écrire un parseur à la main. Nous étendrons la grammaire dans les chapitres ultérieurs avec l'affectation, les instructions, et d'autres trucs, mais rien de tout cela n'est plus complexe que les opérateurs binaires que nous avons taclés ici.

<aside name="harder">

Il est possible de définir une grammaire plus complexe que celle de Lox qui est difficile à parser en utilisant la descente récursive. Le parsing prédictif devient délicat quand vous pouvez avoir besoin de regarder en avant un grand nombre de tokens pour comprendre sur quoi vous êtes assis.

En pratique, la plupart des langages sont conçus pour éviter ça. Même dans les cas où ils ne le sont pas, vous pouvez généralement bricoler autour sans trop de douleur. Si vous pouvez parser C++ en utilisant la descente récursive -- ce que font beaucoup de compilateurs C++ -- vous pouvez parser n'importe quoi.

</aside>

Démarrez l'interpréteur et tapez quelques expressions. Vous voyez comment il gère la précédence et l'associativité correctement ? Pas mal pour moins de 200 lignes de code.

<div class="challenges">

## Défis

1.  En C, un bloc est une forme d'instruction qui vous permet d'emballer une série d'instructions là où une seule est attendue. L'[opérateur virgule][comma operator] est une syntaxe analogue pour les expressions. Une série d'expressions séparées par des virgules peut être donnée là où une seule expression est attendue (sauf à l'intérieur de la liste d'arguments d'un appel de fonction). À l'exécution, l'opérateur virgule évalue l'opérande gauche et rejette le résultat. Puis il évalue et renvoie l'opérande droit.

    Ajoutez le support pour les expressions virgule. Donnez-leur la même précédence et associativité qu'en C. Écrivez la grammaire, et ensuite implémentez le code de parsing nécessaire.

2.  De même, ajoutez le support pour l'opérateur conditionnel ou "ternaire" de style C `?:`. Quel niveau de précédence est autorisé entre le `?` et le `:` ? L'opérateur entier est-il associatif à gauche ou à droite ?

3.  Ajoutez des productions d'erreur pour gérer chaque opérateur binaire apparaissant sans opérande de gauche. En d'autres termes, détectez un opérateur binaire apparaissant au début d'une expression. Rapportez cela comme une erreur, mais parsez aussi et rejetez un opérande de droite avec la précédence appropriée.

[comma operator]: https://en.wikipedia.org/wiki/Comma_operator

</div>

<div class="design-note">

## Note de Conception : Logique Versus Histoire

Disons que nous décidons d'ajouter des opérateurs bit à bit `&` et `|` à Lox. Où devrions-nous les mettre dans la hiérarchie de précédence ? C -- et la plupart des langages qui suivent les traces de C -- les place sous `==`. C'est largement considéré comme une erreur parce que cela signifie que des opérations courantes comme tester un drapeau nécessitent des parenthèses.

```c
if (flags & FLAG_MASK == SOME_FLAG) { ... } // Faux.
if ((flags & FLAG_MASK) == SOME_FLAG) { ... } // Vrai.
```

Devrions-nous corriger cela pour Lox et mettre les opérateurs bit à bit plus haut dans la table de précédence que C ne le fait ? Il y a deux stratégies que nous pouvons prendre.

Vous ne voulez presque jamais utiliser le résultat d'une expression `==` comme opérande d'un opérateur bit à bit. En faisant lier plus fort les opérateurs bit à bit, les utilisateurs n'ont pas besoin de parenthéser aussi souvent. Donc si nous faisons cela, et que les utilisateurs supposent que la précédence est choisie logiquement pour minimiser les parenthèses, ils sont susceptibles de l'inférer correctement.

Ce genre de cohérence interne rend le langage plus facile à apprendre parce qu'il y a moins de cas limites et d'exceptions dans lesquels les utilisateurs doivent trébucher et ensuite corriger. C'est bien, parce qu'avant que les utilisateurs puissent utiliser notre langage, ils doivent charger toute cette syntaxe et sémantique dans leurs têtes. Un langage plus simple, plus rationnel _a du sens_.

Mais, pour beaucoup d'utilisateurs il y a un raccourci encore plus rapide pour mettre les idées de notre langage dans leur cerveau -- _utiliser des concepts qu'ils connaissent déjà_. Beaucoup de nouveaux venus à notre langage viendront de quelque autre langage ou langages. Si notre langage utilise une partie de la même syntaxe ou sémantique que ceux-là, il y a beaucoup moins à apprendre (et à _désapprendre_) pour l'utilisateur.

C'est particulièrement utile avec la syntaxe. Vous ne vous en souvenez peut-être pas bien aujourd'hui, mais il y a longtemps quand vous avez appris votre tout premier langage de programmation, le code semblait probablement étranger et inabordable. Ce n'est que par un effort minutieux que vous avez appris à le lire et à l'accepter. Si vous concevez une syntaxe nouvelle pour votre nouveau langage, vous forcez les utilisateurs à recommencer ce processus à zéro.

Tirer parti de ce que les utilisateurs savent déjà est l'un des outils les plus puissants que vous pouvez utiliser pour faciliter l'adoption de votre langage. Il est presque impossible de surestimer à quel point c'est précieux. Mais cela vous confronte à un problème méchant : Que se passe-t-il quand la chose que les utilisateurs connaissent tous _craint un peu_ ? La précédence des opérateurs bit à bit du C est une erreur qui n'a pas de sens. Mais c'est une erreur _familière_ à laquelle des millions se sont déjà habitués et avec laquelle ils ont appris à vivre.

Restez-vous fidèle à la propre logique interne de votre langage et ignorez-vous l'histoire ? Partez-vous d'une ardoise vierge et des premiers principes ? Ou tissez-vous votre langage dans la riche tapisserie de l'histoire de la programmation et donnez-vous un coup de pouce à vos utilisateurs en partant de quelque chose qu'ils connaissent déjà ?

Il n'y a pas de réponse parfaite ici, seulement des compromis. Vous et moi sommes évidemment biaisés vers le fait d'aimer les langages nouveaux, donc notre inclination naturelle est de brûler les livres d'histoire et de commencer notre propre histoire.

En pratique, il est souvent mieux de tirer le meilleur parti de ce que les utilisateurs savent déjà. Les amener à venir à votre langage nécessite un grand saut. Plus vous pouvez réduire ce gouffre, plus les gens seront prêts à le traverser. Mais vous ne pouvez pas _toujours_ coller à l'histoire, ou votre langage n'aura rien de nouveau et d'impérieux pour donner aux gens une _raison_ de sauter par-dessus.

</div>

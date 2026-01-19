> Tu es mon créateur, mais je suis ton maître ; Obéis !
>
> <cite>Mary Shelley, <em>Frankenstein</em></cite>

Si vous voulez correctement mettre l'ambiance pour ce chapitre, essayez d'invoquer un orage, l'une de ces tempêtes tourbillonnantes qui aiment arracher les volets au point culminant de l'histoire. Peut-être jeter quelques éclairs. Dans ce chapitre, notre interpréteur va prendre sa respiration, ouvrir les yeux, et exécuter du code.

<span name="spooky"></span>

<img src="image/evaluating-expressions/lightning.png" alt="Un éclair frappe un manoir victorien. Effrayant !" />

<aside name="spooky">

Un manoir victorien décrépit est optionnel, mais ajoute à l'ambiance.

</aside>

Il y a toutes sortes de façons dont les implémentations de langage font faire à un ordinateur ce que le code source de l'utilisateur commande. Elles peuvent le compiler en code machine, le traduire vers un autre langage de haut niveau, ou le réduire à un format bytecode pour qu'une machine virtuelle l'exécute. Pour notre premier interpréteur, cependant, nous allons prendre le chemin le plus simple, le plus court et exécuter l'arbre syntaxique lui-même.

Pour l'instant, notre parseur supporte seulement les expressions. Donc, pour "exécuter" du code, nous évaluerons une expression et produirons une valeur. Pour chaque type de syntaxe d'expression que nous pouvons parser -- littéral, opérateur, etc. -- nous avons besoin d'un morceau de code correspondant qui sait comment évaluer cet arbre et produire un résultat. Cela soulève deux questions :

1. Quels types de valeurs produisons-nous ?

2. Comment organisons-nous ces morceaux de code ?

Prenons-les une par une...

## Représenter les Valeurs

Dans Lox, les <span name="value">valeurs</span> sont créées par les littéraux, calculées par les expressions, et stockées dans des variables. L'utilisateur les voit comme des objets _Lox_, mais elles sont implémentées dans le langage sous-jacent dans lequel notre interpréteur est écrit. Cela signifie faire le pont entre les terres du typage dynamique de Lox et les types statiques de Java. Une variable dans Lox peut stocker une valeur de n'importe quel type (Lox), et peut même stocker des valeurs de différents types à différents moments. Quel type Java pourrions-nous utiliser pour représenter cela ?

<aside name="value">

Ici, j'utilise "valeur" et "objet" à peu près de manière interchangeable.

Plus tard dans l'interpréteur C, nous ferons une légère distinction entre eux, mais c'est surtout pour avoir des termes uniques pour deux coins différents de l'implémentation -- données en place contre allouées sur le tas. Du point de vue de l'utilisateur, les termes sont synonymes.

</aside>

Étant donné une variable Java avec ce type statique, nous devons aussi être capables de déterminer quel genre de valeur elle contient à l'exécution. Quand l'interpréteur exécute un opérateur `+`, il a besoin de dire s'il ajoute deux nombres ou concatène deux chaînes. Y a-t-il un type Java qui peut contenir des nombres, des chaînes, des booléens, et plus ? Y en a-t-il un qui peut nous dire quel est son type d'exécution ? Il y en a un ! Le bon vieux java.lang.Object.

Dans les endroits de l'interpréteur où nous avons besoin de stocker une valeur Lox, nous pouvons utiliser Object comme type. Java a des versions "boxées" (enveloppées) de ses types primitifs qui sous-classent toutes Object, donc nous pouvons utiliser celles-ci pour les types intégrés de Lox :

<table>
<thead>
<tr>
  <td>Type Lox</td>
  <td>Représentation Java</td>
</tr>
</thead>
<tbody>
<tr>
  <td>N'importe quelle valeur Lox</td>
  <td>Object</td>
</tr>
<tr>
  <td><code>nil</code></td>
  <td><code>null</code></td>
</tr>
<tr>
  <td>Booléen</td>
  <td>Boolean</td>
</tr>
<tr>
  <td>nombre</td>
  <td>Double</td>
</tr>
<tr>
  <td>chaîne</td>
  <td>String</td>
</tr>
</tbody>
</table>

Étant donné une valeur de type statique Object, nous pouvons déterminer si la valeur d'exécution est un nombre ou une chaîne ou quoi que ce soit en utilisant l'opérateur intégré de Java `instanceof`. En d'autres termes, la propre représentation d'objet de la <span name="jvm">JVM</span> nous donne commodément tout ce dont nous avons besoin pour implémenter les types intégrés de Lox. Nous devrons faire un peu plus de travail plus tard quand nous ajouterons les notions de fonctions, classes et instances de Lox, mais Object et les classes primitives boxées sont suffisants pour les types dont nous avons besoin pour l'instant.

<aside name="jvm">

Une autre chose que nous devons faire avec les valeurs est gérer leur mémoire, et Java fait cela aussi. Une représentation d'objet pratique et un ramasse-miettes vraiment sympa sont les raisons principales pour lesquelles nous écrivons notre premier interpréteur en Java.

</aside>

## Évaluation des Expressions

Ensuite, nous avons besoin de paquets de code pour implémenter la logique d'évaluation pour chaque type d'expression que nous pouvons parser. Nous pourrions fourrer ce code dans les classes d'arbre syntaxique dans quelque chose comme une méthode `interpret()`. En effet, nous pourrions dire à chaque nœud d'arbre syntaxique, "Interprète-toi toi-même". C'est le [patron de conception Interpréteur][interpreter design pattern] du Gang of Four. C'est un patron sympa, mais comme je l'ai mentionné plus tôt, cela devient désordonné si nous bourrons toutes sortes de logique dans les classes d'arbre.

[interpreter design pattern]: https://en.wikipedia.org/wiki/Interpreter_pattern

Au lieu de cela, nous allons réutiliser notre groovy [patron Visiteur][visitor pattern]. Dans le chapitre précédent, nous avons créé une classe AstPrinter. Elle prenait un arbre syntaxique et le parcourait récursivement, construisant une chaîne qu'elle renvoyait finalement. C'est presque exactement ce qu'un vrai interpréteur fait, sauf qu'au lieu de concaténer des chaînes, il calcule des valeurs.

[visitor pattern]: representing-code.html#the-visitor-pattern

Nous commençons avec une nouvelle classe.

^code interpreter-class

La classe déclare qu'elle est un visiteur. Le type de retour des méthodes visit sera Object, la classe racine que nous utilisons pour nous référer à une valeur Lox dans notre code Java. Pour satisfaire l'interface Visitor, nous devons définir des méthodes visit pour chacune des quatre classes d'arbre d'expression que notre parseur produit. Nous commencerons par la plus simple...

### Évaluation des littéraux

Les feuilles d'un arbre d'expression -- les bouts atomiques de syntaxe dont toutes les autres expressions sont composées -- sont les <span name="leaf">littéraux</span>. Les littéraux sont presque déjà des valeurs, mais la distinction est importante. Un littéral est un _bout de syntaxe_ qui produit une valeur. Un littéral apparaît toujours quelque part dans le code source de l'utilisateur. Beaucoup de valeurs sont produites par le calcul et n'existent nulle part dans le code lui-même. Ce ne sont pas des littéraux. Un littéral vient du domaine du parseur. Les valeurs sont un concept de l'interpréteur, une partie du monde de l'exécution (runtime).

<aside name="leaf">

Dans le [prochain chapitre][vars], quand nous implémenterons les variables, nous ajouterons les expressions d'identifiant, qui sont aussi des nœuds feuilles.

[vars]: statements-and-state.html

</aside>

Donc, tout comme nous avons converti un _token_ littéral en un _nœud d'arbre syntaxique_ littéral dans le parseur, maintenant nous convertissons le nœud d'arbre littéral en une valeur d'exécution. Cela s'avère être trivial.

^code visit-literal

Nous avons produit avidemment la valeur d'exécution bien avant pendant le scan et l'avons fourrée dans le token. Le parseur a pris cette valeur et l'a collée dans le nœud d'arbre littéral, donc pour évaluer un littéral, nous la ressortons simplement.

### Évaluation des parenthèses

Le prochain nœud le plus simple à évaluer est le groupement -- le nœud que vous obtenez comme résultat de l'utilisation de parenthèses explicites dans une expression.

^code visit-grouping

Un nœud de <span name="grouping">groupement</span> a une référence vers un nœud interne pour l'expression contenue à l'intérieur des parenthèses. Pour évaluer l'expression de groupement elle-même, nous évaluons récursivement cette sous-expression et la renvoyons.

Nous comptons sur cette méthode d'aide qui renvoie simplement l'expression dans l'implémentation du visiteur de l'interpréteur :

<aside name="grouping">

Certains parseurs ne définissent pas de nœuds d'arbre pour les parenthèses. Au lieu de cela, lors du parsing d'une expression parenthésée, ils renvoient simplement le nœud pour l'expression interne. Nous créons un nœud pour les parenthèses dans Lox parce que nous en aurons besoin plus tard pour gérer correctement les côtés gauches des expressions d'affectation.

</aside>

^code evaluate

### Évaluation des expressions unaires

Comme le groupement, les expressions unaires ont une seule sous-expression que nous devons évaluer en premier. La différence est que l'expression unaire elle-même fait un peu de travail après.

^code visit-unary

D'abord, nous évaluons l'expression opérande. Ensuite, nous appliquons l'opérateur unaire lui-même au résultat de cela. Il y a deux expressions unaires différentes, identifiées par le type du token opérateur.

Montré ici est `-`, qui inverse le signe du résultat de la sous-expression. La sous-expression doit être un nombre. Puisque nous ne savons pas _statiquement_ cela en Java, nous le <span name="cast">castons</span> avant d'effectuer l'opération. Ce cast de type se produit à l'exécution quand le `-` est évalué. C'est le cœur de ce qui rend un langage typé dynamiquement juste là.

<aside name="cast">

Vous vous demandez probablement ce qui se passe si le cast échoue. N'ayez crainte, nous y viendrons bientôt.

</aside>

Vous pouvez commencer à voir comment l'évaluation traverse récursivement l'arbre. Nous ne pouvons pas évaluer l'opérateur unaire lui-même avant d'avoir évalué sa sous-expression opérande. Cela signifie que notre interpréteur fait un **parcours post-ordre** -- chaque nœud évalue ses enfants avant de faire son propre travail.

L'autre opérateur unaire est le non logique.

^code unary-bang (1 before, 1 after)

L'implémentation est simple, mais c'est quoi ce truc "truthy" (vrai) ? Nous avons besoin de faire une petite excursion vers l'une des grandes questions de la philosophie occidentale : _Qu'est-ce que la vérité ?_

### Vérité et fausseté

OK, peut-être que nous n'allons pas vraiment entrer dans la question universelle, mais au moins à l'intérieur du monde de Lox, nous devons décider ce qui se passe quand vous utilisez quelque chose d'autre que `true` ou `false` dans une opération logique comme `!` ou n'importe quel autre endroit où un Booléen est attendu.

Nous _pourrions_ juste dire que c'est une erreur parce que nous ne roulons pas avec les conversions implicites, mais la plupart des langages typés dynamiquement ne sont pas aussi ascétiques. Au lieu de cela, ils prennent l'univers des valeurs de tous types et les partitionnent en deux ensembles, l'un qu'ils définissent comme "vrai", ou "truthy", et le reste qui sont "faux" ou "falsey". Ce partitionnement est quelque peu arbitraire et devient <span name="weird">bizarre</span> dans quelques langages.

<aside name="weird" class="bottom">

En JavaScript, les chaînes sont truthy, mais les chaînes vides ne le sont pas. Les tableaux sont truthy mais les tableaux vides sont... aussi truthy. Le nombre `0` est falsey, mais la _chaîne_ `"0"` est truthy.

En Python, les chaînes vides sont falsey comme en JS, mais d'autres séquences vides sont falsey aussi.

En PHP, à la fois le nombre `0` et la chaîne `"0"` sont falsey. La plupart des autres chaînes non vides sont truthy.

Vous avez tout suivi ?

</aside>

Lox suit la règle simple de Ruby : `false` et `nil` sont falsey, et tout le reste est truthy. Nous implémentons cela comme ceci :

^code is-truthy

### Évaluation des opérateurs binaires

Passons à la dernière classe d'arbre d'expression, les opérateurs binaires. Il y en a une poignée, et nous commencerons par ceux arithmétiques.

^code visit-binary

<aside name="left">

Avez-vous remarqué que nous avons épinglé un coin subtil de la sémantique du langage ici ? Dans une expression binaire, nous évaluons les opérandes dans l'ordre de gauche à droite. Si ces opérandes ont des effets de bord, ce choix est visible par l'utilisateur, donc ce n'est pas simplement un détail d'implémentation.

Si nous voulons que nos deux interpréteurs soient cohérents (indice : nous le voulons), nous devrons nous assurer que clox fait la même chose.

</aside>

Je pense que vous pouvez comprendre ce qui se passe ici. La différence principale avec l'opérateur de négation unaire est que nous avons deux opérandes à évaluer.

J'ai laissé de côté un opérateur arithmétique parce qu'il est un peu spécial.

^code binary-plus (3 before, 1 after)

L'opérateur `+` peut aussi être utilisé pour concaténer deux chaînes. Pour gérer cela, nous ne supposons pas juste que les opérandes sont d'un certain type et les _castons_, nous _vérifions_ dynamiquement le type et choisissons l'opération appropriée. C'est pourquoi nous avons besoin que notre représentation d'objet supporte `instanceof`.

<aside name="plus">

Nous aurions pu définir un opérateur spécifiquement pour la concaténation de chaînes. C'est ce que Perl (`.`), Lua (`..`), Smalltalk (`,`), Haskell (`++`), et d'autres font.

J'ai pensé que cela rendrait Lox un peu plus abordable d'utiliser la même syntaxe que Java, JavaScript, Python, et d'autres. Cela signifie que l'opérateur `+` est **surchargé** pour supporter à la fois l'addition de nombres et la concaténation de chaînes. Même dans les langages qui n'utilisent pas `+` pour les chaînes, ils le surchargent toujours souvent pour ajouter à la fois des entiers et des nombres à virgule flottante.

</aside>

Les suivants sont les opérateurs de comparaison.

^code binary-comparison (1 before, 1 after)

Ils sont fondamentalement les mêmes que l'arithmétique. La seule différence est que là où les opérateurs arithmétiques produisent une valeur dont le type est le même que les opérandes (nombres ou chaînes), les opérateurs de comparaison produisent toujours un Booléen.

La dernière paire d'opérateurs sont pour l'égalité.

^code binary-equality

Contrairement aux opérateurs de comparaison qui nécessitent des nombres, les opérateurs d'égalité supportent des opérandes de n'importe quel type, même mixtes. Vous ne pouvez pas demander à Lox si 3 est _plus petit_ que `"trois"`, mais vous pouvez demander s'il est <span name="equal">_égal_</span> à lui.

<aside name="equal">

Alerte spoiler : il ne l'est pas.

</aside>

Comme la véracité (truthiness), la logique d'égalité est hissée hors dans une méthode séparée.

^code is-equal

C'est l'un de ces coins où les détails de comment nous représentons les objets Lox en termes de Java comptent. Nous devons implémenter correctement la notion d'égalité de _Lox_, qui peut être différente de celle de Java.

Heureusement, les deux sont assez similaires. Lox ne fait pas de conversions implicites dans l'égalité et Java non plus. Nous devons gérer `nil`/`null` spécialement afin de ne pas lancer de NullPointerException si nous essayons d'appeler `equals()` sur `null`. Sinon, nous sommes bons. La méthode <span name="nan">`equals()`</span> de Java sur Boolean, Double, et String a le comportement que nous voulons pour Lox.

<aside name="nan">

À quoi vous attendez-vous que ceci évalue :

```lox
(0 / 0) == (0 / 0)
```

Selon [IEEE 754][], qui spécifie le comportement des nombres à double précision, diviser un zéro par zéro vous donne la valeur spéciale **NaN** ("not a number" - pas un nombre). Étrangement assez, NaN n'est _pas_ égal à lui-même.

En Java, l'opérateur `==` sur les doubles primitifs préserve ce comportement, mais la méthode `equals()` sur la classe Double ne le fait pas. Lox utilise cette dernière, donc ne suit pas IEEE. Ces types d'incompatibilités subtiles occupent une fraction consternante de la vie des implémenteurs de langage.

[ieee 754]: https://en.wikipedia.org/wiki/IEEE_754

</aside>

Et c'est tout ! C'est tout le code dont nous avons besoin pour interpréter correctement une expression Lox valide. Mais qu'en est-il d'une _invalide_ ? En particulier, que se passe-t-il quand une sous-expression s'évalue en un objet du mauvais type pour l'opération effectuée ?

## Erreurs d'Exécution

J'ai été cavalier en bourrant des casts chaque fois qu'une sous-expression produit un Object et que l'opérateur exige qu'il soit un nombre ou une chaîne. Ces casts peuvent échouer. Même si le code de l'utilisateur est erroné, si nous voulons faire un langage <span name="fail">utilisable</span>, nous sommes responsables de la gestion de cette erreur avec grâce.

<aside name="fail">

Nous pourrions simplement ne pas détecter ou rapporter une erreur de type du tout. C'est ce que fait C si vous castez un pointeur vers un certain type qui ne correspond pas aux données qui sont réellement pointées. C gagne de la flexibilité et de la vitesse en permettant cela, mais est aussi fameusement dangereux. Une fois que vous mésinterprétez des bits en mémoire, tous les paris sont ouverts.

Peu de langages modernes acceptent des opérations non sûres comme celle-là. Au lieu de cela, la plupart sont **sûrs pour la mémoire** et assurent -- à travers une combinaison de vérifications statiques et à l'exécution -- qu'un programme ne peut jamais interpréter incorrectement la valeur stockée dans un morceau de mémoire.

</aside>

Il est temps pour nous de parler des **erreurs d'exécution** (runtime errors). J'ai versé beaucoup d'encre dans les chapitres précédents en parlant de la gestion d'erreur, mais c'étaient toutes des erreurs de _syntaxe_ ou _statiques_. Celles-ci sont détectées et rapportées avant que _le moindre_ code soit exécuté. Les erreurs d'exécution sont des échecs que la sémantique du langage exige que nous détections et rapportions pendant que le programme s'exécute (d'où le nom).

Pour l'instant, si un opérande est du mauvais type pour l'opération effectuée, le cast Java échouera et la JVM lancera une ClassCastException. Cela déroule toute la pile et quitte l'application, vomissant une trace de pile Java sur l'utilisateur. Ce n'est probablement pas ce que nous voulons. Le fait que Lox soit implémenté en Java devrait être un détail caché de l'utilisateur. Au lieu de cela, nous voulons qu'ils comprennent qu'une erreur d'exécution _Lox_ s'est produite, et leur donner un message d'erreur pertinent pour notre langage et leur programme.

Le comportement Java a une chose pour lui, cependant. Il arrête correctement l'exécution de tout code quand l'erreur se produit. Disons que l'utilisateur entre une expression comme :

```lox
2 * (3 / -"muffin")
```

Vous ne pouvez pas inverser le signe d'un <span name="muffin">muffin</span>, donc nous devons rapporter une erreur d'exécution à cette expression `-` interne. Cela signifie à son tour que nous ne pouvons pas évaluer l'expression `/` puisqu'elle n'a pas d'opérande droit significatif. De même pour le `*`. Donc quand une erreur d'exécution se produit profondément dans une expression, nous avons besoin de nous échapper tout le chemin vers l'extérieur.

<aside name="muffin">

Je ne sais pas, mec, _peux_-tu inverser le signe d'un muffin ?

<img src="image/evaluating-expressions/muffin.png" alt="Un muffin, inversé." />

</aside>

Nous pourrions imprimer une erreur d'exécution et ensuite avorter le processus et quitter l'application entièrement. Cela a un certain flair mélodramatique. Sorte d'équivalent pour un interpréteur de langage de programmation d'un lâcher de micro.

Aussi tentant que cela soit, nous devrions probablement faire quelque chose d'un peu moins cataclysmique. Bien qu'une erreur d'exécution doive arrêter l'évaluation de l'_expression_, elle ne devrait pas tuer l'_interpréteur_. Si un utilisateur exécute le REPL et a une faute de frappe dans une ligne de code, il devrait toujours être capable de garder la session en cours et d'entrer plus de code après cela.

### Détecter les erreurs d'exécution

Notre interpréteur à parcours d'arbre évalue les expressions imbriquées en utilisant des appels de méthode récursifs, et nous avons besoin de nous dérouler hors de tout ceux-là. Lancer une exception en Java est un bon moyen d'accomplir cela. Cependant, au lieu d'utiliser le propre échec de cast de Java, nous en définirons un spécifique à Lox afin que nous puissions le gérer comme nous voulons.

Avant de faire le cast, nous vérifions le type de l'objet nous-mêmes. Donc, pour le `-` unaire, nous ajoutons :

^code check-unary-operand (1 before, 1 after)

Le code pour vérifier l'opérande est :

^code check-operand

Quand la vérification échoue, elle lance un de ceux-ci :

^code runtime-error-class

Contrairement à l'exception de cast Java, notre <span name="class">classe</span> suit le token qui identifie d'où dans le code de l'utilisateur l'erreur d'exécution est venue. Comme pour les erreurs statiques, cela aide l'utilisateur à savoir où corriger son code.

<aside name="class">

J'admets que le nom "RuntimeError" est confus puisque Java définit une classe RuntimeException. Une chose ennuyeuse à propos de la construction d'interpréteurs est que vos noms entrent souvent en collision avec ceux déjà pris par le langage d'implémentation. Attendez juste que nous supportions les classes Lox.

</aside>

Nous avons besoin de vérifications similaires pour les opérateurs binaires. Puisque je vous ai promis chaque ligne de code nécessaire pour implémenter les interpréteurs, je vais toutes les passer en revue.

Plus grand que :

^code check-greater-operand (1 before, 1 after)

Plus grand ou égal à :

^code check-greater-equal-operand (1 before, 1 after)

Plus petit que :

^code check-less-operand (1 before, 1 after)

Plus petit ou égal à :

^code check-less-equal-operand (1 before, 1 after)

Soustraction :

^code check-minus-operand (1 before, 1 after)

Division :

^code check-slash-operand (1 before, 1 after)

Multiplication :

^code check-star-operand (1 before, 1 after)

Tous ceux-là reposent sur ce validateur, qui est virtuellement le même que celui unaire :

^code check-operands

<aside name="operand">

Un autre choix sémantique subtil : Nous évaluons les _deux_ opérandes avant de vérifier le type de l'_un ou l'autre_. Imaginez que nous ayons une fonction `say()` qui imprime son argument puis le renvoie. En utilisant cela, nous écrivons :

```lox
say("left") - say("right");
```

Notre interpréteur imprime "left" et "right" avant de rapporter l'erreur d'exécution. Nous aurions pu à la place spécifier que l'opérande gauche est vérifié avant même d'évaluer le droit.

</aside>

Le dernier opérateur restant, encore l'intrus, est l'addition. Puisque `+` est surchargé pour les nombres et les chaînes, il a déjà du code pour vérifier les types. Tout ce que nous avons besoin de faire est d'échouer si aucun des deux cas de succès ne matche.

^code string-wrong-type (3 before, 1 after)

Cela nous permet de détecter les erreurs d'exécution profondément dans les entrailles de l'évaluateur. Les erreurs sont lancées. L'étape suivante est d'écrire le code qui les attrape. Pour cela, nous avons besoin de brancher la classe Interpreter dans la classe Lox principale qui la pilote.

## Connecter l'Interpréteur

Les méthodes visit sont en quelque sorte les tripes de la classe Interpreter, où le vrai travail se passe. Nous avons besoin d'envelopper une peau autour d'elles pour s'interfacer avec le reste du programme. L'API publique de l'Interpreter est simplement une méthode.

^code interpret

Celle-ci prend un arbre syntaxique pour une expression et l'évalue. Si cela réussit, `evaluate()` renvoie un objet pour la valeur résultat. `interpret()` convertit cela en une chaîne et la montre à l'utilisateur. Pour convertir une valeur Lox en chaîne, nous comptons sur :

^code stringify

C'est une autre de ces pièces de code comme `isTruthy()` qui traverse la membrane entre la vue de l'utilisateur des objets Lox et leur représentation interne en Java.

C'est assez direct. Puisque Lox a été conçu pour être familier à quelqu'un venant de Java, des choses comme les Booléens semblent identiques dans les deux langages. Les deux cas limites sont `nil`, que nous représentons en utilisant le `null` de Java, et les nombres.

Lox utilise des nombres à double précision même pour les valeurs entières. Dans ce cas, ils devraient s'imprimer sans point décimal. Puisque Java a à la fois des types à virgule flottante et entiers, il veut que vous sachiez lequel vous utilisez. Il vous le dit en ajoutant un `.0` explicite aux doubles à valeur entière. Nous ne nous soucions pas de cela, donc nous le <span name="number">hachons</span> de la fin.

<aside name="number">

Encore une fois, nous prenons soin de ce cas limite avec les nombres pour nous assurer que jlox et clox fonctionnent de la même manière. Gérer des coins bizarres du langage comme celui-ci vous rendra fou mais est une partie importante du boulot.

Les utilisateurs comptent sur ces détails -- soit délibérément soit par inadvertance -- et si les implémentations ne sont pas cohérentes, leur programme cassera quand ils l'exécuteront sur différents interpréteurs.

</aside>

### Rapporter les erreurs d'exécution

Si une erreur d'exécution est lancée pendant l'évaluation de l'expression, `interpret()` l'attrape. Cela nous laisse rapporter l'erreur à l'utilisateur et ensuite continuer avec grâce. Tout notre code de rapport d'erreur existant vit dans la classe Lox, donc nous mettons cette méthode là aussi :

^code runtime-error-method

Nous utilisons le token associé à la RuntimeError pour dire à l'utilisateur quelle ligne de code s'exécutait quand l'erreur s'est produite. Encore mieux serait de donner à l'utilisateur une pile d'appels entière pour montrer comment ils sont _arrivés_ à exécuter ce code. Mais nous n'avons pas encore d'appels de fonction, donc je suppose que nous n'avons pas à nous en soucier.

Après avoir montré l'erreur, `runtimeError()` définit ce champ :

^code had-runtime-error-field (1 before, 1 after)

Ce champ joue un petit mais important rôle.

^code check-runtime-error (4 before, 1 after)

Si l'utilisateur exécute un <span name="repl">script Lox depuis un fichier</span> et qu'une erreur d'exécution se produit, nous définissons un code de sortie quand le processus quitte pour le faire savoir au processus appelant. Tout le monde ne se soucie pas de l'étiquette du shell, mais nous si.

<aside name="repl">

Si l'utilisateur exécute le REPL, nous ne nous soucions pas de suivre les erreurs d'exécution. Après qu'elles soient rapportées, nous bouclons simplement et les laissons entrer du nouveau code et continuer.

</aside>

### Exécuter l'interpréteur

Maintenant que nous avons un interpréteur, la classe Lox peut commencer à l'utiliser.

^code interpreter-instance (1 before, 1 after)

Nous rendons le champ statique afin que les appels successifs à `run()` à l'intérieur d'une session REPL réutilisent le même interpréteur. Cela ne fait pas de différence maintenant, mais cela en fera plus tard quand l'interpréteur stockera des variables globales. Ces variables devraient persister tout au long de la session REPL.

Finalement, nous supprimons la ligne de code temporaire du [dernier chapitre][last chapter] pour imprimer l'arbre syntaxique et la remplaçons par ceci :

[last chapter]: parsing-expressions.html

^code interpreter-interpret (3 before, 1 after)

Nous avons un pipeline de langage entier maintenant : scan, parsing, et exécution. Félicitations, vous avez maintenant votre propre calculatrice arithmétique.

Comme vous pouvez le voir, l'interpréteur est assez squelettique. Mais la classe Interpreter et le patron Visiteur que nous avons mis en place aujourd'hui forment le squelette que les chapitres ultérieurs bourreront plein de tripes intéressantes -- variables, fonctions, etc. Pour l'instant, l'interpréteur ne fait pas grand chose, mais il est vivant !

<img src="image/evaluating-expressions/skeleton.png" alt="Un squelette disant bonjour de la main." />

<div class="challenges">

## Défis

1.  Permettre des comparaisons sur des types autres que les nombres pourrait être utile. Les opérateurs pourraient avoir une interprétation raisonnable pour les chaînes. Même les comparaisons parmi des types mixtes, comme `3 < "pancake"` pourraient être pratiques pour permettre des choses comme des collections ordonnées de types hétérogènes. Ou cela pourrait simplement mener à des bugs et de la confusion.

    Étenderiez-vous Lox pour supporter la comparaison d'autres types ? Si oui, quelles paires de types autorisez-vous et comment définissez-vous leur ordre ? Justifiez vos choix et comparez-les à d'autres langages.

2.  Beaucoup de langages définissent `+` tel que si _l'un ou l'autre_ des opérandes est une chaîne, l'autre est converti en une chaîne et les résultats sont ensuite concaténés. Par exemple, `"scone" + 4` donnerait `scone4`. Étendez le code dans `visitBinaryExpr()` pour supporter cela.

3.  Qu'est-ce qui se passe pour l'instant si vous divisez un nombre par zéro ? Que pensez-vous qu'il devrait se passer ? Justifiez votre choix. Comment d'autres langages que vous connaissez gèrent-ils la division par zéro, et pourquoi font-ils les choix qu'ils font ?

    Changez l'implémentation dans `visitBinaryExpr()` pour détecter et rapporter une erreur d'exécution pour ce cas.

</div>

<div class="design-note">

## Note de Conception : Typage Statique et Dynamique

Certains langages, comme Java, sont typés statiquement ce qui signifie que les erreurs de type sont détectées et rapportées au temps de compilation avant que le moindre code ne soit exécuté. D'autres, comme Lox, sont typés dynamiquement et diffèrent la vérification des erreurs de type jusqu'à l'exécution juste avant qu'une opération ne soit tentée. Nous avons tendance à considérer cela comme un choix noir ou blanc, mais il y a en fait un continuum entre eux.

Il s'avère que même la plupart des langages typés statiquement font _quelques_ vérifications de type à l'exécution. Le système de type vérifie la plupart des règles de type statiquement, mais insère des vérifications à l'exécution dans le code généré pour d'autres opérations.

Par exemple, en Java, le système de type _statique_ suppose qu'une expression de cast réussira toujours en toute sécurité. Après avoir casté une valeur, vous pouvez statiquement la traiter comme le type de destination et ne pas obtenir d'erreurs de compilation. Mais les downcasts peuvent échouer, évidemment. La seule raison pour laquelle le vérificateur statique peut présumer que les casts réussissent toujours sans violer les garanties de robustesse du langage, est parce que le cast est vérifié _à l'exécution_ et lance une exception en cas d'échec.

Un exemple plus subtil est les [tableaux covariants][covariant arrays] en Java et C#. Les règles de sous-typage statique pour les tableaux autorisent des opérations qui ne sont pas sûres. Considérez :

[covariant arrays]: https://en.wikipedia.org/wiki/Covariance_and_contravariance_(computer_science)#Covariant_arrays_in_Java_and_C.23

```java
Object[] stuff = new Integer[1];
stuff[0] = "pas un int !";
```

Ce code compile sans aucune erreur. La première ligne upcaste le tableau d'Integer et le stocke dans une variable de type tableau d'Object. La seconde ligne stocke une chaîne dans l'une de ses cellules. Le type tableau d'Object autorise statiquement cela -- les chaînes _sont_ des Objects -- mais le tableau d'Integer réel auquel `stuff` se réfère à l'exécution ne devrait jamais avoir une chaîne dedans ! Pour éviter cette catastrophe, quand vous stockez une valeur dans un tableau, la JVM fait une vérification _à l'exécution_ pour s'assurer que c'est un type autorisé. Si non, elle lance une ArrayStoreException.

Java aurait pu éviter le besoin de vérifier cela à l'exécution en interdisant le cast sur la première ligne. Il aurait pu rendre les tableaux _invariants_ de telle sorte qu'un tableau d'Integers n'est _pas_ un tableau d'Objects. C'est statiquement sûr, mais cela interdit des patrons courants et sûrs de code qui lisent seulement depuis les tableaux. La covariance est sûre si vous n'_écrivez_ jamais dans le tableau. Ces patrons étaient particulièrement importants pour l'utilisabilité dans Java 1.0 avant qu'il ne supporte les génériques. James Gosling et les autres concepteurs de Java ont échangé un peu de sécurité statique et de performance -- ces vérifications de stockage de tableau prennent du temps -- en retour d'un peu de flexibilité.

Il y a peu de langages typés statiquement modernes qui ne font pas ce compromis _quelque part_. Même Haskell vous laissera exécuter du code avec des correspondances non exhaustives. Si vous vous trouvez à concevoir un langage typé statiquement, gardez à l'esprit que vous pouvez parfois donner aux utilisateurs plus de flexibilité sans sacrifier _trop_ des bénéfices de la sécurité statique en différant certaines vérifications de type jusqu'à l'exécution.

D'un autre côté, une raison clé pour laquelle les utilisateurs choisissent des langages typés statiquement est à cause de la confiance que le langage leur donne que certains types d'erreurs ne peuvent _jamais_ se produire quand leur programme est exécuté. Différez trop de vérifications de type jusqu'à l'exécution, et vous érodez cette confiance.

</div>

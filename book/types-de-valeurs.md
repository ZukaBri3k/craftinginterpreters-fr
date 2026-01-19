> Quand tu es un Ours de Très Peu de Cerveau, et que tu Penses à des Choses, tu trouves parfois qu'une Chose qui semblait très Chosifiée à l'intérieur de toi est tout à fait différente quand elle sort à l'air libre et que d'autres personnes la regardent.
>
> <cite>A. A. Milne, <em>Winnie l'Ourson</em></cite>

Les quelques chapitres passés étaient énormes, remplis de techniques complexes et de pages de code. Dans ce chapitre, il n'y a qu'un seul nouveau concept à apprendre et un éparpillement de code simple. Vous avez mérité un répit.

Lox est <span name="unityped">dynamiquement</span> typé. Une variable unique peut contenir un Booléen, un nombre, ou une chaîne de caractères à différents points dans le temps. Au moins, c'est l'idée. En ce moment, dans clox, toutes les valeurs sont des nombres. À la fin du chapitre, il supportera aussi les Booléens et `nil`. Bien que ceux-ci ne soient pas super intéressants, ils nous forcent à comprendre comment notre représentation de valeur peut gérer dynamiquement différents types.

<aside name="unityped">

Il y a une troisième catégorie à côté de typé statiquement et typé dynamiquement : **unitypé**. Dans ce paradigme, toutes les variables ont un type unique, généralement un entier de registre machine. Les langages unitypés ne sont pas communs aujourd'hui, mais certains Forths et BCPL, le langage qui a inspiré C, fonctionnaient comme ceci.

À ce moment précis, clox est unitypé.

</aside>

## Unions Étiquetées

La chose sympa à propos de travailler en C est que nous pouvons construire nos structures de données depuis les bits bruts. La mauvaise chose est que nous _devons_ faire cela. C ne vous donne pas grand-chose gratuitement à la compilation et encore moins à l'exécution. Pour autant que C soit concerné, l'univers est un tableau indifférencié d'octets. C'est à nous de décider combien de ces octets utiliser et ce qu'ils signifient.

Afin de choisir une représentation de valeur, nous avons besoin de répondre à deux questions clés :

1.  **Comment représentons-nous le type d'une valeur ?** Si vous essayez de, disons, multiplier un nombre par `true`, nous avons besoin de détecter cette erreur à l'exécution et de la rapporter. Afin de faire cela, nous avons besoin d'être capables de dire quel est le type d'une valeur.

2.  **Comment stockons-nous la valeur elle-même ?** Nous avons besoin non seulement d'être capables de dire que trois est un nombre, mais qu'il est différent du nombre quatre. Je sais, ça semble évident, pas vrai ? Mais nous opérons à un niveau où il est bon d'épeler ces choses.

Puisque nous ne faisons pas juste concevoir ce langage mais le construisons nous-mêmes, en répondant à ces deux questions nous devons aussi garder en tête la quête éternelle de l'implémenteur : le faire _efficacement_.

Les hackers de langage au fil des années ont trouvé une variété de façons intelligentes d'empaqueter les informations ci-dessus dans aussi peu de bits que possible. Pour l'instant, nous commencerons avec la solution la plus simple et classique : une **union étiquetée**. Une valeur contient deux parties : une étiquette de type (ou "tag"), et une charge utile pour la valeur réelle. Pour stocker le type de la valeur, nous définissons un enum pour chaque sorte de valeur que la VM supporte.

^code value-type (2 before, 1 after)

<aside name="user-types">

Les cas ici couvrent chaque sorte de valeur qui a un _support intégré dans la VM_. Quand nous en arriverons à ajouter des classes au langage, chaque classe que l'utilisateur définit n'a pas besoin de sa propre entrée dans cet enum. Pour autant que la VM soit concernée, chaque instance d'une classe est du même type : "instance".

En d'autres termes, c'est la notion de "type" de la VM, pas celle de l'utilisateur.

</aside>

Pour l'instant, nous avons seulement une couple de cas, mais cela grandira alors que nous ajouterons les chaînes, fonctions, et classes à clox. En plus du type, nous avons aussi besoin de stocker les données pour la valeur -- le `double` pour un nombre, `true` ou `false` pour un Booléen. Nous pourrions définir une struct avec des champs pour chaque type possible.

<img src="image/types-of-values/struct.png" alt="Une struct avec deux champs posés l'un à côté de l'autre en mémoire." />

Mais c'est un gaspillage de mémoire. Une valeur ne peut pas être simultanément à la fois un nombre et un Booléen. Donc à n'importe quel point dans le temps, seulement un de ces champs sera utilisé. C vous laisse optimiser cela en définissant une <span name="sum">union</span>. Une union ressemble à une struct sauf que tous ses champs se chevauchent en mémoire.

<aside name="sum">

Si vous êtes familier avec un langage dans la famille ML, les structs et unions en C reflètent grossièrement la différence entre types produits et types sommes, entre tuples et types de données algébriques.

</aside>

<img src="image/types-of-values/union.png" alt="Une union avec deux champs se chevauchant en mémoire." />

La taille d'une union est la taille de son plus grand champ. Puisque les champs réutilisent tous les mêmes bits, vous devez être très prudent quand vous travaillez avec eux. Si vous stockez des données en utilisant un champ et qu'ensuite vous y accédez en utilisant un <span name="reinterpret">autre</span>, vous réinterpréterez ce que les bits sous-jacents signifient.

<aside name="reinterpret">

Utiliser une union pour interpréter des bits comme différents types est la quintessence du C. Cela ouvre un nombre d'optimisations intelligentes et vous laisse couper et désosser chaque octet de mémoire de façons que les langages à mémoire sûre interdisent. Mais c'est aussi sauvagement peu sûr et sciera joyeusement vos doigts si vous ne faites pas attention.

</aside>

Comme le nom "union étiquetée" l'implique, notre nouvelle représentation de valeur combine ces deux parties en une struct unique.

^code value (2 before, 2 after)

Il y a un champ pour l'étiquette de type, et ensuite un second champ contenant l'union de toutes les valeurs sous-jacentes. Sur une machine 64-bit avec un compilateur C typique, la disposition ressemble à ceci :

<aside name="as">

Un hacker de langage intelligent m'a donné l'idée d'utiliser "as" pour le nom du champ union parce que cela se lit joliment, presque comme un cast, quand vous tirez les diverses valeurs hors de là.

</aside>

<img src="image/types-of-values/value.png" alt="La struct value complète, avec les champs type et as l'un à côté de l'autre en mémoire." />

L'étiquette de type de quatre octets vient en premier, ensuite l'union. La plupart des architectures préfèrent que les valeurs soient alignées à leur taille. Puisque le champ union contient un double de huit octets, le compilateur ajoute quatre octets de <span name="pad">remplissage</span> (padding) après le champ type pour garder ce double sur la frontière de huit octets la plus proche. Cela signifie que nous dépensons effectivement huit octets sur l'étiquette de type, qui a seulement besoin de représenter un nombre entre zéro et trois. Nous pourrions bourrer l'enum dans une taille plus petite, mais tout ce que ça ferait serait d'augmenter le remplissage.

<aside name="pad">

Nous pourrions déplacer le champ d'étiquette _après_ l'union, mais cela n'aide pas beaucoup non plus. Chaque fois que nous créons un tableau de Values -- ce qui est où la plupart de notre utilisation mémoire pour les Values sera -- le compilateur C insérera ce même remplissage _entre_ chaque Value pour garder les doubles alignés.

</aside>

Donc nos Values font 16 octets, ce qui semble un peu grand. Nous améliorerons cela [plus tard][optimization]. En attendant, elles sont toujours assez petites pour stocker sur la pile C et passer par valeur. La sémantique de Lox permet cela parce que les seuls types que nous supportons jusqu'ici sont **immuables**. Si nous passons une copie d'une Value contenant le nombre trois à quelque fonction, nous n'avons pas besoin de nous inquiéter que l'appelant voie des modifications à la valeur. Vous ne pouvez pas "modifier" trois. C'est trois pour toujours.

[optimization]: optimisation.html

## Valeurs Lox et Valeurs C

C'est notre nouvelle représentation de valeur, mais nous n'avons pas fini. Pour l'instant, le reste de clox suppose que Value est un alias pour `double`. Nous avons du code qui fait un cast C direct de l'un à l'autre. Ce code est tout cassé maintenant. Si triste.

Avec notre nouvelle représentation, une Value peut _contenir_ un double, mais elle n'est pas _équivalente_ à lui. Il y a une étape de conversion obligatoire pour aller de l'un à l'autre. Nous devons passer à travers le code et insérer ces conversions pour faire marcher clox de nouveau.

Nous implémenterons ces conversions comme une poignée de macros, une pour chaque type et opération. D'abord, pour promouvoir une valeur C native en une Value clox :

^code value-macros (1 before, 2 after)

Chacune de celles-ci prend une valeur C du type approprié et produit une Value qui a la bonne étiquette de type et contient la valeur sous-jacente. Ceci hisse les valeurs typées statiquement vers l'univers typé dynamiquement de clox. Afin de _faire_ quoi que ce soit avec une Value, cependant, nous avons besoin de la dépaqueter et d'obtenir la valeur C en retour.

^code as-macros (1 before, 2 after)

<aside name="as-null">

Il n'y a pas de macro `AS_NIL` parce qu'il n'y a qu'une seule valeur `nil`, donc une Value avec le type `VAL_NIL` ne porte aucune donnée supplémentaire.

</aside>

<span name="as-null">Ces</span> macros vont dans la direction opposée. Étant donné une Value du bon type, elles la déballent et renvoient la valeur C brute correspondante. La partie "bon type" est importante ! Ces macros accèdent directement aux champs de l'union. Si nous devions faire quelque chose comme :

```c
Value value = BOOL_VAL(true);
double number = AS_NUMBER(value);
```

Alors nous pourrions ouvrir un portail fumant vers le Royaume des Ombres. Ce n'est pas sûr d'utiliser n'importe laquelle des macros `AS_` à moins que nous sachions que la Value contient le type approprié. À cette fin, nous définissons quelques dernières macros pour vérifier le type d'une Value.

^code is-macros (1 before, 2 after)

<span name="universe">Ces</span> macros renvoient `true` si la Value a ce type. Chaque fois que nous appelons une des macros `AS_`, nous avons besoin de la garder derrière un appel à une de celles-ci d'abord. Avec ces huit macros, nous pouvons maintenant navetter les données en toute sécurité entre le monde dynamique de Lox et celui statique de C.

<aside name="universe">

<img src="image/types-of-values/universe.png" alt="Le firmament C terrestre avec les cieux Lox au-dessus." />

Les macros `_VAL` lèvent une valeur C dans les cieux. Les macros `AS_` la ramènent en bas.

</aside>

## Nombres Typés Dynamiquement

Nous avons notre représentation de valeur et les outils pour convertir vers et depuis elle. Tout ce qui reste pour faire tourner clox de nouveau est de piocher à travers le code et de fixer chaque endroit où les données bougent à travers cette frontière. C'est une de ces sections du livre qui n'est pas exactement époustouflante, mais j'ai promis que je vous montrerais chaque ligne de code unique, donc nous y voici.

Les premières valeurs que nous créons sont les constantes générées quand nous compilons les littéraux nombre. Après avoir converti le lexème en un double C, nous l'enveloppons simplement dans une Value avant de le stocker dans la table de constantes.

^code const-number-val (1 before, 1 after)

Là-bas dans le runtime, nous avons une fonction pour imprimer les valeurs.

^code print-number-value (1 before, 1 after)

Juste avant que nous envoyions la Value à `printf()`, nous la déballons et extrayons la valeur double. Nous revisiterons cette fonction sous peu pour ajouter les autres types, mais faisons marcher notre code existant d'abord.

### Négation unaire et erreurs d'exécution

La prochaine opération la plus simple est la négation unaire. Elle dépile une valeur, la nie, et pousse le résultat. Maintenant que nous avons d'autres types de valeurs (ou que nous en aurons bientôt), nous ne pouvons plus supposer que l'opérande est un nombre. L'utilisateur pourrait tout aussi bien faire :

```lox
print -false; // Euh...
```

Nous avons besoin de gérer cela avec grâce, ce qui signifie qu'il est temps pour les _erreurs d'exécution_. Avant d'effectuer une opération qui exige un certain type, nous avons besoin de nous assurer que la Value _est_ de ce type.

Pour la négation unaire, la vérification ressemble à ceci :

^code op-negate (1 before, 1 after)

D'abord, nous vérifions pour voir si la Value au sommet de la pile est un nombre. Si ce n'est pas le cas, nous rapportons l'erreur d'exécution et <span name="halt">arrêtons</span> l'interpréteur. Sinon, nous continuons. Seulement après cette validation nous déballons l'opérande, le nions, emballons le résultat et le poussons.

<aside name="halt">

L'approche de Lox pour la gestion d'erreur est plutôt... _austère_. Toutes les erreurs sont fatales et arrêtent immédiatement l'interpréteur. Il n'y a aucun moyen pour le code utilisateur de récupérer d'une erreur. Si Lox était un vrai langage, ce serait une des premières choses que je remédierais.

</aside>

Pour accéder à la Value, nous utilisons une nouvelle petite fonction.

^code peek

Elle renvoie une Value depuis la pile mais ne la <span name="peek">dépile</span> pas. L'argument `distance` est à quelle distance du sommet de la pile regarder : zéro est le sommet, un est un emplacement en dessous, etc.

<aside name="peek">

Pourquoi ne pas juste dépiler l'opérande et ensuite le valider ? Nous pourrions faire ça. Dans les chapitres ultérieurs, il sera important de laisser les opérandes sur la pile pour assurer que le ramasse-miettes peut les trouver si une collection est déclenchée au milieu de l'opération. Je fais la même chose ici surtout par habitude.

</aside>

Nous rapportons l'erreur d'exécution en utilisant une nouvelle fonction dont nous tirerons beaucoup de profit sur le reste du livre.

^code runtime-error

Vous avez certainement _appelé_ des fonctions variadiques -- celles qui prennent un nombre variable d'arguments -- en C avant : `printf()` en est une. Mais vous pourriez ne pas avoir _défini_ la vôtre. Ce livre n'est pas un <span name="tutorial">tutoriel</span> C, donc je vais survoler ça ici, mais basiquement le trucs `...` et `va_list` nous laisse passer un nombre arbitraire d'arguments à `runtimeError()`. Elle transfère ceux-là à `vfprintf()`, qui est la saveur de `printf()` qui prend une `va_list` explicite.

<aside name="tutorial">

Si vous cherchez un tutoriel C, j'adore _[Le Langage de Programmation C][kr]_, habituellement appelé "K&R" en l'honneur de ses auteurs. Il n'est pas entièrement à jour, mais la qualité de l'écriture fait plus que compenser cela.

[kr]: https://www.cs.princeton.edu/~bwk/cbook.html

</aside>

Les appelants peuvent passer une chaîne de format à `runtimeError()` suivie par un nombre d'arguments, juste comme ils peuvent quand ils appellent `printf()` directement. `runtimeError()` formate et imprime ensuite ces arguments. Nous ne prendrons pas avantage de cela dans ce chapitre, mais les chapitres plus tardifs produiront des messages d'erreur d'exécution formatés qui contiennent d'autres données.

Après avoir montré le message d'erreur espérons-le utile, nous disons à l'utilisateur quelle <span name="stack">ligne</span> de leur code était exécutée quand l'erreur s'est produite. Puisque nous avons laissé les tokens derrière dans le compilateur, nous cherchons la ligne dans l'information de débogage compilée dans le morceau. Si notre compilateur a fait son travail correctement, cela correspond à la ligne de code source à partir de laquelle le bytecode a été compilé.

Nous regardons dans le tableau de lignes de débogage du morceau en utilisant l'index d'instruction bytecode courant _moins un_. C'est parce que l'interpréteur avance au-delà de chaque instruction avant de l'exécuter. Donc, au point où nous appelons `runtimeError()`, l'instruction échouée est la précédente.

<aside name="stack">

Juste montrer la ligne immédiate où l'erreur s'est produite ne fournit pas beaucoup de contexte. Mieux serait une trace de pile complète. Mais nous n'avons même pas de fonction à appeler encore, donc il n'y a pas de pile d'appels à tracer.

</aside>

Afin d'utiliser `va_list` et les macros pour travailler avec elle, nous avons besoin d'apporter un en-tête standard.

^code include-stdarg (1 after)

Avec ceci, notre VM peut non seulement faire la bonne chose quand nous nions des nombres (comme elle le faisait avant que nous la cassions), mais elle gère aussi avec grâce les tentatives erronées de nier d'autres types (que nous n'avons pas encore, mais quand même).

### Opérateurs arithmétiques binaires

Nous avons notre machinerie d'erreur d'exécution en place maintenant, donc réparer les opérateurs binaires est plus facile même s'ils sont plus complexes. Nous supportons quatre opérateurs binaires aujourd'hui : `+`, `-`, `*`, et `/`. La seule différence entre eux est quel opérateur C sous-jacent ils utilisent. Pour minimiser le code redondant entre les quatre opérateurs, nous avons emballé la communalité dans une grosse macro préprocesseur qui prend le token opérateur comme paramètre.

Cette macro semblait un peu excessive il y a [quelques chapitres][few chapters ago], mais nous tirons profit d'elle aujourd'hui. Elle nous laisse ajouter la vérification de type et les conversions nécessaires en un seul endroit.

[few chapters ago]: machine-virtuelle.html#opérateurs-binaires

^code binary-op (1 before, 2 after)

Ouais, je réalise que c'est un monstre de macro. Ce n'est pas ce que je considérerais normalement comme une bonne pratique C, mais roulons avec. Les changements sont similaires à ce que nous avons fait pour la négation unaire. D'abord, nous vérifions que les deux opérandes sont tous deux des nombres. Si l'un ou l'autre ne l'est pas, nous rapportons une erreur d'exécution et tirons le levier du siège éjectable.

Si les opérandes sont bons, nous les dépilons tous les deux et les déballons. Ensuite nous appliquons l'opérateur donné, emballons le résultat, et le repoussons sur la pile. Notez que nous n'emballons pas le résultat en utilisant directement `NUMBER_VAL()`. Au lieu de cela, l'emballeur à utiliser est passé comme un <span name="macro">paramètre</span> macro. Pour nos opérateurs arithmétiques existants, le résultat est un nombre, donc nous passons la macro `NUMBER_VAL`.

<aside name="macro">

Saviez-vous que vous pouvez passer des macros comme paramètres à des macros ? Maintenant vous savez !

</aside>

^code op-arithmetic (1 before, 1 after)

Bientôt, je vous montrerai pourquoi nous avons fait de la macro d'emballage un argument.

## Deux Nouveaux Types

Tout notre code clox existant est de retour en état de marche. Finalement, il est temps d'ajouter de nouveaux types. Nous avons une calculatrice numérique tournante qui fait maintenant un certain nombre de vérifications de type à l'exécution paranoïaques et sans objet. Nous pouvons représenter d'autres types en interne, mais il n'y a aucun moyen pour un programme utilisateur de jamais créer une Value d'un de ces types.

Pas jusqu'à maintenant, c'est-à-dire. Nous commencerons par ajouter le support du compilateur pour les trois nouveaux littéraux : `true`, `false`, et `nil`. Ils sont tous assez simples, donc nous ferons tous les trois dans un seul lot.

Avec les littéraux nombre, nous avons dû gérer le fait qu'il y a des milliards de valeurs numériques possibles. Nous nous sommes occupés de cela en stockant la valeur du littéral dans la table de constantes du morceau et en émettant une instruction bytecode qui chargeait simplement cette constante. Nous pourrions faire la même chose pour les nouveaux types. Nous stockerions, disons, `true`, dans la table de constantes, et utiliserions un `OP_CONSTANT` pour le lire.

Mais étant donné qu'il y a littéralement (hé) seulement trois valeurs possibles dont nous avons besoin de nous inquiéter avec ces nouveaux types, c'est gratuit -- et <span name="small">lent !</span> -- de gaspiller une instruction de deux octets et une entrée de table de constantes pour eux. Au lieu de cela, nous définirons trois instructions dédiées pour pousser chacun de ces littéraux sur la pile.

<aside name="small" class="bottom">

Je ne plaisante pas à propos des opérations dédiées pour certaines valeurs constantes qui sont plus rapides. Une VM à bytecode passe beaucoup de son temps d'exécution à lire et décoder des instructions. Moins vous avez besoin d'instructions, et plus elles sont simples pour un comportement donné, plus ça va vite. Les instructions courtes dédiées aux opérations communes sont une optimisation classique.

Par exemple, le jeu d'instructions bytecode Java a des instructions dédiées pour charger 0.0, 1.0, 2.0, et les valeurs entières de -1 à 5. (Cela finit par être une optimisation vestigiale étant donné que la plupart des JVMs matures compilent maintenant à la volée (JIT) le bytecode en code machine avant l'exécution de toute façon.)

</aside>

^code literal-ops (1 before, 1 after)

Notre scanner traite déjà `true`, `false`, et `nil` comme des mots-clés, donc nous pouvons sauter directement au parseur. Avec notre parseur Pratt basé sur table, nous avons juste besoin d'insérer des fonctions de parseur dans les lignes associées avec ces types de token mot-clé. Nous utiliserons la même fonction dans les trois emplacements. Ici :

^code table-false (1 before, 1 after)

Ici :

^code table-true (1 before, 1 after)

Et ici :

^code table-nil (1 before, 1 after)

Quand le parseur rencontre `false`, `nil`, ou `true`, en position préfixe, il appelle cette nouvelle fonction de parseur :

^code parse-literal

Puisque `parsePrecedence()` a déjà consommé le token mot-clé, tout ce que nous avons besoin de faire est de sortir l'instruction appropriée. Nous <span name="switch">déterminons</span> celle-ci basé sur le type de token que nous avons parsé. Notre front end peut maintenant compiler les littéraux Booléens et nil en bytecode. En descendant le pipeline d'exécution, nous atteignons l'interpréteur.

<aside name="switch">

Nous aurions pu utiliser des fonctions de parseur séparées pour chaque littéral et nous épargner un switch mais cela me semblait inutilement verbeux. Je pense que c'est surtout une question de goût.

</aside>

^code interpret-literals (5 before, 1 after)

C'est assez auto-explicatif. Chaque instruction invoque la valeur appropriée et la pousse sur la pile. Nous ne devrions pas oublier notre désassembleur non plus.

^code disassemble-literals (2 before, 1 after)

Avec ceci en place, nous pouvons lancer ce programme bouleversant :

```lox
true
```

Sauf que quand l'interpréteur essaie d'imprimer le résultat, il explose. Nous avons besoin d'étendre `printValue()` pour gérer aussi les nouveaux types :

^code print-value (1 before, 1 after)

Et voilà ! Maintenant nous avons de nouveaux types. Ils ne sont juste pas encore très utiles. À part les littéraux, vous ne pouvez pas vraiment _faire_ quoi que ce soit avec eux. Il se passera un moment avant que `nil` entre en jeu, mais nous pouvons commencer à mettre les Booléens au travail dans les opérateurs logiques.

### Non logique et fausseté

L'opérateur logique le plus simple est notre vieil ami exclamatif non unaire.

```lox
print !true; // "false"
```

Cette nouvelle opération obtient une nouvelle instruction.

^code not-op (1 before, 1 after)

Nous pouvons réutiliser la fonction de parseur `unary()` que nous avons écrite pour la négation unaire pour compiler une expression non. Nous avons juste besoin de l'insérer dans la table de parsing.

^code table-not (1 before, 1 after)

Parce que je savais que nous allions faire ceci, la fonction `unary()` a déjà un switch sur le type de token pour déterminer quelle instruction bytecode sortir. Nous ajoutons simplement un autre cas.

^code compile-not (1 before, 3 after)

C'est tout pour le front end. Allons vers la VM et conjurons cette instruction à la vie.

^code op-not (1 before, 1 after)

Comme notre opérateur unaire précédent, il dépile l'unique opérande, effectue l'opération, et pousse le résultat. Et, comme nous l'avons fait là, nous devons nous inquiéter du typage dynamique. Prendre le non logique de `true` est facile, mais il n'y a rien empêchant un programmeur indiscipliné d'écrire quelque chose comme ceci :

```lox
print !nil;
```

Pour le moins unaire, nous avons fait une erreur de nier tout ce qui n'est pas un <span name="negate">nombre</span>. Mais Lox, comme la plupart des langages de script, est plus permissif quand il s'agit de `!` et d'autres contextes où un Booléen est attendu. La règle pour comment les autres types sont gérés est appelée "fausseté" (falsiness), et nous l'implémentons ici :

<aside name="negate">

Maintenant je ne peux m'empêcher d'essayer de comprendre ce que cela signifierait de nier d'autres types de valeurs. `nil` est probablement sa propre négation, une sorte de pseudo-zéro bizarre. Nier une chaîne pourrait, euh, la renverser ?

</aside>

^code is-falsey

Lox suit Ruby en ce que `nil` et `false` sont faux ("falsey") et toute autre valeur se comporte comme `true`. Nous avons une nouvelle instruction que nous pouvons générer, donc nous avons aussi besoin d'être capable de la *dé*générer dans le désassembleur.

^code disassemble-not (2 before, 1 after)

### Égalité et opérateurs de comparaison

Ce n'était pas trop mal. Gardons le momentum et assommons l'égalité et les opérateurs de comparaison aussi : `==`, `!=`, `<`, `>`, `<=`, et `>=`. Cela couvre tous les opérateurs qui renvoient des résultats Booléens excepté les opérateurs logiques `and` et `or`. Puisque ceux-là ont besoin de court-circuiter (basiquement faire un peu de contrôle de flux) nous ne sommes pas prêts pour eux encore.

Voici les nouvelles instructions pour ce opérateurs :

^code comparison-ops (1 before, 1 after)

Attendez, seulement trois ? Quoi à propos de `!=`, `<=`, et `>=` ? Nous pourrions créer des instructions pour ceux-là aussi. Honnêtement, la VM s'exécuterait plus vite si nous le faisions, donc nous _devrions_ faire ça si le but est la performance.

Mais mon but principal est de vous enseigner à propos des compilateurs bytecode. Je veux que vous commenciez à internaliser l'idée que les instructions bytecode n'ont pas besoin de suivre de près le code source de l'utilisateur. La VM a une liberté totale d'utiliser n'importe quel jeu d'instructions et séquences de code qu'elle veut tant qu'ils ont le bon comportement visible par l'utilisateur.

L'expression `a != b` a la même sémantique que `!(a == b)`, donc le compilateur est libre de compiler la première comme si c'était la seconde. Au lieu d'une instruction `OP_NOT_EQUAL` dédiée, il peut sortir un `OP_EQUAL` suivi par un `OP_NOT`. De même, `a <= b` est la <span name="same">même</span> chose que `!(a > b)` et `a >= b` est `!(a < b)`. Ainsi, nous avons seulement besoin de trois nouvelles instructions.

<aside name="same" class="bottom">

_Est-ce que_ `a <= b` est toujours la même chose que `!(a > b)` ? Selon [IEEE 754][], tous les opérateurs de comparaison renvoient faux quand un opérande est NaN. Cela signifie que `NaN <= 1` est faux et `NaN > 1` est aussi faux. Mais notre désucrage suppose que ce dernier est toujours la négation du premier.

Pour le livre, nous ne nous bloquerons pas là-dessus, mais ces genres de détails compteront dans vos implémentations de langage réelles.

[ieee 754]: https://en.wikipedia.org/wiki/IEEE_754

</aside>

Là-bas dans le parseur, cependant, nous avons six nouveaux opérateurs à insérer dans la table de parsing. Nous utilisons la même fonction de parseur `binary()` d'avant. Voici la ligne pour `!=` :

^code table-equal (1 before, 1 after)

Les cinq opérateurs restants sont un peu plus bas dans la table.

^code table-comparisons (1 before, 1 after)

À l'intérieur de `binary()` nous avons déjà un switch pour générer le bon bytecode pour chaque type de token. Nous ajoutons des cas pour les six nouveaux opérateurs.

^code comparison-operators (1 before, 1 after)

Les opérateurs `==`, `<`, et `>` sortent une instruction unique. Les autres sortent une paire d'instructions, une pour évaluer l'opération inverse, et ensuite un `OP_NOT` pour inverser le résultat. Six opérateurs pour le prix de trois instructions !

Cela signifie que là-bas dans la VM, notre travail est plus simple. L'égalité est l'opération la plus générale.

^code interpret-equal (1 before, 1 after)

Vous pouvez évaluer `==` sur n'importe quelle paire d'objets, même des objets de types différents. Il y a assez de complexité pour que cela ait du sens de déporter cette logique vers une fonction séparée. Cette fonction renvoie toujours un `bool` C, donc nous pouvons emballer en toute sécurité le résultat dans une `BOOL_VAL`. La fonction se rapporte aux Values, donc elle vit là-bas dans le module "value".

^code values-equal-h (2 before, 1 after)

Et voici l'implémentation :

^code values-equal

D'abord, nous vérifions les types. Si les Values ont des types <span name="equal">différents</span>, elles ne sont définitivement pas égales. Sinon, nous déballons les deux Values et les comparons directement.

<aside name="equal">

Certains langages ont des "conversions implicites" où des valeurs de types différents peuvent être considérées égales si l'une peut être convertie vers le type de l'autre. Par exemple, le nombre 0 est équivalent à la chaîne "0" en JavaScript. Ce relâchement était une source de douleur assez grande pour que JS ajoute un opérateur d'"égalité stricte" séparé, `===`.

PHP considère les chaînes "1" et "01" comme étant équivalentes parce que les deux peuvent être converties en nombres équivalents, bien que la raison ultime soit parce que PHP a été conçu par un dieu ancien lovecraftien pour détruire l'esprit.

La plupart des langages typés dynamiquement qui ont des types nombre entier et à virgule flottante séparés considèrent les valeurs de types de nombre différents égales si les valeurs numériques sont les mêmes (donc, disons, 1.0 est égal à 1), bien que même cette commodité apparemment inoffensive puisse mordre les imprudents.

</aside>

Pour chaque type de valeur, nous avons un cas séparé qui gère la comparaison de la valeur elle-même. Étant donné combien les cas sont similaires, vous pourriez vous demander pourquoi nous ne pouvons pas simplement `memcmp()` les deux structs Value et en avoir fini avec ça. Le problème est qu'à cause du remplissage et des champs d'union de tailles différentes, une Value contient des bits inutilisés. C ne donne aucune garantie sur ce qui est dans ceux-ci, donc il est possible que deux Values égales diffèrent en fait dans la mémoire qui n'est pas utilisée.

<img src="image/types-of-values/memcmp.png" alt="Les représentations mémoire de deux valeurs égales qui diffèrent dans les octets inutilisés." />

(Vous ne croiriez pas combien de douleur j'ai traversée avant d'apprendre ce fait.)

Quoi qu'il en soit, alors que nous ajoutons plus de types à clox, cette fonction grandira de nouveaux cas. Pour l'instant, ces trois sont suffisants. Les autres opérateurs de comparaison sont plus faciles puisqu'ils fonctionnent seulement sur les nombres.

^code interpret-comparison (3 before, 1 after)

Nous avons déjà étendu la macro `BINARY_OP` pour gérer les opérateurs qui renvoient des types non-numériques. Maintenant nous pouvons utiliser cela. Nous passons `BOOL_VAL` puisque le type de valeur résultat est Booléen. Sinon, ce n'est pas différent de plus ou moins.

Comme toujours, la coda de l'aria d'aujourd'hui est de désassembler les nouvelles instructions.

^code disassemble-comparison (2 before, 1 after)

Avec cela, notre calculatrice numérique est devenue quelque chose de plus proche d'un évaluateur d'expressions général. Démarrez clox et tapez :

```lox
!(5 - 4 > 3 * 2 == !nil)
```

OK, j'admettrai que ce n'est peut-être pas l'expression la plus _utile_, mais nous faisons des progrès. Nous avons un type intégré manquant avec sa propre forme littérale : les chaînes. Celles-ci sont bien plus complexes parce que les chaînes peuvent varier en taille. Cette minuscule différence s'avère avoir des implications si grandes que nous donnons aux chaînes [leur propre chapitre][strings].

[strings]: chaînes-de-caractères.html

<div class="challenges">

## Défis

1. Nous pourrions réduire nos opérateurs binaires encore plus loin que nous l'avons fait ici. Quelles autres instructions pouvez-vous éliminer, et comment le compilateur se débrouillerait-il avec leur absence ?

2. Inversement, nous pouvons améliorer la vitesse de notre VM bytecode en ajoutant plus d'instructions spécifiques qui correspondent à des opérations de plus haut niveau. Quelles instructions définiriez-vous pour accélérer le genre de code utilisateur pour lequel nous avons ajouté le support dans ce chapitre ?

</div>

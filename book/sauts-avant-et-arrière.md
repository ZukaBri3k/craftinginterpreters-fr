> L'ordre que notre esprit imagine est comme un filet, ou comme une échelle, construit pour atteindre quelque chose. Mais après vous devez jeter l'échelle, parce que vous découvrez que, même si c'était utile, c'était vide de sens.
>
> <cite>Umberto Eco, <em>Le Nom de la rose</em></cite>

Cela a pris un moment pour arriver ici, mais nous sommes enfin prêts à ajouter le contrôle de flux à notre machine virtuelle. Dans l'interpréteur à parcours d'arbre que nous avons construit pour jlox, nous avons implémenté le contrôle de flux de Lox en termes de celui de Java. Pour exécuter une instruction `if` Lox, nous avons utilisé une instruction `if` Java pour exécuter la branche choisie. Cela fonctionne, mais n'est pas entièrement satisfaisant. Par quelle magie la _JVM elle-même_ ou un CPU natif implémente-t-il les instructions `if` ? Maintenant que nous avons notre propre VM à bytecode à bricoler, nous pouvons répondre à cela.

Quand nous parlons de "contrôle de flux", à quoi nous référons-nous ? Par "flux", nous voulons dire la façon dont l'exécution se déplace à travers le texte du programme. Presque comme s'il y avait un petit robot à l'intérieur de l'ordinateur errant à travers notre code, exécutant des morceaux ici et là. Le flux est le chemin que ce robot prend, et en _contrôlant_ le robot, nous pilotons quels morceaux de code il exécute.

Dans jlox, le lieu d'attention du robot -- le morceau de code _courant_ -- était implicite basé sur quels nœuds AST étaient stockés dans diverses variables Java et quel code Java nous étions au milieu d'exécuter. Dans clox, c'est beaucoup plus explicite. Le champ `ip` de la VM stocke l'adresse de l'instruction bytecode courante. La valeur de ce champ est exactement "où nous sommes" dans le programme.

L'exécution procède normalement en incrémentant le `ip`. Mais nous pouvons muter cette variable comme nous voulons. Afin d'implémenter le contrôle de flux, tout ce qui est nécessaire est de changer le `ip` de façons plus intéressantes. La construction de contrôle de flux la plus simple est une instruction `if` sans clause `else` :

```lox
if (condition) print("condition was truthy");
```

La VM évalue le bytecode pour l'expression de condition. Si le résultat est "truthy" (vrai), alors elle continue et exécute l'instruction `print` dans le corps. Le cas intéressant est quand la condition est "falsey" (fausse). Quand cela arrive, l'exécution saute par-dessus la branche alors et procède à l'instruction suivante.

Pour sauter par-dessus un morceau de code, nous réglons simplement le champ `ip` à l'adresse de l'instruction bytecode suivant ce code. Pour sauter _conditionnellement_ par-dessus du code, nous avons besoin d'une instruction qui regarde la valeur au sommet de la pile. Si elle est fausse, elle ajoute un décalage donné au `ip` pour sauter par-dessus une plage d'instructions. Sinon, elle ne fait rien et laisse l'exécution procéder à l'instruction suivante comme d'habitude.

Quand nous compilons vers du bytecode, la structure de bloc imbriquée explicite du code s'évapore, laissant seulement une série plate d'instructions derrière. Lox est un langage de [programmation structurée][structured programming], mais le bytecode clox ne l'est pas. Le bon -- ou mauvais, dépendant de comment vous le regardez -- ensemble d'instructions bytecode pourrait sauter au milieu d'un bloc, ou d'une portée dans une autre.

La VM exécutera joyeusement cela, même si le résultat laisse la pile dans un état inconnu, incohérent. Donc même si le bytecode est non structuré, nous prendrons soin de nous assurer que notre compilateur génère seulement du code propre qui maintient la même structure et imbrication que Lox lui-même fait.

C'est exactement comment les vrais CPUs se comportent. Même si nous pourrions les programmer utilisant des langages de plus haut niveau qui mandatent un contrôle de flux structuré, le compilateur abaisse cela à des sauts bruts. Au fond, il s'avère que le goto est le seul vrai contrôle de flux.

[structured programming]: https://fr.wikipedia.org/wiki/Programmation_structur%C3%A9e

De toute façon, je ne voulais pas devenir tout philosophique. Le morceau important est que si nous avons cette instruction de saut conditionnel, c'est assez pour implémenter l'instruction `if` de Lox, tant qu'elle n'a pas de clause `else`. Donc allons de l'avant et commençons avec cela.

## Instructions If

Autant de chapitres dedans, vous connaissez la routine. Toute nouvelle fonctionnalité commence dans le front end et travaille son chemin à travers le pipeline. Une instruction `if` est, eh bien, une instruction, donc c'est là où nous l'accrochons dans l'analyseur.

^code parse-if (2 before, 1 after)

Quand nous voyons un mot-clé `if`, nous passons la main de la compilation à cette fonction :

^code if-statement

<aside name="paren">

Avez-vous déjà remarqué que la `(` après le mot-clé `if` ne fait pas réellement quelque chose d'utile ? Le langage serait tout aussi non ambigu et facile à analyser sans elle, comme :

```lox
if condition) print("looks weird");
```

La `)` fermante est utile parce qu'elle sépare l'expression de condition du corps. Certains langages utilisent un mot-clé `then` à la place. Mais la `(` ouvrante ne fait rien. Elle est juste là parce que les parenthèses non appariées semblent mauvaises pour nous humains.

</aside>

D'abord nous compilons l'expression de condition, encadrée par des parenthèses. À l'exécution, cela laissera la valeur de condition au sommet de la pile. Nous utiliserons cela pour déterminer s'il faut exécuter la branche alors ou la sauter.

Ensuite nous émettons une nouvelle instruction `OP_JUMP_IF_FALSE`. Elle a un opérande pour combien décaler le `ip` -- combien d'octets de code sauter. Si la condition est fausse, elle ajuste le `ip` par ce montant. Quelque chose comme ceci :

<aside name="legend">

Les boîtes avec les bords déchirés ici représentent le blob de bytecode généré en compilant quelque sous-clause d'une construction de contrôle de flux. Donc la boîte "expression de condition" est toutes les instructions émises quand nous avons compilé cette expression.

</aside>

<span name="legend"></span>

<img src="image/jumping-back-and-forth/if-without-else.png" alt="Organigramme du bytecode compilé d'une instruction if." />

Mais nous avons un problème. Quand nous écrivons l'opérande de l'instruction `OP_JUMP_IF_FALSE`, comment savons-nous jusqu'où sauter ? Nous n'avons pas compilé la branche alors encore, donc nous ne savons pas combien de bytecode elle contient.

Pour réparer cela, nous utilisons un truc classique appelé **backpatching** (rétro-apiéçage). Nous émettons l'instruction de saut d'abord avec un opérande de décalage bouche-trou. Nous gardons la trace d'où est cette instruction à moitié finie. Ensuite, nous compilons le corps alors. Une fois que c'est fait, nous savons jusqu'où sauter. Donc nous retournons en arrière et remplaçons ce décalage bouche-trou avec le vrai maintenant que nous pouvons le calculer. Sorte de comme coudre une pièce sur le tissu existant du code compilé.

<img src="image/jumping-back-and-forth/patch.png" alt="Une pièce contenant un nombre étant cousue sur une feuille de bytecode." />

Nous encodons ce truc dans deux fonctions d'aide.

^code emit-jump

La première émet une instruction bytecode et écrit un opérande bouche-trou pour le décalage de saut. Nous passons l'opcode comme un argument parce que plus tard nous aurons deux instructions différentes qui utilisent cet assistant. Nous utilisons deux octets pour l'opérande de décalage de saut. Un <span name="offset">décalage</span> de 16-bits nous laisse sauter par-dessus jusqu'à 65 535 octets de code, ce qui devrait être plein pour nos besoins.

<aside name="offset">

Certains jeux d'instructions ont des instructions de saut "long" séparées qui prennent de plus grands opérandes pour quand vous avez besoin de sauter une plus grande distance.

</aside>

La fonction renvoie le décalage de l'instruction émise dans le chunk. Après avoir compilé la branche alors, nous prenons ce décalage et le passons à ceci :

^code patch-jump

Ceci retourne dans le bytecode et remplace l'opérande à l'emplacement donné avec le décalage de saut calculé. Nous appelons `patchJump()` juste avant d'émettre l'instruction suivante sur laquelle nous voulons que le saut atterrisse, donc il utilise le compte de bytecode courant pour déterminer jusqu'où sauter. Dans le cas d'une instruction `if`, cela signifie juste après que nous compilons la branche alors et avant que nous compilions l'instruction suivante.

C'est tout ce dont nous avons besoin au moment de la compilation. Définissons la nouvelle instruction.

^code jump-if-false-op (1 before, 1 after)

Là-bas dans la VM, nous la faisons fonctionner comme ceci :

^code op-jump-if-false (2 before, 1 after)

C'est la première instruction que nous avons ajoutée qui prend un opérande de 16-bits. Pour lire cela depuis le chunk, nous utilisons une nouvelle macro.

^code read-short (1 before, 1 after)

Elle tire les deux prochains octets du chunk et construit un entier non signé de 16-bits hors d'eux. Comme d'habitude, nous nettoyons notre macro quand nous en avons fini avec elle.

^code undef-read-short (1 before, 1 after)

Après avoir lu le décalage, nous vérifions la valeur de condition au sommet de la pile. <span name="if">Si</span> elle est fausse, nous appliquons ce décalage de saut au `ip`. Sinon, nous laissons le `ip` seul et l'exécution procédera automatiquement à l'instruction suivante suivant l'instruction de saut.

Dans le cas où la condition est fausse, nous n'avons pas besoin de faire d'autre travail. Nous avons décalé le `ip`, donc quand la boucle de répartition d'instruction extérieure tourne encore, elle reprendra l'exécution à cette nouvelle instruction, passé tout le code dans la branche alors.

<aside name="if">

J'ai dit que nous n'utiliserions pas l'instruction `if` du C pour implémenter le contrôle de flux de Lox, mais nous en utilisons bien une ici pour déterminer si oui ou non décaler le pointeur d'instruction. Mais nous n'utilisons pas vraiment le C pour le _contrôle de flux_. Si nous voulions, nous pourrions faire la même chose purement arithmétiquement. Supposons que nous avons une fonction `falsey()` qui prend une Value Lox et renvoie 1 si elle est fausse ou 0 sinon. Alors nous pourrions implémenter l'instruction de saut comme :

```c
case OP_JUMP_IF_FALSE: {
  uint16_t offset = READ_SHORT();
  vm.ip += falsey() * offset;
  break;
}
```

La fonction `falsey()` utiliserait probablement quelque contrôle de flux pour gérer les différents types de valeur, mais c'est un détail d'implémentation de cette fonction et n'affecte pas comment notre VM fait son propre contrôle de flux.

</aside>

Notez que l'instruction de saut ne dépile pas la valeur de condition de la pile. Donc nous n'avons pas totalement fini ici, puisque cela laisse une valeur supplémentaire flottant sur la pile. Nous nettoierons cela bientôt. Ignorant cela pour le moment, nous avons bien une instruction `if` fonctionnelle dans Lox maintenant, avec seulement une petite instruction requise pour la supporter à l'exécution dans la VM.

### Clauses Else

Une instruction `if` sans support pour les clauses `else` est comme Morticia Addams sans Gomez. Donc, après avoir compilé la branche alors, nous cherchons un mot-clé `else`. Si nous en trouvons un, nous compilons la branche sinon.

^code compile-else (1 before, 1 after)

Quand la condition est fausse, nous sauterons par-dessus la branche alors. S'il y a une branche sinon, le `ip` atterrira juste au début de son code. Mais ce n'est pas suffisant, cependant. Voici le flux auquel cela mène :

<img src="image/jumping-back-and-forth/bad-else.png" alt="Organigramme du bytecode compilé avec la branche alors tombant incorrectement à travers vers la branche sinon." />

Si la condition est vraie, nous exécutons la branche alors comme nous voulons. Mais après cela, l'exécution roule droit à travers dans la branche sinon. Oups ! Quand la condition est vraie, après avoir exécuté la branche alors, nous avons besoin de sauter par-dessus la branche sinon. De cette façon, dans l'un ou l'autre cas, nous exécutons seulement une seule branche, comme ceci :

<img src="image/jumping-back-and-forth/if-else.png" alt="Organigramme du bytecode compilé pour un if avec une clause else." />

Pour implémenter cela, nous avons besoin d'un autre saut depuis la fin de la branche alors.

^code jump-over-else (2 before, 1 after)

Nous patchons ce décalage après la fin du corps du sinon.

^code patch-else (1 before, 1 after)

Après l'exécution de la branche alors, ceci saute à l'instruction suivante après la branche sinon. Contrairement à l'autre saut, ce saut est inconditionnel. Nous le prenons toujours, donc nous avons besoin d'une autre instruction qui exprime cela.

^code jump-op (1 before, 1 after)

Nous l'interprétons comme ceci :

^code op-jump (2 before, 1 after)

Rien de trop surprenant ici -- la seule différence est qu'elle ne vérifie pas une condition et applique toujours le décalage.

Nous avons les branches alors et sinon fonctionnant maintenant, donc nous sommes proches. Le dernier morceau est de nettoyer cette valeur de condition que nous avons laissée sur la pile. Rappelez-vous, chaque instruction est requise d'avoir un effet de pile nul -- après que l'instruction est finie d'exécuter, la pile devrait être aussi haute qu'elle l'était avant.

Nous pourrions faire que l'instruction `OP_JUMP_IF_FALSE` dépile la condition elle-même, mais bientôt nous utiliserons cette même instruction pour les opérateurs logiques où nous ne voulons pas que la condition soit dépilée. Au lieu de cela, nous ferons que le compilateur émette une couple d'instructions `OP_POP` explicites lors de la compilation d'une instruction `if`. Nous avons besoin de prendre soin que chaque chemin d'exécution à travers le code généré dépile la condition.

Quand la condition est vraie, nous la dépilons juste avant le code à l'intérieur de la branche alors.

^code pop-then (1 before, 1 after)

Sinon, nous la dépilons au début de la branche sinon.

^code pop-end (1 before, 2 after)

Cette petite instruction ici signifie aussi que chaque instruction `if` a une branche sinon implicite même si l'utilisateur n'a pas écrit une clause `else`. Dans le cas où ils l'ont laissée de côté, tout ce que la branche fait est de jeter la valeur de condition.

Le flux correct complet ressemble à ceci :

<img src="image/jumping-back-and-forth/full-if-else.png" alt="Organigramme du bytecode compilé incluant les instructions pop nécessaires." />

Si vous tracez à travers, vous pouvez voir qu'il exécute toujours une seule branche et assure que la condition est dépilée d'abord. Tout ce qui reste est un peu de support de désassembleur.

^code disassemble-jump (1 before, 1 after)

Ces deux instructions ont un nouveau format avec un opérande de 16-bits, donc nous ajoutons une nouvelle fonction utilitaire pour les désassembler.

^code jump-instruction

Et voilà, c'est une construction de contrôle de flux complète. Si c'était un film des années 80, la musique de montage démarrerait et le reste de la syntaxe de contrôle de flux prendrait soin de lui-même. Hélas, les <span name="80s">années 80</span> sont depuis longtemps finies, donc nous aurons à le broyer nous-mêmes.

<aside name="80s">

Mon amour durable de Depeche Mode nonobstant.

</aside>
## Opérateurs Logiques

Vous vous souvenez probablement de cela de jlox, mais les opérateurs logiques `and` et `or` ne sont pas juste une autre paire d'opérateurs binaires comme `+` et `-`. Parce qu'ils court-circuitent et peuvent ne pas évaluer leur opérande droit dépendant de la valeur de celui de gauche, ils fonctionnent plus comme des expressions de contrôle de flux.

Ils sont fondamentalement une petite variation sur une instruction `if` avec une clause `else`. La façon la plus facile de les expliquer est de juste vous montrer le code du compilateur et le contrôle de flux qu'il produit dans le bytecode résultant. Commençant avec `and`, nous l'accrochons dans la table d'analyse d'expression ici :

^code table-and (1 before, 1 after)

Cela passe la main à une nouvelle fonction d'analyseur.

^code and

Au point que ceci est appelé, l'expression du côté gauche a déjà été compilée. Cela signifie qu'à l'exécution, sa valeur sera au sommet de la pile. Si cette valeur est fausse, alors nous savons que le `and` entier doit être faux, donc nous sautons l'opérande droit et laissons la valeur du côté gauche comme le résultat de l'expression entière. Sinon, nous jetons la valeur de gauche et évaluons l'opérande droit qui devient le résultat du `and` entier.

Ces quatre lignes de code juste là produisent exactement cela. Le flux ressemble à ceci :

<img src="image/jumping-back-and-forth/and.png" alt="Organigramme du bytecode compilé d'une expression 'and'." />

Maintenant vous pouvez voir pourquoi `OP_JUMP_IF_FALSE` <span name="instr">laisse</span> la valeur au sommet de la pile. Quand le côté gauche du `and` est faux, cette valeur traîne pour devenir le résultat de l'expression entière.

<aside name="instr">

Nous avons plein d'espace laissé dans notre plage d'opcode, donc nous pourrions avoir des instructions séparées pour les sauts conditionnels qui dépilent implicitement et ceux qui ne le font pas, je suppose. Mais j'essaie de garder les choses minimales pour le livre. Dans votre VM à bytecode, cela vaut la peine d'explorer l'ajout d'instructions plus spécialisées et voir comment elles affectent la performance.

</aside>

### Opérateur logique or

L'opérateur `or` est un peu plus complexe. D'abord nous l'ajoutons à la table d'analyse.

^code table-or (1 before, 1 after)

Quand cet analyseur consomme un jeton infixe `or`, il appelle ceci :

^code or

Dans une expression `or`, si le côté gauche est _vrai_, alors nous sautons par-dessus l'opérande droit. Ainsi nous avons besoin de sauter quand une valeur est vraie. Nous pourrions ajouter une instruction séparée, mais juste pour montrer comment notre compilateur est libre de mapper la sémantique du langage à n'importe quelle séquence d'instruction qu'il veut, je l'ai implémenté en termes des instructions de saut que nous avons déjà.

Quand le côté gauche est faux, il fait un minuscule saut par-dessus l'instruction suivante. Cette instruction est un saut inconditionnel par-dessus le code pour l'opérande droit. Cette petite danse fait effectivement un saut quand la valeur est vraie. Le flux ressemble à ceci :

<img src="image/jumping-back-and-forth/or.png" alt="Organigramme du bytecode compilé d'une expression logique or." />

Si je suis honnête avec vous, ce n'est pas la meilleure façon de faire cela. Il y a plus d'instructions à répartir et plus de surcoût. Il n'y a aucune bonne raison pourquoi `or` devrait être plus lent que `and`. Mais c'est une sorte d'amusement de voir qu'il est possible d'implémenter les deux opérateurs sans ajouter aucune nouvelle instruction. Pardonnez-moi mes indulgences.

OK, ce sont les trois constructions de _branchement_ dans Lox. Par là, je veux dire, ce sont les fonctionnalités de contrôle de flux qui sautent seulement en _avant_ par-dessus du code. D'autres langages ont souvent quelque sorte d'instruction de branchement multi-voie comme `switch` et peut-être une expression conditionnelle comme `?:`, mais Lox garde ça simple.

## Instructions While

Cela nous amène aux instructions de _boucle_, qui sautent en _arrière_ pour que le code puisse être exécuté plus d'une fois. Lox a seulement deux constructions de boucle, `while` et `for`. Une boucle `while` est (beaucoup) plus simple, donc nous commençons la fête là.

^code parse-while (1 before, 1 after)

Quand nous atteignons un jeton `while`, nous appelons :

^code while-statement

La plupart de ceci reflète les instructions `if` -- nous compilons l'expression de condition, entourée par des parenthèses obligatoires. C'est suivi par une instruction de saut qui saute par-dessus l'instruction de corps subséquente si la condition est fausse.

Nous patchons le saut après la compilation du corps et prenons soin de <span name="pop">dépiler</span> la valeur de condition de la pile sur l'un ou l'autre chemin. La seule différence d'une instruction `if` est la boucle. Cela ressemble à ceci :

<aside name="pop">

Je commence vraiment à remettre en question ma décision d'utiliser les mêmes instructions de saut pour les opérateurs logiques.

</aside>

^code loop (1 before, 2 after)

Après le corps, nous appelons cette fonction pour émettre une instruction "loop" (boucle). Cette instruction a besoin de savoir jusqu'où sauter en arrière. Lors du saut en avant, nous devions émettre l'instruction en deux étapes puisque nous ne savions pas jusqu'où nous allions sauter jusqu'à après que nous ayons émis l'instruction de saut. Nous n'avons pas ce problème maintenant. Nous avons déjà compilé le point dans le code auquel nous voulons sauter en arrière -- c'est juste avant l'expression de condition.

Tout ce que nous avons besoin de faire est de capturer cet emplacement alors que nous le compilons.

^code loop-start (1 before, 1 after)

Après avoir exécuté le corps d'une boucle `while`, nous sautons tout le chemin en arrière à avant la condition. De cette façon, nous réévaluons l'expression de condition à chaque itération. Nous stockons le compte d'instruction courant du chunk dans `loopStart` pour enregistrer le décalage dans le bytecode juste avant l'expression de condition que nous sommes sur le point de compiler. Ensuite nous passons cela dans cette fonction d'aide :

^code emit-loop

C'est un peu comme `emitJump()` et `patchJump()` combinés. Elle émet une nouvelle instruction de boucle, qui saute inconditionnellement en _arrière_ par un décalage donné. Comme les instructions de saut, après cela nous avons un opérande de 16-bits. Nous calculons le décalage depuis l'instruction à laquelle nous sommes actuellement vers le point `loopStart` auquel nous voulons sauter en arrière. Le `+ 2` est pour prendre en compte la taille des propres opérandes de l'instruction `OP_LOOP` que nous avons aussi besoin de sauter par-dessus.

De la perspective de la VM, il n'y a vraiment aucune différence sémantique entre `OP_LOOP` et `OP_JUMP`. Toutes deux ajoutent juste un décalage au `ip`. Nous aurions pu utiliser une seule instruction pour les deux et lui donner un opérande de décalage signé. Mais je me suis figuré que c'était un peu plus facile d'éviter le triturage de bits ennuyeux requis pour empaqueter manuellement un entier signé de 16-bits dans deux octets, et nous avons l'espace d'opcode disponible, alors pourquoi ne pas l'utiliser ?

La nouvelle instruction est ici :

^code loop-op (1 before, 1 after)

Et dans la VM, nous l'implémentons ainsi :

^code op-loop (1 before, 1 after)

La seule différence de `OP_JUMP` est une soustraction au lieu d'une addition. Le désassemblage est similaire aussi.

^code disassemble-loop (1 before, 1 after)

C'est notre instruction `while`. Elle contient deux sauts -- un conditionnel en avant pour échapper à la boucle quand la condition n'est pas remplie, et une boucle inconditionnelle en arrière après que nous avons exécuté le corps. Le flux ressemble à ceci :

<img src="image/jumping-back-and-forth/while.png" alt="Organigramme du bytecode compilé d'une instruction while." />

## Instructions For

L'autre instruction de boucle dans Lox est la vénérable boucle `for`, héritée du C. Elle a beaucoup plus de choses qui se passent avec elle comparée à une boucle `while`. Elle a trois clauses, qui sont toutes optionnelles :

<span name="detail"></span>

- L'initialisateur peut être une déclaration de variable ou une expression. Il s'exécute une fois au début de l'instruction.

- La clause de condition est une expression. Comme dans une boucle `while`, nous sortons de la boucle quand elle évalue à quelque chose de faux.

- L'expression d'incrément s'exécute une fois à la fin de chaque itération de boucle.

<aside name="detail">

Si vous voulez un rafraîchissement, le chapitre correspondant dans la partie II parcourt la sémantique [plus en détail][jlox].

[jlox]: contrôle-de-flux.html#boucles-for

</aside>

Dans jlox, l'analyseur dé-sucre une boucle `for` en un AST synthétisé pour une boucle `while` avec quelques trucs extra avant elle et à la fin du corps. Nous ferons quelque chose de similaire, bien que nous ne passerons par rien comme un AST. Au lieu de cela, notre compilateur de bytecode utilisera les instructions de saut et de boucle que nous avons déjà.

Nous travaillerons notre chemin à travers l'implémentation un morceau à la fois, commençant avec le mot-clé `for`.

^code parse-for (1 before, 1 after)

Elle appelle une fonction d'aide. Si nous supportions seulement les boucles `for` avec des clauses vides comme `for (;;)`, alors nous pourrions l'implémenter comme ceci :

^code for-statement

Il y a un tas de ponctuation obligatoire au sommet. Ensuite nous compilons le corps. Comme nous avons fait pour les boucles `while`, nous enregistrons le décalage bytecode au sommet du corps et émettons une boucle pour sauter en arrière à ce point après lui. Nous avons une implémentation fonctionnelle de boucles <span name="infinite">infinies</span> maintenant.

<aside name="infinite">

Hélas, sans instructions `return`, il n'y a aucun moyen de la terminer à moins d'une erreur d'exécution.

</aside>

### Clause d'initialisateur

Maintenant nous ajouterons la première clause, l'initialisateur. Elle s'exécute seulement une fois, avant le corps, donc compiler est direct.

^code for-initializer (1 before, 2 after)

La syntaxe est un peu complexe puisque nous permettons soit une déclaration de variable soit une expression. Nous utilisons la présence du mot-clé `var` pour dire laquelle nous avons. Pour le cas de l'expression, nous appelons `expressionStatement()` au lieu de `expression()`. Cela cherche un point-virgule, dont nous avons besoin ici aussi, et émet aussi une instruction `OP_POP` pour jeter la valeur. Nous ne voulons pas que l'initialisateur laisse quoi que ce soit sur la pile.

Si une instruction `for` déclare une variable, cette variable devrait être portée au corps de la boucle. Nous assurons cela en enveloppant l'instruction entière dans une portée.

^code for-begin-scope (1 before, 1 after)

Ensuite nous la fermons à la fin.

^code for-end-scope (1 before, 1 after)

### Clause de condition

Suivant, est l'expression de condition qui peut être utilisée pour sortir de la boucle.

^code for-exit (1 before, 1 after)

Puisque la clause est optionnelle, nous avons besoin de voir si elle est réellement présente. Si la clause est omise, le jeton suivant doit être un point-virgule, donc nous cherchons cela pour dire. S'il n'y a pas de point-virgule, il doit y avoir une expression de condition.

Dans ce cas, nous la compilons. Ensuite, juste comme avec while, nous émettons un saut conditionnel qui sort de la boucle si la condition est fausse. Puisque le saut laisse la valeur sur la pile, nous la dépilons avant d'exécuter le corps. Cela assure que nous jetons la valeur quand la condition est vraie.

Après le corps de la boucle, nous avons besoin de patcher ce saut.

^code exit-jump (1 before, 2 after)

Nous faisons cela seulement quand il y a une clause de condition. S'il n'y en a pas, il n'y a pas de saut à patcher et pas de valeur de condition sur la pile à dépiler.

### Clause d'incrément

J'ai gardé le meilleur pour la fin, la clause d'incrément. C'est assez alambiqué. Elle apparaît textuellement avant le corps, mais s'exécute _après_ lui. Si nous analysions vers un AST et générions du code dans une passe séparée, nous pourrions simplement traverser dans et compiler le champ corps de l'AST de l'instruction `for` avant sa clause d'incrément.

Malheureusement, nous ne pouvons pas compiler la clause d'incrément plus tard, puisque notre compilateur fait seulement une seule passe sur le code. Au lieu de cela, nous _sauterons par-dessus_ l'incrément, exécuterons le corps, sauterons _en arrière_ jusqu'à l'incrément, l'exécuterons, et ensuite irons à la prochaine itération.

Je sais, un peu bizarre, mais hey, cela bat la gestion manuelle d'ASTs en mémoire en C, non ? Voici le code :

^code for-increment (2 before, 2 after)

Encore, c'est optionnel. Puisque c'est la dernière clause, quand omise, le jeton suivant sera la parenthèse fermante. Quand un incrément est présent, nous avons besoin de le compiler maintenant, mais il ne devrait pas s'exécuter encore. Donc, d'abord, nous émettons un saut inconditionnel qui saute par-dessus le code de la clause d'incrément vers le corps de la boucle.

Ensuite, nous compilons l'expression d'incrément elle-même. C'est habituellement une assignation. Quoi que ce soit, nous l'exécutons seulement pour son effet de bord, donc nous émettons aussi un pop pour jeter sa valeur.

La dernière partie est un peu délicate. D'abord, nous émettons une instruction de boucle. C'est la boucle principale qui nous ramène au sommet de la boucle `for` -- juste avant l'expression de condition s'il y en a une. Cette boucle arrive juste après l'incrément, puisque l'incrément s'exécute à la fin de chaque itération de boucle.

Ensuite nous changeons `loopStart` pour pointer vers le décalage où l'expression d'incrément commence. Plus tard, quand nous émettons l'instruction de boucle après l'instruction de corps, cela causera qu'elle saute jusqu'à l'expression d'_incrément_ au lieu du sommet de la boucle comme elle fait quand il n'y a pas d'incrément. C'est comme cela que nous tissons l'incrément dedans pour tourner après le corps.

C'est alambiqué, mais tout s'arrange. Une boucle complète avec toutes les clauses compile vers un flux comme ceci :

<img src="image/jumping-back-and-forth/for.png" alt="Organigramme du bytecode compilé d'une instruction for." />

Comme avec l'implémentation des boucles `for` dans jlox, nous n'avons pas eu besoin de toucher au runtime. Tout se fait compiler vers des opérations de contrôle de flux primitives que la VM supporte déjà. Dans ce chapitre, nous avons fait un grand <span name="leap">bond</span> en avant -- clox est maintenant Turing-complet. Nous avons aussi couvert un bon peu de nouvelle syntaxe : trois instructions et deux formes d'expression. Même ainsi, cela a seulement pris trois nouvelles instructions simples. C'est un ratio effort-sur-récompense assez bon pour l'architecture de notre VM.

<aside name="leap">

Je n'ai pas pu résister au jeu de mots. Je ne regrette rien.

</aside>

<div class="challenges">

## Défis

1.  En plus des instructions `if`, la plupart des langages de la famille C ont une instruction `switch` multi-voie. Ajoutez-en une à clox. La grammaire est :

    ```ebnf
    switchStmt     → "switch" "(" expression ")"
                     "{" switchCase* defaultCase? "}" ;
    switchCase     → "case" expression ":" statement* ;
    defaultCase    → "default" ":" statement* ;
    ```

    Pour exécuter une instruction `switch`, évaluez d'abord l'expression de valeur switch parenthesée. Ensuite parcourez les cas. Pour chaque cas, évaluez son expression de valeur. Si la valeur de cas est égale à la valeur switch, exécutez les instructions sous le cas et ensuite sortez de l'instruction `switch`. Sinon, essayez le cas suivant. Si aucun cas ne correspond et qu'il y a une clause `default`, exécutez ses instructions.

    Pour garder les choses plus simples, nous omettons la retombée (fallthrough) et les instructions `break`. Chaque cas saute automatiquement à la fin de l'instruction switch après que ses instructions sont faites.

1.  Dans jlox, nous avions un défi pour ajouter le support pour les instructions `break`. Cette fois, faisons `continue` :

    ```ebnf
    continueStmt   → "continue" ";" ;
    ```

    Une instruction `continue` saute directement au sommet de la boucle englobante la plus proche, sautant le reste du corps de la boucle. À l'intérieur d'une boucle `for`, un `continue` saute à la clause d'incrément, s'il y en a une. C'est une erreur de compilation d'avoir une instruction `continue` non englobée dans une boucle.

    Assurez-vous de penser à la portée. Que devrait-il arriver aux variables locales déclarées à l'intérieur du corps de la boucle ou dans des blocs imbriqués à l'intérieur de la boucle quand un `continue` est exécuté ?

1.  Les constructions de contrôle de flux ont été surtout inchangées depuis Algol 68. L'évolution du langage depuis lors s'est concentrée sur rendre le code plus déclaratif et haut niveau, donc le contrôle de flux impératif n'a pas obtenu beaucoup d'attention.

    Pour le plaisir, essayez d'inventer une fonctionnalité de contrôle de flux nouvelle utile pour Lox. Cela peut être un raffinement d'une forme existante ou quelque chose d'entièrement nouveau. En pratique, il est dur de trouver quelque chose d'assez utile à ce bas niveau d'expressivité pour peser plus lourd que le coût de forcer un utilisateur à apprendre une notation et un comportement non familiers, mais c'est une bonne chance de pratiquer vos compétences de conception.

</div>
<div class="design-note">

## Note de Conception : Considérer le Goto Nuisible

Découvrir que tout notre beau contrôle de flux structuré dans Lox est en fait compilé en sauts bruts non structurés est comme le moment dans Scooby Doo quand le monstre arrache le masque de son visage. C'était goto tout le long ! Sauf que dans ce cas, le monstre est _sous_ le masque. Nous savons tous que goto est maléfique. Mais... pourquoi ?

Il est vrai que vous pouvez écrire du code outrageusement non maintenable utilisant goto. Mais je ne pense pas que la plupart des programmeurs autour d'aujourd'hui ont vu cela de première main. Cela fait longtemps que ce style était commun. Ces jours-ci, c'est un croque-mitaine que nous invoquons dans des histoires effrayantes autour du feu de camp.

La raison pour laquelle nous confrontons rarement ce monstre en personne est parce que Edsger Dijkstra l'a tué avec sa célèbre lettre "Go To Statement Considered Harmful" (L'instruction Go To considérée nuisible), publiée dans _Communications of the ACM_ (Mars, 1968). Le débat autour de la programmation structurée avait été féroce pendant quelque temps avec des adhérents des deux côtés, mais je pense que Dijkstra mérite le plus de crédit pour effectivement y mettre fin. La plupart des nouveaux langages aujourd'hui n'ont pas d'instructions de saut non structuré.

Une lettre d'une page et demie qui a presque à elle seule détruit une fonctionnalité de langage doit être un truc assez impressionnant. Si vous ne l'avez pas lue, je vous encourage à le faire. C'est un morceau séminal du folklore de la science informatique, une des chansons ancestrales de notre tribu. Aussi, c'est un joli, court morceau de pratique pour lire l'<span name="style">écriture</span> académique de CS, ce qui est une compétence utile à développer.

<aside name="style">

C'est-à-dire, si vous pouvez passer outre le style d'écriture faussement modeste et auto-agrandissant insupportable de Dijkstra :

> Plus récemment, j'ai découvert pourquoi l'utilisation de l'instruction go to a de tels effets désastreux. ...À ce moment-là, je n'attachais pas trop d'importance à cette découverte ; je soumets maintenant mes considérations pour publication parce que dans des discussions très récentes dans lesquelles le sujet est apparu, j'ai été pressé de le faire.

Ah, encore une de mes nombreuses découvertes. Je ne pouvais même pas être dérangé de l'écrire jusqu'à ce que les masses clamantes me supplient de le faire.

</aside>

Je l'ai lue un certain nombre de fois, avec quelques critiques, réponses, et commentaires. J'ai fini avec des sentiments mitigés, au mieux. À un très haut niveau, je suis avec lui. Son argument général est quelque chose comme ceci :

1.  En tant que programmeurs, nous écrivons des programmes -- texte statique -- mais ce dont nous nous soucions est le programme s'exécutant réellement -- son comportement dynamique.

2.  Nous sommes meilleurs à raisonner sur des choses statiques que des choses dynamiques. (Il ne fournit aucune preuve pour supporter cette affirmation, mais je l'accepte.)

3.  Ainsi, plus nous pouvons faire que l'exécution dynamique du programme reflète sa structure textuelle, mieux c'est.

C'est un bon début. Attirer notre attention sur la séparation entre le code que nous écrivons et le code tel qu'il s'exécute à l'intérieur de la machine est une vue intéressante. Ensuite il essaie de définir une "correspondance" entre le texte du programme et l'exécution. Pour quelqu'un qui a passé littéralement sa carrière entière à préconiser une plus grande rigueur dans la programmation, sa définition est assez vague. Il dit :

> Considérons maintenant comment nous pouvons caractériser le progrès d'un processus. (Vous pouvez penser à cette question d'une manière très concrète : supposons qu'un processus, considéré comme une succession temporelle d'actions, est arrêté après une action arbitraire, quelles données devons-nous fixer afin que nous puissions refaire le processus jusqu'au même point ?)

Imaginez-le comme ceci. Vous avez deux ordinateurs avec le même programme s'exécutant sur exactement les mêmes entrées -- donc totalement déterministes. Vous mettez en pause l'un d'eux à un point arbitraire dans son exécution. Quelles données auriez-vous besoin d'envoyer à l'autre ordinateur pour être capable de l'arrêter exactement aussi loin que le premier l'était ?

Si votre programme permet seulement des instructions simples comme l'assignation, c'est facile. Vous avez juste besoin de connaître le point après la dernière instruction que vous avez exécutée. Fondamentalement un point d'arrêt, le `ip` dans notre VM, ou le numéro de ligne dans un message d'erreur. Ajouter le contrôle de flux de branchement comme `if` et `switch` n'ajoute rien de plus à cela. Même si le marqueur pointe à l'intérieur d'une branche, nous pouvons toujours dire où nous sommes.

Une fois que vous ajoutez les appels de fonction, vous avez besoin de quelque chose de plus. Vous pourriez avoir mis en pause le premier ordinateur au milieu d'une fonction, mais cette fonction peut être appelée de multiples endroits. Pour mettre en pause la seconde machine à exactement le même point dans l'exécution du _programme entier_, vous avez besoin de la mettre en pause sur le _bon_ appel à cette fonction.

Donc vous avez besoin de savoir non seulement l'instruction courante, mais, pour les appels de fonction qui n'ont pas encore retourné, vous avez besoin de connaître les emplacements des sites d'appel. En d'autres termes, une pile d'appels, bien que je ne pense pas que ce terme existait quand Dijkstra a écrit ceci. Groovy (Super).

Il note que les boucles rendent les choses plus dures. Si vous mettez en pause au milieu d'un corps de boucle, vous ne savez pas combien d'itérations ont tourné. Donc il dit que vous avez aussi besoin de garder un compte d'itération. Et, puisque les boucles peuvent s'imbriquer, vous avez besoin d'une pile de ceux-ci (présumément entrelacés avec les pointeurs de pile d'appels puisque vous pouvez être dans des boucles dans des appels extérieurs aussi).

C'est là que ça devient bizarre. Donc nous construisons vraiment vers quelque chose maintenant, et vous vous attendez à ce qu'il explique comment goto brise tout cela. Au lieu de cela, il dit juste :

> L'utilisation débridée de l'instruction go to a une conséquence immédiate qu'il devient terriblement dur de trouver un ensemble significatif de coordonnées dans lequel décrire le progrès du processus.

Il ne prouve pas que c'est dur, ou dit pourquoi. Il le dit juste. Il dit bien qu'une approche est insatisfaisante :

> Avec l'instruction go to on peut, bien sûr, toujours décrire le progrès uniquement par un compteur comptant le nombre d'actions effectuées depuis le début du programme (c.-à-d. une sorte d'horloge normalisée). La difficulté est qu'une telle coordonnée, bien qu'unique, est totalement inutile.

Mais... c'est effectivement ce que les compteurs de boucle font, et il était d'accord avec ceux-là. Ce n'est pas comme si chaque boucle est un simple "pour chaque entier de 0 à 10" comptage incrémental. Beaucoup sont des boucles `while` avec des conditionnelles complexes.

Prenant un exemple proche de la maison, considérez la boucle d'exécution de bytecode centrale au cœur de clox. Dijkstra argumente que cette boucle est traitable parce que nous pouvons simplement compter combien de fois la boucle a tourné pour raisonner sur son progrès. Mais cette boucle tourne une fois pour chaque instruction exécutée dans le programme Lox compilé de quelque utilisateur. Est-ce que savoir qu'elle a exécuté 6 201 instructions bytecode nous dit vraiment _quoi que ce soit_ d'édifiant sur l'état de l'interpréteur ?

En fait, cet exemple particulier pointe vers une vérité plus profonde. Böhm et Jacopini ont [prouvé][proved] que _tout_ contrôle de flux utilisant goto peut être transformé en un utilisant juste le séquencement, les boucles, et les branches. Notre boucle d'interpréteur de bytecode est un exemple vivant de cette preuve : elle implémente le contrôle de flux non structuré du jeu d'instructions bytecode de clox sans utiliser aucun goto elle-même.

[proved]: https://fr.wikipedia.org/wiki/Th%C3%A9or%C3%A8me_de_b%C3%B6hm-jacopini

Cela semble offrir un contre-argument à l'affirmation de Dijkstra : vous _pouvez_ définir une correspondance pour un programme utilisant des gotos en le transformant en un qui ne le fait pas et ensuite utiliser la correspondance depuis ce programme, qui -- selon lui -- est acceptable parce qu'il utilise seulement des branches et des boucles.

Mais, honnêtement, mon argument ici est aussi faible. Je pense que nous deux faisons fondamentalement des maths pour de faux et utilisons de la fausse logique pour faire ce qui devrait être un argument empirique, centré sur l'humain. Dijkstra a raison que du code utilisant goto est vraiment mauvais. Beaucoup de cela pourrait et devrait être tourné en code plus clair en utilisant le contrôle de flux structuré.

En éliminant goto complètement des langages, vous êtes définitivement empêché d'écrire du mauvais code utilisant des gotos. Il se peut que forcer les utilisateurs à utiliser le contrôle de flux structuré et faire que ce soit une bataille difficile d'écrire du code de type goto utilisant ces constructions est un gain net pour toute notre productivité.

Mais je me demande parfois si nous avons jeté le bébé avec l'eau du bain. En l'absence de goto, nous recourons souvent à des motifs structurés plus complexes. Le "switch à l'intérieur d'une boucle" en est un classique. Un autre est l'utilisation d'une variable garde pour sortir d'une série de boucles imbriquées :

<span name="break">
</span>

```c
// Voir si la matrice contient un zéro.
bool found = false;
for (int x = 0; x < xSize; x++) {
  for (int y = 0; y < ySize; y++) {
    for (int z = 0; z < zSize; z++) {
      if (matrix[x][y][z] == 0) {
        printf("found");
        found = true;
        break;
      }
    }
    if (found) break;
  }
  if (found) break;
}
```

Est-ce vraiment mieux que :

```c
for (int x = 0; x < xSize; x++) {
  for (int y = 0; y < ySize; y++) {
    for (int z = 0; z < zSize; z++) {
      if (matrix[x][y][z] == 0) {
        printf("found");
        goto done;
      }
    }
  }
}
done:
```

<aside name="break">

Vous pourriez faire cela sans instructions `break` -- elles-mêmes une construction de style goto limitée -- en insérant `!found &&` au début de la clause de condition de chaque boucle.

</aside>

Je suppose que ce que je n'aime vraiment pas est que nous prenons des décisions de conception de langage et d'ingénierie aujourd'hui basées sur la peur. Peu de gens aujourd'hui ont une compréhension subtile des problèmes et bénéfices de goto. Au lieu de cela, nous pensons juste qu'il est "considéré nuisible". Personnellement, je n'ai jamais trouvé le dogme un bon point de départ pour un travail créatif de qualité.

</div>

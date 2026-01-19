> Au milieu du chemin de notre vie je me retrouvai par une forêt obscure où la voie droite était perdue.
>
> <cite>Dante Alighieri, <em>Enfer</em></cite>

Ce chapitre est excitant pour non pas une, non pas deux, mais _trois_ raisons. Premièrement, il fournit le segment final du pipeline d'exécution de notre VM. Une fois en place, nous pouvons tuyauter le code source de l'utilisateur depuis le scan tout le long jusqu'à son exécution.

<img src="image/compiling-expressions/pipeline.png" alt="Abaisser la section 'compilateur' du tuyau entre 'scanner' et 'VM'." />

Deuxièmement, nous pouvons écrire un _compilateur_ réel, authentique. Il parse le code source et sort une série d'instructions binaires de bas niveau. Bien sûr, c'est du <span name="wirth">bytecode</span> et pas le jeu d'instructions natif d'une puce, mais c'est bien plus proche du métal que ne l'était jlox. Nous sommes sur le point d'être de vrais hackers de langage.

<aside name="wirth">

Le bytecode était assez bon pour Niklaus Wirth, et personne ne remet en question sa crédibilité de rue.

</aside>

<span name="pratt">Troisièmement</span> et finalement, je peux vous montrer l'un de mes algorithmes favoris absolus : l'"analyse syntaxique à précédence d'opérateur descendante" de Vaughan Pratt. C'est la façon la plus élégante que je connaisse de parser des expressions. Elle gère avec grâce les opérateurs préfixes, postfixes, infixes, _mixfixes_, n'importe quel genre de _-fixe_ que vous avez. Elle traite la précédence et l'associativité sans transpirer. J'adore ça.

<aside name="pratt">

Les parseurs Pratt sont une sorte de tradition orale dans l'industrie. Aucun livre de compilateur ou de langage que j'ai lu ne les enseigne. Le monde académique est très focalisé sur les parseurs générés, et la technique de Pratt est pour ceux écrits à la main, donc elle est négligée.

Mais dans les compilateurs en production, où les parseurs roulés à la main sont communs, vous seriez surpris de combien de gens la connaissent. Demandez où ils l'ont apprise, et c'est toujours, "Oh, j'ai travaillé sur ce compilateur il y a des années et mon collègue a dit qu'ils l'avaient prise de ce vieux front end..."

</aside>

Comme d'habitude, avant que nous arrivions aux trucs amusants, nous avons quelques préliminaires à travailler. Vous devez manger vos légumes avant d'avoir le dessert. D'abord, abandonnons cet échafaudage temporaire que nous avons écrit pour tester le scanner et remplaçons-le par quelque chose de plus utile.

^code interpret-chunk (1 before, 1 after)

Nous créons un nouveau morceau vide et le passons au compilateur. Le compilateur prendra le programme de l'utilisateur et remplira le morceau avec du bytecode. Au moins, c'est ce qu'il fera si le programme n'a aucune erreur de compilation. S'il rencontre une erreur, `compile()` renvoie `false` et nous jetons le morceau inutilisable.

Sinon, nous envoyons le morceau complété à la VM pour être exécuté. Quand la VM finit, nous libérons le morceau et nous avons fini. Comme vous pouvez le voir, la signature de `compile()` est différente maintenant.

^code compile-h (2 before, 2 after)

Nous passons le morceau où le compilateur écrira le code, et ensuite `compile()` renvoie si la compilation a réussi ou non. Nous faisons le même changement à la signature dans l'implémentation.

^code compile-signature (2 before, 1 after)

Cet appel à `initScanner()` est la seule ligne qui survit à ce chapitre. Arrachez le code temporaire que nous avons écrit pour tester le scanner et remplacez-le par ces trois lignes :

^code compile-chunk (1 before, 1 after)

L'appel à `advance()` "amorce la pompe" sur le scanner. Nous verrons ce qu'il fait bientôt. Ensuit nous parsons une unique expression. Nous n'allons pas faire les instructions (statements) encore, donc c'est le seul sous-ensemble de la grammaire que nous supportons. Nous revisiterons cela quand nous [ajouterons les instructions dans quelques chapitres][globals]. Après que nous ayons compilé l'expression, nous devrions être à la fin du code source, donc nous vérifions le token sentinelle EOF.

[globals]: variables-globales.html

Nous allons passer le reste du chapitre à faire marcher cette fonction, spécialement ce petit appel `expression()`. Normalement, nous plongerions directement dans cette définition de fonction et travaillerions notre chemin à travers l'implémentation de haut en bas.

Ce chapitre est <span name="blog">différent</span>. La technique de parsing de Pratt est remarquablement simple une fois que vous l'avez toute chargée dans votre tête, mais c'est un peu délicat de la casser en morceaux de taille bouchée. Elle est récursive, bien sûr, ce qui est une partie du problème. Mais elle repose aussi sur une grosse table de données. Alors que nous construisons l'algorithme, cette table grandit de colonnes additionnelles.

<aside name="blog">

Si ce chapitre ne clique pas avec vous et que vous aimeriez une autre prise sur les concepts, j'ai écrit un article qui enseigne le même algorithme mais en utilisant Java et un style orienté objet : ["Pratt Parsing: Expression Parsing Made Easy"][blog].

[blog]: http://journal.stuffwithstuff.com/2011/03/19/pratt-parsers-expression-parsing-made-easy/

</aside>

Je ne veux pas revisiter 40 et quelques lignes de code chaque fois que nous étendons la table. Donc nous allons travailler notre chemin vers le cœur du parseur depuis l'extérieur et couvrir tous les bouts environnants avant que nous arrivions au centre juteux. Cela exigera un peu plus de patience et d'espace de brouillon mental que la plupart des chapitres, mais c'est le mieux que je pouvais faire.

## Compilation à Une Passe

Un compilateur a grossièrement deux travaux. Il parse le code source de l'utilisateur pour comprendre ce qu'il signifie. Ensuite il prend cette connaissance et sort des instructions de bas niveau qui produisent la même sémantique. Beaucoup de langages séparent ces deux rôles en deux <span name="passes">passes</span> séparées dans l'implémentation. Un parseur produit un AST -- juste comme jlox le fait -- et ensuite un générateur de code traverse l'AST et sort le code cible.

<aside name="passes">

En fait, la plupart des compilateurs optimisants sophistiqués ont un sacré paquet de plus que deux passes. Déterminer non seulement _quelles_ passes d'optimisation avoir, mais comment les ordonner pour presser le plus de performance hors du compilateur -- puisque les optimisations interagissent souvent de manières complexes -- est quelque part entre une "zone ouverte de recherche" et un "art noir".

</aside>

Dans clox, nous prenons une approche vieille méthode et fusionnons ces deux passes en une. À l'époque, les hackers de langage faisaient cela parce que les ordinateurs n'avaient littéralement pas assez de mémoire pour stocker l'AST d'un fichier source entier. Nous le faisons parce que cela garde notre compilateur plus simple, ce qui est un vrai atout quand on programme en C.

Les compilateurs à une passe comme nous allons construire ne fonctionnent pas bien pour tous les langages. Puisque le compilateur a seulement une vue par le trou de la serrure dans le programme de l'utilisateur tout en générant du code, le langage doit être conçu de telle sorte que vous n'avez pas besoin de beaucoup de contexte environnant pour comprendre un morceau de syntaxe. Heureusement, le minuscule Lox typé dynamiquement est <span name="lox">bien adapté</span> à cela.

<aside name="lox">

Pas que cela devrait venir comme une grosse surprise. J'ai conçu le langage spécifiquement pour ce livre après tout.

<img src="image/compiling-expressions/keyhole.png" alt="Regardant à travers un trou de serrure à 'var x;'" />

</aside>

Ce que cela signifie en termes pratiques est que notre module C "compilateur" a une fonctionnalité que vous reconnaîtrez de jlox pour parser -- consommer des tokens, correspondre des types de token attendus, etc. Et il a aussi des fonctions pour la génération de code -- émettre du bytecode et ajouter des constantes au morceau de destination. (Et cela signifie que j'utiliserai "parser" et "compiler" de manière interchangeable à travers ce chapitre et les suivants.)

Nous construirons les moitiés de parsing et de génération de code d'abord. Ensuite nous les coudrons ensemble avec le code au milieu qui utilise la technique de Pratt pour parser la grammaire particulière de Lox et sortir le bon bytecode.

## Parser les Tokens

En premier, la moitié avant du compilateur. Le nom de cette fonction devrait sembler familier.

^code advance (1 before)

Juste comme dans jlox, elle avance d'un pas à travers le flux de tokens. Elle demande au scanner le prochain token et le stocke pour une utilisation ultérieure. Avant de faire cela, elle prend le vieux token `current` et planque ça dans un champ `previous`. Cela deviendra utile plus tard pour que nous puissions accéder au lexème après que nous ayons correspondu un token.

Le code pour lire le prochain token est enveloppé dans une boucle. Rappelez-vous, le scanner de clox ne rapporte pas les erreurs lexicales. Au lieu de cela, il crée des _tokens d'erreur_ spéciaux et laisse au parseur le soin de les rapporter. Nous faisons cela ici.

Nous continuons de boucler, lisant des tokens et rapportant les erreurs, jusqu'à ce nous touchions un non-erreur ou atteignions la fin. De cette façon, le reste du parseur voit seulement des tokens valides. Le token courant et le précédent sont stockés dans cette struct :

^code parser (1 before, 2 after)

Comme nous l'avons fait dans d'autres modules, nous avons une variable globale unique de ce type struct pour que nous n'ayons pas besoin de passer l'état de fonction en fonction dans le compilateur.

### Gestion des erreurs de syntaxe

Si le scanner nous passe un token d'erreur, nous devons dire réellement à l'utilisateur. Cela arrive en utilisant ceci :

^code error-at-current

Nous tirons l'emplacement hors du token courant afin de dire à l'utilisateur où l'erreur s'est produite et de transférer à `errorAt()`. Plus souvent, nous rapporterons une erreur à l'emplacement du token que nous venons de consommer, donc nous donnons le nom plus court à cette autre fonction :

^code error

Le travail réel se passe ici :

^code error-at

D'abord, nous imprimons où l'erreur s'est produite. Nous essayons de montrer le lexème s'il est lisible par un humain. Ensuite nous imprimons le message d'erreur lui-même. Après cela, nous définissons ce drapeau `hadError`. Cela enregistre si des erreurs se sont produites durant la compilation. Ce champ vit aussi dans la struct parser.

^code had-error-field (1 before, 1 after)

Plus tôt j'ai dit que `compile()` devrait renvoyer `false` si une erreur s'est produite. Maintenant nous pouvons faire en sorte qu'il fasse cela.

^code return-had-error (1 before, 1 after)

J'ai un autre drapeau à introduire pour la gestion d'erreur. Nous voulons éviter les cascades d'erreurs. Si l'utilisateur a une erreur dans son code et que le parseur devient confus sur où il est dans la grammaire, nous ne voulons pas qu'il vomisse tout un tas d'erreurs consécutives sans signification après la première.

Nous avons corrigé ça dans jlox en utilisant la récupération d'erreur en mode panique. Dans l'interpréteur Java, nous levions une exception pour dérouler hors de tout le code du parseur à un point où nous pouvions sauter des tokens et resynchroniser. Nous n'avons pas d'<span name="setjmp">exceptions</span> en C. Au lieu de cela, nous ferons un peu de fumée et de miroirs. Nous ajoutons un drapeau pour suivre si nous sommes actuellement en mode panique.

<aside name="setjmp">

Il y a `setjmp()` et `longjmp()`, mais je préférerais ne pas aller par là. Ceux-là rendent trop facile de fuiter de la mémoire, d'oublier de maintenir des invariants, ou autrement d'avoir une Très Mauvaise Journée.

</aside>

^code panic-mode-field (1 before, 1 after)

Quand une erreur se produit, nous le définissons.

^code set-panic-mode (1 before, 1 after)

Après cela, nous allons de l'avant et continuons de compiler comme normal comme si l'erreur ne s'était jamais produite. Le bytecode ne sera jamais exécuté, donc c'est inoffensif de continuer à avancer. Le truc est que tant que le drapeau de mode panique est défini, nous supprimons simplement toute autre erreur qui est détectée.

^code check-panic-mode (1 before, 1 after)

Il y a une bonne chance que le parseur aille dans les mauvaises herbes, mais l'utilisateur ne le saura pas parce que les erreurs sont toutes avalées. Le mode panique finit quand le parseur atteint un point de synchronisation. Pour Lox, nous avons choisi les frontières d'instruction (statement), donc quand nous ajouterons plus tard celles-ci à notre compilateur, nous effacerons le drapeau là.

Ces nouveaux champs ont besoin d'être initialisés.

^code init-parser-error (1 before, 1 after)

Et pour afficher les erreurs, nous avons besoin d'un en-tête standard.

^code compiler-include-stdlib (1 before, 2 after)

Il y a une dernière fonction de parsing, une autre vieille amie de jlox.

^code consume

Elle est similaire à `advance()` en ce qu'elle lit le prochain token. Mais elle valide aussi que le token a un type attendu. Si non, elle rapporte une erreur. Cette fonction est la fondation de la plupart des erreurs de syntaxe dans le compilateur.

OK, c'est assez sur le front end pour l'instant.

## Émettre du Bytecode

Après que nous ayons parsé et compris un morceau du programme de l'utilisateur, la prochaine étape est de traduire cela vers une série d'instructions bytecode. Cela commence avec l'étape la plus facile possible : ajouter un seul octet au morceau.

^code emit-byte

C'est dur de croire que de grandes choses découleront d'une fonction si simple. Elle écrit l'octet donné, qui peut être un opcode ou un opérande à une instruction. Elle envoie l'information de ligne du token précédent de sorte que les erreurs d'exécution soient associées à cette ligne.

Le morceau que nous écrivons est passé dans `compile()`, mais il a besoin de faire son chemin vers `emitByte()`. Pour faire ça, nous comptons sur cette fonction intermédiaire :

^code compiling-chunk (1 before, 1 after)

En ce moment, le pointeur de morceau est stocké dans une variable au niveau du module comme nous stockons d'autre état global. Plus tard, quand nous commencerons à compiler des fonctions définies par l'utilisateur, la notion de "morceau courant" deviendra plus compliquée. Pour éviter d'avoir à revenir et changer beaucoup de code, j'encapsule cette logique dans la fonction `currentChunk()`.

Nous initialisons cette nouvelle variable de module avant que nous écrivions tout bytecode :

^code init-compile-chunk (2 before, 2 after)

Ensuite, à la toute fin, quand nous avons fini de compiler le morceau, nous emballons les choses.

^code finish-compile (1 before, 1 after)

Cela appelle ceci :

^code end-compiler

Dans ce chapitre, notre VM traite seulement avec des expressions. Quand vous lancez clox, il parsera, compilera, et exécutera une unique expression, puis imprimera le résultat. Pour imprimer cette valeur, nous utilisons temporairement l'instruction `OP_RETURN`. Donc nous faisons en sorte que le compilateur ajoute une de celles-ci à la fin du morceau.

^code emit-return

Tant que nous sommes ici dans le back end nous pourrions aussi bien nous rendre la vie plus facile.

^code emit-bytes

Avec le temps, nous aurons assez de cas où nous avons besoin d'écrire un opcode suivi par un opérande d'un octet pour qu'il vaille la peine de définir cette fonction de commodité.

## Parser les Expressions Préfixes

Nous avons assemblé nos fonctions utilitaires de parsing et de génération de code. La pièce manquante est le code au milieu qui connecte celles-ci ensemble.

<img src="image/compiling-expressions/mystery.png" alt="Fonctions de parsing à gauche, fonctions d'émission de bytecode à droite. Qu'est-ce qui va au milieu ?" />

La seule étape dans `compile()` qu'il nous reste à implémenter est cette fonction :

^code expression

Nous ne sommes pas prêts à implémenter chaque sorte d'expression en Lox encore. Zut, nous n'avons même pas les Booléens. Pour ce chapitre, nous allons seulement nous inquiéter de quatre :

- Littéraux nombre : `123`
- Parenthèses pour le groupement : `(123)`
- Négation unaire : `-123`
- Les Quatre Cavaliers de l'Arithmétique : `+`, `-`, `*`, `/`

Alors que nous travaillons à travers les fonctions pour compiler chacun de ces genres d'expressions, nous assemblerons aussi les exigences pour le parseur piloté par table qui les appelle.

### Parseurs pour tokens

Pour l'instant, concentrons-nous sur les expressions Lox qui sont chacune seulement un token unique. Dans ce chapitre, c'est juste les littéraux nombre, mais il y en aura plus tard. Voici comment nous pouvons les compiler :

Nous mappons chaque type de token vers un genre différent d'expression. Nous définissons une fonction pour chaque expression qui sort le bytecode approprié. Ensuite nous construisons un tableau de pointeurs de fonction. Les index dans le tableau correspondent aux valeurs de l'enum `TokenType`, et la fonction à chaque index est le code pour compiler une expression de ce type de token.

Pour compiler les littéraux nombre, nous stockons un pointeur vers la fonction suivante à l'index `TOKEN_NUMBER` dans le tableau.

^code number

Nous supposons que le token pour le littéral nombre a déjà été consommé et est stocké dans `previous`. Nous prenons ce lexème et utilisons la bibliothèque standard C pour le convertir en une valeur double. Ensuite nous générons le code pour charger cette valeur en utilisant cette fonction :

^code emit-constant

D'abord, nous ajoutons la valeur à la table de constantes, ensuite nous émettons une instruction `OP_CONSTANT` qui la pousse sur la pile à l'exécution. Pour insérer une entrée dans la table de constantes, nous comptons sur :

^code make-constant

La plupart du travail se passe dans `addConstant()`, que nous avons définie de retour dans un [chapitre précédent][bytecode]. Cela ajoute la valeur donnée à la fin de la table de constantes du morceau et renvoie son index. Le travail de la nouvelle fonction est surtout de s'assurer que nous n'avons pas trop de constantes. Puisque l'instruction `OP_CONSTANT` utilise un unique octet pour l'opérande d'index, nous pouvons stocker et charger seulement jusqu'à <span name="256">256</span> constantes dans un morceau.

[bytecode]: morceaux-de-bytecode.html

<aside name="256">

Oui, cette limite est assez basse. Si c'était une implémentation de langage de pleine taille, nous voudrions ajouter une autre instruction comme `OP_CONSTANT_16` qui stocke l'index comme un opérande de deux octets pour que nous puissions gérer plus de constantes quand nécessaire.

Le code pour supporter cela n'est pas particulièrement illuminant, donc je l'ai omis de clox, mais vous voudrez que vos VMs passent à l'échelle pour de plus gros programmes.

</aside>

C'est basiquement tout ce qu'il faut. Pourvu qu'il y ait quelque code convenable qui consomme un token `TOKEN_NUMBER`, cherche `number()` dans le tableau de pointeurs de fonction, et ensuite l'appelle, nous pouvons maintenant compiler les littéraux nombre vers du bytecode.

### Parenthèses pour le groupement

Notre tableau de pointeurs de fonction de parsing pour l'instant imaginaire serait génial si chaque expression était longue de seulement un token unique. Hélas, la plupart sont plus longues. Cependant, beaucoup d'expressions _commencent_ avec un token particulier. Nous appelons celles-ci des expressions _préfixes_. Par exemple, quand nous parsons une expression et que le token courant est `(`, nous savons que nous devons regarder une expression de groupement parenthésée.

Il s'avère que notre tableau de pointeurs de fonction gère celles-ci aussi. La fonction de parsing pour un type d'expression peut consommer tous les tokens additionnels qu'elle veut, juste comme dans un parseur à descente récursive régulier. Voici comment les parenthèses fonctionnent :

^code grouping

Encore une fois, nous supposons que la parenthèse `(` initiale a déjà été consommée. Nous appelons <span name="recursive">récursivement</span> de retour dans `expression()` pour compiler l'expression entre les parenthèses, puis parsons la parenthèse fermante `)` à la fin.

<aside name="recursive">

Un parseur Pratt n'est pas un parseur à _descente_ récursive, mais il est toujours récursif. C'est attendu puisque la grammaire elle-même est récursive.

</aside>

Pour autant que le back end soit concerné, il n'y a littéralement rien à une expression de groupement. Sa seule fonction est syntaxique -- elle vous laisse insérer une expression de priorité plus basse là où une priorité plus haute est attendue. Ainsi, elle n'a aucune sémantique d'exécution par elle-même et par conséquent n'émet aucun bytecode. L'appel intérieur à `expression()` prend soin de générer le bytecode pour l'expression à l'intérieur des parenthèses.

### Négation unaire

Le moins unaire est aussi une expression préfixe, donc cela fonctionne avec notre modèle aussi.

^code unary

Le token `-` de tête a été consommé et est assis dans `parser.previous`. Nous attrapons le type de token de là pour noter à quel opérateur unaire nous avons affaire. C'est inutile pour l'instant, mais cela aura plus de sens quand nous utiliserons cette même fonction pour compiler l'opérateur `!` dans [le prochain chapitre][next].

[next]: types-de-valeurs.html

Comme dans `grouping()`, nous appelons récursivement `expression()` pour compiler l'opérande. Après cela, nous émettons le bytecode pour effectuer la négation. Cela pourrait sembler un peu bizarre d'écrire l'instruction negate _après_ le bytecode de son opérande puisque le `-` apparaît sur la gauche, mais pensez-y en termes d'ordre d'exécution :

1. Nous évaluons l'opérande d'abord ce qui laisse sa valeur sur la pile.

2. Ensuite nous dépilons cette valeur, la nions, et poussons le résultat.

Donc l'instruction `OP_NEGATE` devrait être émise en <span name="line">dernier</span>. C'est une partie du travail du compilateur -- parser le programme dans l'ordre où il apparaît dans le code source et le réarranger dans l'ordre où l'exécution se produit.

<aside name="line">

Émettre l'instruction `OP_NEGATE` après les opérandes signifie que le token courant quand le bytecode est écrit n'est _pas_ le token `-`. Cela n'a surtout pas d'importance, excepté que nous utilisons ce token pour le numéro de ligne à associer avec cette instruction.

Cela signifie que si vous avez une expression de négation multi-lignes, comme :

```lox
print -
  true;
```

Alors l'erreur d'exécution sera rapportée sur la mauvaise ligne. Ici, elle montrerait l'erreur à la ligne 2, même si le `-` est à la ligne 1. Une approche plus robuste serait de stocker la ligne du token avant de compiler l'opérande et ensuite de passer cela dans `emitByte()`, mais je voulais garder les choses simples pour le livre.

</aside>

Il y a un problème avec ce code, cependant. La fonction `expression()` qu'il appelle parsera n'importe quelle expression pour l'opérande, indépendamment de la précédence. Une fois que nous ajouterons les opérateurs binaires et autre syntaxe, cela fera la mauvaise chose. Considérez :

```lox
-a.b + c;
```

Ici, l'opérande de `-` devrait être juste l'expression `a.b`, pas le `a.b + c` entier. Mais si `unary()` appelle `expression()`, cette dernière mâchera joyeusement à travers tout le code restant incluant le `+`. Elle traitera faussement le `-` comme de précédence plus basse que le `+`.

Quand nous parsons l'opérande de `-` unaire, nous avons besoin de compiler seulement les expressions à un certain niveau de précédence ou plus haut. Dans le parseur à descente récursive de jlox nous accomplissions cela en appelant dans la méthode de parsing pour l'expression de plus basse priorité que nous voulions autoriser (dans ce cas, `call()`). Chaque méthode pour parser une expression spécifique parsait aussi n'importe quelles expressions de priorité plus haute aussi, donc cela incluait le reste de la table de précédence.

Les fonctions de parsing comme `number()` et `unary()` ici dans clox sont différentes. Chacune parse seulement exactement un type d'expression. Elles ne cascadent pas pour inclure les types d'expression de priorité plus haute aussi. Nous avons besoin d'une solution différente, et elle ressemble à ceci :

^code parse-precedence

Cette fonction -- une fois que nous l'implémenterons -- commence au token courant et parse n'importe quelle expression au niveau de précédence donné ou plus haut. Nous avons quelque autre installation à traverser avant que nous puissions écrire le corps de cette fonction, mais vous pouvez probablement deviner qu'elle utilisera cette table de pointeurs de fonction de parsing dont j'ai parlé. Pour l'instant, ne vous inquiétez pas trop de comment elle fonctionne. Afin de prendre la "précédence" comme un paramètre, nous la définissons numériquement.

^code precedence (1 before, 2 after)

Ce sont tous les niveaux de précédence de Lox dans l'ordre du plus bas au plus haut. Puisque C donne implicitement des nombres successivement plus grands pour les enums, cela signifie que `PREC_CALL` est numériquement plus grand que `PREC_UNARY`. Par exemple, disons que le compilateur est assis sur un morceau de code comme :

```lox
-a.b + c
```

Si nous appelons `parsePrecedence(PREC_ASSIGNMENT)`, alors il parsera l'expression entière parce que `+` a une priorité plus haute que l'assignation. Si au lieu de cela nous appelons `parsePrecedence(PREC_UNARY)`, il compilera le `-a.b` et arrêtera là. Il ne continue pas à travers le `+` parce que l'addition a une priorité plus basse que les opérateurs unaires.

Avec cette fonction en main, c'est un jeu d'enfant de remplir le corps manquant pour `expression()`.

^code expression-body (1 before, 1 after)

Nous parsons simplement le niveau de précédence le plus bas, qui subsume toutes les expressions de priorité plus haute aussi. Maintenant, pour compiler l'opérande pour une expression unaire, nous appelons cette nouvelle fonction et la limitons au niveau approprié :

^code unary-operand (1 before, 2 after)

Nous utilisons la propre précédence `PREC_UNARY` de l'opérateur unaire pour permettre des expressions unaires <span name="useful">imbriquées</span> comme `!!doubleNegative`. Puisque les opérateurs unaires ont une priorité assez haute, cela exclut correctement des choses comme les opérateurs binaires. En parlant desquels...

<aside name="useful">

Pas que l'imbrication d'expressions unaires soit particulièrement utile en Lox. Mais d'autres langages vous laissent le faire, donc nous aussi.

</aside>

## Parser les Expressions Infixes

Les opérateurs binaires sont différents des expressions précédentes parce qu'ils sont _infixes_. Avec les autres expressions, nous savons ce que nous parsons dès le tout premier token. Avec les expressions infixes, nous ne savons pas que nous sommes au milieu d'un opérateur binaire jusqu'à _après_ que nous ayons parsé son opérande gauche et ensuite trébuché sur le token opérateur au milieu.

Voici un exemple :

```lox
1 + 2
```

Marchons à travers l'essai de compilation de ceci avec ce que nous savons jusqu'ici :

1.  Nous appelons `expression()`. Cela appelle à son tour
    `parsePrecedence(PREC_ASSIGNMENT)`.

2.  Cette fonction (une fois que nous l'implémentons) voit le token nombre de tête et reconnaît qu'elle parse un littéral nombre. Elle passe la main à `number()`.

3.  `number()` crée une constante, émet un `OP_CONSTANT`, et renvoie vers `parsePrecedence()`.

Maintenant quoi ? L'appel à `parsePrecedence()` devrait consommer l'expression d'addition entière, donc il a besoin de continuer d'une manière ou d'une autre. Heureusement, le parseur est juste là où nous avons besoin qu'il soit. Maintenant que nous avons compilé l'expression de nombre de tête, le prochain token est `+`. C'est le token exact dont `parsePrecedence()` a besoin pour détecter que nous sommes au milieu d'une expression infixe et pour réaliser que l'expression que nous avons déjà compilée est en fait un opérande à cela.

Donc ce tableau hypothétique de pointeurs de fonction ne liste pas juste des fonctions pour parser des expressions qui commencent avec un token donné. Au lieu de cela, c'est une _table_ de pointeurs de fonction. Une colonne associe les fonctions de parsing préfixes avec les types de token. La seconde colonne associe les fonctions de parsing infixes avec les types de token.

La fonction que nous utiliserons comme le parseur infixe pour `TOKEN_PLUS`, `TOKEN_MINUS`, `TOKEN_STAR`, et `TOKEN_SLASH` est celle-ci :

^code binary

Quand une fonction de parsing préfixe est appelée, le token de tête a déjà été consommé. Une fonction de parsing infixe est encore plus _in medias res_ -- l'expression de l'opérande gauche entier a déjà été compilée et l'opérateur infixe subséquent consommé.

Le fait que l'opérande gauche soit compilé en premier s'arrange bien. Cela signifie qu'à l'exécution, ce code est exécuté en premier. Quand il tourne, la valeur qu'il produit finira sur la pile. C'est juste là où l'opérateur infixe va en avoir besoin.

Ensuite nous venons ici à `binary()` pour gérer le reste des opérateurs arithmétiques. Cette fonction compile l'opérande droit, un peu comme comment `unary()` compile son propre opérande de traîne. Finalement, elle émet l'instruction bytecode qui effectue l'opération binaire.

Quand tourné, la VM exécutera le code de l'opérande gauche et droit, dans cet ordre, laissant leurs valeurs sur la pile. Ensuite elle exécute l'instruction pour l'opérateur. Cela dépile les deux valeurs, calcule l'opération, et pousse le résultat.

Le code qui a probablement attiré votre œil ici est cette ligne `getRule()`. Quand nous parsons l'opérande de droite, nous avons de nouveau besoin de nous inquiéter de la précédence. Prenez une expression comme :

```lox
2 * 3 + 4
```

Quand nous parsons l'opérande droit de l'expression `*`, nous avons besoin de juste capturer `3`, et non `3 + 4`, parce que `+` est de précédence plus basse que `*`. Nous pourrions définir une fonction séparée pour chaque opérateur binaire. Chacune appellerait `parsePrecedence()` et passerait le niveau de précédence correct pour son opérande.

Mais c'est un peu fastidieux. La précédence de l'opérande de droite de chaque opérateur binaire est un niveau plus <span name="higher">haut</span> que la sienne. Nous pouvons chercher cela dynamiquement avec ce truc `getRule()` auquel nous arriverons bientôt. Utilisant cela, nous appelons `parsePrecedence()` avec un niveau plus haut que le niveau de cet opérateur.

<aside name="higher">

Nous utilisons un niveau de précédence plus _haut_ pour l'opérande droit parce que les opérateurs binaires sont associatifs à gauche. Étant donné une série du _même_ opérateur, comme :

```lox
1 + 2 + 3 + 4
```

Nous voulons le parser comme :

```lox
((1 + 2) + 3) + 4
```

Ainsi, quand nous parsons l'opérande de droite pour le premier `+`, nous voulons consommer le `2`, mais pas le reste, donc nous utilisons un niveau au-dessus de la précédence de `+`. Mais si notre opérateur était associatif à _droite_, ce serait faux. Étant donné :

```lox
a = b = c = d
```

Puisque l'assignation est associative à droite, nous voulons le parser comme :

```lox
a = (b = (c = d))
```

Pour permettre cela, nous appellerions `parsePrecedence()` avec la _même_ précédence que l'opérateur courant.

</aside>

De cette façon, nous pouvons utiliser une fonction `binary()` unique pour tous les opérateurs binaires même s'ils ont des précédences différentes.

## Un Parseur Pratt

Nous avons maintenant toutes les pièces et parties du compilateur disposées. Nous avons une fonction pour chaque production de grammaire : `number()`, `grouping()`, `unary()`, et `binary()`. Nous avons encore besoin d'implémenter `parsePrecedence()`, et `getRule()`. Nous savons aussi que nous avons besoin d'une table qui, étant donné un type de token, nous laisse trouver :

- la fonction pour compiler une expression préfixe commençant avec un token de ce type,

- la fonction pour compiler une expression infixe dont l'opérande gauche est suivi par un token de ce type, et

- la précédence d'une expression <span name="prefix">infixe</span> qui utilise ce token comme un opérateur.

<aside name="prefix">

Nous n'avons pas besoin de suivre la précédence de l'expression _préfixe_ commençant avec un token donné parce que tous les opérateurs préfixes en Lox ont la même précédence.

</aside>

Nous enveloppons ces trois propriétés dans une petite struct qui représente une ligne unique dans la table du parseur.

^code parse-rule (1 before, 2 after)

Ce type ParseFn est un simple <span name="typedef">typedef</span> pour un type de fonction qui ne prend aucun argument et ne renvoie rien.

<aside name="typedef" class="bottom">

La syntaxe de C pour les types de pointeur de fonction est si mauvaise que je la cache toujours derrière un typedef. Je comprends l'intention derrière la syntaxe -- le truc entier "la déclaration reflète l'utilisation" -- mais je pense que c'était une expérience syntaxique ratée.

</aside>

^code parse-fn-type (1 before, 2 after)

La table qui pilote notre parseur entier est un tableau de ParseRules. Nous en avons parlé depuis toujours, et finalement vous pouvez la voir.

^code rules

<aside name="big">

Voyez ce que je veux dire à propos de ne pas vouloir revisiter la table chaque fois que nous avions besoin d'une nouvelle colonne ? C'est une bête.

Si vous n'avez pas vu la syntaxe `[TOKEN_DOT] = ` dans un littéral de tableau C, c'est la syntaxe d'initialiseur désigné de C99. C'est plus clair que d'avoir à compter les index de tableau à la main.

</aside>

Vous pouvez voir comment `grouping` et `unary` sont insérés dans la colonne de parseur préfixe pour leurs types de token respectifs. Dans la colonne suivante, `binary` est câblé aux quatre opérateurs infixes arithmétiques. Ces opérateurs infixes ont aussi leurs précédences définies dans la dernière colonne.

À part ceux-là, le reste de la table est plein de `NULL` et `PREC_NONE`. La plupart de ces cellules vides sont parce qu'il n'y a pas d'expression associée avec ces tokens. Vous ne pouvez pas commencer une expression avec, disons, `else`, et `}` ferait un opérateur infixe assez confus.

Mais, aussi, nous n'avons pas encore rempli la grammaire entière. Dans les chapitres ultérieurs, alors que nous ajoutons de nouveaux types d'expression, certains de ces créneaux obtiendront des fonctions dedans. Une des choses que j'aime à propos de cette approche du parsing est qu'elle rend très facile de voir quels tokens sont utilisés par la grammaire et lesquels sont disponibles.

Maintenant que nous avons la table, nous sommes enfin prêts à écrire le code qui l'utilise. C'est là que notre parseur Pratt prend vie. La fonction la plus facile à définir est `getRule()`.

^code get-rule

Elle renvoie simplement la règle à l'index donné. Elle est appelée par `binary()` pour chercher la précédence de l'opérateur courant. Cette fonction existe seulement pour gérer un cycle de déclaration dans le code C. `binary()` est définie _avant_ la table de règles de sorte que la table peut stocker un pointeur vers elle. Cela signifie que le corps de `binary()` ne peut pas accéder à la table directement.

Au lieu de cela, nous enveloppons la recherche dans une fonction. Cela nous laisse déclarer de manière anticipée `getRule()` avant la définition de `binary()`, et <span name="forward">ensuite</span> _définir_ `getRule()` après la table. Nous aurons besoin d'une couple d'autres déclarations anticipées pour gérer le fait que notre grammaire est récursive, donc sortons-les toutes du chemin.

<aside name="forward">

C'est ce qui arrive quand vous écrivez votre VM dans un langage qui a été conçu pour être compilé sur un PDP-11.

</aside>

^code forward-declarations (2 before, 1 after)

Si vous suivez et implémentez clox vous-même, faites très attention aux petites annotations qui vous disent où mettre ces bouts de code. Ne vous inquiétez pas, cependant, si vous vous trompez, le compilateur C sera heureux de vous le dire.

### Parser avec précédence

Maintenant nous arrivons aux trucs amusants. Le maestro qui orchestre toutes les fonctions de parsing que nous avons définies est `parsePrecedence()`. Commençons avec le parsing des expressions préfixes.

^code precedence-body (1 before, 1 after)

Nous lisons le prochain token et cherchons la ParseRule correspondante. S'il n'y a pas de parseur préfixe, alors le token doit être une erreur de syntaxe. Nous rapportons cela et revenons à l'appelant.

Sinon, nous appelons cette fonction de parsing préfixe et la laissons faire son truc. Ce parseur préfixe compile le reste de l'expression préfixe, consommant tous les autres tokens dont il a besoin, et revient ici. Les expressions infixes sont là où ça devient intéressant puisque la précédence entre en jeu. L'implémentation est remarquablement simple.

^code infix (1 before, 1 after)

C'est la chose entière. Vraiment. Voici comment la fonction entière fonctionne : Au début de `parsePrecedence()`, nous cherchons un parseur préfixe pour le token courant. Le premier token va _toujours_ appartenir à quelque sorte d'expression préfixe, par définition. Il peut s'avérer être imbriqué comme un opérande à l'intérieur d'une ou plusieurs expressions infixes, mais alors que vous lisez le code de gauche à droite, le premier token que vous touchez appartient toujours à une expression préfixe.

Après avoir parsé cela, ce qui peut consommer plus de tokens, l'expression préfixe est faite. Maintenant nous cherchons un parseur infixe pour le prochain token. Si nous en trouvons un, cela signifie que l'expression préfixe que nous avons déjà compilée pourrait être un opérande pour lui. Mais seulement si l'appel à `parsePrecedence()` a une `precedence` qui est assez basse pour permettre cet opérateur infixe.

Si le prochain token est de trop basse priorité, ou n'est pas un opérateur infixe du tout, nous avons fini. Nous avons parsé autant d'expression que nous pouvons. Sinon, nous consommons l'opérateur et passons la main au parseur infixe que nous avons trouvé. Il consomme quels que soient les autres tokens dont il a besoin (habituellement l'opérande de droite) et revient à `parsePrecedence()`. Ensuite nous bouclons en arrière et voyons si le _prochain_ token est aussi un opérateur infixe valide qui peut prendre l'expression précédente entière comme son opérande. Nous continuons de boucler comme ça, craquant à travers les opérateurs infixes et leurs opérandes jusqu'à ce nous touchions un token qui n'est pas un opérateur infixe ou est de trop basse priorité et nous arrêtons.

C'est beaucoup de prose, mais si vous voulez vraiment fusionner votre esprit avec Vaughan Pratt et comprendre pleinement l'algorithme, passez à travers le parseur dans votre débogueur alors qu'il travaille à travers quelques expressions. Peut-être qu'une image aidera. Il n'y a qu'une poignée de fonctions, mais elles sont merveilleusement entrelacées :

<span name="connections"></span>

<img src="image/compiling-expressions/connections.png" alt="Les diverses fonctions de parsing et comment elles s'appellent les unes les autres." />

<aside name="connections">

La flèche <img src="image/compiling-expressions/calls.png" alt="Une flèche pleine." class="arrow" /> connecte une fonction à une autre fonction qu'elle appelle directement. La flèche <img src="image/compiling-expressions/points-to.png" alt="Une flèche ouverte." class="arrow" /> montre les pointeurs de la table vers les fonctions de parsing.

</aside>

Plus tard, nous aurons besoin d'ajuster le code dans ce chapitre pour gérer l'assignation. Mais, autrement, ce que nous avons écrit couvre tous nos besoins de compilation d'expression pour le reste du livre. Nous brancherons des fonctions de parsing supplémentaires dans la table quand nous ajouterons de nouveaux genres d'expressions, mais `parsePrecedence()` est complète.

## Dumper les Morceaux

Pendant que nous sommes ici dans le cœur de notre compilateur, nous devrions mettre un peu d'instrumentation. Pour aider à déboguer le bytecode généré, nous ajouterons le support pour dumper le morceau une fois que le compilateur finit. Nous avons eu un peu de journalisation temporaire plus tôt quand nous écrivions le morceau à la main. Maintenant nous mettrons du vrai code pour que nous puissions l'activer chaque fois que nous voulons.

Puisque ce n'est pas pour les utilisateurs finaux, nous le cachons derrière un drapeau.

^code define-debug-print-code (2 before, 1 after)

Quand ce drapeau est défini, nous utilisons notre module "debug" existant pour imprimer le bytecode du morceau.

^code dump-chunk (1 before, 1 after)

Nous faisons cela seulement si le code était libre d'erreurs. Après une erreur de syntaxe, le compilateur continue d'avancer mais il est dans une sorte d'état bizarre et pourrait produire du code cassé. C'est inoffensif parce qu'il ne sera pas exécuté, mais nous nous embrouillerons juste nous-mêmes si nous essayons de le lire.

Finalement, pour accéder à `disassembleChunk()`, nous avons besoin d'inclure son en-tête.

^code include-debug (1 before, 2 after)

Nous l'avons fait ! C'était la dernière section majeure à installer dans le pipeline de compilation et d'exécution de notre VM. Notre interpréteur ne _ressemble_ pas à grand-chose, mais à l'intérieur il scanne, parse, compile vers du bytecode, et exécute.

Démarrez la VM et tapez une expression. Si nous avons tout fait juste, il devrait calculer et imprimer le résultat. Nous avons maintenant une calculatrice arithmétique très sur-ingénierée. Nous avons beaucoup de fonctionnalités de langage à ajouter dans les chapitres à venir, mais la fondation est en place.

<div class="challenges">

## Défis

1.  Pour comprendre vraiment le parseur, vous avez besoin de voir comment l'exécution file à travers les fonctions de parsing intéressantes -- `parsePrecedence()` et les fonctions de parseur stockées dans la table. Prenez cette (étrange) expression :

    ```lox
    (-1 + 2) * 3 - -4
    ```

    Écrivez une trace de comment ces fonctions sont appelées. Montrez l'ordre dans lequel elles sont appelées, qui appelle qui, et les arguments passés à elles.

2.  La ligne ParseRule pour `TOKEN_MINUS` a les deux pointeurs de fonction préfixe et infixe. C'est parce que `-` est à la fois un opérateur préfixe (négation unaire) et un infixe (soustraction).

    Dans le langage Lox complet, quels autres tokens peuvent être utilisés dans les deux positions préfixe et infixe ? Quoi à propos de C ou dans un autre langage de votre choix ?

3.  Vous pourriez vous interroger sur les expressions complexes "mixfixes" qui ont plus que deux opérandes séparés par des tokens. L'opérateur conditionnel ou "ternaire" de C, `?:`, est un largement connu.

    Ajoutez le support pour cet opérateur au compilateur. Vous n'avez pas à générer de bytecode, montrez juste comment vous le connecteriez au parseur et géreriez les opérandes.

</div>

<div class="design-note">

## Note de Conception : C'est Juste du Parsing

Je vais faire une déclaration ici qui sera impopulaire avec certains gens de compilateur et de langage. C'est OK si vous n'êtes pas d'accord. Personnellement, j'apprends plus d'opinions fortement énoncées avec lesquelles je suis en désaccord que je ne le fais de plusieurs pages de qualificatifs et d'équivoque. Ma réclamation est que _le parsing n'a pas d'importance_.

Au fil des années, beaucoup de gens de langage de programmation, spécialement dans le monde académique, se sont mis _vraiment_ dans les parseurs et les ont pris très sérieusement. Initialement, c'étaient les gens de compilateur qui se sont mis dans les <span name="yacc">compilateurs de compilateurs</span>, LALR, et d'autres trucs comme ça. La première moitié du livre du dragon est une longue lettre d'amour aux merveilles des générateurs de parseurs.

<aside name="yacc">

Nous souffrons tous du vice de "quand tout ce que vous avez est un marteau, tout ressemble à un clou", mais peut-être aucun si visiblement que les gens de compilateur. Vous ne croiriez pas l'ampleur des problèmes logiciels qui semblent miraculeusement exiger un nouveau petit langage dans leur solution dès que vous demandez de l'aide à un hacker de compilateur.

Yacc et d'autres compilateurs de compilateurs sont l'exemple le plus délicieusement récursif. "Wouah, écrire des compilateurs est une corvée. Je sais, écrivons un compilateur pour écrire notre compilateur pour nous."

Pour l'enregistrement, je ne réclame pas l'immunité à cette affliction.

</aside>

Plus tard, les gens de programmation fonctionnelle se sont mis dans les combinateurs de parseurs, les parseurs packrat, et d'autres sortes de choses. Parce que, évidemment, si vous donnez un problème à un programmeur fonctionnel, la première chose qu'ils feront est de sortir une poche pleine de fonctions d'ordre supérieur.

Là-bas dans le pays de l'analyse d'algorithme et de maths, il y a un long héritage de recherche dans la preuve de temps et d'utilisation mémoire pour diverses techniques de parsing, transformant des problèmes de parsing en d'autres problèmes et vice versa, et assignant des classes de complexité à différentes grammaires.
À un niveau, ce truc est important. Si vous implémentez un langage, vous voulez une certaine assurance que votre parseur ne deviendra pas exponentiel et prendra 7 000 ans pour parser un cas limite bizarre dans la grammaire. La théorie des parseurs vous donne cette borne. Comme exercice intellectuel, apprendre les techniques de parsing est aussi amusant et gratifiant.

Mais si votre but est juste d'implémenter un langage et de le mettre devant des utilisateurs, presque tout ce truc n'a pas d'importance. Il est vraiment facile de se laisser emporter par l'enthousiasme des gens qui _sont_ dedans et pensent que votre front end a _besoin_ de quelque chose de génial type usine-de-parseur-combinateur-généré. J'ai vu des gens brûler des tonnes de temps à écrire et réécrire leur parseur en utilisant quelle que soit la bibliothèque ou technique chaude d'aujourd'hui.

C'est du temps qui n'ajoute aucune valeur à la vie de votre utilisateur. Si vous essayez juste de finir votre parseur, choisissez une des techniques standard, utilisez-la, et passez à autre chose. La descente récursive, le parsing Pratt, et les générateurs de parseurs populaires comme ANTLR ou Bison sont tous bien.

Prenez le temps supplémentaire que vous avez économisé à ne pas réécrire votre code de parsing et dépensez-le à améliorer les messages d'erreur de compilation que votre compilateur montre aux utilisateurs. Une bonne gestion et rapport d'erreur est plus précieuse aux utilisateurs que presque n'importe quoi d'autre dans lequel vous pouvez mettre du temps dans le front end.

</div>
